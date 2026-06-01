import 'package:flutter/material.dart';

import 'adult_bmi_calculator_page.dart';
import 'cockcroft_gault_calculator_page.dart';
import 'weight_dose_calculator_page.dart';

/// Ferramentas clínicas e bulário.
class MedicalToolsPage extends StatelessWidget {
  const MedicalToolsPage({super.key});

  static const _primary = Color(0xFF1E3A8A);
  static const _accent = Color(0xFF2563EB);

  static const _calculadoras = [
    _MedicalToolItem(
      title: 'IMC Adulto',
      icon: Icons.monitor_weight_outlined,
      available: true,
    ),
    _MedicalToolItem(
      title: 'IMC Pediátrico',
      icon: Icons.child_care_outlined,
    ),
    _MedicalToolItem(
      title: 'Cálculo de Dose por Peso',
      icon: Icons.medication_outlined,
      available: true,
    ),
    _MedicalToolItem(
      title: 'Correção de Idade Gestacional',
      icon: Icons.pregnant_woman_outlined,
    ),
    _MedicalToolItem(
      title: 'Superfície Corporal (SC)',
      icon: Icons.accessibility_new_outlined,
    ),
    _MedicalToolItem(
      title: 'Regra de Parkland',
      icon: Icons.local_fire_department_outlined,
    ),
    _MedicalToolItem(
      title: 'Clearance de Creatinina (Cockcroft-Gault)',
      icon: Icons.science_outlined,
      available: true,
    ),
  ];

  static const _bularios = [
    _MedicalToolItem(
      title: 'Consulta de medicamentos cadastrados',
      icon: Icons.medication_liquid_outlined,
    ),
    _MedicalToolItem(
      title: 'Busca por nome comercial',
      icon: Icons.search_outlined,
    ),
    _MedicalToolItem(
      title: 'Busca por princípio ativo',
      icon: Icons.biotech_outlined,
    ),
    _MedicalToolItem(
      title: 'Posologia',
      icon: Icons.schedule_outlined,
    ),
    _MedicalToolItem(
      title: 'Contraindicações',
      icon: Icons.block_outlined,
    ),
    _MedicalToolItem(
      title: 'Uso na gestação',
      icon: Icons.pregnant_woman_outlined,
    ),
    _MedicalToolItem(
      title: 'Uso pediátrico',
      icon: Icons.child_friendly_outlined,
    ),
  ];

  void _onItemTap(BuildContext context, _MedicalToolItem item) {
    if (item.available) {
      final page = switch (item.title) {
        'IMC Adulto' => const AdultBmiCalculatorPage(),
        'Cálculo de Dose por Peso' => const WeightDoseCalculatorPage(),
        'Clearance de Creatinina (Cockcroft-Gault)' =>
          const CockcroftGaultCalculatorPage(),
        _ => null,
      };
      if (page != null) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => page),
        );
      }
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.title} — em breve'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Ferramentas Médicas'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _accent.withValues(alpha: 0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.medical_information_outlined,
                    color: _accent, size: 32),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Calculadoras e bulário para apoio à prática clínica. '
                    'IMC, dose por peso e Cockcroft-Gault já disponíveis.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _CategorySection(
            title: 'Calculadoras',
            icon: Icons.calculate_outlined,
            items: _calculadoras,
            onItemTap: (item) => _onItemTap(context, item),
          ),
          const SizedBox(height: 28),
          _CategorySection(
            title: 'Bulários',
            icon: Icons.menu_book_outlined,
            items: _bularios,
            onItemTap: (item) => _onItemTap(context, item),
          ),
        ],
      ),
    );
  }
}

class _MedicalToolItem {
  const _MedicalToolItem({
    required this.title,
    required this.icon,
    this.available = false,
  });

  final String title;
  final IconData icon;
  final bool available;
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.title,
    required this.icon,
    required this.items,
    required this.onItemTap,
  });

  final String title;
  final IconData icon;
  final List<_MedicalToolItem> items;
  final void Function(_MedicalToolItem item) onItemTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: MedicalToolsPage._primary, size: 26),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: MedicalToolsPage._primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ToolCard(
              item: item,
              onTap: () => onItemTap(item),
            ),
          ),
        ),
      ],
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.item,
    required this.onTap,
  });

  final _MedicalToolItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: MedicalToolsPage._primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: MedicalToolsPage._primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.available ? 'Disponível' : 'Em breve',
                      style: TextStyle(
                        fontSize: 12,
                        color: item.available
                            ? const Color(0xFF059669)
                            : Colors.grey.shade600,
                        fontWeight:
                            item.available ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
