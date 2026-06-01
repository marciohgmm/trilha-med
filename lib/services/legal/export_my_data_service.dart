import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/legal/legal_versions.dart';

/// Portabilidade de dados (LGPD Art. 18, V) — exportação JSON do titular.
class ExportMyDataService {
  ExportMyDataService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<Map<String, dynamic>> buildExportPayload(String userId) async {
    final info = await PackageInfo.fromPlatform();
    final exportedAt = DateTime.now().toUtc().toIso8601String();

    final userDoc = await _db.collection(FirestorePaths.users).doc(userId).get();
    final profileDoc = await _db
        .collection(FirestorePaths.users)
        .doc(userId)
        .collection(FirestorePaths.userPublicProfile)
        .doc(FirestorePaths.userPublicProfileDocId)
        .get();

    final progresso = await _collectionMaps(userId, FirestorePaths.userProgressSubcollection);
    final progressoQuestoes =
        await _collectionMaps(userId, FirestorePaths.userProgressoQuestoesSubcollection);
    final simulados =
        await _collectionMaps(userId, FirestorePaths.userSimuladosHistoricoSubcollection);
    final cronogramaMeta = await _db
        .collection(FirestorePaths.users)
        .doc(userId)
        .collection('cronograma_meta')
        .get();
    final cronogramaItens = await _db
        .collection(FirestorePaths.users)
        .doc(userId)
        .collection('cronograma_itens')
        .get();
    final entitlements = await _collectionMaps(
      userId,
      FirestorePaths.userPlatformEntitlements,
    );
    final legalAcceptances =
        await _collectionMaps(userId, FirestorePaths.legalAcceptances);

    final subscriptions = await _queryPlatform(
      FirestorePaths.platformSubscriptions,
      'userId',
      userId,
    );
    final payments = await _queryPlatform(
      FirestorePaths.platformPayments,
      'userId',
      userId,
    );

    final osceAsEvaluator = await _db
        .collection(FirestorePaths.osceEvaluations)
        .where('evaluatorId', isEqualTo: userId)
        .limit(200)
        .get();
    final osceAsEvaluated = await _db
        .collection(FirestorePaths.osceEvaluations)
        .where('evaluatedUserId', isEqualTo: userId)
        .limit(200)
        .get();

    return {
      'exportVersion': '1',
      'exportedAt': exportedAt,
      'appVersion': '${info.version}+${info.buildNumber}',
      'legalVersions': {
        'policy': LegalVersions.policyVersion,
        'terms': LegalVersions.termsVersion,
      },
      'userId': userId,
      'profile': userDoc.data(),
      'publicProfile': profileDoc.data(),
      'progresso': progresso,
      'progressoQuestoes': progressoQuestoes,
      'simuladosHistorico': simulados,
      'cronograma': {
        'meta': cronogramaMeta.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
        'itens': cronogramaItens.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
      },
      'platformEntitlements': entitlements,
      'subscriptions': subscriptions,
      'payments': payments,
      'osce': {
        'asEvaluator': osceAsEvaluator.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList(),
        'asEvaluated': osceAsEvaluated.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList(),
      },
      'legalAcceptances': legalAcceptances,
    };
  }

  Future<void> exportAndShare(String userId) async {
    final payload = await buildExportPayload(userId);
    final json = const JsonEncoder.withIndent('  ').convert(payload);
    final bytes = utf8.encode(json);

    if (kIsWeb) {
      await SharePlus.instance.share(
        ShareParams(text: json, subject: 'meus_dados_trilhamed.json'),
      );
      return;
    }

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/trilhamed_dados_${userId.substring(0, 8)}.json',
    );
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: 'Exportação dos meus dados',
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _collectionMaps(
    String userId,
    String sub,
  ) async {
    final snap = await _db
        .collection(FirestorePaths.users)
        .doc(userId)
        .collection(sub)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<List<Map<String, dynamic>>> _queryPlatform(
    String collection,
    String field,
    String userId,
  ) async {
    try {
      final snap = await _db
          .collection(collection)
          .where(field, isEqualTo: userId)
          .limit(100)
          .get();
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (e) {
      debugPrint('[ExportMyData] $collection: $e');
      return [];
    }
  }
}
