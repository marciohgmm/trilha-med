import 'dart:io';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/firebase_service.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

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
  final ImagePicker picker = ImagePicker();

  List<String> materias = [];
  List<String> temas = [];
  List<String> subtemas = [];

  String? materiaSelecionada;
  String? temaSelecionado;
  String? subtemaSelecionado;

  bool carregando = true;
  bool salvando = false;

  bool get modoEdicao => widget.cardId != null && widget.dados != null;

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
      if (decoded is List) {
        controller.document = quill.Document.fromJson(
          List<Map<String, dynamic>>.from(
            decoded.map((item) => Map<String, dynamic>.from(item as Map)),
          ),
        );
      } else {
        controller.document = quill.Document()..insert(0, conteudo);
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
    // #region agent log
    await _debugLog(
      hypothesisId: 'H2',
      location: 'criar_flashcard_page.dart:92',
      message: 'carregarMaterias:start',
      data: {'modoEdicao': modoEdicao},
    );
    // #endregion
    final snapshot =
        await FirebaseFirestore.instance.collection('flashcards').get();

    final set = <String>{};

    for (final doc in snapshot.docs) {
      final materia = (doc.data()['materia'] ?? '').toString().trim();
      if (materia.isNotEmpty) {
        set.add(materia);
      }
    }

    final lista = set.toList()..sort();
    // #region agent log
    await _debugLog(
      hypothesisId: 'H2',
      location: 'criar_flashcard_page.dart:104',
      message: 'carregarMaterias:loaded',
      data: {'materiasCount': lista.length},
    );
    // #endregion

    if (!mounted) return;

    setState(() {
      materias = lista;
    });

    if (modoEdicao) {
      await _preencherDadosEdicao();
    } else {
      setState(() {
        carregando = false;
      });
    }
  }

  Future<void> _preencherDadosEdicao() async {
    final dados = widget.dados!;

    materiaSelecionada = (dados['materia'] ?? '').toString().trim();
    temaSelecionado = (dados['tema'] ?? '').toString().trim();
    subtemaSelecionado = (dados['subtema'] ?? '').toString().trim();

    if (materiaSelecionada != null && materiaSelecionada!.isNotEmpty) {
      await carregarTemas(materiaSelecionada!);
    }

    if (materiaSelecionada != null &&
        temaSelecionado != null &&
        temaSelecionado!.isNotEmpty) {
      await carregarSubtemas(materiaSelecionada!, temaSelecionado!);
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

    if (!mounted) return;

    setState(() {
      carregando = false;
    });
  }

  Future<void> carregarTemas(String materia) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('flashcards')
        .where('materia', isEqualTo: materia)
        .get();

    final set = <String>{};

    for (final doc in snapshot.docs) {
      final tema = (doc.data()['tema'] ?? '').toString().trim();
      if (tema.isNotEmpty) {
        set.add(tema);
      }
    }

    if (!mounted) return;

    setState(() {
      temas = set.toList()..sort();
      subtemas = [];
    });
  }

  Future<void> carregarSubtemas(String materia, String tema) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('flashcards')
        .where('materia', isEqualTo: materia)
        .where('tema', isEqualTo: tema)
        .get();

    final set = <String>{};

    for (final doc in snapshot.docs) {
      final subtema = (doc.data()['subtema'] ?? '').toString().trim();
      if (subtema.isNotEmpty) {
        set.add(subtema);
      }
    }

    if (!mounted) return;

    setState(() {
      subtemas = set.toList()..sort();
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
                temaSelecionado = null;
                subtemaSelecionado = null;
                temas = [];
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

  void mostrarDialogNovoTema() {
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
        title: const Text("Novo Tema"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Digite o nome do tema',
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
                if (!temas.contains(valor)) {
                  temas.add(valor);
                  temas.sort();
                }
                temaSelecionado = valor;
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
    if (materiaSelecionada == null ||
        materiaSelecionada!.isEmpty ||
        temaSelecionado == null ||
        temaSelecionado!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione matéria e tema primeiro')),
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
                if (!subtemas.contains(valor)) {
                  subtemas.add(valor);
                  subtemas.sort();
                }
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

  Widget _buildEditorCard({
    required String titulo,
    required quill.QuillController controller,
    required FocusNode focusNode,
    required ScrollController scrollController,
    required String campo,
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
            child: Wrap(
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
                IconButton(
                  tooltip: 'Inserir imagem',
                  onPressed: () => _inserirImagemNoEditor(controller, campo),
                  icon: const Icon(
                    Icons.image_outlined,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: altura,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: quill.QuillEditor.basic(
              controller: controller,
              focusNode: focusNode,
              scrollController: scrollController,
              config: quill.QuillEditorConfig(
                padding: const EdgeInsets.all(12),
                placeholder: 'Digite o conteúdo de $titulo...',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _inserirImagemNoEditor(
    quill.QuillController controller,
    String campo,
  ) async {
    // #region agent log
    await _debugLog(
      hypothesisId: 'H1',
      location: 'criar_flashcard_page.dart:457',
      message: 'inserirImagem:start',
      data: {'campo': campo},
    );
    // #endregion
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null) return;
    if (!mounted) return;

    try {
      final bytes = await image.readAsBytes();
      final nomeOriginal = image.name;
      final extensao = nomeOriginal.contains('.')
          ? nomeOriginal.split('.').last.toLowerCase()
          : image.path.split('.').last.toLowerCase();

      // Validar extensão
      if (!['jpg', 'jpeg'].contains(extensao)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, selecione uma imagem em formato JPG ou JPEG'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      final nomeArquivo =
          '${campo}_${DateTime.now().millisecondsSinceEpoch}.${extensao.isEmpty ? 'jpg' : extensao}';
      // #region agent log
      await _debugLog(
        hypothesisId: 'H1',
        location: 'criar_flashcard_page.dart:468',
        message: 'inserirImagem:beforeUpload',
        data: {
          'campo': campo,
          'imagePath': image.path,
          'nomeArquivo': nomeArquivo,
          'bytesLength': bytes.length,
        },
      );
      // #endregion

      final url = await firebaseService.uploadImagem(bytes, nomeArquivo);

      if (url == null || !mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao enviar imagem')),
        );
        return;
      }

      final selection = controller.selection;
      final index = selection.baseOffset >= 0
          ? selection.baseOffset
          : controller.document.length;

      controller.replaceText(
        index,
        0,
        quill.BlockEmbed.image(url),
        TextSelection.collapsed(offset: index + 1),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Imagem inserida com sucesso!')),
      );
    } catch (e) {
      // #region agent log
      await _debugLog(
        hypothesisId: 'H1',
        location: 'criar_flashcard_page.dart:493',
        message: 'inserirImagem:error',
        data: {'campo': campo, 'error': e.toString()},
      );
      // #endregion
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao inserir imagem: $e')),
      );
    }
  }

  Future<String> _getConteudoParaSalvar(
    quill.QuillController controller,
    {bool preservarFormatacao = false}
  ) async {
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
    // #region agent log
    await _debugLog(
      hypothesisId: 'H3',
      location: 'criar_flashcard_page.dart:522',
      message: 'salvarCard:collectedInputs',
      data: {
        'materia': materiaSelecionada,
        'tema': temaSelecionado,
        'subtema': subtemaSelecionado,
        'perguntaLen': pergunta.length,
        'respostaLen': resposta.length,
        'explicacaoLen': explicacao.length,
        'perguntaTextoPlanoLen': perguntaTextoPlano.length,
        'respostaTextoPlanoLen': respostaTextoPlano.length,
      },
    );
    // #endregion

    if (materiaSelecionada == null ||
        materiaSelecionada!.trim().isEmpty ||
        temaSelecionado == null ||
        temaSelecionado!.trim().isEmpty ||
        subtemaSelecionado == null ||
        subtemaSelecionado!.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Preencha matéria, tema e subtema")),
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
      // #region agent log
      await _debugLog(
        hypothesisId: 'H4',
        location: 'criar_flashcard_page.dart:548',
        message: 'salvarCard:beforePersist',
        data: {'modoEdicao': modoEdicao, 'cardId': widget.cardId},
      );
      // #endregion
      if (modoEdicao) {
        await firebaseService.atualizarCard(
          cardId: widget.cardId!,
          materia: materiaSelecionada!.trim(),
          tema: temaSelecionado!.trim(),
          subtema: subtemaSelecionado!.trim(),
          pergunta: pergunta,
          resposta: resposta,
          explicacao: explicacao,
        );
      } else {
        await firebaseService.adicionarCard(
          materia: materiaSelecionada!.trim(),
          tema: temaSelecionado!.trim(),
          subtema: subtemaSelecionado!.trim(),
          pergunta: pergunta,
          resposta: resposta,
          explicacao: explicacao,
        );
      }
      // #region agent log
      await _debugLog(
        hypothesisId: 'H4',
        location: 'criar_flashcard_page.dart:569',
        message: 'salvarCard:afterPersist',
        data: {'modoEdicao': modoEdicao},
      );
      // #endregion

      if (!mounted) return;

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
      // #region agent log
      await _debugLog(
        hypothesisId: 'H4',
        location: 'criar_flashcard_page.dart:583',
        message: 'salvarCard:error',
        data: {'error': e.toString()},
      );
      // #endregion
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
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: materiaSelecionada,
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
                        temaSelecionado = null;
                        subtemaSelecionado = null;
                        temas = [];
                        subtemas = [];
                      });

                      if (value != null && value.isNotEmpty) {
                        await carregarTemas(value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: temaSelecionado,
                    decoration: _decoracaoCampo("Tema"),
                    items: [
                      ...temas.map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(t),
                        ),
                      ),
                      const DropdownMenuItem(
                        value: "__novo_tema__",
                        child: Text("➕ Novo Tema"),
                      ),
                    ],
                    onChanged: (value) async {
                      if (value == "__novo_tema__") {
                        mostrarDialogNovoTema();
                        return;
                      }

                      setState(() {
                        temaSelecionado = value;
                        subtemaSelecionado = null;
                        subtemas = [];
                      });

                      if (materiaSelecionada != null &&
                          value != null &&
                          value.isNotEmpty) {
                        await carregarSubtemas(materiaSelecionada!, value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: subtemaSelecionado,
                    decoration: _decoracaoCampo("Subtema"),
                    items: [
                      ...subtemas.map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(s),
                        ),
                      ),
                      const DropdownMenuItem(
                        value: "__novo_subtema__",
                        child: Text("➕ Novo Subtema"),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == "__novo_subtema__") {
                        mostrarDialogNovoSubtema();
                        return;
                      }

                      setState(() {
                        subtemaSelecionado = value;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildEditorCard(
                    titulo: "Pergunta",
                    controller: perguntaController,
                    focusNode: perguntaFocusNode,
                    scrollController: perguntaScrollController,
                    campo: "pergunta",
                    altura: 240,
                  ),
                  const SizedBox(height: 16),
                  _buildEditorCard(
                    titulo: "Resposta",
                    controller: respostaController,
                    focusNode: respostaFocusNode,
                    scrollController: respostaScrollController,
                    campo: "resposta",
                    altura: 240,
                  ),
                  const SizedBox(height: 16),
                  _buildEditorCard(
                    titulo: "Explicação",
                    controller: explicacaoController,
                    focusNode: explicacaoFocusNode,
                    scrollController: explicacaoScrollController,
                    campo: "explicacao",
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