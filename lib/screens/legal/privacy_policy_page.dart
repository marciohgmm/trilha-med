import 'package:flutter/material.dart';

import '../../core/legal/legal_versions.dart';

/// Política de Privacidade — versão [LegalVersions.policyVersion].
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Política de Privacidade'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Versão ${LegalVersions.policyVersion}',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.grey.shade700,
                ),
          ),
          const SizedBox(height: 16),
          const _Section(
            title: '1. Controlador',
            body:
                'O aplicativo Trilha Med / Revalida Cards é operado para fins educacionais '
                'de preparação para exames. Para questões de privacidade e direitos do titular, '
                'entre em contato: ${LegalVersions.privacyContactEmail}.',
          ),
          const _Section(
            title: '2. Dados que coletamos',
            body:
                '• Dados de cadastro: e-mail e identificador de conta.\n'
                '• Dados de perfil opcionais: nome, telefone, cidade.\n'
                '• Dados de uso: progresso em flashcards e questões, cronograma, simulados, '
                'participação em OSCE e eventos ao vivo.\n'
                '• Dados técnicos: token de notificação push, preferências de notificação, '
                'eventos de analytics agregados.\n'
                '• Dados de assinatura: status de plano, pagamentos processados pelo Mercado Pago '
                '(não armazenamos dados completos de cartão no app).',
          ),
          const _Section(
            title: '3. Finalidades e bases legais',
            body:
                'Tratamos dados para execução do contrato (prestação do serviço educacional), '
                'legítimo interesse (segurança, melhoria do produto, métricas) e consentimento '
                'quando aplicável (notificações push).',
          ),
          const _Section(
            title: '4. Compartilhamento',
            body:
                'Utilizamos operadores: Google (Firebase — autenticação, banco de dados, '
                'analytics, mensagens), Mercado Pago (pagamentos). Não vendemos seus dados pessoais.',
          ),
          const _Section(
            title: '5. Retenção',
            body:
                'Mantemos dados enquanto a conta estiver ativa. Eventos de analytics espelhados '
                'são eliminados após aproximadamente 90 dias. Registros financeiros podem ser '
                'conservados pelo prazo legal aplicável após exclusão da conta.',
          ),
          const _Section(
            title: '6. Seus direitos (LGPD)',
            body:
                'Você pode solicitar acesso, correção, portabilidade, eliminação e revogação de '
                'consentimento pela Central de Privacidade no app ou pelo e-mail acima.',
          ),
          const _Section(
            title: '7. Segurança',
            body:
                'Adotamos controles técnicos como regras de acesso ao banco de dados, '
                'autenticação e processamento de pagamentos em servidor seguro.',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(fontSize: 15, height: 1.45)),
        ],
      ),
    );
  }
}
