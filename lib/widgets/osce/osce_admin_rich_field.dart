import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';

import '../flashcard_readonly_quill.dart';

/// Campo de texto com formatação básica (Quill) para o admin OSCE.
class OsceAdminRichField extends StatefulWidget {
  final String label;
  final String initialValue;
  final double minHeight;
  final ValueChanged<String> onChanged;

  const OsceAdminRichField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.minHeight = 120,
  });

  static bool looksLikeDeltaJson(String s) {
    final t = s.trim();
    return t.startsWith('[') || t.startsWith('{"');
  }

  static quill.Document documentFromStorage(String stored) {
    if (stored.trim().isEmpty) {
      return quill.Document();
    }
    if (looksLikeDeltaJson(stored)) {
      try {
        final decoded = jsonDecode(stored);
        if (decoded is List) {
          return quill.Document.fromJson(decoded);
        }
      } catch (_) {}
    }
    return quill.Document()..insert(0, stored);
  }

  static String exportToStorage(quill.QuillController controller) {
    return jsonEncode(controller.document.toDelta().toJson());
  }

  @override
  State<OsceAdminRichField> createState() => OsceAdminRichFieldState();
}

class OsceAdminRichFieldState extends State<OsceAdminRichField> {
  late quill.QuillController _controller;
  late FocusNode _focus;
  late ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode();
    _scroll = ScrollController();
    _controller = quill.QuillController(
      document: OsceAdminRichField.documentFromStorage(widget.initialValue),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _controller.addListener(_notify);
  }

  void _notify() {
    widget.onChanged(OsceAdminRichField.exportToStorage(_controller));
  }

  void _persistToParent() {
    widget.onChanged(OsceAdminRichField.exportToStorage(_controller));
  }

  String get value => OsceAdminRichField.exportToStorage(_controller);

  @override
  void deactivate() {
    _persistToParent();
    super.deactivate();
  }

  @override
  void dispose() {
    _persistToParent();
    _controller.removeListener(_notify);
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(10),
              color: Colors.white,
            ),
            child: Column(
              children: [
                quill.QuillSimpleToolbar(
                  controller: _controller,
                  config: const quill.QuillSimpleToolbarConfig(
                    showSearchButton: false,
                    showFontFamily: false,
                    showFontSize: false,
                    showColorButton: false,
                    showBackgroundColorButton: false,
                    showCodeBlock: false,
                    showInlineCode: false,
                    showQuote: false,
                    showSubscript: false,
                    showSuperscript: false,
                    showHeaderStyle: false,
                    showListCheck: false,
                  ),
                ),
                const Divider(height: 1),
                SizedBox(
                  height: widget.minHeight,
                  child: quill.QuillEditor(
                    controller: _controller,
                    focusNode: _focus,
                    scrollController: _scroll,
                    config: quill.QuillEditorConfig(
                      padding: const EdgeInsets.all(12),
                      autoFocus: false,
                      expands: true,
                      placeholder: 'Digite aqui…',
                      embedBuilders: kIsWeb
                          ? FlutterQuillEmbeds.editorWebBuilders(
                              imageEmbedConfig: FlashcardReadonlyQuill
                                  .kQuillImageEmbedConfig,
                              videoEmbedConfig: null,
                            )
                          : FlutterQuillEmbeds.editorBuilders(
                              imageEmbedConfig: FlashcardReadonlyQuill
                                  .kQuillImageEmbedConfig,
                              videoEmbedConfig: null,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
