import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

class BiometriaService {
  final LocalAuthentication _autenticador = LocalAuthentication();

  Future<bool> dispositivoSuportaBiometria() async {
    try {
      final deviceSupported = await _autenticador.isDeviceSupported();
      if (!deviceSupported) return false;

      final canCheck = await _autenticador.canCheckBiometrics;
      final available = await _autenticador.getAvailableBiometrics();

      // Em muitos aparelhos PIN/padrão conta como "device credential".
      return canCheck || available.isNotEmpty || deviceSupported;
    } catch (e, stackTrace) {
      debugPrint('[BiometriaService] Erro verificando suporte: $e');
      debugPrint(stackTrace.toString());
      return false;
    }
  }

  Future<bool> autenticarComBiometria() async {
    try {
      final deviceSupported = await _autenticador.isDeviceSupported();
      if (!deviceSupported) {
        debugPrint('[BiometriaService] Dispositivo sem autenticação local.');
        return false;
      }

      return await _autenticador.authenticate(
        localizedReason:
            'Confirme sua identidade para entrar no Trilha Med',
        biometricOnly: false,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException catch (e) {
      debugPrint('[BiometriaService] LocalAuthException: ${e.code}');
      return false;
    } catch (e, stackTrace) {
      debugPrint('[BiometriaService] Falha na autenticação: $e');
      debugPrint(stackTrace.toString());
      return false;
    }
  }
}
