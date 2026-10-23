import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// A password field with an eye button that shows / hides what was typed
/// (2026-10-23, login and Profile). Hidden by default.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.errorText,
    this.validator,
    this.onSubmitted,
    this.autofillHints = const [AutofillHints.password],
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String> autofillHints;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _shown = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextFormField(
      controller: widget.controller,
      obscureText: !_shown,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: widget.autofillHints,
      validator: widget.validator,
      onFieldSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: widget.errorText,
        suffixIcon: IconButton(
          icon: Icon(_shown ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          tooltip: _shown ? l10n.hidePassword : l10n.showPassword,
          onPressed: () => setState(() => _shown = !_shown),
        ),
      ),
    );
  }
}
