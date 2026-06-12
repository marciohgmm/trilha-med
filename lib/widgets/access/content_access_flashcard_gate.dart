import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../application/platform/platform_registry.dart';
import '../../core/access/app_access_feature.dart';
import '../../models/access_usage_stats.dart';
import 'free_limit_reached_view.dart';

/// Consome cota de flashcard na primeira exibição real (pós-frame).
class ContentAccessFlashcardGate extends StatefulWidget {
  const ContentAccessFlashcardGate({
    super.key,
    required this.userId,
    required this.cardId,
    required this.child,
  });

  final String userId;
  final String cardId;
  final Widget child;

  @override
  State<ContentAccessFlashcardGate> createState() =>
      _ContentAccessFlashcardGateState();
}

class _ContentAccessFlashcardGateState extends State<ContentAccessFlashcardGate> {
  ConsumeResult? _block;
  String? _scheduledForCardId;

  @override
  void initState() {
    super.initState();
    _scheduleConsume();
  }

  @override
  void didUpdateWidget(ContentAccessFlashcardGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cardId != widget.cardId) {
      _block = null;
      _scheduledForCardId = null;
      _scheduleConsume();
    }
  }

  void _scheduleConsume() {
    final cardId = widget.cardId.trim();
    if (cardId.isEmpty || _scheduledForCardId == cardId) return;
    _scheduledForCardId = cardId;

    SchedulerBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || widget.cardId != cardId) return;
      final result = await PlatformRegistry.instance.contentAccess
          .tryConsumeFlashcard(userId: widget.userId, cardId: cardId);
      if (!mounted || widget.cardId != cardId) return;
      if (_isHardBlock(result)) {
        setState(() => _block = result);
      }
    });
  }

  bool _isHardBlock(ConsumeResult result) {
    return !result.allowed &&
        (result.reason == ContentAccessBlockReason.limitReached ||
            result.reason == ContentAccessBlockReason.featureDisabled);
  }

  @override
  Widget build(BuildContext context) {
    final block = _block;
    if (block != null && _isHardBlock(block)) {
      return FreeLimitReachedView(
        feature: AppAccessFeature.flashcards,
        limit: block.limit,
        used: block.used,
      );
    }
    return widget.child;
  }
}
