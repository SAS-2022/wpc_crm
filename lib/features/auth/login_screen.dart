import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/language_button.dart';
import '../../core/text_input_dialog.dart';
import '../../l10n/app_localizations.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _failed = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on FirebaseAuthException {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Emails a reset link. The answer is the same whether or not the address
  /// has an account, so the screen doesn't reveal who has one.
  Future<void> _forgotPassword() async {
    final l10n = AppLocalizations.of(context);
    final email = await showTextInputDialog(
      context,
      title: l10n.forgotPassword,
      label: l10n.email,
      initialText: _email.text.trim(),
      confirmLabel: l10n.sendResetLink,
      maxLines: 1,
    );
    if (email == null || !email.trim().contains('@') || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseAuth.instance.setLanguageCode(Localizations.localeOf(context).languageCode);
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'too-many-requests') {
        messenger.showSnackBar(SnackBar(content: Text(l10n.tooManyAttempts)));
        return;
      }
      if (e.code == 'invalid-email') {
        messenger.showSnackBar(SnackBar(content: Text(l10n.invalidEmail)));
        return;
      }
    }
    messenger.showSnackBar(SnackBar(content: Text(l10n.resetEmailSentIfExists)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(actions: const [LanguageButton()]),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset('assets/images/Regular.png', height: 96, semanticLabel: l10n.appTitle),
                  const SizedBox(height: 16),
                  Text(
                    l10n.appTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: InputDecoration(labelText: l10n.email),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(labelText: l10n.password),
                    onSubmitted: (_) => _signIn(),
                  ),
                  if (_failed) ...[
                    const SizedBox(height: 12),
                    Text(
                      l10n.signInFailed,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _signIn,
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.signIn),
                  ),
                  const SizedBox(height: 8),
                  TextButton(onPressed: _busy ? null : _forgotPassword, child: Text(l10n.forgotPassword)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
