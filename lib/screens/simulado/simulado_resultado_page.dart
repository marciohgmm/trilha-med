import 'package:flutter/material.dart';

import 'simulado_historico_page.dart';

class SimuladoResultadoPage extends StatelessWidget {
  final String userId;
  final int totalQuestoes;
  final int acertos;
  final int erros;
  final int naoRespondidas;
  final int tempoSegundos;

  const SimuladoResultadoPage({
    super.key,
    required this.userId,
    required this.totalQuestoes,
    required this.acertos,
    required this.erros,
    required this.naoRespondidas,
    required this.tempoSegundos,
  });

  String _formatarTempo(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final respondidas = acertos + erros;
    final percentual =
        respondidas > 0 ? (acertos / respondidas * 100).round() : 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Simulado finalizado'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(
                Icons.emoji_events_outlined,
                size: 72,
                color: Color(0xFF1E3A8A),
              ),
              const SizedBox(height: 16),
              Text(
                '$percentual%',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              const Text(
                'de acerto nas respondidas',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 8),
              const Text(
                'Resultado salvo na sua conta',
                style: TextStyle(fontSize: 13, color: Color(0xFF059669)),
              ),
              const SizedBox(height: 28),
              _statRow('Questões', '$totalQuestoes'),
              _statRow('Acertos', '$acertos', color: const Color(0xFF059669)),
              _statRow('Erros', '$erros', color: const Color(0xFFDC2626)),
              if (naoRespondidas > 0)
                _statRow('Não respondidas', '$naoRespondidas'),
              _statRow('Tempo', _formatarTempo(tempoSegundos)),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Voltar às questões'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SimuladoHistoricoPage(userId: userId),
                      ),
                    );
                  },
                  icon: const Icon(Icons.history),
                  label: const Text('Ver histórico de simulados'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color ?? const Color(0xFF1E3A8A),
            ),
          ),
        ],
      ),
    );
  }
}
