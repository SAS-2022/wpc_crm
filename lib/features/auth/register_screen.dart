import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/login_name.dart';
import '../../core/saudi_phone.dart';
import '../../core/saving.dart';
import '../../l10n/app_localizations.dart';
import '../users/companies.dart';
import '../../core/app_user.dart';

/// Self-registration for people without a company account (user request
/// 2026-10-19): name, phone, position and company, plus email and password.
/// The account is created inactive and pending; the sales manager / GM are
/// notified (`registrationRequested` Cloud Function) and approve it, setting
/// the role. Until then the app shows "Waiting for approval".
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _companyId;
  /// The job asked for, saved as a role value in `position` (see
  /// [AppUser.requestedRole]); the admin confirms it on approval.
  UserRole? _role;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await saving(() async {
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
        await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
          'name': _name.text.trim(),
          'email': _email.text.trim(),
          'phone': saudiMobile(_phone.text) ?? '',
          'position': _role?.value,
          'companyId': _companyId,
          'role': '',
          'active': false,
          'approval': 'pending',
          'registeredAt': FieldValue.serverTimestamp(),
        });
      });
      // The router now shows "Waiting for approval".
    } on FirebaseAuthException catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(switch (e.code) {
          'email-already-in-use' => l10n.registerEmailInUse,
          'invalid-email' => l10n.invalidEmail,
          'weak-password' => l10n.passwordTooShort,
          _ => l10n.errorWithMessage(e.message ?? e.code),
        }),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final companies = [for (final c in ref.watch(companiesProvider).value ?? const <Company>[]) if (c.active) c];
    String? required(String? v) => (v == null || v.trim().isEmpty) ? l10n.required : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.createAccount),
        leading: BackButton(onPressed: () => context.go('/login')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(l10n.registerHelp, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: l10n.name),
                  validator: required,
                ),
                SaudiPhoneField(controller: _phone, required: true),
                DropdownButtonFormField<UserRole>(
                  initialValue: _role,
                  decoration: InputDecoration(labelText: l10n.position),
                  items: [for (final r in UserRole.registrable) DropdownMenuItem(value: r, child: Text(r.label(l10n)))],
                  onChanged: (v) => setState(() => _role = v),
                  validator: (v) => v == null ? l10n.required : null,
                ),
                DropdownButtonFormField<String>(
                  initialValue: _companyId,
                  decoration: InputDecoration(labelText: l10n.company),
                  items: [for (final c in companies) DropdownMenuItem(value: c.id, child: Text(c.name))],
                  onChanged: (v) => setState(() => _companyId = v),
                  validator: (v) => v == null ? l10n.required : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(labelText: l10n.email),
                  // The username accounts' hidden domain is not for registering.
                  validator: (v) => (v == null || !v.contains('@'))
                      ? l10n.invalidEmail
                      : usernameOf(v) != null
                      ? l10n.reservedEmail
                      : null,
                ),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: InputDecoration(labelText: l10n.password),
                  validator: (v) => (v == null || v.length < 6) ? l10n.passwordTooShort : null,
                ),
                TextFormField(
                  controller: _confirm,
                  obscureText: true,
                  decoration: InputDecoration(labelText: l10n.confirmPassword),
                  validator: (v) => v != _password.text ? l10n.passwordsDontMatch : null,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: BusyLabel(busy: _busy, child: Text(l10n.createAccount)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
