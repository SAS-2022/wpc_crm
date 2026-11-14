import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

// Where a self-registration came from (2026-11-12, user: an "Eddy K" account
// kept being registered and nobody could tell by whom). Right after
// registering, the app sends its device details to the `noteRegistration`
// Cloud Function, which adds the IP address and saves `users/{uid}.registeredFrom`
// once (the person can't write that field themselves).

/// `users.registeredFrom`: {platform, app, maker, model, os, emulator,
/// browser, language, ip, userAgent, at}.
class RegistrationSource {
  const RegistrationSource({
    this.platform,
    this.app,
    this.maker,
    this.model,
    this.os,
    this.emulator = false,
    this.browser,
    this.language,
    this.ip,
    this.userAgent,
    this.at,
  });

  final String? platform;
  final String? app;
  final String? maker;
  final String? model;
  final String? os;
  final bool emulator;
  final String? browser;
  final String? language;
  final String? ip;
  final String? userAgent;
  final DateTime? at;

  static RegistrationSource? fromMap(Object? raw) {
    if (raw is! Map) return null;
    String? s(String k) => (raw[k] is String && (raw[k] as String).isNotEmpty) ? raw[k] as String : null;
    return RegistrationSource(
      platform: s('platform'),
      app: s('app'),
      maker: s('maker'),
      model: s('model'),
      os: s('os'),
      emulator: raw['emulator'] == true,
      browser: s('browser'),
      language: s('language'),
      ip: s('ip'),
      userAgent: s('userAgent'),
      at: (raw['at'] as Timestamp?)?.toDate(),
    );
  }

  /// "Samsung SM-A546E · Android 14", "iPhone 15 Pro · iOS 18.1", "Chrome · macOS".
  String get device {
    final name = [?maker, ?model].join(' ');
    return [if (name.isNotEmpty) name, ?browser, ?os].join(' · ');
  }
}

/// This phone / browser, for [noteRegistration].
Future<Map<String, Object?>> registrationDevice() async {
  Future<T?> safe<T>(Future<T> Function() f) async {
    try {
      return await f();
    } catch (_) {
      return null;
    }
  }

  final info = DeviceInfoPlugin();
  final package = await safe(PackageInfo.fromPlatform);
  final data = <String, Object?>{
    'app': ?(package == null ? null : '${package.version} (${package.buildNumber})'),
    'language': PlatformDispatcher.instance.locale.toLanguageTag(),
  };
  if (kIsWeb) {
    final web = await safe(() => info.webBrowserInfo);
    data.addAll({
      'platform': 'web',
      if (web != null) ...{
        'browser': web.browserName.name,
        'os': ?web.platform,
        'userAgent': ?web.userAgent,
      },
    });
  } else if (Platform.isAndroid) {
    final a = await safe(() => info.androidInfo);
    data.addAll({
      'platform': 'android',
      if (a != null) ...{
        'maker': a.manufacturer,
        'model': a.model,
        'os': 'Android ${a.version.release}',
        'emulator': !a.isPhysicalDevice,
      },
    });
  } else if (Platform.isIOS) {
    final i = await safe(() => info.iosInfo);
    data.addAll({
      'platform': 'ios',
      if (i != null) ...{
        'maker': 'Apple',
        'model': i.modelName.isNotEmpty ? i.modelName : i.utsname.machine,
        'os': 'iOS ${i.systemVersion}',
        'emulator': !i.isPhysicalDevice,
      },
    });
  } else {
    data['platform'] = Platform.operatingSystem;
  }
  return data;
}

/// Sends this device's details for the account just registered. Never
/// fails the registration.
Future<void> noteRegistration() async {
  try {
    await FirebaseFunctions.instance.httpsCallable('noteRegistration').call(await registrationDevice());
  } catch (e) {
    debugPrint('noteRegistration: $e');
  }
}
