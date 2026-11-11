import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../core/city_areas.dart';
import '../../core/providers.dart';
import '../../core/short_name.dart';
import '../../l10n/app_localizations.dart';
import '../attendance/work_sites.dart';
import '../clients/client.dart';
import '../clients/clients_repository.dart';
import 'companies.dart';

// One filter card for the people maps (user 2026-11-11): Employee Map, Route
// history and Live tracking share regions (Eastern / Central / Western) across
// the width, and under an arrow the companies and the work sites. Picking a
// company narrows the sites row to that company's sites (`work_sites.companyId`).
// Each page decides itself who is "in" a region or "at" a site.

/// Chip labels: the short name typed on the company / site (user 2026-11-11:
/// "I want to be able to edit this"), else [abbreviate]d; an automatic one
/// that clashes (with another or a typed one) keeps the full name.
Map<String, String> chipLabels(Map<String, String> names, Map<String, String> custom) {
  final typed = {
    for (final e in custom.entries)
      if (names.containsKey(e.key) && e.value.trim().isNotEmpty) e.key: e.value.trim(),
  };
  final auto = shortLabels({
    for (final e in names.entries)
      if (!typed.containsKey(e.key)) e.key: e.value,
  });
  final taken = {for (final t in typed.values) t.toUpperCase()};
  return {
    for (final id in names.keys)
      id: typed[id] ?? (taken.contains((auto[id] ?? '').toUpperCase()) ? names[id]!.trim() : auto[id] ?? names[id]!),
  };
}

Map<String, String> companyChipLabels(List<Company> companies) =>
    chipLabels({for (final c in companies) c.id: c.name}, {for (final c in companies) c.id: c.shortName});

Map<String, String> siteChipLabels(List<WorkSite> sites) =>
    chipLabels({for (final s in sites) s.id: s.name}, {for (final s in sites) s.id: s.shortName});

/// The sites of [companyId] (null = every site).
List<WorkSite> sitesOfCompany(List<WorkSite> sites, String? companyId) =>
    companyId == null ? sites : [for (final s in sites) if (s.companyId == companyId) s];

/// The region most of each salesperson's (non-hidden, located) clients are
/// in — their territory, used when there's no position (off duty, no site).
/// Only supervisors read every client; others get an empty map.
final territoryRegionsProvider = Provider<Map<String, SaudiRegion>>((ref) {
  final me = ref.watch(currentUserProvider).value;
  if (me == null || !me.role.isSupervisor) return const {};
  final counts = <String, Map<SaudiRegion, int>>{};
  for (final c in ref.watch(allClientsProvider).value ?? const <Client>[]) {
    final owner = c.assignedTo;
    if (owner == null || owner.isEmpty || c.hidden || c.lat == null || c.lng == null) continue;
    final r = SaudiRegion.of(c.lat!, c.lng!);
    if (r == null) continue;
    final m = counts[owner] ??= {};
    m[r] = (m[r] ?? 0) + 1;
  }
  return {
    for (final e in counts.entries) e.key: (e.value.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key,
  };
});

/// Whether a person is in [region]: by their position when there is one,
/// else by an assigned work site inside it, else by their clients' region.
bool personInRegion(
  SaudiRegion? region, {
  double? lat,
  double? lng,
  required List<String> siteIds,
  required List<WorkSite> sites,
  SaudiRegion? territory,
}) {
  if (region == null) return true;
  if (lat != null && lng != null) return region.contains(lat, lng);
  final own = [for (final s in sites) if (siteIds.contains(s.id)) s];
  if (own.isNotEmpty) return own.any((s) => region.contains(s.lat, s.lng));
  return territory == region;
}

/// Regions across the width; the arrow opens a companies row and a sites row.
/// [companies] / [sites] are the ones to offer (already narrowed by the
/// region and the company); [hasCompanies] false hides the companies row.
class PeopleFilterCard extends StatefulWidget {
  const PeopleFilterCard({
    super.key,
    required this.region,
    required this.onRegion,
    required this.companies,
    required this.companyId,
    required this.onCompany,
    required this.sites,
    required this.siteId,
    required this.onSite,
    this.hasCompanies = true,
    this.maxWidth = 720,
  });

  final SaudiRegion? region;
  final ValueChanged<SaudiRegion?> onRegion;
  final List<Company> companies;
  final String? companyId;
  final ValueChanged<String?> onCompany;
  final List<WorkSite> sites;
  final String? siteId;
  final ValueChanged<WorkSite?> onSite;
  final bool hasCompanies;
  final double maxWidth;

  @override
  State<PeopleFilterCard> createState() => _PeopleFilterCardState();
}

class _PeopleFilterCardState extends State<PeopleFilterCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final showCompanies = widget.hasCompanies && widget.companies.isNotEmpty;
    final companyShort = companyChipLabels(widget.companies);
    final siteShort = siteChipLabels(widget.sites);
    final site = widget.sites.where((s) => s.id == widget.siteId).firstOrNull;

    Widget choice(String label, bool selected, VoidCallback onTap, [String? full]) {
      final chip = ChoiceChip(
        visualDensity: VisualDensity.compact,
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
      );
      return full == null || full == label ? chip : Tooltip(message: full, child: chip);
    }

    Widget chipRow(IconData icon, List<Widget> chips) => Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.outline),
        const SizedBox(width: 6),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [for (final c in chips) Padding(padding: const EdgeInsetsDirectional.only(end: 6), child: c)],
            ),
          ),
        ),
      ],
    );

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.maxWidth),
        child: PointerInterceptor(
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 2, 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: RegionChips(fill: true, selected: widget.region, onSelected: widget.onRegion)),
                      if (showCompanies || widget.sites.isNotEmpty)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: _open ? l10n.showLessFilters : l10n.showMoreFilters,
                          icon: Badge(
                            // Something picked while the rows are hidden.
                            isLabelVisible: !_open && (widget.companyId != null || site != null),
                            smallSize: 8,
                            child: Icon(_open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                          ),
                          onPressed: () => setState(() => _open = !_open),
                        )
                      else
                        const SizedBox(width: 8),
                    ],
                  ),
                  if (_open && showCompanies) ...[
                    const Divider(height: 10),
                    chipRow(Icons.business, [
                      choice(l10n.allCompanies, widget.companyId == null, () => widget.onCompany(null)),
                      for (final c in widget.companies)
                        choice(
                          companyShort[c.id] ?? c.name,
                          widget.companyId == c.id,
                          () => widget.onCompany(widget.companyId == c.id ? null : c.id),
                          c.name,
                        ),
                    ]),
                  ],
                  if (_open && widget.sites.isNotEmpty) ...[
                    const Divider(height: 10),
                    chipRow(Icons.place_outlined, [
                      choice(l10n.allSites, site == null, () => widget.onSite(null)),
                      for (final s in widget.sites)
                        choice(
                          siteShort[s.id] ?? s.name,
                          site?.id == s.id,
                          () => widget.onSite(site?.id == s.id ? null : s),
                          s.name,
                        ),
                    ]),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
