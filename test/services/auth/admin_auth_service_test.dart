import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/auth/admin_auth_service.dart';

void main() {
  group('AdminAuthService', () {
    test('isFounderEmail reconhece email do criador', () {
      expect(
        AdminAuthService.isFounderEmail('marciohgmm@gmail.com'),
        isTrue,
      );
      expect(
        AdminAuthService.isFounderEmail('  MarcioHGMM@gmail.com  '),
        isTrue,
      );
    });

    test('isFounderEmail rejeita outros emails', () {
      expect(AdminAuthService.isFounderEmail('outro@test.com'), isFalse);
      expect(AdminAuthService.isFounderEmail(null), isFalse);
      expect(AdminAuthService.isFounderEmail(''), isFalse);
    });

    test('normalizeEmail lowercases e trim', () {
      expect(
        AdminAuthService.normalizeEmail('  Test@Example.COM '),
        'test@example.com',
      );
    });
  });
}
