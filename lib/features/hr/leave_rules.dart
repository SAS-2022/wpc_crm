import 'package:intl/intl.dart';

import '../../core/app_user.dart';
import '../attendance/absence.dart' show smActsAsHr;
import '../notifications/notifications.dart' show directManagersOf;

/// "My leave" (own balances and new requests). Greyed out 2026-10-20 until
/// the module was finished; open to every employee since 2026-10-30.
const myLeaveEnabled = true;

/// One kind of leave (or a non-leave request such as a salary certificate),
/// set by HR in Firestore `settings/leaveTypes` {types: [...]}. Until HR
/// saves the list, [LeaveType.defaults] apply.
class LeaveType {
  const LeaveType({
    required this.id,
    required this.en,
    required this.ar,
    this.isLeave = true,
    this.yearlyDays,
    this.calendarDays = false,
    this.paid = true,
    this.needsDocument = false,
    this.documentEn = '',
    this.documentAr = '',
  });

  final String id;
  final String en;
  final String ar;

  /// Leave has dates and counts days; a request (letter, advance) has neither.
  final bool isLeave;

  /// Days per year everyone gets unless HR sets another number for a person;
  /// null = no balance kept (e.g. unpaid leave).
  final int? yearlyDays;

  /// Counts every day of the range (sick, maternity); otherwise only work
  /// days that are not public holidays.
  final bool calendarDays;
  final bool paid;

  /// The request can't be sent without a file, e.g. a hospital report.
  final bool needsDocument;
  final String documentEn;
  final String documentAr;

  String name(String lang) => lang == 'ar' && ar.isNotEmpty ? ar : en;
  String document(String lang) => lang == 'ar' && documentAr.isNotEmpty ? documentAr : documentEn;

  /// Saudi labour law as a starting point; HR checks and edits the numbers.
  static const defaults = [
    LeaveType(id: 'annual', en: 'Annual leave', ar: 'إجازة سنوية', yearlyDays: 21),
    LeaveType(
      id: 'sick',
      en: 'Sick leave',
      ar: 'إجازة مرضية',
      yearlyDays: 120,
      calendarDays: true,
      needsDocument: true,
      documentEn: 'Hospital / medical report',
      documentAr: 'تقرير طبي من المستشفى',
    ),
    LeaveType(id: 'emergency', en: 'Emergency leave', ar: 'إجازة اضطرارية', yearlyDays: 5),
    LeaveType(
      id: 'marriage',
      en: 'Marriage leave',
      ar: 'إجازة زواج',
      yearlyDays: 5,
      needsDocument: true,
      documentEn: 'Marriage contract',
      documentAr: 'عقد الزواج',
    ),
    LeaveType(
      id: 'bereavement',
      en: 'Bereavement leave',
      ar: 'إجازة وفاة',
      yearlyDays: 5,
      needsDocument: true,
      documentEn: 'Death certificate',
      documentAr: 'شهادة الوفاة',
    ),
    LeaveType(
      id: 'paternity',
      en: 'Paternity leave',
      ar: 'إجازة مولود',
      yearlyDays: 3,
      needsDocument: true,
      documentEn: 'Birth certificate',
      documentAr: 'شهادة الميلاد',
    ),
    LeaveType(
      id: 'maternity',
      en: 'Maternity leave',
      ar: 'إجازة وضع',
      yearlyDays: 84,
      calendarDays: true,
      needsDocument: true,
      documentEn: 'Medical report',
      documentAr: 'تقرير طبي',
    ),
    LeaveType(
      id: 'hajj',
      en: 'Hajj leave',
      ar: 'إجازة حج',
      yearlyDays: 15,
      calendarDays: true,
      needsDocument: true,
      documentEn: 'Hajj permit',
      documentAr: 'تصريح الحج',
    ),
    LeaveType(
      id: 'exam',
      en: 'Exam leave',
      ar: 'إجازة امتحان',
      needsDocument: true,
      documentEn: 'Exam schedule',
      documentAr: 'جدول الامتحانات',
    ),
    LeaveType(id: 'unpaid', en: 'Unpaid leave', ar: 'إجازة بدون راتب', paid: false),
    LeaveType(id: 'salaryCertificate', en: 'Salary certificate', ar: 'تعريف بالراتب', isLeave: false),
    LeaveType(id: 'experienceLetter', en: 'Experience letter', ar: 'شهادة خبرة', isLeave: false),
    LeaveType(id: 'salaryAdvance', en: 'Salary advance', ar: 'سلفة على الراتب', isLeave: false),
  ];

