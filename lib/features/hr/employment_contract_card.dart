import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../core/saving.dart';
import '../../l10n/app_localizations.dart';
import '../attachments/attachments.dart';
import '../attachments/attachments_section.dart';
import '../clients/document_text.dart';
import 'contract_pay.dart';
import 'employee_record.dart';
import 'employee_records_repository.dart';
import 'hr_actions.dart' show formatAmount;
import 'payroll.dart';
import 'payroll_repository.dart';

// Employment contract (user request 2026-11-13): HR and the payroll account
// upload an employee's contract on their HR page. Its text is read on the
// device, the salary parts found are shown for review, and the ticked ones
// update `payroll/{uid}`. The file goes to Storage
// `employee_contracts/{uid}/…`, its details to `employee_records/{uid}.contract`.

/// Employee HR page: the contract file, with Upload / Replace / Open. No
/// Delete: the amounts taken from it stay locked, so a wrong contract is
/// corrected by uploading the right one (user decision 2026-11-13).
class EmploymentContractCard extends ConsumerWidget {
  const EmploymentContractCard({super.key, required this.user, this.margin});

  final AppUser user;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider).value;
    if (!canUploadContract(me, user.id)) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final records = ref.watch(employeeRecordsProvider);
    final contract = records.value?[user.id]?.contract;
    return Card(
      margin: margin,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Text(l10n.employmentContract, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
            ),
            TextButton.icon(
              onPressed: records.hasValue ? () => uploadEmploymentContract(context, ref, user, contract) : null,
              icon: const Icon(Icons.upload_file_outlined, size: 18),
              label: Text(contract == null ? l10n.contractUpload : l10n.contractReplace),
            ),
          ]),
          if (contract == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(l10n.contractNone, style: theme.textTheme.bodyMedium),
            )
          else
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(contract.contentType == 'application/pdf' ? Icons.picture_as_pdf_outlined : Icons.description_outlined),
              title: Text(contract.fileName),
              subtitle: contract.uploadedAt == null
                  ? null
                  : Text(l10n.contractUploadedOn(DateFormat.yMMMd(locale).format(contract.uploadedAt!))),
              onTap: () => _open(contract),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  tooltip: l10n.contractOpen,
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => _open(contract),
                ),
              ]),
            ),
          Text(l10n.contractCardHint, style: theme.textTheme.bodySmall),
        ]),
      ),
    );
  }

  /// Opened through a fresh download URL (none is stored, so only those the
  /// Storage rules let in can get one).
  static Future<void> _open(EmploymentContract c) async {
    final url = await FirebaseStorage.instance.ref(c.storagePath).getDownloadURL();
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

}

