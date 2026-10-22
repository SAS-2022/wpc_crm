import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../l10n/app_localizations.dart';
import '../clients/client.dart';
import '../clients/given_items.dart';
import '../clients/given_items_widgets.dart' show givenItemLabel;
import 'report_ranking.dart';
import 'report_sections.dart';
import 'routing_pace.dart';
import 'timeline_widgets.dart';

// One salesperson's report as a PDF, downloaded from Reports (one file per
// person). Same numbers as the page; Arabic names need the bundled Noto
// fonts, and the pdf package shapes Arabic only in right-to-left text.

class ReportFonts {
  const ReportFonts({required this.base, required this.bold, required this.arabic, required this.arabicBold});

  final pw.Font base;
  final pw.Font bold;
  final pw.Font arabic;
  final pw.Font arabicBold;
}

Future<ReportFonts> loadReportFonts() async {
  Future<pw.Font> font(String name) async => pw.Font.ttf(await rootBundle.load('assets/fonts/$name.ttf'));
  return ReportFonts(
    base: await font('NotoSans-Regular'),
    bold: await font('NotoSans-Bold'),
    arabic: await font('NotoSansArabic-Regular'),
    arabicBold: await font('NotoSansArabic-Bold'),
  );
}

Future<Uint8List> loadReportLogo() async => (await rootBundle.load('assets/images/Regular.png')).buffer.asUint8List();

/// Labels and lookups the PDF needs.
class ReportPdfContext {
  const ReportPdfContext({
    required this.l10n,
    required this.languageCode,
    required this.periodLabel,
    required this.teamSize,
    required this.clients,
    required this.tagLabel,
    required this.createdAt,
    this.catalog,
    this.fonts,
    this.logo,
  });

  final AppLocalizations l10n;
  final String languageCode;

  /// "October 2026" or "1 Oct – 15 Oct 2026".
  final String periodLabel;

  /// People ranked.
  final int teamSize;
  final Map<String, Client> clients;

  /// Tag id ('' = no tag) → its name.
  final String Function(String) tagLabel;
  final DateTime createdAt;

  /// Catalogs / stands the person handed over in the period.
  final CatalogRow? catalog;

  /// Null = the pdf package's built-in font (no Arabic; tests).
  final ReportFonts? fonts;
  final Uint8List? logo;
}

/// File name, e.g. "Sami Mansour - October 2026.pdf".
String reportPdfFileName(RankedPerson p, String periodLabel) =>
    '${p.report.user.name} - $periodLabel.pdf'.replaceAll(RegExp(r'[\\/:*?"<>|]'), '');

final _arabic = RegExp(r'[؀-ۿݐ-ݿﭐ-﷿ﹰ-﻿]');

const _ink = PdfColor.fromInt(0xFF1F2937);
const _muted = PdfColor.fromInt(0xFF6B7280);
const _accent = PdfColor.fromInt(0xFF1F4E79);
const _panel = PdfColor.fromInt(0xFFF1F4F8);
const _line = PdfColor.fromInt(0xFFD9DEE5);
const _good = PdfColor.fromInt(0xFF0CA30C);
const _bad = PdfColor.fromInt(0xFFC62828);
const _warn = PdfColor.fromInt(0xFFFAB219);