  factory LeaveType.fromMap(Map<String, dynamic> m) => LeaveType(
        id: m['id'] as String? ?? '',
        en: m['en'] as String? ?? '',
        ar: m['ar'] as String? ?? '',
        isLeave: m['isLeave'] as bool? ?? true,
        yearlyDays: (m['yearlyDays'] as num?)?.toInt(),
        calendarDays: m['calendarDays'] as bool? ?? false,
        paid: m['paid'] as bool? ?? true,
        needsDocument: m['needsDocument'] as bool? ?? false,
        documentEn: m['documentEn'] as String? ?? '',
        documentAr: m['documentAr'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'en': en,
        'ar': ar,
        'isLeave': isLeave,
        'yearlyDays': isLeave ? yearlyDays : null,
        'calendarDays': calendarDays,
        'paid': paid,
        'needsDocument': needsDocument,
        'documentEn': needsDocument ? documentEn : '',
        'documentAr': needsDocument ? documentAr : '',
      };
}

/// "2026-10-17".
String leaveDayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Days a leave from [from] to [to] (both included) uses. Calendar-day types
/// count every day; others skip days off ([workDays], ISO weekdays) and
/// [holidays] ('yyyy-MM-dd'). [halfDay] (one-day leave only) counts 0.5.
double leaveDays({
  required DateTime from,
  required DateTime to,
  required bool calendarDays,
  required Set<int> workDays,
  required Set<String> holidays,
  bool halfDay = false,
}) {
  final start = DateTime(from.year, from.month, from.day);
  final end = DateTime(to.year, to.month, to.day);
  var days = 0;
  for (var d = start; !d.isAfter(end); d = DateTime(d.year, d.month, d.day + 1)) {
    if (calendarDays || (workDays.contains(d.weekday) && !holidays.contains(leaveDayKey(d)))) days++;
  }
  return halfDay && start == end && days == 1 ? 0.5 : days.toDouble();
}

enum LeaveStatus { pending, approved, rejected, cancelled }

/// One approval in a request's chain. [uid] is set for the requester's
/// direct manager; other steps can be taken by any active user with [role].
class ApprovalStep {
  const ApprovalStep({
    required this.role,
    this.uid,
    this.status = LeaveStatus.pending,
    this.byId,
    this.at,
    this.comment = '',
  });

  final UserRole role;
  final String? uid;

  /// pending, approved or rejected.
  final LeaveStatus status;
  final String? byId;
  final DateTime? at;
  final String comment;

  /// `leave_requests.awaitingKey` while this step is the current one: who may
  /// act on it, in a form one equality / `in` query finds.
  String get awaitingKey => uid != null ? 'uid:$uid' : 'role:${role.value}';

