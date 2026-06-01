import 'package:flutter/material.dart';

import '../../core/legal/legal_versions.dart';

/// Termos de Uso — versão [LegalVersions.termsVersion].
class TermsOfUsePage extends StatelessWidget {
  const TermsOfUsePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Termos de Uso'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Versão ${LegalVersions.termsVersion}',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.grey.shade700,
                ),
          ),
          const SizedBox(height: 16),
          const _Section(
            title: '1. Aceitação',
            body:
                'Ao criar conta e utilizar o aplicativo, você concorda com estes Termos e com a '
                'Política de Privacidade vigentes. O aceite é registrado com data e versão dos documentos.',
          ),
          const _Section(
            title: '2. Serviço',
            body:
                'O app oferece conteúdo educacional (flashcards, questões, simulados, fase prática, '
                'OSCE e recursos correlatos). O material não substitui orientação profissional individual.',
          ),
          const _Section(
            title: '3. Conta do usuário',
            body:
                'Você é responsável pela confidencialidade da senha e pelas atividades na sua conta. '
                'Informações falsas ou uso indevido podem resultar em suspensão.',
          ),
          const _Section(
            title: '4. Assinaturas e pagamentos',
            body:
                'Planos pagos são processados pelo Mercado Pago. Regras de renovação, cancelamento e '
                'reembolso seguem a legislação consumerista e as políticas do meio de pagamento.',
          ),
          const _Section(
            title: '5. Propriedade intelectual',
            body:
                'Conteúdos, marcas e software do app são protegidos. É proibida cópia, redistribuição '
                'ou engenharia reversa não autorizada.',
          ),
          const _Section(
            title: '6. Limitação de responsabilidade',
            body:
                'O serviço é fornecido “como está”, dentro dos limites da lei. Não garantimos '
                'aprovação em exames ou resultados específicos de estudo.',
          ),
          const _Section(
            title: '7. Encerramento',
            body:
                'Você pode encerrar a conta pela Central de Privacidade. Podemos suspender o acesso '
                'em caso de violação destes Termos.',
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
