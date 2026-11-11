import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_user.dart';
import '../../core/short_name.dart';
import '../../l10n/app_localizations.dart';
import 'companies.dart';
import 'users_repository.dart';

/// More → Companies (sales manager / GM): the companies people pick when
/// registering. Add, rename, or hide one from the registration form.
class CompaniesScreen extends ConsumerWidget {
  const CompaniesScreen({super.key});

  Future<void> _edit(BuildContext context, {Company? company}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _CompanyDialog(company: company),
    );
    if (result == null || result.$1.trim().isEmpty) return;
    try {
      await saveCompany(id: company?.id, name: result.$1, shortName: result.$2, active: company?.active ?? true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final companies = ref.watch(companiesProvider).value ?? const <Company>[];
    final users = ref.watch(usersProvider).value ?? const <AppUser>[];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.companies)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add_business),
        label: Text(l10n.addCompany),
      ),
      body: companies.isEmpty
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(l10n.noCompanies, textAlign: TextAlign.center)))
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                for (final c in companies)
                  ListTile(
                    leading: Icon(Icons.business, color: c.active ? null : Theme.of(context).disabledColor),
                    title: Text(c.shortName.isEmpty ? c.name : '${c.name} (${c.shortName})'),
                    subtitle: Text(l10n.peopleCount(users.where((u) => u.companyId == c.id).length)),
                    onTap: () => _edit(context, company: c),
                    // Hidden companies stay on their people but aren't offered when registering.
                    trailing: Switch(
                      value: c.active,
                      onChanged: (v) => saveCompany(id: c.id, name: c.name, active: v),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Name + short name (the chip label on the maps, user 2026-11-11).
class _CompanyDialog extends StatefulWidget {
  const _CompanyDialog({this.company});

  final Company? company;

  @override
  State<_CompanyDialog> createState() => _CompanyDialogState();
}

class _CompanyDialogState extends State<_CompanyDialog> {
  late final _name = TextEditingController(text: widget.company?.name ?? '');
  late final _short = TextEditingController(text: widget.company?.shortName ?? '');

  @override
  void dispose() {
    _name.dispose();
    _short.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.company == null ? l10n.addCompany : l10n.editCompany),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l10n.company),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _short,
              maxLength: 12,
              decoration: InputDecoration(
                labelText: l10n.shortName,
                helperText: l10n.shortNameHelp(abbreviate(_name.text.trim())),
                helperMaxLines: 2,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: _name.text.trim().isEmpty ? null : () => Navigator.pop(context, (_name.text, _short.text)),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
