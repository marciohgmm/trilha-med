// F1 — Valida que não há referências funcionais novas à coleção `usuarios`.
//
// Uso: dart run tool/f1_validate_usuarios_refs.dart
//
// Exit 0 = OK; exit 1 = referências proibidas encontradas.

import 'dart:io';

final _allowlistSuffixes = [
  'lib/core/constants/firestore_paths.dart',
  'lib/services/user_progress_migration_service.dart',
  'lib/services/progresso_service.dart',
  'tool/f1_validate_usuarios_refs.dart',
];

void main() {
  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    stderr.writeln('Execute na raiz do projeto Flutter.');
    exit(2);
  }

  final violations = <String>[];

  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;

    final normalized = entity.path.replaceAll('\\', '/');
    if (_allowlistSuffixes.any(normalized.endsWith)) continue;

    final content = entity.readAsStringSync();
    final indices = <int>[
      ..._allIndexesOf(content, "'usuarios'"),
      ..._allIndexesOf(content, '"usuarios"'),
    ]..sort();
    for (final index in indices) {
      final line = _lineNumber(content, index);
      violations.add('$normalized:$line');
    }
  }

  if (violations.isEmpty) {
    stdout.writeln(
      'F1 OK: nenhuma referência a "usuarios" fora da allowlist em lib/.',
    );
    exit(0);
  }

  stderr.writeln('F1 FALHOU: referências a coleção legada usuarios:');
  for (final v in violations) {
    stderr.writeln('  - $v');
  }
  stderr.writeln(
    '\nAllowlist: firestore_paths, user_progress_migration_service, '
    'progresso_service (@Deprecated), este script.',
  );
  exit(1);
}

int _lineNumber(String content, int offset) {
  var line = 1;
  for (var i = 0; i < offset && i < content.length; i++) {
    if (content.codeUnitAt(i) == 10) line++;
  }
  return line;
}

Iterable<int> _allIndexesOf(String content, String needle) sync* {
  if (needle.isEmpty) return;
  var start = 0;
  while (true) {
    final index = content.indexOf(needle, start);
    if (index < 0) return;
    yield index;
    start = index + needle.length;
  }
}
