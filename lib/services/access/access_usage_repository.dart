import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/firestore_paths.dart';
import '../../models/access_usage_stats.dart';

/// Estado em memória para testes unitários.
class AccessUsageInMemory {
  AccessUsageStats stats = const AccessUsageStats();
  final Set<String> flashcardIds = {};
  final Set<String> questionIds = {};

  bool markFlashcard(String cardId) {
    if (flashcardIds.contains(cardId)) return false;
    flashcardIds.add(cardId);
    stats = AccessUsageStats(
      flashcardsConsumed: stats.flashcardsConsumed + 1,
      questionsConsumed: stats.questionsConsumed,
    );
    return true;
  }

  bool markQuestion(String questionId) {
    if (questionIds.contains(questionId)) return false;
    questionIds.add(questionId);
    stats = AccessUsageStats(
      flashcardsConsumed: stats.flashcardsConsumed,
      questionsConsumed: stats.questionsConsumed + 1,
    );
    return true;
  }
}

/// Persistência de cota P0 — dedup por item + contadores em `stats`.
class AccessUsageRepository {
  AccessUsageRepository({FirebaseFirestore? firestore, AccessUsageInMemory? memory})
      : _db = firestore,
        _memory = memory;

  factory AccessUsageRepository.memory(AccessUsageInMemory memory) {
    return AccessUsageRepository(memory: memory);
  }

  final FirebaseFirestore? _db;
  final AccessUsageInMemory? _memory;

  FirebaseFirestore get _firestore => _db ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _statsRef(String userId) {
    return _firestore.doc(FirestorePaths.userAccessUsageStatsPath(userId));
  }

  CollectionReference<Map<String, dynamic>> _flashcardItems(String userId) {
    return _firestore
        .collection(FirestorePaths.users)
        .doc(userId)
        .collection(FirestorePaths.userAccessUsage)
        .doc('flashcards')
        .collection('items');
  }

  CollectionReference<Map<String, dynamic>> _questionItems(String userId) {
    return _firestore
        .collection(FirestorePaths.users)
        .doc(userId)
        .collection(FirestorePaths.userAccessUsage)
        .doc('questions')
        .collection('items');
  }

  Future<AccessUsageStats> loadStats(String userId) async {
    final memory = _memory;
    if (memory != null) return memory.stats;
    try {
      final snap = await _statsRef(userId).get();
      return AccessUsageStats.fromMap(snap.data());
    } catch (e) {
      _logFailOpen('loadUsageStats', userId: userId, detail: e);
      return const AccessUsageStats();
    }
  }

  /// Retorna `true` se registrou consumo novo; `false` se já existia.
  Future<bool> tryMarkFlashcardConsumed(String userId, String cardId) async {
    return _tryMarkItemConsumed(
      userId: userId,
      itemId: cardId,
      itemRef: _memory == null ? _flashcardItems(userId).doc(cardId) : null,
      statsField: 'flashcardsConsumed',
      action: 'tryConsumeFlashcard',
      markInMemory: (mem) => mem.markFlashcard(cardId),
    );
  }

  Future<bool> tryMarkQuestionConsumed(String userId, String questionId) async {
    return _tryMarkItemConsumed(
      userId: userId,
      itemId: questionId,
      itemRef: _memory == null ? _questionItems(userId).doc(questionId) : null,
      statsField: 'questionsConsumed',
      action: 'tryConsumeQuestion',
      markInMemory: (mem) => mem.markQuestion(questionId),
    );
  }

  Future<bool> _tryMarkItemConsumed({
    required String userId,
    required String itemId,
    required DocumentReference<Map<String, dynamic>>? itemRef,
    required String statsField,
    required String action,
    required bool Function(AccessUsageInMemory mem) markInMemory,
  }) async {
    final memory = _memory;
    if (memory != null) {
      return markInMemory(memory);
    }
    if (itemRef == null) return false;
    try {
      final existing = await itemRef.get();
      if (existing.exists) return false;

      final statsRef = _statsRef(userId);
      await _firestore.runTransaction((tx) async {
        final itemSnap = await tx.get(itemRef);
        if (itemSnap.exists) return;
        tx.set(itemRef, {
          'firstConsumedAt': FieldValue.serverTimestamp(),
        });
        tx.set(
          statsRef,
          {
            statsField: FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });
      return true;
    } catch (e) {
      _logFailOpen(
        action,
        userId: userId,
        detail: e,
        extra: 'itemId=$itemId',
      );
      return false;
    }
  }

  void _logFailOpen(
    String action, {
    required String userId,
    required Object detail,
    String? extra,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[ContentAccess] fail-open action=$action userId=$userId '
      '${extra != null ? '$extra ' : ''}'
      'reason=firestore_error detail=$detail',
    );
  }
}
