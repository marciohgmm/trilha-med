import 'package:flutter/material.dart';

import 'package:flutter_application_1/app_scaffold.dart';

/// Diálogo de texto longo (reporte, suporte). SnackBars vão ao messenger raiz
/// quando o [context] da página não estiver disponível no overlay.
Future<String?> showReportTextDialog({
  required BuildContext context,
  required String title,
  String? hintText,
  int maxLines = 6,
  Widget? description,
  String emptyMessage = 'Digite uma mensagem antes de enviar.',
}) async {
  if (!context.mounted) return null;

  final messenger = ScaffoldMessenger.maybeOf(context) ??
      rootScaffoldMessengerKey.currentState;

  void snack(String text) {
    final s = SnackBar(content: Text(text));
    messenger?.showSnackBar(s);
  }

  final controller = TextEditingController();
  String? result;
  try {
    result = await showDialog<String>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (description != null) ...[
                  description,
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: controller,
                  maxLines: maxLines,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: hintText,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final t = controller.text.trim();
                if (t.isEmpty) {
                  snack(emptyMessage);
                  return;
                }
                Navigator.of(dialogContext).pop(t);
              },
              child: const Text('Enviar'),
            ),
          ],
        );
      },
    );
  } finally {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
  }
  return result;
}
