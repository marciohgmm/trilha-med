import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/feature_flags/feature_modules.dart';
import '../../data/feature_flag_default_seed.dart';
import '../../models/feature_flag_model.dart';

/// Leitura de flags com cache em memória (TTL) + stream da coleção.
class FeatureFlagService {
  FeatureFlagService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  static final FeatureFlagService instance = FeatureFlagService();

  final FirebaseFirestore _db;

  Map<String, FeatureFlagModel> _cache = {
    for (final m in FeatureFlagDefaultSeed.defaults()) m.id: m,
  };
  DateTime? _cacheAt;
  Stream<Map<String, FeatureFlagModel>>? _watchAllStream;

  static const _cacheTtl = Duration(minutes: 5);

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestorePaths.platformFeatureFlags);

  Map<String, FeatureFlagModel> get cachedFlags =>
      Map.unmodifiable(_cache);

  Stream<Map<String, FeatureFlagModel>> watchAll() {
    _watchAllStream ??= _col.snapshots().map(_mergeSnapshot).asBroadcastStream();
    return _watchAllStream!;
  }

  Stream<FeatureFlagModel?> watchModule(String moduleId) {
    return watchAll().map((all) => all[moduleId]);
  }

  Map<String, FeatureFlagModel> _mergeSnapshot(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) {
    final merged = {
      for (final m in FeatureFlagDefaultSeed.defaults()) m.id: m,
    };
    for (final doc in snap.docs) {
      merged[doc.id] = FeatureFlagModel.fromDoc(doc.id, doc.data());
    }
    _cache = merged;
    _cacheAt = DateTime.now();
    return merged;
  }

  Future<void> refreshCache() async {
    final snap = await _col.get();
    _mergeSnapshot(snap);
  }

  Future<FeatureFlagModel?> getModule(String moduleId) async {
    if (_cacheAt != null &&
        DateTime.now().difference(_cacheAt!) < _cacheTtl &&
        _cache.containsKey(moduleId)) {
      return _cache[moduleId];
    }
    try {
      final doc = await _col.doc(moduleId).get();
      if (!doc.exists || doc.data() == null) {
        return FeatureFlagModel.enabledDefault(moduleId);
      }
      final model = FeatureFlagModel.fromDoc(moduleId, doc.data()!);
      _cache = {..._cache, moduleId: model};
      _cacheAt = DateTime.now();
      return model;
    } catch (e) {
      if (kDebugMode) debugPrint('[FeatureFlagService] getModule: $e');
      return FeatureFlagModel.enabledDefault(moduleId);
    }
  }

  Future<bool> isEnabled(String moduleId) async {
    final module = await getModule(moduleId);
    return module?.enabled ?? true;
  }

  Future<bool> isInMaintenance(String moduleId) async {
    final module = await getModule(moduleId);
    return module?.maintenanceMode ?? false;
  }

  /// Cria documentos ausentes (merge) — idempotente.
  Future<int> ensureDefaultDocuments() async {
    var created = 0;
    final batch = _db.batch();
    for (final def in FeatureFlagDefaultSeed.defaults()) {
      final ref = _col.doc(def.id);
      final snap = await ref.get();
      if (snap.exists) continue;
      batch.set(ref, {
        ...def.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': 'system_seed',
      });
      created++;
    }
    if (created > 0) await batch.commit();
    return created;
  }

  Future<void> saveModule({
    required String moduleId,
    required bool enabled,
    required bool maintenanceMode,
    required String maintenanceMessage,
    required String updatedBy,
  }) async {
    if (!FeatureModules.all.contains(moduleId)) {
      throw ArgumentError('Módulo desconhecido: $moduleId');
    }
    final data = {
      'enabled': enabled,
      'maintenanceMode': maintenanceMode,
      'maintenanceMessage': maintenanceMessage.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    };
    await _col.doc(moduleId).set(data, SetOptions(merge: true));
    _cache[moduleId] = FeatureFlagModel.fromDoc(moduleId, data);
    _cacheAt = DateTime.now();
  }

  void invalidateCache() {
    _cacheAt = null;
  }
}
