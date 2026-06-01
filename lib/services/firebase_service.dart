import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/services/flashcard_materia_stats_service.dart';
import 'package:flutter_application_1/services/flashcard_subtema_catalog_service.dart';
import 'package:flutter_application_1/utils/content_hierarchy_utils.dart';
import 'package:flutter_application_1/utils/image_helper.dart';
import 'package:http/http.dart' as http;
import 'package:universal_html/html.dart' as html;

/// Serviço que abstrai todas as operações de cards e arquivos.
class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FlashcardMateriaStatsService _materiaStats =
      FlashcardMateriaStatsService.instance;
  final FlashcardSubtemaCatalogService _subtemaCatalog =
      FlashcardSubtemaCatalogService.instance;

  Future<void> _debugLog({
    required String hypothesisId,
    required String location,
    required String message,
    required Map<String, dynamic> data,
    String runId = 'pre-fix',
  }) async {
    final payload = {
      'sessionId': 'f07c83',
      'runId': runId,
      'hypothesisId': hypothesisId,
      'location': location,
      'message': message,
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    if (kIsWeb) {
      try {
        await http.post(
          Uri.parse(
            'http://127.0.0.1:7463/ingest/d9685535-6979-4ca8-bff0-c9a30618c2c4',
          ),
          headers: {
            'Content-Type': 'application/json',
            'X-Debug-Session-Id': 'f07c83',
          },
          body: jsonEncode(payload),
        );
      } catch (_) {}
      return;
    }

    try {
      await File(
        'debug-f07c83.log',
      ).writeAsString('${jsonEncode(payload)}\n', mode: FileMode.append);
    } catch (_) {}
  }

  int _parseOrdemEstudo(dynamic raw) {
    if (raw == null) return 0;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString()) ?? 0;
  }

  /// Próximo [ordemEstudo] para o par matéria/subtema (max existente + 1).
  Future<int> _proximaOrdemEstudoParaSubtema(
    String materia,
    String subtema,
  ) async {
    final snap = await _db
        .collection('flashcards')
        .where('materia', isEqualTo: materia)
        .where('subtema', isEqualTo: subtema)
        .get();
    var max = 0;
    for (final doc in snap.docs) {
      final n = _parseOrdemEstudo(doc.data()['ordemEstudo']);
      if (n > max) max = n;
    }
    return max + 1;
  }

  Set<String> _gerarSearchTerms(List<String> textos) {
    final termos = <String>{};

    String normalizar(String texto) {
      return texto
          .toLowerCase()
          .trim()
          .replaceAll('á', 'a')
          .replaceAll('à', 'a')
          .replaceAll('ã', 'a')
          .replaceAll('â', 'a')
          .replaceAll('é', 'e')
          .replaceAll('ê', 'e')
          .replaceAll('í', 'i')
          .replaceAll('ó', 'o')
          .replaceAll('ô', 'o')
          .replaceAll('õ', 'o')
          .replaceAll('ú', 'u')
          .replaceAll('ç', 'c');
    }

    for (final textoOriginal in textos) {
      final texto = normalizar(textoOriginal);

      if (texto.isEmpty) continue;

      final palavras = texto.split(RegExp(r'\s+'));

      for (final palavra in palavras) {
        final limpa = palavra.replaceAll(RegExp(r'[^a-z0-9]'), '');
        if (limpa.isEmpty) continue;

        for (int i = 1; i <= limpa.length; i++) {
          termos.add(limpa.substring(0, i));
        }
      }
    }

    return termos;
  }

  // ========================================================================
  // FLASHCARDS: CRUD
  // ========================================================================

  /// Cria um novo flashcard (imagens locais: só nome do arquivo em [imagem*Local]).
  Future<void> adicionarCard({
    required String materia,
    required String subtema,
    required String pergunta,
    required String resposta,
    String? explicacao,
    String? imagemPerguntaLocal,
    String? imagemRespostaLocal,
    String? imagemExplicacaoLocal,
    String dificuldade = "medio",
  }) async {
    try {
      final imgP = imagemPerguntaLocal?.trim() ?? '';
      final imgR = imagemRespostaLocal?.trim() ?? '';
      final imgE = imagemExplicacaoLocal?.trim() ?? '';
      // #region agent log
      await _debugLog(
        hypothesisId: 'H4',
        location: 'firebase_service.dart:72',
        message: 'adicionarCard:start',
        data: {
          'materia': materia,
          'subtema': subtema,
          'perguntaLen': pergunta.length,
          'respostaLen': resposta.length,
          'imagemPerguntaLocalLen': imgP.length,
        },
      );
      // #endregion
      final docRef = _db.collection('flashcards').doc();

      final searchTerms = _gerarSearchTerms([
        materia,
        subtema,
        pergunta,
        resposta,
        explicacao ?? '',
      ]);

      final ordemEstudo =
          await _proximaOrdemEstudoParaSubtema(materia, subtema);

      await docRef.set({
        'id': docRef.id,
        'materia': materia,
        'tema': '',
        'subtema': subtema,
        'pergunta': pergunta,
        'resposta': resposta,
        'explicacao': explicacao ?? '',
        'imagemPerguntaLocal': imgP,
        'imagemRespostaLocal': imgR,
        'imagemExplicacaoLocal': imgE,
        'dificuldade': dificuldade,
        'ordemEstudo': ordemEstudo,
        'searchTerms': searchTerms.toList(),
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
      await _materiaStats.incrementMateria(materia);
      await _subtemaCatalog.registerCard(materia, subtema);
      // #region agent log
      await _debugLog(
        hypothesisId: 'H4',
        location: 'firebase_service.dart:118',
        message: 'adicionarCard:success',
        data: {'docId': docRef.id},
      );
      // #endregion
    } catch (e) {
      // #region agent log
      await _debugLog(
        hypothesisId: 'H4',
        location: 'firebase_service.dart:119',
        message: 'adicionarCard:error',
        data: {'error': e.toString()},
      );
      // #endregion
      rethrow;
    }
  }

  /// Atribui [ordemEstudo] = 1..n na ordem visual desejada (mesmo subtema).
  Future<void> reordenarFlashcardsNoSubtema({
    required String materia,
    required String subtema,
    required List<String> orderedCardIds,
  }) async {
    if (orderedCardIds.isEmpty) return;
    const chunk = 400;
    for (var i = 0; i < orderedCardIds.length; i += chunk) {
      final batch = _db.batch();
      final end = i + chunk > orderedCardIds.length ? orderedCardIds.length : i + chunk;
      for (var j = i; j < end; j++) {
        final id = orderedCardIds[j];
        batch.update(_db.collection('flashcards').doc(id), {
          'ordemEstudo': j + 1,
          'updatedAt': Timestamp.now(),
        });
      }
      await batch.commit();
    }
  }

  /// Atualiza um flashcard já existente.
  Future<void> atualizarCard({
    required String cardId,
    required String materia,
    required String subtema,
    required String pergunta,
    required String resposta,
    String? explicacao,
    String? imagemPerguntaLocal,
    String? imagemRespostaLocal,
    String? imagemExplicacaoLocal,
    String dificuldade = "medio",
  }) async {
    try {
      final imgP = imagemPerguntaLocal?.trim() ?? '';
      final imgR = imagemRespostaLocal?.trim() ?? '';
      final imgE = imagemExplicacaoLocal?.trim() ?? '';

      final searchTerms = _gerarSearchTerms([
        materia,
        subtema,
        pergunta,
        resposta,
        explicacao ?? '',
      ]);

      final snap = await _db.collection('flashcards').doc(cardId).get();
      final oldM = (snap.data()?['materia'] ?? '').toString().trim();
      final oldS = (snap.data()?['subtema'] ?? '').toString().trim();

      await _db.collection('flashcards').doc(cardId).update({
        'materia': materia,
        'tema': '',
        'subtema': subtema,
        'pergunta': pergunta,
        'resposta': resposta,
        'explicacao': explicacao ?? '',
        'imagemPerguntaLocal': imgP,
        'imagemRespostaLocal': imgR,
        'imagemExplicacaoLocal': imgE,
        'dificuldade': dificuldade,
        'searchTerms': searchTerms.toList(),
        'updatedAt': Timestamp.now(),
      });
      if (oldM != materia.trim() || oldS != subtema.trim()) {
        if (oldM.isNotEmpty && oldS.isNotEmpty) {
          await _subtemaCatalog.unregisterCard(oldM, oldS);
        }
        await _subtemaCatalog.registerCard(materia, subtema);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Exclui um card no Firestore (imagens ficam nos assets do app).
  Future<void> excluirCard(String cardId) async {
    try {
      final ref = _db.collection('flashcards').doc(cardId);
      final snap = await ref.get();
      final materia = (snap.data()?['materia'] ?? '').toString().trim();
      final subtema = (snap.data()?['subtema'] ?? '').toString().trim();
      await ref.delete();
      if (materia.isNotEmpty) {
        await _materiaStats.decrementMateria(materia);
      }
      if (materia.isNotEmpty && subtema.isNotEmpty) {
        await _subtemaCatalog.unregisterCard(materia, subtema);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Exclui vários cards em lote (sem tratar imagens por enquanto).
  Future<void> excluirCardsEmLote(List<String> cardIds) async {
    try {
      if (cardIds.isEmpty) return;
      final counts = <String, int>{};
      final pairCounts = <String, ({String materia, String subtema, int count})>{};
      final refs = <DocumentReference<Map<String, dynamic>>>[];
      for (final id in cardIds) {
        final ref = _db.collection('flashcards').doc(id);
        refs.add(ref);
        final snap = await ref.get();
        final m = (snap.data()?['materia'] ?? '').toString().trim();
        final s = (snap.data()?['subtema'] ?? '').toString().trim();
        if (m.isNotEmpty) {
          counts[m] = (counts[m] ?? 0) + 1;
        }
        if (m.isNotEmpty && s.isNotEmpty) {
          final key = ContentHierarchyUtils.subtemaPairKey(m, s);
          final prev = pairCounts[key];
          if (prev == null) {
            pairCounts[key] = (materia: m, subtema: s, count: 1);
          } else {
            pairCounts[key] = (
              materia: prev.materia,
              subtema: prev.subtema,
              count: prev.count + 1,
            );
          }
        }
      }
      await _commitDeletesEmLotes(refs);
      for (final e in counts.entries) {
        await _materiaStats.decrementMateria(e.key, by: e.value);
      }
      for (final e in pairCounts.values) {
        await _subtemaCatalog.unregisterCard(
          e.materia,
          e.subtema,
          by: e.count,
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Firestore aceita no máximo 500 operações por batch; acima disso o commit falha (ex.: `invalid-argument`).
  Future<void> _commitDeletesEmLotes(
    List<DocumentReference<Map<String, dynamic>>> refs,
  ) async {
    if (refs.isEmpty) return;
    const chunk = 450;
    for (var i = 0; i < refs.length; i += chunk) {
      final batch = _db.batch();
      final end = i + chunk > refs.length ? refs.length : i + chunk;
      for (var j = i; j < end; j++) {
        batch.delete(refs[j]);
      }
      await batch.commit();
    }
  }

  /// Remove flashcards que batem no filtro (matéria obrigatória; subtema opcional).
  Future<int> excluirFlashcardsPorFiltro({
    required String materia,
    String? subtema,
  }) async {
    Query<Map<String, dynamic>> q =
        _db.collection('flashcards').where('materia', isEqualTo: materia);
    if (subtema != null && subtema.isNotEmpty) {
      q = q.where('subtema', isEqualTo: subtema);
    }

    final snap = await q.get();
    if (snap.docs.isEmpty) return 0;

    final pairCounts = <String, ({String materia, String subtema, int count})>{};
    for (final doc in snap.docs) {
      final m = (doc.data()['materia'] ?? '').toString().trim();
      final s = (doc.data()['subtema'] ?? '').toString().trim();
      if (m.isEmpty || s.isEmpty) continue;
      final key = ContentHierarchyUtils.subtemaPairKey(m, s);
      final prev = pairCounts[key];
      if (prev == null) {
        pairCounts[key] = (materia: m, subtema: s, count: 1);
      } else {
        pairCounts[key] = (
          materia: prev.materia,
          subtema: prev.subtema,
          count: prev.count + 1,
        );
      }
    }

    await _commitDeletesEmLotes(snap.docs.map((d) => d.reference).toList());
    await _materiaStats.decrementMateria(materia, by: snap.docs.length);
    for (final e in pairCounts.values) {
      await _subtemaCatalog.unregisterCard(
        e.materia,
        e.subtema,
        by: e.count,
      );
    }
    return snap.docs.length;
  }

  // ========================================================================
  // LISTAGEM E EXPORTAÇÃO
  // ========================================================================

  /// Stream contínuo de cards ordenados por data de criação decrescente.
  Stream<QuerySnapshot> listarCardsStream() {
    return _db
        .collection('flashcards')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Lista todos os cards para exportar em JSON (sem paginar).
  Future<List<Map<String, dynamic>>> listarCardsParaExportacao() async {
    final snapshot = await _db
        .collection('flashcards')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': data['id'] ?? doc.id,
        'materia': data['materia'] ?? '',
        'tema': data['tema'] ?? '',
        'subtema': data['subtema'] ?? '',
        'pergunta': data['pergunta'] ?? '',
        'resposta': data['resposta'] ?? '',
        'explicacao': data['explicacao'] ?? '',
        'imagemPerguntaLocal': data['imagemPerguntaLocal'] ?? '',
        'imagemRespostaLocal': data['imagemRespostaLocal'] ?? '',
        'imagemExplicacaoLocal': data['imagemExplicacaoLocal'] ?? '',
        'dificuldade': data['dificuldade'] ?? 'medio',
        'createdAt': data['createdAt'] is Timestamp
            ? (data['createdAt'] as Timestamp).toDate().toIso8601String()
            : '',
        'updatedAt': data['updatedAt'] is Timestamp
            ? (data['updatedAt'] as Timestamp).toDate().toIso8601String()
            : '',
      };
    }).toList();
  }

  /// Exporta todos os cards para um arquivo JSON e oferece para download (Web).
  Future<void> exportarCardsJson() async {
    try {
      final cards = await listarCardsParaExportacao();
      final jsonString = const JsonEncoder.withIndent('  ').convert(cards);
      final bytes = utf8.encode(jsonString);
      final nomeArquivo =
          'flashcards_export_${DateTime.now().millisecondsSinceEpoch}.json';

      final blob = html.Blob([bytes], 'application/json');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', nomeArquivo)
        ..click();

      html.Url.revokeObjectUrl(url);
    } catch (e) {
      rethrow;
    }
  }

  /// Importa cards de um arquivo JSON (dosados, evitando dados inválidos).
  Future<int> importarCardsJson() async {
    try {
      final resultado = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (resultado == null || resultado.files.isEmpty) {
        return 0;
      }

      final arquivo = resultado.files.first;
      String conteudo = '';

      if (arquivo.bytes != null) {
        conteudo = utf8.decode(arquivo.bytes!);
      } else if (arquivo.path != null) {
        conteudo = await File(arquivo.path!).readAsString();
      }

      if (conteudo.trim().isEmpty) return 0;

      final dynamic jsonDecodificado = jsonDecode(conteudo);

      if (jsonDecodificado is! List) {
        throw Exception('O JSON precisa ser uma lista de flashcards.');
      }

      int importados = 0;

      for (final item in jsonDecodificado) {
        if (item is! Map<String, dynamic>) continue;

        final materia = (item['materia'] ?? '').toString().trim();
        final subtema = (item['subtema'] ?? '').toString().trim();
        final pergunta = (item['pergunta'] ?? '').toString().trim();
        final resposta = (item['resposta'] ?? '').toString().trim();
        final explicacao = (item['explicacao'] ?? '').toString().trim();
        var imagemPerguntaLocal = flashcardMigrateImageFieldToStorageRef(
          (item['imagemPerguntaLocal'] ?? '').toString(),
        );
        var imagemRespostaLocal = flashcardMigrateImageFieldToStorageRef(
          (item['imagemRespostaLocal'] ?? '').toString(),
        );
        var imagemExplicacaoLocal = flashcardMigrateImageFieldToStorageRef(
          (item['imagemExplicacaoLocal'] ?? '').toString(),
        );
        if (imagemPerguntaLocal.isEmpty) {
          final legado = (item['imagemLocal'] ?? '').toString().trim();
          if (legado.isNotEmpty &&
              !legado.contains('..') &&
              !legado.toLowerCase().startsWith('http')) {
            imagemPerguntaLocal =
                flashcardMigrateImageFieldToStorageRef(legado);
          }
        }
        final dificuldade = (item['dificuldade'] ?? 'medio').toString().trim();

        if (materia.isEmpty ||
            subtema.isEmpty ||
            pergunta.isEmpty ||
            resposta.isEmpty) {
          continue;
        }

        final docRef = _db.collection('flashcards').doc();

        final searchTerms = _gerarSearchTerms([
          materia,
          subtema,
          pergunta,
          resposta,
          explicacao,
        ]);

        final ordemEstudo =
            await _proximaOrdemEstudoParaSubtema(materia, subtema);

        await docRef.set({
          'id': docRef.id,
          'materia': materia,
          'tema': '',
          'subtema': subtema,
          'pergunta': pergunta,
          'resposta': resposta,
          'explicacao': explicacao,
          'imagemPerguntaLocal': imagemPerguntaLocal,
          'imagemRespostaLocal': imagemRespostaLocal,
          'imagemExplicacaoLocal': imagemExplicacaoLocal,
          'dificuldade': dificuldade.isEmpty ? 'medio' : dificuldade,
          'ordemEstudo': ordemEstudo,
          'searchTerms': searchTerms.toList(),
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        });

        importados++;
      }

      if (importados > 0) {
        await _materiaStats.rebuildFromFlashcards();
        await _subtemaCatalog.rebuildFromFlashcards();
      }

      return importados;
    } catch (e) {
      rethrow;
    }
  }
}
