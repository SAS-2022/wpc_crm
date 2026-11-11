import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../users/companies.dart';
import '../users/users_repository.dart';
import 'company_docs.dart';
import 'company_docs_repository.dart';
import 'company_docs_widgets.dart';
import 'service_widgets.dart';

/// Company documents (`/documents`, 2026-11-01): one page per place in the
/// tree — the sections at the top, then (Official) the group's companies,
/// then folders and files. Search covers the files below the page. Files
/// can be shared one at a time (share icon) or several at once (select
/// mode). Editors (GM / SM everywhere, HR in Expiring) add folders and
/// files with the + button and change items from their ⋮ menu.
class CompanyDocsScreen extends ConsumerStatefulWidget {
  const CompanyDocsScreen({super.key, this.section, this.companyId = '', this.folderId = ''});

  /// Null = the top (the sections).
  final DocSection? section;
  final String companyId;
  final String folderId;

  @override
  ConsumerState<CompanyDocsScreen> createState() => _CompanyDocsScreenState();
}

class _CompanyDocsScreenState extends ConsumerState<CompanyDocsScreen> {
  final _search = TextEditingController();
  bool _selecting = false;
  final _selected = <String>{};
  int _uploading = 0;

  void _endSelecting() {
    _selecting = false;
    _selected.clear();
  }

