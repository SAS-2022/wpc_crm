import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_user.dart';
import '../../core/password_field.dart';
import '../../core/providers.dart';
import '../../core/saving.dart';
import '../../l10n/app_localizations.dart';
import '../attachments/attachments.dart' show PendingFile;
import '../attachments/attachments_section.dart' show pickAttachments;
import '../settings/page_access.dart';
import '../users/companies.dart';
import '../users/users_repository.dart';
import 'company_docs.dart';
import 'company_docs_repository.dart';

String docSectionLabel(AppLocalizations l10n, DocSection s) => switch (s) {
      DocSection.official => l10n.docSectionOfficial,
      DocSection.expiring => l10n.docSectionExpiring,
      DocSection.subscription => l10n.docSectionSubscription,
      DocSection.product => l10n.docSectionProduct,
    };

String docSectionHint(AppLocalizations l10n, DocSection s) => switch (s) {
      DocSection.official => l10n.docSectionOfficialHint,
      DocSection.expiring => l10n.docSectionExpiringHint,
      DocSection.subscription => l10n.docSectionSubscriptionHint,
      DocSection.product => l10n.docSectionProductHint,
    };

IconData docSectionIcon(DocSection s) => switch (s) {
      DocSection.official => Icons.account_balance_outlined,
      DocSection.expiring => Icons.miscellaneous_services_outlined,
      DocSection.subscription => Icons.vpn_key_outlined,
      DocSection.product => Icons.inventory_2_outlined,
    };

IconData docFileIcon(CompanyDoc d) => d.isFolder
    ? Icons.folder
    : d.isHealthInsurance
        ? Icons.health_and_safety_outlined
        : !d.hasFile
            ? docSectionIcon(d.section)
            : d.isPdf
        ? Icons.picture_as_pdf
        : d.isImage
            ? Icons.image_outlined
            : Icons.insert_drive_file_outlined;

/// The page of a place in the tree.
String docPlaceLocation(DocSection section, {String companyId = '', String folderId = ''}) => Uri(
      path: '/documents',
      queryParameters: {
        's': section.name,
        if (companyId.isNotEmpty) 'c': companyId,
        if (folderId.isNotEmpty) 'f': folderId,
      },
    ).toString();

Color docExpiryColor(BuildContext context, DocExpiryState s) => switch (s) {
      DocExpiryState.ok => Colors.green.shade700,
      DocExpiryState.dueSoon => Colors.orange.shade800,
      DocExpiryState.expired => Theme.of(context).colorScheme.error,
      DocExpiryState.none => Theme.of(context).disabledColor,
    };

String formatDocDay(BuildContext context, String day) {
  final d = DateTime.tryParse(day);
  return d == null ? day : DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(d);
}

/// "Expires in 12 days" / "Expired 4 days ago" / "Valid until Mar 3, 2027" / "No expiry date".
String docExpiryText(BuildContext context, CompanyDoc d, DateTime today) {
  final l10n = AppLocalizations.of(context);
  final state = docExpiryState(d.expiry, today);
  if (state == DocExpiryState.none) return l10n.docNoExpiry;
  final days = docDaysLeft(d.expiry, today);
  if (state == DocExpiryState.ok) return l10n.docValidUntil(formatDocDay(context, d.expiry));
  if (days > 0) return l10n.docExpiresIn(days);
  return days == 0 ? l10n.docExpiresToday : l10n.docExpiredAgo(-days);
}

