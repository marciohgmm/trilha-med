import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

class BiometriaService {
  final LocalAuthentication _autenticador = LocalAuthentication();

  Future<bool> dispositivoSuportaBiometria() async {
    try {
      final canCheckBiometrics = await _autenticador.canCheckBiometrics;
      final deviceSupported = await _autenticador.isDeviceSupported();
      final availableBiometrics = await _autenticador.getAvailableBiometrics();

      final suporta = availableBiometrics.isNotEmpty || deviceSupported;

      debugPrint(
        '[BiometriaService] Suporte a biometria: '
        'canCheckBiometrics=$canCheckBiometrics, '
        'isDeviceSupported=$deviceSupported, '
        'availableBiometrics=$availableBiometrics, '
        'suporta=$suporta',
      );

      return suporta;
    } catch (e, stackTrace) {
      debugPrint('[BiometriaService] Erro verificando suporte a biometria: $e');
      debugPrint(stackTrace.toString());
      return false;
    }
  }

  Future<bool> autenticarComBiometria() async {
    try {
      final availableBiometrics = await _autenticador.getAvailableBiometrics();
      final deviceSupported = await _autenticador.isDeviceSupported();
      final suporta = availableBiometrics.isNotEmpty || deviceSupported;

      if (!suporta) {
        debugPrint('[BiometriaService] Autenticação cancelada: dispositivo sem suporte.');
        return false;
      }

      final autenticado = await _autenticador.authenticate(
        localizedReason:
            'Use sua biometria ou método do dispositivo para continuar',
        biometricOnly: availableBiometrics.isNotEmpty,
        persistAcrossBackgrounding: false,
        sensitiveTransaction: true,
      );

      return autenticado;
    } catch (e, stackTrace) {
      debugPrint('[BiometriaService] Falha na autenticação: $e');
      debugPrint(stackTrace.toString());
      return false;
    }
  }
}
