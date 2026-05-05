import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CredenciaisSalvasService {
  static const _kEmailKey = 'saved_email';
  static const _kSenhaKey = 'saved_password';
  static const _kSalvarSenhaKey = 'save_password_enabled';

  final FlutterSecureStorage _storage;

  CredenciaisSalvasService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<bool> getSalvarSenhaHabilitado() async {
    final v = await _storage.read(key: _kSalvarSenhaKey);
    return v == '1';
  }

  Future<void> setSalvarSenhaHabilitado(bool enabled) async {
    await _storage.write(key: _kSalvarSenhaKey, value: enabled ? '1' : '0');
    if (!enabled) {
      await apagarCredenciais();
    }
  }

  Future<void> salvarCredenciais({
    required String email,
    required String senha,
  }) async {
    await _storage.write(key: _kEmailKey, value: email);
    await _storage.write(key: _kSenhaKey, value: senha);
  }

  Future<({String? email, String? senha})> lerCredenciais() async {
    final email = await _storage.read(key: _kEmailKey);
    final senha = await _storage.read(key: _kSenhaKey);
    return (email: email, senha: senha);
  }

  Future<void> apagarCredenciais() async {
    await _storage.delete(key: _kEmailKey);
    await _storage.delete(key: _kSenhaKey);
  }
}

