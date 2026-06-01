import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Pré-check de rate limit antes de enviar e-mail de recuperação de senha.
/// Não altera telas — apenas evita abuso antes do SDK Auth.
class AuthRateLimitService {
  AuthRateLimitService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'southamerica-east1');

  final FirebaseFunctions _functions;

  Future<void> assertPasswordResetAllowed(String email) async {
    try {
      await _functions.httpsCallable('rateLimitPasswordReset').call({
        'email': email.trim(),
      });
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') {
        throw FirebaseAuthException(
          code: 'too-many-requests',
          message: e.message ??
              'Muitas tentativas. Aguarde alguns minutos e tente novamente.',
        );
      }
      rethrow;
    }
  }
}
