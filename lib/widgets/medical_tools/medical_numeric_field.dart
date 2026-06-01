import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'medical_tools_theme.dart';

class MedicalNumericField extends StatelessWidget {
  const MedicalNumericField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.suffix,
    this.allowDecimal = true,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? suffix;
  final bool allowDecimal;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp(allowDecimal ? r'^\d*[,.]?\d*' : r'^\d*'),
        ),
      ],
      decoration: MedicalToolsTheme.inputDecoration(
        label: label,
        hint: hint,
        suffix: suffix,
      ),
    );
  }
}

double? parseMedicalDouble(String raw) {
  final normalized = raw.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

int? parseMedicalInt(String raw) {
  final normalized = raw.trim();
  if (normalized.isEmpty) return null;
  return int.tryParse(normalized);
}
