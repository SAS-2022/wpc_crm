/**
 * Tracked live with tracking alerts and wake pings: sales execs, KAMs and
 * drivers, plus anyone the SM / GM switched on (`users.liveTracking: true`,
 * 2026-11-18); `liveTracking: false` switches it off. The SM / GM are
 * tracked by role without alerts (unchanged) — `AppUser.locationTracked`
 * in the app, minus those two roles.
 */
function tracksLive(u) {
  if (!u || u.liveTracking === false) return false;
  return u.liveTracking === true || ['sales_exec', 'kam', 'driver'].includes(u.role);
}

module.exports = { tracksLive };
