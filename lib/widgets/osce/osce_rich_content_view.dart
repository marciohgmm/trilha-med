import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../flashcard_readonly_quill.dart';
import 'osce_admin_rich_field.dart';

/// Exibe conteúdo salvo do admin (Quill JSON ou texto simples).
class OsceRichContentView extends StatelessWidget {
  final String content;
  final String? imageUrl;

  const OsceRichContentView({
    super.key,
    required this.content,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;
    final hasText = content.trim().isNotEmpty;

    if (!hasText && !hasImage) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasText)
          OsceAdminRichField.looksLikeDeltaJson(content)
              ? FlashcardReadonlyQuill(
                  valor: content,
                  materia: 'osce',
                  maxContentHeight: 2400,
                  // Sem scroll interno — a tela OSCE rola tudo de uma vez.
                  studyMode: true,
                )
              : Text(content, style: const TextStyle(height: 1.45)),
        if (hasImage) ...[
          if (hasText) const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: imageUrl!,
              fit: BoxFit.contain,
              placeholder: (_, __) => const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (_, __, ___) => const Text('Erro ao carregar imagem'),
            ),
          ),
        ],
      ],
    );
  }
}
