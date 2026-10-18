/// Google Plus Codes (Open Location Code) in Maps links. Some shared links
/// (e.g. from the iPhone share sheet, `?g_st=ac`) open a place URL with no
/// coordinates, only "RH8W+2QH Akdal، الملقا، الرياض" and a place id. A full
/// code ("7HP8RH8W+2QH") decodes on its own; a short one needs a reference
/// point, taken from the Saudi city named in the same text. Same logic as
/// `plusCode.js` in functions/ — keep both in sync.
library;

const _alphabet = '23456789CFGHJMPQRVWX';
const _c = '[23456789CFGHJMPQRVWX]';
final _full = RegExp('(?<![0-9A-Z])($_c{8})\\+($_c{2,3})(?![0-9A-Z])');
final _short = RegExp('(?<![0-9A-Z+])($_c{4})\\+($_c{2,3})(?![0-9A-Z])');

/// Reference points for short codes: city names (EN / AR) → centre.
const saudiCities = <(List<String>, double, double)>[
  (['riyadh', 'الرياض'], 24.7136, 46.6753),
  (['jeddah', 'jiddah', 'جده'], 21.5433, 39.1728),
  (['makkah', 'mecca', 'مكه'], 21.3891, 39.8579),
  (['madinah', 'medina', 'المدينه المنوره'], 24.5247, 39.5692),
  (['dammam', 'الدمام'], 26.4207, 50.0888),
  (['khobar', 'الخبر'], 26.2172, 50.1971),
  (['dhahran', 'الظهران'], 26.2361, 50.0393),
  (['jubail', 'الجبيل'], 27.0174, 49.6225),
  (['qatif', 'القطيف'], 26.5196, 50.0115),
  (['hofuf', 'ahsa', 'hasa', 'الهفوف', 'الاحساء'], 25.3830, 49.5866),
  (['buraidah', 'buraydah', 'بريده'], 26.3260, 43.9750),
  (['unaizah', 'unayzah', 'عنيزه'], 26.0840, 43.9940),
  (['taif', 'الطايف', 'الطائف'], 21.2703, 40.4158),
  (['abha', 'ابها'], 18.2164, 42.5053),
  (['khamis mushait', 'خميس مشيط'], 18.3000, 42.7333),
  (['tabuk', 'تبوك'], 28.3838, 36.5550),
  (['hail', 'حائل', 'حايل'], 27.5114, 41.6900),
  (['jazan', 'jizan', 'جازان'], 16.8892, 42.5511),
  (['najran', 'نجران'], 17.5650, 44.2289),
  (['yanbu', 'ينبع'], 24.0895, 38.0618),
  (['kharj', 'الخرج'], 24.1556, 47.3346),
  (['hafar al batin', 'حفر الباطن'], 28.4328, 45.9708),
  (['arar', 'عرعر'], 30.9753, 41.0381),
  (['sakaka', 'سكاكا'], 29.9697, 40.2064),
  (['baha', 'الباحه'], 20.0129, 41.4677),
];

String _normalize(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[أإآ]'), 'ا')
    .replaceAll('ة', 'ه')
    .replaceAll('ى', 'ي');

/// The centre of the city named last in [text] (addresses end with the
/// city), or null.
(double, double)? cityReference(String text) {
  final s = _normalize(text);
  (double, double)? best;
  var at = -1;
  for (final (names, lat, lng) in saudiCities) {
    for (final name in names) {
      // Whole words only ("hail" is not in "thumbnail").
      final word = RegExp('(?<![a-z\u0621-\u064A])${RegExp.escape(_normalize(name))}(?![a-z\u0621-\u064A])');
      for (final m in word.allMatches(s)) {
        if (m.start > at) {
          at = m.start;
          best = (lat, lng);
        }
      }
    }
  }
  return best;
}

/// Centre of a full code (8 digits, '+', 2–3 more).
(double, double) _decode(String code) {
  final digits = code.replaceAll('+', '');
  var lat = 0.0, lng = 0.0, res = 20.0;
  for (var i = 0; i < 10 && i + 1 < digits.length; i += 2) {
    lat += _alphabet.indexOf(digits[i]) * res;
    lng += _alphabet.indexOf(digits[i + 1]) * res;
    res /= 20;
  }
  var latSize = res * 20, lngSize = res * 20;
  for (var i = 10; i < digits.length; i++) {
    latSize /= 5;
    lngSize /= 4;
    final d = _alphabet.indexOf(digits[i]);
    lat += (d ~/ 4) * latSize;
    lng += (d % 4) * lngSize;
  }
  return (lat - 90 + latSize / 2, lng - 180 + lngSize / 2);
}

String _prefix(double lat, double lng) {
  var a = lat + 90, b = lng + 180, res = 20.0, out = '';
  for (var i = 0; i < 2; i++) {
    out += _alphabet[(a ~/ res).clamp(0, 19)] + _alphabet[(b ~/ res).clamp(0, 19)];
    a %= res;
    b %= res;
    res /= 20;
  }
  return out;
}

/// A short code ("RH8W+2QH", 4 digits dropped = 1° cells) completed with the
/// cell nearest to the reference (Open Location Code "recover nearest").
(double, double) _recover(String short, double refLat, double refLng) {
  var (lat, lng) = _decode(_prefix(refLat, refLng) + short);
  if (lat - refLat > 0.5) lat -= 1;
  if (refLat - lat > 0.5) lat += 1;
  if (lng - refLng > 0.5) lng -= 1;
  if (refLng - lng > 0.5) lng += 1;
  return (lat, lng);
}

/// Coordinates from a Plus Code in [text] (a decoded Maps URL or an
/// address): a full code, or a short one next to a known Saudi city.
({double lat, double lng})? coordsFromPlusCode(String text) {
  final upper = text.toUpperCase();
  final full = _full.firstMatch(upper);
  if (full != null) {
    final (lat, lng) = _decode('${full.group(1)}+${full.group(2)}');
    return (lat: lat, lng: lng);
  }
  final short = _short.firstMatch(upper);
  if (short == null) return null;
  // The address right after the code, up to the next URL part.
  final rest = text.substring(short.end);
  final ref = cityReference(rest.split(RegExp(r'[/?&]')).first);
  if (ref == null) return null;
  final (lat, lng) = _recover('${short.group(1)}+${short.group(2)}', ref.$1, ref.$2);
  return (lat: lat, lng: lng);
}
