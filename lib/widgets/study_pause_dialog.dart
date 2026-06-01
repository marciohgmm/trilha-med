import 'package:flutter/material.dart';

import '../services/study_timer_service.dart';

/// Diálogo de pausa com mensagem motivacional e cronômetro regressivo.
class StudyPauseDialog {
  StudyPauseDialog._();

  static void show(BuildContext context, StudyTimerService service) {
    final message = service.pickRandomPauseMessage();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _StudyPauseDialogBody(
        service: service,
        message: message,
      ),
    );
  }
}

class _StudyPauseDialogBody extends StatelessWidget {
  final StudyTimerService service;
  final String message;

  const _StudyPauseDialogBody({
    required this.service,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: service.pauseTimeStream,
      builder: (context, snapshot) {
        final remaining = snapshot.data ?? service.pauseTime;
        final minutes = remaining.inMinutes;
        final seconds = remaining.inSeconds % 60;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.spa_outlined,
                  color: Color(0xFF0D9488),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Pausa ativa',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: Color(0xFF1E3A8A),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4F8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Tempo restante',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                service.retomarEstudoAposPausa();
                Navigator.of(context).pop();
              },
              child: const Text('Voltar a estudar agora'),
            ),
          ],
        );
      },
    );
  }
}
