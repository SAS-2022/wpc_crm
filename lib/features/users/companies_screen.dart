import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_user.dart';
import '../../core/text_input_dialog.dart';
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
    final name = await showTextInputDialog(
      context,
      title: company == null ? l10n.addCompany : l10n.renameCompany,
      initialText: company?.name ?? '',
      label: l10n.company,
      confirmLabel: l10n.save,
      maxLines: 1,
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      await saveCompany(id: company?.id, name: name, active: company?.active ?? true);
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
                    title: Text(c.name),
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
