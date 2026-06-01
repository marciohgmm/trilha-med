import 'package:flutter/material.dart';

import '../../models/medical_tool_history_entry.dart';
import 'medical_tools_theme.dart';

class MedicalResultCard extends StatelessWidget {
  const MedicalResultCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.details = const [],
  });

  final String title;
  final String value;
  final String? subtitle;
  final List<String> details;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MedicalToolsTheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: MedicalToolsTheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: MedicalToolsTheme.primary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
          if (details.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...details.map(
              (d) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  d,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class MedicalHistorySection extends StatelessWidget {
  const MedicalHistorySection({
    super.key,
    required this.entries,
  });

  final List<MedicalToolHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        const Text(
          'Histórico recente',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: MedicalToolsTheme.primary,
          ),
        ),
        const SizedBox(height: 10),
        ...entries.take(5).map(
              (e) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  dense: true,
                  title: Text(
                    e.summary,
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(
                    _formatDate(e.calculatedAt),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year} $h:$m';
  }
}
