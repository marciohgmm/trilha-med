import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'admin_auth_service.dart';
import '../user_progress_migration_service.dart';
import 'user_public_profile_service.dart';

/// Garante documento `users/{uid}` sem sobrescrever permissões de admin.
class UserProfileService {
  UserProfileService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final AdminAuthService _adminAuth = AdminAuthService();
  final UserPublicProfileService _publicProfile = UserPublicProfileService();
  final UserProgressMigrationService _progressMigration =
      UserProgressMigrationService();

  Future<void> ensureUserDocument({User? user}) async {
    final u = user ?? FirebaseAuth.instance.currentUser;
    if (u == null) return;

    await _db.collection('users').doc(u.uid).set({
      'email': u.email ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _adminAuth.syncCurrentUser(user: u);

    try {
      await _publicProfile.syncFromAuthUser(user: u);
    } catch (_) {
      // Não bloqueia login se o perfil público falhar.
    }

    try {
      await _progressMigration.migrateLegacyProgressIfNeeded(u.uid);
    } catch (_) {
      // F1: migração legada não bloqueia login.
    }
  }
}
