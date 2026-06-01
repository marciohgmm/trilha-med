import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Ativa persistência local do Firestore (dados em cache + leitura offline).
///
/// Chamado uma vez no arranque do app. As telas com `.snapshots()` passam a
/// poder receber dados do cache quando não há rede (sem crash), desde que já
/// tenham sido lidos pelo menos uma vez online.
void configureFirestoreForOffline() {
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('configureFirestoreForOffline: $e\n$st');
    }
  }
}
