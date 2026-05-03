import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

class BiometriaService {
  final LocalAuthentication _autenticador = LocalAuthentication();

  Future<bool> dispositivoSuportaBiometria() async {
    try {
      final canCheckBiometrics = await _autenticador.canCheckBiometrics;
      final deviceSupported = await _autenticador.isDeviceSupported();

      final suporta = canCheckBiometrics || deviceSupported;

      if (!suporta) {
        debugPrint(
          '[BiometriaService] Dispositivo não suporta biometria segura: '
          'canCheckBiometrics=$canCheckBiometrics, isDeviceSupported=$deviceSupported',
        );
      }

      return suporta;
    } catch (e, stackTrace) {
      debugPrint('[BiometriaService] Erro verificando suporte a biometria: $e');
      debugPrint(stackTrace.toString());
      return false;
    }
  }

  Future<bool> autenticarComBiometria() async {
    try {
      final suporta = await dispositivoSuportaBiometria();
      if (!suporta) {
        debugPrint('[BiometriaService] Autenticação cancelada: dispositivo sem suporte.');
        return false;
      }

      final autenticado = await _autenticador.authenticate(
        localizedReason: 'Use sua biometria ou método do dispositivo para continuar',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      return autenticado;
    } catch (e, stackTrace) {
      debugPrint('[BiometriaService] Falha na autenticação: $e');
      debugPrint(stackTrace.toString());
      return false;
    }
  }
}
