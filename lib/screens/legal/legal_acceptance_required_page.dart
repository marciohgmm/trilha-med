import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/legal/legal_versions.dart';
import '../../services/legal/legal_acceptance_service.dart';
import 'privacy_policy_page.dart';
import 'terms_of_use_page.dart';

/// Tela de aceite obrigatório (novo cadastro ou nova versão legal).
class LegalAcceptanceRequiredPage extends StatefulWidget {
  const LegalAcceptanceRequiredPage({super.key, required this.userId});

  final String userId;

  @override
  State<LegalAcceptanceRequiredPage> createState() =>
      _LegalAcceptanceRequiredPageState();
}

class _LegalAcceptanceRequiredPageState
    extends State<LegalAcceptanceRequiredPage> {
  bool _checked = false;
  bool _loading = false;

  Future<void> _accept() async {
    if (!_checked || _loading) return;
    setState(() => _loading = true);
    try {
      await LegalAcceptanceService().recordAcceptance(userId: widget.userId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao registrar aceite: $e')),
      );
      setState(() => _loading = false);
      return;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Termos e Privacidade'),
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Para continuar, leia e aceite os documentos abaixo.',
              style: TextStyle(fontSize: 16, height: 1.4),
            ),
            const SizedBox(height: 8),
            Text(
              'Política v${LegalVersions.policyVersion} · Termos v${LegalVersions.termsVersion}',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Política de Privacidade'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Termos de Uso'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TermsOfUsePage()),
              ),
            ),
            const Spacer(),
            CheckboxListTile(
              value: _checked,
              onChanged: _loading ? null : (v) => setState(() => _checked = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 14),
                  children: [
                    const TextSpan(text: 'Li e aceito a '),
                    TextSpan(
                      text: 'Política de Privacidade',
                      style: const TextStyle(
                        color: Color(0xFF1E3A8A),
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const PrivacyPolicyPage(),
                              ),
                            ),
                    ),
                    const TextSpan(text: ' e os '),
                    TextSpan(
                      text: 'Termos de Uso',
                      style: const TextStyle(
                        color: Color(0xFF1E3A8A),
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const TermsOfUsePage(),
                              ),
                            ),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _checked && !_loading ? _accept : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
  }
}
