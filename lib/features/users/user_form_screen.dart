import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_user.dart';
import '../../core/login_name.dart';
import '../../core/saudi_phone.dart';
import '../../core/text_input_dialog.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import 'home_location_field.dart';
import 'users_repository.dart';
import '../notifications/notifications.dart' show directManagersOf;
import '../../core/saving.dart';
import '../attendance/attendance_rules.dart' show defaultOvertimeMaxMin;
import '../attendance/work_sites.dart';
import '../tracking/work_hours.dart';
import '../tracking/work_hours_editor.dart';
import 'companies.dart';
import '../settings/tracking_schedules_screen.dart';
import '../tracking/tracking_schedule.dart';
import '../settings/app_settings.dart';
import '../hr/hr_people.dart';

/// Create (userId == null) or edit a user. Sales manager / GM: anyone;
/// logistics manager: workers, drivers and warehouse supervisors ([UserRole.editableRoles]).
class UserFormScreen extends ConsumerStatefulWidget {
  const UserFormScreen({super.key, required this.userId});

  final String? userId;

  @override
  ConsumerState<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends ConsumerState<UserFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _username = TextEditingController();

  /// New user signs in with a username instead of an email (hidden email,
  /// see login_name.dart).
  bool _useUsername = false;

  /// Typed by the admin: the name no longer replaces it with a suggestion.
  bool _usernameEdited = false;
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _odooName = TextEditingController();
  final _target = TextEditingController();
  /// None for a new user until picked (2026-10-23: the sales-only fields
  /// stay hidden until a sales role is chosen).
  UserRole? _role;

  /// Role-based defaults (attendance, leaving the site) before a role is picked.
  UserRole get _roleOrDefault => _role ?? UserRole.worker;
  String _companyId = '';
  String _position = '';
  Set<String> _sites = {};
  bool _overtime = false;
  int? _overtimeMax;

  /// Null until set here or saved: follows the role ([AppUser.leavesSite]).
  bool? _leaveSite;

  /// Null until set here or saved: follows the role (see [AppUser.needsAttendance]).
  bool? _attendance;

  /// Their own work days / hours; null = the company work hours.
  WorkHours? _schedule;
  bool get _needsAttendance => _attendance ?? AppUser.defaultAttendance(_roleOrDefault, _sites.toList());

  /// A self-registered account waiting for approval.
  AppUser? _pending;
  String? _kamId;

  /// Direct manager chosen here; null = automatic ([directManagersOf]).
  String? _managerId;

  /// "Is a manager" for roles that aren't manager roles (e.g. the accounting manager).
  bool _markedManager = false;

  /// A driver's warehouse supervisor.
  String? _supervisorId;
  ({double lat, double lng})? _home;
  String? _joiningDate;
  String? _department;
  bool _active = true;
  bool _loaded = false;
  bool _busy = false;

  bool get _isNew => widget.userId == null;

  /// Saved role of the user being edited (null for a new one).
  UserRole? _savedRole;

  /// Only the accounts in [userDeleterEmails]. Never oneself.
  bool _canDelete(AppUser? me) =>
      !_isNew && me != null && widget.userId != me.id && userDeleterEmails.contains(me.email.trim().toLowerCase());

  /// GM: anyone; sales manager: anyone but GMs and sales managers;
  /// logistics manager: drivers. Never oneself (same rule as the
  /// `setUserPassword` Cloud Function).
  bool _canSetPassword(AppUser? me) =>
      !_isNew &&
      me != null &&
      widget.userId != me.id &&
      (me.role == UserRole.gm ||
          (me.role == UserRole.salesManager && _savedRole?.isAdmin != true) ||
          (me.role == UserRole.logisticsManager && me.role.editableRoles.contains(_savedRole)));

