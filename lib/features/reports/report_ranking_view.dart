import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/save_file.dart';
import '../../core/saving.dart';
import '../../l10n/app_localizations.dart';
import '../clients/client.dart';
import '../home/stats_widgets.dart';
import 'report_pdf.dart';
import 'report_ranking.dart';
import 'report_sections_view.dart' show ReportCard;

/// Rank badge: gold, silver, bronze, then plain.
class RankBadge extends StatelessWidget {
  const RankBadge(this.rank, {super.key, this.size = 26});

  final int rank;
  final double size;

  static const _medals = [Color(0xFFD4A017), Color(0xFF9EA7AD), Color(0xFFB0703C)];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final medal = rank <= 3 ? _medals[rank - 1] : null;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: medal ?? scheme.surfaceContainerHighest,
      child: Text(
        '$rank',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: size * 0.45,
          color: medal != null ? Colors.white : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Client types (tags) each person visited: distinct clients · visits.
class ClientTypesCard extends StatelessWidget {
  const ClientTypesCard({super.key, required this.people, required this.tagLabel});

  final List<RankedPerson> people;
  final String Function(String) tagLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final shown = people.where((p) => p.byTag.isNotEmpty).toList();
    // Most visited types first; "no type" last.
    final totals = <String, int>{};
    for (final p in shown) {
      for (final MapEntry(key: t, value: n) in p.byTag.entries) {
        totals[t] = (totals[t] ?? 0) + n.clients;
      }
    }
    final tags = totals.keys.toList()
      ..sort((a, b) => a.isEmpty != b.isEmpty ? (a.isEmpty ? 1 : -1) : totals[b]!.compareTo(totals[a]!));
    return ReportCard(
      title: l10n.mrClientTypes,
      icon: Icons.category_outlined,
      trailing: Text(l10n.mrTypesHint, style: theme.textTheme.bodySmall),
      child: shown.isEmpty
          ? Text(l10n.mrNoVisits)
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 24,
                columns: [
                  DataColumn(label: Text(l10n.person)),
                  for (final t in tags) DataColumn(label: Text(tagLabel(t)), numeric: true),
                ],
                rows: [
                  for (final p in shown)
                    DataRow(cells: [
                      DataCell(Text(p.report.user.name)),
                      for (final t in tags)
                        DataCell(switch (p.byTag[t]) {
                          final n? => Text.rich(TextSpan(children: [
                              TextSpan(text: '${n.clients}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              TextSpan(text: ' · ${n.visits}'),
                            ])),
                          null => const Text('–'),
                        }),
                    ]),
                ],
              ),
            ),
    );
  }
}

/// Per person, the clients visited for the first time and those re-visited.
class FirstVisitsCard extends StatelessWidget {
  const FirstVisitsCard({super.key, required this.people, required this.clients});

  final List<RankedPerson> people;
  final Map<String, Client> clients;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final shown = people.where((p) => p.visitsByClient.isNotEmpty).toList();
    Widget list(RankedPerson p, String title, List<String> ids) => ExpansionTile(
          title: Text(title, style: theme.textTheme.bodyMedium),
          dense: true,
          enabled: ids.isNotEmpty,
          tilePadding: const EdgeInsetsDirectional.only(start: 16),
          children: [
            for (final id in ids)
              ListTile(
                dense: true,
                contentPadding: const EdgeInsetsDirectional.only(start: 32, end: 8),
                title: Text(clients[id]?.name ?? id, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: (clients[id]?.city ?? '').isEmpty ? null : Text(clients[id]!.city),
                trailing: Text(l10n.visitsCount(p.visitsByClient[id] ?? 0)),
                onTap: clients[id] == null ? null : () => context.go('/clients/$id'),
              ),
          ],
        );
    return ReportCard(
      title: l10n.mrFirstAndRevisited,
      icon: Icons.fiber_new_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (shown.isEmpty) Text(l10n.mrNoVisits),
        for (final p in shown)
          ExpansionTile(
            initiallyExpanded: shown.length == 1,
            tilePadding: EdgeInsets.zero,
            title: Text(p.report.user.name),
            subtitle: Text('${l10n.mrFirstVisits}: ${p.firstClients.length} · ${l10n.mrRevisited}: ${p.revisitedClients.length}'),
            children: [
              list(p, l10n.mrFirstVisitList(p.firstClients.length), p.firstClients),
              list(p, l10n.mrRevisitedList(p.revisitedClients.length), p.revisitedClients),
            ],
          ),
        const SizedBox(height: 8),
        Text(l10n.mrFirstVisitsHint, style: theme.textTheme.bodySmall),
      ]),
    );
  }
}

/// Lets the user tick people (unless [ask] is false), then saves one PDF per person (web: one
/// download each; phones: one share sheet with all files).
Future<void> downloadReportPdfs(
  BuildContext context, {
  required List<RankedPerson> people,
  required ReportPdfContext Function(RankedPerson, ReportFonts, Uint8List) contextFor,
  required String periodLabel,
  bool ask = true,
}) async {
  final picked = !ask
      ? people
      : await showDialog<List<RankedPerson>>(
          context: context,
          builder: (_) => _PickPeopleDialog(people: people, selected: {for (final p in people) p.report.user.id}),
        );
  if (picked == null || picked.isEmpty) return;
  // The bar at the top shows while the files are made.
  final files = await saving(() async {
    final fonts = await loadReportFonts();
    final logo = await loadReportLogo();
    return [
      for (final p in picked)
        (name: reportPdfFileName(p, periodLabel), bytes: await buildPersonPdf(p, contextFor(p, fonts, logo))),
    ];
  });
  if (kIsWeb) {
    for (final f in files) {
      saveBytes(f.bytes, f.name, 'application/pdf');
    }
  } else {
    await SharePlus.instance.share(ShareParams(
      files: [for (final f in files) XFile.fromData(f.bytes, mimeType: 'application/pdf', name: f.name)],
      fileNameOverrides: [for (final f in files) f.name],
    ));
  }
}