String formatDocSize(int bytes) {
  if (bytes >= 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  return '${(bytes / 1024).ceil()} KB';
}

void openCompanyDoc(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

/// The name a shared file gets: the document's name with the file's
/// extension.
String shareFileName(CompanyDoc d) {
  final ext = d.fileName.contains('.') ? '.${d.fileName.split('.').last}' : '';
  final base = d.name.replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_').trim();
  return ext.isEmpty || base.toLowerCase().endsWith(ext.toLowerCase()) ? base : '$base$ext';
}

/// Shares one or several files as files, never as links (user request
/// 2026-11-01: the receiver sees only the file name): downloaded, then
/// handed to the phone's share sheet (WhatsApp, email, Drive …) under the
/// document's name. On the web the browser's share sheet gets the files
/// (phone browsers); browsers without one download them instead. The web
/// needs CORS on the Storage bucket to fetch the files.
Future<void> shareCompanyDocs(BuildContext context, List<CompanyDoc> docs) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final box = context.findRenderObject() as RenderBox?;
  final files = [for (final d in docs) if (!d.isFolder && d.url.isNotEmpty) d];
  if (files.isEmpty) return;
  final shared = <XFile>[];
  try {
    await saving(() async {
      for (final d in files) {
        final res = await http.get(Uri.parse(d.url));
        if (res.statusCode != 200) throw Exception('${d.name}: HTTP ${res.statusCode}');
        shared.add(XFile.fromData(res.bodyBytes, mimeType: d.contentType, name: shareFileName(d)));
      }
    });
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.docShareFailed)));
    return;
  }
  try {
    await SharePlus.instance.share(ShareParams(
      files: shared,
      fileNameOverrides: [for (final d in files) shareFileName(d)],
      downloadFallbackEnabled: true,
      // iPad: the share popover points at the button.
      sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    ));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.docShareFailed)));
  }
}

/// A small coloured chip with the expiry state.
class DocExpiryChip extends StatelessWidget {
  const DocExpiryChip({super.key, required this.doc, required this.today});

  final CompanyDoc doc;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final color = docExpiryColor(context, doc.expiryState(today));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event, size: 16, color: color),
          const SizedBox(width: 4),
          Flexible(child: Text(docExpiryText(context, doc, today), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color))),
        ],
      ),
    );
  }
}

/// Asks for a folder's name and whether it's management only. Returns null
/// when cancelled.
Future<({String name, bool ownRestricted})?> showDocFolderDialog(
  BuildContext context, {
  required DocSection section,
  CompanyDoc? folder,
}) async {
  final l10n = AppLocalizations.of(context);
  final name = TextEditingController(text: folder?.name ?? '');
  var restricted = folder?.ownRestricted ?? false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (dialog, setDialog) => AlertDialog(
        title: Text(folder == null ? l10n.docNewFolder : l10n.docEditFolder),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.docFolderName),
              onSubmitted: (_) => Navigator.pop(dialog, true),
            ),
            if (section.salesVisible)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: restricted,
                onChanged: (v) => setDialog(() => restricted = v),
                title: Text(l10n.docManagementOnly),
                subtitle: Text(l10n.docManagementOnlyHint),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l10n.save)),
        ],
      ),
    ),
  );
  final text = name.text.trim();
  name.dispose();
  if (ok != true || text.isEmpty) return null;
  return (name: text, ownRestricted: restricted);
}

/// The file form: a new file ([file] picked, [doc] null) or a document's
/// details. [companyEditable]: at the top of Official, where the company is
/// chosen. Returns null when cancelled.
Future<DocDetails?> showDocDetailsDialog(
  BuildContext context, {
  required DocSection section,
  CompanyDoc? doc,
  PendingFile? file,
  String companyId = '',
  bool companyEditable = false,
}) =>
    showDialog<DocDetails>(
      context: context,
      builder: (_) => _DocDetailsDialog(
        section: section,
        doc: doc,
        file: file,
        companyId: doc?.companyId ?? companyId,
        companyEditable: companyEditable,
      ),
    );

class _DocDetailsDialog extends ConsumerStatefulWidget {
  const _DocDetailsDialog({
    required this.section,
    required this.doc,
    required this.file,
    required this.companyId,
    required this.companyEditable,
  });

  final DocSection section;
  final CompanyDoc? doc;
  final PendingFile? file;
  final String companyId;
  final bool companyEditable;

  @override
  ConsumerState<_DocDetailsDialog> createState() => _DocDetailsDialogState();
}

