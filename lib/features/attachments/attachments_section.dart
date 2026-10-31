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
  // Scaled down again (and given a thumbnail) at upload.
  const maxSide = 1600.0;
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
/// other file. Tap opens the file; the × on a photo / bin on a file (or long-press) deletes it when allowed.
class AttachmentsSection extends ConsumerStatefulWidget {
  const AttachmentsSection({
    super.key,
    required this.owner,
    required this.canAdd,
    required this.canDelete,
    this.canDeleteOwn = false,
  });

  final AttachmentOwner owner;
  final bool canAdd;

  /// Any file may be deleted.
  final bool canDelete;

  /// Files the signed-in user uploaded may be deleted (e.g. the owner of a
  /// pending leave request or absence).
  final bool canDeleteOwn;

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
    // Client documents (CR, VAT, …) are listed by name even when they are photos.
    final photos = list.where((a) => a.isImage && a.docType.isEmpty).toList();
    final files = list.where((a) => !photos.contains(a)).toList();
    final myId = ref.watch(currentUserProvider).value?.id;
    bool deletable(Attachment a) => widget.canDelete || (widget.canDeleteOwn && myId != null && a.uploadedBy == myId);

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
                      Stack(
                        children: [
                          InkWell(
                            onTap: () => _open(a),
                            onLongPress: deletable(a) ? () => _delete(a) : null,
                            borderRadius: BorderRadius.circular(8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              // HEIC (iPhone) photos: only Safari can show them, so other
                              // browsers get a labelled tile; tapping opens the file.
                              child: a.contentType == 'image/heic' && kIsWeb
                                  ? _FileTile(label: 'HEIC', icon: Icons.photo, tooltip: a.fileName)
                                  : AttachmentThumb(attachment: a),
                            ),
                          ),
                          // Visible delete button (long-press alone was hard to find).
                          if (deletable(a))
                            PositionedDirectional(
                              top: 2,
                              end: 2,
                              child: Material(
                                color: Colors.black54,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () => _delete(a),
                                  child: Tooltip(
                                    message: l10n.delete,
                                    child: const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(Icons.close, size: 16, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            for (final a in files)
              ListTile(
                dense: true,
                leading: Icon(a.contentType == 'application/pdf'
                    ? Icons.picture_as_pdf
                    : a.isImage
                        ? Icons.image_outlined
                        : Icons.insert_drive_file),
                title: Text(switch (a.docType) {
                  'cr' => l10n.docCr,
                  'vat' => l10n.docVat,
                  'nationalAddress' => l10n.docNationalAddress,
                  _ => a.fileName,
                }),
                subtitle: Text([
                  if (a.docType.isNotEmpty) a.fileName,
                  if (a.createdAt != null) DateFormat.yMMMd(locale).format(a.createdAt!),
                ].join(' · ')),
                trailing: deletable(a)
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

/// 96×96 photo thumbnail (the small `thumbUrl` when there is one) with a
/// loading placeholder until the image has fully arrived.
class AttachmentThumb extends StatelessWidget {
  const AttachmentThumb({super.key, required this.attachment, this.size = 96});

  final Attachment attachment;
  final double size;

  @override
  Widget build(BuildContext context) {
    final a = attachment;
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      width: size,
      height: size,
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: SizedBox.square(
        dimension: 22,
        child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onSurfaceVariant),
      ),
    );
    return Image.network(
      a.thumbUrl.isNotEmpty ? a.thumbUrl : a.url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      cacheWidth: (size * 3).round(),
      // Web: when the canvas renderer can't load the photo, the browser's
      // own <img> shows it instead.
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      frameBuilder: (_, child, frame, wasSynchronouslyLoaded) => wasSynchronouslyLoaded
          ? child
          : Stack(
              children: [
                placeholder,
                AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: child,
                ),
              ],
            ),
      errorBuilder: (_, _, _) => _FileTile(label: a.fileName, icon: Icons.broken_image, tooltip: a.fileName),
    );
  }
}

/// A 96×96 tile standing in for a photo that can't be shown as a thumbnail.
class _FileTile extends StatelessWidget {
  const _FileTile({required this.label, required this.icon, required this.tooltip});

  final String label;
  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 96,
        height: 96,
        padding: const EdgeInsets.all(6),
        color: theme.colorScheme.surfaceContainerHighest,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon),
            const SizedBox(height: 4),
            Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
