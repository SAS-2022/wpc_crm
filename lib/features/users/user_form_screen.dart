import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import 'users_repository.dart';

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
    _role = u.role;
    _kamId = u.kamId;
    _active = u.active;
    _odooName.text = u.odooName;
    _target.text = u.monthlyTarget > 0 ? '${u.monthlyTarget}' : '';
    _loaded = true;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
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
    );
    try {
      final repo = ref.read(usersRepositoryProvider);
      final assigned = _isNew ? await repo.create(user, _password.text) : await repo.update(user);
      messenger.showSnackBar(SnackBar(
        content: Text(assigned > 0 ? l10n.savedWithClients(assigned) : l10n.saved),
      ));
      if (mounted) context.go('/users');
    } on EmailInUseException {
      messenger.showSnackBar(SnackBar(
        duration: const Duration(seconds: 8),
        content: Text(l10n.emailInUse),
      ));
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
    String? required(String? v) => (v == null || v.trim().isEmpty) ? l10n.required : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l10n.addUser : l10n.editUser),
        actions: [
          // Only the GM deletes users, and never themselves.
          if (!_isNew &&
              ref.watch(currentUserProvider).value?.role == UserRole.gm &&
              widget.userId != ref.watch(currentUserProvider).value?.id)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.delete,
              onPressed: _busy ? null : _delete,
            ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
            const SizedBox(height: 16),
            DropdownButtonFormField<UserRole>(
              initialValue: _role,
              decoration: InputDecoration(labelText: l10n.role),
              items: [
                for (final r in UserRole.values)
                  DropdownMenuItem(value: r, child: Text(r.label(l10n))),
              ],
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
            if (_role == UserRole.salesExec)
              TextFormField(
                controller: _odooName,
                decoration: InputDecoration(
                  labelText: l10n.odooSalespersonName,
                  helperText: l10n.odooSalespersonHelp,
                ),
              ),
            if (_role.isTracked)
              TextFormField(
                controller: _target,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.monthlyVisitTarget, helperText: l10n.monthlyVisitTargetHelp),
                validator: (v) => (v == null || v.trim().isEmpty || int.tryParse(v.trim()) != null) ? null : l10n.invalidNumber,
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.active),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}
