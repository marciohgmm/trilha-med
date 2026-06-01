import 'dart:convert';

import 'package:flutter_application_1/utils/image_helper.dart';
import 'package:flutter_application_1/utils/materia_asset_slug.dart';

final RegExp _kImgTag = RegExp(r'\[img:\s*([^\]]+)\]', caseSensitive: false);

/// Normaliza ops vindas do Firestore (List nativa, Map, ou JSON em String).
List<dynamic>? _normalizeOpsList(dynamic raw) {
  if (raw == null) return null;
  if (raw is! List) return null;
  final out = <dynamic>[];
  for (final e in raw) {
    if (e is Map<String, dynamic>) {
      out.add(e);
    } else if (e is Map) {
      out.add(Map<String, dynamic>.from(e));
    }
  }
  return out.isEmpty ? null : out;
}

/// Extrai lista JSON de ops a partir do valor salvo no Firestore.
List<dynamic>? decodeDeltaOps(dynamic valor) {
  if (valor == null) return null;

  if (valor is List) {
    return _normalizeOpsList(valor);
  }
  if (valor is Map) {
    final ops = valor['ops'];
    if (ops is List) return _normalizeOpsList(ops);
  }

  final texto = valor.toString();
  if (texto.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(texto);
    if (decoded is List) return _normalizeOpsList(decoded);
    if (decoded is Map && decoded['ops'] is List) {
      return _normalizeOpsList(decoded['ops']);
    }
  } catch (_) {}
  return null;
}

Map<String, dynamic>? _cloneAttrs(dynamic attrs) {
  if (attrs is Map) {
    return attrs.map((k, v) => MapEntry(k.toString(), v));
  }
  return null;
}

/// Migrado: antes [stripNonOfflineImageEmbeds] removia URLs que não eram `assets/`.
/// Agora normaliza embeds para ref de Storage ou mantém URL `http(s)`.
List<Map<String, dynamic>> migrateFlashcardImageEmbedOps(List<dynamic> ops) {
  final out = <Map<String, dynamic>>[];
  for (final raw in ops) {
    if (raw is! Map) continue;
    final op = Map<String, dynamic>.from(raw);
    final ins = op['insert'];
    if (ins is Map && ins['image'] != null) {
      final url = ins['image'].toString().trim();
      final migrated = flashcardMigrateImageFieldToStorageRef(url);
      if (migrated.isEmpty) {
        out.add({
          'insert':
              '\n(Referência de imagem inválida — envie a imagem para o Firebase Storage em "imagenscard/".)\n',
        });
        continue;
      }
      final insMap = Map<String, dynamic>.from(ins);
      op['insert'] = <String, dynamic>{
        ...insMap,
        'image': migrated,
      };
    }
    out.add(op);
  }
  return out;
}

/// Histórico: removia imagens “online”. Mantido como alias da migração para Storage.
List<Map<String, dynamic>> stripNonOfflineImageEmbeds(List<dynamic> ops) {
  return migrateFlashcardImageEmbedOps(ops);
}

/// Expande trechos `[img:arquivo.webp]` em ops `insert.image` (ref Storage).
List<Map<String, dynamic>> expandImgTagsInDeltaOps(List<dynamic> ops) {
  final out = <Map<String, dynamic>>[];

  for (final raw in ops) {
    if (raw is! Map) continue;
    final op = Map<String, dynamic>.from(raw);
    final insert = op['insert'];
    final attrs = _cloneAttrs(op['attributes']);

    if (insert is String && _kImgTag.hasMatch(insert)) {
      out.addAll(_expandStringInsertWithImgTags(insert, attrs));
    } else {
      out.add(op);
    }
  }

  return out;
}

