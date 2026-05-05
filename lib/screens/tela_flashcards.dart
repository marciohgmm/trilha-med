import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'cronograma_page.dart';
import 'questoes_page.dart';
import '../services/study_timer_service.dart';
import '../widgets/study_timer_overlay.dart';

class TelaFlashcards extends StatefulWidget {
  final String userId;
  final String materia;
  final String tema;
  final String subtema;

  const TelaFlashcards({
    super.key,
    required this.userId,
    required this.materia,
    required this.tema,
    required this.subtema,
  });

  @override
  State<TelaFlashcards> createState() => _TelaFlashcardsState();
}

class _TelaFlashcardsState extends State<TelaFlashcards> {
  int indiceAtual = 0;
  bool mostrandoResposta = false;
  bool salvando = false;
  bool enviandoReport = false;
  bool _mostrarExplicacao = false;
  bool _assuntoConcluido = false;

  final StudyTimerService _timerService = StudyTimerService();

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
    debugPrint('TelaFlashcards init: userId=${widget.userId}, materia=${widget.materia}, tema=${widget.tema}, subtema=${widget.subtema}');
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
    _timerService.pausarEstudo();
    super.dispose();
  }

  void _mostrarAlertaPausa() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('⏱️ Você estudou por 50 minutos. Faça uma pausa de 10 minutos.'),
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: 'Pausar agora',
          onPressed: () {
            _timerService.pausarEstudo();
            _timerService.iniciarPausa();
            _mostrarCronometroPausa();
          },
        ),
      ),
    );
  }

  void _mostrarCronometroPausa() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StreamBuilder<Duration>(
        stream: _timerService.pauseTimeStream,
        builder: (context, snapshot) {
          final remaining = snapshot.data ?? _timerService.pauseTime;
          final minutes = remaining.inMinutes;
          final seconds = remaining.inSeconds % 60;

          return AlertDialog(
            title: const Text('Pausa em andamento'),
            content: Text(
              'Tempo restante: ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 24),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _timerService.cancelarPausa();
                  Navigator.of(context).pop();
                  _timerService.iniciarEstudo();
                },
                child: const Text('Voltar a estudar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _mostrarFimPausa() {
    Navigator.of(context).pop(); // Fechar dialog de pausa
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('⏱️ Pausa finalizada. Hora de voltar aos estudos!'),
        action: SnackBarAction(
          label: 'Voltar a estudar',
          onPressed: () {
            _timerService.iniciarEstudo();
          },
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

  Color? _parseHexColor(String? value) {
    if (value == null || value.isEmpty) return null;
    final hex = value.replaceFirst('#', '');
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    }
    if (hex.length == 8) {
      return Color(int.parse(hex, radix: 16));
    }
    return null;
  }

  List<dynamic>? _tryDecodeDelta(dynamic valor) {
    final texto = (valor ?? '').toString();
    if (texto.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(texto);
      if (decoded is List) return decoded;
      if (decoded is Map && decoded['ops'] is List) {
        return decoded['ops'] as List;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  TextSpan _toSpanFromOp(Map op) {
    final insert = op['insert']?.toString() ?? '';
    final attrs = op['attributes'];
    final atributos = attrs is Map ? attrs : const {};

    final fontWeight = atributos['bold'] == true ? FontWeight.bold : FontWeight.w400;
    final fontStyle = atributos['italic'] == true ? FontStyle.italic : FontStyle.normal;
    final decorationParts = <TextDecoration>[];
    if (atributos['underline'] == true) decorationParts.add(TextDecoration.underline);
    if (atributos['strike'] == true) decorationParts.add(TextDecoration.lineThrough);
    if (atributos['link'] != null) decorationParts.add(TextDecoration.underline);

    final link = atributos['link']?.toString();
    final textColor = link != null
        ? const Color(0xFF1D4ED8)
        : _parseHexColor(atributos['color']?.toString()) ?? Colors.black87;
    final background = _parseHexColor(atributos['background']?.toString());

    TapGestureRecognizer? recognizer;
    if (link != null && link.isNotEmpty) {
      recognizer = TapGestureRecognizer()
        ..onTap = () async {
          final uri = Uri.tryParse(link);
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.platformDefault);
          }
        };
    }

    return TextSpan(
      text: insert,
      recognizer: recognizer,
      style: TextStyle(
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        color: textColor,
        backgroundColor: background,
        decoration: decorationParts.isEmpty
            ? TextDecoration.none
            : TextDecoration.combine(decorationParts),
      ),
    );
  }

  Widget _buildConteudoFormatado({
    required dynamic valor,
    required bool destaquePergunta,
  }) {
    final delta = _tryDecodeDelta(valor);
    if (delta == null) {
      return Text(
        _normalizarConteudoRichText(valor),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 20,
          height: 1.5,
          color: Colors.black87,
          fontWeight: destaquePergunta ? FontWeight.bold : FontWeight.w500,
        ),
      );
    }

    final widgets = <Widget>[];
    final spans = <TextSpan>[];

    void flushSpans() {
      if (spans.isEmpty) return;
      widgets.add(
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(
              fontSize: 20,
              height: 1.5,
              color: Colors.black87,
              fontWeight: destaquePergunta ? FontWeight.bold : FontWeight.w500,
            ),
            children: List<TextSpan>.from(spans),
          ),
        ),
      );
      spans.clear();
    }

    for (final raw in delta) {
      if (raw is! Map) continue;
      final op = Map<String, dynamic>.from(raw);
      final insert = op['insert'];

      if (insert is String) {
        if (insert.isNotEmpty) spans.add(_toSpanFromOp(op));
      } else if (insert is Map && insert['image'] != null) {
        flushSpans();
        final imageUrl = insert['image'].toString();
        if (imageUrl.isNotEmpty) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _buildImagemUrl(imageUrl),
            ),
          );
        }
      }
    }
    flushSpans();

    if (widgets.isEmpty) {
      return Text(
        _normalizarConteudoRichText(valor),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 20,
          height: 1.5,
          color: Colors.black87,
          fontWeight: destaquePergunta ? FontWeight.bold : FontWeight.w500,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: widgets,
    );
  }

  Widget _buildImagemUrl(String url) {
    if (url.trim().isEmpty) return const SizedBox.shrink();

    // Em alguns casos pode ser salvo como gs://..., especialmente em migrações/imports.
    if (url.startsWith('gs://')) {
      return FutureBuilder<String>(
        future: FirebaseStorage.instance.refFromURL(url).getDownloadURL(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _buildImagemNetwork(snapshot.data!);
        },
      );
    }

    return _buildImagemNetwork(url);
  }

  Widget _buildImagemNetwork(String url) {
    return Image.network(
      url,
      height: 180,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        final expected = progress.expectedTotalBytes;
        final loaded = progress.cumulativeBytesLoaded;
        final value = expected != null && expected > 0 ? loaded / expected : null;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Center(
            child: CircularProgressIndicator(value: value),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Falha carregando imagem: $url -> $error');
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Imagem não carregada.\n$url\n$error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        );
      },
    );
  }

  void proximoCard(int total) {
    setState(() {
      if (indiceAtual < total - 1) {
        indiceAtual++;
      } else {
        // Ao concluir, mostramos a tela final (não popamos automaticamente).
        _assuntoConcluido = true;
      }
      mostrandoResposta = false;
      _mostrarExplicacao = false;
    });
  }

  Future<void> salvarProgresso(String cardId, String dificuldade, int total) async {
    final progressoRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('progresso')
        .doc(cardId);

    final resumoRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId);

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
      'tema': widget.tema,
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
      'ultimoTema': widget.tema,
      'ultimoSubtema': widget.subtema,
      'totalRespondidas': FieldValue.increment(1),
      'totalAcertos': FieldValue.increment(acertos),
      'totalErros': FieldValue.increment(erros),
    }, SetOptions(merge: true));
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
      'mensagem': mensagem,
      'userId': widget.userId,
      'materia': widget.materia,
      'tema': widget.tema,
      'subtema': widget.subtema,
      'flashcardDocId': cardId,
      'indiceCard': indiceCard,
      'totalCardsSubtema': totalCards,
      'pergunta': pergunta,
      'resposta': resposta,
      'explicacao': explicacao,
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
    final controller = TextEditingController();

    final mensagem = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reportar erro'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Descreva o erro encontrado neste card',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, controller.text.trim());
              },
              child: const Text('Enviar'),
            ),
          ],
        );
      },
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

  Future<void> responderCard(String cardId, String dificuldade, int total) async {
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

      // Se for o último card, em vez de sair, mostramos a finalização do tema.
      if (indiceAtual >= total - 1) {
        if (!mounted) return;
        setState(() {
          _assuntoConcluido = true;
        });
      } else {
        proximoCard(total);
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
      ),
      body: SafeArea(
        child: Stack(
          children: [
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('flashcards')
                  .where('materia', isEqualTo: widget.materia)
                  .where('tema', isEqualTo: widget.tema)
                  .where('subtema', isEqualTo: widget.subtema)
                  .snapshots(),
              builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!.docs;
            debugPrint('Encontrados ${docs.length} flashcards para materia: ${widget.materia}, tema: ${widget.tema}, subtema: ${widget.subtema}');

            if (docs.isEmpty) {
              return const Center(child: Text('Sem flashcards'));
            }

            if (indiceAtual >= docs.length) {
              indiceAtual = 0;
            }

            final data = docs[indiceAtual];
            final cardId = data.id;
            final indiceCard = indiceAtual + 1;

            final perguntaTexto = _normalizarConteudoRichText(data['pergunta']);
            final respostaTexto = _normalizarConteudoRichText(data['resposta']);
            final imagemPergunta = data['imagemPergunta'] ?? '';
            final imagemResposta = data['imagemResposta'] ?? '';
            final explicacao = _normalizarConteudoRichText(data['explicacao']);

            // Tela final do tema/subtema (se o usuário concluiu o último card)
            if (_assuntoConcluido) {
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
                                  'Você concluiu mais um tema.\nFoco, disciplina e constância é o caminho do sucesso.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 16),
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
                                  tema: widget.tema,
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
                            Navigator.popUntil(context, (route) => route.isFirst);
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: bottomPadding),
                  ],
                ),
              );
            }

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
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
                            onTap: () => setState(
                                () {
                                  mostrandoResposta = !mostrandoResposta;
                                  _mostrarExplicacao = false;
                                }),
                            child: Column(
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    mostrandoResposta ? 'RESPOSTA' : 'PERGUNTA',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.1,
                                      color: Color(0xFF1E3A8A),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _buildConteudoFormatado(
                                  valor: mostrandoResposta ? data['resposta'] : data['pergunta'],
                                  destaquePergunta: !mostrandoResposta,
                                ),
                                const SizedBox(height: 16),
                                if (!mostrandoResposta &&
                                    imagemPergunta.toString().isNotEmpty)
                                  _buildImagemUrl(imagemPergunta.toString()),
                                if (mostrandoResposta &&
                                    imagemResposta.toString().isNotEmpty)
                                  _buildImagemUrl(imagemResposta.toString()),
                                if (mostrandoResposta &&
                                    explicacao.toString().isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _mostrarExplicacao =
                                              !_mostrarExplicacao;
                                        });
                                      },
                                      child: Text(
                                        _mostrarExplicacao
                                            ? 'OCULTAR EXPLICAÇÃO'
                                            : 'MOSTRAR EXPLICAÇÃO',
                                      ),
                                    ),
                                  ),
                                  if (_mostrarExplicacao)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Column(
                                        children: [
                                          const Text(
                                            '💡',
                                            textAlign: TextAlign.center,
                                          ),
                                          _buildConteudoFormatado(
                                            valor: data['explicacao'],
                                            destaquePergunta: false,
                                          ),
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
                              icon: const Icon(Icons.report_problem_outlined),
                              label: Text(
                                'Reportar erro no card $indiceCard/${docs.length}',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (mostrandoResposta)
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
                    child: Column(
                      children: [
                        const Text(
                          'Como foi essa questão?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (salvando)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 16),
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
                              cor: Colors.blueGrey,
                              onPressed: () => responderCard(
                                cardId,
                                'Moderado',
                                docs.length,
                              ),
                            ),
                            _BotaoDificuldade(
                              texto: 'Difícil',
                              cor: Colors.orange,
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
                    padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPadding),
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
          ],
        ),
      ),
    );
  }
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