class _DocDetailsDialogState extends ConsumerState<_DocDetailsDialog> {
  late final _name = TextEditingController(
    text: widget.doc?.name ?? widget.file?.name.replaceAll(RegExp(r'\.\w+$'), '').replaceAll('_', ' ') ?? '',
  );
  late final _number = TextEditingController(text: widget.doc?.docNumber ?? '');
  late final _notes = TextEditingController(text: widget.doc?.notes ?? '');
  late String _companyId = widget.companyId;
  late String _personId = widget.doc?.personId ?? '';
  late String _issueDate = widget.doc?.issueDate ?? '';
  late String _expiry = widget.doc?.expiry ?? '';
  late bool _restricted = widget.doc?.ownRestricted ?? false;
  late bool _insurance = widget.doc?.serviceType == healthInsuranceService;
  late final _class = TextEditingController(text: widget.doc?.insuranceClass ?? '');
  late final _url = TextEditingController(text: widget.doc?.loginUrl ?? '');
  late final _steps = TextEditingController(text: widget.doc?.loginSteps ?? '');
  late final _username = TextEditingController(text: widget.doc?.username ?? '');
  late final _password = TextEditingController(text: widget.doc?.password ?? '');
  bool _tried = false;

  bool get _expiring => widget.section.expires;
  bool get _service => widget.section == DocSection.expiring;
  bool get _subscription => widget.section == DocSection.subscription;

  @override
  void dispose() {
    for (final c in [_name, _number, _notes, _class, _url, _steps, _username, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDay(String current, ValueChanged<String> set, String help) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(current) ?? now,
      firstDate: DateTime(now.year - 30),
      lastDate: DateTime(now.year + 30),
      helpText: help,
    );
    if (picked != null) setState(() => set(docDay(picked)));
  }

  void _save() {
    setState(() => _tried = true);
    if (_name.text.trim().isEmpty || (_expiring && _expiry.isEmpty)) return;
    Navigator.pop<DocDetails>(context, (
      name: _name.text,
      companyId: _companyId,
      docNumber: _number.text,
      personId: _personId,
      issueDate: _issueDate,
      expiry: _expiry,
      notes: _notes.text,
      ownRestricted: _restricted,
      serviceType: _service && _insurance ? healthInsuranceService : '',
      insuranceClass: _class.text,
      loginUrl: _url.text,
      loginSteps: _steps.text,
      username: _username.text,
      password: _password.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final companies = [for (final c in ref.watch(companiesProvider).value ?? const <Company>[]) if (c.active || c.id == _companyId) c];
    final users = [for (final u in ref.watch(usersProvider).value ?? const <AppUser>[]) if (u.active || u.id == _personId) u]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    Widget dayTile(String label, String value, ValueChanged<String> set, {bool required = false}) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event),
          title: Text(label),
          subtitle: Text(
            value.isEmpty ? (required && _tried ? l10n.docExpiryRequired : '—') : formatDocDay(context, value),
            style: value.isEmpty && required && _tried ? TextStyle(color: Theme.of(context).colorScheme.error) : null,
          ),
          trailing: value.isEmpty || required
              ? const Icon(Icons.edit_calendar)
              : IconButton(icon: const Icon(Icons.clear), tooltip: l10n.clear, onPressed: () => setState(() => set(''))),
          onTap: () => _pickDay(value, set, label),
        );
    return AlertDialog(
      title: Text(widget.doc != null
          ? l10n.docEditDetails
          : widget.file != null
              ? l10n.docAddFile
              : _subscription
                  ? l10n.docAddSubscription
                  : l10n.docAddService),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.file != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.attach_file),
                  title: Text(widget.file!.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(formatDocSize(widget.file!.bytes.length)),
                ),
              TextField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: l10n.docName,
                  errorText: _tried && _name.text.trim().isEmpty ? l10n.required : null,
                ),
              ),
              if (widget.section == DocSection.official && widget.companyEditable) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: companies.any((c) => c.id == _companyId) ? _companyId : '',
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.company),
                  items: [
                    DropdownMenuItem(value: '', child: Text(l10n.docNoCompany)),
                    for (final c in companies) DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() => _companyId = v ?? ''),
                ),
              ],
              if (_service) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _insurance,
                  onChanged: (v) => setState(() => _insurance = v),
                  title: Text(l10n.docHealthInsurance),
                  subtitle: Text(l10n.docHealthInsuranceHint),
                ),
                if (_insurance)
                  TextField(
                    controller: _class,
                    decoration: InputDecoration(labelText: l10n.docUsualClass, helperText: l10n.docUsualClassHint),
                  ),
              ],
              if (_subscription) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _url,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(labelText: l10n.docLoginUrl, hintText: 'https://…'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _steps,
                  minLines: 2,
                  maxLines: 6,
                  decoration: InputDecoration(labelText: l10n.docLoginSteps, helperText: l10n.optional),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _username,
                  autofillHints: const [],
                  decoration: InputDecoration(labelText: l10n.docUsername, helperText: l10n.optional),
                ),
                const SizedBox(height: 12),
                PasswordField(controller: _password, label: l10n.docPassword, autofillHints: const []),
              ],
              if (_service && !_insurance) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: users.any((u) => u.id == _personId) ? _personId : '',
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.docEmployee),
                  items: [
                    DropdownMenuItem(value: '', child: Text(l10n.docForCompany)),
                    for (final u in users) DropdownMenuItem(value: u.id, child: Text(u.name, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() => _personId = v ?? ''),
                ),
              ],
              if (widget.section == DocSection.official || _service) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _number,
                  decoration: InputDecoration(labelText: _insurance && _service ? l10n.docPolicyNumber : l10n.docNumber),
                ),
              ],
              if (_expiring) ...[
                const SizedBox(height: 4),
                if (_service) dayTile(l10n.docIssueDate, _issueDate, (v) => _issueDate = v),
                dayTile(l10n.docExpiryDate, _expiry, (v) => _expiry = v, required: true),
              ],
              const SizedBox(height: 8),
              TextField(
                controller: _notes,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(labelText: l10n.notes),
              ),
              if (widget.section.salesVisible)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _restricted,
                  onChanged: (v) => setState(() => _restricted = v),
                  title: Text(l10n.docManagementOnly),
                  subtitle: Text(l10n.docManagementOnlyHint),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(onPressed: _save, child: Text(widget.file != null ? l10n.docUpload : l10n.save)),
      ],
    );
  }
}

