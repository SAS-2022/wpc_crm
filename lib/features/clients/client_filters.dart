import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../users/users_repository.dart';
import 'client.dart';
import 'client_tags.dart';
import 'client_widgets.dart';
import 'clients_repository.dart';
import 'given_items.dart';
import 'given_items_widgets.dart';
import 'client_status.dart';
import 'client_status_widgets.dart';

/// Number of active filters (salesperson, type, each tag).
int _activeCount(WidgetRef ref) =>
    ref.watch(salesFilterProvider).length +
    (ref.watch(clientTypeFilterProvider) == null ? 0 : 1) +
    ref.watch(tagFilterProvider).length +
    ref.watch(givenDueFilterProvider).length +
    (isDefaultStatusFilter(ref.watch(clientStatusFilterProvider)) ? 0 : 1);

void _clearAll(WidgetRef ref) {
  ref.read(salesFilterProvider.notifier).clear();
  ref.read(clientTypeFilterProvider.notifier).set(null);
  ref.read(tagFilterProvider.notifier).clear();
  ref.read(givenDueFilterProvider.notifier).clear();
  ref.read(clientStatusFilterProvider.notifier).reset();
}

String _typeLabel(AppLocalizations l10n, String type) =>
    type == clientTypeCompany ? l10n.clientTypeCompany : l10n.clientTypeIndividual;

/// "Filters" button with the number of active filters; opens the filter
/// sheet shared by the client list and map.
class ClientFiltersButton extends ConsumerWidget {
  const ClientFiltersButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final n = _activeCount(ref);
    return OutlinedButton.icon(
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        // Opens over the map on the web too.
        builder: (_) => PointerInterceptor(child: const _FiltersSheet()),
      ),
      icon: Badge(isLabelVisible: n > 0, label: Text('$n'), child: const Icon(Icons.tune)),
      label: Text(l10n.filters),
    );
  }
}

class _FiltersSheet extends ConsumerWidget {
  const _FiltersSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final supervisor = ref.watch(currentUserProvider).value?.role.isSupervisor ?? false;
    final type = ref.watch(clientTypeFilterProvider);
    final tagFilter = ref.watch(tagFilterProvider);
    final tags = ref.watch(clientTagsProvider).value ?? defaultClientTags;
    final lang = Localizations.localeOf(context).languageCode;

    Widget heading(String text) => Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: Text(l10n.filters, style: theme.textTheme.titleLarge)),
              TextButton(onPressed: _activeCount(ref) == 0 ? null : () => _clearAll(ref), child: Text(l10n.clearFilters)),
            ],
          ),
          if (supervisor) ...[
            heading(l10n.salesperson),
            const SalesFilterChips(),
          ],
          heading(l10n.clientStatus),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in ClientStatus.values)
                FilterChip(
                  avatar: Icon(clientStatusIcon(s), size: 18),
                  label: Text(clientStatusLabel(l10n, s)),
                  selected: ref.watch(clientStatusFilterProvider).contains(s),
                  onSelected: (_) => ref.read(clientStatusFilterProvider.notifier).toggle(s),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(l10n.clientStatusFilterHelp, style: theme.textTheme.bodySmall),
          ),
          heading(l10n.clientType),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (value, label) in [
                (null, l10n.statusAll),
                (clientTypeCompany, l10n.clientTypeCompany),
                (clientTypeIndividual, l10n.clientTypeIndividual),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: type == value,
                  onSelected: (_) => ref.read(clientTypeFilterProvider.notifier).set(value),
                ),
            ],
          ),
          heading(l10n.clientTags),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in tags)
                FilterChip(
                  label: Text(t.label(lang)),
                  selected: tagFilter.contains(t.id),
                  onSelected: (_) => ref.read(tagFilterProvider.notifier).toggle(t.id),
                ),
            ],
          ),
          if (tagFilter.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(l10n.tagFilterAny, style: theme.textTheme.bodySmall),
            ),
          heading(l10n.givenDueFilter),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in GivenItem.values)
                FilterChip(
                  avatar: Icon(givenItemIcon(item), size: 18),
                  label: Text(givenItemLabel(l10n, item)),
                  selected: ref.watch(givenDueFilterProvider).contains(item),
                  onSelected: (_) => ref.read(givenDueFilterProvider.notifier).toggle(item),
                ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: () => Navigator.pop(context), child: Text(l10n.done)),
        ],
      ),
    );
  }
}

/// The active filters as chips; ✕ removes one. Nothing when none is active.
class ActiveClientFilters extends ConsumerWidget {
  const ActiveClientFilters({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sales = ref.watch(salesFilterProvider);
    final type = ref.watch(clientTypeFilterProvider);
    final tagFilter = ref.watch(tagFilterProvider);
    final due = ref.watch(givenDueFilterProvider);
    final statuses = ref.watch(clientStatusFilterProvider);
    final defaultStatuses = isDefaultStatusFilter(statuses);
    if (sales.isEmpty && type == null && tagFilter.isEmpty && due.isEmpty && defaultStatuses) {
      return const SizedBox.shrink();
    }
    final users = {for (final u in ref.watch(usersProvider).value ?? const []) u.id: u};
    final tags = ref.watch(clientTagsByIdProvider);
    final lang = Localizations.localeOf(context).languageCode;

    Widget chip(IconData icon, String label, VoidCallback onDeleted) => Padding(
          padding: const EdgeInsetsDirectional.only(end: 6),
          child: InputChip(
            visualDensity: compact ? VisualDensity.compact : null,
            avatar: Icon(icon, size: 16),
            label: Text(label),
            onDeleted: onDeleted,
          ),
        );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final id in sales)
            chip(Icons.person, id == unassignedFilter ? l10n.unassigned : users[id]?.name ?? '?',
                () => ref.read(salesFilterProvider.notifier).toggle(id)),
          if (type != null)
            chip(type == clientTypeCompany ? Icons.business : Icons.person_outline, _typeLabel(l10n, type),
                () => ref.read(clientTypeFilterProvider.notifier).set(null)),
          for (final id in tagFilter)
            chip(Icons.sell_outlined, tags[id]?.label(lang) ?? '?', () => ref.read(tagFilterProvider.notifier).toggle(id)),
          if (!defaultStatuses)
            chip(Icons.store_mall_directory_outlined,
                [for (final s in ClientStatus.values) if (statuses.contains(s)) clientStatusLabel(l10n, s)].join(', '),
                () => ref.read(clientStatusFilterProvider.notifier).reset()),
          for (final item in due)
            chip(givenItemIcon(item), '${givenItemLabel(l10n, item)} · ${l10n.givenDue}',
                () => ref.read(givenDueFilterProvider.notifier).toggle(item)),
          TextButton(onPressed: () => _clearAll(ref), child: Text(l10n.clearFilters)),
        ],
      ),
    );
  }
}
