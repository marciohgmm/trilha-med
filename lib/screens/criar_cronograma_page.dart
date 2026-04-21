import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/cronograma_service.dart';

class CriarCronogramaPage extends StatefulWidget {
  final String userId;

  const CriarCronogramaPage({
    super.key,
    required this.userId,
  });

  @override
  State<CriarCronogramaPage> createState() => _CriarCronogramaPageState();
}

class _CriarCronogramaPageState extends State<CriarCronogramaPage> {
  final CronogramaService service = CronogramaService();

  bool carregando = false;
  bool temCronogramaExistente = false;

  DateTime? dataProva;

  @override
  void initState() {
    super.initState();
    _verificarCronogramaExistente();
  }

  Future<void> _verificarCronogramaExistente() async {
    try {
      final meta = await service.metaCronograma(widget.userId).first;

      final rawData = meta.data();
      final data = rawData is Map<String, dynamic> ? rawData : null;

      if (!mounted) return;

      setState(() {
        temCronogramaExistente = meta.exists && data != null;

        if (data != null && data['dataProva'] != null) {
          dataProva = (data['dataProva'] as Timestamp).toDate();
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao carregar cronograma: $e")),
      );
    }
  }

  Future<void> selecionarData() async {
    final agora = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: dataProva ?? agora.add(const Duration(days: 30)),
      firstDate: DateTime(agora.year, agora.month, agora.day),
      lastDate: DateTime(2100),
    );

    if (picked != null && mounted) {
      setState(() => dataProva = picked);
    }
  }

  Future<void> salvarData() async {
    if (dataProva == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecione a data da prova")),
      );
      return;
    }

    setState(() => carregando = true);

    try {
      if (temCronogramaExistente) {
        await service.salvarDataProva(
          userId: widget.userId,
          dataProva: dataProva!,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Data da prova atualizada!"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        await service.criarCronogramaInicial(
          userId: widget.userId,
          dataProva: dataProva!,
        );

        if (!mounted) return;
        setState(() => temCronogramaExistente = true);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Cronograma criado com sucesso!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => carregando = false);
      }
    }
  }

  Future<void> excluirCronograma() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Excluir cronograma"),
        content: const Text(
          "Isso apagará todo o seu progresso. Tem certeza?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Excluir"),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() => carregando = true);

    try {
      await service.excluirCronograma(widget.userId);

      if (!mounted) return;

      setState(() {
        temCronogramaExistente = false;
        dataProva = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cronograma excluído!")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => carregando = false);
      }
    }
  }

  String _formatarData(DateTime data) {
    return "${data.day.toString().padLeft(2, '0')}/"
        "${data.month.toString().padLeft(2, '0')}/"
        "${data.year}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          temCronogramaExistente ? "Editar Cronograma" : "Criar Cronograma",
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: carregando
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: ListTile(
                      title: const Text("Data da prova"),
                      subtitle: Text(
                        dataProva == null
                            ? "Selecione a data da prova"
                            : _formatarData(dataProva!),
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: selecionarData,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: dataProva != null ? salvarData : null,
                    icon: const Icon(Icons.save),
                    label: Text(
                      temCronogramaExistente
                          ? "Salvar nova data da prova"
                          : "Criar Cronograma",
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (temCronogramaExistente)
                    OutlinedButton.icon(
                      onPressed: excluirCronograma,
                      icon: const Icon(Icons.delete),
                      label: const Text("Excluir Cronograma"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}