import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'import_plan.dart';
import 'location_import.dart';
import 'odoo_parser.dart';

/// Reads the first sheet of an .xlsx, or a .csv, into rows of strings.
List<List<String>> readTable(String fileName, Uint8List bytes) {
  if (fileName.toLowerCase().endsWith('.csv')) {
    final text = utf8.decode(bytes, allowMalformed: true).replaceFirst('﻿', '');
    return [
      for (final r in csv.decode(text)) [for (final c in r) '${c ?? ''}'],
    ];
  }
  final sheet = Excel.decodeBytes(bytes).tables.values.first;
  return [
    for (final r in sheet.rows) [for (final c in r) c?.value?.toString() ?? ''],
  ];
}

/// Resolves Google Maps short links: directly on phones, through the
/// `resolvePins` Cloud Function on the web (browsers can't follow them).
/// Returns the coordinates found and whether resolving was possible.
Future<({Map<String, Coords> coords, bool available})> resolveShortLinks(
  List<String> urls,
  void Function(int done) onProgress,
) async {
  if (!kIsWeb) return (coords: await _resolveOnDevice(urls, onProgress), available: true);
  final callable = FirebaseFunctions.instance.httpsCallable('resolvePins');
  final coords = <String, Coords>{};
  for (var i = 0; i < urls.length; i += 50) {
    final chunk = urls.skip(i).take(50).toList();
    try {
      final res = await callable.call({'urls': chunk});
      (res.data as Map).forEach((url, value) {
        if (value is Map) {
          coords[url as String] = (
            lat: (value['lat'] as num).toDouble(),
            lng: (value['lng'] as num).toDouble(),
          );
        }
      });
    } on FirebaseFunctionsException {
      return (coords: coords, available: false);
    }
    onProgress(i + chunk.length);
  }
  return (coords: coords, available: true);
}

/// Coordinates from pasted text: any Google Maps link (short links are
/// followed) or plain "24.63, 46.80". Null when nothing can be read.
Future<Coords?> coordsFromPastedText(String text) async {
  final plain = coordsFromText(text);
  if (plain != null) return plain;
  final url = extractUrl(text.trim());
  if (url.isEmpty) return null;
  final direct = coordsFromUrl(url);
  if (direct != null || !isShortLink(url)) return direct;
  return (await resolveShortLinks([url], (_) {})).coords[url];
}

const _googleHosts = {
  'maps.app.goo.gl', 'goo.gl', 'share.google', 'g.co',
  'www.google.com', 'google.com', 'maps.google.com', 'www.google.com.sa', 'google.com.sa',
};

/// Follows each short link's redirects (5 at a time) and reads the coordinates.
Future<Map<String, Coords>> _resolveOnDevice(List<String> urls, void Function(int done) onProgress) async {
  final client = http.Client();
  final coords = <String, Coords>{};
  try {
    for (var i = 0; i < urls.length; i += 5) {
      final chunk = urls.skip(i).take(5).toList();
      final results = await Future.wait(chunk.map((url) => _followRedirects(client, url)
          .timeout(const Duration(seconds: 15), onTimeout: () => null)));
      for (var j = 0; j < chunk.length; j++) {
        if (results[j] != null) coords[chunk[j]] = results[j]!;
      }
      onProgress(i + chunk.length);
    }
  } finally {
    client.close();
  }
  return coords;
}

Future<Coords?> _followRedirects(http.Client client, String url) async {
  try {
    var current = Uri.parse(url);
    for (var hop = 0; hop < 6; hop++) {
      if (!_googleHosts.contains(current.host)) return null;
      final found = coordsFromUrl(current.toString());
      if (found != null) return found;
      final request = http.Request('GET', current)..followRedirects = false;
      final response = await client.send(request).timeout(const Duration(seconds: 10));
      await response.stream.drain<void>();
      final next = response.headers['location'];
      if (next == null) return null;
      current = current.resolve(next);
    }
  } catch (_) {
    // Network error or timeout: report the link as unreadable.
  }
  return null;
}
