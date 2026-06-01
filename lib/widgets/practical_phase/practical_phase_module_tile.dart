import 'package:flutter/material.dart';

import '../../models/practical_phase_module.dart';
import 'practical_phase_constants.dart';

class PracticalPhaseModuleTile extends StatefulWidget {
  final PracticalPhaseModule module;
  final VoidCallback onTap;

  const PracticalPhaseModuleTile({
    super.key,
    required this.module,
    required this.onTap,
  });

  @override
  State<PracticalPhaseModuleTile> createState() =>
      _PracticalPhaseModuleTileState();
}

class _PracticalPhaseModuleTileState extends State<PracticalPhaseModuleTile> {
  bool _hovered = false;

  IconData _iconFor(String name) {
    switch (name) {
      case 'quiz':
        return Icons.quiz_outlined;
      case 'medical_information':
        return Icons.medical_information_outlined;
      case 'monitor_heart':
        return Icons.monitor_heart_outlined;
      case 'checklist':
        return Icons.checklist_rtl_outlined;
      case 'forum':
        return Icons.forum_outlined;
      case 'emergency':
        return Icons.emergency_outlined;
      case 'auto_stories':
        return Icons.auto_stories_outlined;
      default:
        return Icons.school_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = _hovered ? 1.02 : 1.0;
    final elevation = _hovered ? 12.0 : 4.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: PracticalPhaseColors.primary.withValues(alpha: 0.12),
                blurRadius: elevation,
                offset: Offset(0, elevation / 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: PracticalPhaseColors.primary
                            .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        _iconFor(widget.module.iconName),
                        color: PracticalPhaseColors.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      widget.module.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Text(
                        widget.module.description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: PracticalPhaseColors.muted,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          widget.module.actionLabel,
                          style: const TextStyle(
                            color: PracticalPhaseColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward,
                          size: 16,
                          color: PracticalPhaseColors.primary
                              .withValues(alpha: _hovered ? 1 : 0.7),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
