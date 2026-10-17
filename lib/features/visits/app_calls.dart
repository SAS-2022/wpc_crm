import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// A call dialled from a client's page: when it started and, once the user
/// is back in the app, how long they were away (dialling, ringing, talking).
/// Phones can't tell an app whether the call was answered, so this is the
/// closest honest measure.
class AppCall {
  const AppCall({required this.clientId, required this.startedAt, this.endedAt});

  final String clientId;
  final DateTime startedAt;

  /// When the user came back to the app; null while they are still away.
  final DateTime? endedAt;

  int get seconds => endedAt == null ? 0 : endedAt!.difference(startedAt).inSeconds;
}

/// A finished app call is offered for logging this long after it ended.
const appCallValidFor = Duration(hours: 2);

/// The last call dialled from the app, if any. Phones only: on the web a
/// `tel:` link doesn't take the user out of the app.
final appCallProvider = NotifierProvider<AppCallNotifier, AppCall?>(AppCallNotifier.new);

class AppCallNotifier extends Notifier<AppCall?> {
  /// The dialler opened (the app went to the background) for the current call.
  bool _left = false;

  @override
  AppCall? build() {
    final observer = _Lifecycle(_onLifecycle);
    WidgetsBinding.instance.addObserver(observer);
    ref.onDispose(() => WidgetsBinding.instance.removeObserver(observer));
    return null;
  }

  /// Opens the phone's dialler for [number] and remembers the call.
  Future<void> dial(String clientId, String number) async {
    if (!kIsWeb) {
      _left = false;
      state = AppCall(clientId: clientId, startedAt: DateTime.now());
    }
    await launchUrl(Uri.parse('tel:$number'));
  }

  /// The call that may be logged for [clientId] now: ended within
  /// [appCallValidFor]. [now] is for tests.
  AppCall? finishedFor(String clientId, {DateTime? now}) {
    final c = state;
    if (c == null || c.clientId != clientId || c.endedAt == null) return null;
    return (now ?? DateTime.now()).difference(c.endedAt!) <= appCallValidFor ? c : null;
  }

  /// The call was logged (or dismissed): don't offer it again.
  void clear() => state = null;

  void _onLifecycle(AppLifecycleState lifecycle) {
    final c = state;
    if (c == null || c.endedAt != null) return;
    if (lifecycle == AppLifecycleState.paused || lifecycle == AppLifecycleState.hidden) {
      _left = true;
    } else if (lifecycle == AppLifecycleState.resumed && _left) {
      state = AppCall(clientId: c.clientId, startedAt: c.startedAt, endedAt: DateTime.now());
    }
  }
}

class _Lifecycle with WidgetsBindingObserver {
  _Lifecycle(this.onChange);

  final ValueChanged<AppLifecycleState> onChange;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => onChange(state);
}
