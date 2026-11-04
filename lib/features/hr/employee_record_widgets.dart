import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../documents/company_docs.dart';
import '../documents/company_docs_repository.dart';
import '../documents/company_docs_widgets.dart';
import '../users/users_repository.dart';
import 'employee_record.dart';
import 'employee_records_repository.dart';

String idTypeLabel(AppLocalizations l10n, IdType t) => switch (t) {
      IdType.iqama => l10n.idTypeIqama,
      IdType.nationalId => l10n.idTypeNationalId,
    };

/// "Expires in 12 days" / "Expired 4 days ago" / "Valid until …" for an ID.
String idExpiryText(BuildContext context, String expiry, DateTime today) {
  final l10n = AppLocalizations.of(context);
  final state = docExpiryState(expiry, today);
  if (state == DocExpiryState.none) return l10n.idExpiryNotSet;
  final days = docDaysLeft(expiry, today);
  if (state == DocExpiryState.ok) return l10n.docValidUntil(formatDocDay(context, expiry));
  if (days > 0) return l10n.docExpiresIn(days);
  return days == 0 ? l10n.docExpiresToday : l10n.docExpiredAgo(-days);
}

/// HR area: [uid]'s Iqama / national ID, nationality and health insurance,
/// with Edit for HR / GM / SM. Shown on the HR employee page and the user
/// form. Hidden from everyone else (the records are HR-only).
class EmployeeRecordCard extends ConsumerWidget {
  const EmployeeRecordCard({super.key, required this.uid, this.margin});

  final String uid;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider).value;
    if (me == null || !me.role.canSeeHr) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final records = ref.watch(employeeRecordsProvider);
    final record = records.value?[uid] ?? EmployeeRecord(uid: uid);
    final policies = healthInsurances(ref.watch(companyDocsProvider).value ?? const <CompanyDoc>[]);
    final ins = insuranceOf(record, policies);
    final today = DateTime.now();
    final idState = docExpiryState(record.idExpiry, today);
    final canEdit = me.role.canManageHr;
    return Card(
      margin: margin,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(l10n.employeeRecordTitle, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
                ),
                if (canEdit)
                  TextButton.icon(
                    onPressed: records.hasValue ? () => editEmployeeRecord(context, ref, record) : null,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text(l10n.edit),
                  ),
              ],
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.badge_outlined),
              title: Text(record.idNumber.isEmpty ? idTypeLabel(l10n, record.idType) : '${idTypeLabel(l10n, record.idType)} · ${record.idNumber}'),
              subtitle: Text(
                record.hasId ? idExpiryText(context, record.idExpiry, today) : l10n.idNotEntered,
                style: TextStyle(color: idState == DocExpiryState.none ? null : docExpiryColor(context, idState)),
              ),
              trailing: canEdit && record.idNeedsRenewal(today)
                  ? TextButton(onPressed: () => renewEmployeeIdDialog(context, record), child: Text(l10n.markRenewed))
                  : null,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.flag_outlined),
              title: Text(l10n.nationality),
              subtitle: Text(record.nationality.isEmpty ? '—' : record.nationality),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.health_and_safety_outlined),
              title: Text(l10n.docHealthInsurance),
              subtitle: Text(ins == null
                  ? (record.insuranceId == noInsurance ? l10n.insuranceNotCovered : l10n.insuranceNoPolicy)
                  : [
                      ins.policy.name,
                      if (ins.insuranceClass.isNotEmpty) l10n.docClassValue(ins.insuranceClass),
                      docExpiryText(context, ins.policy, today),
                    ].join(' · ')),
              onTap: ins == null ? null : () => context.push('/documents/file/${ins.policy.id}'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The edit form of [record] (HR / GM / SM).
Future<void> editEmployeeRecord(BuildContext context, WidgetRef ref, EmployeeRecord record) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final policies = healthInsurances(ref.read(companyDocsProvider).value ?? const <CompanyDoc>[]);
  final known = {
    ...commonNationalities,
    for (final r in (ref.read(employeeRecordsProvider).value ?? const {}).values) if (r.nationality.isNotEmpty) r.nationality,
  }.toList()
    ..sort();
  final classes = {
    for (final p in policies) if (p.insuranceClass.isNotEmpty) p.insuranceClass,
    for (final r in (ref.read(employeeRecordsProvider).value ?? const {}).values) if (r.insuranceClass.isNotEmpty) r.insuranceClass,
  }.toList()
    ..sort();
  final saved = await showDialog<EmployeeRecord>(
    context: context,
    builder: (_) => _EmployeeRecordDialog(record: record, policies: policies, nationalities: known, classes: classes),
  );
  if (saved == null) return;
  try {
    await saveEmployeeRecord(saved);
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
  }
}

class _EmployeeRecordDialog extends StatefulWidget {
  const _EmployeeRecordDialog({required this.record, required this.policies, required this.nationalities, required this.classes});

  final EmployeeRecord record;
  final List<CompanyDoc> policies;
  final List<String> nationalities;
  final List<String> classes;

  @override
  State<_EmployeeRecordDialog> createState() => _EmployeeRecordDialogState();
}

class _EmployeeRecordDialogState extends State<_EmployeeRecordDialog> {
  late IdType _type = widget.record.idType;
  late final _number = TextEditingController(text: widget.record.idNumber);
  late String _expiry = widget.record.idExpiry;
  late String _nationality = widget.record.nationality;
  late String _insuranceId = widget.record.insuranceId == noInsurance || widget.policies.any((p) => p.id == widget.record.insuranceId)
      ? widget.record.insuranceId
      : '';
  late final _class = TextEditingController(text: widget.record.insuranceClass);

