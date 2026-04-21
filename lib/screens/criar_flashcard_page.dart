import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/firebase_service.dart';
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
  final perguntaController = TextEditingController();
  final respostaController = TextEditingController();
  final explicacaoController = TextEditingController();

  final FirebaseService firebaseService = FirebaseService();
  final ImagePicker picker = ImagePicker();

  File? imagemPergunta;
  File? imagemResposta;

  String imagemPerguntaUrlAtual = '';
  String imagemRespostaUrlAtual = '';

  List<String> materias = [];
  List<String> temas = [];
  List<String> subtemas = [];

  String? materiaSelecionada;
  String? temaSelecionado;
  String? subtemaSelecionado;

  bool carregando = true;
  bool salvando = false;

  bool get modoEdicao => widget.cardId != null && widget.dados != null;

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
    super.dispose();
  }

  Future<void> carregarMaterias() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('flashcards').get();

    final set = <String>{};

    for (var doc in snapshot.docs) {
      final materia = (doc.data()['materia'] ?? '').toString().trim();
      if (materia.isNotEmpty) {
        set.add(materia);
      }
    }

    final lista = set.toList()..sort();

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

    perguntaController.text = (dados['pergunta'] ?? '').toString();
    respostaController.text = (dados['resposta'] ?? '').toString();
    explicacaoController.text = (dados['explicacao'] ?? '').toString();

    materiaSelecionada = (dados['materia'] ?? '').toString().trim();
    temaSelecionado = (dados['tema'] ?? '').toString().trim();
    subtemaSelecionado = (dados['subtema'] ?? '').toString().trim();

    imagemPerguntaUrlAtual = (dados['imagemPergunta'] ?? '').toString();
    imagemRespostaUrlAtual = (dados['imagemResposta'] ?? '').toString();

    if (materiaSelecionada != null && materiaSelecionada!.isNotEmpty) {
      await carregarTemas(materiaSelecionada!, silencioso: true);
    }

    if (materiaSelecionada != null &&
        materiaSelecionada!.isNotEmpty &&
        temaSelecionado != null &&
        temaSelecionado!.isNotEmpty) {
      await carregarSubtemas(
        materiaSelecionada!,
        temaSelecionado!,
        silencioso: true,
      );
    }

    if (!mounted) return;

    setState(() {
      if (materiaSelecionada != null &&
          materiaSelecionada!.isNotEmpty &&
          !materias.contains(materiaSelecionada)) {
        materias.add(materiaSelecionada!);
        materias.sort();
      }

      if (temaSelecionado != null &&
          temaSelecionado!.isNotEmpty &&
          !temas.contains(temaSelecionado)) {
        temas.add(temaSelecionado!);
        temas.sort();
      }

      if (subtemaSelecionado != null &&
          subtemaSelecionado!.isNotEmpty &&
          !subtemas.contains(subtemaSelecionado)) {
        subtemas.add(subtemaSelecionado!);
        subtemas.sort();
      }

      carregando = false;
    });
  }

  Future<void> carregarTemas(String materia, {bool silencioso = false}) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('flashcards')
        .where('materia', isEqualTo: materia)
        .get();

    final set = <String>{};

    for (var doc in snapshot.docs) {
      final tema = (doc.data()['tema'] ?? '').toString().trim();
      if (tema.isNotEmpty) {
        set.add(tema);
      }
    }

    final lista = set.toList()..sort();

    if (!mounted) return;

    setState(() {
      temas = lista;
      if (!silencioso) {
        subtemas = [];
      }
    });
  }

  Future<void> carregarSubtemas(
    String materia,
    String tema, {
    bool silencioso = false,
  }) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('flashcards')
        .where('materia', isEqualTo: materia)
        .where('tema', isEqualTo: tema)
        .get();

    final set = <String>{};

    for (var doc in snapshot.docs) {
      final subtema = (doc.data()['subtema'] ?? '').toString().trim();
      if (subtema.isNotEmpty) {
        set.add(subtema);
      }
    }

    final lista = set.toList()..sort();

    if (!mounted) return;

    setState(() {
      subtemas = lista;
      if (!silencioso) {}
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

  Future<void> selecionarImagemPergunta() async {
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        imagemPergunta = File(image.path);
      });
    }
  }

  Future<void> selecionarImagemResposta() async {
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        imagemResposta = File(image.path);
      });
    }
  }

  Future<void> salvarCard() async {
    if (salvando) return;

    final pergunta = perguntaController.text.trim();
    final resposta = respostaController.text.trim();
    final explicacao = explicacaoController.text.trim();

    if (materiaSelecionada == null ||
        materiaSelecionada!.trim().isEmpty ||
        temaSelecionado == null ||
        temaSelecionado!.trim().isEmpty ||
        subtemaSelecionado == null ||
        subtemaSelecionado!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Preencha matéria, tema e subtema")),
      );
      return;
    }

    if (pergunta.isEmpty || resposta.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Preencha pergunta e resposta")),
      );
      return;
    }

    setState(() {
      salvando = true;
    });

    try {
      if (modoEdicao) {
        await firebaseService.atualizarCard(
          cardId: widget.cardId!,
          materia: materiaSelecionada!.trim(),
          tema: temaSelecionado!.trim(),
          subtema: subtemaSelecionado!.trim(),
          pergunta: pergunta,
          resposta: resposta,
          explicacao: explicacao,
          novaImagemPergunta: imagemPergunta,
          novaImagemResposta: imagemResposta,
          imagemPerguntaAtual: imagemPerguntaUrlAtual,
          imagemRespostaAtual: imagemRespostaUrlAtual,
        );
      } else {
        await firebaseService.adicionarCard(
          materia: materiaSelecionada!.trim(),
          tema: temaSelecionado!.trim(),
          subtema: subtemaSelecionado!.trim(),
          pergunta: pergunta,
          resposta: resposta,
          explicacao: explicacao,
          imagemPergunta: imagemPergunta,
          imagemResposta: imagemResposta,
        );
      }

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

  InputDecoration _decoracaoCampo(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildPreviewImagem({
    required String titulo,
    required File? arquivo,
    required String urlAtual,
  }) {
    return Container(
      width: double.infinity,
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
            ),
          ),
          const SizedBox(height: 8),
          if (arquivo != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                arquivo,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else if (urlAtual.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                urlAtual,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else
            const Text('Nenhuma imagem selecionada'),
        ],
      ),
    );
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
                    value: materiaSelecionada,
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
                    value: temaSelecionado,
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
                    value: subtemaSelecionado,
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
                  const SizedBox(height: 16),
                  TextField(
                    controller: perguntaController,
                    maxLines: 3,
                    decoration: _decoracaoCampo("Pergunta"),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: respostaController,
                    maxLines: 3,
                    decoration: _decoracaoCampo("Resposta"),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: explicacaoController,
                    maxLines: 4,
                    decoration: _decoracaoCampo("Explicação"),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: selecionarImagemPergunta,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1E3A8A),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      imagemPergunta == null
                          ? (imagemPerguntaUrlAtual.isNotEmpty
                              ? "Trocar imagem da pergunta"
                              : "Selecionar imagem da pergunta")
                          : "Imagem da pergunta selecionada",
                    ),
                  ),
                                    const SizedBox(height: 10),
                  _buildPreviewImagem(
                    titulo: 'Prévia da imagem da pergunta',
                    arquivo: imagemPergunta,
                    urlAtual: imagemPerguntaUrlAtual,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: selecionarImagemResposta,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1E3A8A),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      imagemResposta == null
                          ? (imagemRespostaUrlAtual.isNotEmpty
                              ? "Trocar imagem da resposta"
                              : "Selecionar imagem da resposta")
                          : "Imagem da resposta selecionada",
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildPreviewImagem(
                    titulo: 'Prévia da imagem da resposta',
                    arquivo: imagemResposta,
                    urlAtual: imagemRespostaUrlAtual,
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