import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../core/saving.dart';
import '../../l10n/app_localizations.dart';
import '../clients/client_tags.dart';
import '../users/users_repository.dart';
import 'leave_repository.dart';
import 'leave_rules.dart';

// HR additions (user request 2026-10-24): joining date (leave years run from
// its anniversary), departments, whether annual leave carries over, and the
// record kept of every closed leave year.

final _db = FirebaseFirestore.instance;

final departmentsProvider = tagListProvider(TagList.departments);

String departmentName(List<ClientTag> departments, String? id, String lang) {
  if (id == null) return '';
  for (final d in departments) {
    if (d.id == id) return d.label(lang);
  }
  return id;
}

/// "2026" or, from a joining date, "Mar 15, 2026 – Mar 14, 2027".
String leaveYearLabel(BuildContext context, String? joiningDate, int year) {
  if (joiningDate == null) return '$year';
  final r = leaveYearRange(joiningDate, year);
  final f = DateFormat.yMMMd(Localizations.localeOf(context).toString());
  return '${f.format(r.start)} – ${f.format(r.end)}';
}

/// `settings/leavePolicy` {annualCarryOver}: annual days left at the end of
/// a leave year move to the next one (true) or are lost (false, default).
/// Overdrawn days always move.
final annualCarryOverProvider = StreamProvider<bool>(
    (ref) => _db.doc('settings/leavePolicy').snapshots().map((s) => s.data()?['annualCarryOver'] == true));

Future<void> saveAnnualCarryOver(bool on) =>
    saving(() => _db.doc('settings/leavePolicy').set({'annualCarryOver': on}, SetOptions(merge: true)));

/// HR sets a person's joining date / department (rules: the HR area may
/// change only these two fields of a user).
Future<void> saveEmployeeHrFields(String uid, {required String? joiningDate, required String? department}) =>
    saving(() => _db.collection('users').doc(uid).update({'joiningDate': joiningDate, 'department': department}));

/// [uid]'s balances in leave year [year]: their joining date, HR's numbers
/// and what was carried from the year before.
Map<String, LeaveBalance> personLeaveBalances(
  WidgetRef ref, {
  required String uid,
  required int year,
  required List<LeaveType> types,
  required List<LeaveUse> requests,
}) {
  final record = ref.watch(leaveBalanceRecordProvider((uid, year))).value ?? LeaveBalanceRecord.empty;
  return leaveBalances(
    types: types,
    year: year,
    joiningDate: joiningDateOf(ref, uid),
    entitledOverride: record.entitled,
    adjustments: record.forBalance,
    carried: record.carried,
    requests: requests,
  );
}

String? joiningDateOf(WidgetRef ref, String uid) {
  for (final u in ref.watch(usersProvider).value ?? const <AppUser>[]) {
    if (u.id == uid) return u.joiningDate;
  }
  return null;
}

/// The leave year [day] falls in for [uid].
int personLeaveYear(WidgetRef ref, String uid, DateTime day) => leaveYearOf(joiningDateOf(ref, uid), day);

/// One closed leave year, written by the `closeLeaveYears` Cloud Function:
/// `leave_history/{uid}_{year}`.
class LeaveYearRecord {
  const LeaveYearRecord({
    required this.year,
    required this.from,
    required this.to,
    required this.types,
    required this.carriedOut,
    required this.carryOver,
  });

  final int year;
  final String from;
  final String to;

  /// Per type id: entitled (with adjustments), carried in, used, remaining.
  final Map<String, ({double entitled, double carried, double used, double remaining})> types;

  /// Annual days moved into the next year.
  final double carriedOut;

  /// Whether left-over days could carry over when it closed.
  final bool carryOver;

  factory LeaveYearRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    double n(Object? v) => (v as num?)?.toDouble() ?? 0;
    return LeaveYearRecord(
      year: (d['year'] as num?)?.toInt() ?? 0,
      from: d['from'] as String? ?? '',
      to: d['to'] as String? ?? '',
      types: {
        for (final e in (d['types'] as Map<String, dynamic>? ?? const {}).entries)
          if (e.value is Map)
            e.key: (
              entitled: n(e.value['entitled']),
              carried: n(e.value['carried']),
              used: n(e.value['used']),
              remaining: n(e.value['remaining']),
            ),
      },
      carriedOut: n(d['carriedOut']),
      carryOver: d['carryOver'] == true,
    );
  }
}

/// [uid]'s closed leave years, newest first.
final leaveHistoryProvider = StreamProvider.family<List<LeaveYearRecord>, String>((ref, uid) => _db
    .collection('leave_history')
    .where('uid', isEqualTo: uid)
    .snapshots()
    .map((s) => s.docs.map(LeaveYearRecord.fromDoc).toList()..sort((a, b) => b.year.compareTo(a.year))));

/// Department dropdown; empty = automatic from the role.
class DepartmentField extends ConsumerWidget {
  const DepartmentField({super.key, required this.value, required this.role, required this.onChanged});

  final String? value;
  final UserRole role;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final departments = ref.watch(departmentsProvider).value ?? defaultDepartments;
    final auto = AppUser.defaultDepartmentOf(role);
    return DropdownButtonFormField<String>(
      key: ValueKey('department-$value-${role.name}'),
      initialValue: departments.any((d) => d.id == value) ? value : '',
      decoration: InputDecoration(labelText: l10n.department),
      items: [
        DropdownMenuItem(
          value: '',
          child: Text(auto == null ? l10n.none : l10n.departmentAutomatic(departmentName(departments, auto, lang))),
        ),
        for (final d in departments) DropdownMenuItem(value: d.id, child: Text(d.label(lang))),
      ],
      onChanged: (v) => onChanged(v == null || v.isEmpty ? null : v),
    );
  }
}

/// Joining date picker row.
class JoiningDateField extends StatelessWidget {
  const JoiningDateField({super.key, required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final date = value == null ? null : DateTime.tryParse(value!);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event_outlined),
      title: Text(l10n.joiningDate),
      subtitle: Text(date == null
          ? l10n.joiningDateNotSet
          : DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(date)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (date != null)
            IconButton(icon: const Icon(Icons.clear), tooltip: l10n.clear, onPressed: () => onChanged(null)),
          const Icon(Icons.edit_calendar),
        ],
      ),
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? now,
          firstDate: DateTime(1970),
          lastDate: DateTime(now.year + 1, 12, 31),
          helpText: l10n.joiningDate,
        );
        if (picked != null) onChanged(leaveDayKey(picked));
      },
    );
  }
}

/// HR / GM / SM switch: annual leave left at the end of a leave year carries
/// over or resets (overdrawn days are always taken from the next year).
class AnnualCarryOverTile extends ConsumerWidget {
  const AnnualCarryOverTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final canEdit = ref.watch(currentUserProvider).value?.role.canManageHr ?? false;
    final on = ref.watch(annualCarryOverProvider).value ?? false;
    return SwitchListTile(
      secondary: const Icon(Icons.redo),
      title: Text(l10n.annualCarryOver),
      subtitle: Text(on ? l10n.annualCarryOverOn : l10n.annualCarryOverOff),
      value: on,
      onChanged: canEdit ? saveAnnualCarryOver : null,
    );
  }
}
