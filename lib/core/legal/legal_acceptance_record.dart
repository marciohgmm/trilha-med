import 'package:cloud_firestore/cloud_firestore.dart';

import 'legal_versions.dart';

/// Registro em `users/{uid}/legal_acceptances/{id}`.
class LegalAcceptanceRecord {
  final String id;
  final DateTime acceptedAt;
  final String policyVersion;
  final String termsVersion;
  final String? ipHash;
  final String platform;
  final String appVersion;

  const LegalAcceptanceRecord({
    required this.id,
    required this.acceptedAt,
    required this.policyVersion,
    required this.termsVersion,
    this.ipHash,
    required this.platform,
    required this.appVersion,
  });

  factory LegalAcceptanceRecord.fromDoc(String id, Map<String, dynamic> data) {
    final ts = data['acceptedAt'];
    DateTime at;
    if (ts is Timestamp) {
      at = ts.toDate();
    } else if (ts is DateTime) {
      at = ts;
    } else {
      at = DateTime.now();
    }
    return LegalAcceptanceRecord(
      id: id,
      acceptedAt: at,
      policyVersion: data['policyVersion']?.toString() ?? '',
      termsVersion: data['termsVersion']?.toString() ?? '',
      ipHash: data['ipHash']?.toString(),
      platform: data['platform']?.toString() ?? 'unknown',
      appVersion: data['appVersion']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'acceptedAt': FieldValue.serverTimestamp(),
        'policyVersion': policyVersion,
        'termsVersion': termsVersion,
        if (ipHash != null && ipHash!.isNotEmpty) 'ipHash': ipHash,
        'platform': platform,
        'appVersion': appVersion,
      };

  bool coversCurrentVersions() =>
      policyVersion == LegalVersions.policyVersion &&
      termsVersion == LegalVersions.termsVersion;
}