List<Map<String, dynamic>> _expandStringInsertWithImgTags(
  String text,
  Map<String, dynamic>? attrs,
) {
  final out = <Map<String, dynamic>>[];
  var last = 0;

  for (final m in _kImgTag.allMatches(text)) {
    if (m.start > last) {
      final chunk = text.substring(last, m.start);
      if (chunk.isNotEmpty) {
        out.add({
          'insert': chunk,
          if (attrs != null && attrs.isNotEmpty)
            'attributes': Map<String, dynamic>.from(attrs),
        });
      }
    }
    final inner = m.group(1)?.trim() ?? '';
    final path = flashcardImgTagToStorageRef(inner);
    out.add({
      'insert': <String, dynamic>{'image': path}
    });
    out.add({'insert': '\n'});
    last = m.end;
  }

  if (last < text.length) {
    final tail = text.substring(last);
    if (tail.isNotEmpty) {
      out.add({
        'insert': tail,
        if (attrs != null && attrs.isNotEmpty)
          'attributes': Map<String, dynamic>.from(attrs),
      });
    }
  }

  if (out.isEmpty && text.isNotEmpty) {
    out.add({
      'insert': text,
      if (attrs != null && attrs.isNotEmpty)
        'attributes': Map<String, dynamic>.from(attrs),
    });
  }

  return out;
}

/// Resolve refs `imagenscard/...` para URL de download antes do [Document.fromJson].
Future<List<Map<String, dynamic>>> resolveFlashcardDeltaImageUrls(
  List<Map<String, dynamic>> ops,
) async {
  final out = <Map<String, dynamic>>[];
  for (final op in ops) {
    final ins = op['insert'];
    if (ins is Map && ins['image'] != null) {
      final refOrUrl = ins['image'].toString().trim();
      if (refOrUrl.startsWith('http://') || refOrUrl.startsWith('https://')) {
        out.add(op);
        continue;
      }
      try {
        final url = await getFlashcardImageDownloadUrl(refOrUrl);
        final newOp = Map<String, dynamic>.from(op);
        final insMap = Map<String, dynamic>.from(ins);
        newOp['insert'] = <String, dynamic>{...insMap, 'image': url};
        out.add(newOp);
      } catch (_) {
        out.add({
          'insert': '$kFlashcardMissingAssetMessage\n',
        });
      }
    } else {
      out.add(op);
    }
  }
  return out;
}

/// Converte delta JSON (string ou ops) em ops prontos para [Document.fromJson],
/// aplicando tags [img:] e normalizando imagens para Storage.
List<Map<String, dynamic>> prepareDeltaOpsForQuill(
  dynamic valor,
  String materia,
) {
  final ops = decodeDeltaOps(valor);
  if (ops == null || ops.isEmpty) {
    return [
      {
        'insert': '${_plainTextFallback(valor)}\n',
      },
    ];
  }

  final migrated = migrateFlashcardImageEmbedOps(ops);
  final expanded = expandImgTagsInDeltaOps(migrated);
  if (expanded.isEmpty) {
    return [
      {'insert': '\n'}
    ];
  }

  final last = expanded.last;
  final lastInsert = last['insert'];
  if (lastInsert is String && !lastInsert.endsWith('\n')) {
    expanded.add({'insert': '\n'});
  }

  return expanded;
}

String _plainTextFallback(dynamic valor) {
  final ops = decodeDeltaOps(valor);
  if (ops == null) return (valor ?? '').toString();
  final buf = StringBuffer();
  for (final raw in ops) {
    if (raw is Map && raw['insert'] is String) {
      buf.write(raw['insert']);
    }
  }
  final s = buf.toString().replaceAll('\n', ' ').trim();
  return s.isEmpty ? '' : s;
}

/// Lista nomes de arquivo `.webp` em [assets/images/<pasta>/] a partir do manifest.
List<String> listWebpFilenamesForMateria(
  List<String> manifestPaths,
  String materia,
) {
  final folder = materiaToAssetFolder(materia);
  final prefix = 'assets/images/$folder/';
  final names = <String>[];
  for (final p in manifestPaths) {
    if (!p.startsWith(prefix)) continue;
    if (!p.toLowerCase().endsWith('.webp')) continue;
    final name = p.substring(prefix.length);
    if (name.contains('/')) continue;
    names.add(name);
  }
  names.sort();
  return names;
}
