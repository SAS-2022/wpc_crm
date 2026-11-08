import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/app_user.dart';

// HR actions (user request 2026-11-07): warnings, deductions, rewards and
// notes HR keeps on an employee — Firestore `hr_actions/{id}` (+
// `attachments`), read and written by the HR area only. Deductions and
// rewards carry the payroll month they belong to (`payroll.dart` uses them
// once payroll is turned on).
//
// Acknowledgement (user request 2026-11-07): a record sent to the employee
// ([HrAction.sent]; always for warnings, deductions and rewards, notes only
// when HR ticks it) covers the app until they press "Agreed and Accepted"
// ([HrAction.acceptedAt]); HR is then told (`hrActionWritten` Cloud
// Function). Only HR (role hr) adds or changes records; an edit of an
// accepted record asks the employee again.

/// Only HR adds, edits, cancels or deletes records (user 2026-11-07; rules `hrOnly()`).
bool canEditHrActions(AppUser? me) => me != null && me.active && me.role == UserRole.hr;

enum HrActionKind {
  warning,
  deduction,
  reward,
  note;

  static HrActionKind fromKey(Object? key) => values.asNameMap()[key] ?? note;

  /// Has an amount (SAR) and / or days of salary, and a payroll month.
  bool get affectsPay => this == deduction || this == reward;

  /// Always sent to the employee to accept (notes: HR's choice).
  bool get alwaysSent => this != note;
}

/// Warning steps, from the mildest.
enum WarningLevel {
  verbal,
  first,
  second,
  last;

  static WarningLevel? fromKey(Object? key) => values.asNameMap()[key];
}

/// Warnings count towards the next step for this long (company practice;
/// change when HR gives the rule).
const warningActiveDays = 180;

class HrAction {
  const HrAction({
    this.id = '',
    required this.uid,
    required this.kind,
    this.level,
    required this.date,
    String? month,
    required this.title,
    this.notes = '',
    this.amount,
    this.days,
    this.cancelled = false,
    this.cancelNote = '',
    this.createdBy = '',
    this.createdAt,
    bool? sent,
    this.acceptedAt,
  })  : month = month ?? '',
        sent = sent ?? kind != HrActionKind.note;

  final String id;
  final String uid;
  final HrActionKind kind;

  /// Warnings only.
  final WarningLevel? level;

  /// 'yyyy-MM-dd': when it happened / was issued.
  final String date;

  /// 'yyyy-MM': the payroll month a deduction / reward applies to ('' = the date's month).
  final String month;
  final String title;
  final String notes;

  /// SAR (deductions / rewards).
  final double? amount;

  /// Days of salary (deductions / rewards).
  final double? days;

  /// Cancelled ones stay on record but don't count.
  final bool cancelled;
  final String cancelNote;
  final String createdBy;
  final DateTime? createdAt;

  /// Shown to the employee, who must accept it.
  final bool sent;

  /// When the employee pressed "Agreed and Accepted" (null = not yet).
  final DateTime? acceptedAt;

  /// Sent, not cancelled and not accepted yet: covers the employee's app.
  bool get awaitingAcceptance => sent && !cancelled && acceptedAt == null;

  /// The fields the employee accepted: changing any asks them again.
  bool sameContentAs(HrAction o) =>
      o.kind == kind && o.level == level && o.date == date && o.payMonth == payMonth && o.title == title &&
      o.notes == notes && o.amount == amount && o.days == days;

  /// The payroll month it counts in.
  String get payMonth => month.isNotEmpty ? month : (date.length >= 7 ? date.substring(0, 7) : '');

  factory HrAction.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) => HrAction.fromMap(doc.data() ?? const {}, id: doc.id);

  factory HrAction.fromMap(Map<String, dynamic> d, {String id = ''}) {
    final kind = HrActionKind.fromKey(d['kind']);
    return HrAction(
      id: id,
      uid: d['uid'] as String? ?? '',
      kind: kind,
      level: kind == HrActionKind.warning ? WarningLevel.fromKey(d['level']) : null,
      date: d['date'] as String? ?? '',
      month: d['month'] as String?,
      title: d['title'] as String? ?? '',
      notes: d['notes'] as String? ?? '',
      amount: (d['amount'] as num?)?.toDouble(),
      days: (d['days'] as num?)?.toDouble(),
      cancelled: d['cancelled'] == true,
      cancelNote: d['cancelNote'] as String? ?? '',
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      sent: d['sent'] as bool?,
      acceptedAt: (d['acceptedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// The fields HR edits (the repository adds who / when).
  Map<String, dynamic> toMap() => {
        'uid': uid,
        'kind': kind.name,
        'level': kind == HrActionKind.warning ? level?.name : null,
        'date': date,
        'month': kind.affectsPay ? payMonth : null,
        'title': title,
        'notes': notes,
        'amount': kind.affectsPay ? amount : null,
        'days': kind.affectsPay ? days : null,
        'sent': kind.alwaysSent || sent,
      };
}

/// The step to suggest for [uid]'s next warning on [day]: one above the
/// highest active warning of the last [warningActiveDays] days (verbal
/// when none; stays at the last step).
WarningLevel nextWarningLevel(List<HrAction> actions, String uid, DateTime day) {
  final since = DateTime(day.year, day.month, day.day - warningActiveDays);
  var highest = -1;
  for (final a in actions) {
    final d = DateTime.tryParse(a.date);
    if (a.uid != uid || a.cancelled || a.kind != HrActionKind.warning || a.level == null || d == null) continue;
    if (d.isBefore(since) || d.isAfter(day)) continue;
    if (a.level!.index > highest) highest = a.level!.index;
  }
  return WarningLevel.values[(highest + 1).clamp(0, WarningLevel.values.length - 1)];
}

/// Deductions and rewards of [uid] in payroll month [month] ('yyyy-MM'),
/// cancelled ones left out.
typedef PayEffects = ({double deductedAmount, double deductedDays, double rewardAmount, double rewardDays});

PayEffects payEffects(List<HrAction> actions, String uid, String month) {
  var dA = 0.0, dD = 0.0, rA = 0.0, rD = 0.0;
  for (final a in actions) {
    if (a.uid != uid || a.cancelled || !a.kind.affectsPay || a.payMonth != month) continue;
    if (a.kind == HrActionKind.deduction) {
      dA += a.amount ?? 0;
      dD += a.days ?? 0;
    } else {
      rA += a.amount ?? 0;
      rD += a.days ?? 0;
    }
  }
  return (deductedAmount: dA, deductedDays: dD, rewardAmount: rA, rewardDays: rD);
}

/// "1,250.50" style amount without trailing zeros ("300", "12.5").
String formatAmount(double v) {
  final r = (v * 100).roundToDouble() / 100;
  return r == r.roundToDouble() ? '${r.round()}' : r.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');
}
