import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/login_name.dart';
import '../../core/saudi_phone.dart';
import '../../core/password_field.dart';
import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import 'users_repository.dart';
import '../../core/app_version.dart';
import 'package:flutter/foundation.dart';

/// The signed-in user's own page: name and phone, password change (with the
/// current password) or a reset link by email. Email, role, KAM and target
/// are set by sales managers / GM in Users.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _infoForm = GlobalKey<FormState>();
  final _passwordForm = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  String? _loadedFor;
  bool _savingInfo = false;
  bool _savingPassword = false;
  bool _sendingReset = false;
  String? _currentError;

  @override
  void dispose() {
    for (final c in [_name, _phone, _current, _new, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveInfo(AppUser me) async {
    if (!_infoForm.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _savingInfo = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(me.id).update({
        'name': _name.text.trim(),
        'phone': saudiMobile(_phone.text) ?? '',
      });
      messenger.showSnackBar(SnackBar(content: Text(l10n.saved)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    } finally {
      if (mounted) setState(() => _savingInfo = false);
    }
  }

  Future<void> _changePassword(String email) async {
    setState(() => _currentError = null);
    if (!_passwordForm.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _savingPassword = true);
    try {
      // Firebase asks for a recent sign-in before a password change.
      await user.reauthenticateWithCredential(EmailAuthProvider.credential(email: email, password: _current.text));
      await user.updatePassword(_new.text);
      for (final c in [_current, _new, _confirm]) {
        c.clear();
      }
      messenger.showSnackBar(SnackBar(content: Text(l10n.passwordChanged)));
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password' || 'invalid-credential' || 'invalid-login-credentials':
          setState(() => _currentError = l10n.wrongCurrentPassword);
        case 'weak-password':
          messenger.showSnackBar(SnackBar(content: Text(l10n.passwordTooShort)));
        case 'too-many-requests':
          messenger.showSnackBar(SnackBar(content: Text(l10n.tooManyAttempts)));
        default:
          messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage(e.message ?? e.code))));
      }
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  Future<void> _sendReset(String email) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sendingReset = true);
    try {
      await FirebaseAuth.instance.setLanguageCode(Localizations.localeOf(context).languageCode);
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      messenger.showSnackBar(SnackBar(content: Text(l10n.resetEmailSent(email))));
    } on FirebaseAuthException catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(e.code == 'too-many-requests' ? l10n.tooManyAttempts : l10n.errorWithMessage(e.message ?? e.code)),
      ));
    } finally {
      if (mounted) setState(() => _sendingReset = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final me = ref.watch(currentUserProvider).value;
    if (me == null) return const SizedBox.shrink();
    if (_loadedFor != me.id) {
      _loadedFor = me.id;
      _name.text = me.name;
      _phone.text = saudiMobileFieldText(me.phone);
    }
    final users = ref.watch(usersProvider).value ?? const <AppUser>[];
    final kam = users.where((u) => u.id == me.kamId).firstOrNull;
    String? required(String? v) => (v == null || v.trim().isEmpty) ? l10n.required : null;
    final email = FirebaseAuth.instance.currentUser?.email ?? me.email;
    // Username accounts: no mailbox, so no reset email.
    final username = usernameOf(email);

    Widget busy(bool on, String label) => on
        ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
        : Text(label);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profile)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _infoForm,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(l10n.personalInfo, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _name,
                          decoration: InputDecoration(labelText: l10n.name),
                          textCapitalization: TextCapitalization.words,
                          validator: required,
                        ),
                        const SizedBox(height: 12),
                        SaudiPhoneField(controller: _phone),
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(username != null ? Icons.account_circle_outlined : Icons.email_outlined),
                          title: Text(username ?? email),
                          subtitle: Text(username != null ? l10n.username : l10n.email),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.badge_outlined),
                          title: Text(me.role.label(l10n)),
                          subtitle: Text(l10n.role),
                        ),
                        if (kam != null)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.supervisor_account_outlined),
                            title: Text(kam.name),
                            subtitle: Text(l10n.roleKam),
                          ),
                        // Installed app version; on a phone behind the newest build, a way to update.
                        Builder(builder: (context) {
                          final info = ref.watch(packageInfoProvider).value;
                          if (info == null) return const SizedBox.shrink();
                          final own = ref.watch(ownBuildProvider);
                          final latest = latestBuild(ref.watch(usersProvider).value ?? const <AppUser>[], own);
                          final behind = !kIsWeb && own < latest;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.info_outline, color: behind ? theme.colorScheme.error : null),
                            title: Text('${info.version} (${info.buildNumber})'),
                            subtitle: Text(behind ? l10n.newerVersionAvailable : l10n.appVersion),
                            trailing: behind
                                ? FilledButton.tonal(onPressed: openAppStore, child: Text(l10n.updateApp))
                                : null,
                          );
                        }),
                        Text(l10n.emailChangeByAdmin, style: theme.textTheme.bodySmall),
                        const SizedBox(height: 12),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: FilledButton(
                            onPressed: _savingInfo ? null : () => _saveInfo(me),
                            child: busy(_savingInfo, l10n.save),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _passwordForm,
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(l10n.changePassword, style: theme.textTheme.titleMedium),
                          const SizedBox(height: 12),
                          PasswordField(
                            controller: _current,
                            label: l10n.currentPassword,
                            errorText: _currentError,
                            validator: (v) => (v == null || v.isEmpty) ? l10n.required : null,
                          ),
                          const SizedBox(height: 12),
                          PasswordField(
                            controller: _new,
                            label: l10n.newPassword,
                            autofillHints: const [AutofillHints.newPassword],
                            validator: (v) => (v == null || v.length < 6) ? l10n.passwordTooShort : null,
                          ),
                          const SizedBox(height: 12),
                          PasswordField(
                            controller: _confirm,
                            label: l10n.confirmNewPassword,
                            autofillHints: const [AutofillHints.newPassword],
                            validator: (v) => v != _new.text ? l10n.passwordsDontMatch : null,
                            onSubmitted: (_) => _changePassword(email),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: FilledButton(
                              onPressed: _savingPassword ? null : () => _changePassword(email),
                              child: busy(_savingPassword, l10n.changePassword),
                            ),
                          ),
                          const Divider(height: 32),
                          if (username != null)
                            Text(l10n.usernameAccountInfo, style: theme.textTheme.bodySmall)
                          else ...[
                            Text(l10n.resetPasswordByEmail, style: theme.textTheme.titleSmall),
                            const SizedBox(height: 4),
                            Text(l10n.resetPasswordInfo, style: theme.textTheme.bodySmall),
                            const SizedBox(height: 8),
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.mail_outline),
                                onPressed: _sendingReset ? null : () => _sendReset(email),
                                label: busy(_sendingReset, l10n.sendResetLink),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
