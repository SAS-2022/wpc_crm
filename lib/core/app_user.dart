import 'package:cloud_firestore/cloud_firestore.dart';

import '../l10n/app_localizations.dart';
import '../features/attendance/attendance_rules.dart' show defaultOvertimeMaxMin;
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

  /// Production (user decision 2026-10-30): the factory manager approves
  /// the production staff's leave first (engineers, operators, workers of
  /// the Production department), then HR. Operators: attendance only.
  factoryManager('factory_manager'),
  operator('operator'),

  /// A role this app version doesn't know (added in a later version): no
  /// access until the app is updated. Never stored.
  unknown('');

  const UserRole(this.value);

  /// Value stored in Firestore `users/{uid}.role` and RTDB `roles/{uid}`.
  final String value;

  /// Roles that can be given to a user (the user form's list).
  static const assignable = [
    salesExec, kam, salesManager, gm, hr, accounting, procurement, worker, engineer, driver,
    logisticsManager, warehouseSupervisor, factoryManager, operator,
  ];

  /// What a person may ask for when registering (2026-10-21: the role is
  /// the job; the old Positions list repeated it). Managers are made by an admin.
  static const registrable = [
    salesExec, kam, hr, accounting, procurement, worker, engineer, driver, logisticsManager, warehouseSupervisor,
    factoryManager, operator,
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

  /// Office staff whose GPS is recorded (not shared live) during the
  /// recording hours when they check attendance (2026-10-28, see
  /// [AppUser.recordsGps]): the back office except drivers.
  bool get recordsGps => isBackOffice && !isLocationTracked;
  bool get isDriver => this == driver;

  /// Sees the drivers' live locations and route history: sales manager, GM
  /// and the logistics manager.
  bool get managesDrivers => isAdmin || this == logisticsManager;

  /// Drivers page and their route history: [managesDrivers] for every
  /// driver, the warehouse supervisor for their own drivers
  /// ([AppUser.supervisorId], user decision 2026-10-23).
  bool get seesDrivers => managesDrivers || this == warehouseSupervisor;

  /// Manager roles: always a manager, can be someone's direct manager
  /// (2026-10-23). Anyone else becomes one with [AppUser.markedManager].
  bool get isManagerRole =>
      this == gm || this == salesManager || this == kam || this == logisticsManager || this == factoryManager;

  /// Opens the Users page: sales manager and GM for everyone, the logistics
  /// manager for drivers only (user decision 2026-10-23).
  bool get managesUsers => isAdmin || this == logisticsManager;

  /// The roles this person may give to and edit on the user form.
  List<UserRole> get editableRoles => isAdmin
      ? assignable
      : this == logisticsManager
      ? const [driver]
      : const [];

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
      this == warehouseSupervisor ||
      this == factoryManager ||
      this == operator;

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
        factoryManager => l10n.roleFactoryManager,
        operator => l10n.roleOperator,
        unknown => l10n.roleUnknown,
      };
}