  ApprovalStep decide({required bool approve, required String byId, required DateTime at, String comment = ''}) =>
      ApprovalStep(
        role: role,
        uid: uid,
        status: approve ? LeaveStatus.approved : LeaveStatus.rejected,
        byId: byId,
        at: at,
        comment: comment,
      );
}

/// Who approves [requester]'s requests (user decision 2026-10-30, replaces
/// the long role chain): their direct manager ([directManagersOf]: the one
/// chosen on the user form, else the automatic one), then HR. Both must
/// approve, in that order. No direct manager (the GM) → HR only. One
/// direct manager = a step for that person; several (e.g. two sales
/// managers) = any of them. While nobody has the HR role, the sales manager
/// stands in ([smActsAsHr]), else the GM. A manager who would also take
/// the HR step isn't asked twice. Empty = nobody can approve yet.
List<ApprovalStep> approvalChain(AppUser requester, List<AppUser> users) {
  bool anyone(UserRole role) => users.any((u) => u.active && u.role == role && u.id != requester.id);
  final hasHr = users.any((u) => u.active && u.role == UserRole.hr);
  final hrRole = hasHr
      ? (anyone(UserRole.hr) ? UserRole.hr : null)
      : [if (smActsAsHr) UserRole.salesManager, UserRole.gm].where(anyone).firstOrNull;
  final managers = [
    for (final id in directManagersOf(requester, users)) ...users.where((u) => u.id == id),
  ];
  final manager = switch (managers) {
    [final m] => ApprovalStep(role: m.role, uid: m.id),
    [final m, ...] => ApprovalStep(role: m.role),
    _ => null,
  };
  return [
    if (manager != null && manager.role != hrRole) manager,
    if (hrRole != null) ApprovalStep(role: hrRole),
  ];
}

/// Who is only informed of [requester]'s request at every step (user
/// decision 2026-10-30): every GM, and for a sales executive also the sales
/// managers — never the requester or anyone who takes a step of [chain].
List<String> leaveWatchers(AppUser requester, List<ApprovalStep> chain, List<AppUser> users) {
  bool approves(AppUser u) => chain.any((s) => s.uid == u.id || (s.uid == null && s.role == u.role));
  return [
    for (final u in users)
      if (u.active &&
          u.id != requester.id &&
          (u.role == UserRole.gm || (requester.role == UserRole.salesExec && u.role == UserRole.salesManager)) &&
          !approves(u))
        u.id,
  ];
}

/// Whether [me] is the one to act on a request now: it's pending, not their
/// own, and its current step is theirs (by uid, or by role).
bool canDecide({required AppUser me, required String requesterId, required String? awaitingKey}) =>
    awaitingKey != null &&
    me.id != requesterId &&
    (awaitingKey == 'uid:${me.id}' || awaitingKey == 'role:${me.role.value}');

/// The type whose days left over (or overdrawn) move to the next leave year.
const annualLeaveTypeId = 'annual';

/// Leave years (user request 2026-10-24): each person's runs from their
/// joining date's anniversary (`users.joiningDate`) to the day before the
/// next one; without a joining date, the calendar year. A year is named by
/// the calendar year it starts in. Same as `leaveYearOf` in
/// functions/leaveYears.js.
int leaveYearOf(String? joiningDate, DateTime day) {
  final j = joiningDate == null ? null : DateTime.tryParse(joiningDate);
  if (j == null) return day.year;
  final start = _anniversary(j, day.year);
  final d = DateTime(day.year, day.month, day.day);
  return d.isBefore(start) ? day.year - 1 : day.year;
}

/// First and last day of leave year [year].
({DateTime start, DateTime end}) leaveYearRange(String? joiningDate, int year) {
  final j = joiningDate == null ? null : DateTime.tryParse(joiningDate);
  if (j == null) return (start: DateTime(year), end: DateTime(year, 12, 31));
  final next = _anniversary(j, year + 1);
  return (start: _anniversary(j, year), end: DateTime(next.year, next.month, next.day - 1));
}

/// The joining day and month in [year] (29 February → 28 February).
DateTime _anniversary(DateTime joining, int year) {
  final d = DateTime(year, joining.month, joining.day);
  return d.month == joining.month ? d : DateTime(year, joining.month + 1, 0);
}

/// What moves from a closed year's annual leave into the next one: days
/// overdrawn always (taken from the new year); days left only when HR lets
/// annual leave carry over (`settings/leavePolicy.annualCarryOver`).
double annualCarry(double remaining, {required bool carryOver}) =>
    remaining < 0 ? remaining : (carryOver ? remaining : 0);

/// One person's numbers for one leave type and year.
class LeaveBalance {
  const LeaveBalance({required this.entitled, required this.used, required this.pending, this.carried = 0});

  /// Yearly days (HR's number for the person, else the type's) plus adjustments.
  final double entitled;

  /// Moved from the year before (annual leave; negative = overdrawn then).
  final double carried;

  /// Approved requests, and requests still waiting for approval.
  final double used;
  final double pending;

  double get remaining => entitled + carried - used - pending;
}

/// A request as far as balances are concerned. [from] ('yyyy-MM-dd') places
/// it in the person's leave year; requests without dates use [year].
typedef LeaveUse = ({String typeId, int year, String? from, double days, LeaveStatus status});

/// A person's adjustment (carry-over, correction), + or − days.
typedef LeaveAdjustment = ({String typeId, double days});

/// Balances per type id for the types that keep one ([LeaveType.yearlyDays]).
Map<String, LeaveBalance> leaveBalances({
  required List<LeaveType> types,
  required int year,
  String? joiningDate,
  required Map<String, num> entitledOverride,
  required List<LeaveAdjustment> adjustments,
  Map<String, num> carried = const {},
  required List<LeaveUse> requests,
}) {
  bool inYear(LeaveUse r) {
    final from = r.from == null ? null : DateTime.tryParse(r.from!);
    return from == null ? r.year == year : leaveYearOf(joiningDate, from) == year;
  }

  return {
    for (final t in types)
      if (t.isLeave && t.yearlyDays != null)
        t.id: () {
          double sum(LeaveStatus s) => requests
              .where((r) => r.typeId == t.id && r.status == s && inYear(r))
              .fold(0.0, (a, r) => a + r.days);
          final entitled = (entitledOverride[t.id] ?? t.yearlyDays!).toDouble() +
              adjustments.where((a) => a.typeId == t.id).fold(0.0, (a, b) => a + b.days);
          return LeaveBalance(
            entitled: entitled,
            carried: (carried[t.id] ?? 0).toDouble(),
            used: sum(LeaveStatus.approved),
            pending: sum(LeaveStatus.pending),
          );
        }(),
  };
}

/// "3" or "2.5".
String formatLeaveDays(double days) => days == days.roundToDouble() ? '${days.round()}' : '$days';