/// Picks files to add (camera / gallery / file), max 50 MB each.
Future<List<PendingFile>> pickCompanyDocFiles(BuildContext context) =>
    pickAttachments(context, maxBytes: maxCompanyDocBytes);

/// Renewed: asks the new expiry (offered: a year after the old one) and,
/// optionally, the new document's file.
Future<void> renewCompanyDocDialog(BuildContext context, CompanyDoc doc) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  var day = nextDocExpiry(doc.expiry, DateTime.now());
  PendingFile? file;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (dialog, setDialog) => AlertDialog(
        title: Text(l10n.docRenewTitle(doc.name)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(l10n.docNewExpiry),
              subtitle: Text(formatDocDay(dialog, day)),
              trailing: const Icon(Icons.edit_calendar),
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: dialog,
                  initialDate: DateTime.tryParse(day) ?? now,
                  firstDate: DateTime(now.year - 10),
                  lastDate: DateTime(now.year + 30),
                  helpText: l10n.docNewExpiry,
                );
                if (picked != null) setDialog(() => day = docDay(picked));
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.attach_file),
              title: Text(file?.name ?? l10n.docNewFileOptional, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(l10n.docOldFileKept),
              trailing: file == null
                  ? const Icon(Icons.upload_file)
                  : IconButton(icon: const Icon(Icons.clear), tooltip: l10n.clear, onPressed: () => setDialog(() => file = null)),
              onTap: () async {
                final picked = await pickCompanyDocFiles(dialog);
                if (picked.isNotEmpty) setDialog(() => file = picked.first);
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l10n.save)),
        ],
      ),
    ),
  );
  if (ok != true) return;
  try {
    await renewCompanyDoc(doc, day, file);
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
  }
}

