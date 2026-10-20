import 'package:cloud_firestore/cloud_firestore.dart';

import '../l10n/app_localizations.dart';
import '../features/tracking/work_hours.dart';
import 'app_version.dart';

enum UserRole {
  salesExec('sales_exec'),
  kam('kam'),
  salesManager('sales_manager'),
  gm('gm'),
  hr('hr'),
  accounting('accounting'),
  procurement('procurement'),

  /// Attendance only (user request 2026-10-19). Drivers go out and come back
  /// during the day, like the sales team.
  worker('worker'),
  engineer('engineer'),
  driver('driver'),

  /// Manages the drivers: Drivers live map, their route history and
  /// tracking alerts; attendance like other staff (user decision 2026-10-20).
  logisticsManager('logistics_manager'),

  /// Attendance only for now (user decision 2026-10-20).
  warehouseSupervisor('warehouse_supervisor'),

  /// A role this app version doesn't know (added in a later version): no
  /// access until the app is updated. Never stored.
  unknown('');

  const UserRole(this.value);

  /// Value stored in Firestore `users/{uid}.role` and RTDB `roles/{uid}`.
  final String value;

  /// Roles that can be given to a user (the user form's list).
  static const assignable = [
    salesExec, kam, salesManager, gm, hr, accounting, procurement, worker, engineer, driver,
    logisticsManager, warehouseSupervisor,
  ];

  /// Unknown or missing values become [unknown], never a sales role: an old
  /// app must not treat a newer role as a sales executive (tracked, sees
  /// clients).
  static UserRole fromValue(String? value) =>
      assignable.firstWhere((r) => r.value == value, orElse: () => unknown);

  /// Sales manager and GM: manage users, import and edit clients.
  bool get isAdmin => this == salesManager || this == gm;

  /// KAM, sales manager and GM: see all clients, visits and live locations.
  bool get isSupervisor => isAdmin || this == kam;

  /// The sales field staff (clients, plans, visits, targets).
  bool get isTracked => this == salesExec || this == kam;

  /// Location shared during work hours (live map, route history): the sales
  /// field staff and drivers (user request 2026-10-20; drivers are shown
  /// apart, see [isDriver]).
  bool get isLocationTracked => isTracked || this == driver;
  bool get isDriver => this == driver;

  /// Sees the drivers' live locations and route history: sales manager, GM
  /// and the logistics manager.
  bool get managesDrivers => isAdmin || this == logisticsManager;

  /// The sales team: uses clients, visits and plans.
  bool get isSales => isSupervisor || this == salesExec;

  /// HR, accounting, procurement, workers, engineers and drivers: no sales
  /// features; Home (attendance, leave), Profile.
  bool get isBackOffice =>
      this == hr ||
      this == accounting ||
      this == procurement ||
      this == worker ||
      this == engineer ||
      this == driver ||
      this == logisticsManager ||
      this == warehouseSupervisor;

  /// Attendance: people who leave the work site during the day (sales team,
  /// drivers) aren't checked out when they leave before the end of the day;
  /// office staff are (at the time they left).
  bool get leavesSiteForWork => this == salesExec || this == kam || this == driver;

  /// HR or GM: run the HR area (attendance, payroll, leave, warnings).
  bool get isHr => this == hr || this == gm;

  /// Sees the HR area. The sales manager too, for now (user decision
  /// 2026-10-17, so they can test it).
  bool get canSeeHr => isHr || this == salesManager;

  /// Edits leave types, holidays, balances and request details in the HR
  /// area. HR and GM; the sales manager too for now (user asked 2026-10-17
  /// to edit while testing — narrow to [isHr] later).
  bool get canManageHr => isHr || this == salesManager;

