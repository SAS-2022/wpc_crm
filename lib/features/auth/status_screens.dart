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
    // A role this version doesn't know: the account is fine, the app is old.
    final outdated = ref.watch(currentUserProvider).value?.role == UserRole.unknown;
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
