import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/content_query_limits.dart';

import 'package:flutter_application_1/utils/image_helper.dart';
import 'package:flutter_application_1/utils/report_message_dialog.dart';
import 'package:flutter_application_1/widgets/flashcard_readonly_quill.dart';

import 'package:flutter_application_1/services/flashcard_study_daily_store.dart';
import 'package:flutter_application_1/utils/flashcard_study_order.dart';

import 'cronograma_page.dart';
import 'questoes_page.dart';
import '../services/study_timer_service.dart';
import '../core/analytics/analytics_events.dart';
import '../core/analytics/analytics_feature_tracker.dart';
import '../widgets/study_pause_dialog.dart';
import '../widgets/study_timer_overlay.dart';

class TelaFlashcards extends StatefulWidget {
  final String userId;
  final String materia;
  final String subtema;

  const TelaFlashcards({
    super.key,
    required this.userId,
    required this.materia,
    required this.subtema,
  });

  @override
  State<TelaFlashcards> createState() => _TelaFlashcardsState();
}

class _TelaFlashcardsState extends State<TelaFlashcards> with WidgetsBindingObserver, AnalyticsFeatureTracker {
  // Sessão (fila dinâmica)
  bool _sessaoIniciada = false;
  String? _cardAtualId;
  final List<String> _fila = [];
  final List<_CardRetorno> _retornos = [];
  final Map<String, int> _aparicoes = {};
  final Set<String> _vistosAoMenosUmaVez = {};
  final Set<String> _marcadosFaceis = {};
  int _totalCardsSessao = 0;
  bool _sessaoEsgotada = false;

  /// Preferências locais (carregadas antes de montar a sessão).
  bool _prefsReady = false;
  FlashcardStudySessionSnapshot? _snapshotCarregado;

  /// Dia civil local em que a sessão atual foi registrada (troca à meia-noite → reinicia).
  String? _diaSessaoRegistrado;

  bool mostrandoResposta = false;
  bool salvando = false;
  bool enviandoReport = false;
  bool _mostrarExplicacao = false;
  bool _assuntoConcluido = false;

  final StudyTimerService _timerService = StudyTimerService();

  /// Rede indisponível (Connectivity) — aviso amigável; dados de cards podem vir do cache Firestore.
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _netOffline = false;

