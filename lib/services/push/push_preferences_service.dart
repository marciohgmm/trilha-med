import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/push/push_notification_types.dart';

/// Preferências de push em `users/{uid}.notificationPrefs`.
class PushPreferencesService {
  PushPreferencesService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static Map<String, bool> defaultPrefs() {
    return {
      for (final k in PushNotificationType.all) k: true,
    };
  }

  Future<Map<String, bool>> getPrefs(String userId) async {
    final snap = await _db.collection('users').doc(userId).get();
    final raw = snap.data()?['notificationPrefs'] as Map?;
    if (raw == null) return defaultPrefs();
    final out = defaultPrefs();
    for (final e in raw.entries) {
      out[e.key.toString()] = e.value == true;
    }
    return out;
  }

  Stream<Map<String, bool>> watchPrefs(String userId) {
    return _db.collection('users').doc(userId).snapshots().map((snap) {
      final raw = snap.data()?['notificationPrefs'] as Map?;
      if (raw == null) return defaultPrefs();
      final out = defaultPrefs();
      for (final e in raw.entries) {
        out[e.key.toString()] = e.value == true;
      }
      return out;
    });
  }

  Future<void> setPref(String userId, String key, bool enabled) async {
    await _db.collection('users').doc(userId).set({
      'notificationPrefs': {key: enabled},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setAll(String userId, Map<String, bool> prefs) async {
    await _db.collection('users').doc(userId).set({
      'notificationPrefs': prefs,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