/// Asks where to move [item] (same section) and moves it.
Future<void> moveCompanyDocDialog(BuildContext context, WidgetRef ref, CompanyDoc item) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final all = ref.read(companyDocsProvider).value ?? const <CompanyDoc>[];
  final companies = ref.read(companyNamesProvider);
  String label(CompanyDoc f) => [
        if (f.section == DocSection.official && f.companyId.isNotEmpty) companies[f.companyId] ?? '?',
        for (final p in docPath(all, f.id)) p.name,
      ].join(' › ');
  // Top of the section; at the top of Official, one per company.
  final tops = <(String, String)>[
    if (item.section == DocSection.official) ...[
      for (final c in ref.read(companiesProvider).value ?? const <Company>[]) if (c.active) (c.id, c.name),
      ('', l10n.docNoCompany),
    ] else
      ('', docSectionLabel(l10n, item.section)),
  ];
  final folders = docMoveTargets(all, item)..sort((a, b) => label(a).compareTo(label(b)));
  final picked = await showDialog<(CompanyDoc?, String)>(
    context: context,
    builder: (dialog) => SimpleDialog(
      title: Text(l10n.docMoveTo(item.name)),
      children: [
        for (final (id, name) in tops)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialog, (null, id)),
            child: ListTile(dense: true, leading: Icon(docSectionIcon(item.section)), title: Text(name)),
          ),
        for (final f in folders)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialog, (f, f.companyId)),
            child: ListTile(dense: true, leading: const Icon(Icons.folder_outlined), title: Text(label(f))),
          ),
      ],
    ),
  );
  if (picked == null) return;
  try {
    await moveCompanyDoc(all, item, picked.$1, picked.$2);
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
  }
}

/// Asks first, then deletes [item] (a folder with all it holds). Returns
/// whether it was deleted.
Future<bool> deleteCompanyDocDialog(BuildContext context, WidgetRef ref, CompanyDoc item) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final all = ref.read(companyDocsProvider).value ?? const <CompanyDoc>[];
  final inside = item.isFolder ? docDescendants(all, item.id).where((d) => !d.isFolder).length : 0;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(l10n.docDeleteTitle(item.name)),
      content: Text(item.isFolder ? l10n.docDeleteFolderText(inside) : l10n.docDeleteFileText),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.cancel)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(dialog).colorScheme.error),
          onPressed: () => Navigator.pop(dialog, true),
          child: Text(l10n.delete),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  try {
    await deleteCompanyDoc(all, item);
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    return false;
  }
}

/// Home card for HR, the GM and the sales manager: every expiring document
/// expired or due within App settings `docRenewalDays` (30), until it's
/// renewed. Hidden when there are none.
class CompanyDocRenewalsCard extends ConsumerWidget {
  const CompanyDocRenewalsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider).value;
    if (me == null || !me.role.seesAllCompanyDocs) return const SizedBox.shrink();
    if (!(ref.watch(pageAccessProvider).value ?? PageAccess.defaults).allowsUser(me, AppPage.companyDocs)) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final today = DateTime.now();
    final names = {for (final u in ref.watch(usersProvider).value ?? const <AppUser>[]) u.id: u.name};
    final due = [
      for (final d in ref.watch(companyDocsProvider).value ?? const <CompanyDoc>[])
        if (d.needsRenewal(today)) d,
    ]..sort((a, b) => a.expiry.compareTo(b.expiry));
    if (due.isEmpty) return const SizedBox.shrink();
    bool canRenew(CompanyDoc d) => canEditDocSection(me.role, d.section);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(l10n.docRenewalsDue(due.length), style: Theme.of(context).textTheme.titleMedium),
            ),
            for (final d in due.take(8))
              ListTile(
                dense: true,
                leading: Icon(Icons.event_busy_outlined, color: docExpiryColor(context, d.expiryState(today))),
                title: Text([d.name, ?names[d.personId]].join(' · ')),
                subtitle: Text(docExpiryText(context, d, today), style: TextStyle(color: docExpiryColor(context, d.expiryState(today)))),
                trailing: canRenew(d) ? TextButton(onPressed: () => renewCompanyDocDialog(context, d), child: Text(l10n.markRenewed)) : null,
                onTap: () => context.push('/documents/file/${d.id}'),
              ),
            if (due.length > 8)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () => context.push(docPlaceLocation(DocSection.expiring)),
                  child: Text(l10n.viewAll),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
