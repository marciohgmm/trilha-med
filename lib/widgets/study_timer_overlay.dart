import 'package:flutter/material.dart';
import '../services/study_timer_service.dart';

class StudyTimerOverlay extends StatefulWidget {
  const StudyTimerOverlay({super.key});

  @override
  State<StudyTimerOverlay> createState() => _StudyTimerOverlayState();
}

class _StudyTimerOverlayState extends State<StudyTimerOverlay> {
  final StudyTimerService _service = StudyTimerService();
  Duration _currentTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _service.studyTimeStream.listen((time) {
      if (mounted) {
        setState(() {
          _currentTime = time;
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (!_service.showFloatingClock || (!_service.isStudying && !_service.isPaused)) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 50,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _service.isStudying ? Icons.timer : Icons.pause,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              _formatDuration(_currentTime),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}