/// Picks [user]'s contract, reads it, lets the uploader check the amounts,
/// then saves the file and the ticked amounts.
Future<void> uploadEmploymentContract(BuildContext context, WidgetRef ref, AppUser user, EmploymentContract? previous) async {
  final me = ref.read(currentUserProvider).value;
  if (!canUploadContract(me, user.id)) return;
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final files = await pickAttachments(context);
  if (files.isEmpty || !context.mounted) return;
  final file = files.first;

  // Contracts run to several pages; the salary is rarely on the first.
  messenger.showSnackBar(SnackBar(content: Text(l10n.contractReading), duration: const Duration(seconds: 30)));
  final text = await tryReadDocumentText(file, pages: 15, scannedPages: 4);
  messenger.hideCurrentSnackBar();
  if (!context.mounted) return;
  final pay = text == null ? const ContractPay() : parseContractText(text);
  // Only the payroll account may read the current salary.
  final current = canSeePayroll(me) ? (ref.read(salariesProvider).value ?? const {})[user.id] : null;

  final update = await showDialog<SalaryUpdate>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ContractReviewDialog(
      name: user.name,
      fileName: file.name,
      pay: pay,
      unreadable: text == null,
      current: current,
    ),
  );
  if (update == null) return;
  await saving(() async {
    final path = await _uploadFile(user.id, file);
    await FirebaseFirestore.instance.collection('employee_records').doc(user.id).set({
      'uid': user.id,
      'contract': {
        'storagePath': path,
        'fileName': file.name,
        'contentType': file.contentType,
        'size': file.bytes.length,
        'uploadedBy': me!.id,
        'uploadedAt': FieldValue.serverTimestamp(),
      },
      // Older contracts stay in Storage, listed here.
      if (previous != null) 'contractHistory': FieldValue.arrayUnion([previous.toMap()]),
      'updatedBy': me.id,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (!update.isEmpty) {
      await ref.read(payrollRepositoryProvider).applyContract(
            user.id,
            update,
            me.id,
            path,
            gross: canSeePayroll(me) ? update.applyTo(current ?? SalaryStructure.empty).monthly : null,
          );
    }
  });
  messenger.showSnackBar(SnackBar(content: Text(update.isEmpty ? l10n.contractSavedFileOnly : l10n.contractSaved)));
}

Future<String> _uploadFile(String uid, PendingFile file) async {
  final safeName = file.name.replaceAll(RegExp(r'[^\w.\-]+'), '_');
  final path = 'employee_contracts/$uid/${DateTime.now().millisecondsSinceEpoch}_$safeName';
  await FirebaseStorage.instance
      .ref(path)
      .putData(file.bytes, SettableMetadata(contentType: file.contentType, cacheControl: 'private, max-age=0'));
  return path;
}

/// One line of the review: ticked = written to the salary.
class _Line {
  _Line(this.name, ContractAmount? found, {this.note = ContractNote.none})
      : amount = TextEditingController(text: found == null ? '' : formatAmount(found.amount)),
        selected = found != null;

  _Line.other(this.name, ContractAmount found)
      : amount = TextEditingController(text: formatAmount(found.amount)),
        note = found.note,
        selected = true;

  final TextEditingController amount;
  final ContractNote note;
  String name;
  bool selected;

  double? get value => double.tryParse(amount.text.trim().replaceAll(',', ''));
}

class _ContractReviewDialog extends StatefulWidget {
  const _ContractReviewDialog({
    required this.name,
    required this.fileName,
    required this.pay,
    required this.unreadable,
    required this.current,
  });

  final String name;
  final String fileName;
  final ContractPay pay;
  final bool unreadable;

  /// The salary now — only for the payroll account (HR can't read it).
  final SalaryStructure? current;

  @override
  State<_ContractReviewDialog> createState() => _ContractReviewDialogState();
}

class _ContractReviewDialogState extends State<_ContractReviewDialog> {
  late final _basic = _Line('', widget.pay.basic, note: widget.pay.basic?.note ?? ContractNote.none);
  late final _housing = _Line('', widget.pay.housing, note: widget.pay.housing?.note ?? ContractNote.none);
  late final _transport = _Line('', widget.pay.transport, note: widget.pay.transport?.note ?? ContractNote.none);
  late final List<_Line> _others = [for (final o in widget.pay.others) _Line.other(o.name, o.amount)];
  final List<TextEditingController> _names = [];

  @override
  void initState() {
    super.initState();
    for (final o in _others) {
      _names.add(TextEditingController(text: o.name));
    }
  }

  @override
  void dispose() {
    for (final l in [_basic, _housing, _transport, ..._others]) {
      l.amount.dispose();
    }
    for (final n in _names) {
      n.dispose();
    }
    super.dispose();
  }

  SalaryUpdate get _value {
    double? v(_Line l) => l.selected ? l.value : null;
    final others = [
      for (final (i, o) in _others.indexed)
        if (o.selected && (o.value ?? 0) != 0 && _names[i].text.trim().isNotEmpty)
          OtherAllowance(name: _names[i].text.trim(), amount: o.value!),
    ];
    return SalaryUpdate(
      basic: v(_basic),
      housing: v(_housing),
      transport: v(_transport),
      others: others.isEmpty ? null : others,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final money = NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: 2);
    const numbers = TextInputType.numberWithOptions(decimal: true);
    final cur = widget.current;

    String? noteText(ContractNote n) => switch (n) {
          ContractNote.none => null,
          ContractNote.yearly => l10n.contractYearly,
          ContractNote.percentOfBasic => l10n.contractPercent,
        };

    Widget row(_Line line, Widget label, {double? now, VoidCallback? onRemove}) {
      final note = noteText(line.note);
      final helper = [?note, if (now != null) l10n.contractNow(money.format(now))].join(' · ');
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Checkbox(value: line.selected, onChanged: (v) => setState(() => line.selected = v ?? false)),
          Expanded(flex: 3, child: Padding(padding: const EdgeInsets.only(top: 4), child: label)),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: line.amount,
              keyboardType: numbers,
              decoration: InputDecoration(
                isDense: true,
                suffixText: l10n.sar,
                helperText: helper.isEmpty ? null : helper,
                helperMaxLines: 2,
              ),
              onChanged: (_) => setState(() => line.selected = line.value != null),
            ),
          ),
          if (onRemove != null) IconButton(icon: const Icon(Icons.close), tooltip: l10n.delete, onPressed: onRemove),
        ]),
      );
    }

    final pay = widget.pay;
    return AlertDialog(
      title: Text(l10n.contractReviewTitle(widget.name)),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Icon(Icons.description_outlined, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(widget.fileName, style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 8),
            if (widget.unreadable || pay.isEmpty)
              _Notice(text: widget.unreadable ? l10n.contractUnreadable : l10n.contractNothingFound)
            else
              Text(l10n.contractReviewHint, style: theme.textTheme.bodySmall),
            if (pay.totalMismatch)
              _Notice(text: l10n.contractTotalMismatch(money.format(pay.total), money.format(pay.partsTotal))),
            const SizedBox(height: 8),
            row(_basic, Text(l10n.salaryBasic), now: cur?.basic),
            row(_housing, Text(l10n.salaryHousing), now: cur?.housing),
            row(_transport, Text(l10n.salaryTransport), now: cur?.transport),
            Text(l10n.salaryOther, style: theme.textTheme.titleSmall),
            Text(l10n.contractOthersReplace, style: theme.textTheme.bodySmall),
            if (cur != null && cur.others.isNotEmpty)
              Text(
                l10n.contractNow([for (final o in cur.others) '${o.name} ${money.format(o.amount)}'].join(', ')),
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            for (final (i, o) in _others.indexed)
              row(
                o,
                TextField(
                  controller: _names[i],
                  decoration: InputDecoration(isDense: true, labelText: l10n.allowanceName),
                ),
                onRemove: () => setState(() {
                  final line = _others.removeAt(i);
                  final name = _names.removeAt(i);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    line.amount.dispose();
                    name.dispose();
                  });
                }),
              ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => setState(() {
                  _others.add(_Line.other('', const ContractAmount(0))..amount.text = '');
                  _names.add(TextEditingController());
                }),
                icon: const Icon(Icons.add),
                label: Text(l10n.contractAddOther),
              ),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, _value), child: Text(l10n.save)),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
    );
  }
}
