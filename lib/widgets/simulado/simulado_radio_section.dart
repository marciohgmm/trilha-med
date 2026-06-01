import 'package:flutter/material.dart';

/// Grupo de opções com [RadioGroup] (sem APIs deprecadas).
class SimuladoRadioSection<T> extends StatelessWidget {
  final T groupValue;
  final ValueChanged<T?> onChanged;
  final List<({T value, String label})> options;

  const SimuladoRadioSection({
    super.key,
    required this.groupValue,
    required this.onChanged,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    return RadioGroup<T>(
      groupValue: groupValue,
      onChanged: onChanged,
      child: Column(
        children: options
            .map(
              (o) => RadioListTile<T>(
                title: Text(o.label),
                value: o.value,
                activeColor: const Color(0xFF1E3A8A),
              ),
            )
            .toList(),
      ),
    );
  }
}