  DocPlace? get _place => widget.section == null
      ? null
      : (section: widget.section!, companyId: widget.companyId, folderId: widget.folderId);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _newFolder(List<CompanyDoc> all) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDocFolderDialog(context, section: widget.section!);
    if (result == null) return;
    try {
      await createDocFolder(all, _place!, name: result.name, ownRestricted: result.ownRestricted);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    }
  }

  /// One file: asks its details. Several: Official / Product upload them
  /// all under their file names (renamed later if needed); Expiring asks
  /// each one's details (the expiry date is needed).
  Future<void> _upload(List<CompanyDoc> all) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final place = _place!;
    final files = await pickCompanyDocFiles(context);
    if (files.isEmpty || !mounted) return;
    final ask = files.length == 1 || place.section.expires;
    for (final f in files) {
      DocDetails? details;
      if (ask) {
        if (!mounted) return;
        details = await showDocDetailsDialog(
          context,
          section: place.section,
          file: f,
          companyId: place.companyId,
          companyEditable: place.section == DocSection.official && place.folderId.isEmpty,
        );
        if (details == null) continue;
      }
      details ??= plainDocDetails(f.name.replaceAll(RegExp(r'\.\w+$'), '').replaceAll('_', ' '), place.companyId);
      if (!mounted) return;
      setState(() => _uploading++);
      try {
        await uploadCompanyDoc(all, place, f, details);
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
      } finally {
        if (mounted) setState(() => _uploading--);
      }
    }
  }

  /// Services / subscriptions: an item with its details, no file needed.
  Future<void> _addRecord(List<CompanyDoc> all) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final place = _place!;
    final details = await showDocDetailsDialog(context, section: place.section, companyId: place.companyId);
    if (details == null) return;
    try {
      await uploadCompanyDoc(all, place, null, details);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    }
  }

  void _addMenu(List<CompanyDoc> all) {
    final l10n = AppLocalizations.of(context);
    final section = widget.section!;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (section.expires)
              ListTile(
                leading: Icon(docSectionIcon(section)),
                title: Text(section == DocSection.subscription ? l10n.docAddSubscription : l10n.docAddService),
                onTap: () {
                  Navigator.pop(sheet);
                  _addRecord(all);
                },
              ),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: Text(l10n.docUploadFiles),
              onTap: () {
                Navigator.pop(sheet);
                _upload(all);
              },
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: Text(l10n.docNewFolder),
              onTap: () {
                Navigator.pop(sheet);
                _newFolder(all);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final me = ref.watch(currentUserProvider).value;
    if (me == null) return const SizedBox.shrink();
    final docsAsync = ref.watch(companyDocsProvider);
    final all = docsAsync.value ?? const <CompanyDoc>[];
    final companies = ref.watch(companiesProvider).value ?? const <Company>[];
    final companyNames = ref.watch(companyNamesProvider);
    final personNames = {for (final u in ref.watch(usersProvider).value ?? const <AppUser>[]) u.id: u.name};
    final sections = docSectionsFor(me.role);
    final section = widget.section;
    if (section != null && !sections.contains(section)) {
      return Scaffold(appBar: AppBar(), body: Center(child: Text(l10n.docNotFound)));
    }
    final place = _place;
    final editable = section != null && canEditDocSection(me.role, section);
    final today = DateTime.now();
    final query = _search.text.trim();

    // Files below this page (for search and "select all").
    final scope = [
      for (final d in all)
        if (section == null || d.section == section) d,
    ];
    final below = widget.folderId.isNotEmpty
        ? docDescendants(all, widget.folderId)
        : section == DocSection.official && widget.companyId.isNotEmpty
            ? [for (final d in scope) if (d.companyId == widget.companyId) d]
            : scope;
    final results = query.isEmpty ? const <CompanyDoc>[] : searchDocs(below, query, personNames);
    final items = place == null || query.isNotEmpty || (section == DocSection.official && widget.companyId.isEmpty && widget.folderId.isEmpty)
        ? const <CompanyDoc>[]
        : docsIn(all, place);
    // Official top: a folder per company of the group, then items with no company.
    final officialTop = section == DocSection.official && widget.companyId.isEmpty && widget.folderId.isEmpty && query.isEmpty;
    final companyRows = officialTop
        ? [
            for (final c in companies)
              if (c.active || all.any((d) => d.section == DocSection.official && d.companyId == c.id)) c,
          ]
        : const <Company>[];
    final noCompany = officialTop ? docsIn(all, (section: DocSection.official, companyId: '', folderId: '')) : const <CompanyDoc>[];
    final visibleFiles = [
      for (final d in [...results, ...items, ...noCompany])
        if (d.hasFile) d,
    ];

    final folder = widget.folderId.isEmpty ? null : ref.watch(companyDocProvider(widget.folderId));
    final title = folder?.name ??
        (widget.companyId.isNotEmpty
            ? companyNames[widget.companyId] ?? l10n.company
            : section == null
                ? l10n.companyDocs
                : docSectionLabel(l10n, section));
    final crumbs = [
      if (section != null && (widget.companyId.isNotEmpty || widget.folderId.isNotEmpty)) docSectionLabel(l10n, section),
      if (widget.companyId.isNotEmpty && widget.folderId.isNotEmpty) companyNames[widget.companyId] ?? '',
      if (widget.folderId.isNotEmpty) ...[for (final f in docPath(all, widget.folderId)) f.name]..removeLast(),
    ];

    Widget tile(CompanyDoc d) => _DocTile(
          doc: d,
          today: today,
          editable: editable,
          showRestricted: me.can.seesAllCompanyDocs,
          personName: personNames[d.personId],
          path: query.isEmpty ? null : [for (final f in docPath(all, d.parentId)) f.name].join(' › '),
          selecting: _selecting,
          selected: _selected.contains(d.id),
          onSelected: (v) => setState(() => v ? _selected.add(d.id) : _selected.remove(d.id)),
          onLongPress: d.isFolder
              ? null
              : () => setState(() {
                    _selecting = true;
                    _selected.add(d.id);
                  }),
        );

    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_endSelecting);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _selecting
              ? IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: l10n.cancel,
                  onPressed: () => setState(_endSelecting),
                )
              : null,
          title: _selecting
              ? Text(l10n.selectedCount(_selected.length))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, overflow: TextOverflow.ellipsis),
                    if (crumbs.isNotEmpty)
                      Text(crumbs.join(' › '), overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                  ],
                ),
          actions: [
            if (_selecting) ...[
              IconButton(
                icon: const Icon(Icons.select_all),
                tooltip: l10n.selectAll,
                onPressed: () => setState(() => _selected.addAll([for (final d in visibleFiles) d.id])),
              ),
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: l10n.docShare,
                onPressed: _selected.isEmpty
                    ? null
                    : () => shareCompanyDocs(context, [for (final d in all) if (_selected.contains(d.id)) d]),
              ),
            ] else if (visibleFiles.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.checklist),
                tooltip: l10n.docSelectToShare,
                onPressed: () => setState(() => _selecting = true),
              ),
          ],
        ),
        floatingActionButton: editable && !_selecting && query.isEmpty
            ? FloatingActionButton.extended(
                onPressed: () => _addMenu(all),
                icon: const Icon(Icons.add),
                label: Text(l10n.add),
              )
            : null,
        body: ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: l10n.docSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(icon: const Icon(Icons.clear), tooltip: l10n.clear, onPressed: () => setState(_search.clear)),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            if (docsAsync.isLoading && !docsAsync.hasValue) const LinearProgressIndicator(),
            if (docsAsync.hasError) ListTile(title: Text(l10n.errorWithMessage('${docsAsync.error}'))),
            if (_uploading > 0)
              ListTile(
                dense: true,
                leading: const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                title: Text(l10n.uploading),
              ),
            if (query.isNotEmpty) ...[
              if (results.isEmpty) ListTile(title: Text(l10n.docNoResults)),
              for (final d in results) tile(d),
            ] else if (section == null)
              for (final s in sections)
                _SectionTile(
                  section: s,
                  files: all.where((d) => d.section == s && !d.isFolder).length,
                  due: all.where((d) => d.section == s && d.needsRenewal(today)).length,
                )
            else if (officialTop) ...[
              for (final c in companyRows)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(Icons.business, color: theme.colorScheme.onPrimaryContainer),
                  ),
                  title: Text(c.name),
                  subtitle: Text(l10n.docFileCount(
                    all.where((d) => d.section == DocSection.official && d.companyId == c.id && !d.isFolder).length,
                  )),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(docPlaceLocation(DocSection.official, companyId: c.id)),
                ),
              for (final d in noCompany) tile(d),
              if (companyRows.isEmpty && noCompany.isEmpty) ListTile(title: Text(l10n.docEmpty)),
            ] else ...[
              for (final d in items) tile(d),
              if (items.isEmpty && docsAsync.hasValue)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(editable ? l10n.docEmptyEditable : l10n.docEmpty, textAlign: TextAlign.center),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({required this.section, required this.files, required this.due});

  final DocSection section;
  final int files;
  final int due;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(docSectionIcon(section), color: theme.colorScheme.onPrimaryContainer),
        ),
        title: Text(docSectionLabel(l10n, section), style: theme.textTheme.titleMedium),
        subtitle: Text('${docSectionHint(l10n, section)}\n${l10n.docFileCount(files)}'),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (due > 0) Badge(label: Text('$due'), backgroundColor: Colors.orange.shade800),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => context.push(docPlaceLocation(section)),
      ),
    );
  }
}

