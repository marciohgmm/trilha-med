import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/firestore_paths.dart';
import '../../models/user_public_profile.dart';

/// Sincroniza campos públicos (S1) — sem dados privados.
class UserPublicProfileService {
  UserPublicProfileService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _profileRef(String userId) => _db
      .collection(FirestorePaths.users)
      .doc(userId)
      .collection(FirestorePaths.userPublicProfile)
      .doc(FirestorePaths.userPublicProfileDocId);

  /// Atualiza apenas `public_profile` (merge). Não altera `users` privado.
  Future<void> syncFromAuthUser({User? user}) async {
    final u = user ?? FirebaseAuth.instance.currentUser;
    if (u == null) return;

    final name = (u.displayName ?? '').trim();
    final photo = u.photoURL?.trim();

    await syncProfile(
      userId: u.uid,
      displayName: name.isNotEmpty ? name : _fallbackFromEmail(u.email),
      photoUrl: photo?.isNotEmpty == true ? photo : null,
    );
  }

  Future<void> syncProfile({
    required String userId,
    String? displayName,
    String? photoUrl,
  }) async {
    if (userId.isEmpty) return;

    final data = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (displayName != null) {
      data['displayName'] = displayName.trim();
    }
    if (photoUrl != null && photoUrl.trim().isNotEmpty) {
      data['photoUrl'] = photoUrl.trim();
    }

    await _profileRef(userId).set(data, SetOptions(merge: true));
  }

  Future<UserPublicProfile?> getProfile(String userId) async {
    if (userId.isEmpty) return null;
    final snap = await _profileRef(userId).get();
    if (!snap.exists) return null;
    return UserPublicProfile.fromMap(userId, snap.data());
  }

  Stream<UserPublicProfile?> watchProfile(String userId) {
    return _profileRef(userId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return UserPublicProfile.fromMap(userId, snap.data());
    });
  }

  static String _fallbackFromEmail(String? email) {
    final e = (email ?? '').trim();
    if (e.contains('@')) return e.split('@').first;
    return 'Participante';
  }
}
