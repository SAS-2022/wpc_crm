import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/notifications/notifications.dart';
import 'app_user.dart';
import 'providers.dart';
import 'saving.dart';

// App versions per user (user request 2026-10-19): each phone writes the
// version it runs to `users/{uid}.appVersions.{android|ios}`; admins see them
// on the Users page and remind people on an older build (at most once a
// minute per person).

/// One phone platform's installed version.
class InstalledVersion {
  const InstalledVersion({required this.version, required this.build, required this.at});

  /// e.g. '1.0.4' and 9 (pubspec `version: 1.0.4+9`).
  final String version;
  final int build;

  /// When the phone last reported it.
  final DateTime? at;

  String get label => '$version ($build)';

  static Map<String, InstalledVersion> parseAll(Object? raw) => {
        if (raw is Map)
          for (final MapEntry(:key, :value) in raw.entries)
            if (value is Map && value['build'] is num)
              '$key': InstalledVersion(
                version: value['version'] as String? ?? '',
                build: (value['build'] as num).toInt(),
                at: (value['at'] as Timestamp?)?.toDate(),
              ),
      };
}

/// The newest build anyone runs: this app's own build (the web dashboard is
/// always the newest deploy) or the highest a phone reported.
int latestBuild(Iterable<AppUser> users, int ownBuild) => [
      ownBuild,
      for (final u in users)
        for (final v in u.appVersions.values) v.build,
    ].reduce((a, b) => a > b ? a : b);

/// Phone platforms of [u] on a build older than [latest].
List<String> outdatedPlatforms(AppUser u, int latest) => [
      for (final MapEntry(:key, :value) in u.appVersions.entries)
        if (value.build < latest) key,
    ];

/// Minimum time between two update reminders to the same person.
const reminderCooldown = Duration(minutes: 1);

/// Time left before [u] may be reminded again; zero when allowed.
Duration reminderWait(AppUser u, DateTime now) {
  final last = u.updateRemindedAt;
  if (last == null) return Duration.zero;
  final left = reminderCooldown - now.difference(last);
  return left.isNegative ? Duration.zero : left;
}

final packageInfoProvider = FutureProvider<PackageInfo>((ref) => PackageInfo.fromPlatform());

/// This app's build number (0 until known).
final ownBuildProvider = Provider<int>(
  (ref) => int.tryParse(ref.watch(packageInfoProvider).value?.buildNumber ?? '') ?? 0,
);

String? get _platform => kIsWeb
    ? null
    : switch (defaultTargetPlatform) {
        TargetPlatform.android => 'android',
        TargetPlatform.iOS => 'ios',
        _ => null,
      };

/// Phones: saves the running version on the signed-in user when it changed.
final appVersionReporterProvider = Provider<void>((ref) {
  final platform = _platform;
  if (platform == null) return;
  final me = ref.watch(currentUserProvider).value;
  final info = ref.watch(packageInfoProvider).value;
  if (me == null || !me.active || info == null) return;
  final build = int.tryParse(info.buildNumber) ?? 0;
  final known = me.appVersions[platform];
  if (known != null && known.build == build && known.version == info.version) return;
  FirebaseFirestore.instance.collection('users').doc(me.id).update({
    'appVersions.$platform': {'version': info.version, 'build': build, 'at': FieldValue.serverTimestamp()},
  }).catchError((Object e) => debugPrint('appVersion: $e'));
});

/// Sends an update reminder (in-app + push) to each of [people] not
/// reminded in the last minute; returns how many were sent.
Future<int> sendUpdateReminders(List<AppUser> people, AppUser me) => saving(() async {
      final now = DateTime.now();
      final due = [for (final u in people) if (u.id != me.id && reminderWait(u, now) == Duration.zero) u];
      if (due.isEmpty) return 0;
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      for (final u in due) {
        batch.update(db.collection('users').doc(u.id), {'updateRemindedAt': FieldValue.serverTimestamp()});
      }
      await batch.commit();
      await sendNotifications(
        toIds: [for (final u in due) u.id],
        type: NotificationType.updateReminder,
        fromId: me.id,
        ownerId: me.id,
        date: '',
        count: 0,
      );
      return due.length;
    });

/// Where to update: Google Play on Android, TestFlight on iPhone.
Future<void> openAppStore() => launchUrl(
      Uri.parse(defaultTargetPlatform == TargetPlatform.iOS
          ? 'itms-beta://'
          : 'https://play.google.com/store/apps/details?id=com.wisora.wpc'),
      mode: LaunchMode.externalApplication,
    );