/// The only accounts that may delete users (user decision 2026-10-23: a
/// deletion by mistake does great harm). Same list as USER_DELETERS in
/// functions/index.js, which enforces it.
const userDeleterEmails = {'wissam.b@woodpanelsco.com'};

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
    this.overtimeMaxMin,
    this.attendanceRequired,
    this.leaveSiteAllowed,
    this.workSchedule,
    this.managerId,
    this.markedManager = false,
    this.supervisorId,
    this.joiningDate,
    this.department,
    this.homeLocation,
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

  /// The company they work for (`companies/{id}`).
  final String companyId;

  /// Registration's job choice (2026-10-21: a role value, see
  /// [requestedRole]); earlier a position id from the old Positions list.
  /// No longer edited: the role is the job. Kept as stored.
  final String position;

  /// The role a self-registered person asked for, preselected on approval.
  UserRole? get requestedRole => requestedRoleOf(position);

  /// Role values, plus the ids of the old Positions list that match a role.
  static UserRole? requestedRoleOf(String position) {
    final role = UserRole.fromValue(position);
    if (role != UserRole.unknown) return role;
    return switch (position) {
      'sales_executive' => UserRole.salesExec,
      'key_account_manager' => UserRole.kam,
      'accountant' => UserRole.accounting,
      'procurement_officer' => UserRole.procurement,
      'hr_officer' => UserRole.hr,
      _ => null,
    };
  }

  /// Self-registration (2026-10-19): 'pending' until the sales manager / GM
  /// approves, 'rejected', or '' (approved / created by an admin).
  final String approval;
  final DateTime? registeredAt;
  bool get isPendingApproval => approval == 'pending';

  /// Attendance: the work sites they check in at, and whether time after
  /// the end of the work day counts (overtime).
  final List<String> workSiteIds;
  final bool overtimeAllowed;

  /// Most overtime counted a day (user form, 2026-10-24); null = 3 hours.
  final int? overtimeMaxMin;
  int get overtimeCapMin {
    final v = overtimeMaxMin;
    return v != null && v > 0 && v <= 1440 ? v : defaultOvertimeMaxMin;
  }

  /// Set on the user form (2026-10-20). Not set yet: everyone outside the
  /// sales team, plus sales people already given a work site.
  final bool? attendanceRequired;
  bool get needsAttendance => attendanceRequired ?? defaultAttendance(role, workSiteIds);

  /// User form "Allowed to leave the site" (2026-10-22): leaving during the
  /// work day doesn't check them out. Not set = the sales team and drivers.
  final bool? leaveSiteAllowed;
  bool get leavesSite => leaveSiteAllowed ?? role.leavesSiteForWork;

  /// Checks in and out: attendance required and at least one work site.
  bool get checksAttendance => needsAttendance && workSiteIds.isNotEmpty;

  /// GPS recorded 08:00–18:00 on their work days, only into the route
  /// history (no live map, no presence or alerts) — user request
  /// 2026-10-28 after a missed geofence arrival: the server then sees when
  /// they really arrived (`gpsArrival`) and whether they're at the site.
  bool get recordsGps => active && role.recordsGps && checksAttendance;

  /// Their own attendance days and hours (2026-10-20, user form); null =
  /// the company work hours (More → Work hours).
  final WorkHours? workSchedule;
  WorkHours scheduleOr(WorkHours company) => workSchedule ?? company;

  /// Their direct manager, chosen on the user form (2026-10-23); null =
  /// automatic ([directManagersOf] in notifications.dart).
  final String? managerId;

  /// User form "Is a manager" (`users.isManager`): e.g. the accounting
  /// manager, who has the Accounting role.
  final bool markedManager;

  /// Can be chosen as someone's direct manager.
  bool get isManager => role.isManagerRole || markedManager;

  /// A driver's warehouse supervisor (`users.supervisorId`, 2026-10-23):
  /// sees their tracking and attendance. Their direct manager stays the
  /// logistics manager.
  final String? supervisorId;

  /// A driver's home (`users.homeLocation` {lat, lng}, 2026-10-25): their
  /// overtime after the work day ends when they arrive here or at a work
  /// site (they take the company car home).
  final ({double lat, double lng})? homeLocation;

  /// Attendance page for the people under them (2026-10-23): managers and
  /// warehouse supervisors; the HR area ([UserRole.canSeeHr]) sees everyone.
  bool get seesTeamAttendance => role.canSeeHr || isManager || role == UserRole.warehouseSupervisor;

  /// Joining date 'yyyy-MM-dd' (HR, 2026-10-24): their leave year starts
  /// on its anniversary (`leaveYearOf` in leave_rules.dart); null = the
  /// calendar year.
  final String? joiningDate;

  /// Department id (`settings/departments`, 2026-10-24) as set on the user
  /// form / by HR; null = [defaultDepartmentOf] their role.
  final String? department;
  String? get departmentId => department ?? defaultDepartmentOf(role);

  /// The department a role belongs to until one is chosen (ids of
  /// `defaultDepartments`); workers: none (logistics or production, chosen
  /// per person — it decides who approves their leave).
  static String? defaultDepartmentOf(UserRole role) => switch (role) {
        UserRole.salesExec || UserRole.kam || UserRole.salesManager => 'sales',
        UserRole.driver || UserRole.logisticsManager => 'logistics',
        UserRole.warehouseSupervisor => 'warehouse',
        UserRole.factoryManager || UserRole.operator || UserRole.engineer => 'production',
        UserRole.gm => 'admin',
        UserRole.hr => 'hr',
        UserRole.accounting => 'accounting',
        UserRole.procurement => 'procurement',
        _ => null,
      };

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
      overtimeMaxMin: (d['overtimeMaxMin'] as num?)?.toInt(),
      attendanceRequired: d['attendanceRequired'] as bool?,
      leaveSiteAllowed: d['leaveSiteAllowed'] as bool?,
      workSchedule: WorkHours.tryParse(d['workSchedule']),
      managerId: d['managerId'] as String?,
      markedManager: d['isManager'] == true,
      supervisorId: d['supervisorId'] as String?,
      homeLocation: switch (d['homeLocation']) {
        {'lat': final num lat, 'lng': final num lng} => (lat: lat.toDouble(), lng: lng.toDouble()),
        _ => null,
      },
      joiningDate: switch (d['joiningDate']) {
        final String s when DateTime.tryParse(s) != null => s,
        _ => null,
      },
      department: switch (d['department']) {
        final String s when s.isNotEmpty => s,
        _ => null,
      },
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'phone': phone,
        'role': role.value,
        'kamId': role == UserRole.salesExec ? kamId : null,
        'active': active,
        'odooName': role.isTracked ? odooName : '',
        'monthlyTarget': role.isTracked ? monthlyTarget : 0,
        'companyId': companyId,
        'position': position,
        'workSiteIds': workSiteIds,
        'overtimeAllowed': overtimeAllowed,
        'overtimeMaxMin': overtimeAllowed ? overtimeMaxMin : null,
        'attendanceRequired': ?attendanceRequired,
        'leaveSiteAllowed': ?leaveSiteAllowed,
        'workSchedule': workSchedule?.toMap(),
        'managerId': managerId,
        'isManager': role.isManagerRole ? false : markedManager,
        'supervisorId': role == UserRole.driver ? supervisorId : null,
        'homeLocation': role == UserRole.driver && homeLocation != null
            ? {'lat': homeLocation!.lat, 'lng': homeLocation!.lng}
            : null,
        'joiningDate': joiningDate,
        'department': department,
      };
}
