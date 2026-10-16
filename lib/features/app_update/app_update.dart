import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart';

import '../../l10n/app_localizations.dart';

/// Android: asks Google Play (In-App Updates API) whether a newer build is
/// published, at start and whenever the app comes back to the foreground,
/// and runs Play's full-screen update. A user who cancels it gets
/// [UpdateGate]'s "Update required" screen until they update.
/// iOS updates come through TestFlight's automatic updates; the web is
/// always the deployed version. Only works for apps installed from Play
/// (not debug builds or APKs installed by hand).
class AndroidUpdateNotifier extends Notifier<bool> {
  bool _checking = false;

  @override
  bool build() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    final listener = AppLifecycleListener(onResume: check);
    ref.onDispose(listener.dispose);
    Future.microtask(check);
    return false;
  }

  /// true = an update is waiting and the user hasn't installed it.
  Future<void> check() async {
    if (_checking) return;
    _checking = true;
    try {
      final info = await InAppUpdate.checkForUpdate();
      final waiting = info.updateAvailability == UpdateAvailability.updateAvailable ||
          info.updateAvailability == UpdateAvailability.developerTriggeredUpdateInProgress;
      state = waiting;
      if (waiting && info.immediateUpdateAllowed) await update();
    } catch (_) {
      // Not installed from Play, no Play services, offline: nothing to enforce.
    } finally {
      _checking = false;
    }
  }

  /// Play's update screen; the app restarts on the new build when it's done.
  Future<void> update() async {
    try {
      final result = await InAppUpdate.performImmediateUpdate();
      if (result != AppUpdateResult.success) state = true;
    } catch (_) {
      state = true;
    }
  }
}

final androidUpdateProvider = NotifierProvider<AndroidUpdateNotifier, bool>(AndroidUpdateNotifier.new);

/// Replaces the whole app while a Play update is waiting.
class UpdateGate extends ConsumerWidget {
  const UpdateGate({super.key, required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(androidUpdateProvider)) return child ?? const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset('assets/images/Regular.png', height: 80, semanticLabel: l10n.appTitle),
                const SizedBox(height: 24),
                Text(l10n.updateRequiredTitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(l10n.updateRequiredBody, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => ref.read(androidUpdateProvider.notifier).update(),
                  icon: const Icon(Icons.system_update),
                  label: Text(l10n.updateNow),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
