import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../attachments/attachments.dart';
import '../attachments/attachments_section.dart';
import 'client_documents.dart';
import 'document_text.dart';

String clientDocLabel(AppLocalizations l10n, ClientDocType t) => switch (t) {
      ClientDocType.cr => l10n.docCr,
      ClientDocType.vat => l10n.docVat,
      ClientDocType.nationalAddress => l10n.docNationalAddress,
    };

IconData clientDocIcon(ClientDocType t) => switch (t) {
      ClientDocType.cr => Icons.business_center_outlined,
      ClientDocType.vat => Icons.receipt_long_outlined,
      ClientDocType.nationalAddress => Icons.home_work_outlined,
    };

/// A field the document could fill: shown in the review dialog.
class DocSuggestion {
  DocSuggestion({required this.label, required this.value, required this.current, required this.apply})
      : selected = current.trim().isEmpty || current.trim() == value;

  final String label;
  final String value;
  final String current;
  final void Function(String value) apply;
  bool selected;
}

/// Client edit screen: CR, VAT certificate and National Address. A picked
/// document is kept in [pending] until the client is saved; its text is read
/// on the device and [suggest] turns what was found into fields to fill.
class ClientDocumentsSection extends ConsumerStatefulWidget {
  const ClientDocumentsSection({
    super.key,
    required this.clientId,
    required this.pending,
    required this.onPicked,
    required this.suggest,
  });

  /// Null while adding a client.
  final String? clientId;
  final Map<ClientDocType, PendingFile> pending;
  final void Function(ClientDocType type, PendingFile? file) onPicked;
  final List<DocSuggestion> Function(DocFields fields) suggest;

  @override
  ConsumerState<ClientDocumentsSection> createState() => _ClientDocumentsSectionState();
}

class _ClientDocumentsSectionState extends ConsumerState<ClientDocumentsSection> {
  ClientDocType? _reading;

  Future<void> _pick(ClientDocType type) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final files = await pickAttachments(context);
    if (files.isEmpty || !mounted) return;
    final file = files.first;
    widget.onPicked(type, file);
    setState(() => _reading = type);
    final text = await tryReadDocumentText(file);
    if (!mounted) return;
    setState(() => _reading = null);
    if (text == null) {
      messenger.showSnackBar(SnackBar(
        content: Text(file.contentType.startsWith('image/') && !canReadPhotos ? l10n.docPhotoOnWeb : l10n.docUnreadable),
      ));
      return;
    }
    final suggestions = widget.suggest(parseDocText(text));
    if (suggestions.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.docNothingFound)));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => _SuggestionsDialog(title: clientDocLabel(l10n, type), suggestions: suggestions),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final id = widget.clientId;
    final saved = id == null
        ? const <Attachment>[]
        : ref.watch(attachmentsProvider((parent: AttachmentParent.clients, id: id))).value ?? const <Attachment>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.docsHelp, style: theme.textTheme.bodySmall),
        for (final type in ClientDocType.values)
          Builder(builder: (context) {
            final pending = widget.pending[type];
            // Newest first, as the provider gives them.
            final existing = saved.where((a) => a.docType == type.key).firstOrNull;
            final status = pending != null
                ? l10n.docWillUpload(pending.name)
                : existing?.fileName ?? l10n.docNotAdded;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(clientDocIcon(type),
                  color: pending != null || existing != null ? theme.colorScheme.primary : theme.colorScheme.outline),
              title: Text(clientDocLabel(l10n, type)),
              subtitle: Text(status, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: pending == null && existing != null
                  ? () => launchUrl(Uri.parse(existing.url), mode: LaunchMode.externalApplication)
                  : null,
              trailing: _reading == type
                  ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (pending != null)
                          IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: l10n.remove,
                            onPressed: () => widget.onPicked(type, null),
                          ),
                        TextButton.icon(
                          onPressed: _reading != null ? null : () => _pick(type),
                          icon: const Icon(Icons.upload_file, size: 18),
                          label: Text(pending != null || existing != null ? l10n.replace : l10n.upload),
                        ),
                      ],
                    ),
            );
          }),
      ],
    );
  }
}

class _SuggestionsDialog extends StatefulWidget {
  const _SuggestionsDialog({required this.title, required this.suggestions});

  final String title;
  final List<DocSuggestion> suggestions;

  @override
  State<_SuggestionsDialog> createState() => _SuggestionsDialogState();
}

class _SuggestionsDialogState extends State<_SuggestionsDialog> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.docFoundTitle(widget.title)),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.docFoundHelp, style: theme.textTheme.bodySmall),
              for (final s in widget.suggestions)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: s.selected,
                  onChanged: (v) => setState(() => s.selected = v ?? false),
                  title: Text(s.label, style: theme.textTheme.labelMedium),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.value, style: theme.textTheme.bodyLarge),
                      if (s.current.trim().isNotEmpty && s.current.trim() != s.value)
                        Text(l10n.docCurrentValue(s.current), style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: () {
            for (final s in widget.suggestions.where((s) => s.selected)) {
              s.apply(s.value);
            }
            Navigator.pop(context);
          },
          child: Text(l10n.docFill),
        ),
      ],
    );
  }
}