/// A folder or file row.
class _DocTile extends ConsumerWidget {
  const _DocTile({
    required this.doc,
    required this.today,
    required this.editable,
    required this.showRestricted,
    required this.personName,
    required this.path,
    required this.selecting,
    required this.selected,
    required this.onSelected,
    required this.onLongPress,
  });

  final CompanyDoc doc;
  final DateTime today;
  final bool editable;

  /// Shows the lock on management-only items (to those who see them).
  final bool showRestricted;
  final String? personName;

  /// Search results: the folders it's in.
  final String? path;
  final bool selecting;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final d = doc;
    final all = ref.watch(companyDocsProvider).value ?? const <CompanyDoc>[];
    final state = d.expiryState(today);
    final subtitle = [
      if (path != null && path!.isNotEmpty) path!,
      if (d.isFolder)
        l10n.docFileCount(docDescendants(all, d.id).where((x) => !x.isFolder).length)
      else ...[
        ?personName,
        if (d.isHealthInsurance) l10n.docHealthInsurance,
        if (d.insuranceClass.isNotEmpty) l10n.docClassValue(d.insuranceClass),
        if (d.docNumber.isNotEmpty) d.docNumber,
        if (d.loginUrl.isNotEmpty) Uri.tryParse(d.loginUrl)?.host ?? d.loginUrl,
        if (d.username.isNotEmpty) d.username,
        if (!d.section.expires && d.updatedAt != null)
          DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(d.updatedAt!),
      ],
    ].join(' · ');
    final restrictedMark = showRestricted && d.ownRestricted && d.section.salesVisible;
    void open() => d.isFolder
        ? context.push(docPlaceLocation(d.section, companyId: d.companyId, folderId: d.id))
        : context.push('/documents/file/${d.id}');
    return ListTile(
      leading: d.isImage && d.thumbUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(d.thumbUrl, width: 40, height: 40, fit: BoxFit.cover,
                  webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                  errorBuilder: (_, _, _) => Icon(docFileIcon(d))),
            )
          : Icon(docFileIcon(d), size: 32, color: d.isFolder ? Colors.amber.shade700 : d.isPdf && d.hasFile ? Colors.red.shade700 : null),
      title: Row(
        children: [
          Flexible(child: Text(d.name, overflow: TextOverflow.ellipsis)),
          if (restrictedMark)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 6),
              child: Tooltip(message: l10n.docManagementOnly, child: Icon(Icons.lock_outline, size: 16, color: theme.disabledColor)),
            ),
        ],
      ),
      subtitle: state == DocExpiryState.none
          ? (subtitle.isEmpty ? null : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis))
          : Text.rich(
              TextSpan(children: [
                TextSpan(text: docExpiryText(context, d, today), style: TextStyle(color: docExpiryColor(context, state))),
                if (subtitle.isNotEmpty) TextSpan(text: ' · $subtitle'),
              ]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: selecting
          ? (d.hasFile ? Checkbox(value: selected, onChanged: (v) => onSelected(v ?? false)) : null)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (d.hasFile)
                  IconButton(icon: const Icon(Icons.share_outlined), tooltip: l10n.docShare, onPressed: () => shareCompanyDocs(context, [d])),
                if (editable) _ItemMenu(item: d) else if (d.isFolder) const Icon(Icons.chevron_right),
              ],
            ),
      onTap: selecting ? (d.hasFile ? () => onSelected(!selected) : null) : open,
      onLongPress: selecting || !d.hasFile ? null : onLongPress,
    );
  }
}

