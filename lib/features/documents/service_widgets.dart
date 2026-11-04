import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_user.dart';
import '../../l10n/app_localizations.dart';
import '../hr/employee_record.dart';
import '../hr/employee_records_repository.dart';
import '../users/users_repository.dart';
import 'company_docs.dart';
import 'company_docs_repository.dart';

// Services and subscriptions (2026-11-03): a subscription's login details
// on its page, and the employees a health insurance service covers.

void _copy(BuildContext context, String text) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).copied)));
}

/// Login URL (opens it), how to log in, user name and password (hidden
/// until shown), each with a copy button. Rows without a value are left out.
class SubscriptionLoginTiles extends StatefulWidget {
  const SubscriptionLoginTiles({super.key, required this.doc});

  final CompanyDoc doc;

  @override
  State<SubscriptionLoginTiles> createState() => _SubscriptionLoginTilesState();
}

class _SubscriptionLoginTilesState extends State<SubscriptionLoginTiles> {
  bool _show = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final d = widget.doc;
    Widget copy(String text) => IconButton(icon: const Icon(Icons.copy), tooltip: l10n.copy, onPressed: () => _copy(context, text));
    final url = d.loginUrl.contains('://') ? d.loginUrl : 'https://${d.loginUrl}';
    return Column(
      children: [
        if (d.loginUrl.isNotEmpty)
          ListTile(
            leading: const Icon(Icons.link),
            title: Text(l10n.docLoginUrl),
            subtitle: Text(d.loginUrl, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            trailing: copy(d.loginUrl),
            onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          ),
        if (d.loginSteps.isNotEmpty)
          ListTile(leading: const Icon(Icons.format_list_numbered), title: Text(l10n.docLoginSteps), subtitle: Text(d.loginSteps)),
        if (d.username.isNotEmpty)
          ListTile(leading: const Icon(Icons.person_outline), title: Text(l10n.docUsername), subtitle: Text(d.username), trailing: copy(d.username)),
        if (d.password.isNotEmpty)
          ListTile(
            leading: const Icon(Icons.password),
            title: Text(l10n.docPassword),
            subtitle: Text(_show ? d.password : '••••••••'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  tooltip: _show ? l10n.hidePassword : l10n.showPassword,
                  onPressed: () => setState(() => _show = !_show),
                ),
                copy(d.password),
              ],
            ),
          ),
      ],
    );
  }
}

/// The employees [policy] covers (every active employee on the company's
/// usual policy, unless their record names another one or none) with their
/// class; editors tap a person to change their class.
class InsuredEmployeesCard extends ConsumerWidget {
  const InsuredEmployeesCard({super.key, required this.policy, required this.editable});

  final CompanyDoc policy;
  final bool editable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final policies = healthInsurances(ref.watch(companyDocsProvider).value ?? const <CompanyDoc>[]);
    final records = ref.watch(employeeRecordsProvider).value ?? const <String, EmployeeRecord>{};
    final people = [
      for (final u in ref.watch(usersProvider).value ?? const <AppUser>[])
        if (u.active && u.role != UserRole.unknown)
          if (insuranceOf(records[u.id], policies) case final ins? when ins.policy.id == policy.id) (user: u, ins: ins),
    ]..sort((a, b) => a.user.name.toLowerCase().compareTo(b.user.name.toLowerCase()));
    final byClass = <String, int>{};
    for (final p in people) {
      byClass.update(p.ins.insuranceClass, (n) => n + 1, ifAbsent: () => 1);
    }
    final classes = {
      if (policy.insuranceClass.isNotEmpty) policy.insuranceClass,
      for (final r in records.values) if (r.insuranceClass.isNotEmpty) r.insuranceClass,
    }.toList()
      ..sort();
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(l10n.docInsuredEmployees(people.length),
                style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
          ),
          if (byClass.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final e in byClass.entries)
                    Chip(visualDensity: VisualDensity.compact, label: Text('${e.key.isEmpty ? '—' : l10n.docClassValue(e.key)}: ${e.value}')),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(editable ? l10n.docInsuredHintEdit : l10n.docInsuredHint, style: theme.textTheme.bodySmall),
          ),
          for (final p in people)
            ListTile(
              dense: true,
              title: Text(p.user.name),
              subtitle: Text(p.user.role.label(l10n)),
              trailing: Text(
                p.ins.insuranceClass.isEmpty ? '—' : p.ins.insuranceClass,
                style: p.ins.ownClass ? const TextStyle(fontWeight: FontWeight.bold) : null,
              ),
              onTap: editable
                  ? () => editInsuranceClass(context, uid: p.user.id, name: p.user.name, current: p.ins.ownClass ? p.ins.insuranceClass : '',
                      usual: policy.insuranceClass, classes: classes)
                  : () => context.push('/hr/employee/${p.user.id}'),
            ),
        ],
      ),
    );
  }
}

/// Asks [name]'s class ('' = the policy's usual one) and saves it.
Future<void> editInsuranceClass(
  BuildContext context, {
  required String uid,
  required String name,
  required String current,
  required String usual,
  required List<String> classes,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final text = TextEditingController(text: current);
  final result = await showDialog<String>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (dialog, setDialog) => AlertDialog(
        title: Text(l10n.docClassOf(name)),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (classes.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in classes)
                      ChoiceChip(
                        label: Text(c),
                        selected: text.text.trim() == c,
                        onSelected: (_) => setDialog(() => text.text = c),
                      ),
                  ],
                ),
              const SizedBox(height: 8),
              TextField(
                controller: text,
                decoration: InputDecoration(labelText: l10n.docInsuranceClass, helperText: l10n.docClassEmptyHint(usual.isEmpty ? '—' : usual)),
                onChanged: (_) => setDialog(() {}),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialog, text.text.trim()), child: Text(l10n.save)),
        ],
      ),
    ),
  );
  text.dispose();
  if (result == null) return;
  try {
    // The usual class typed in = no own class (follows the policy).
    await setInsuranceClass(uid, result == usual ? '' : result);
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
  }
}
