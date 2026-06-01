import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:flutter_application_1/utils/flashcard_delta_img_tags.dart';
import 'package:flutter_application_1/utils/image_helper.dart';

/// Leitura fiel ao editor Quill (listas, alinhamento, negrito; imagens em URLs
/// com [CachedNetworkImageProvider] para cache em disco alinhado aos slots do card).
class FlashcardReadonlyQuill extends StatefulWidget {
  final dynamic valor;
  final String materia;
  final double maxContentHeight;

  /// Estudo no app: sem scroll interno nem seleção — evita conflito de gestos no mobile.
  final bool studyMode;

  const FlashcardReadonlyQuill({
    super.key,
    required this.valor,
    required this.materia,
    this.maxContentHeight = 520,
    this.studyMode = false,
  });

  /// Mesma ideia do editor de criação: imagens por URL (Storage) + fallback.
  static final QuillEditorImageEmbedConfig kQuillImageEmbedConfig =
      QuillEditorImageEmbedConfig(
    imageProviderBuilder: (context, imageUrl) {
      final s = imageUrl.trim();
      if (s.startsWith('http://') || s.startsWith('https://')) {
        // Cache em disco (mesmo gestor que os slots de imagem do card).
        return CachedNetworkImageProvider(s);
      }
      // MIGRADO: antes retornava `AssetImage` para `assets/...` (bundle local).
      // if (s.startsWith('assets/')) {
      //   return AssetImage(s);
      // }
      return null;
    },
    imageErrorWidgetBuilder: (context, error, stackTrace) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Text(
          kFlashcardMissingAssetMessage,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade800,
            fontSize: 14,
            height: 1.35,
          ),
        ),
      );
    },
  );

  @override
  State<FlashcardReadonlyQuill> createState() => _FlashcardReadonlyQuillState();
}

class _FlashcardReadonlyQuillState extends State<FlashcardReadonlyQuill> {
  QuillController? _controller;
  late ScrollController _scroll;
  late FocusNode _focus;
  int _loadGen = 0;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController();
    _focus = FocusNode(canRequestFocus: false, skipTraversal: true);
    _scheduleRebuildController();
  }

  @override
  void didUpdateWidget(covariant FlashcardReadonlyQuill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.valor.toString() != oldWidget.valor.toString() ||
        widget.materia != oldWidget.materia) {
      _scheduleRebuildController();
    }
  }

  void _scheduleRebuildController() {
    final gen = ++_loadGen;
    _controller?.dispose();
    _controller = null;
    setState(() {});

    Future<void>(() async {
      try {
        final ops = prepareDeltaOpsForQuill(widget.valor, widget.materia);
        final resolved = await resolveFlashcardDeltaImageUrls(ops);
        if (!mounted || gen != _loadGen) return;
        setState(() {
          _controller = QuillController(
            document: Document.fromJson(resolved),
            selection: const TextSelection.collapsed(offset: 0),
            readOnly: true,
          );
        });
      } catch (e, st) {
        debugPrint('FlashcardReadonlyQuill: $e\n$st');
        if (!mounted || gen != _loadGen) return;
        setState(() {
          _controller = QuillController(
            document: Document.fromJson([
              {
                'insert':
                    'Não foi possível exibir este conteúdo formatado. Edite o card no admin.\n',
              },
            ]),
            selection: const TextSelection.collapsed(offset: 0),
            readOnly: true,
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _loadGen++;
    _controller?.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;
    if (ctrl == null) {
      final maxH = math.max(
        160.0,
        math.min(
            widget.maxContentHeight, MediaQuery.sizeOf(context).height * 0.62),
      );
      return SizedBox(
        height: maxH,
        child: const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    final maxH = widget.studyMode
        ? math.max(
            widget.maxContentHeight,
            MediaQuery.sizeOf(context).height * 0.85,
          )
        : math.max(
            160.0,
            math.min(widget.maxContentHeight,
                MediaQuery.sizeOf(context).height * 0.62),
          );

    final embeds = kIsWeb
        ? FlutterQuillEmbeds.editorWebBuilders(
            imageEmbedConfig: FlashcardReadonlyQuill.kQuillImageEmbedConfig,
            videoEmbedConfig: null,
          )
        : FlutterQuillEmbeds.editorBuilders(
            imageEmbedConfig: FlashcardReadonlyQuill.kQuillImageEmbedConfig,
            videoEmbedConfig: null,
          );

    final editor = QuillEditor(
      controller: ctrl,
      scrollController: _scroll,
      focusNode: _focus,
      config: QuillEditorConfig(
        scrollable: !widget.studyMode,
        expands: false,
        maxHeight: maxH,
        padding: const EdgeInsets.fromLTRB(6, 10, 6, 14),
        showCursor: false,
        autoFocus: false,
        enableInteractiveSelection: !widget.studyMode,
        embedBuilders: embeds,
        scrollPhysics: widget.studyMode
            ? const NeverScrollableScrollPhysics()
            : const BouncingScrollPhysics(),
      ),
    );

    if (!widget.studyMode) return editor;

    return IgnorePointer(child: editor);
  }
}