class _PickPeopleDialog extends StatefulWidget {
  const _PickPeopleDialog({required this.people, required this.selected});

  final List<RankedPerson> people;
  final Set<String> selected;

  @override
  State<_PickPeopleDialog> createState() => _PickPeopleDialogState();
}

class _PickPeopleDialogState extends State<_PickPeopleDialog> {
  late final _selected = {...widget.selected};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final all = _selected.length == widget.people.length;
    return AlertDialog(
      title: Text(l10n.downloadPdfs),
      content: SizedBox(
        width: 360,
        child: ListView(shrinkWrap: true, children: [
          Text(l10n.pdfChoosePeople, style: Theme.of(context).textTheme.bodySmall),
          if (widget.people.length > 1)
            CheckboxListTile(
              value: all,
              title: Text(l10n.everyone, style: const TextStyle(fontWeight: FontWeight.w600)),
              onChanged: (v) => setState(() {
                _selected.clear();
                if (v == true) _selected.addAll(widget.people.map((p) => p.report.user.id));
              }),
            ),
          for (final p in widget.people)
            CheckboxListTile(
              value: _selected.contains(p.report.user.id),
              secondary: RankBadge(p.rank),
              title: Text(p.report.user.name),
              onChanged: (v) => setState(() => v == true ? _selected.add(p.report.user.id) : _selected.remove(p.report.user.id)),
            ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(MaterialLocalizations.of(context).cancelButtonLabel)),
        FilledButton.icon(
          icon: const Icon(Icons.picture_as_pdf),
          label: Text(l10n.pdfDownloadCount(_selected.length)),
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.pop(context, [for (final p in widget.people) if (_selected.contains(p.report.user.id)) p]),
        ),
      ],
    );
  }
}

/// Target cell text: ✓ / ✗ and the share once the period is over.
Widget targetVerdict(BuildContext context, RankedPerson p) {
  final l10n = AppLocalizations.of(context);
  final share = p.targetShare;
  if (share == null) return const SizedBox.shrink();
  final ok = p.targetAchieved;
  return Tooltip(
    message: ok ? l10n.mrTargetAchieved : l10n.mrTargetMissed,
    child: Icon(ok ? Icons.check_circle : Icons.cancel, size: 16, color: ok ? statusGood : Theme.of(context).colorScheme.error),
  );
}

/// How the score is made; with [person], their points per part too.
Future<void> showScoreInfo(BuildContext context, {RankedPerson? person}) {
  final l10n = AppLocalizations.of(context);
  final theme = Theme.of(context);
  final parts = [
    (ScorePart.target, l10n.target, l10n.scorePartTargetHow),
    (ScorePart.efficiency, l10n.efficiency, l10n.scorePartEfficiencyHow),
    (ScorePart.clients, l10n.mrClientsVisited, l10n.scorePartClientsHow),
    (ScorePart.newClients, l10n.mrNewClients, l10n.scorePartNewHow),
    (ScorePart.firstVisits, l10n.mrFirstVisits, l10n.scorePartFirstHow),
  ];
  Widget cell(String text, {bool bold = false, TextAlign? align}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Text(text, textAlign: align, style: bold ? const TextStyle(fontWeight: FontWeight.w600) : null),
      );
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.scoreInfoTitle),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            if (person != null) ...[
              Row(children: [
                RankBadge(person.rank),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.scoreFor(person.report.user.name, person.score.toStringAsFixed(1)),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ]),
              const SizedBox(height: 12),
            ],
            Text(l10n.scoreInfoIntro),
            const SizedBox(height: 12),
            Table(
              columnWidths: {
                0: const IntrinsicColumnWidth(),
                1: const IntrinsicColumnWidth(),
                2: const FlexColumnWidth(),
                if (person != null) 3: const IntrinsicColumnWidth(),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              border: TableBorder(horizontalInside: BorderSide(color: theme.dividerColor)),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)),
                  children: [
                    cell(l10n.scoreInfoPart, bold: true),
                    cell(l10n.scoreInfoMax, bold: true, align: TextAlign.center),
                    cell(l10n.scoreInfoHow, bold: true),
                    if (person != null) cell(l10n.scoreInfoPoints, bold: true, align: TextAlign.center),
                  ],
                ),
                for (final (part, label, how) in parts)
                  TableRow(children: [
                    cell(label, bold: true),
                    cell('${scoreWeights[part]}', align: TextAlign.center),
                    cell(how),
                    if (person != null) cell(person.scoreParts[part]!.toStringAsFixed(1), bold: true, align: TextAlign.center),
                  ]),
              ],
            ),
            const SizedBox(height: 12),
            Text(l10n.scoreInfoExample, style: theme.textTheme.bodySmall),
          ]),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(MaterialLocalizations.of(context).closeButtonLabel))],
    ),
  );
}
