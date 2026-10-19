import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../core/sign_out.dart';
import '../../l10n/app_localizations.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Image.asset('assets/images/Regular.png', width: 220),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ]),
        ),
      );
}

class NoAccessScreen extends ConsumerWidget {
  const NoAccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(currentUserProvider).value;
    // Registered, waiting for the sales manager / GM (or turned down).
    if (me != null && (me.isPendingApproval || me.approval == 'rejected')) {
      final pending = me.isPendingApproval;
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(pending ? Icons.hourglass_top : Icons.block, size: 56, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text(pending ? l10n.waitingForApprovalTitle : l10n.registrationRejectedTitle,
                    style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(pending ? l10n.waitingForApprovalBody(me.name) : l10n.registrationRejectedBody,
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                OutlinedButton(onPressed: signOut, child: Text(l10n.signOut)),
              ],
            ),
          ),
        ),
      );
    }
    // A role this version doesn't know: the account is fine, the app is old.
    final outdated = me?.role == UserRole.unknown && me?.active == true;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(outdated ? l10n.updateRequiredTitle : l10n.noAccessTitle, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text(outdated ? l10n.updateAppForRole : l10n.noAccessBody, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: signOut,
                child: Text(l10n.signOut),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
