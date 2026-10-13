import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import 'attachments.dart';

/// Asks camera / gallery / file and returns the picked files (empty when
/// cancelled). Photos are scaled down to keep uploads small.
Future<List<PendingFile>> pickAttachments(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final canUseCamera = !kIsWeb;
  final source = await showModalBottomSheet<String>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canUseCamera)
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: Text(l10n.takePhoto),
              onTap: () => Navigator.pop(sheet, 'camera'),
            ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: Text(l10n.chooseFromGallery),
            onTap: () => Navigator.pop(sheet, 'gallery'),
          ),
          ListTile(
            leading: const Icon(Icons.attach_file),
            title: Text(l10n.chooseFile),
            onTap: () => Navigator.pop(sheet, 'file'),
          ),
        ],
      ),
    ),
  );
  if (source == null) return const [];

  final picked = <PendingFile>[];
  final picker = ImagePicker();
  const maxSide = 1920.0;
  const quality = 75;
  switch (source) {
    case 'camera':
      final x = await picker.pickImage(source: ImageSource.camera, maxWidth: maxSide, maxHeight: maxSide, imageQuality: quality);
      if (x != null) picked.add(PendingFile(name: x.name, bytes: await x.readAsBytes()));
    case 'gallery':
      for (final x in await picker.pickMultiImage(maxWidth: maxSide, maxHeight: maxSide, imageQuality: quality)) {
        picked.add(PendingFile(name: x.name, bytes: await x.readAsBytes()));
      }
    case 'file':
      for (final f in await FilePicker.pickFiles()) {
        picked.add(PendingFile(name: f.name, bytes: await f.readAsBytes()));
      }
  }
  final tooLarge = picked.where((f) => f.bytes.length >= maxAttachmentBytes).toList();
  for (final f in tooLarge) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.fileTooLarge(f.name))));
  }
  return picked.where((f) => f.bytes.length < maxAttachmentBytes).toList();
}

/// Photos and files of a client or visit: thumbnails for photos, a row per
/// other file. Tap opens the file; long-press deletes it when allowed.
class AttachmentsSection extends ConsumerStatefulWidget {
  const AttachmentsSection({super.key, required this.owner, required this.canAdd, required this.canDelete});

  final AttachmentOwner owner;
  final bool canAdd;
  final bool canDelete;

  @override
  ConsumerState<AttachmentsSection> createState() => _AttachmentsSectionState();
}

class _AttachmentsSectionState extends ConsumerState<AttachmentsSection> {
  int _uploading = 0;

  Future<void> _add() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final me = ref.read(currentUserProvider).value;
    if (me == null) return;
    final files = await pickAttachments(context);
    if (files.isEmpty || !mounted) return;
    setState(() => _uploading += files.length);
    final repo = ref.read(attachmentsRepositoryProvider);
    for (final f in files) {
      try {
        await repo.upload(widget.owner, f, me.id);
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
      } finally {
        if (mounted) setState(() => _uploading--);
      }
    }
  }

  Future<void> _delete(Attachment a) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        content: Text(l10n.deleteAttachmentConfirm(a.fileName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l10n.delete)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(attachmentsRepositoryProvider).delete(widget.owner, a);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    }
  }

  void _open(Attachment a) => launchUrl(Uri.parse(a.url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final attachments = ref.watch(attachmentsProvider(widget.owner));
    final list = attachments.value ?? const <Attachment>[];
    final photos = list.where((a) => a.isImage).toList();
    final files = list.where((a) => !a.isImage).toList();
    final onLongPress = widget.canDelete ? _delete : null;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(l10n.attachments,
                        style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
                  ),
                  if (widget.canAdd)
                    IconButton(
                      icon: const Icon(Icons.add_a_photo),
                      tooltip: l10n.addAttachment,
                      onPressed: _add,
                    ),
                ],
              ),
            ),
            if (_uploading > 0)
              ListTile(
                dense: true,
                leading: const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                title: Text(l10n.uploading),
              ),
            if (attachments.hasError) ListTile(dense: true, title: Text(l10n.errorWithMessage('${attachments.error}'))),
            if (attachments.hasValue && list.isEmpty && _uploading == 0)
              ListTile(dense: true, title: Text(l10n.noAttachments)),
            if (photos.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in photos)
                      InkWell(
                        onTap: () => _open(a),
                        onLongPress: onLongPress == null ? null : () => onLongPress(a),
                        borderRadius: BorderRadius.circular(8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            a.url,
                            width: 96,
                            height: 96,
                            fit: BoxFit.cover,
                            cacheWidth: 288,
                            errorBuilder: (_, _, _) => Container(
                              width: 96,
                              height: 96,
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: const Icon(Icons.broken_image),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            for (final a in files)
              ListTile(
                dense: true,
                leading: Icon(a.contentType == 'application/pdf' ? Icons.picture_as_pdf : Icons.insert_drive_file),
                title: Text(a.fileName),
                subtitle: a.createdAt == null ? null : Text(DateFormat.yMMMd(locale).format(a.createdAt!)),
                trailing: widget.canDelete
                    ? IconButton(icon: const Icon(Icons.delete_outline), tooltip: l10n.delete, onPressed: () => _delete(a))
                    : null,
                onTap: () => _open(a),
              ),
          ],
        ),
      ),
    );
  }
}
