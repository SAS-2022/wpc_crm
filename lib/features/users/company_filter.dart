import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'companies.dart';

/// "All companies" / one company, as a small menu button (live map, phone
/// status page; user request 2026-11-01). Hidden when there is at most one
/// company.
class CompanyFilterButton extends ConsumerWidget {
  const CompanyFilterButton({super.key, required this.value, required this.onChanged});

  /// Company id; null = all.
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final companies = ref.watch(companiesProvider).value ?? const <Company>[];
    if (companies.length < 2) return const SizedBox.shrink();
    final name = companies.where((c) => c.id == value).firstOrNull?.name;
    return PopupMenuButton<String>(
      tooltip: l10n.company,
      // Root navigator: inside the tab pager a menu scrolled it to another tab.
      useRootNavigator: true,
      onSelected: (id) => onChanged(id.isEmpty ? null : id),
      itemBuilder: (_) => [
        CheckedPopupMenuItem(value: '', checked: value == null, child: Text(l10n.allCompanies)),
        for (final c in companies)
          CheckedPopupMenuItem(value: c.id, checked: value == c.id, child: Text(c.name)),
      ],
      child: Chip(
        visualDensity: VisualDensity.compact,
        avatar: const Icon(Icons.business, size: 16),
        backgroundColor: value == null ? null : Theme.of(context).colorScheme.secondaryContainer,
        label: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(name ?? l10n.allCompanies),
          const Icon(Icons.arrow_drop_down, size: 18),
        ]),
      ),
    );
  }
}

/// The company picked on the live map, Phone status and the clients map's
/// people pins — one choice shared by the three (user 2026-11-02: opening the
/// map from Phone status keeps the filter). Null = all companies.
final peopleCompanyProvider = NotifierProvider<PeopleCompany, String?>(PeopleCompany.new);

class PeopleCompany extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? id) => state = id;
}
