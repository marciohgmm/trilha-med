/// Chaves e rótulos do script do avaliador (checklist OSCE).
class OsceScriptFields {
  OsceScriptFields._();

  static const fieldDefs = <({String key, String label})>[
    (key: 'dados_pessoais', label: 'Dados pessoais'),
    (key: 'motivo_consulta', label: 'Motivo da consulta'),
    (key: 'sintomas', label: 'Sintomas'),
    (key: 'habitos_alimentares', label: 'Hábitos alimentares'),
    (key: 'antecedentes_pessoais', label: 'Antecedentes pessoais'),
    (key: 'antecedentes_familiares', label: 'Antecedentes familiares'),
    (key: 'duvidas', label: 'Dúvidas do paciente'),
    (key: 'respostas_permitidas', label: 'Respostas permitidas'),
  ];

  /// Migração de casos antigos no Firestore.
  static const legacyKeyMap = <String, String>{
    'sobre_dor': 'sintomas',
    'emagrecimento': 'habitos_alimentares',
    'antecedentes': 'antecedentes_pessoais',
  };

  static String labelForKey(String key) {
    for (final f in fieldDefs) {
      if (f.key == key) return f.label;
    }
    return key.replaceAll('_', ' ');
  }

  static Map<String, String> normalizeScript(Map<String, String> raw) {
    final out = <String, String>{};
    for (final f in fieldDefs) {
      var v = raw[f.key]?.trim() ?? '';
      if (v.isEmpty) {
        for (final e in legacyKeyMap.entries) {
          if (e.value == f.key) {
            final legacy = raw[e.key]?.trim() ?? '';
            if (legacy.isNotEmpty) v = legacy;
          }
        }
      }
      out[f.key] = v;
    }
    return out;
  }

  static Map<String, String> titlesMap() {
    return {for (final f in fieldDefs) f.key: f.label};
  }
}
