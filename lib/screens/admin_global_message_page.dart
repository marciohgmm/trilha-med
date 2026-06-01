import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/global_message_service.dart';

class AdminGlobalMessagePage extends StatefulWidget {
  const AdminGlobalMessagePage({super.key});

  @override
  State<AdminGlobalMessagePage> createState() => _AdminGlobalMessagePageState();
}

class _AdminGlobalMessagePageState extends State<AdminGlobalMessagePage> {
  final TextEditingController _mensagem = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _mensagem.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_enviando) return;
    final texto = _mensagem.text.trim();
    if (texto.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite a mensagem.')),
      );
      return;
    }

    setState(() => _enviando = true);
    try {
      await GlobalMessageService.instance.enviarMensagemParaTodos(texto);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mensagem enviada a todos os usuários.')),
      );
      _mensagem.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao enviar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Mensagem global'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Enviar mensagem para todos os usuários',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cada usuário verá o aviso uma vez por versão da mensagem. '
            'Novos envios geram nova versão e o popup volta a aparecer.',
            style: TextStyle(
                fontSize: 14, color: Colors.grey.shade800, height: 1.4),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _mensagem,
            minLines: 5,
            maxLines: 12,
            decoration: InputDecoration(
              labelText: 'Mensagem',
              hintText:
                  'Ex.: Novos flashcards adicionados.\nAtualize o aplicativo na Play Store.',
              alignLabelWithHint: true,
              filled: true,
              fillColor: Colors.white,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _enviando ? null : _enviar,
            icon: _enviando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(_enviando
                ? 'Enviando…'
                : 'Enviar mensagem para todos os usuários'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            ),
          ),
        ],
      ),
    );
  }
}
