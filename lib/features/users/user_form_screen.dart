import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import 'users_repository.dart';
import '../../core/saving.dart';
import '../attendance/work_sites.dart';
import '../tracking/work_hours.dart';
import '../tracking/work_hours_editor.dart';
import 'companies.dart';
import '../clients/client_tags.dart';

/// Create (userId == null) or edit a user. Only reachable by sales manager / GM.
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
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _odooName = TextEditingController();
  final _target = TextEditingController();
  UserRole _role = UserRole.salesExec;
  String _companyId = '';
  String _position = '';
  Set<String> _sites = {};
  bool _overtime = false;

  /// Null until set here or saved: follows the role (see [AppUser.needsAttendance]).
  bool? _attendance;

  /// Their own work days / hours; null = the company work hours.
  WorkHours? _schedule;
  bool get _needsAttendance => _attendance ?? AppUser.defaultAttendance(_role, _sites.toList());

  /// A self-registered account waiting for approval.
  AppUser? _pending;
  String? _kamId;
  bool _active = true;
  bool _loaded = false;
  bool _busy = false;

  bool get _isNew => widget.userId == null;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _password, _odooName, _target]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(AppUser u) {
    _name.text = u.name;
    _email.text = u.email;
    _phone.text = u.phone;
    // An unknown role (from a newer app) is shown as sales exec; saving sets it.
    _role = u.role == UserRole.unknown ? UserRole.salesExec : u.role;
    _kamId = u.kamId;
    _active = u.active;
    _odooName.text = u.odooName;
    _target.text = u.monthlyTarget > 0 ? '${u.monthlyTarget}' : '';
    _position = u.position;
    _companyId = u.companyId;
    _sites = {...u.workSiteIds};
    _overtime = u.overtimeAllowed;
    _attendance = u.attendanceRequired;
    _schedule = u.workSchedule;
    _pending = u.isPendingApproval ? u : null;
    // Registered accounts have no role yet: pick one before approving.
    if (_pending != null) _role = UserRole.worker;
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
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      role: _role,
      kamId: _kamId,
      active: _active,
      odooName: _odooName.text.trim(),
      monthlyTarget: int.tryParse(_target.text.trim()) ?? 0,
      companyId: _companyId,
      position: _position,
      workSiteIds: _needsAttendance ? _sites.toList() : const [],
      overtimeAllowed: _overtime,
      attendanceRequired: _needsAttendance,
      workSchedule: schedule,
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
      messenger.showSnackBar(SnackBar(duration: const Duration(seconds: 8), content: Text(l10n.emailInUse)));
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
    if (!_isNew && !_loaded) {
      final existing = users.where((u) => u.id == widget.userId).firstOrNull;
      if (existing == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      _fill(existing);
    }
    final kams = users.where((u) => u.role == UserRole.kam && u.active).toList();
    final companies = ref.watch(companiesProvider).value ?? const <Company>[];
    final company = ref.watch(workHoursProvider).value ?? WorkHours.defaults;
    final positions = ref.watch(tagListProvider(TagList.positions)).value ?? defaultPositions;
    final lang = Localizations.localeOf(context).languageCode;
    final sites = ref.watch(workSitesProvider).value ?? const <WorkSite>[];
    String? required(String? v) => (v == null || v.trim().isEmpty) ? l10n.required : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l10n.addUser : l10n.editUser),
        actions: [
          // Only the GM deletes users, and never themselves.
          if (!_isNew &&
              ref.watch(currentUserProvider).value?.role == UserRole.gm &&
              widget.userId != ref.watch(currentUserProvider).value?.id)
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
            ),
            TextFormField(
              controller: _email,
              enabled: _isNew,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: l10n.email),
              validator: (v) => (v == null || !v.contains('@')) ? l10n.invalidEmail : null,
            ),
            if (_isNew)
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(labelText: l10n.password),
                validator: (v) => (v == null || v.length < 6) ? l10n.passwordTooShort : null,
              ),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: l10n.phone),
            ),
            DropdownButtonFormField<String>(
              initialValue: _position,
              decoration: InputDecoration(labelText: l10n.position),
              items: [
                DropdownMenuItem(value: '', child: Text(l10n.none)),
                for (final p in positions) DropdownMenuItem(value: p.id, child: Text(p.label(lang))),
                // Typed before positions became a list: kept until changed.
                if (_position.isNotEmpty && !positions.any((p) => p.id == _position))
                  DropdownMenuItem(value: _position, child: Text(_position)),
              ],
              onChanged: (v) => setState(() => _position = v ?? ''),
            ),
            DropdownButtonFormField<String>(
              initialValue: companies.any((c) => c.id == _companyId) ? _companyId : '',
              decoration: InputDecoration(labelText: l10n.company),
              items: [
                DropdownMenuItem(value: '', child: Text(l10n.none)),
                for (final c in companies) DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() => _companyId = v ?? ''),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<UserRole>(
              initialValue: _role,
              decoration: InputDecoration(labelText: l10n.role),
              items: [for (final r in UserRole.assignable) DropdownMenuItem(value: r, child: Text(r.label(l10n)))],
              onChanged: (r) => setState(() => _role = r!),
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
            // KAMs too: some Odoo clients are under a KAM until they're moved to the team.
            if (_role.isTracked)
              TextFormField(
                controller: _odooName,
                decoration: InputDecoration(labelText: l10n.odooSalespersonName, helperText: l10n.odooSalespersonHelp),
              ),
            if (_role.isTracked)
              TextFormField(
                controller: _target,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.monthlyVisitTarget, helperText: l10n.monthlyVisitTargetHelp),
                validator: (v) => (v == null || v.trim().isEmpty || int.tryParse(v.trim()) != null) ? null : l10n.invalidNumber,
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
                title: Text(l10n.overtimeAllowed),
                subtitle: Text(l10n.overtimeAllowedHelp),
                value: _overtime,
                onChanged: (v) => setState(() => _overtime = v),
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
          ],
        ),
      ),
    );
  }
}
