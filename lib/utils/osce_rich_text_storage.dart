import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../widgets/osce/osce_admin_rich_field.dart';

/// Normaliza conteúdo Quill vazio ou só com quebra de linha para string vazia.
String normalizeOsceRichStorage(String? raw) {
  final v = raw?.trim() ?? '';
  if (v.isEmpty) return '';

  if (OsceAdminRichField.looksLikeDeltaJson(v)) {
    try {
      final decoded = jsonDecode(v);
      if (decoded is List) {
        final plain =
            quill.Document.fromJson(decoded).toPlainText().trim();
        if (plain.isEmpty) return '';
      }
    } catch (_) {
      return v;
    }
  }

  return v;
}
