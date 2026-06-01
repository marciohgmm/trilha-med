import 'package:flutter/material.dart';

import '../../models/practical_phase_model.dart';
import 'practical_phase_constants.dart';

class PracticalPhaseFiltersBar extends StatelessWidget {
  final PracticalPhaseFilters filters;
  final List<String> categories;
  final List<String> specialties;
  final List<String> difficulties;
  final bool showStatusFilter;
  final ValueChanged<PracticalPhaseFilters> onChanged;

  const PracticalPhaseFiltersBar({
    super.key,
    required this.filters,
    required this.categories,
    required this.specialties,
    required this.difficulties,
    required this.onChanged,
    this.showStatusFilter = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: 'Buscar por nome do modelo...',
            prefixIcon: const Icon(Icons.search, color: PracticalPhaseColors.primary),
            suffixIcon: filters.search.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () =>
                        onChanged(filters.copyWith(search: '')),
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (v) => onChanged(filters.copyWith(search: v)),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _dropdown(
                label: 'Categoria',
                value: filters.category,
                items: categories,
                onSelect: (v) => onChanged(
                  v == null
                      ? filters.copyWith(clearCategory: true)
                      : filters.copyWith(category: v),
                ),
              ),
              _dropdown(
                label: 'Especialidade',
                value: filters.specialty,
                items: specialties,
                onSelect: (v) => onChanged(
                  v == null
                      ? filters.copyWith(clearSpecialty: true)
                      : filters.copyWith(specialty: v),
                ),
              ),
              _dropdown(
                label: 'Dificuldade',
                value: filters.difficulty,
                items: difficulties,
                onSelect: (v) => onChanged(
                  v == null
                      ? filters.copyWith(clearDifficulty: true)
                      : filters.copyWith(difficulty: v),
                ),
              ),
              if (showStatusFilter)
                _dropdown(
                  label: 'Status',
                  value: filters.status,
                  items: const [
                    'todos',
                    'publicado',
                    'rascunho',
                    'inativo',
                  ],
                  onSelect: (v) => onChanged(
                    v == null || v == 'todos'
                        ? filters.copyWith(clearStatus: true)
                        : filters.copyWith(status: v),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onSelect,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PopupMenuButton<String?>(
        onSelected: onSelect,
        itemBuilder: (context) => [
          const PopupMenuItem(value: null, child: Text('Todos')),
          ...items.map(
            (e) => PopupMenuItem(value: e, child: Text(e)),
          ),
        ],
        child: Chip(
          avatar: const Icon(Icons.filter_list, size: 18),
          label: Text(value == null || value.isEmpty ? label : value),
          backgroundColor: Colors.white,
          side: BorderSide(
            color: PracticalPhaseColors.primary.withValues(alpha: 0.2),
          ),
        ),
      ),
    );
  }
}
