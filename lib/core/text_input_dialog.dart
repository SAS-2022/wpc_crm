import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Asks for one line (or a few) of text; returns null when cancelled.
/// The dialog owns its controller, so it is disposed only after the closing
/// animation has finished.
Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  String initialText = '',
  String? label,
  String? hint,
  String? confirmLabel,
  int maxLines = 3,
}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _TextInputDialog(
        title: title,
        initialText: initialText,
        label: label,
        hint: hint,
        confirmLabel: confirmLabel,
        maxLines: maxLines,
      ),
    );

class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    required this.initialText,
    required this.label,
    required this.hint,
    required this.confirmLabel,
    required this.maxLines,
  });

  final String title;
  final String initialText;
  final String? label;
  final String? hint;
  final String? confirmLabel;
  final int maxLines;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final _controller = TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 1,
        maxLines: widget.maxLines,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: widget.label, hintText: widget.hint),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(widget.confirmLabel ?? l10n.save),
        ),
      ],
    );
  }
}
