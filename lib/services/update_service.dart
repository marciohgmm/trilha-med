import 'dart:convert';
import 'dart:developer' as developer;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

class UpdateService {
  static const String _versionUrl = 'https://jsonkeeper.com/b/NK1O';
  static String currentVersion = '1.0.0';
  static String latestVersion = '0.0.0';

  static Future<bool> temInternet() async {
    final List<ConnectivityResult> connectivityResult =
        await Connectivity().checkConnectivity();

    return connectivityResult.isNotEmpty &&
        !connectivityResult.contains(ConnectivityResult.none);
  }

  static Future<bool> temAtualizacao() async {
    if (!await temInternet()) return false;

    try {
      final response = await http.get(Uri.parse(_versionUrl));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        latestVersion = data['version'].toString();
        return _isNewerVersion(latestVersion, currentVersion);
      }
    } catch (e, s) {
      developer.log(
        'Erro check update: $e',
        name: 'UpdateService',
        stackTrace: s,
      );
    }

    return false;
  }

  static bool _isNewerVersion(String newVer, String oldVer) {
    final newParts = newVer.split('.').map(int.parse).toList();
    final oldParts = oldVer.split('.').map(int.parse).toList();

    for (int i = 0; i < 3; i++) {
      if (newParts[i] > oldParts[i]) return true;
      if (newParts[i] < oldParts[i]) return false;
    }

    return false;
  }
}
