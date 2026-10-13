import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'client.dart';

const clientCategories = ['A', 'B', 'C'];
const defaultCategory = 'B';

/// Days since the last visit up to which a client is green, then yellow.
class CategoryRule {
  const CategoryRule(this.greenDays, this.yellowDays);

  final int greenDays;
  final int yellowDays;
}

/// Visit frequency per category, set by the GM / sales manager in
/// `settings/visitRules`.
class VisitRules {
  const VisitRules(this.byCategory);

  static const defaults = VisitRules({
    'A': CategoryRule(7, 14),
    'B': CategoryRule(14, 28),
    'C': CategoryRule(30, 45),
  });

  final Map<String, CategoryRule> byCategory;

  CategoryRule of(String category) => byCategory[category] ?? byCategory[defaultCategory]!;

  factory VisitRules.fromMap(Map<String, dynamic>? d) => VisitRules({
        for (final c in clientCategories)
          c: switch (d?[c]) {
            {'green': final num g, 'yellow': final num y} => CategoryRule(g.toInt(), y.toInt()),
            _ => defaults.byCategory[c]!,
          },
      });

  Map<String, dynamic> toMap() => {
        for (final e in byCategory.entries) e.key: {'green': e.value.greenDays, 'yellow': e.value.yellowDays},
      };
}

final visitRulesProvider = StreamProvider<VisitRules>((ref) => FirebaseFirestore.instance
    .doc('settings/visitRules')
    .snapshots()
    .map((s) => VisitRules.fromMap(s.data())));

Future<void> saveVisitRules(VisitRules rules) =>
    FirebaseFirestore.instance.doc('settings/visitRules').set(rules.toMap());

/// green = visited recently, yellow = due soon, red = overdue (or never visited).
enum VisitStatus { recent, dueSoon, overdue }

VisitStatus visitStatus(Client c, VisitRules rules, DateTime now) {
  if (c.lastVisitAt == null) return VisitStatus.overdue;
  final days = now.difference(c.lastVisitAt!).inDays;
  final rule = rules.of(c.category);
  if (days <= rule.greenDays) return VisitStatus.recent;
  if (days <= rule.yellowDays) return VisitStatus.dueSoon;
  return VisitStatus.overdue;
}

/// Fixed status colours (always shown with a label or the legend).
const statusRecentColor = Color(0xFF0CA30C);
const statusDueSoonColor = Color(0xFFFAB219);
const statusOverdueColor = Color(0xFFD03B3B);

/// Clients on today's plan.
const plannedColor = Color(0xFF2A78D6);

Color visitStatusColor(VisitStatus s) => switch (s) {
      VisitStatus.recent => statusRecentColor,
      VisitStatus.dueSoon => statusDueSoonColor,
      VisitStatus.overdue => statusOverdueColor,
    };

String visitStatusLabel(VisitStatus s, AppLocalizations l10n) => switch (s) {
      VisitStatus.recent => l10n.statusRecent,
      VisitStatus.dueSoon => l10n.statusDueSoon,
      VisitStatus.overdue => l10n.statusOverdue,
    };
