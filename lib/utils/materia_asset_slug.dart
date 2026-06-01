/// Pastas conhecidas em `assets/images/` (minúsculas, snake_case).
const Set<String> kMateriaAssetFolders = {
  'pediatria',
  'ginecologia',
  'cardiologia',
  'clinica_medica',
};

/// Converte nome de matéria (Firestore) para pasta de assets.
String materiaToAssetFolder(String materia) {
  final raw = materia.trim().toLowerCase();
  if (raw.isEmpty) return 'pediatria';

  final noAccent = _stripDiacritics(raw);
  final compact = noAccent.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  final collapsed =
      compact.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');

  if (collapsed == 'clinica_medica' ||
      compact.contains('clinica') && compact.contains('medica')) {
    return 'clinica_medica';
  }
  if (kMateriaAssetFolders.contains(collapsed)) return collapsed;

  if (collapsed.contains('pediatr')) return 'pediatria';
  if (collapsed.contains('ginecolog')) return 'ginecologia';
  if (collapsed.contains('cardiolog') || collapsed == 'cardiologia') {
    return 'cardiologia';
  }

  return collapsed.isEmpty ? 'pediatria' : collapsed;
}

String _stripDiacritics(String input) {
  const map = {
    'á': 'a',
    'à': 'a',
    'ã': 'a',
    'â': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'õ': 'o',
    'ô': 'o',
    'ö': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
    'ñ': 'n',
  };
  final buf = StringBuffer();
  for (var i = 0; i < input.length; i++) {
    final ch = input[i];
    final lower = ch.toLowerCase();
    buf.write(map[ch] ?? map[lower] ?? ch);
  }
  return buf.toString();
}

/// Resolve referência `[img:arquivo.webp]` para caminho de asset.
/// [ref] pode ser só o arquivo ou caminho completo `assets/images/...`.
String resolveFlashcardAssetPath(String materia, String ref) {
  final r = ref.trim();
  if (r.startsWith('assets/images/')) return r;
  final folder = materiaToAssetFolder(materia);
  final file = r.replaceAll(RegExp(r'^/+'), '');
  return 'assets/images/$folder/$file';
}
