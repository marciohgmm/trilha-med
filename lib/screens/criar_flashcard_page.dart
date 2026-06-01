import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/firebase_service.dart';
import 'package:flutter_application_1/services/flashcard_materia_stats_service.dart';
import 'package:flutter_application_1/services/flashcard_subtema_catalog_service.dart';
import 'package:flutter_application_1/services/flashcard_create_session_defaults.dart';
import 'package:flutter_application_1/utils/content_hierarchy_utils.dart';
import 'package:flutter_application_1/widgets/subtema_search_field.dart';
import 'package:flutter_application_1/utils/flashcard_storage_upload.dart';
import 'package:flutter_application_1/utils/image_helper.dart';
import 'package:flutter_application_1/widgets/flashcard_readonly_quill.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:http/http.dart' as http;

enum _SlotImagemCard { pergunta, resposta, explicacao }

class CriarFlashcardPage extends StatefulWidget {
  final String? cardId;
  final Map<String, dynamic>? dados;

  const CriarFlashcardPage({
    super.key,
    this.cardId,
    this.dados,
  });

  @override
  State<CriarFlashcardPage> createState() => _CriarFlashcardPageState();
}

class _CriarFlashcardPageState extends State<CriarFlashcardPage> {
  final quill.QuillController perguntaController =
      quill.QuillController.basic();
  final quill.QuillController respostaController =
      quill.QuillController.basic();
  final quill.QuillController explicacaoController =
      quill.QuillController.basic();

  final FocusNode perguntaFocusNode = FocusNode();
  final FocusNode respostaFocusNode = FocusNode();
  final FocusNode explicacaoFocusNode = FocusNode();

  final ScrollController perguntaScrollController = ScrollController();
  final ScrollController respostaScrollController = ScrollController();
  final ScrollController explicacaoScrollController = ScrollController();

  final FirebaseService firebaseService = FirebaseService();

  List<String> materias = [];
  List<String> subtemas = [];

  String? materiaSelecionada;
  String? subtemaSelecionado;

  bool carregando = true;
  bool salvando = false;
  bool _enviandoImagemCard = false;

  String _imagemPerguntaLocal = '';
  String _imagemRespostaLocal = '';
  String _imagemExplicacaoLocal = '';

  bool get modoEdicao => widget.cardId != null && widget.dados != null;

