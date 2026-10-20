import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'client_search.dart';

/// Yellow behind the matching letters, dark text so it reads in dark mode too.
const searchHighlight = TextStyle(backgroundColor: Color(0xFFFFEB3B), color: Colors.black);

/// [text] as spans with [ranges] highlighted.
List<TextSpan> highlightSpans(String text, List<(int, int)> ranges, {TextStyle? style}) {
  final spans = <TextSpan>[];
  var at = 0;
  for (final (start, end) in ranges) {
    if (start < at || end > text.length) continue;
    if (start > at) spans.add(TextSpan(text: text.substring(at, start), style: style));
    spans.add(TextSpan(text: text.substring(start, end), style: (style ?? const TextStyle()).merge(searchHighlight)));
    at = end;
  }
  if (at < text.length) spans.add(TextSpan(text: text.substring(at), style: style));
  return spans;
}

/// A name (or any text) with the search match highlighted.
class HighlightedText extends StatelessWidget {
  const HighlightedText(this.text, this.ranges, {super.key, this.style, this.maxLines = 1});

  final String text;
  final List<(int, int)> ranges;
  final TextStyle? style;
  final int maxLines;

  @override
  Widget build(BuildContext context) => ranges.isEmpty
      ? Text(text, style: style, maxLines: maxLines, overflow: TextOverflow.ellipsis)
      : Text.rich(TextSpan(children: highlightSpans(text, ranges)), style: style, maxLines: maxLines, overflow: TextOverflow.ellipsis);
}

String searchFieldLabel(AppLocalizations l10n, SearchField f) => switch (f) {
      SearchField.name => l10n.name,
      SearchField.alias => l10n.searchOtherName,
      SearchField.city => l10n.city,
      SearchField.contactPerson => l10n.contactPerson,
      SearchField.contact => l10n.searchContact,
      SearchField.phone => l10n.phone,
      SearchField.vat => l10n.vat,
      SearchField.cr => l10n.companyId,
      SearchField.salesperson => l10n.salesExecutive,
    };

/// "Phone: +966 55 123 4567" with the match highlighted, for a row whose
/// name didn't match.
TextSpan searchHitSpan(AppLocalizations l10n, SearchHit hit) => TextSpan(children: [
      TextSpan(text: '${searchFieldLabel(l10n, hit.field)}: '),
      ...highlightSpans(hit.text, hit.ranges),
    ]);
