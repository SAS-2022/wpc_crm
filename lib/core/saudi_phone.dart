import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';

/// Staff phone numbers are Saudi mobiles only (user decision 2026-10-31):
/// the user form, registration and Profile take 5X XXX XXXX after a fixed
/// +966 and save "+9665XXXXXXXX". Typed or pasted 05…, 9665…, +9665… and
/// 009665… (Arabic digits too) are read the same.

const saudiPrefix = '+966';

/// The 9 digits after +966 ("5XXXXXXXX"), or null when [raw] isn't a Saudi mobile.
String? saudiMobileDigits(String raw) {
  var d = _westernDigits(raw).replaceAll(RegExp(r'[^0-9]'), '');
  if (d.startsWith('00966')) {
    d = d.substring(5);
  } else if (d.startsWith('966')) {
    d = d.substring(3);
  }
  if (d.startsWith('0')) d = d.substring(1);
  return RegExp(r'^5[0-9]{8}$').hasMatch(d) ? d : null;
}

/// "+9665XXXXXXXX" for a Saudi mobile, else null.
String? saudiMobile(String raw) {
  final d = saudiMobileDigits(raw);
  return d == null ? null : '$saudiPrefix$d';
}

/// What the field shows for a stored number: the 9 digits when it is a
/// Saudi mobile, otherwise the old value as it is (the form then asks to fix it).
String saudiMobileFieldText(String stored) => saudiMobileDigits(stored) ?? stored;

String _westernDigits(String s) => s.replaceAllMapped(
      RegExp('[٠-٩۰-۹]'),
      (m) {
        final c = m[0]!.codeUnitAt(0);
        return '${c >= 0x06F0 ? c - 0x06F0 : c - 0x0660}';
      },
    );

/// Phone field with a fixed +966; [required] refuses an empty value, else
/// empty is allowed. Save with `saudiMobile(controller.text) ?? ''`.
class SaudiPhoneField extends StatelessWidget {
  const SaudiPhoneField({super.key, required this.controller, this.required = false});

  final TextEditingController controller;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      textDirection: TextDirection.ltr,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩۰-۹+ ]'))],
      decoration: InputDecoration(
        labelText: l10n.phone,
        prefixText: '$saudiPrefix ',
        hintText: '5X XXX XXXX',
        hintTextDirection: TextDirection.ltr,
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return required ? l10n.required : null;
        return saudiMobileDigits(v) == null ? l10n.saudiPhoneInvalid : null;
      },
    );
  }
}
