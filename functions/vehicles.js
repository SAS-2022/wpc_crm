// Vehicles (user request 2026-10-24): kilometres driven per driver per day
// from their GPS points (`driver_km/{uid}_{day}`), and the yearly renewals
// (registration, insurance, periodic inspection) to remind about. Same
// rules as lib/features/vehicles/vehicle.dart — keep in sync.

const RENEWALS = ['registration', 'insurance', 'inspection'];

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

module.exports = { dayKm, daysLeft, renewalAlerts, RENEWALS, DUE_SOON_DAYS };
