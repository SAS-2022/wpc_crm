import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';

/// Staff phone numbers are Saudi mobiles only (user decision 2026-10-31):
/// the user form, registration and Profile take 05X XXX XXXX (10 digits, no
/// more can be typed) and save "+9665XXXXXXXX". Pasted 9665…, +9665… and
/// 009665… (Arabic digits too) are turned into 05… in the field.

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

/// What the field shows for a stored number: 05XXXXXXXX when it is a Saudi
/// mobile, otherwise the old value as it is (the form then asks to fix it).
String saudiMobileFieldText(String stored) {
  final d = saudiMobileDigits(stored);
  return d == null ? stored : '0$d';
}

/// The field's text as it is typed: digits only, a country code dropped,
/// a leading 5 gets its 0, at most 10 digits.
String saudiMobileInput(String raw) {
  var d = _westernDigits(raw).replaceAll(RegExp(r'[^0-9]'), '');
  if (d.startsWith('00966')) {
    d = d.substring(5);
  } else if (d.startsWith('966')) {
    d = d.substring(3);
  }
  if (d.startsWith('5')) d = '0$d';
  return d.length > 10 ? d.substring(0, 10) : d;
}

class _SaudiMobileFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final t = saudiMobileInput(newValue.text);
    if (t == newValue.text) return newValue;
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}

String _westernDigits(String s) => s.replaceAllMapped(
      RegExp('[٠-٩۰-۹]'),
      (m) {
        final c = m[0]!.codeUnitAt(0);
        return '${c >= 0x06F0 ? c - 0x06F0 : c - 0x0660}';
      },
    );

/// Saudi mobile field (05X XXX XXXX); [required] refuses an empty value, else
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
      inputFormatters: [_SaudiMobileFormatter()],
      decoration: InputDecoration(
        labelText: l10n.phone,
        hintText: '05X XXX XXXX',
        hintTextDirection: TextDirection.ltr,
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return required ? l10n.required : null;
        return saudiMobileDigits(v) == null ? l10n.saudiPhoneInvalid : null;
      },
    );
  }
}
