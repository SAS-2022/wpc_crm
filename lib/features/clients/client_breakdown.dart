import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_user.dart';
import '../users/users_repository.dart';

import '../../l10n/app_localizations.dart';
import 'client.dart';
import 'client_tags.dart';
import 'clients_repository.dart';

/// How many of [clients] are of each type and carry each tag (2026-11-21,
/// user: a small legend when a salesperson is picked, web only).
class ClientBreakdownCounts {
  const ClientBreakdownCounts({
    required this.total,
    required this.companies,
    required this.individuals,
    required this.typeUnset,
    required this.tags,
    required this.untagged,
  });

  final int total;
  final int companies;
  final int individuals;

  /// Clients without a type (Odoo's "Is a Company" empty).
  final int typeUnset;

  /// Tag id → clients with that tag, most first; a client with two tags
  /// counts under both. Only ids in the tag list (deleted tags left out).
  final List<(String, int)> tags;

  /// Clients with none of the listed tags.
  final int untagged;
}

ClientBreakdownCounts clientBreakdown(Iterable<Client> clients, Set<String> tagIds) {
  var total = 0, companies = 0, individuals = 0, unset = 0, untagged = 0;
  final tags = <String, int>{};
  for (final c in clients) {
    total++;
    switch (c.clientType) {
      case clientTypeCompany:
        companies++;
      case clientTypeIndividual:
        individuals++;
      default:
        unset++;
    }
    final own = c.tagIds.where(tagIds.contains).toSet();
    if (own.isEmpty) untagged++;
    for (final t in own) {
      tags[t] = (tags[t] ?? 0) + 1;
    }
  }
  final sorted = tags.entries.map((e) => (e.key, e.value)).toList()
    ..sort((a, b) => b.$2 != a.$2 ? b.$2.compareTo(a.$2) : a.$1.compareTo(b.$1));
  return ClientBreakdownCounts(
    total: total,
    companies: companies,
    individuals: individuals,
    typeUnset: unset,
    tags: sorted,
    untagged: untagged,
  );
}

/// Legend hidden by the user (× on it; the "Types & tags" pill shows it
/// again), remembered in this browser.
final breakdownHiddenProvider = NotifierProvider<BreakdownHidden, bool>(BreakdownHidden.new);

class BreakdownHidden extends Notifier<bool> {
  static const _key = 'clientBreakdownHidden';

  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    try {
      if ((await SharedPreferences.getInstance()).getBool(_key) == true) state = true;
    } catch (_) {
      // Shown.
    }
  }

  Future<void> set(bool hidden) async {
    state = hidden;
    try {
      await (await SharedPreferences.getInstance()).setBool(_key, hidden);
    } catch (_) {
      // Kept for this session only.
    }
  }
}

/// Legend (web, 2026-11-21; always shown since the same day, user): the
/// clients shown — after the salesperson filter (everyone when none is
/// picked), search, status and the other filters — by type and by tag, with
/// counts, share and a bar. The arrow folds it; × hides it to a pill.
class ClientBreakdownLegend extends ConsumerStatefulWidget {
  const ClientBreakdownLegend({super.key, required this.clients, this.elevated = false});

  final List<Client> clients;

  /// Over the map: a card with a shadow, a fixed width and a scrolling body.
  final bool elevated;

  @override
  ConsumerState<ClientBreakdownLegend> createState() => _ClientBreakdownLegendState();
}

class _ClientBreakdownLegendState extends ConsumerState<ClientBreakdownLegend> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final tagsById = ref.watch(clientTagsByIdProvider);
    final b = clientBreakdown(widget.clients, tagsById.keys.toSet());
    if (ref.watch(breakdownHiddenProvider)) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: ActionChip(
          avatar: const Icon(Icons.pie_chart_outline, size: 16),
          label: Text(l10n.clientBreakdownShow),
          tooltip: l10n.clientBreakdownShow,
          elevation: widget.elevated ? 2 : 0,
          onPressed: () => ref.read(breakdownHiddenProvider.notifier).set(false),
        ),
      );
    }
    // Whose clients: everyone, or the people picked in the filter.
    final names = {for (final u in ref.watch(usersProvider).value ?? const <AppUser>[]) u.id: u.name};
    final picked = [
      for (final id in ref.watch(salesFilterProvider)) id == unassignedFilter ? l10n.unassigned : names[id] ?? '?',
    ]..sort();
    final who = picked.isEmpty
        ? l10n.allSalespeople
        : picked.length <= 2
        ? picked.join(', ')
        : '${picked.take(2).join(', ')} +${picked.length - 2}';

    final header = InkWell(
      onTap: () => setState(() => _open = !_open),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(children: [
          Icon(Icons.pie_chart_outline, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.clientBreakdownHeading, style: theme.textTheme.titleSmall),
              Text(l10n.clientBreakdownWho(b.total, who),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
          Icon(_open ? Icons.expand_less : Icons.expand_more, size: 20),
          const SizedBox(width: 4),
          InkResponse(
            radius: 16,
            onTap: () => ref.read(breakdownHiddenProvider.notifier).set(true),
            child: Tooltip(message: l10n.clientBreakdownHide, child: const Icon(Icons.close, size: 18)),
          ),
        ]),
      ),
    );

    final type = _Section(
      title: l10n.clientType,
      total: b.total,
      rows: [
        (l10n.clientTypeCompany, b.companies, false),
        (l10n.clientTypeIndividual, b.individuals, false),
        if (b.typeUnset > 0) (l10n.notSet, b.typeUnset, true),
      ],
    );
    final tags = _Section(
      title: l10n.tags,
      total: b.total,
      rows: [
        for (final (id, n) in b.tags) (tagsById[id]!.label(lang), n, false),
        if (b.untagged > 0) (l10n.noTag, b.untagged, true),
      ],
    );
    final body = LayoutBuilder(builder: (context, c) {
      // Side by side when there's room (the Clients list), else one under the other.
      if (c.maxWidth >= 560) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: type),
          const SizedBox(width: 24),
          Expanded(child: tags),
        ]);
      }
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        type,
        const SizedBox(height: 12),
        tags,
      ]);
    });
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        if (_open) ...[
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: b.total == 0 ? Text(l10n.noClients, style: theme.textTheme.bodySmall) : body,
            ),
          ),
        ],
      ],
    );
    if (!widget.elevated) {
      return Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 320), child: content),
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 340, maxHeight: MediaQuery.sizeOf(context).height * 0.5),
      child: Card(margin: EdgeInsets.zero, clipBehavior: Clip.antiAlias, child: content),
    );
  }
}

/// One part of the legend: a title, then a row per value with its count,
/// share of the clients shown and a bar. Rows marked muted (not set / no
/// tag) are grey.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.total, required this.rows});

  final String title;
  final int total;
  final List<(String, int, bool)> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, letterSpacing: 0.6)),
        const SizedBox(height: 6),
        for (final (label, n, muted) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: small?.copyWith(color: muted ? theme.colorScheme.onSurfaceVariant : null)),
                ),
                Text('$n',
                    style: small?.copyWith(fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
                SizedBox(
                  width: 40,
                  child: Text(
                    total == 0 ? '' : '${(n * 100 / total).round()}%',
                    textAlign: TextAlign.end,
                    style: small?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ]),
              const SizedBox(height: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : n / total,
                  minHeight: 4,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  color: muted ? theme.colorScheme.outline : theme.colorScheme.primary,
                ),
              ),
            ]),
          ),
      ],
    );
  }
}