/// ⋮ of an item for editors: details, move, delete (files: also replace,
/// renew).
class _ItemMenu extends ConsumerWidget {
  const _ItemMenu({required this.item});

  final CompanyDoc item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      tooltip: l10n.moreOptions,
      onSelected: (v) => switch (v) {
        'edit' => editCompanyDoc(context, ref, item),
        'renew' => renewCompanyDocDialog(context, item),
        'replace' => replaceCompanyDocFileDialog(context, item),
        'move' => moveCompanyDocDialog(context, ref, item),
        _ => deleteCompanyDocDialog(context, ref, item),
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 'edit', child: ListTile(leading: const Icon(Icons.edit_outlined), title: Text(item.isFolder ? l10n.docEditFolder : l10n.docEditDetails))),
        if (item.section.expires && !item.isFolder)
          PopupMenuItem(value: 'renew', child: ListTile(leading: const Icon(Icons.event_repeat), title: Text(l10n.markRenewed))),
        if (!item.isFolder)
          PopupMenuItem(
            value: 'replace',
            child: ListTile(leading: const Icon(Icons.upload_file), title: Text(item.hasFile ? l10n.docReplaceFile : l10n.docAttachFile)),
          ),
        PopupMenuItem(value: 'move', child: ListTile(leading: const Icon(Icons.drive_file_move_outlined), title: Text(l10n.docMove))),
        PopupMenuItem(value: 'delete', child: ListTile(leading: const Icon(Icons.delete_outline), title: Text(l10n.delete))),
      ],
    );
  }
}

