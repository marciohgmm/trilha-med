import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../application/admin/admin_access_service.dart';
import '../../application/admin/admin_legacy_compat.dart';
import '../../core/permissions/permission_context.dart';

/// Permissões admin: criador por e-mail (sempre) + coleção `admins/{uid}`.
class AdminAuthService {
  AdminAuthService({
    FirebaseFirestore? firestore,
    AdminLegacyCompat? legacyCompat,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _legacyCompat = legacyCompat ?? AdminLegacyCompat();

  final FirebaseFirestore _db;
  final AdminLegacyCompat _legacyCompat;

  static const String collectionAdmins = 'admins';
  static const String founderEmail = 'marciohgmm@gmail.com';
  static const String roleSuperAdmin = 'superadmin';
  static const String roleAdmin = 'admin';

  static String normalizeEmail(String? email) =>
      (email ?? '').trim().toLowerCase();

  /// Criador do app — bypass imediato, sem depender do Firestore.
  static bool isFounderEmail(String? email) {
    return normalizeEmail(email) == founderEmail;
  }

  static bool isFounderUser(User? user) => isFounderEmail(user?.email);

  void logState(String where, {User? user, bool? listedAdmin}) {
    if (!kDebugMode) return;
    final u = user ?? FirebaseAuth.instance.currentUser;
    final email = u?.email;
    final founder = isFounderEmail(email);
    debugPrint(
      '[AdminAuth][$where] '
      'email=$email uid=${u?.uid} '
      'isFounder=$founder '
      'listedAdmin=$listedAdmin',
    );
  }

  /// Verificação síncrona para UI (founder sempre true).
  bool isAdminSync({String? email}) {
    if (isFounderEmail(email)) return true;
    return false;
  }

  /// Resolve acesso administrativo — delega ao [AdminAccessService] (RBAC + legado).
  Future<AdminAccessResult> resolveAccess({User? user}) async {
    final u = user ?? FirebaseAuth.instance.currentUser;
    if (u == null) {
      logState('resolveAccess_no_user');
      return const AdminAccessResult(
        allowed: false,
        isFounder: false,
        listedInAdmins: false,
      );
    }

    if (isFounderUser(u)) {
      try {
        await syncCurrentUser(user: u);
      } catch (e) {
        debugPrint('[AdminAuth] sync founder (não bloqueante): $e');
      }
    }

    return AdminAccessService.instance.resolveAdminAccess(user: u);
  }

  Future<void> syncCurrentUser({User? user}) async {
    final u = user ?? FirebaseAuth.instance.currentUser;
    if (u == null) return;

    final email = normalizeEmail(u.email);
    final founder = isFounderEmail(email);
    final adminRef = _db.collection(collectionAdmins).doc(u.uid);
    final userRef = _db.collection('users').doc(u.uid);

    final listed = await adminRef.get();
    final isAdmin = founder || listed.exists;

    if (founder) {
      await adminRef.set({
        'uid': u.uid,
        'email': email,
        'role': roleSuperAdmin,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await userRef.set({
      'email': email,
      'isAdmin': isAdmin,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    logState('syncCurrentUser', user: u, listedAdmin: listed.exists || founder);
  }

  Future<bool> isCurrentUserAdmin() async {
    final r = await resolveAccess();
    return r.allowed;
  }

  Future<bool> isUserAdmin(String uid, {String? email}) async {
    if (isFounderEmail(email)) return true;
    final doc = await _db.collection(collectionAdmins).doc(uid).get();
    return doc.exists;
  }

  /// Founder: emite `true` imediatamente. Outros: stream do doc admins.
  Stream<bool> watchIsAdmin(String uid, {String? email}) {
    if (isFounderEmail(email)) {
      logState('watchIsAdmin_founder_immediate', user: FirebaseAuth.instance.currentUser);
      return Stream<bool>.value(true);
    }
    return _db.collection(collectionAdmins).doc(uid).snapshots().map((snap) {
      if (kDebugMode) {
        debugPrint('[AdminAuth][watchIsAdmin] uid=$uid exists=${snap.exists}');
      }
      return snap.exists;
    });
  }

  Future<void> grantAdmin({
    required String uid,
    required String email,
    String role = roleAdmin,
  }) async {
    final actor = FirebaseAuth.instance.currentUser;
    if (actor == null) {
      throw Exception('Usuário não autenticado.');
    }
    if (!await isCurrentUserAdmin()) {
      throw Exception('Sem permissão para conceder admin.');
    }
    await _db.collection(collectionAdmins).doc(uid).set({
      'uid': uid,
      'email': email.trim(),
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _db.collection('users').doc(uid).set({
      'isAdmin': true,
      'email': email.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _legacyCompat.syncRbacAfterGrant(uid);

    await AdminAccessService.instance.logAdminAccessGranted(
      actorUserId: actor.uid,
      targetUserId: uid,
      source: 'legacy.grantAdmin',
      metadata: {
        'legacyRole': role,
        'email': email.trim(),
      },
    );
  }

  Future<void> revokeAdmin(String uid) async {
    final actor = FirebaseAuth.instance.currentUser;
    if (actor == null) {
      throw Exception('Usuário não autenticado.');
    }
    final userSnap = await _db.collection('users').doc(uid).get();
    if (isFounderEmail(userSnap.data()?['email']?.toString())) {
      throw Exception('Não é possível revogar o criador do app.');
    }
    await _db.collection(collectionAdmins).doc(uid).delete();
    await _db.collection('users').doc(uid).set({
      'isAdmin': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _legacyCompat.syncRbacAfterRevoke(uid);

    await AdminAccessService.instance.logAdminAccessRevoked(
      actorUserId: actor.uid,
      targetUserId: uid,
      source: 'legacy.revokeAdmin',
    );
  }

  Stream<List<AdminRecord>> streamAllAdmins() {
    return _db.collection(collectionAdmins).orderBy('email').snapshots().map(
          (s) => s.docs
              .map((d) => AdminRecord.fromMap(d.id, d.data()))
              .toList(),
        );
  }
}

class AdminAccessResult {
  final bool allowed;
  final bool isFounder;
  final bool listedInAdmins;
  final bool hasIsAdminFlag;
  final String email;
  final String uid;
  final PermissionContext? permissionContext;

  const AdminAccessResult({
    required this.allowed,
    required this.isFounder,
    required this.listedInAdmins,
    this.hasIsAdminFlag = false,
    this.email = '',
    this.uid = '',
    this.permissionContext,
  });

  bool get isAdmin => allowed;
}

class AdminRecord {
  final String uid;
  final String email;
  final String role;
  final DateTime? createdAt;

  const AdminRecord({
    required this.uid,
    required this.email,
    required this.role,
    this.createdAt,
  });

  factory AdminRecord.fromMap(String id, Map<String, dynamic> map) {
    DateTime? created;
    final c = map['createdAt'];
    if (c is Timestamp) created = c.toDate();
    return AdminRecord(
      uid: map['uid']?.toString() ?? id,
      email: map['email']?.toString() ?? '',
      role: map['role']?.toString() ?? AdminAuthService.roleAdmin,
      createdAt: created,
    );
  }

  bool get isSuperAdmin => role == AdminAuthService.roleSuperAdmin;
}
