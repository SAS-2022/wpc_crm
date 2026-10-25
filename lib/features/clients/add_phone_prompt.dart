import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'client.dart';
import 'clients_repository.dart';

// Visiting or logging a call for a client with no number (user decisions
// 2026-10-24): the visit / call is saved only after the salesperson adds one — typed, or on phones picked from
// the phone's contacts with the system picker (no contacts permission: only
// the chosen number reaches the app). Cancel = nothing is saved.

/// Digits and a leading + only ("050 123 4567" → "0501234567").
String cleanPhoneNumber(String raw) {
  final t = raw.trim();
  final digits = t.replaceAll(RegExp(r'[^0-9]'), '');
  final international = t.startsWith('+') || (t.startsWith('00') && digits.length > 2);
  return international ? '+${digits.replaceFirst(RegExp('^00'), '')}' : digits;
}

/// A plausible phone number: 7 to 15 digits.
bool isPhoneNumber(String raw) {
  final n = cleanPhoneNumber(raw).replaceAll('+', '').length;
  return n >= 7 && n <= 15;
}

/// Shows the form; true when a number was saved (then the visit / call may be saved).
Future<bool> showAddPhonePrompt(BuildContext context, Client client, {bool call = false}) async =>
    await showDialog<bool>(context: context, builder: (_) => _AddPhoneDialog(client: client, call: call)) ?? false;

class _AddPhoneDialog extends ConsumerStatefulWidget {
  const _AddPhoneDialog({required this.client, required this.call});

  final Client client;
  final bool call;

  @override
  ConsumerState<_AddPhoneDialog> createState() => _AddPhoneDialogState();
}

class _AddPhoneDialogState extends ConsumerState<_AddPhoneDialog> {
  late final _name = TextEditingController(text: widget.client.contactPerson);
  final _number = TextEditingController();
  final _form = GlobalKey<FormState>();
  var _busy = false;

  static bool get _phone => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    try {
      final c = await FlutterNativeContactPicker().selectPhoneNumber();
      final number = c?.selectedPhoneNumber ?? c?.phoneNumbers?.firstOrNull;
      if (c == null || number == null) return;
      setState(() {
        _number.text = cleanPhoneNumber(number);
        if (_name.text.trim().isEmpty) _name.text = c.fullName?.trim() ?? '';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).errorWithMessage('$e'))));
      }
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final name = _name.text.trim();
    try {
      await ref.read(clientsRepositoryProvider).update(widget.client.id, {
        'mobile': cleanPhoneNumber(_number.text),
        if (name.isNotEmpty && name != widget.client.contactPerson) 'contactPerson': name,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).errorWithMessage('$e'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      icon: const Icon(Icons.contact_phone_outlined),
      title: Text(l10n.addPhoneTitle),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(widget.call ? l10n.addPhoneMessageCall(widget.client.name) : l10n.addPhoneMessage(widget.client.name)),
            const SizedBox(height: 16),
            if (_phone) ...[
              OutlinedButton.icon(
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.contacts_outlined),
                label: Text(l10n.pickFromContacts),
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _number,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(labelText: l10n.mobile, prefixIcon: const Icon(Icons.phone)),
              validator: (v) => isPhoneNumber(v ?? '') ? null : l10n.phoneNumberInvalid,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l10n.contactPerson, prefixIcon: const Icon(Icons.person_outline)),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: Text(l10n.cancel)),
        FilledButton(onPressed: _busy ? null : _save, child: Text(l10n.saveAndContinue)),
      ],
    );
  }
}
