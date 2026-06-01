import 'package:flutter_application_1/core/legal/legal_acceptance_record.dart';
import 'package:flutter_application_1/core/legal/legal_versions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LegalVersions', () {
    test('policyVersion e termsVersion definidos', () {
      expect(LegalVersions.policyVersion.isNotEmpty, true);
      expect(LegalVersions.termsVersion.isNotEmpty, true);
    });
  });

  group('LegalAcceptanceRecord', () {
    test('coversCurrentVersions true quando versões iguais', () {
      final record = LegalAcceptanceRecord(
        id: '1',
        acceptedAt: DateTime.now(),
        policyVersion: LegalVersions.policyVersion,
        termsVersion: LegalVersions.termsVersion,
        platform: 'test',
        appVersion: '1.0.0',
      );
      expect(record.coversCurrentVersions(), true);
    });

    test('coversCurrentVersions false quando política desatualizada', () {
      final record = LegalAcceptanceRecord(
        id: '1',
        acceptedAt: DateTime.now(),
        policyVersion: '2000-01-01',
        termsVersion: LegalVersions.termsVersion,
        platform: 'test',
        appVersion: '1.0.0',
      );
      expect(record.coversCurrentVersions(), false);
    });
  });

  group('requiredLegalAcceptance (lógica)', () {
    test('sem aceite equivale a bloqueio', () {
      bool requiresAcceptance(LegalAcceptanceRecord? latest) {
        if (latest == null) return true;
        return !latest.coversCurrentVersions();
      }

      expect(requiresAcceptance(null), true);
    });

    test('aceite atual libera acesso', () {
      final latest = LegalAcceptanceRecord(
        id: '1',
        acceptedAt: DateTime.now(),
        policyVersion: LegalVersions.policyVersion,
        termsVersion: LegalVersions.termsVersion,
        platform: 'test',
        appVersion: '1.0.0',
      );
      final needs = !latest.coversCurrentVersions();
      expect(needs, false);
    });
  });
}
