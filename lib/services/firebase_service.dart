import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:universal_html/html.dart' as html;

/// Serviço que abstrai todas as operações de cards e arquivos.
class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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

  /// Cria um novo flashcard, com ou sem imagem.
  Future<void> adicionarCard({
    required String materia,
    required String tema,
    required String subtema,
    required String pergunta,
    required String resposta,
    String? explicacao,
    Uint8List? imagemPergunta,
    Uint8List? imagemResposta,
    String dificuldade = "medio",
  }) async {
    try {
      // #region agent log
      await _debugLog(
        hypothesisId: 'H4',
        location: 'firebase_service.dart:72',
        message: 'adicionarCard:start',
        data: {
          'materia': materia,
          'tema': tema,
          'subtema': subtema,
          'perguntaLen': pergunta.length,
          'respostaLen': resposta.length,
          'hasImagemPergunta': imagemPergunta != null,
          'hasImagemResposta': imagemResposta != null,
        },
      );
      // #endregion
      final docRef = _db.collection('flashcards').doc();

      String? urlPergunta;
      String? urlResposta;

      // Envia imagem da pergunta, se existir (como Uint8List).
      if (imagemPergunta != null) {
        urlPergunta = await uploadImagem(
          imagemPergunta,
          'pergunta_${docRef.id}${p.extension('_imagemPergunta_').isEmpty ? '.jpg' : p.extension('_imagemPergunta_')}',
        );
      }

      // Envia imagem da resposta, se existir (como Uint8List).
      if (imagemResposta != null) {
        urlResposta = await uploadImagem(
          imagemResposta,
          'resposta_${docRef.id}${p.extension('_imagemResposta_').isEmpty ? '.jpg' : p.extension('_imagemResposta_')}',
        );
      }

      final searchTerms = _gerarSearchTerms([
        materia,
        tema,
        subtema,
        pergunta,
        resposta,
        explicacao ?? '',
      ]);

      await docRef.set({
        'id': docRef.id,
        'materia': materia,
        'tema': tema,
        'subtema': subtema,
        'pergunta': pergunta,
        'resposta': resposta,
        'explicacao': explicacao ?? '',
        'imagemPergunta': urlPergunta ?? '',
        'imagemResposta': urlResposta ?? '',
        'dificuldade': dificuldade,
        'searchTerms': searchTerms.toList(),
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
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

  /// Atualiza um flashcard já existente (incluindo substituição de imagens).
  Future<void> atualizarCard({
    required String cardId,
    required String materia,
    required String tema,
    required String subtema,
    required String pergunta,
    required String resposta,
    String? explicacao,
    Uint8List? novaImagemPergunta,
    Uint8List? novaImagemResposta,
    String? imagemPerguntaAtual,
    String? imagemRespostaAtual,
    String dificuldade = "medio",
  }) async {
    try {
      String urlPergunta = imagemPerguntaAtual ?? '';
      String urlResposta = imagemRespostaAtual ?? '';

      if (novaImagemPergunta != null) {
        urlPergunta = (await uploadImagem(
          novaImagemPergunta,
          'pergunta_$cardId${p.extension('_imagemPergunta_').isEmpty ? '.jpg' : p.extension('_imagemPergunta_')}',
        )) ??
            urlPergunta;
      }

      if (novaImagemResposta != null) {
        urlResposta = (await uploadImagem(
          novaImagemResposta,
          'resposta_$cardId${p.extension('_imagemResposta_').isEmpty ? '.jpg' : p.extension('_imagemResposta_')}',
        )) ??
            urlResposta;
      }

      final searchTerms = _gerarSearchTerms([
        materia,
        tema,
        subtema,
        pergunta,
        resposta,
        explicacao ?? '',
      ]);

      await _db.collection('flashcards').doc(cardId).update({
        'materia': materia,
        'tema': tema,
        'subtema': subtema,
        'pergunta': pergunta,
        'resposta': resposta,
        'explicacao': explicacao ?? '',
        'imagemPergunta': urlPergunta,
        'imagemResposta': urlResposta,
        'dificuldade': dificuldade,
        'searchTerms': searchTerms.toList(),
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Exclui um card e suas imagens associadas no Storage.
  Future<void> excluirCard(String cardId) async {
    try {
      final doc = await _db.collection('flashcards').doc(cardId).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;

        final imagemPergunta = (data['imagemPergunta'] ?? '').toString();
        final imagemResposta = (data['imagemResposta'] ?? '').toString();

        if (imagemPergunta.isNotEmpty) {
          await _excluirArquivoStoragePorUrl(imagemPergunta);
        }

        if (imagemResposta.isNotEmpty) {
          await _excluirArquivoStoragePorUrl(imagemResposta);
        }
      }

      await _db.collection('flashcards').doc(cardId).delete();
    } catch (e) {
      rethrow;
    }
  }

  /// Exclui vários cards em lote (sem tratar imagens por enquanto).
  Future<void> excluirCardsEmLote(List<String> cardIds) async {
    try {
      final batch = _db.batch();

      for (final cardId in cardIds) {
        final docRef = _db.collection('flashcards').doc(cardId);
        batch.delete(docRef);
      }

      await batch.commit();
    } catch (e) {
      rethrow;
    }
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
        'imagemPergunta': data['imagemPergunta'] ?? '',
        'imagemResposta': data['imagemResposta'] ?? '',
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
        final tema = (item['tema'] ?? '').toString().trim();
        final subtema = (item['subtema'] ?? '').toString().trim();
        final pergunta = (item['pergunta'] ?? '').toString().trim();
        final resposta = (item['resposta'] ?? '').toString().trim();
        final explicacao = (item['explicacao'] ?? '').toString().trim();
        final imagemPergunta = (item['imagemPergunta'] ?? '').toString().trim();
        final imagemResposta = (item['imagemResposta'] ?? '').toString().trim();
        final dificuldade = (item['dificuldade'] ?? 'medio').toString().trim();

        if (materia.isEmpty ||
            tema.isEmpty ||
            subtema.isEmpty ||
            pergunta.isEmpty ||
            resposta.isEmpty) {
          continue;
        }

        final docRef = _db.collection('flashcards').doc();

        final searchTerms = _gerarSearchTerms([
          materia,
          tema,
          subtema,
          pergunta,
          resposta,
          explicacao,
        ]);

        await docRef.set({
          'id': docRef.id,
          'materia': materia,
          'tema': tema,
          'subtema': subtema,
          'pergunta': pergunta,
          'resposta': resposta,
          'explicacao': explicacao,
          'imagemPergunta': imagemPergunta,
          'imagemResposta': imagemResposta,
          'dificuldade': dificuldade.isEmpty ? 'medio' : dificuldade,
          'searchTerms': searchTerms.toList(),
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        });

        importados++;
      }

      return importados;
    } catch (e) {
      rethrow;
    }
  }

  // ========================================================================
  // Imagem / Firebase Storage
  // ========================================================================

  /// Envia uma imagem (como Uint8List) para o Firebase Storage e retorna a URL de download.
  Future<String?> uploadImagem(
    Uint8List imagemBytes,
    String nomeArquivo,
  ) async {
    try {
      // #region agent log
      await _debugLog(
        hypothesisId: 'H1',
        location: 'firebase_service.dart:394',
        message: 'uploadImagem:start',
        data: {
          'nomeArquivo': nomeArquivo,
          'bytesLength': imagemBytes.length,
        },
      );
      // #endregion
      final ref = FirebaseStorage.instance
          .ref()
          .child('flashcards')
          .child(nomeArquivo);

      await ref.putData(imagemBytes);
      final url = await ref.getDownloadURL();
      // #region agent log
      await _debugLog(
        hypothesisId: 'H1',
        location: 'firebase_service.dart:400',
        message: 'uploadImagem:success',
        data: {'nomeArquivo': nomeArquivo, 'hasUrl': url.isNotEmpty},
      );
      // #endregion
      return url;
    } catch (e) {
      // #region agent log
      await _debugLog(
        hypothesisId: 'H1',
        location: 'firebase_service.dart:402',
        message: 'uploadImagem:error',
        data: {'nomeArquivo': nomeArquivo, 'error': e.toString()},
      );
      // #endregion
      return null;
    }
  }

  /// Deleta um arquivo no Firebase Storage a partir de sua URL.
  Future<void> _excluirArquivoStoragePorUrl(String url) async {
    try {
      final ref = FirebaseStorage.instance.refFromURL(url);
      await ref.delete();
    } catch (e) {
      // Ignorar erros ao excluir arquivo do storage, pois pode não existir
    }
  }
}