  Future<String> _carregarNomeAluno() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      final data = doc.data();
      final nome = (data?['nome'] ?? '').toString().trim();
      return nome.isNotEmpty ? nome : 'Aluno(a)';
    } catch (_) {
      return 'Aluno(a)';
    }
  }

  @override
  void initState() {
    super.initState();
    trackFeatureOnce(
      AnalyticsEvents.flashcardStudyStart,
      userId: widget.userId,
      parameters: {AnalyticsParams.materia: widget.materia},
    );
    WidgetsBinding.instance.addObserver(this);
    FlashcardStudyDailyStore.load(
      userId: widget.userId,
      materia: widget.materia,
      subtema: widget.subtema,
    ).then((snap) {
      if (!mounted) return;
      setState(() {
        _snapshotCarregado = snap;
        _prefsReady = true;
      });
    });
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((results) {
      if (!mounted) return;
      final offline = results.isEmpty ||
          results.every((r) => r == ConnectivityResult.none);
      setState(() => _netOffline = offline);
    });
    Connectivity().checkConnectivity().then((results) {
      if (!mounted) return;
      final offline = results.isEmpty ||
          results.every((r) => r == ConnectivityResult.none);
      setState(() => _netOffline = offline);
    });
    debugPrint(
        'TelaFlashcards init: userId=${widget.userId}, materia=${widget.materia}, subtema=${widget.subtema}');
    _timerService.loadSettings().then((_) {
      _timerService.iniciarEstudo();
    });
    _timerService.alertStream.listen((alert) {
      if (alert == 'pause_reminder') {
        _mostrarAlertaPausa();
      } else if (alert == 'pause_end') {
        _mostrarFimPausa();
      }
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _timerService.pausarEstudo();
    WidgetsBinding.instance.removeObserver(this);
    _salvarSnapshotFireAndForget();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _salvarSnapshotFireAndForget();
    }
  }

  void _salvarSnapshotFireAndForget() {
    if (!_prefsReady || !_sessaoIniciada || _assuntoConcluido) return;
    final snap = FlashcardStudySessionSnapshot(
      dateYmd: FlashcardStudyDailyStore.todayYmdLocal(),
      materia: widget.materia,
      subtema: widget.subtema,
      marcadosFaceis: _marcadosFaceis.toList(),
      fila: List<String>.from(_fila),
      retornos: _retornos
          .map(
            (r) => FlashcardRetornoSnapshot(cardId: r.cardId, faltam: r.faltam),
          )
          .toList(),
      cardAtualId: _cardAtualId,
      aparicoes: Map<String, int>.from(_aparicoes),
      vistos: _vistosAoMenosUmaVez.toList(),
      totalCardsSessao: _totalCardsSessao,
      assuntoConcluido: _assuntoConcluido,
      sessaoEsgotada: _sessaoEsgotada,
    );
    FlashcardStudyDailyStore.save(
      userId: widget.userId,
      materia: widget.materia,
      subtema: widget.subtema,
      snapshot: snap,
    );
  }

  /// Zera só o estado em memória da sessão (fila, fáceis, etc.).
  void _resetarEstadoSessaoEstudo() {
    _sessaoIniciada = false;
    _marcadosFaceis.clear();
    _fila.clear();
    _retornos.clear();
    _aparicoes.clear();
    _vistosAoMenosUmaVez.clear();
    _cardAtualId = null;
    _totalCardsSessao = 0;
    _sessaoEsgotada = false;
    _assuntoConcluido = false;
    mostrandoResposta = false;
    _mostrarExplicacao = false;
  }

  void _reiniciarSessaoPorTrocaDeDia() {
    _snapshotCarregado = null;
    _resetarEstadoSessaoEstudo();
    FlashcardStudyDailyStore.clear(
      userId: widget.userId,
      materia: widget.materia,
      subtema: widget.subtema,
    );
  }

  Future<void> _confirmarELimparCacheSessaoDoDia() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpar progresso da sessão?'),
        content: const Text(
          'Apaga neste aparelho o progresso da sessão de hoje para este subtema '
          '(fila, retornos e cards já marcados como Fácil na sessão). '
          'O histórico no Firebase (nível de revisão) não é apagado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
            ),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    await FlashcardStudyDailyStore.clear(
      userId: widget.userId,
      materia: widget.materia,
      subtema: widget.subtema,
    );
    if (!mounted) return;
    setState(_resetarEstadoSessaoEstudo);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Progresso da sessão de hoje limpo. Estudo recomeça do zero.'),
        backgroundColor: Color(0xFF1E3A8A),
      ),
    );
  }

  void _restaurarDeSnapshot(
    FlashcardStudySessionSnapshot snap,
    Set<String> idsSet,
  ) {
    _marcadosFaceis
      ..clear()
      ..addAll(snap.marcadosFaceis.where(idsSet.contains));
    _fila
      ..clear()
      ..addAll(snap.fila.where(idsSet.contains));
    _retornos.clear();
    for (final r in snap.retornos) {
      if (idsSet.contains(r.cardId) && r.faltam > 0) {
        _retornos.add(_CardRetorno(cardId: r.cardId, faltam: r.faltam));
      }
    }
    _aparicoes.clear();
    snap.aparicoes.forEach((k, v) {
      if (idsSet.contains(k)) {
        _aparicoes[k] = v;
      }
    });
    _vistosAoMenosUmaVez
      ..clear()
      ..addAll(snap.vistos.where(idsSet.contains));
    _assuntoConcluido = snap.assuntoConcluido;
    _sessaoEsgotada = snap.sessaoEsgotada;
    final cid = snap.cardAtualId;
    if (cid != null &&
        idsSet.contains(cid) &&
        !_marcadosFaceis.contains(cid)) {
      _cardAtualId = cid;
    } else {
      _cardAtualId = null;
    }
    if (!_assuntoConcluido && _cardAtualId == null) {
      if (_fila.isNotEmpty) {
        _cardAtualId = _fila.removeAt(0);
      } else {
        _avancarParaProximoCard();
      }
    }
  }

  void _iniciarPausaComDialogo() {
    _timerService.pausarEstudo();
    _timerService.iniciarPausa();
    StudyPauseDialog.show(context, _timerService);
  }

  void _mostrarAlertaPausa() {
    final min = _timerService.studyDuration.inMinutes;
    final pauseMin = _timerService.pauseDuration.inMinutes;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '⏱️ Você estudou $min min. Hora de uma pausa de $pauseMin min.',
        ),
        duration: const Duration(seconds: 12),
        action: SnackBarAction(
          label: 'Pausar agora',
          onPressed: _iniciarPausaComDialogo,
        ),
      ),
    );
  }

  void _mostrarFimPausa() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          '⏰ Pausa finalizada! O despertador tocou — volte aos estudos.',
        ),
        duration: const Duration(seconds: 12),
        action: SnackBarAction(
          label: 'Voltar a estudar',
          onPressed: () => _timerService.retomarEstudoAposPausa(),
        ),
      ),
    );
  }

  String _normalizarConteudoRichText(dynamic valor) {
    final texto = (valor ?? '').toString();
    if (texto.trim().isEmpty) return '';

    try {
      final decoded = jsonDecode(texto);
      if (decoded is List) {
        final buffer = StringBuffer();
        for (final op in decoded) {
          if (op is Map && op['insert'] is String) {
            buffer.write(op['insert'] as String);
          }
        }
        return buffer.toString().trim();
      }
    } catch (_) {
      // Já é texto comum.
    }

    return texto;
  }

  Widget _conteudoRichCard({
    required String cardId,
    required dynamic valor,
    required bool destaque,
    required String materia,
  }) {
    return DefaultTextStyle.merge(
      style: TextStyle(
        fontSize: 18.5,
        height: 1.52,
        color: const Color(0xFF1F2937),
        fontWeight: destaque ? FontWeight.w600 : FontWeight.w500,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: FlashcardReadonlyQuill(
          key: ValueKey('fc_study_$cardId'),
          valor: valor,
          materia: materia,
          studyMode: true,
        ),
      ),
    );
  }

  int _metaFaceis(int total) {
    // 50% arredondando para cima (ex.: 1->1, 3->2, 20->10)
    return ((total * 0.5).ceil()).clamp(1, total);
  }

  /// Quantos **outros** cards ver antes de repetir (após responder Difícil/Moderado).
  static const int _intervaloOutrosCardsDificil = 3;
  static const int _intervaloOutrosCardsModerado = 5;

  /// Máximo de vezes que o card aparece na sessão; na 4ª sai como Fácil.
  static const int _maxAparicoesPorCardNaSessao = 4;

  void _removerCardDaRotacao(String cardId) {
    _fila.removeWhere((id) => id == cardId);
    _retornos.removeWhere((r) => r.cardId == cardId);
  }

  /// Agenda retorno após [outrosCards] interações com **outros** cards.
  /// O contador interno usa +1 porque [_tickRetornosEInserirNaFila] roda já no
  /// primeiro [_avancarParaProximoCard] logo após responder.
  void _agendarRetorno(String cardId, int outrosCards) {
    _removerCardDaRotacao(cardId);
    _retornos.add(_CardRetorno(cardId: cardId, faltam: outrosCards + 1));
  }

  /// Decrementa contadores e recoloca no início da fila (próximo card a ver).
  void _tickRetornosEInserirNaFila() {
    if (_retornos.isEmpty) return;
    for (final r in _retornos) {
      r.faltam--;
    }
    final prontos = _retornos.where((r) => r.faltam <= 0).toList();
    if (prontos.isEmpty) return;
    _retornos.removeWhere((r) => r.faltam <= 0);
    for (var i = prontos.length - 1; i >= 0; i--) {
      final id = prontos[i].cardId;
      if (_marcadosFaceis.contains(id)) continue;
      _fila.removeWhere((x) => x == id);
      _fila.insert(0, id);
    }
  }

  void _avancarParaProximoCard() {
    _tickRetornosEInserirNaFila();

    if (_fila.isNotEmpty) {
      _cardAtualId = _fila.removeAt(0);
      mostrandoResposta = false;
      _mostrarExplicacao = false;
      return;
    }

    // Sem mais cards para mostrar (sem fila e sem retornos)
    _cardAtualId = null;
    _sessaoEsgotada = true;
    _assuntoConcluido = true;
    FlashcardStudyDailyStore.clear(
      userId: widget.userId,
      materia: widget.materia,
      subtema: widget.subtema,
    );
  }

  void _iniciarOuSincronizarSessao(List<QueryDocumentSnapshot> docs) {
    sortFlashcardDocsPorEstudo(docs);

    final hoje = FlashcardStudyDailyStore.todayYmdLocal();
    if (_diaSessaoRegistrado != null && _diaSessaoRegistrado != hoje) {
      _reiniciarSessaoPorTrocaDeDia();
    }
    _diaSessaoRegistrado = hoje;

    final ids = docs.map((d) => d.id).toList();
    final idsSet = ids.toSet();

    /// Remove da sessão cards que foram apagados no Firestore.
    _marcadosFaceis.removeWhere((id) => !idsSet.contains(id));
    _vistosAoMenosUmaVez.removeWhere((id) => !idsSet.contains(id));
    _aparicoes.removeWhere((id, _) => !idsSet.contains(id));
    _fila.removeWhere((id) => !idsSet.contains(id));
    _retornos.removeWhere((r) => !idsSet.contains(r.cardId));

    _totalCardsSessao = ids.length;

    // Primeira inicialização: garante que todos apareçam ao menos 1x.
    if (!_sessaoIniciada) {
      _sessaoIniciada = true;

      if (_snapshotCarregado != null &&
          _snapshotCarregado!.dateYmd == hoje) {
        _restaurarDeSnapshot(_snapshotCarregado!, idsSet);
        _snapshotCarregado = null;
        _totalCardsSessao = ids.length;
        return;
      }

      _marcadosFaceis.clear();
      _retornos.clear();
      _aparicoes.clear();
      _vistosAoMenosUmaVez.clear();
      _fila
        ..clear()
        ..addAll(ids.where((id) => !_marcadosFaceis.contains(id)));

      if (_fila.isNotEmpty) {
        _cardAtualId = _fila.removeAt(0);
      } else {
        _cardAtualId = null;
        _assuntoConcluido = true;
      }
      return;
    }

    // Se entrarem cards novos enquanto a sessão está aberta, adiciona ao fim da fila
    // para garantir que sejam vistos ao menos 1x sem reiniciar tudo.
    final conhecidos = <String>{
      ..._aparicoes.keys,
      ..._fila,
      ..._retornos.map((r) => r.cardId),
      if (_cardAtualId != null) _cardAtualId!,
    };

    final novos = ids
        .where((id) =>
            !conhecidos.contains(id) && !_marcadosFaceis.contains(id))
        .toList();
    if (novos.isNotEmpty) {
      _fila.addAll(novos);
    }

    if (_cardAtualId != null && !idsSet.contains(_cardAtualId!)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _cardAtualId = null;
          _avancarParaProximoCard();
        });
      });
    }
  }

  static String _fmtEstat(int n) {
    if (n >= 1000) return '$n';
    return n.toString().padLeft(2, '0');
  }

  /// Esquerda: marcados como Fácil | Meio: ainda não Fácil | Direita: total no subtema.
  Widget _indicadorSessaoTresNumeros(int faceis, int naoFaceis, int total) {
    final a = _fmtEstat(faceis);
    final b = _fmtEstat(naoFaceis);
    final c = _fmtEstat(total);
    return Tooltip(
      message: '$a — marcados como Fácil (saíram da rotação principal)\n'
          '$b — ainda não marcados como Fácil\n'
          '$c — total de cards neste subtema',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E3A8A).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: const Color(0xFF1E3A8A).withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$a - $b - $c',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: Color(0xFF1E3A8A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> salvarProgresso(
      String cardId, String dificuldade, int total) async {
    final progressoRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('progresso')
        .doc(cardId);

    final resumoRef =
        FirebaseFirestore.instance.collection('users').doc(widget.userId);

    final agora = DateTime.now();

    // 🔥 BUSCA PROGRESSO ATUAL
    final doc = await progressoRef.get();

    int nivelAtual = 0;
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      nivelAtual = data['nivel'] ?? 0;
    }

    // 🔥 REGRAS DE EVOLUÇÃO
    int novoNivel = nivelAtual;

    // Use max 0 e keep within 0..4
    const maxNivel = 4;

    if (dificuldade == "Difícil") {
      novoNivel = (nivelAtual - 1).clamp(0, maxNivel);
    } else if (dificuldade == "Fácil") {
      novoNivel = (nivelAtual + 1).clamp(0, maxNivel);
    }
    // "Moderado" -> mantém nível

    // 🔥 CURVA DE REPETIÇÃO
    List<int> intervalos = [1, 3, 7, 15, 30]; // 1, 3, 7, 15, 30

    int intervalo;

    if (novoNivel >= intervalos.length) {
      intervalo = 30;
    } else {
      intervalo = intervalos[novoNivel];
    }

    final proximaRevisao = agora.add(Duration(days: intervalo));

    // 🔥 SALVA PROGRESSO DETALHADO
    await progressoRef.set({
      'cardId': cardId,
      'userId': widget.userId,
      'materia': widget.materia,
      'subtema': widget.subtema,
      'dificuldade': dificuldade,
      'nivel': novoNivel,
      'intervalo': intervalo,
      'proximaRevisao': Timestamp.fromDate(proximaRevisao),
      'dataEstudo': Timestamp.fromDate(agora),
      'atualizadoEm': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 🔥 ATUALIZA RESUMO (opcional manter)
    int acertos = 0;
    int erros = 0;

    if (dificuldade == "Difícil") {
      erros = 1;
    } else {
      acertos = 1;
    }

    await resumoRef.set({
      'ultimoAcesso': FieldValue.serverTimestamp(),
      'ultimaMateria': widget.materia,
      'ultimoSubtema': widget.subtema,
      'totalRespondidas': FieldValue.increment(1),
      'totalAcertos': FieldValue.increment(acertos),
      'totalErros': FieldValue.increment(erros),
    }, SetOptions(merge: true));
  }

  static String _truncarCampoFirestore(String s, [int max = 8000]) {
    if (s.length <= max) return s;
    return '${s.substring(0, max)}…';
  }

  Future<void> enviarReportErro({
    required String cardId,
    required String pergunta,
    required String resposta,
    required String explicacao,
    required int indiceCard,
    required int totalCards,
    required String mensagem,
  }) async {
    final agora = DateTime.now();

    await FirebaseFirestore.instance.collection('notificacoes_admin').add({
      'tipo': 'erro_card',
      'status': 'novo',
      'mensagem': _truncarCampoFirestore(mensagem, 2000),
      'userId': widget.userId,
      'materia': widget.materia,
      'subtema': widget.subtema,
      'flashcardDocId': cardId,
      'indiceCard': indiceCard,
      'totalCardsSubtema': totalCards,
      'pergunta': _truncarCampoFirestore(pergunta),
      'resposta': _truncarCampoFirestore(resposta),
      'explicacao': _truncarCampoFirestore(explicacao),
      'criadoEm': Timestamp.fromDate(agora),
      'atualizadoEm': FieldValue.serverTimestamp(),
    });
  }

  Future<void> mostrarDialogReport({
    required String cardId,
    required String pergunta,
    required String resposta,
    required String explicacao,
    required int indiceCard,
    required int totalCards,
  }) async {
    if (!mounted) return;

    final mensagem = await showReportTextDialog(
      context: context,
      title: 'Reportar erro',
      hintText: 'Descreva o erro encontrado neste card',
      maxLines: 6,
      emptyMessage: 'Descreva o erro antes de enviar.',
    );

    if (mensagem == null || mensagem.isEmpty) return;

    setState(() {
      enviandoReport = true;
    });

    try {
      await enviarReportErro(
        cardId: cardId,
        pergunta: pergunta,
        resposta: resposta,
        explicacao: explicacao,
        indiceCard: indiceCard,
        totalCards: totalCards,
        mensagem: mensagem,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro reportado com sucesso'),
          backgroundColor: Color(0xFF1E3A8A),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao enviar report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          enviandoReport = false;
        });
      }
    }
  }

  Future<void> responderCard(
      String cardId, String dificuldade, int total) async {
    if (salvando) return;

    setState(() {
      salvando = true;
    });

    try {
      await salvarProgresso(cardId, dificuldade, total);

      // Não mostramos mais o SnackBar
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(
      //     content: Text('Progresso salvo com sucesso'),
      //     backgroundColor: Color(0xFF1E3A8A),
      //   ),
      // );

      if (!mounted) return;

      var concluiuSessao = false;
      setState(() {
        // Atualiza aparições do card na sessão (conta a aparição atual)
        final aparicoes = (_aparicoes[cardId] ?? 0) + 1;
        _aparicoes[cardId] = aparicoes;
        _vistosAoMenosUmaVez.add(cardId);

        final atingiuMax = aparicoes >= _maxAparicoesPorCardNaSessao;

        if (dificuldade == 'Fácil' || atingiuMax) {
          // Fácil ou 4ª visualização: sai da rotação da sessão.
          _removerCardDaRotacao(cardId);
          _marcadosFaceis.add(cardId);
        } else if (dificuldade == 'Difícil') {
          _agendarRetorno(cardId, _intervaloOutrosCardsDificil);
        } else if (dificuldade == 'Moderado') {
          _agendarRetorno(cardId, _intervaloOutrosCardsModerado);
        }

        // Critérios de conclusão da sessão:
        // - todos vistos ao menos 1x
        // - meta de 50% dos cards em "Fácil"
        final meta = _metaFaceis(_totalCardsSessao);
        final podeConcluir = _vistosAoMenosUmaVez.length >= _totalCardsSessao &&
            _marcadosFaceis.length >= meta;

        if (podeConcluir) {
          concluiuSessao = true;
          _assuntoConcluido = true;
          _cardAtualId = null;
          return;
        }

        // Avança seguindo a fila dinâmica.
        _avancarParaProximoCard();
      });
      if (concluiuSessao) {
        await FlashcardStudyDailyStore.clear(
          userId: widget.userId,
          materia: widget.materia,
          subtema: widget.subtema,
        );
      } else {
        _salvarSnapshotFireAndForget();
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar progresso: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          salvando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom + 16;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text(widget.subtema),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Limpar progresso da sessão de hoje',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: salvando ? null : _confirmarELimparCacheSessaoDoDia,
          ),
        ],
      ),
      body: !_prefsReady
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: Stack(
          children: [
            StreamBuilder<QuerySnapshot>(
              // Com persistence ativa (main), esta query pode servir dados do cache offline.
              stream: FirebaseFirestore.instance
                  .collection('flashcards')
                  .where('materia', isEqualTo: widget.materia)
                  .where('subtema', isEqualTo: widget.subtema)
                  .limit(ContentQueryLimits.maxStudySubtema)
                  // Permite ler metadata.isFromCache (útil com persistence offline).
                  .snapshots(includeMetadataChanges: true),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Não foi possível carregar os flashcards.\n'
                        'Se estiver offline, abra este subtema ao menos uma vez com rede para guardar em cache.\n\n'
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Ordem: [sortFlashcardDocsPorEstudo] — ordemEstudo (criação/reordenação) e,
                // para legado sem campo, desempate por [createdAt].
                final docs = snapshot.data!.docs.toList();
                sortFlashcardDocsPorEstudo(docs);
                debugPrint(
                    'Encontrados ${docs.length} flashcards para materia: ${widget.materia}, subtema: ${widget.subtema}');

                if (docs.isEmpty) {
                  return const Center(child: Text('Sem flashcards'));
                }

                // Inicia/sincroniza sessão baseada nos docs atuais
                _iniciarOuSincronizarSessao(docs);

                // Se não há card atual e ainda não concluiu, tenta avançar
                if (_cardAtualId == null && !_assuntoConcluido) {
                  _avancarParaProximoCard();
                }

                final cardId = _cardAtualId;

                // Tela final do tema/subtema (se o usuário concluiu a sessão)
                if (_assuntoConcluido || cardId == null) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: FutureBuilder<String>(
                              future: _carregarNomeAluno(),
                              builder: (context, snap) {
                                final nome = snap.data ?? 'Aluno(a)';
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.emoji_events_outlined,
                                      size: 64,
                                      color: Color(0xFF1E3A8A),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Parabéns Dr.(a) $nome!',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E3A8A),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    const Text(
                                      'Sessão concluída.\nFoco, disciplina e constância é o caminho do sucesso.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 16),
                                    ),
                                    if (_sessaoEsgotada) ...[
                                      const SizedBox(height: 10),
                                      const Text(
                                        'Sessão finalizada: limite de aparições atingido para os cards restantes.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Colors.black54),
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                    Text(
                                      'Fácil: ${_marcadosFaceis.length}/$_totalCardsSessao (meta: ${_metaFaceis(_totalCardsSessao)})',
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _FooterActionButton(
                              texto: 'Resolver questões',
                              icone: Icons.quiz,
                              cor: const Color(0xFF1E3A8A),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => QuestoesPage(
                                      userId: widget.userId,
                                      materia: widget.materia,
                                      subtema: widget.subtema,
                                    ),
                                  ),
                                );
                              },
                            ),
                            _FooterActionButton(
                              texto: 'Cronograma',
                              icone: Icons.schedule,
                              cor: Colors.blueGrey,
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CronogramaPage(
                                      userId: widget.userId,
                                    ),
                                  ),
                                );
                              },
                            ),
                            _FooterActionButton(
                              texto: 'Home',
                              icone: Icons.home,
                              cor: const Color(0xFF1E3A8A),
                              onPressed: () {
                                Navigator.popUntil(
                                    context, (route) => route.isFirst);
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: bottomPadding),
                      ],
                    ),
                  );
                }

                QueryDocumentSnapshot? docAtual;
                for (final d in docs) {
                  if (d.id == cardId) {
                    docAtual = d;
                    break;
                  }
                }
                if (docAtual == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    setState(() {
                      _cardAtualId = null;
                      _avancarParaProximoCard();
                    });
                  });
                  return const Center(child: CircularProgressIndicator());
                }

                final data = docAtual.data() as Map<String, dynamic>;
                final idsSetAtual = docs.map((d) => d.id).toSet();
                final nFaceis =
                    _marcadosFaceis.where(idsSetAtual.contains).length;
                final totalSub = docs.length;
                final nNaoFaceis = (totalSub - nFaceis).clamp(0, totalSub);

                final perguntaTexto =
                    _normalizarConteudoRichText(data['pergunta']);
                final respostaTexto =
                    _normalizarConteudoRichText(data['resposta']);
                final imagemPerguntaLocal =
                    (data['imagemPerguntaLocal'] ?? '').toString().trim();
                final imagemRespostaLocal =
                    flashcardMigrateImageFieldToStorageRef(
                  (data['imagemRespostaLocal'] ?? '').toString(),
                );
                final imagemExplicacaoLocal =
                    flashcardMigrateImageFieldToStorageRef(
                  (data['imagemExplicacaoLocal'] ?? '').toString(),
                );
                final legadoImagemLocal =
                    (data['imagemLocal'] ?? '').toString().trim();
                var imagemPerguntaEfetiva =
                    flashcardMigrateImageFieldToStorageRef(imagemPerguntaLocal);
                if (imagemPerguntaEfetiva.isEmpty &&
                    legadoImagemLocal.isNotEmpty &&
                    !legadoImagemLocal.contains('..') &&
                    !legadoImagemLocal.toLowerCase().startsWith('http')) {
                  imagemPerguntaEfetiva =
                      flashcardMigrateImageFieldToStorageRef(legadoImagemLocal);
                }
                final explicacao =
                    _normalizarConteudoRichText(data['explicacao']);
                final indiceCard =
                    (_vistosAoMenosUmaVez.length + 1).clamp(1, docs.length);

                return Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 720),
                            child: Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.fromLTRB(20, 24, 20, 26),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.white, Colors.grey[50]!],
                                ),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => setState(() {
                                      mostrandoResposta = !mostrandoResposta;
                                      _mostrarExplicacao = false;
                                    }),
                                    child: Column(
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  mostrandoResposta
                                                      ? 'RESPOSTA'
                                                      : 'PERGUNTA',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 1.1,
                                                    color: Color(0xFF1E3A8A),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            _indicadorSessaoTresNumeros(
                                              nFaceis,
                                              nNaoFaceis,
                                              totalSub,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        _conteudoRichCard(
                                          cardId: cardId,
                                          valor: mostrandoResposta
                                              ? data['resposta']
                                              : data['pergunta'],
                                          destaque: !mostrandoResposta,
                                          materia: (data['materia'] ??
                                                  widget.materia)
                                              .toString(),
                                        ),
                                        if (!mostrandoResposta &&
                                            imagemPerguntaEfetiva
                                                .isNotEmpty) ...[
                                          const SizedBox(height: 16),
                                          buildImagemPergunta(
                                            imagemPerguntaEfetiva,
                                            studyFullscreenTap: true,
                                          ),
                                        ],
                                        if (mostrandoResposta &&
                                            imagemRespostaLocal.isNotEmpty) ...[
                                          const SizedBox(height: 16),
                                          buildImagemResposta(
                                            imagemRespostaLocal,
                                            studyFullscreenTap: true,
                                          ),
                                        ],
                                        if (mostrandoResposta &&
                                            explicacao.isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: OutlinedButton(
                                              onPressed: () {
                                                setState(() {
                                                  _mostrarExplicacao =
                                                      !_mostrarExplicacao;
                                                });
                                              },
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor:
                                                    const Color(0xFF1E3A8A),
                                                side: BorderSide(
                                                  color: const Color(0xFF1E3A8A)
                                                      .withValues(alpha: 0.35),
                                                  width: 1,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 6,
                                                ),
                                                minimumSize: const Size(0, 0),
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                                visualDensity:
                                                    VisualDensity.compact,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                              child: Text(
                                                _mostrarExplicacao
                                                    ? 'OCULTAR EXPLICAÇÃO'
                                                    : 'MOSTRAR EXPLICAÇÃO',
                                              ),
                                            ),
                                          ),
                                          if (_mostrarExplicacao)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 4),
                                              child: Column(
                                                children: [
                                                  const Text(
                                                    '💡',
                                                    textAlign: TextAlign.center,
                                                  ),
                                                  _conteudoRichCard(
                                                    cardId: '${cardId}_exp',
                                                    valor: data['explicacao'],
                                                    destaque: false,
                                                    materia: (data['materia'] ??
                                                            widget.materia)
                                                        .toString(),
                                                  ),
                                                  if (imagemExplicacaoLocal
                                                      .isNotEmpty) ...[
                                                    const SizedBox(height: 12),
                                                    buildImagemExplicacao(
                                                      imagemExplicacaoLocal,
                                                      studyFullscreenTap: true,
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (mostrandoResposta) ...[
                                    const SizedBox(height: 20),
                                    const Divider(),
                                    const SizedBox(height: 8),
                                    if (enviandoReport)
                                      const Padding(
                                        padding: EdgeInsets.only(bottom: 8),
                                        child: CircularProgressIndicator(),
                                      ),
                                    TextButton.icon(
                                      onPressed: enviandoReport
                                          ? null
                                          : () => mostrarDialogReport(
                                                cardId: cardId,
                                                pergunta: perguntaTexto,
                                                resposta: respostaTexto,
                                                explicacao: explicacao,
                                                indiceCard: indiceCard,
                                                totalCards: docs.length,
                                              ),
                                      icon: const Icon(
                                        Icons.report_problem_outlined,
                                        color: Color(0xFFFBBF24),
                                      ),
                                      label: const Text('Reportar erro'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (mostrandoResposta)
                      Container(
                        padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPadding),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 10,
                              offset: Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            if (salvando)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: CircularProgressIndicator(),
                              ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _BotaoDificuldade(
                                  texto: 'Fácil',
                                  cor: Colors.green,
                                  onPressed: () => responderCard(
                                    cardId,
                                    'Fácil',
                                    docs.length,
                                  ),
                                ),
                                _BotaoDificuldade(
                                  texto: 'Moderado',
                                  cor: Colors.orange,
                                  onPressed: () => responderCard(
                                    cardId,
                                    'Moderado',
                                    docs.length,
                                  ),
                                ),
                                _BotaoDificuldade(
                                  texto: 'Difícil',
                                  cor: Colors.red,
                                  onPressed: () => responderCard(
                                    cardId,
                                    'Difícil',
                                    docs.length,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: EdgeInsets.fromLTRB(24, 20, 24, bottomPadding),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 10,
                              offset: Offset(0, -2),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () => setState(() {
                            mostrandoResposta = true;
                            _mostrarExplicacao = false;
                          }),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Mostrar Resposta',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const StudyTimerOverlay(),
            if (_netOffline)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Material(
                  elevation: 6,
                  color: Colors.orange.shade800,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: const [
                          Icon(
                            Icons.cloud_off_outlined,
                            color: Colors.white,
                            size: 22,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Sem internet — usando dados em cache do Firestore e de imagens quando disponíveis.',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CardRetorno {
  final String cardId;
  int faltam;

  _CardRetorno({
    required this.cardId,
    required this.faltam,
  });
}

class _BotaoDificuldade extends StatelessWidget {
  final String texto;
  final Color cor;
  final VoidCallback onPressed;

  const _BotaoDificuldade({
    required this.texto,
    required this.cor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: cor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        texto,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _FooterActionButton extends StatelessWidget {
  final String texto;
  final IconData icone;
  final Color cor;
  final VoidCallback onPressed;

  const _FooterActionButton({
    required this.texto,
    required this.icone,
    required this.cor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icone, size: 20),
      label: Text(texto),
      style: ElevatedButton.styleFrom(
        backgroundColor: cor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
