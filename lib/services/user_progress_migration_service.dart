import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/firestore_paths.dart';

/// Resultado da migração não destrutiva `usuarios` → `users` (F1).
class UserProgressMigrationResult {
  final int copied;
  final int skipped;
  final int legacyDocs;

  const UserProgressMigrationResult({
    this.copied = 0,
    this.skipped = 0,
    this.legacyDocs = 0,
  });

  bool get hadLegacyData => legacyDocs > 0;
  bool get performedWork => copied > 0;
}

/// Copia progresso legado para `users/{uid}/progresso` sem apagar `usuarios`.
class UserProgressMigrationService {
  UserProgressMigrationService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String migrationSourceField = '_migratedFrom';
  static const String migrationSourceValue = 'usuarios';
  static const String migrationAtField = 'migratedAt';

  /// Idempotente: só grava em `users` se o doc do card ainda não existir.
  Future<UserProgressMigrationResult> migrateLegacyProgressIfNeeded(
    String userId,
  ) async {
    if (userId.isEmpty) {
      return const UserProgressMigrationResult();
    }

    try {
      final legacySnap = await _db
          .collection(FirestorePaths.usuarios)
          .doc(userId)
          .collection(FirestorePaths.userProgressSubcollection)
          .get();

      if (legacySnap.docs.isEmpty) {
        return const UserProgressMigrationResult();
      }

      var copied = 0;
      var skipped = 0;

      for (final leg in legacySnap.docs) {
        final targetRef = _db
            .collection(FirestorePaths.users)
            .doc(userId)
            .collection(FirestorePaths.userProgressSubcollection)
            .doc(leg.id);

        final existing = await targetRef.get();
        if (existing.exists) {
          skipped++;
          continue;
        }

        final data = Map<String, dynamic>.from(leg.data());
        data[migrationSourceField] = migrationSourceValue;
        data[migrationAtField] = FieldValue.serverTimestamp();

        await targetRef.set(data, SetOptions(merge: true));
        copied++;
      }

      if (kDebugMode && copied > 0) {
        debugPrint(
          '[F1] migrateLegacyProgress uid=$userId '
          'copied=$copied skipped=$skipped legacy=${legacySnap.docs.length}',
        );
      }

      return UserProgressMigrationResult(
        copied: copied,
        skipped: skipped,
        legacyDocs: legacySnap.docs.length,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[F1] migrateLegacyProgress failed uid=$userId: $e');
      }
      return const UserProgressMigrationResult();
    }
  }
}