Future<Uint8List> buildPersonPdf(RankedPerson p, ReportPdfContext x) async {
  final l10n = x.l10n;
  final rtl = x.languageCode == 'ar';
  final f = x.fonts;
  final r = p.report;
  final day = p.averageDay;

  // Arabic is shaped only when the Arabic font is the main one (not a
  // fallback) and the text runs right to left.
  pw.TextStyle style({double size = 10, bool bold = false, PdfColor color = _ink, bool arabic = false}) {
    final (latin, ar) = f == null ? (null, null) : (bold ? f.bold : f.base, bold ? f.arabicBold : f.arabic);
    return pw.TextStyle(
      fontSize: size,
      color: color,
      font: arabic ? ar : latin,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      fontFallback: [?(arabic ? latin : ar)],
    );
  }

  pw.Widget text(String s, {double size = 10, bool bold = false, PdfColor color = _ink, pw.TextAlign? align}) {
    final arabic = _arabic.hasMatch(s);
    return pw.Text(
      s,
      style: style(size: size, bold: bold, color: color, arabic: arabic),
      // Aligned with the page, also when an Arabic name sits in an English report.
      textAlign: align ?? (rtl ? pw.TextAlign.right : pw.TextAlign.left),
      textDirection: rtl || arabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
    );
  }

  pw.Widget heading(String s, {String? hint}) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          text(s, size: 12.5, bold: true, color: _accent),
          if (hint != null) ...[pw.SizedBox(width: 8), text(hint, size: 8.5, color: _muted)],
        ]),
      );

  pw.Widget tile(String label, String value, {PdfColor color = _ink}) => pw.Container(
        width: 122,
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: const pw.BoxDecoration(color: _panel, borderRadius: pw.BorderRadius.all(pw.Radius.circular(4))),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          text(value, size: 14, bold: true, color: color),
          text(label, size: 8.5, color: _muted),
        ]),
      );

  pw.Widget tiles(List<pw.Widget> children) => pw.Wrap(spacing: 6, runSpacing: 6, children: children);

  pw.Widget table(List<String> headers, List<List<String>> rows, {Map<int, pw.TableColumnWidth>? widths}) => pw.Table(
        columnWidths: widths,
        border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _line, width: 0.5)),
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: _panel),
            children: [for (final h in headers) pw.Padding(padding: const pw.EdgeInsets.all(4), child: text(h, size: 9, bold: true))],
          ),
          for (final row in rows)
            pw.TableRow(children: [
              for (final c in row) pw.Padding(padding: const pw.EdgeInsets.all(4), child: text(c, size: 9)),
            ]),
        ],
      );

  String minutes(int m) => formatSplitMinutes(l10n, m);
  String pct(double share) => '${(share * 100).round()}%';
  String ratio(int done, int total) => total == 0 ? '–' : '$done/$total · ${pct(done / total)}';

  // Target verdict and bar.
  final share = p.targetShare;
  final (verdict, verdictColor) = share == null
      ? (l10n.mrNoTarget, _muted)
      : p.targetAchieved
          ? (l10n.mrTargetAchieved, _good)
          : (l10n.mrTargetMissed, _bad);
  final contactsText = r.calls > 0 ? '${r.visits} + ${r.calls}' : '${r.visits}';

  pw.Widget timeBar(TimeSplit split) {
    final total = split.values.fold(0, (s, n) => s + n);
    if (total == 0) return pw.SizedBox();
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      pw.ClipRRect(
        horizontalRadius: 5,
        verticalRadius: 5,
        child: pw.SizedBox(
          height: 10,
          child: pw.Row(children: [
            for (final k in TimeKind.values)
              if ((split[k] ?? 0) > 0)
                pw.Expanded(flex: split[k]!, child: pw.Container(color: PdfColor.fromInt(timeKindColor(k).toARGB32()))),
          ]),
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Wrap(spacing: 10, runSpacing: 2, children: [
        for (final k in TimeKind.values)
          if ((split[k] ?? 0) > 0)
            pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
              pw.Container(width: 7, height: 7, color: PdfColor.fromInt(timeKindColor(k).toARGB32())),
              pw.SizedBox(width: 3),
              text('${timeKindLabel(l10n, k)} ${minutes(split[k]!)} · ${pct(split[k]! / total)}', size: 8),
            ]),
      ]),
    ]);
  }

  List<String> clientRow(String id) {
    final c = x.clients[id];
    return [
      c?.name ?? id,
      c?.city ?? '',
      (c == null || c.tagIds.isEmpty ? [''] : c.tagIds).map(x.tagLabel).join(', '),
      '${p.visitsByClient[id] ?? 0}',
    ];
  }

  const clientWidths = {
    0: pw.FlexColumnWidth(4),
    1: pw.FlexColumnWidth(2),
    2: pw.FlexColumnWidth(2.5),
    3: pw.FlexColumnWidth(1),
  };
  final tags = p.byTag.entries.toList()..sort((a, b) => b.value.clients.compareTo(a.value.clients));
  final given = x.catalog?.byItem.entries.where((e) => e.value > 0).toList() ?? const <MapEntry<GivenItem, int>>[];

  final doc = pw.Document(title: '${l10n.reportPdfTitle} – ${r.user.name} – ${x.periodLabel}', author: 'WPC CRM');
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 28),
    textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
    theme: f == null ? null : pw.ThemeData.withFont(base: f.base, bold: f.bold, fontFallback: [f.arabic, f.arabicBold]),
    footer: (context) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      text(l10n.pdfCreated(DateFormat.yMMMd(x.languageCode).add_jm().format(x.createdAt)), size: 8, color: _muted),
      text(l10n.pdfPage(context.pageNumber, context.pagesCount), size: 8, color: _muted),
    ]),
    build: (context) => [
      // Header: logo, title, period.
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        if (x.logo != null) pw.Image(pw.MemoryImage(x.logo!), height: 30),
        pw.Spacer(),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          text(l10n.reportPdfTitle, size: 11, color: _muted),
          text(x.periodLabel, size: 11, bold: true),
        ]),
      ]),
      pw.Divider(color: _line),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            text(r.user.name, size: 20, bold: true),
            text(l10n.rankOfTeam(p.rank, x.teamSize), size: 11, color: _muted),
          ]),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: const pw.BoxDecoration(color: _accent, borderRadius: pw.BorderRadius.all(pw.Radius.circular(6))),
          child: pw.Column(children: [
            text(p.score.toStringAsFixed(1), size: 18, bold: true, color: PdfColors.white),
            text(l10n.mrScore, size: 8, color: PdfColors.white),
          ]),
        ),
      ]),

      heading(l10n.target),
      // Separate pieces: numbers inside Arabic text get reordered.
      pw.Row(children: [
        text(verdict, size: 12, bold: true, color: verdictColor),
        pw.SizedBox(width: 16),
        text(r.target > 0 ? '$contactsText / ${r.target.round()}' : contactsText, size: 11),
        if (share != null) ...[pw.SizedBox(width: 16), text(pct(share), size: 11, bold: true)],
      ]),
      if (share != null) ...[
        pw.SizedBox(height: 4),
        pw.ClipRRect(
          horizontalRadius: 3,
          verticalRadius: 3,
          child: pw.Row(children: [
            if (share > 0)
              pw.Expanded(
                flex: (share.clamp(0, 1) * 1000).round(),
                child: pw.Container(height: 6, color: p.targetAchieved ? _good : _warn),
              ),
            if (share < 1) pw.Expanded(flex: ((1 - share) * 1000).round(), child: pw.Container(height: 6, color: _line)),
          ]),
        ),
      ],

      heading(l10n.keyNumbers),
      tiles([
        tile(l10n.visits, '${r.visits}'),
        tile(l10n.calls, '${r.calls}'),
        tile(l10n.mrWorkDays, '${p.workDays}'),
        tile(l10n.mrVisitsPerDay, p.workDays == 0 ? '–' : (r.visits / p.workDays).toStringAsFixed(1)),
        tile(l10n.mrClientsVisited, '${p.visitsByClient.length}'),
        tile(l10n.mrFirstVisits, '${p.firstClients.length}', color: _good),
        tile(l10n.mrRevisited, '${p.revisitedClients.length}'),
        tile(l10n.mrNewClients, '${p.newClients}'),
        tile(l10n.ownClientsVisited, ratio(r.assignedVisited, r.assigned)),
        tile(l10n.onSchedule, ratio(r.onSchedule, r.assigned)),
        tile(l10n.planCompletion, ratio(r.tasksDone, r.tasksApproved)),
        tile(l10n.flaggedVisits, '${r.flagged}', color: r.flagged > 0 ? _bad : _ink),
      ]),

      heading(l10n.mrClientTypes),
      if (tags.isEmpty)
        text(l10n.mrNoVisits, color: _muted)
      else
        table(
          [l10n.mrClientType, l10n.mrClientsVisited, l10n.visits],
          [for (final MapEntry(key: t, value: n) in tags) [x.tagLabel(t), '${n.clients}', '${n.visits}']],
          widths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(1.5), 2: pw.FlexColumnWidth(1.5)},
        ),

      heading(l10n.mrAverageDay, hint: day == null ? null : l10n.mrAverageDayHint(day.days)),
      tiles([
        tile(l10n.efficiency, p.efficiency == null ? '–' : pct(p.efficiency!)),
        tile(l10n.mrTimePerClient, p.routing?.pace.visitMinutes == null ? '–' : minutes(p.routing!.pace.visitMinutes!.round())),
        if (day != null) ...[
          if (day.firstClientMin != null && day.lastClientMin != null)
            tile(l10n.mrFirstToLast, l10n.mrDayStartEnd(clockOf(day.firstClientMin!), clockOf(day.lastClientMin!))),
          tile(l10n.mrAtClientsDay, minutes(day.split[TimeKind.client] ?? 0)),
          tile(l10n.mrDrivingDay, minutes(day.split[TimeKind.driving] ?? 0)),
          tile(l10n.mrDrivingKmColumn, day.drivingKm.toStringAsFixed(0)),
        ],
      ]),
      pw.SizedBox(height: 6),
      if (day == null) text(l10n.mrNoGps, size: 9, color: _muted) else timeBar(day.split),
      if (p.efficiency != null) ...[
        pw.SizedBox(height: 4),
        text(l10n.mrEfficiencyHint(p.routing?.days.length ?? 0), size: 8, color: _muted),
      ],

      if (given.isNotEmpty) ...[
        heading(l10n.reportCatalogs),
        tiles([for (final MapEntry(key: item, value: n) in given) tile(givenItemLabel(l10n, item), '$n')]),
      ],

      heading(l10n.scoreBreakdown),
      table(
        [l10n.mrScore, ''],
        [
          for (final (part, label) in [
            (ScorePart.target, l10n.target),
            (ScorePart.efficiency, l10n.efficiency),
            (ScorePart.clients, l10n.mrClientsVisited),
            (ScorePart.newClients, l10n.mrNewClients),
            (ScorePart.firstVisits, l10n.mrFirstVisits),
          ])
            [label, '${p.scoreParts[part]!.toStringAsFixed(1)} / ${scoreWeights[part]}'],
          [l10n.reportTotal, l10n.mrPoints(p.score.toStringAsFixed(1))],
        ],
        widths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(2)},
      ),
      pw.SizedBox(height: 4),
      text(
        l10n.mrHowScored(
          scoreWeights[ScorePart.target]!,
          scoreWeights[ScorePart.efficiency]!,
          scoreWeights[ScorePart.clients]!,
          scoreWeights[ScorePart.newClients]!,
          scoreWeights[ScorePart.firstVisits]!,
        ),
        size: 8,
        color: _muted,
      ),

      for (final (title, ids) in [
        (l10n.mrFirstVisitList(p.firstClients.length), p.firstClients),
        (l10n.mrRevisitedList(p.revisitedClients.length), p.revisitedClients),
      ])
        if (ids.isNotEmpty) ...[
          heading(title),
          table([l10n.mrClient, l10n.city, l10n.mrClientType, l10n.visits], [for (final id in ids) clientRow(id)],
              widths: clientWidths),
        ],
      pw.SizedBox(height: 6),
      text(l10n.mrFirstVisitsHint, size: 8, color: _muted),
    ],
  ));
  return doc.save();
}