  /// Sem `dart:io`: compatível com Web e VM.
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
    debugPrint('[flashcard_debug] $message ${jsonEncode(data)}');
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
    }
  }

  @override
  void initState() {
    super.initState();
    carregarMaterias();
  }

  @override
  void dispose() {
    perguntaController.dispose();
    respostaController.dispose();
    explicacaoController.dispose();

    perguntaFocusNode.dispose();
    respostaFocusNode.dispose();
    explicacaoFocusNode.dispose();

    perguntaScrollController.dispose();
    respostaScrollController.dispose();
    explicacaoScrollController.dispose();

    super.dispose();
  }

  Future<void> _carregarConteudoNoController(
    quill.QuillController controller,
    String conteudo,
  ) async {
    if (conteudo.trim().isEmpty) return;

    try {
      final decoded = jsonDecode(conteudo);
      final delta = decoded is List
          ? decoded
          : decoded is Map<String, dynamic> && decoded['ops'] is List
              ? decoded['ops']
              : null;

      if (delta is List) {
        controller.document = quill.Document.fromJson(
          List<Map<String, dynamic>>.from(
            delta.map((item) => Map<String, dynamic>.from(item as Map)),
          ),
        );
      } else {
        controller.document = quill.Document.fromJson(
          List<Map<String, dynamic>>.from(
            jsonDecode(conteudo) as List,
          ),
        );
      }
    } catch (_) {
      controller.document = quill.Document()..insert(0, conteudo);
    }
    controller.updateSelection(
      const TextSelection.collapsed(offset: 0),
      quill.ChangeSource.local,
    );
  }

  Future<void> carregarMaterias() async {
    await _debugLog(
      hypothesisId: 'H2',
      location: 'criar_flashcard_page.dart:carregarMaterias',
      message: 'carregarMaterias:start',
      data: {'modoEdicao': modoEdicao},
    );
    final stats = await FlashcardMateriaStatsService.instance.fetchMateriaStats();
    final lista = ContentHierarchyUtils.sortAlphabetically(
      stats.map((s) => s.name),
    );
    await _debugLog(
      hypothesisId: 'H2',
      location: 'criar_flashcard_page.dart:carregarMaterias',
      message: 'carregarMaterias:loaded',
      data: {'materiasCount': lista.length},
    );

    if (!mounted) return;

    setState(() {
      materias = lista;
    });

    if (modoEdicao) {
      await _preencherDadosEdicao();
    } else {
      await _aplicarUltimosAssuntosSeDisponivel();
      if (!mounted) return;
      setState(() {
        carregando = false;
      });
    }
  }

  /// Reaplica matéria/subtema da sessão ([FlashcardCreateSessionDefaults]) ao criar novo card.
  Future<void> _aplicarUltimosAssuntosSeDisponivel() async {
    if (modoEdicao) return;
    if (!FlashcardCreateSessionDefaults.hasPair) return;

    final m = FlashcardCreateSessionDefaults.ultimaMateriaSelecionada!.trim();
    final s = FlashcardCreateSessionDefaults.ultimoSubtemaSelecionado!.trim();

    if (!materias.contains(m)) return;

    materiaSelecionada = m;
    await carregarSubtemas(m);
    if (!mounted) return;
    subtemaSelecionado = s;
    setState(() {});
  }

  Future<void> _preencherDadosEdicao() async {
    final dados = widget.dados!;

    materiaSelecionada = (dados['materia'] ?? '').toString().trim();
    subtemaSelecionado = (dados['subtema'] ?? '').toString().trim();

    if (materiaSelecionada != null && materiaSelecionada!.isNotEmpty) {
      await carregarSubtemas(materiaSelecionada!);
    }

    await _carregarConteudoNoController(
      perguntaController,
      (dados['pergunta'] ?? '').toString(),
    );
    await _carregarConteudoNoController(
      respostaController,
      (dados['resposta'] ?? '').toString(),
    );
    await _carregarConteudoNoController(
      explicacaoController,
      (dados['explicacao'] ?? '').toString(),
    );

    _imagemPerguntaLocal = flashcardMigrateImageFieldToStorageRef(
      (dados['imagemPerguntaLocal'] ?? '').toString(),
    );
    _imagemRespostaLocal = flashcardMigrateImageFieldToStorageRef(
      (dados['imagemRespostaLocal'] ?? '').toString(),
    );
    _imagemExplicacaoLocal = flashcardMigrateImageFieldToStorageRef(
      (dados['imagemExplicacaoLocal'] ?? '').toString(),
    );

    if (_imagemPerguntaLocal.isEmpty) {
      final legado = (dados['imagemLocal'] ?? '').toString().trim();
      if (legado.isNotEmpty &&
          !legado.contains('..') &&
          !legado.toLowerCase().startsWith('http')) {
        _imagemPerguntaLocal = flashcardMigrateImageFieldToStorageRef(legado);
      }
    }

    if (!mounted) return;

    setState(() {
      carregando = false;
    });
  }

  Future<void> carregarSubtemas(String materia) async {
    final lista =
        await FlashcardSubtemaCatalogService.instance.fetchSubtemasByMateria(
      materia,
    );

    if (!mounted) return;

    setState(() {
      subtemas = lista;
    });
  }

  void mostrarDialogNovaMateria() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Nova Matéria"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Digite o nome da matéria',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              final valor = controller.text.trim();
              if (valor.isEmpty) return;

              setState(() {
                if (!materias.contains(valor)) {
                  materias.add(valor);
                  materias.sort();
                }
                materiaSelecionada = valor;
                subtemaSelecionado = null;
                subtemas = [];
              });

              Navigator.pop(context);
            },
            child: const Text("Salvar"),
          ),
        ],
      ),
    );
  }

  void mostrarDialogNovoSubtema() {
    if (materiaSelecionada == null || materiaSelecionada!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione a matéria primeiro')),
      );
      return;
    }

    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Novo Subtema"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Digite o nome do subtema',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              final valor = controller.text.trim();
              if (valor.isEmpty) return;

              setState(() {
                subtemas = ContentHierarchyUtils.sortAlphabetically({
                  ...subtemas,
                  valor,
                });
                subtemaSelecionado = valor;
              });

              Navigator.pop(context);
            },
            child: const Text("Salvar"),
          ),
        ],
      ),
    );
  }

  Future<void> _escolherImagemCard(_SlotImagemCard slot) async {
    final FilePickerResult? resultado = kIsWeb
        ? await FilePicker.platform.pickFiles(
            type: FileType.image,
            allowMultiple: false,
            withData: true,
          )
        : await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: kExtensoesImagemCardPicker,
            allowMultiple: false,
            withData: false,
          );

    if (resultado == null || resultado.files.isEmpty) return;

    final f = resultado.files.first;
    var nome = f.name.trim();
    if (nome.isEmpty && f.path != null && f.path!.trim().isNotEmpty) {
      nome = f.path!.trim().replaceAll(r'\', '/').split('/').last;
    }
    nome = flashcardSanitizeBareFilename(
      nome.replaceAll(r'\', '/').split('/').last,
    );
    if (nome.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nome de arquivo inválido. Escolha outra imagem.'),
        ),
      );
      return;
    }

    final ref =
        FirebaseStorage.instance.ref('$kFlashcardStorageRootSegment/$nome');

    if (!mounted) return;
    setState(() {
      _enviandoImagemCard = true;
    });

    try {
      await uploadFlashcardPickedFile(ref, f);
      final storageRef =
          flashcardMigrateImageFieldToStorageRef(nome); // imagenscard/nome

      if (!mounted) return;
      setState(() {
        switch (slot) {
          case _SlotImagemCard.pergunta:
            _imagemPerguntaLocal = storageRef;
            break;
          case _SlotImagemCard.resposta:
            _imagemRespostaLocal = storageRef;
            break;
          case _SlotImagemCard.explicacao:
            _imagemExplicacaoLocal = storageRef;
            break;
        }
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imagem enviada para Firebase Storage: $storageRef',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao enviar imagem: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _enviandoImagemCard = false;
        });
      }
    }
  }

  Widget _previewImagemSlot(_SlotImagemCard slot, String nome) {
    if (nome.isEmpty) return const SizedBox.shrink();
    switch (slot) {
      case _SlotImagemCard.pergunta:
        return buildImagemPergunta(nome, height: 140);
      case _SlotImagemCard.resposta:
        return buildImagemResposta(nome, height: 140);
      case _SlotImagemCard.explicacao:
        return buildImagemExplicacao(nome, height: 140);
    }
  }

  Widget _buildEditorCard({
    required String titulo,
    required _SlotImagemCard slotImagem,
    required String imagemNomeArquivo,
    required quill.QuillController controller,
    required FocusNode focusNode,
    required ScrollController scrollController,
    double altura = 220,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                quill.QuillToolbarHistoryButton(
                  controller: controller,
                  isUndo: true,
                ),
                quill.QuillToolbarHistoryButton(
                  controller: controller,
                  isUndo: false,
                ),
                quill.QuillToolbarToggleStyleButton(
                  controller: controller,
                  attribute: quill.Attribute.bold,
                ),
                quill.QuillToolbarToggleStyleButton(
                  controller: controller,
                  attribute: quill.Attribute.italic,
                ),
                quill.QuillToolbarToggleStyleButton(
                  controller: controller,
                  attribute: quill.Attribute.underline,
                ),
                quill.QuillToolbarClearFormatButton(
                  controller: controller,
                ),
                quill.QuillToolbarColorButton(
                  controller: controller,
                  isBackground: false,
                ),
                quill.QuillToolbarColorButton(
                  controller: controller,
                  isBackground: true,
                ),
                quill.QuillToolbarToggleStyleButton(
                  controller: controller,
                  attribute: quill.Attribute.ol,
                ),
                quill.QuillToolbarToggleStyleButton(
                  controller: controller,
                  attribute: quill.Attribute.ul,
                ),
                quill.QuillToolbarLinkStyleButton(
                  controller: controller,
                ),
                quill.QuillToolbarSelectAlignmentButton(
                  controller: controller,
                ),
                quill.QuillToolbarToggleStyleButton(
                  controller: controller,
                  attribute: quill.Attribute.strikeThrough,
                ),
                quill.QuillToolbarIndentButton(
                  controller: controller,
                  isIncrease: true,
                ),
                quill.QuillToolbarIndentButton(
                  controller: controller,
                  isIncrease: false,
                ),
                IconButton(
                  tooltip:
                      'Enviar imagem para Firebase Storage ($kFlashcardStorageRootSegment/)',
                  onPressed: _enviandoImagemCard
                      ? null
                      : () => _escolherImagemCard(slotImagem),
                  icon: _enviandoImagemCard
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.add_photo_alternate_outlined,
                          color: Color(0xFF1E3A8A),
                        ),
                ),
              ],
            ),
          ),
          if (imagemNomeArquivo.isNotEmpty) ...[
            const SizedBox(height: 8),
            Center(child: _previewImagemSlot(slotImagem, imagemNomeArquivo)),
          ],
          const SizedBox(height: 12),
          Container(
            height: altura,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: quill.QuillEditor(
              controller: controller,
              focusNode: focusNode,
              scrollController: scrollController,
              config: quill.QuillEditorConfig(
                padding: const EdgeInsets.all(12),
                autoFocus: false,
                expands: false,
                placeholder: 'Digite o conteúdo de $titulo...',
                embedBuilders: kIsWeb
                    ? FlutterQuillEmbeds.editorWebBuilders(
                        imageEmbedConfig:
                            FlashcardReadonlyQuill.kQuillImageEmbedConfig,
                        videoEmbedConfig: null,
                      )
                    : FlutterQuillEmbeds.editorBuilders(
                        imageEmbedConfig:
                            FlashcardReadonlyQuill.kQuillImageEmbedConfig,
                        videoEmbedConfig: null,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<String> _getConteudoParaSalvar(quill.QuillController controller,
      {bool preservarFormatacao = false}) async {
    if (preservarFormatacao) {
      return jsonEncode(controller.document.toDelta().toJson());
    }
    return controller.document.toPlainText().trim();
  }

  String _getTextoPlano(quill.QuillController controller) {
    return controller.document.toPlainText().trim();
  }

  InputDecoration _decoracaoCampo(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Future<void> salvarCard() async {
    if (salvando) return;

    final pergunta = await _getConteudoParaSalvar(
      perguntaController,
      preservarFormatacao: true,
    );
    final resposta = await _getConteudoParaSalvar(
      respostaController,
      preservarFormatacao: true,
    );
    final explicacao = await _getConteudoParaSalvar(
      explicacaoController,
      preservarFormatacao: true,
    );
    final perguntaTextoPlano = _getTextoPlano(perguntaController);
    final respostaTextoPlano = _getTextoPlano(respostaController);
    await _debugLog(
      hypothesisId: 'H3',
      location: 'criar_flashcard_page.dart:salvarCard',
      message: 'salvarCard:collectedInputs',
      data: {
        'materia': materiaSelecionada,
        'subtema': subtemaSelecionado,
        'perguntaLen': pergunta.length,
        'respostaLen': resposta.length,
        'explicacaoLen': explicacao.length,
        'perguntaTextoPlanoLen': perguntaTextoPlano.length,
        'respostaTextoPlanoLen': respostaTextoPlano.length,
      },
    );

    if (materiaSelecionada == null ||
        materiaSelecionada!.trim().isEmpty ||
        subtemaSelecionado == null ||
        subtemaSelecionado!.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha matéria e subtema')),
      );
      return;
    }

    if (perguntaTextoPlano.isEmpty || respostaTextoPlano.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Preencha pergunta e resposta")),
      );
      return;
    }

    setState(() {
      salvando = true;
    });

    try {
      await _debugLog(
        hypothesisId: 'H4',
        location: 'criar_flashcard_page.dart:salvarCard',
        message: 'salvarCard:beforePersist',
        data: {'modoEdicao': modoEdicao, 'cardId': widget.cardId},
      );
      final imagemPerguntaLocal = flashcardMigrateImageFieldToStorageRef(
        _imagemPerguntaLocal.trim(),
      );
      final imagemRespostaLocal = flashcardMigrateImageFieldToStorageRef(
        _imagemRespostaLocal.trim(),
      );
      final imagemExplicacaoLocal = flashcardMigrateImageFieldToStorageRef(
        _imagemExplicacaoLocal.trim(),
      );
      if (modoEdicao) {
        await firebaseService.atualizarCard(
          cardId: widget.cardId!,
          materia: materiaSelecionada!.trim(),
          subtema: subtemaSelecionado!.trim(),
          pergunta: pergunta,
          resposta: resposta,
          explicacao: explicacao,
          imagemPerguntaLocal: imagemPerguntaLocal,
          imagemRespostaLocal: imagemRespostaLocal,
          imagemExplicacaoLocal: imagemExplicacaoLocal,
        );
      } else {
        await firebaseService.adicionarCard(
          materia: materiaSelecionada!.trim(),
          subtema: subtemaSelecionado!.trim(),
          pergunta: pergunta,
          resposta: resposta,
          explicacao: explicacao,
          imagemPerguntaLocal: imagemPerguntaLocal,
          imagemRespostaLocal: imagemRespostaLocal,
          imagemExplicacaoLocal: imagemExplicacaoLocal,
        );
      }
      await _debugLog(
        hypothesisId: 'H4',
        location: 'criar_flashcard_page.dart:salvarCard',
        message: 'salvarCard:afterPersist',
        data: {'modoEdicao': modoEdicao},
      );

      if (!mounted) return;

      FlashcardCreateSessionDefaults.setFromForm(
        materiaSelecionada!.trim(),
        subtemaSelecionado!.trim(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            modoEdicao
                ? "Flashcard atualizado com sucesso!"
                : "Flashcard salvo com sucesso!",
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      await _debugLog(
        hypothesisId: 'H4',
        location: 'criar_flashcard_page.dart:salvarCard',
        message: 'salvarCard:error',
        data: {'error': e.toString()},
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao salvar flashcard: $e")),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text(modoEdicao ? "Editar Flashcard" : "Criar Flashcard"),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          if (!modoEdicao)
            IconButton(
              tooltip: 'Limpar assunto padrão da sessão',
              icon: const Icon(Icons.restart_alt_rounded),
              onPressed: () {
                FlashcardCreateSessionDefaults.clear();
                setState(() {
                  materiaSelecionada = null;
                  subtemaSelecionado = null;
                  subtemas = [];
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Seleção padrão da sessão limpa.'),
                  ),
                );
              },
            ),
        ],
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    key: ValueKey<String>(
                      'fc_dd_materia_${materias.length}_${materiaSelecionada ?? ''}',
                    ),
                    initialValue: materias.contains(materiaSelecionada)
                        ? materiaSelecionada
                        : null,
                    decoration: _decoracaoCampo("Matéria"),
                    items: [
                      ...materias.map(
                        (m) => DropdownMenuItem(
                          value: m,
                          child: Text(m),
                        ),
                      ),
                      const DropdownMenuItem(
                        value: "__nova_materia__",
                        child: Text("➕ Nova Matéria"),
                      ),
                    ],
                    onChanged: (value) async {
                      if (value == "__nova_materia__") {
                        mostrarDialogNovaMateria();
                        return;
                      }

                      setState(() {
                        materiaSelecionada = value;
                        subtemaSelecionado = null;
                        subtemas = [];
                      });

                      if (value != null && value.isNotEmpty) {
                        await carregarSubtemas(value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  if (materiaSelecionada != null &&
                      materiaSelecionada!.isNotEmpty)
                    SubtemaSearchField(
                      key: ValueKey(
                          'fc_sub_${materiaSelecionada}_${subtemas.length}'),
                      subtemas: subtemas,
                      selectedSubtema: subtemaSelecionado,
                      enabled: !salvando,
                      onCreateNew: mostrarDialogNovoSubtema,
                      onSelected: (value) {
                        setState(() {
                          subtemaSelecionado = value?.trim().isEmpty == true
                              ? null
                              : value?.trim();
                        });
                      },
                    ),
                  const SizedBox(height: 20),
                  _buildEditorCard(
                    titulo: "Pergunta",
                    slotImagem: _SlotImagemCard.pergunta,
                    imagemNomeArquivo: _imagemPerguntaLocal,
                    controller: perguntaController,
                    focusNode: perguntaFocusNode,
                    scrollController: perguntaScrollController,
                    altura: 240,
                  ),
                  const SizedBox(height: 16),
                  _buildEditorCard(
                    titulo: "Resposta",
                    slotImagem: _SlotImagemCard.resposta,
                    imagemNomeArquivo: _imagemRespostaLocal,
                    controller: respostaController,
                    focusNode: respostaFocusNode,
                    scrollController: respostaScrollController,
                    altura: 240,
                  ),
                  const SizedBox(height: 16),
                  _buildEditorCard(
                    titulo: "Explicação",
                    slotImagem: _SlotImagemCard.explicacao,
                    imagemNomeArquivo: _imagemExplicacaoLocal,
                    controller: explicacaoController,
                    focusNode: explicacaoFocusNode,
                    scrollController: explicacaoScrollController,
                    altura: 260,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: salvando ? null : salvarCard,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: salvando
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            modoEdicao
                                ? "Salvar Alterações"
                                : "Salvar Flashcard",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
