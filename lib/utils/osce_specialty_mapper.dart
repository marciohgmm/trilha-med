/// Mapeia nome de especialidade do caso OSCE → chave em [users.oscePerformance].
class OsceSpecialtyMapper {
  OsceSpecialtyMapper._();

  static const Map<String, String> _displayToKey = {
    'Clínica Médica': 'clinica_medica',
    'Clinica Medica': 'clinica_medica',
    'Clínica Cirúrgica': 'clinica_cirurgica',
    'Clinica Cirurgica': 'clinica_cirurgica',
    'Medicina da Família e Comunidade': 'mfc',
    'Medicina da Familia e Comunidade': 'mfc',
    'Pediatria': 'pediatria',
    'Ginecologia e Obstetrícia': 'go',
    'Ginecologia e Obstetricia': 'go',
    'Emergência': 'clinica_medica',
    'Emergencia': 'clinica_medica',
    'Preventiva': 'mfc',
  };

  static String specialtyToKey(String specialty) {
    final t = specialty.trim();
    if (t.isEmpty) return 'clinica_medica';
    return _displayToKey[t] ??
        _displayToKey.entries
            .firstWhere(
              (e) => e.key.toLowerCase() == t.toLowerCase(),
              orElse: () => const MapEntry('', 'clinica_medica'),
            )
            .value;
  }
}
