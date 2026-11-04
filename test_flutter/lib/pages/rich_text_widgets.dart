import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:url_launcher/url_launcher.dart';
import '../utils/rich_text_content.dart';

quill.Document _document(String value) {
  final ops = RichTextContent.operations(value);
  if (ops != null) {
    try {
      return quill.Document.fromJson(ops);
    } catch (_) {
      /* Preserve malformed legacy content as text. */
    }
  }
  return quill.Document()..insert(0, value);
}

Future<void> _openLink(BuildContext context, String value) async {
  final uri = Uri.tryParse(value);
  var opened = false;
  if (uri != null && ['https', 'http', 'mailto'].contains(uri.scheme)) {
    try {
      opened = await launchUrl(uri);
    } catch (_) {
      opened = false;
    }
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(const SnackBar(content: Text('Could not open this link.')));
  }
}

class RichTextEditor extends StatefulWidget {
  const RichTextEditor({
    super.key,
    required this.controller,
    required this.label,
    this.required = false,
  });
  final TextEditingController controller;
  final String label;
  final bool required;
  @override
  State<RichTextEditor> createState() => _RichTextEditorState();
}

class _RichTextEditorState extends State<RichTextEditor> {
  late final quill.QuillController _controller = quill.QuillController(
    document: _document(widget.controller.text),
    selection: const TextSelection.collapsed(offset: 0),
  );
  @override
  void initState() {
    super.initState();
    _controller.addListener(_sync);
  }

  void _sync() {
    final text = _controller.document.toPlainText().trim();
    widget.controller.text = text.isEmpty
        ? ''
        : RichTextContent.encode(_controller.document.toDelta().toJson());
  }

  @override
  void dispose() {
    _controller.removeListener(_sync);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FormField<String>(
    validator: (_) =>
        widget.required &&
            RichTextContent.plainText(widget.controller.text).trim().isEmpty
        ? 'Enter a note'
        : null,
    builder: (field) => InputDecorator(
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        errorText: field.errorText,
      ),
      child: Localizations.override(
        context: context,
        delegates: const [quill.FlutterQuillLocalizations.delegate],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            quill.QuillSimpleToolbar(
              controller: _controller,
              config: const quill.QuillSimpleToolbarConfig(
                showFontFamily: false,
                showFontSize: false,
                showUnderLineButton: false,
                showStrikeThrough: false,
                showInlineCode: false,
                showColorButton: false,
                showBackgroundColorButton: false,
                showHeaderStyle: false,
                showListNumbers: false,
                showListCheck: false,
                showCodeBlock: false,
                showQuote: false,
                showIndent: false,
                showSearchButton: false,
                showSubscript: false,
                showSuperscript: false,
              ),
            ),
            const Divider(),
            quill.QuillEditor.basic(
              controller: _controller,
              config: quill.QuillEditorConfig(
                minHeight: 100,
                maxHeight: 220,
                padding: const EdgeInsets.all(8),
                onLaunchUrl: (url) => _openLink(context, url),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class RichTextView extends StatefulWidget {
  const RichTextView(this.value, {super.key});
  final String value;
  @override
  State<RichTextView> createState() => _RichTextViewState();
}

class _RichTextViewState extends State<RichTextView> {
  late quill.QuillController _controller;
  void _load() {
    _controller = quill.QuillController(
      document: _document(widget.value),
      selection: const TextSelection.collapsed(offset: 0),
    )..readOnly = true;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(RichTextView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.dispose();
      _load();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RichTextContent.operations(widget.value) == null
      ? SelectableText(widget.value)
      : Localizations.override(
          context: context,
          delegates: const [quill.FlutterQuillLocalizations.delegate],
          child: quill.QuillEditor.basic(
            controller: _controller,
            config: quill.QuillEditorConfig(
              scrollable: false,
              showCursor: false,
              padding: EdgeInsets.zero,
              onLaunchUrl: (url) => _openLink(context, url),
            ),
          ),
        );
}
