import 'package:flutter/material.dart';

/// Cores e estilos das Ferramentas Médicas.
abstract final class MedicalToolsTheme {
  static const primary = Color(0xFF1E3A8A);
  static const accent = Color(0xFF2563EB);
  static const background = Color(0xFFF8FAFC);
  static const cardBorder = Color(0xFFE2E8F0);

  static InputDecoration inputDecoration({
    required String label,
    String? hint,
    String? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixText: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.white,
    );
  }

  static ButtonStyle primaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}

/// IDs estáveis para histórico e navegação.
abstract final class MedicalToolIds {
  static const adultBmi = 'adult_bmi';
  static const weightDose = 'weight_dose';
  static const cockcroftGault = 'cockcroft_gault';
}
