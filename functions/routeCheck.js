// Route history loops (2026-10-26): Google's road route between two fixes
// sometimes adds a detour the car never drove (the fix landed on the other
// side of a divided road or at an interchange → drive on, U-turn, come
// back), and a single rough fix that jumps out and back gets routed as a
// loop. Worker Number Two's 25 Oct: 148.8 km in Route history vs 134.6 km by
// the vehicle, ~10 km of it such loops. The phone's fixes every 30 s show
// the way actually driven, so a road route much longer than the path
// through them is refused (drawn and counted along the fixes instead).
// No extra Routes API calls; stored legs are re-checked for free.

/** Road route refused when longer than this × the path through the fixes … */
const LOOP_FACTOR = 1.4;
/** … plus this (short city moves round corners stay). */
const LOOP_EXTRA_M = 400;
/** Fixes at most this far apart in time show the way taken; sparser legs keep the older, looser check. */
const DENSE_GAP_MS = 75 * 1000;
/** Moves shorter than this (or the fixes' accuracy) are jitter (same as _minMove in report.dart). */
const MIN_MOVE_M = 25;

function metersBetween(a, b) {
  const rad = (d) => (d * Math.PI) / 180;
  const dLat = rad(b.lat - a.lat);
  const dLng = rad(b.lng - a.lng);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * 6371000 * Math.asin(Math.sqrt(h));
}

/**
 * Rough single fixes that jump out and straight back: accuracy 50 m or
 * worse, 100 m+ from both neighbours, which are within 50 m of each other.
 * Returns the set of their times ([path] sorted).
 */
function spikeTimes(path) {
  const out = new Set();
  for (let i = 1; i + 1 < path.length; i++) {
    const [a, b, c] = [path[i - 1], path[i], path[i + 1]];
    if ((b.accuracy || 0) < 50) continue;
    if (metersBetween(a, c) <= 50 && metersBetween(a, b) >= 100 && metersBetween(b, c) >= 100) out.add(b.t);
  }
  return out;
}

/** Distance along [points] (sorted), jitter left out like summarizeRoute in report.dart. */
function pathMeters(points) {
  let m = 0;
  let from = null;
  for (const p of points) {
    if (!from) { from = p; continue; }
    const d = metersBetween(from, p);
    if (d > Math.max(MIN_MOVE_M, from.accuracy || 0, p.accuracy || 0)) { m += d; from = p; }
  }
  return m;
}

/**
 * Whether a road route of [meters] / [seconds] between the leg's first and
 * last fix is believable. [fixes] = the leg's fixes (both ends included,
 * spikes left out); [spike] = an end of the leg is a spike.
 */
function roadPlausible({ meters, seconds, fixes, spike }) {
  if (spike || fixes.length < 2) return false;
  const a = fixes[0];
  const b = fixes[fixes.length - 1];
  const straight = metersBetween(a, b);
  const elapsed = (b.t - a.t) / 1000;
  if (seconds > Math.max(2 * elapsed, elapsed + 300)) return false;
  if (meters > Math.max(2.5 * straight, straight + 2000)) return false;
  let maxGap = 0;
  for (let i = 1; i < fixes.length; i++) maxGap = Math.max(maxGap, fixes[i].t - fixes[i - 1].t);
  if (maxGap > DENSE_GAP_MS) return true;
  return meters <= LOOP_FACTOR * pathMeters(fixes) + LOOP_EXTRA_M;
}

/**
 * The fixes of leg [a]→[b] from [path] (sorted, one track) without spikes,
 * and whether an end is one.
 */
function legFixes(path, spikes, a, b) {
  return {
    fixes: path.filter((p) => p.t >= a.t && p.t <= b.t && !spikes.has(p.t)),
    spike: spikes.has(a.t) || spikes.has(b.t),
  };
}

/**
 * What to store for a leg: the road route {p, m} when believable, else
 * {s: true, m: distance along the fixes}. [route] = {p, m, seconds} or null.
 */
function legValue(route, { fixes, spike }) {
  if (route?.p && roadPlausible({ meters: route.m, seconds: route.seconds ?? 0, fixes, spike })) {
    return { p: route.p, m: route.m };
  }
  return { s: true, m: Math.round(pathMeters(fixes)) };
}

/**
 * A stored leg re-checked with today's rules (no API call; stored legs have
 * no duration, so only the distance checks apply). Null = unchanged.
 */
function recheckLeg(stored, legInfo) {
  const next = stored.s
    ? { s: true, m: Math.round(pathMeters(legInfo.fixes)) }
    : legValue({ p: stored.p, m: stored.m, seconds: 0 }, legInfo);
  if (!!next.s === !!stored.s && Math.abs((next.m || 0) - (stored.m || 0)) < 1) return null;
  return next;
}

module.exports = {
  spikeTimes, pathMeters, roadPlausible, legFixes, legValue, recheckLeg, metersBetween,
  LOOP_FACTOR, LOOP_EXTRA_M, DENSE_GAP_MS,
};
