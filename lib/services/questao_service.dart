import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class QuestaoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Exemplo de uso:
  /// final questaoService = QuestaoService();
  /// final sucesso = await questaoService.salvarQuestao(
  ///   enunciado: 'Qual é a capital do Brasil?',
  ///   alternativas: [
  ///     {'letra': 'A', 'texto': 'São Paulo', 'correta': false},
  ///     {'letra': 'B', 'texto': 'Brasília', 'correta': true},
  ///     {'letra': 'C', 'texto': 'Rio de Janeiro', 'correta': false},
  ///     {'letra': 'D', 'texto': 'Belo Horizonte', 'correta': false},
  ///   ],
  ///   comentario: 'Brasília é a capital federal do Brasil.',
  ///   materia: 'Geografia',
  ///   tema: 'Capitais',
  ///   subtema: 'Capitais Brasileiras',
  ///   nivel: 'Fácil',
  ///   ano: 2023,
  ///   banca: 'ENEM',
  ///   criadoPor: 'user123',
  /// );
  /// if (sucesso) { print('Questão salva com sucesso!'); }

  /// Salva uma questão no Cloud Firestore.
  /// Retorna true se sucesso, false se erro.
  Future<bool> salvarQuestao({
    required String enunciado,
    required List<Map<String, dynamic>> alternativas,
    required String comentario,
    required String materia,
    required String tema,
    required String subtema,
    required String nivel,
    required int ano,
    required String banca,
    required String criadoPor,
  }) async {
    try {
      // Validação: enunciado não vazio
      if (enunciado.trim().isEmpty) {
        throw Exception('Enunciado não pode estar vazio');
      }

      // Validação: apenas uma alternativa correta
      final corretas = alternativas.where((alt) => alt['correta'] == true).length;
      if (corretas != 1) {
        throw Exception('Deve haver exatamente uma alternativa correta');
      }

      // Validação: alternativas têm letra, texto e correta
      for (final alt in alternativas) {
        if (alt['letra'] == null || alt['texto'] == null || alt['correta'] == null) {
          throw Exception('Alternativas devem ter letra, texto e correta');
        }
      }

      // Criar documento
      await _firestore.collection('questoes').add({
        'enunciado': enunciado.trim(),
        'alternativas': alternativas,
        'comentario': comentario.trim(),
        'materia': materia.trim(),
        'tema': tema.trim(),
        'subtema': subtema.trim(),
        'nivel': nivel.trim(),
        'ano': ano,
        'banca': banca.trim(),
        'criadoPor': criadoPor.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('Erro ao salvar questão: $e');
      return false;
    }
  }

  /// Busca questões por matéria
  Stream<QuerySnapshot> getQuestoesPorMateria(String materia) {
    return _firestore
        .collection('questoes')
        .where('materia', isEqualTo: materia)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Busca questões por tema
  Stream<QuerySnapshot> getQuestoesPorTema(String tema) {
    return _firestore
        .collection('questoes')
        .where('tema', isEqualTo: tema)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Busca todas as matérias disponíveis
  Future<List<String>> getMaterias() async {
    final snapshot = await _firestore.collection('questoes').get();
    final set = <String>{};
    for (final doc in snapshot.docs) {
      final materia = (doc.data()['materia'] ?? '').toString().trim();
      if (materia.isNotEmpty) {
        set.add(materia);
      }
    }
    return set.toList()..sort();
  }

  /// Busca temas por matéria
  Future<List<String>> getTemasPorMateria(String materia) async {
    final snapshot = await _firestore
        .collection('questoes')
        .where('materia', isEqualTo: materia)
        .get();
    final set = <String>{};
    for (final doc in snapshot.docs) {
      final tema = (doc.data()['tema'] ?? '').toString().trim();
      if (tema.isNotEmpty) {
        set.add(tema);
      }
    }
    return set.toList()..sort();
  }
}