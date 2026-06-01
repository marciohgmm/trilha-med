import 'package:flutter/material.dart';

import '../../models/osce_models.dart';

/// Seleção de tema/caso ao criar sala.
Future<OsceCaseModel?> showOsceCasePickerSheet(
  BuildContext context,
  List<OsceCaseModel> cases,
) {
  return showModalBottomSheet<OsceCaseModel>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.85,
      builder: (_, scroll) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Escolha o tema / caso da sala',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              itemCount: cases.length,
              itemBuilder: (_, i) {
                final c = cases[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF0D9488).withValues(alpha: 0.15),
                    child: const Icon(Icons.menu_book, color: Color(0xFF0D9488)),
                  ),
                  title: Text(c.title),
                  subtitle: Text(c.specialty),
                  onTap: () => Navigator.pop(ctx, c),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
