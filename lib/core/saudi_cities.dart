import 'dart:math' as math;

/// A Saudi city for naming where a place is ("Showroom · Dammam").
class SaudiCity {
  const SaudiCity(this.en, this.ar, this.lat, this.lng);

  final String en;
  final String ar;
  final double lat;
  final double lng;

  String label(String languageCode) => languageCode == 'ar' ? ar : en;
}

/// Main cities and towns (city centres, approximate).
const saudiCities = [
  SaudiCity('Riyadh', 'الرياض', 24.7136, 46.6753),
  SaudiCity('Jeddah', 'جدة', 21.5433, 39.1728),
  SaudiCity('Makkah', 'مكة المكرمة', 21.3891, 39.8579),
  SaudiCity('Madinah', 'المدينة المنورة', 24.4672, 39.6024),
  SaudiCity('Dammam', 'الدمام', 26.4207, 50.0888),
  SaudiCity('Khobar', 'الخبر', 26.2172, 50.1971),
  SaudiCity('Dhahran', 'الظهران', 26.2361, 50.0393),
  SaudiCity('Qatif', 'القطيف', 26.5650, 49.9960),
  SaudiCity('Jubail', 'الجبيل', 27.0046, 49.6460),
  SaudiCity('Ras Tanura', 'رأس تنورة', 26.6436, 50.1597),
  SaudiCity('Al Ahsa', 'الأحساء', 25.3833, 49.5867),
  SaudiCity('Hafar Al Batin', 'حفر الباطن', 28.4328, 45.9708),
  SaudiCity('Khafji', 'الخفجي', 28.4391, 48.4913),
  SaudiCity('Buraidah', 'بريدة', 26.3260, 43.9750),
  SaudiCity('Unaizah', 'عنيزة', 26.0843, 43.9935),
  SaudiCity('Hail', 'حائل', 27.5114, 41.7208),
  SaudiCity('Tabuk', 'تبوك', 28.3835, 36.5662),
  SaudiCity('Abha', 'أبها', 18.2164, 42.5053),
  SaudiCity('Khamis Mushait', 'خميس مشيط', 18.3000, 42.7333),
  SaudiCity('Jazan', 'جازان', 16.8892, 42.5511),
  SaudiCity('Najran', 'نجران', 17.4924, 44.1277),
  SaudiCity('Taif', 'الطائف', 21.2703, 40.4158),
  SaudiCity('Yanbu', 'ينبع', 24.0895, 38.0618),
  SaudiCity('Rabigh', 'رابغ', 22.7986, 39.0349),
  SaudiCity('Al Kharj', 'الخرج', 24.1556, 47.3120),
  SaudiCity('Al Majmaah', 'المجمعة', 25.9039, 45.3456),
  SaudiCity('Al Zulfi', 'الزلفي', 26.2994, 44.8155),
  SaudiCity('Ad Dawadimi', 'الدوادمي', 24.5077, 44.3924),
  SaudiCity('Sakaka', 'سكاكا', 29.9697, 40.2064),
  SaudiCity('Arar', 'عرعر', 30.9753, 41.0381),
  SaudiCity('Al Qurayyat', 'القريات', 31.3318, 37.3428),
  SaudiCity('Al Baha', 'الباحة', 20.0129, 41.4677),
  SaudiCity('Bisha', 'بيشة', 20.0005, 42.6052),
  SaudiCity('Al Qunfudhah', 'القنفذة', 19.1281, 41.0787),
];

/// The nearest of [saudiCities] within [maxKm]; null when none is that close.
SaudiCity? nearestSaudiCity(double lat, double lng, {double maxKm = 50}) {
  SaudiCity? best;
  var bestKm = maxKm;
  for (final c in saudiCities) {
    final km = _km(lat, lng, c.lat, c.lng);
    if (km <= bestKm) {
      best = c;
      bestKm = km;
    }
  }
  return best;
}

double _km(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1), dLng = rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * r * math.asin(math.sqrt(a));
}
