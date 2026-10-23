import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../../l10n/app_localizations.dart';

/// How a manual check-in / check-out was confirmed, saved on the event as
/// `verified`: 'device' = fingerprint / face / screen-lock PIN, 'none' = the
/// phone has no screen lock, so nothing could be asked.
typedef IdentityCheck = String;

/// Fingerprint / face (or the screen-lock PIN) before the Check in / Check
/// out buttons record anything (user request 2026-10-22). A phone without
/// any screen lock isn't blocked (user decision 2026-10-22): the event is
/// marked 'none'. Returns null when the person cancelled or failed, or the
/// phone is locked out. Automatic check-ins at the site aren't asked.
Future<IdentityCheck?> confirmIdentity(BuildContext context) async {
  if (kIsWeb) return 'none';
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  void say(String text) => messenger.showSnackBar(SnackBar(content: Text(text)));
  final auth = LocalAuthentication();
  try {
    if (!await auth.isDeviceSupported()) return 'none';
    final ok = await auth.authenticate(localizedReason: l10n.identityReason, persistAcrossBackgrounding: true);
    return ok ? 'device' : null;
  } on LocalAuthException catch (e) {
    switch (e.code) {
      case LocalAuthExceptionCode.noCredentialsSet || LocalAuthExceptionCode.noBiometricHardware:
        return 'none'; // no screen lock to ask for
      case LocalAuthExceptionCode.userCanceled || LocalAuthExceptionCode.systemCanceled || LocalAuthExceptionCode.timeout:
        break;
      case LocalAuthExceptionCode.temporaryLockout || LocalAuthExceptionCode.biometricLockout:
        say(l10n.identityLocked);
      default:
        say(l10n.errorWithMessage(e.description ?? e.code.name));
    }
    return null;
  }
}
