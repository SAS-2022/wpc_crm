// Vehicles (user request 2026-10-24): kilometres driven per driver per day
// from their GPS points (`driver_km/{uid}_{day}`), and the yearly renewals
// (registration, insurance, periodic inspection, TGA operating card) and
// oil changes to remind about. Same rules as
// lib/features/vehicles/vehicle.dart — keep in sync.

const RENEWALS = ['registration', 'insurance', 'inspection', 'operatingCard'];

/** Oil change reminded this many km before it's due: default of App settings `oilDueSoonKm`. */
const OIL_DUE_SOON_KM = 500;

/** Reminded this many days before an expiry: default of App settings `vehicleRenewalDays`. */
const DUE_SOON_DAYS = 14;

function metersBetween(a, b) {
  const rad = (d) => (d * Math.PI) / 180;
  const dLat = rad(b.lat - a.lat);
  const dLng = rad(b.lng - a.lng);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * 6371000 * Math.asin(Math.sqrt(h));
}

/**
 * Kilometres between a day's fixes (sorted, one phone, rough fixes removed):
 * straight lines from fix to fix, also across gaps without fixes (the car
 * still went there), so it reads a little under the odometer. Jitter while
 * standing still (a move within both fixes' accuracy, or under 30 m) isn't
 * distance.
 */
function dayKm(points) {
  let m = 0;
  for (let i = 0; i + 1 < points.length; i++) {
    const a = points[i], b = points[i + 1];
    const d = metersBetween(a, b);
    if (d > Math.max(30, (a.accuracy || 0) + (b.accuracy || 0))) m += d;
  }
  return Math.round(m / 100) / 10;
}

/** Whole days from [today] to [expiry] ('yyyy-MM-dd'); negative once past. */
function daysLeft(expiry, today) {
  return Math.round((Date.parse(`${expiry}T00:00:00Z`) - Date.parse(`${today}T00:00:00Z`)) / 86400000);
}

/**
 * The reminders due for [vehicle] on [today]: one per item when it enters
 * the last [dueSoonDays] (App setting, default DUE_SOON_DAYS; or is added already that close / expired), sent
 * once per expiry date ([notified] = keys already sent, saved on the vehicle
 * as `renewalNotified`); a new date after renewing starts again.
 * Returns [{item, expiry, days, key}].
 */
function renewalAlerts(vehicle, today, notified = [], dueSoonDays = DUE_SOON_DAYS) {
  if (vehicle.active === false) return [];
  const sent = new Set(notified);
  const out = [];
  for (const item of RENEWALS) {
    const expiry = vehicle.expiries?.[item];
    if (typeof expiry !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(expiry)) continue;
    const days = daysLeft(expiry, today);
    if (days > dueSoonDays) continue;
    const key = `${item}:${expiry}`;
    if (sent.has(key)) continue;
    out.push({ item, expiry, days, key });
  }
  return out;
}

/** The latest odometer reading by day (then entry time), or null. */
function lastReading(vehicle) {
  const readings = (vehicle.readings || []).filter((r) => typeof r?.km === 'number' && typeof r?.day === 'string');
  readings.sort((a, b) => a.day.localeCompare(b.day) || ((a.at?.toMillis?.() || 0) - (b.at?.toMillis?.() || 0)));
  return readings.length ? readings[readings.length - 1] : null;
}

/**
 * Odometer estimate = last reading + the GPS km ([kmDocs] {uid, day, km}) of
 * the vehicle's drivers on days after the reading's day, while each was on
 * the vehicle (`vehicleMileage` in vehicle.dart). Null without a reading.
 */
function vehicleEstimate(vehicle, kmDocs) {
  const last = lastReading(vehicle);
  if (!last) return null;
  const log = vehicle.driverLog || [];
  let km = 0;
  for (const d of kmDocs) {
    if (d.day <= last.day) continue;
    if (!log.some((s) => s.driverId === d.uid && s.from <= d.day && (s.to == null || d.day <= s.to))) continue;
    km += d.km || 0;
  }
  return last.km + Math.round(km);
}

/**
 * The oil change reminder due for [vehicle] at odometer [estimate]: once
 * when it's [dueSoonKm] (App setting, default OIL_DUE_SOON_KM) from due, once
 * when due (only the due one when both are new); keys `oil:<nextKm>:soon|due`
 * in [notified]. A recorded change moves nextKm and starts again.
 * Returns [{key, nextKm, kmLeft}].
 */
function oilAlerts(vehicle, estimate, notified = [], dueSoonKm = OIL_DUE_SOON_KM) {
  if (vehicle.active === false || estimate == null) return [];
  const interval = vehicle.oilIntervalKm;
  const log = (vehicle.oilLog || []).filter((r) => typeof r?.km === 'number' && typeof r?.day === 'string');
  if (typeof interval !== 'number' || interval <= 0 || !log.length) return [];
  log.sort((a, b) => a.day.localeCompare(b.day) || a.km - b.km);
  const nextKm = log[log.length - 1].km + interval;
  const kmLeft = nextKm - estimate;
  const stage = kmLeft <= 0 ? 'due' : kmLeft <= dueSoonKm ? 'soon' : null;
  if (!stage) return [];
  const key = `oil:${nextKm}:${stage}`;
  return new Set(notified).has(key) ? [] : [{ key, nextKm, kmLeft }];
}

module.exports = {
  dayKm, daysLeft, renewalAlerts, lastReading, vehicleEstimate, oilAlerts, RENEWALS, DUE_SOON_DAYS, OIL_DUE_SOON_KM,
};
