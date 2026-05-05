import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/questao_model.dart';

class QuestaoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String collectionQuestoes = 'questoes';
  static const String collectionNotificacoesAdmin = 'notificacoes_admin';
  static const String collectionUsers = 'users';
  static const String subcollectionProgressoQuestoes = 'progresso_questoes';

  Stream<List<QuestaoModel>> getTodasQuestoes() {
    return _firestore.collection(collectionQuestoes).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => QuestaoModel.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  Stream<List<QuestaoModel>> getQuestoesPorTema({
    String? temaId,
    String? temaSlug,
    String? tema,
    String? materiaId,
    String? materia,
    String? subtema,
    bool somenteAtivas = true,
  }) {
    Query query = _firestore.collection(collectionQuestoes);

    if (temaId != null && temaId.isNotEmpty) {
      query = query.where('temaId', isEqualTo: temaId);
    } else if (temaSlug != null && temaSlug.isNotEmpty) {
      query = query.where('temaSlug', isEqualTo: temaSlug);
    } else if (tema != null && tema.isNotEmpty) {
      query = query.where('tema', isEqualTo: tema);
    }

    if (materiaId != null && materiaId.isNotEmpty) {
      query = query.where('materiaId', isEqualTo: materiaId);
    } else if (materia != null && materia.isNotEmpty) {
      query = query.where('materia', isEqualTo: materia);
    }

    if (subtema != null && subtema.isNotEmpty) {
      query = query.where('subtema', isEqualTo: subtema);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => QuestaoModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .where((questao) => !somenteAtivas || questao.ativo || questao.status == 'ativo')
          .toList();
    });
  }

  Future<QuestaoModel?> getQuestaoPorId(String id) async {
    final snapshot = await _firestore.collection(collectionQuestoes).doc(id).get();
    if (!snapshot.exists) return null;
    return QuestaoModel.fromMap(snapshot.id, snapshot.data()!);
  }

  Future<bool> salvarQuestaoModel(QuestaoModel questao, {bool criar = true}) async {
    try {
      final data = questao.toMap();

      if (criar) {
        final docRef = _firestore.collection(collectionQuestoes).doc();
        await docRef.set(data);
      } else {
        if (questao.id.isEmpty) {
          throw Exception('Questão inválida para atualização.');
        }
        await _firestore
            .collection(collectionQuestoes)
            .doc(questao.id)
            .set(data, SetOptions(merge: true));
      }

      return true;
    } catch (e) {
      debugPrint('Erro ao salvar questão: $e');
      return false;
    }
  }

  Future<bool> excluirQuestao(String id) async {
    try {
      await _firestore.collection(collectionQuestoes).doc(id).delete();
      return true;
    } catch (e) {
      debugPrint('Erro ao excluir questão: $e');
      return false;
    }
  }

  Future<List<String>> getMaterias() async {
    final snapshot = await _firestore.collection(collectionQuestoes).get();
    final set = <String>{};
    for (final doc in snapshot.docs) {
      final materia = (doc.data()['materia'] ?? '').toString().trim();
      if (materia.isNotEmpty) {
        set.add(materia);
      }
    }
    return set.toList()..sort();
  }

  Future<List<String>> getTemasPorMateria(String materia) async {
    final snapshot = await _firestore
        .collection(collectionQuestoes)
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

  Future<void> reportarErroQuestao({
    required QuestaoModel questao,
    required String? userId,
    required String motivo,
  }) async {
    // Mantém o mesmo padrão do reporte de cards: salva em notificacoes_admin
    // e inclui um campo "pergunta" para o admin visualizar rapidamente.
    await _firestore.collection(collectionNotificacoesAdmin).add({
      'tipo': 'erro_questao',
      'status': 'novo',
      'mensagem': motivo,
      'userId': userId ?? '',
      'materia': questao.materia,
      'tema': questao.tema,
      'subtema': questao.subtema,
      'temaSlug': questao.temaSlug,
      'questaoId': questao.id,
      'pergunta': questao.enunciado,
      'enunciado': questao.enunciado,
      'alternativas': questao.alternativas.map((a) => a.toMap()).toList(),
      'corretaId': questao.corretaId,
      'justificativasPorAlternativa': questao.justificativasPorAlternativa,
      'criadoEm': Timestamp.fromDate(DateTime.now()),
      'atualizadoEm': FieldValue.serverTimestamp(),
    });
  }

  Future<String?> _tentarEncontrarFlashcardIdPorTema(String temaSlug) async {
    try {
      // tentativa 1: tema "comum" exato (sem case-insensitive)
      final snapshot1 = await _firestore
          .collection('flashcards')
          .where('tema', isEqualTo: 'Bronquiolite')
          .limit(1)
          .get();
      if (snapshot1.docs.isNotEmpty) return snapshot1.docs.first.id;
    } catch (_) {}

    // fallback: varrer um pequeno lote e bater por slug
    try {
      final snap = await _firestore.collection('flashcards').limit(200).get();
      for (final doc in snap.docs) {
        final tema = (doc.data()['tema'] ?? '').toString();
        if (QuestaoModel.slugify(tema) == temaSlug) {
          return doc.id;
        }
      }
    } catch (_) {}

    return null;
  }

  Future<void> seedBronquioliteExampleIfMissing() async {
    final tema = 'Bronquiolite';
    final temaSlug = QuestaoModel.slugify(tema);

    final existing = await _firestore
        .collection(collectionQuestoes)
        .where('temaSlug', isEqualTo: temaSlug)
        .limit(10)
        .get();

    final enunciado =
        'Lactente de 6 meses apresenta coriza, tosse, febre baixa e sibilância difusa após quadro viral de vias aéreas superiores. Qual é a conduta inicial mais adequada na maioria dos casos de bronquiolite aguda?';

    final jaExiste = existing.docs.any((d) {
      final data = d.data();
      final e = (data['enunciado'] ?? '').toString().trim();
      return e == enunciado;
    });

    if (jaExiste) return;

    final flashcardId = await _tentarEncontrarFlashcardIdPorTema(temaSlug);

    final questao = QuestaoModel(
      id: '',
      temaId: '',
      temaSlug: temaSlug,
      materiaId: '',
      materia: '',
      tema: tema,
      subtema: '',
      flashcardId: flashcardId,
      enunciado: enunciado,
      alternativas: const [
        QuestaoAlternativa(id: 'A', texto: 'Iniciar antibiótico oral de rotina'),
        QuestaoAlternativa(id: 'B', texto: 'Solicitar tomografia de tórax'),
        QuestaoAlternativa(
          id: 'C',
          texto: 'Oferecer suporte clínico, hidratação e observar saturação',
        ),
        QuestaoAlternativa(
          id: 'D',
          texto: 'Iniciar corticoide sistêmico para todos os casos',
        ),
      ],
      corretaId: 'C',
      explicacaoGeral:
          'A bronquiolite aguda, na maioria dos casos, tem manejo de suporte, com atenção à hidratação, ao desconforto respiratório e à oxigenação. Exames complementares e medicações de rotina não são indicados para todos os pacientes.',
      explicacaoCorreta:
          'C está correta porque o tratamento da bronquiolite é predominantemente de suporte, avaliando hidratação, esforço respiratório e necessidade de oxigênio.',
      explicacoesErradas: const {},
      justificativasPorAlternativa: const {
        'A':
            'A está errada porque antibiótico não é indicado de rotina em bronquiolite viral sem evidência de infecção bacteriana.',
        'B':
            'B está errada porque tomografia não faz parte da avaliação inicial habitual.',
        'D':
            'D está errada porque corticoide sistêmico não é recomendado rotineiramente na maioria dos casos.',
      },
      dificuldade: 'médio',
      status: 'ativo',
      tags: const ['pediatria', 'bronquiolite'],
      ativo: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      ordem: 0,
    );

    await salvarQuestaoModel(questao, criar: true);
  }

  Future<void> registrarResposta({
    required String userId,
    required QuestaoModel questao,
    required String alternativaSelecionadaId,
    required bool acertou,
  }) async {
    final ref = _firestore
        .collection(collectionUsers)
        .doc(userId)
        .collection(subcollectionProgressoQuestoes)
        .doc(questao.id);

    await ref.set({
      'questaoId': questao.id,
      'materia': questao.materia,
      'tema': questao.tema,
      'subtema': questao.subtema,
      'temaSlug': questao.temaSlug,
      'selecionadaId': alternativaSelecionadaId,
      'corretaId': questao.corretaId,
      'acertou': acertou,
      'respondidaEm': Timestamp.now(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> progressoQuestoesStream(
    String userId,
  ) {
    return _firestore
        .collection(collectionUsers)
        .doc(userId)
        .collection(subcollectionProgressoQuestoes)
        .snapshots();
  }
}
