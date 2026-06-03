import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/practical_phase_model.dart';
import '../../services/practical_phase_service.dart';
import '../../widgets/practical_phase/practical_phase_access_error.dart';
import '../../widgets/practical_phase/practical_phase_constants.dart';
import '../../widgets/practical_phase/practical_phase_premium_gate.dart';

/// Detalhe de um modelo/estação — conteúdo protegido por Premium.
class PracticalPhaseDetailPage extends StatelessWidget {
  final String modelId;
  final String userId;

  const PracticalPhaseDetailPage({
    super.key,
    required this.modelId,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PracticalPhaseColors.background,
      appBar: AppBar(
        title: const Text('Modelo'),
        backgroundColor: PracticalPhaseColors.primary,
        foregroundColor: Colors.white,
      ),
      body: PracticalPhasePremiumGate(
        userId: userId,
        screenName: 'practical_phase_detail',
        child: _PracticalPhaseDetailContent(
          modelId: modelId,
          userId: userId,
        ),
      ),
    );
  }
}

class _PracticalPhaseDetailContent extends StatelessWidget {
  const _PracticalPhaseDetailContent({
    required this.modelId,
    required this.userId,
  });

  final String modelId;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final service = PracticalPhaseService();

    return FutureBuilder<PracticalPhaseModel?>(
      future: service.getById(modelId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          if (PracticalPhaseAccessError.isPermissionDenied(snapshot.error)) {
            return PracticalPhaseAccessError.permissionDenied(
              context: context,
              userId: userId,
            );
          }
          return Center(child: Text('Erro: ${snapshot.error}'));
        }
        final model = snapshot.data;
        if (model == null) {
          return const Center(child: Text('Modelo não encontrado.'));
        }
        if (!model.visibleToStudents) {
          return const Center(
            child: Text('Este modelo não está disponível.'),
          );
        }

        return SingleChildScrollView(
          padding: PracticalPhaseInsets.page(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                model.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: PracticalPhaseColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  Chip(label: Text(model.category)),
                  Chip(label: Text(model.specialty)),
                  Chip(label: Text(model.difficulty)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                model.description,
                style: const TextStyle(fontSize: 15, height: 1.45),
              ),
              if (model.attachments.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Materiais de apoio',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: PracticalPhaseColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                ...model.attachments.map(
                  (a) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.attach_file),
                      title: Text(a.name),
                      subtitle: Text(
                        '${a.type.toUpperCase()} • ${_formatSize(a.size)}',
                      ),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () => _openUrl(context, a.url),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              const Text(
                'Estações / seções',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: PracticalPhaseColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              if (model.sections.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Nenhuma seção cadastrada neste modelo.'),
                  ),
                )
              else
                ...model.sections.map(
                  (s) => _SectionTile(section: s),
                ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Modo treino: percorra as seções acima. '
                        'Timer e checklist interativo podem ser ligados ao backend.',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Iniciar treino'),
                style: FilledButton.styleFrom(
                  backgroundColor: PracticalPhaseColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '—';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o arquivo.')),
        );
      }
    }
  }
}

class _SectionTile extends StatelessWidget {
  final PracticalPhaseSection section;

  const _SectionTile({required this.section});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ExpansionTile(
        title: Text(
          section.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: section.description.isNotEmpty
            ? Text(section.description, maxLines: 2)
            : null,
        children: section.items.isEmpty
            ? const [
                ListTile(
                  title: Text('Sem itens nesta seção.'),
                ),
              ]
            : section.items
                .map(
                  (item) => ListTile(
                    title: Text(item.title),
                    subtitle: Text(
                      item.content,
                      style: const TextStyle(height: 1.35),
                    ),
                    leading: Icon(
                      item.type == 'checklist'
                          ? Icons.checklist
                          : Icons.notes,
                      color: PracticalPhaseColors.primary,
                    ),
                  ),
                )
                .toList(),
      ),
    );
  }
}