  @override
  void dispose() {
    _number.dispose();
    _class.dispose();
    super.dispose();
  }

  CompanyDoc? get _policy => _insuranceId == noInsurance
      ? null
      : widget.policies.where((p) => p.id == _insuranceId).firstOrNull ?? widget.policies.firstOrNull;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final policy = _policy;
    return AlertDialog(
      title: Text(l10n.employeeRecordTitle),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<IdType>(
                segments: [
                  for (final t in IdType.values) ButtonSegment(value: t, label: Text(idTypeLabel(l10n, t))),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _number,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.idNumber),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: Text(l10n.idExpiryDate),
                subtitle: Text(_expiry.isEmpty ? '—' : formatDocDay(context, _expiry)),
                trailing: _expiry.isEmpty
                    ? const Icon(Icons.edit_calendar)
                    : IconButton(icon: const Icon(Icons.clear), tooltip: l10n.clear, onPressed: () => setState(() => _expiry = '')),
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.tryParse(_expiry) ?? now,
                    firstDate: DateTime(now.year - 10),
                    lastDate: DateTime(now.year + 30),
                    helpText: l10n.idExpiryDate,
                  );
                  if (picked != null) setState(() => _expiry = docDay(picked));
                },
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(l10n.idReminderHint, style: Theme.of(context).textTheme.bodySmall),
              ),
              Autocomplete<String>(
                initialValue: TextEditingValue(text: _nationality),
                optionsBuilder: (v) {
                  final q = v.text.trim().toLowerCase();
                  return q.isEmpty ? const [] : widget.nationalities.where((n) => n.toLowerCase().contains(q));
                },
                onSelected: (v) => _nationality = v,
                fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
                  controller: controller,
                  focusNode: focus,
                  decoration: InputDecoration(labelText: l10n.nationality),
                  onChanged: (v) => _nationality = v,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _insuranceId,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.docHealthInsurance),
                items: [
                  DropdownMenuItem(
                    value: '',
                    child: Text(widget.policies.isEmpty
                        ? l10n.insuranceNoPolicy
                        : l10n.insuranceUsual(widget.policies.first.name), overflow: TextOverflow.ellipsis),
                  ),
                  for (final p in widget.policies.skip(1)) DropdownMenuItem(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: noInsurance, child: Text(l10n.insuranceNotCovered)),
                ],
                onChanged: (v) => setState(() => _insuranceId = v ?? ''),
              ),
              if (policy != null) ...[
                const SizedBox(height: 12),
                if (widget.classes.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final c in widget.classes)
                        ChoiceChip(
                          label: Text(c),
                          selected: _class.text.trim() == c,
                          onSelected: (_) => setState(() => _class.text = c),
                        ),
                    ],
                  ),
                TextField(
                  controller: _class,
                  decoration: InputDecoration(
                    labelText: l10n.docInsuranceClass,
                    helperText: l10n.docClassEmptyHint(policy.insuranceClass.isEmpty ? '—' : policy.insuranceClass),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: () {
            final cls = _class.text.trim();
            Navigator.pop(
              context,
              EmployeeRecord(
                uid: widget.record.uid,
                idType: _type,
                idNumber: _number.text,
                idExpiry: _expiry,
                nationality: _nationality,
                insuranceId: _insuranceId,
                // The policy's usual class typed in = follows the policy.
                insuranceClass: policy == null || cls == policy.insuranceClass ? '' : cls,
              ),
            );
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

/// Renewed Iqama / ID: asks the new expiry (a year after the old one offered).
Future<void> renewEmployeeIdDialog(BuildContext context, EmployeeRecord record) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final now = DateTime.now();
  final picked = await showDatePicker(
    context: context,
    initialDate: DateTime.parse(nextDocExpiry(record.idExpiry, now)),
    firstDate: DateTime(now.year - 10),
    lastDate: DateTime(now.year + 30),
    helpText: l10n.docNewExpiry,
  );
  if (picked == null) return;
  try {
    await renewEmployeeId(record, docDay(picked));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
  }
}

/// Home card for HR, the GM and the sales manager: Iqamas / IDs expired or
/// due within App settings `docRenewalDays` (30) until renewed. Hidden when
/// there are none.
class IdRenewalsCard extends ConsumerWidget {
  const IdRenewalsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider).value;
    if (me == null || !me.role.canSeeHr) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final today = DateTime.now();
    final users = {
      for (final u in ref.watch(usersProvider).value ?? const <AppUser>[])
        if (u.active) u.id: u,
    };
    final due = [
      for (final r in (ref.watch(employeeRecordsProvider).value ?? const <String, EmployeeRecord>{}).values)
        if (users.containsKey(r.uid) && r.idNeedsRenewal(today)) r,
    ]..sort((a, b) => a.idExpiry.compareTo(b.idExpiry));
    if (due.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(l10n.idRenewalsDue(due.length), style: Theme.of(context).textTheme.titleMedium),
            ),
            for (final r in due)
              ListTile(
                dense: true,
                leading: Icon(Icons.badge_outlined, color: docExpiryColor(context, docExpiryState(r.idExpiry, today))),
                title: Text('${users[r.uid]!.name} · ${idTypeLabel(l10n, r.idType)}'),
                subtitle: Text(
                  idExpiryText(context, r.idExpiry, today),
                  style: TextStyle(color: docExpiryColor(context, docExpiryState(r.idExpiry, today))),
                ),
                trailing: me.role.canManageHr
                    ? TextButton(onPressed: () => renewEmployeeIdDialog(context, r), child: Text(l10n.markRenewed))
                    : null,
                onTap: () => context.push('/hr/employee/${r.uid}'),
              ),
          ],
        ),
      ),
    );
  }
}
