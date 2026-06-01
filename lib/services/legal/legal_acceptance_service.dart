import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/legal/legal_acceptance_record.dart';
import '../../core/legal/legal_versions.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Aceite legal registrável (LGPD Art. 8º / 9º).
class LegalAcceptanceService {
  LegalAcceptanceService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String userId) => _db
      .collection(FirestorePaths.users)
      .doc(userId)
      .collection(FirestorePaths.legalAcceptances);

  /// Verifica se o usuário aceitou as versões vigentes de política e termos.
  Future<bool> requiredLegalAcceptance(String userId) async {
    if (userId.isEmpty) return true;
    final latest = await getLatestAcceptance(userId);
    if (latest == null) return true;
    return !latest.coversCurrentVersions();
  }

  Future<LegalAcceptanceRecord?> getLatestAcceptance(String userId) async {
    try {
      final snap = await _col(userId)
          .orderBy('acceptedAt', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      return LegalAcceptanceRecord.fromDoc(doc.id, doc.data());
    } catch (e) {
      debugPrint('[LegalAcceptance] getLatest: $e');
      return null;
    }
  }

  Stream<bool> watchNeedsAcceptance(String userId) {
    return _col(userId)
        .orderBy('acceptedAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return true;
      final record =
          LegalAcceptanceRecord.fromDoc(snap.docs.first.id, snap.docs.first.data());
      return !record.coversCurrentVersions();
    });
  }

  Future<void> recordAcceptance({
    required String userId,
    String? ipHash,
  }) async {
    final info = await PackageInfo.fromPlatform();
    final platform = _platformLabel();
    final record = LegalAcceptanceRecord(
      id: '',
      acceptedAt: DateTime.now(),
      policyVersion: LegalVersions.policyVersion,
      termsVersion: LegalVersions.termsVersion,
      ipHash: ipHash,
      platform: platform,
      appVersion: '${info.version}+${info.buildNumber}',
    );
    await _col(userId).add(record.toMap());
  }

  String _platformLabel() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }
}