  String label(AppLocalizations l10n) => switch (this) {
        salesExec => l10n.roleSalesExec,
        kam => l10n.roleKam,
        salesManager => l10n.roleSalesManager,
        gm => l10n.roleGm,
        hr => l10n.roleHr,
        accounting => l10n.roleAccounting,
        procurement => l10n.roleProcurement,
        worker => l10n.roleWorker,
        engineer => l10n.roleEngineer,
        driver => l10n.roleDriver,
        logisticsManager => l10n.roleLogisticsManager,
        warehouseSupervisor => l10n.roleWarehouseSupervisor,
        unknown => l10n.roleUnknown,
      };
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.kamId,
    required this.active,
    this.odooName = '',
    this.monthlyTarget = 0,
    this.appVersions = const {},
    this.updateRemindedAt,
    this.companyId = '',
    this.position = '',
    this.approval = '',
    this.registeredAt,
    this.workSiteIds = const [],
    this.overtimeAllowed = false,
    this.attendanceRequired,
    this.workSchedule,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final UserRole role;

  /// The KAM supervising this sales executive.
  final String? kamId;
  final bool active;

  /// Salesperson name as written in Odoo exports, used to assign imported clients.
  final String odooName;

  /// Visits per month expected from this person; 0 = no target.
  final int monthlyTarget;

  /// Installed app per phone platform ('android' / 'ios'), reported by the app.
  final Map<String, InstalledVersion> appVersions;

  /// Last "please update" reminder (one a minute at most).
  final DateTime? updateRemindedAt;

  /// The company they work for (`companies/{id}`) and their job title.
  final String companyId;
  final String position;

  /// Self-registration (2026-10-19): 'pending' until the sales manager / GM
  /// approves, 'rejected', or '' (approved / created by an admin).
  final String approval;
  final DateTime? registeredAt;
  bool get isPendingApproval => approval == 'pending';

  /// Attendance: the work sites they check in at, and whether time after
  /// the end of the work day counts (overtime).
  final List<String> workSiteIds;
  final bool overtimeAllowed;

  /// Set on the user form (2026-10-20). Not set yet: everyone outside the
  /// sales team, plus sales people already given a work site.
  final bool? attendanceRequired;
  bool get needsAttendance => attendanceRequired ?? defaultAttendance(role, workSiteIds);

  /// Checks in and out: attendance required and at least one work site.
  bool get checksAttendance => needsAttendance && workSiteIds.isNotEmpty;

  /// Their own attendance days and hours (2026-10-20, user form); null =
  /// the company work hours (More → Work hours).
  final WorkHours? workSchedule;
  WorkHours scheduleOr(WorkHours company) => workSchedule ?? company;

  static bool defaultAttendance(UserRole role, List<String> workSiteIds) => !role.isSales || workSiteIds.isNotEmpty;

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return AppUser(
      id: doc.id,
      name: d['name'] as String? ?? '',
      email: d['email'] as String? ?? '',
      phone: d['phone'] as String? ?? '',
      role: UserRole.fromValue(d['role'] as String?),
      kamId: d['kamId'] as String?,
      active: d['active'] as bool? ?? false,
      odooName: d['odooName'] as String? ?? '',
      monthlyTarget: (d['monthlyTarget'] as num?)?.toInt() ?? 0,
      appVersions: InstalledVersion.parseAll(d['appVersions']),
      updateRemindedAt: (d['updateRemindedAt'] as Timestamp?)?.toDate(),
      companyId: d['companyId'] as String? ?? '',
      position: d['position'] as String? ?? '',
      approval: d['approval'] as String? ?? '',
      registeredAt: (d['registeredAt'] as Timestamp?)?.toDate(),
      workSiteIds: List<String>.from(d['workSiteIds'] as List? ?? const []),
      overtimeAllowed: d['overtimeAllowed'] == true,
      attendanceRequired: d['attendanceRequired'] as bool?,
      workSchedule: WorkHours.tryParse(d['workSchedule']),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'phone': phone,
        'role': role.value,
        'kamId': role == UserRole.salesExec ? kamId : null,
        'active': active,
        'odooName': odooName,
        'monthlyTarget': role.isTracked ? monthlyTarget : 0,
        'companyId': companyId,
        'position': position,
        'workSiteIds': workSiteIds,
        'overtimeAllowed': overtimeAllowed,
        'attendanceRequired': ?attendanceRequired,
        'workSchedule': workSchedule?.toMap(),
      };
}