  Future<void> _setPassword() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final password = await showTextInputDialog(
      context,
      title: l10n.setPasswordFor(_name.text),
      label: l10n.newPassword,
      confirmLabel: l10n.setPassword,
      maxLines: 1,
    );
    if (password == null || !mounted) return;
    if (password.length < 6) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.passwordTooShort)));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(usersRepositoryProvider).setPassword(widget.userId!, password);
      messenger.showSnackBar(SnackBar(content: Text(l10n.passwordSetFor(_name.text))));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _username, _phone, _password, _odooName, _target]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(AppUser u) {
    _name.text = u.name;
    _email.text = u.email;
    _username.text = usernameOf(u.email) ?? '';
    _useUsername = _username.text.isNotEmpty;
    _phone.text = saudiMobileFieldText(u.phone);
    // An unknown role (from a newer app) is shown as sales exec; saving sets it.
    _role = u.role == UserRole.unknown ? UserRole.salesExec : u.role;
    _kamId = u.kamId;
    _managerId = u.managerId;
    _markedManager = u.markedManager;
    _supervisorId = u.supervisorId;
    _home = u.homeLocation;
    _joiningDate = u.joiningDate;
    _department = u.department;
    _active = u.active;
    _odooName.text = u.odooName;
    _target.text = u.monthlyTarget > 0 ? '${u.monthlyTarget}' : '';
    _position = u.position;
    _companyId = u.companyId;
    _sites = {...u.workSiteIds};
    _overtime = u.overtimeAllowed;
    _overtimeMax = u.overtimeMaxMin;
    _leaveSite = u.leaveSiteAllowed;
    _attendance = u.attendanceRequired;
    _schedule = u.workSchedule;
    _pending = u.isPendingApproval ? u : null;
    _savedRole = u.role;
    // Registered accounts have no role yet: the one they asked for, changeable before approving.
    if (_pending != null) _role = u.requestedRole ?? UserRole.worker;
    _loaded = true;
  }

  Future<void> _save({bool approve = false}) async {
    if (!_form.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final schedule = _needsAttendance ? _schedule : null;
    if (schedule != null && (schedule.days.isEmpty || schedule.endMinute <= schedule.startMinute)) {
      messenger.showSnackBar(SnackBar(content: Text(schedule.days.isEmpty ? l10n.pickWorkDays : l10n.endAfterStart)));
      return;
    }
    setState(() => _busy = true);
    final user = AppUser(
      id: widget.userId ?? '',
      name: _name.text.trim(),
      email: _useUsername ? loginEmailFor(_username.text) : _email.text.trim(),
      phone: saudiMobile(_phone.text) ?? '',
      role: _role!,
      kamId: _kamId,
      active: _active,
      odooName: _odooName.text.trim(),
      monthlyTarget: int.tryParse(_target.text.trim()) ?? 0,
      companyId: _companyId,
      position: _position,
      workSiteIds: _needsAttendance ? _sites.toList() : const [],
      overtimeAllowed: _overtime,
      overtimeMaxMin: _overtimeMax,
      attendanceRequired: _needsAttendance,
      leaveSiteAllowed: _needsAttendance ? _leaveSite ?? _roleOrDefault.leavesSiteForWork : null,
      workSchedule: schedule,
      managerId: _managerId,
      markedManager: _markedManager,
      supervisorId: _supervisorId,
      homeLocation: _home,
      joiningDate: _joiningDate,
      department: _department,
    );
    try {
      final repo = ref.read(usersRepositoryProvider);
      final assigned = _isNew
          ? await repo.create(user, _password.text)
          : approve
          ? await repo.approveRegistration(user)
          : await repo.update(user);
      messenger.showSnackBar(SnackBar(content: Text(assigned > 0 ? l10n.savedWithClients(assigned) : l10n.saved)));
      if (mounted) context.go('/users');
    } on EmailInUseException {
      messenger.showSnackBar(SnackBar(
        duration: const Duration(seconds: 8),
        content: Text(_useUsername ? l10n.usernameInUse : l10n.emailInUse),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        content: Text(l10n.rejectRegistrationConfirm(_name.text)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l10n.reject)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(usersRepositoryProvider).rejectRegistration(widget.userId!);
      messenger.showSnackBar(SnackBar(content: Text(l10n.registrationRejected)));
      if (mounted) context.go('/users');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.deleteUserTitle(_name.text)),
        content: Text(l10n.deleteUserBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(dialog).colorScheme.error),
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(usersRepositoryProvider).delete(widget.userId!);
      messenger.showSnackBar(SnackBar(content: Text(l10n.userDeleted)));
      if (mounted) context.go('/users');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final users = ref.watch(usersProvider).value ?? const [];
    final me = ref.watch(currentUserProvider).value;
    final roles = me?.role.editableRoles ?? const <UserRole>[];
    if (_isNew && _role != null && !roles.contains(_role)) _role = null;
    // Only one role to choose from: already picked.
    if (_isNew && roles.length == 1) _role ??= roles.first;
    if (!_isNew && !_loaded) {
      final existing = users.where((u) => u.id == widget.userId).firstOrNull;
      if (existing == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      _fill(existing);
    }
    // Logistics manager: workers, drivers, warehouse supervisors (also enforced by the rules).
    if (!_isNew && me != null && !me.role.isAdmin && !roles.contains(_savedRole)) {
      return Scaffold(appBar: AppBar(), body: Center(child: Text(l10n.noAccessTitle)));
    }
    final kams = users.where((u) => u.role == UserRole.kam && u.active).toList();
    final companies = ref.watch(companiesProvider).value ?? const <Company>[];
    final company = ref.watch(workHoursProvider).value ?? WorkHours.defaults;
    final sites = ref.watch(workSitesProvider).value ?? const <WorkSite>[];
    String? required(String? v) => (v == null || v.trim().isEmpty) ? l10n.required : null;
    // Usernames of the other accounts (checked again by Auth when saving).
    final taken = usernamesOf([for (final u in users) if (u.id != widget.userId) u.email]);
    final typedUsername = normalizeUsername(_username.text);
    final usernameTaken = _isNew && taken.contains(typedUsername);
    final usernameFree = _isNew && !usernameTaken && isValidUsername(typedUsername);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l10n.addUser : l10n.editUser),
        actions: [
          if (_canDelete(me))
            IconButton(icon: const Icon(Icons.delete_outline), tooltip: l10n.delete, onPressed: _busy ? null : _delete),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_pending != null)
              Card(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.hourglass_top),
                  title: Text(l10n.registrationPendingBanner),
                  subtitle: Text(l10n.registrationPendingHelp),
                ),
              ),
            TextFormField(
              controller: _name,
              decoration: InputDecoration(labelText: l10n.name),
              validator: required,
              // A new user's username follows the name until it's typed by hand.
              onChanged: (v) {
                if (_isNew && !_usernameEdited) setState(() => _username.text = suggestUsername(v, taken) ?? '');
              },
            ),
            if (_isNew) ...[
              const SizedBox(height: 12),
              Text(l10n.signInWith, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, icon: const Icon(Icons.email_outlined), label: Text(l10n.email)),
                  ButtonSegment(value: true, icon: const Icon(Icons.account_circle_outlined), label: Text(l10n.username)),
                ],
                selected: {_useUsername},
                onSelectionChanged: (v) => setState(() => _useUsername = v.first),
              ),
            ],
            if (_useUsername)
              TextFormField(
                controller: _username,
                enabled: _isNew,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l10n.username,
                  helperText: !_isNew
                      ? null
                      : usernameFree
                      ? l10n.usernameAvailable
                      : l10n.usernameHelp,
                  helperStyle: usernameFree ? const TextStyle(color: Colors.green) : null,
                  helperMaxLines: 2,
                  errorText: usernameTaken ? l10n.usernameTaken : null,
                  suffixIcon: usernameTaken
                      ? Icon(Icons.cancel, color: Theme.of(context).colorScheme.error, semanticLabel: l10n.usernameTaken)
                      : usernameFree
                      ? Icon(Icons.check_circle, color: Colors.green, semanticLabel: l10n.usernameAvailable)
                      : null,
                ),
                onChanged: (v) => setState(() => _usernameEdited = v.trim().isNotEmpty),
                validator: (v) => !_isNew
                    ? null
                    : !isValidUsername(v ?? '')
                    ? l10n.invalidUsername
                    : taken.contains(normalizeUsername(v!))
                    ? l10n.usernameTaken
                    : null,
              )
            else
              TextFormField(
                controller: _email,
                enabled: _isNew,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: l10n.email),
                validator: (v) => (v == null || !v.contains('@'))
                    ? l10n.invalidEmail
                    : _isNew && usernameOf(v) != null
                    ? l10n.reservedEmail
                    : null,
              ),
            if (_isNew)
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(labelText: l10n.password),
                validator: (v) => (v == null || v.length < 6) ? l10n.passwordTooShort : null,
              ),
            SaudiPhoneField(controller: _phone),
            DropdownButtonFormField<String>(
              initialValue: companies.any((c) => c.id == _companyId) ? _companyId : '',
              decoration: InputDecoration(labelText: l10n.company),
              items: [
                DropdownMenuItem(value: '', child: Text(l10n.none)),
                for (final c in companies) DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() => _companyId = v ?? ''),
            ),
            DepartmentField(
              value: _department,
              role: _role ?? UserRole.worker,
              onChanged: (v) => setState(() => _department = v),
            ),
            JoiningDateField(value: _joiningDate, onChanged: (v) => setState(() => _joiningDate = v)),
            const SizedBox(height: 16),
            DropdownButtonFormField<UserRole>(
              initialValue: _role,
              decoration: InputDecoration(labelText: l10n.role),
              items: [
                for (final r in _role == null || roles.contains(_role) ? roles : [_role!, ...roles])
                  DropdownMenuItem(value: r, child: Text(r.label(l10n))),
              ],
              hint: Text(l10n.selectRole),
              validator: (r) => r == null ? l10n.required : null,
              onChanged: (r) => setState(() => _role = r),
            ),
            if (_role == UserRole.salesExec)
              DropdownButtonFormField<String?>(
                initialValue: kams.any((k) => k.id == _kamId) ? _kamId : null,
                decoration: InputDecoration(labelText: l10n.keyAccountManager),
                items: [
                  DropdownMenuItem(value: null, child: Text(l10n.none)),
                  for (final k in kams) DropdownMenuItem(value: k.id, child: Text(k.name)),
                ],
                onChanged: (id) => setState(() => _kamId = id),
              ),
            // Managers: by role, or marked here (e.g. the accounting manager).
            if (_role != null && !_role!.isManagerRole && me?.role.isAdmin == true)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.isManager),
                subtitle: Text(l10n.isManagerHelp),
                value: _markedManager,
                onChanged: (v) => setState(() => _markedManager = v),
              ),
            if (_role != null)
              Builder(builder: (context) {
                // Who it is when left on automatic, for the label.
                final auto = directManagersOf(
                  AppUser(id: widget.userId ?? '', name: '', email: '', phone: '', role: _role!, kamId: _kamId, active: true),
                  users,
                );
                final names = {for (final u in users) u.id: u.name};
                final managers = [for (final u in users) if (u.active && u.isManager && u.id != widget.userId) u];
                return DropdownButtonFormField<String?>(
                  initialValue: managers.any((m) => m.id == _managerId) ? _managerId : null,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.directManager, helperText: l10n.directManagerHelp, helperMaxLines: 2),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(l10n.directManagerAuto(auto.map((id) => names[id] ?? '').join(', ')), overflow: TextOverflow.ellipsis),
                    ),
                    for (final m in managers)
                      DropdownMenuItem(value: m.id, child: Text('${m.name} · ${m.role.label(l10n)}', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (id) => setState(() => _managerId = id),
                );
              }),
            // Drivers: the warehouse supervisor who follows them (their
            // direct manager stays the logistics manager).
            if (_role == UserRole.driver)
              Builder(builder: (context) {
                final supervisors = [for (final u in users) if (u.active && u.role == UserRole.warehouseSupervisor) u];
                return DropdownButtonFormField<String?>(
                  initialValue: supervisors.any((u) => u.id == _supervisorId) ? _supervisorId : null,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.roleWarehouseSupervisor),
                  items: [
                    DropdownMenuItem(value: null, child: Text(l10n.none)),
                    for (final u in supervisors) DropdownMenuItem(value: u.id, child: Text(u.name)),
                  ],
                  onChanged: (id) => setState(() => _supervisorId = id),
                );
              }),
            // Drivers: home, where their overtime ends (2026-10-25).
            if (_role == UserRole.driver)
              HomeLocationField(value: _home, onChanged: (v) => setState(() => _home = v)),
            // KAMs too: some Odoo clients are under a KAM until they're moved to the team.
            if (_role?.isTracked == true)
              TextFormField(
                controller: _odooName,
                decoration: InputDecoration(labelText: l10n.odooSalespersonName, helperText: l10n.odooSalespersonHelp),
              ),
            if (_role?.isTracked == true)
              TextFormField(
                controller: _target,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.monthlyVisitTarget, helperText: l10n.monthlyVisitTargetHelp),
                validator: (v) => (v == null || v.trim().isEmpty || int.tryParse(v.trim()) != null) ? null : l10n.invalidNumber,
              ),
            // When their location is shared; saved at once (App settings → Tracking schedules).
            // RTDB settings: sales manager / GM only.
            if (_role?.isLocationTracked == true && !_isNew && _pending == null && me?.role.isAdmin == true)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.edit_calendar_outlined),
                title: Text(l10n.trackingHours),
                subtitle: Text(trackingScheduleSummary(
                  context,
                  ref.watch(trackingSchedulesProvider).value?[widget.userId] ?? const TrackingSchedule.standard(),
                  company,
                  driver: _role!.isDriver,
                )),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showTrackingScheduleDialog(
                  context,
                  uid: widget.userId!,
                  name: _name.text,
                  driver: _role!.isDriver,
                  current: ref.read(trackingSchedulesProvider).value?[widget.userId],
                  company: company,
                ),
              ),
            // Attendance: required or not, where they check in, and whether time after the work day counts.
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.attendanceRequired),
              subtitle: Text(l10n.attendanceRequiredHelp),
              value: _needsAttendance,
              onChanged: (v) => setState(() => _attendance = v),
            ),
            if (_needsAttendance) ...[
              Text(l10n.workSites, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              if (sites.isEmpty)
                Text(l10n.noWorkSites, style: Theme.of(context).textTheme.bodySmall)
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in sites)
                      FilterChip(
                        avatar: const Icon(Icons.apartment, size: 16),
                        label: Text(s.name),
                        selected: _sites.contains(s.id),
                        onSelected: (on) => setState(() => on ? _sites.add(s.id) : _sites.remove(s.id)),
                      ),
                  ],
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.leaveSiteAllowed),
                subtitle: Text((_leaveSite ?? _roleOrDefault.leavesSiteForWork)
                    ? l10n.leaveSiteAllowedHelp
                    : l10n.leaveSiteNotAllowedHelp(ref.watch(appSettingsProvider).value?[AppSetting.awayGraceMin] ??
                        AppSetting.awayGraceMin.defaultValue)),
                value: _leaveSite ?? _roleOrDefault.leavesSiteForWork,
                onChanged: (v) => setState(() => _leaveSite = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.overtimeAllowed),
                subtitle: Text(l10n.overtimeAllowedHelp),
                value: _overtime,
                onChanged: (v) => setState(() => _overtime = v),
              ),
              // Cap a day (user decision 2026-10-24): 3 hours unless set higher here.
              if (_overtime)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.overtimeMax),
                  subtitle: Text(l10n.overtimeMaxHelp),
                  trailing: DropdownButton<int>(
                    value: _overtimeMax ?? defaultOvertimeMaxMin,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final h in [1, 2, 3, 4, 5, 6, 8, 10, 12])
                        DropdownMenuItem(value: h * 60, child: Text(l10n.hoursCount(h))),
                    ],
                    onChanged: (v) => setState(() => _overtimeMax = v == defaultOvertimeMaxMin ? null : v),
                  ),
                ),
              // Their own days / hours; off = the company work hours.
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.ownWorkSchedule),
                subtitle: Text(_schedule == null
                    ? l10n.companyWorkHoursNote(WorkHoursEditor.summary(context, company))
                    : l10n.ownWorkScheduleHelp),
                value: _schedule != null,
                onChanged: (v) => setState(() => _schedule = v ? company : null),
              ),
              if (_schedule != null) ...[
                WorkHoursEditor(value: _schedule!, onChanged: (v) => setState(() => _schedule = v)),
                const SizedBox(height: 8),
              ],
            ],
            if (_pending == null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.active),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
            const SizedBox(height: 16),
            if (_pending != null)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(onPressed: _busy ? null : _reject, icon: const Icon(Icons.close), label: Text(l10n.reject)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : () => _save(approve: true),
                      icon: busyIcon(_busy, const Icon(Icons.check)),
                      label: Text(l10n.approve),
                    ),
                  ),
                ],
              )
            else
              FilledButton(
                onPressed: _busy ? null : _save,
                child: BusyLabel(busy: _busy, child: Text(l10n.save)),
              ),
            if (_canSetPassword(me)) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : _setPassword,
                icon: const Icon(Icons.password),
                label: Text(l10n.setPassword),
              ),
            ],
            if (_canDelete(me)) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                onPressed: _busy ? null : _delete,
                icon: const Icon(Icons.delete_outline),
                label: Text(l10n.deleteUser),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
