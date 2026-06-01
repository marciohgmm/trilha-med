import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth/credenciais_salvas_service.dart';

/// Exclusão de conta (LGPD Art. 18, VI) — confirmação dupla + Cloud Function.
class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key, required this.userId});

  final String userId;

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final _confirmController = TextEditingController();
  bool _loading = false;
  bool _understood = false;

  static const _phrase = 'EXCLUIR';

  Future<void> _delete() async {
    if (_loading) return;
    if (_confirmController.text.trim().toUpperCase() != _phrase) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite EXCLUIR para confirmar.')),
      );
      return;
    }

    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Última confirmação'),
        content: const Text(
          'Esta ação é irreversível. Seus dados de estudo serão apagados. '
          'Registros financeiros podem ser mantidos de forma anonimizada por obrigação legal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir permanentemente'),
          ),
        ],
      ),
    );

    if (sure != true || !mounted) return;

    setState(() => _loading = true);
    try {
      final functions =
          FirebaseFunctions.instanceFor(region: 'southamerica-east1');
      await functions.httpsCallable('deleteMyAccount').call({
        'confirmation': _phrase,
      });
      await CredenciaisSalvasService().apagarCredenciais();
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conta excluída com sucesso.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Erro ao excluir conta.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Excluir conta'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Ao excluir sua conta:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            const Text(
              '• Seu perfil e progresso de estudo serão removidos.\n'
              '• Você não poderá recuperar o acesso com este e-mail.\n'
              '• Pagamentos e registros de auditoria financeira podem ser preservados '
              'sem dados identificáveis, conforme a lei.',
            ),
            const SizedBox(height: 24),
            CheckboxListTile(
              value: _understood,
              onChanged:
                  _loading ? null : (v) => setState(() => _understood = v ?? false),
              title: const Text('Entendo que a exclusão é permanente'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            TextField(
              controller: _confirmController,
              enabled: !_loading,
              decoration: const InputDecoration(
                labelText: 'Digite EXCLUIR para confirmar',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const Spacer(),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _understood && !_loading ? _delete : null,
              child: _loading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Excluir minha conta'),
            ),
          ],
        ),
      ),
    );
  }
}
