import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/firestore_paths.dart';
import '../../data/app_access_default_seed.dart';
import '../../models/app_access_config_model.dart';

/// Leitura/escrita de `app_access_config/plans`.
class AppAccessConfigService {
  AppAccessConfigService({FirebaseFirestore? db, AppAccessConfigModel? inMemory})
      : _db = db,
        _inMemory = inMemory;

  /// Serviço em memória (testes) — não acessa Firestore.
  factory AppAccessConfigService.memory(AppAccessConfigModel model) {
    return AppAccessConfigService(inMemory: model);
  }

  static final AppAccessConfigService instance = AppAccessConfigService();

  final FirebaseFirestore? _db;
  final AppAccessConfigModel? _inMemory;

  AppAccessConfigModel _cache = AppAccessDefaultSeed.defaults();
  DateTime? _cacheAt;
  Stream<AppAccessConfigModel>? _watchStream;

  static const _cacheTtl = Duration(minutes: 5);

  FirebaseFirestore get _firestore => _db ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _docRef => _firestore
      .collection(FirestorePaths.appAccessConfig)
      .doc(AppAccessConfigModel.documentId);

  AppAccessConfigModel get cached => _cache;

  Stream<AppAccessConfigModel> watch() {
    final inMemory = _inMemory;
    if (inMemory != null) {
      return Stream.value(inMemory);
    }
    _watchStream ??= _docRef.snapshots().map((snap) {
      final model = snap.exists && snap.data() != null
          ? AppAccessConfigModel.fromDoc(snap.data())
          : AppAccessDefaultSeed.defaults();
      _cache = model;
      _cacheAt = DateTime.now();
      return model;
    }).asBroadcastStream();
    return _watchStream!;
  }

  Future<AppAccessConfigModel> get() async {
    final inMemory = _inMemory;
    if (inMemory != null) return inMemory;
    if (_cacheAt != null &&
        DateTime.now().difference(_cacheAt!) < _cacheTtl) {
      return _cache;
    }
    try {
      final snap = await _docRef.get();
      if (!snap.exists || snap.data() == null) {
        _cache = AppAccessDefaultSeed.defaults();
      } else {
        _cache = AppAccessConfigModel.fromDoc(snap.data());
      }
      _cacheAt = DateTime.now();
      return _cache;
    } catch (e) {
      if (kDebugMode) debugPrint('[AppAccessConfigService] get: $e');
      return AppAccessDefaultSeed.defaults();
    }
  }

  Future<void> refreshCache() async {
    await get();
  }

  Future<void> ensureDefaultDocument() async {
    if (_inMemory != null) return;
    final snap = await _docRef.get();
    if (snap.exists) return;
    final defaults = AppAccessDefaultSeed.defaults();
    await _docRef.set(
      defaults.toFirestore(updatedBy: 'system_seed'),
      SetOptions(merge: true),
    );
    _cache = defaults;
    _cacheAt = DateTime.now();
  }

  Future<void> save(AppAccessConfigModel config, {required String updatedBy}) async {
    if (_inMemory != null) {
      _cache = config;
      _cacheAt = DateTime.now();
      return;
    }
    await _docRef.set(
      config.toFirestore(updatedBy: updatedBy),
      SetOptions(merge: false),
    );
    _cache = config;
    _cacheAt = DateTime.now();
  }
}
