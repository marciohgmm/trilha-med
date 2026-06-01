import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/firebase_service.dart';
import 'package:flutter_application_1/utils/flashcard_study_order.dart';

/// Define a ordem de estudo (campo [ordemEstudo]) para cards de um subtema.
class ReordenarFlashcardsPage extends StatefulWidget {
  const ReordenarFlashcardsPage({super.key});

  @override
  State<ReordenarFlashcardsPage> createState() => _ReordenarFlashcardsPageState();
}

class _ReordenarFlashcardsPageState extends State<ReordenarFlashcardsPage> {
  final FirebaseService _firebase = FirebaseService();

  String? _materia;
  String? _subtema;

  /// Última lista de ids recebida do servidor (após filtro + ordenação base).
  String _serverKey = '';

  /// Ordem editável pelo usuário (arrastar).
  final List<String> _orderedIds = [];

  /// Se true, mudanças no Firestore só acrescentam/removem ids sem reordenar o restante.
  bool _dirty = false;

  bool _salvando = false;

  static bool _mesmoSubtema(Map<String, dynamic> d, String m, String s) {
    return (d['materia'] ?? '').toString() == m &&
        (d['subtema'] ?? '').toString() == s;
  }

  List<String> _unicos(Iterable<String> raw) {
    final s = raw.where((e) => e.trim().isNotEmpty).toSet().toList()..sort();
    return s;
  }

  String _previewPergunta(dynamic pergunta) {
    final t = pergunta?.toString() ?? '';
    if (t.length <= 120) return t.trim();
    return '${t.trim().substring(0, 117)}…';
  }

  void _syncOrderedIdsFromServer(List<QueryDocumentSnapshot> filtrados) {
    sortFlashcardDocsPorEstudo(filtrados);
    final ids = filtrados.map((d) => d.id).toList();
    final key = ids.join('\x1e');
    if (key == _serverKey) return;

    setState(() {
      _serverKey = key;
      if (!_dirty) {
        _orderedIds
          ..clear()
          ..addAll(ids);
      } else {
        final setIds = ids.toSet();
        _orderedIds.removeWhere((id) => !setIds.contains(id));
        for (final id in ids) {
          if (!_orderedIds.contains(id)) _orderedIds.add(id);
        }
      }
    });
  }

  void _resetOrdemDoServidor(List<QueryDocumentSnapshot> filtrados) {
    sortFlashcardDocsPorEstudo(filtrados);
    setState(() {
      _dirty = false;
      _serverKey = filtrados.map((d) => d.id).join('\x1e');
      _orderedIds
        ..clear()
        ..addAll(filtrados.map((d) => d.id));
    });
  }

  bool get _podeSalvar =>
      _materia != null && _subtema != null && _orderedIds.isNotEmpty;

  Future<void> _salvarOrdem() async {
    if (!_podeSalvar || _materia == null || _subtema == null) return;
    setState(() => _salvando = true);
    try {
      await _firebase.reordenarFlashcardsNoSubtema(
        materia: _materia!,
        subtema: _subtema!,
        orderedCardIds: List<String>.from(_orderedIds),
      );
      if (!mounted) return;
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ordem de estudo salva.'),
          backgroundColor: Color(0xFF1E3A8A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar ordem: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        title: const Text('Ordem de estudo'),
        actions: [
          if (_podeSalvar)
            TextButton(
              onPressed: _salvando ? null : _salvarOrdem,
              child: _salvando
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Salvar',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firebase.listarCardsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Erro ao carregar: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('Nenhum flashcard cadastrado.'));
          }

          final materias = _unicos(docs.map((d) => (d.data() as Map)['materia']?.toString() ?? ''));
          final subtemas = _materia != null
              ? _unicos(
                  docs
                      .where((d) =>
                          (d.data() as Map)['materia']?.toString() == _materia)
                      .map((d) => (d.data() as Map)['subtema']?.toString() ?? ''),
                )
              : <String>[];

          if (_materia != null && !materias.contains(_materia)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _materia = null;
                _subtema = null;
                _dirty = false;
                _serverKey = '';
                _orderedIds.clear();
              });
            });
          }
          if (_subtema != null && !subtemas.contains(_subtema)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _subtema = null;
                _dirty = false;
                _serverKey = '';
                _orderedIds.clear();
              });
            });
          }

          final filtrados = docs.where((d) {
            if (_materia == null || _subtema == null) return false;
            return _mesmoSubtema(
                d.data() as Map<String, dynamic>, _materia!, _subtema!);
          }).toList();

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_materia != null && _subtema != null) {
              _syncOrderedIdsFromServer(filtrados);
            }
          });

          final mapPorId = <String, Map<String, dynamic>>{};
          for (final d in filtrados) {
            mapPorId[d.id] = d.data() as Map<String, dynamic>;
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Escolha matéria e subtema. Arraste os cards para a ordem desejada e toque em Salvar.',
                style: TextStyle(fontSize: 15, height: 1.35),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey('m_${materias.length}'),
                initialValue: _materia != null && materias.contains(_materia) ? _materia : null,
                decoration: const InputDecoration(
                  labelText: 'Matéria',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: materias
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _materia = v;
                    _subtema = null;
                    _dirty = false;
                    _serverKey = '';
                    _orderedIds.clear();
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('s_${_materia}_${subtemas.length}'),
                initialValue:
                    _subtema != null && subtemas.contains(_subtema) ? _subtema : null,
                decoration: const InputDecoration(
                  labelText: 'Subtema',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: subtemas
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: _materia == null
                    ? null
                    : (v) {
                        setState(() {
                          _subtema = v;
                          _dirty = false;
                          _serverKey = '';
                          _orderedIds.clear();
                        });
                      },
              ),
              const SizedBox(height: 20),
              if (_materia != null && _subtema != null) ...[
                Row(
                  children: [
                    Text(
                      '${filtrados.length} card(s)',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: filtrados.isEmpty ? null : () => _resetOrdemDoServidor(filtrados),
                      icon: const Icon(Icons.restore),
                      label: const Text('Restaurar ordem atual'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (filtrados.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Nenhum card neste subtema.'),
                    ),
                  )
                else
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: _orderedIds.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        _dirty = true;
                        if (newIndex > oldIndex) newIndex -= 1;
                        final id = _orderedIds.removeAt(oldIndex);
                        _orderedIds.insert(newIndex, id);
                      });
                    },
                    proxyDecorator: (child, index, animation) {
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (_, c) {
                          final t = Curves.easeInOut.transform(animation.value);
                          return Transform.scale(
                            scale: 1.0 + 0.02 * t,
                            child: Material(
                              elevation: 6 * t,
                              borderRadius: BorderRadius.circular(12),
                              child: c,
                            ),
                          );
                        },
                        child: child,
                      );
                    },
                    itemBuilder: (context, index) {
                      final id = _orderedIds[index];
                      final data = mapPorId[id];
                      final preview = _previewPergunta(data?['pergunta']);

                      return Card(
                        key: ValueKey<String>(id),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: ReorderableDragStartListener(
                            index: index,
                            child: const Icon(Icons.drag_handle, size: 28),
                          ),
                          title: Text(
                            preview.isEmpty ? '(sem pergunta)' : preview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            'ordemEstudo: ${data == null ? "—" : (flashcardOrdemEstudoNullable(data)?.toString() ?? "—")}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
