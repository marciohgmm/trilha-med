import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/practical_phase_model.dart';
import 'practical_phase_constants.dart';

class PracticalPhaseModelCard extends StatelessWidget {
  final PracticalPhaseModel model;
  final VoidCallback onOpen;
  final bool showAdminStatus;

  const PracticalPhaseModelCard({
    super.key,
    required this.model,
    required this.onOpen,
    this.showAdminStatus = false,
  });

  Color _statusColor() {
    if (!model.isActive) return Colors.grey;
    if (!model.isPublished) return PracticalPhaseColors.warning;
    return PracticalPhaseColors.success;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 100,
              child: model.thumbnailUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: model.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _thumbPlaceholder(),
                    )
                  : _thumbPlaceholder(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showAdminStatus)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor().withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          model.displayStatus,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _statusColor(),
                          ),
                        ),
                      ),
                    Text(
                      model.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      model.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: PracticalPhaseColors.muted,
                        height: 1.3,
                      ),
                    ),
                    const Spacer(),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _chip(model.category),
                        if (model.specialty.isNotEmpty)
                          _chip(model.specialty, filled: false),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.layers_outlined,
                            size: 14, color: PracticalPhaseColors.muted),
                        const SizedBox(width: 4),
                        Text(
                          '${model.sections.length} seções • ${model.stationCount} itens',
                          style: const TextStyle(
                            fontSize: 11,
                            color: PracticalPhaseColors.muted,
                          ),
                        ),
                        const Spacer(),
                        _chip(model.difficulty, filled: false),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: onOpen,
                        style: FilledButton.styleFrom(
                          backgroundColor: PracticalPhaseColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Abrir'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      color: PracticalPhaseColors.primary.withValues(alpha: 0.08),
      child: const Center(
        child: Icon(
          Icons.medical_services_outlined,
          size: 40,
          color: PracticalPhaseColors.primary,
        ),
      ),
    );
  }

  Widget _chip(String label, {bool filled = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled
            ? PracticalPhaseColors.primary.withValues(alpha: 0.1)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: filled
              ? PracticalPhaseColors.primary
              : PracticalPhaseColors.muted,
        ),
      ),
    );
  }
}