/// Edits a folder (name, management only) or a file's details.
Future<void> editCompanyDoc(BuildContext context, WidgetRef ref, CompanyDoc item) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final all = ref.read(companyDocsProvider).value ?? const <CompanyDoc>[];
  try {
    if (item.isFolder) {
      final result = await showDocFolderDialog(context, section: item.section, folder: item);
      if (result != null) await updateDocFolder(all, item, name: result.name, ownRestricted: result.ownRestricted);
    } else {
      final details = await showDocDetailsDialog(
        context,
        section: item.section,
        doc: item,
        companyEditable: item.section == DocSection.official && item.parentId.isEmpty,
      );
      if (details != null) await updateCompanyDoc(all, item, details);
    }
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
  }
}

/// Picks a new file for [doc]; the old one stays in its history.
Future<void> replaceCompanyDocFileDialog(BuildContext context, CompanyDoc doc) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final files = await pickCompanyDocFiles(context);
  if (files.isEmpty) return;
  try {
    await replaceCompanyDocFile(doc, files.first);
    if (doc.hasFile) messenger.showSnackBar(SnackBar(content: Text(l10n.docFileReplaced)));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
  }
}

/// A file's page (`/documents/file/:id`): preview, Open / Share, details,
/// and for editors the changes; earlier files and renewals below.
class CompanyDocScreen extends ConsumerWidget {
  const CompanyDocScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final me = ref.watch(currentUserProvider).value;
    final docsAsync = ref.watch(companyDocsProvider);
    final doc = ref.watch(companyDocProvider(id));
    if (me == null || doc == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: docsAsync.isLoading ? const CircularProgressIndicator() : Text(l10n.docNotFound)),
      );
    }
    final all = docsAsync.value ?? const <CompanyDoc>[];
    final names = {for (final u in ref.watch(usersProvider).value ?? const <AppUser>[]) u.id: u.name};
    final companyNames = ref.watch(companyNamesProvider);
    final locale = Localizations.localeOf(context).toString();
    final today = DateTime.now();
    final editable = canEditDocSection(me.role, doc.section);
    final folders = docPath(all, doc.parentId);
    final where = [
      docSectionLabel(l10n, doc.section),
      if (doc.section == DocSection.official && doc.companyId.isNotEmpty) companyNames[doc.companyId] ?? '',
      for (final f in folders) f.name,
    ].join(' › ');
    String when(DateTime? t) => t == null ? '' : DateFormat.yMMMd(locale).add_jm().format(t);
    final versions = [...doc.versions]..sort((a, b) => (b.replacedAt ?? DateTime(0)).compareTo(a.replacedAt ?? DateTime(0)));

    return Scaffold(
      appBar: AppBar(
        title: Text(doc.name, overflow: TextOverflow.ellipsis),
        actions: [if (editable) _ItemMenu(item: doc)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  InkWell(
                    onTap: doc.hasFile ? () => openCompanyDoc(doc.url) : null,
                    child: doc.isImage && doc.hasFile
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              doc.thumbUrl.isNotEmpty ? doc.thumbUrl : doc.url,
                              height: 180,
                              fit: BoxFit.contain,
                              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                              errorBuilder: (_, _, _) => Icon(docFileIcon(doc), size: 72),
                            ),
                          )
                        : Icon(docFileIcon(doc), size: 72, color: doc.isPdf && doc.hasFile ? Colors.red.shade700 : null),
                  ),
                  const SizedBox(height: 8),
                  if (doc.hasFile) ...[
                    Text(doc.fileName, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                    Text(formatDocSize(doc.size), style: theme.textTheme.bodySmall),
                  ] else
                    Text(l10n.docNoFile, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                  if (doc.section.expires) ...[
                    const SizedBox(height: 8),
                    DocExpiryChip(doc: doc, today: today),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      if (doc.hasFile) ...[
                        FilledButton.icon(
                          onPressed: () => openCompanyDoc(doc.url),
                          icon: const Icon(Icons.open_in_new),
                          label: Text(l10n.docOpen),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () => shareCompanyDocs(context, [doc]),
                          icon: const Icon(Icons.share),
                          label: Text(l10n.docShare),
                        ),
                      ] else if (editable)
                        FilledButton.tonalIcon(
                          onPressed: () => replaceCompanyDocFileDialog(context, doc),
                          icon: const Icon(Icons.upload_file),
                          label: Text(l10n.docAttachFile),
                        ),
                      if (editable && doc.section.expires)
                        OutlinedButton.icon(
                          onPressed: () => renewCompanyDocDialog(context, doc),
                          icon: const Icon(Icons.event_repeat),
                          label: Text(l10n.markRenewed),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.folder_open_outlined),
                  title: Text(l10n.docLocation),
                  subtitle: Text(where),
                  onTap: () => context.push(docPlaceLocation(doc.section, companyId: doc.companyId, folderId: doc.parentId)),
                ),
                if (doc.section == DocSection.expiring && !doc.isHealthInsurance)
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(l10n.docEmployee),
                    subtitle: Text(doc.personId.isEmpty ? l10n.docForCompany : names[doc.personId] ?? l10n.deletedUser),
                  ),
                if (doc.isHealthInsurance) ...[
                  ListTile(leading: const Icon(Icons.health_and_safety_outlined), title: Text(l10n.docHealthInsurance), subtitle: Text(l10n.docHealthInsuranceHint)),
                  ListTile(
                    leading: const Icon(Icons.workspace_premium_outlined),
                    title: Text(l10n.docUsualClass),
                    subtitle: Text(doc.insuranceClass.isEmpty ? '—' : doc.insuranceClass),
                  ),
                ],
                if (doc.docNumber.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.tag),
                    title: Text(doc.isHealthInsurance ? l10n.docPolicyNumber : l10n.docNumber),
                    subtitle: Text(doc.docNumber),
                  ),
                if (doc.section == DocSection.subscription) SubscriptionLoginTiles(doc: doc),
                if (doc.issueDate.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.event_available_outlined),
                    title: Text(l10n.docIssueDate),
                    subtitle: Text(formatDocDay(context, doc.issueDate)),
                  ),
                if (doc.section.expires)
                  ListTile(
                    leading: Icon(Icons.event_busy_outlined, color: docExpiryColor(context, doc.expiryState(today))),
                    title: Text(l10n.docExpiryDate),
                    subtitle: Text(doc.expiry.isEmpty ? l10n.docNoExpiry : formatDocDay(context, doc.expiry)),
                  ),
                if (doc.notes.isNotEmpty)
                  ListTile(leading: const Icon(Icons.notes), title: Text(l10n.notes), subtitle: Text(doc.notes)),
                if (me.can.seesAllCompanyDocs && doc.section.salesVisible)
                  ListTile(
                    leading: Icon(doc.restricted ? Icons.lock_outline : Icons.groups_outlined),
                    title: Text(doc.restricted ? l10n.docManagementOnly : l10n.docSalesCanSee),
                  ),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(l10n.docLastChange),
                  subtitle: Text([names[doc.updatedBy] ?? '', when(doc.updatedAt ?? doc.createdAt)].where((s) => s.isNotEmpty).join(' · ')),
                ),
              ],
            ),
          ),
          if (doc.isHealthInsurance) InsuredEmployeesCard(policy: doc, editable: editable),
          if (versions.isNotEmpty || doc.renewals.isNotEmpty)
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(l10n.docHistory, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
                  ),
                  for (final r in doc.renewals.reversed)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.event_repeat),
                      title: Text(l10n.docRenewedTo(formatDocDay(context, r.expiry))),
                      subtitle: Text([
                        if (r.previous.isNotEmpty) l10n.docWasUntil(formatDocDay(context, r.previous)),
                        names[r.byId] ?? '',
                        when(r.at),
                      ].where((s) => s.isNotEmpty).join(' · ')),
                    ),
                  for (final v in versions)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.description_outlined),
                      title: Text(v.fileName),
                      subtitle: Text([
                        l10n.docReplacedOn(when(v.replacedAt)),
                        if (v.expiry.isNotEmpty) l10n.docWasUntil(formatDocDay(context, v.expiry)),
                        names[v.byId] ?? '',
                      ].where((s) => s.isNotEmpty).join(' · ')),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () => openCompanyDoc(v.url),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
