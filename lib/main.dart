import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'core/router.dart';
import 'features/notifications/push.dart';
import 'features/tracking/tracking_service.dart';
import 'features/tracking/tracking_status.dart';
import 'features/users/users_repository.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Tracking.configure();
  runApp(const ProviderScope(child: WpcCrmApp()));
}

class WpcCrmApp extends ConsumerWidget {
  const WpcCrmApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Starts / stops live tracking as the signed-in user changes.
    ref.listen(trackingStatusProvider, (_, _) {});
    // Registers this phone for push notifications while signed in.
    ref.listen(pushProvider, (_, _) {});
    // GM / manager: keeps the RTDB role copies the database rules read in sync.
    ref.listen(roleMirrorProvider, (_, _) {});
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF8B5A2B),
        useMaterial3: true,
      ),
      locale: ref.watch(localeProvider),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(routerProvider),
      // Tapping anywhere outside a text field closes the keyboard.
      builder: (context, child) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: child,
      ),
    );
  }
}
