import 'package:flutter/material.dart';

import 'package:flutter_application_1/utils/content_hierarchy_utils.dart';

/// Campo de busca com lupa + autocomplete para subtemas (ordem alfab?tica).
class SubtemaSearchField extends StatefulWidget {
  final List<String> subtemas;
  final String? selectedSubtema;
  final ValueChanged<String?> onSelected;
  final VoidCallback? onCreateNew;
  final String? hintText;
  final bool enabled;

  const SubtemaSearchField({
    super.key,
    required this.subtemas,
    required this.onSelected,
    this.selectedSubtema,
    this.onCreateNew,
    this.hintText,
    this.enabled = true,
  });

  @override
  State<SubtemaSearchField> createState() => _SubtemaSearchFieldState();
}

class _SubtemaSearchFieldState extends State<SubtemaSearchField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<String> _suggestions = [];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    if (widget.selectedSubtema != null && widget.selectedSubtema!.isNotEmpty) {
      _controller.text = widget.selectedSubtema!;
    }
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(SubtemaSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedSubtema != oldWidget.selectedSubtema) {
      final sel = widget.selectedSubtema ?? '';
      if (sel != _controller.text) {
        _controller.text = sel;
      }
    }
    if (widget.subtemas != oldWidget.subtemas && _focusNode.hasFocus) {
      _updateSuggestions(_controller.text);
    }
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _updateSuggestions(_controller.text);
      setState(() => _showSuggestions = true);
    } else {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && !_focusNode.hasFocus) {
          setState(() => _showSuggestions = false);
        }
      });
    }
  }

  void _updateSuggestions(String query) {
    final sorted = ContentHierarchyUtils.sortAlphabetically(widget.subtemas);
    setState(() {
      _suggestions = ContentHierarchyUtils.filterSubtemas(sorted, query);
    });
  }

  void _select(String value) {
    _controller.text = value;
    widget.onSelected(value);
    setState(() => _showSuggestions = false);
    _focusNode.unfocus();
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          decoration: InputDecoration(
            labelText: 'Subtema / assunto',
            hintText: widget.hintText ?? 'Digite 2+ letras para buscar...',
            prefixIcon: const Icon(Icons.search, color: Color(0xFF1E3A8A)),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      widget.onSelected(null);
                      _updateSuggestions('');
                      setState(() {});
                    },
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onChanged: (value) {
            widget.onSelected(value.trim().isEmpty ? null : value.trim());
            _updateSuggestions(value);
            setState(() => _showSuggestions = true);
          },
          onTap: () {
            _updateSuggestions(_controller.text);
            setState(() => _showSuggestions = true);
          },
        ),
        if (widget.onCreateNew != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.enabled ? widget.onCreateNew : null,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Novo subtema'),
            ),
          ),
        ],
        if (_showSuggestions && _suggestions.isNotEmpty) ...[
          const SizedBox(height: 4),
          Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = _suggestions[index];
                  return ListTile(
                    dense: true,
                    title: Text(item),
                    onTap: () => _select(item),
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }
}
