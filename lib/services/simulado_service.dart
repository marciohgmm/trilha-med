import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/questao_model.dart';
import '../models/simulado_models.dart';
import '../utils/content_hierarchy_utils.dart';
import 'questao_materia_stats_service.dart';
import 'questao_service.dart';

/// Monta e persiste simulados de questões.
class SimuladoService {
  SimuladoService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final QuestaoMateriaStatsService _materiaStats =
      QuestaoMateriaStatsService.instance;

  static const quantidadesDisponiveis = [25, 50, 75, 100];
  static const subcollectionSimuladosHistorico = 'simulados_historico';

  CollectionReference<Map<String, dynamic>> _historicoCol(String userId) =>
      _db
          .collection(QuestaoService.collectionUsers)
          .doc(userId)
          .collection(subcollectionSimuladosHistorico);

  /// Carrega mapa questaoId → progresso do usuário (uma leitura).
  Future<Map<String, ProgressoQuestaoUsuario>> carregarProgressoUsuario(
    String userId,
  ) async {
    final snap = await _db
        .collection(QuestaoService.collectionUsers)
        .doc(userId)
        .collection(QuestaoService.subcollectionProgressoQuestoes)
        .get();

    final map = <String, ProgressoQuestaoUsuario>{};
    for (final doc in snap.docs) {
      map[doc.id] = ProgressoQuestaoUsuario.fromMap(doc.id, doc.data());
    }
    return map;
  }

  /// Lista matérias com questões ativas (catálogo agregado).
  Future<List<String>> listarMateriasDisponiveis() async {
    final stats = await _materiaStats.fetchMateriaStats();
    return ContentHierarchyUtils.sortAlphabetically(stats.map((s) => s.name));
  }

  bool _passaFiltros({
    required String questaoId,
    required SimuladoFiltros filtros,
    required Map<String, ProgressoQuestaoUsuario> progresso,
  }) {
    final prog = progresso[questaoId];
    final resolvida = prog != null;

    final passaStatus = filtros.statusResolucao ==
            SimuladoStatusResolucao.incluirResolvidas ||
        !resolvida;

    if (!passaStatus) return false;

    if (filtros.tipoQuestoes == SimuladoTipoQuestoes.todas) {
      return true;
    }

    // Apenas erradas: precisa ter sido respondida e errada.
    return resolvida && prog.acertou == false;
  }

  /// Busca candidatas paginadas, aplica filtros e retorna até [quantidade] únicas.
  Future<List<QuestaoModel>> montarSimulado({
    required String userId,
    required SimuladoFiltros filtros,
  }) async {
    if (filtros.tipoQuestoes == SimuladoTipoQuestoes.apenasErradas &&
        filtros.statusResolucao ==
            SimuladoStatusResolucao.apenasNaoResolvidas) {
      throw SimuladoInsufficientQuestionsException(
        disponiveis: 0,
        solicitadas: filtros.quantidade,
      );
    }

    final progresso = await carregarProgressoUsuario(userId);
    final materiasFiltro = filtros.todasMaterias
        ? null
        : filtros.materiasSelecionadas
            .map((m) => m.trim())
            .where((m) => m.isNotEmpty)
            .toSet();

    if (materiasFiltro != null && materiasFiltro.isEmpty) {
      throw SimuladoInsufficientQuestionsException(
        disponiveis: 0,
        solicitadas: filtros.quantidade,
      );
    }

    final candidatas = <QuestaoModel>[];
    final idsVistos = <String>{};

    final minimo = filtros.quantidade;

    if (materiasFiltro == null) {
      final todasMaterias = await listarMateriasDisponiveis();
      final lista = todasMaterias;
      for (var i = 0; i < lista.length; i += 10) {
        if (candidatas.length >= minimo) break;
        final batch = lista.sublist(i, min(i + 10, lista.length));
        await _coletarPorMaterias(
          materias: batch,
          candidatas: candidatas,
          idsVistos: idsVistos,
          filtros: filtros,
          progresso: progresso,
          minimoNecessario: minimo,
        );
      }
    } else {
      final lista = materiasFiltro.toList();
      for (var i = 0; i < lista.length; i += 10) {
        if (candidatas.length >= minimo) break;
        final batch = lista.sublist(i, min(i + 10, lista.length));
        await _coletarPorMaterias(
          materias: batch,
          candidatas: candidatas,
          idsVistos: idsVistos,
          filtros: filtros,
          progresso: progresso,
          minimoNecessario: minimo,
        );
      }
    }

    if (candidatas.length < filtros.quantidade) {
      throw SimuladoInsufficientQuestionsException(
        disponiveis: candidatas.length,
        solicitadas: filtros.quantidade,
      );
    }

    candidatas.shuffle(Random());
    return candidatas.take(filtros.quantidade).toList();
  }

  Future<void> _coletarPorMaterias({
    required List<String> materias,
    required List<QuestaoModel> candidatas,
    required Set<String> idsVistos,
    required SimuladoFiltros filtros,
    required Map<String, ProgressoQuestaoUsuario> progresso,
    required int minimoNecessario,
  }) async {
    final snap = await _db
        .collection(QuestaoService.collectionQuestoes)
        .where('materia', whereIn: materias)
        .get();

    for (final doc in snap.docs) {
      if (idsVistos.contains(doc.id)) continue;
      final qm = QuestaoModel.fromMap(doc.id, doc.data());
      if (!qm.disponivelParaEstudo) continue;
      if (!_passaFiltros(
        questaoId: doc.id,
        filtros: filtros,
        progresso: progresso,
      )) {
        continue;
      }
      idsVistos.add(doc.id);
      candidatas.add(qm);
      if (candidatas.length >= minimoNecessario) return;
    }
  }

  Future<String> salvarHistorico({
    required String userId,
    required SimuladoFiltros filtros,
    required List<QuestaoModel> questoes,
    required int acertos,
    required int erros,
    required int naoRespondidas,
    required int tempoSegundos,
  }) async {
    final total = questoes.length;
    final respondidas = acertos + erros;
    final percentual = respondidas > 0 ? (acertos / respondidas) * 100 : 0.0;

    final ref = _historicoCol(userId).doc();
    await ref.set({
      'userId': userId,
      'filtros': filtros.toMap(),
      'totalQuestoes': total,
      'acertos': acertos,
      'erros': erros,
      'naoRespondidas': naoRespondidas,
      'percentualAcertos': double.parse(percentual.toStringAsFixed(1)),
      'tempoSegundos': tempoSegundos,
      'questaoIds': questoes.map((q) => q.id).toList(),
      'criadoEm': FieldValue.serverTimestamp(),
    });

    return ref.id;
  }

  Stream<List<SimuladoHistorico>> streamHistorico(String userId) {
    return _historicoCol(userId)
        .orderBy('criadoEm', descending: true)
        .limit(30)
        .snapshots()
        .map((s) => s.docs
            .map((d) => SimuladoHistorico.fromDoc(d.id, d.data()))
            .toList());
  }

}
