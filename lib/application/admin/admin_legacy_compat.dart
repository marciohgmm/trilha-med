import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/permissions/app_role.dart';
import '../../core/constants/firestore_paths.dart';
import '../../services/auth/admin_auth_service.dart';

/// Camada de compatibilidade: sinais legados → papéis RBAC (Fase 1).
class AdminLegacyCompat {
  AdminLegacyCompat({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<bool> isListedInAdminsCollection(String uid) async {
    if (uid.isEmpty) return false;
    try {
      final doc = await _db.collection(AdminAuthService.collectionAdmins).doc(uid).get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  /// Papéis implícitos quando `rbacRoles` ainda não foi definido no Firestore.
  List<AppRole> implicitRoles({
    required bool isFounder,
    required bool listedInAdmins,
    required bool isAdminFlag,
    required List<AppRole> existingRbacRoles,
  }) {
    if (existingRbacRoles.isNotEmpty) return existingRbacRoles;
    if (isFounder) return const [AppRole.masterAdmin];
    if (listedInAdmins || isAdminFlag) return const [AppRole.admin];
    return const [AppRole.user];
  }

  /// Grava `rbacRoles` apenas se ausente — não sobrescreve atribuições explícitas.
  Future<bool> ensureRbacRolesPersisted({
    required String userId,
    required bool isFounder,
    required bool listedInAdmins,
    required bool isAdminFlag,
    Map<String, dynamic>? userData,
  }) async {
    if (userId.isEmpty) return false;

    final existing = AppRole.fromKeys(
      _readStringList(userData?['rbacRoles']),
    );
    if (existing.isNotEmpty) return false;

    final roles = implicitRoles(
      isFounder: isFounder,
      listedInAdmins: listedInAdmins,
      isAdminFlag: isAdminFlag,
      existingRbacRoles: existing,
    );
    if (roles.length == 1 && roles.first == AppRole.user) return false;

    await _db.collection(FirestorePaths.users).doc(userId).set({
      'rbacRoles': roles.map((r) => r.key).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return true;
  }

  /// Após [AdminAuthService.grantAdmin] — garante papel admin no RBAC.
  Future<void> syncRbacAfterGrant(String userId) async {
    if (userId.isEmpty) return;
    final doc = await _db.collection(FirestorePaths.users).doc(userId).get();
    final existing = AppRole.fromKeys(
      _readStringList(doc.data()?['rbacRoles']),
    );
    final roles = <AppRole>{...existing, AppRole.admin};
    await _db.collection(FirestorePaths.users).doc(userId).set({
      'rbacRoles': roles.map((r) => r.key).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Após [AdminAuthService.revokeAdmin] — remove admin do RBAC sem apagar outros papéis.
  Future<void> syncRbacAfterRevoke(String userId) async {
    if (userId.isEmpty) return;
    final doc = await _db.collection(FirestorePaths.users).doc(userId).get();
    var roles = AppRole.fromKeys(_readStringList(doc.data()?['rbacRoles']));
    roles = roles.where((r) => r != AppRole.admin && r != AppRole.masterAdmin).toList();
    if (roles.isEmpty) roles = const [AppRole.user];
    await _db.collection(FirestorePaths.users).doc(userId).set({
      'rbacRoles': roles.map((r) => r.key).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  List<String> _readStringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
  }
}
