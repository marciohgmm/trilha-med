import 'package:flutter/material.dart';

import '../../core/legal/legal_acceptance_record.dart';
import '../../core/legal/legal_versions.dart';
import '../../services/legal/export_my_data_service.dart';
import '../../services/legal/legal_acceptance_service.dart';
import 'delete_account_page.dart';
import 'privacy_policy_page.dart';
import 'terms_of_use_page.dart';

/// Central de Privacidade (LGPD).
class PrivacyCenterPage extends StatefulWidget {
  const PrivacyCenterPage({super.key, required this.userId});

  final String userId;

  @override
  State<PrivacyCenterPage> createState() => _PrivacyCenterPageState();
}

class _PrivacyCenterPageState extends State<PrivacyCenterPage> {
  bool _exporting = false;
  LegalAcceptanceRecord? _latestAcceptance;

  @override
  void initState() {
    super.initState();
    _loadAcceptance();
  }

  Future<void> _loadAcceptance() async {
    final latest =
        await LegalAcceptanceService().getLatestAcceptance(widget.userId);
    if (mounted) setState(() => _latestAcceptance = latest);
  }

  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await ExportMyDataService().exportAndShare(widget.userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exportação gerada com sucesso.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro na exportação: $e')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final latest = _latestAcceptance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacidade e dados'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Política de Privacidade'),
            subtitle: Text('Versão ${LegalVersions.policyVersion}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Termos de Uso'),
            subtitle: Text('Versão ${LegalVersions.termsVersion}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TermsOfUsePage()),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Exportar meus dados'),
            subtitle: const Text('Arquivo JSON com seus dados pessoais'),
            trailing: _exporting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: _exporting ? null : _export,
          ),
          ListTile(
            leading: Icon(Icons.delete_forever, color: Colors.red.shade700),
            title: Text(
              'Excluir minha conta',
              style: TextStyle(color: Colors.red.shade700),
            ),
            subtitle: const Text('Eliminação permanente dos dados da conta'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DeleteAccountPage(userId: widget.userId),
              ),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Consentimentos registrados',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 8),
                if (latest == null)
                  const Text('Nenhum aceite registrado.')
                else ...[
                  Text(
                    'Último aceite: ${latest.acceptedAt.toLocal()}',
                  ),
                  Text('Política: v${latest.policyVersion}'),
                  Text('Termos: v${latest.termsVersion}'),
                  Text('Plataforma: ${latest.platform} · App ${latest.appVersion}'),
                  if (!latest.coversCurrentVersions())
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Há nova versão dos documentos — você será solicitado a aceitar ao abrir o app.',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                Text(
                  'Contato LGPD: ${LegalVersions.privacyContactEmail}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
