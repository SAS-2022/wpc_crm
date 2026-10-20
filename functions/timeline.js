// A salesperson's working day from their GPS points (user request
// 2026-10-20): how the time between the start and end of work was spent.
//   client   – staying at a client they checked in at that day
//   office   – staying at a work site (office, warehouse…)
//   lunch    – up to 60 minutes of stops elsewhere around midday
//   stopped  – staying 15+ minutes somewhere else
//   driving  – moving (and short stops: traffic, a quick errand)
//   noData   – the phone sent nothing and the person moved meanwhile
// The report compares the time taken with team benchmarks built from these
// days (see routing_pace.dart).

const MINUTE = 60 * 1000;

/** A run of points within this distance of its first point is one place. */
const STAY_RADIUS_M = 150;
/** Jumpy fixes in a row ignored inside a stay. */
const MAX_STRAYS = 2;
/** A check-in this close to a stay makes it a client stay. */
const CLIENT_RADIUS_M = 200;
/** Shortest stay counted at a client (drop-ins) / anywhere else. */
const MIN_CLIENT_STAY_MS = 2 * MINUTE;
const MIN_STAY_MS = 5 * MINUTE;
/** Shorter stops elsewhere count as driving (traffic lights, fuel). */
const MIN_STOP_MS = 15 * MINUTE;
/** No point for this long while the person moved: unknown time. */
const GAP_MS = 10 * MINUTE;
/** Lunch allowance, for stops between 11:00 and 15:00 Saudi time. */
const LUNCH_MS = 60 * MINUTE;
const LUNCH_FROM_MIN = 11 * 60;
const LUNCH_TO_MIN = 15 * 60;

const KINDS = ['client', 'driving', 'office', 'lunch', 'stopped', 'noData'];

function metersBetween(a, b) {
  const rad = (d) => (d * Math.PI) / 180;
  const dLat = rad(b.lat - a.lat);
  const dLng = rad(b.lng - a.lng);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * 6371000 * Math.asin(Math.sqrt(h));
}

/** Minutes past midnight, Saudi time (UTC+3). */
const saudiMinute = (ms) => Math.floor(((ms / MINUTE) + 180) % 1440);

/**
 * @param {object} o
 * @param {Array<{t:number, lat:number, lng:number, accuracy?:number}>} o.points sorted, one phone, rough fixes removed
 * @param {Array<{id:string, clientId:string, at:number, lat:number, lng:number}>} o.visits the day's check-ins
 * @param {Array<{id:string, lat:number, lng:number, radius:number}>} o.sites active work sites
 * @param {number} o.startMs start of the work day
 * @param {number} o.endMs end of the work day
 */
function buildDayTimeline({ points, visits, sites, startMs, endMs }) {
  const pts = points.filter((p) => p.t >= startMs && p.t <= endMs);
  const segments = []; // {from, to, kind, stay?}
  const add = (from, to, kind, stay) => {
    if (to <= from) return;
    const last = segments[segments.length - 1];
    if (last && last.kind === kind && last.stay === stay && last.to === from) last.to = to;
    else segments.push({ from, to, kind, stay });
  };

  // 1. Places where the person stayed.
  const stays = [];
  let i = 0;
  while (i < pts.length) {
    // Extend while points stay near the first one (allowing for each fix's
    // accuracy); up to [MAX_STRAYS] jumpy fixes in a row are skipped when
    // the next one is back in place.
    const near = (p) => metersBetween(pts[i], p) <= STAY_RADIUS_M + Math.min(p.accuracy || 0, 100);
    let j = i;
    for (;;) {
      if (j + 1 < pts.length && near(pts[j + 1])) { j++; continue; }
      let k = j + 2;
      while (k < pts.length && k - j - 1 <= MAX_STRAYS && !near(pts[k])) k++;
      if (k < pts.length && k - j - 1 <= MAX_STRAYS && near(pts[k])) { j = k; continue; }
      break;
    }
    const from = pts[i].t, to = pts[j].t;
    const lat = pts.slice(i, j + 1).reduce((s, p) => s + p.lat, 0) / (j - i + 1);
    const lng = pts.slice(i, j + 1).reduce((s, p) => s + p.lng, 0) / (j - i + 1);
    const here = { lat, lng };
    // The nearest check-in made around this stay.
    let visit = null;
    for (const v of visits) {
      const d = metersBetween(here, v);
      if (d <= CLIENT_RADIUS_M && v.at >= from - 30 * MINUTE && v.at <= to + 30 * MINUTE
        && (!visit || d < metersBetween(here, visit))) visit = v;
    }
    const site = sites.find((s) => metersBetween(here, s) <= (s.radius || 100) + 50);
    const kind = visit ? 'client' : site ? 'office' : 'stopped';
    const min = kind === 'client' ? MIN_CLIENT_STAY_MS : kind === 'office' ? MIN_STAY_MS : MIN_STOP_MS;
    if (j > i && to - from >= min) {
      stays.push({ from, to, kind, lat, lng, clientId: visit?.clientId, visitId: visit?.id, siteId: site?.id, first: i, last: j });
      i = j + 1;
    } else {
      i++;
    }
  }

  // 2. Every stretch between two points: inside a stay, driving, or unknown.
  const stayOf = new Array(pts.length).fill(-1);
  stays.forEach((s, k) => { for (let n = s.first; n <= s.last; n++) stayOf[n] = k; });
  let drivingM = 0;
  if (pts.length > 0) add(startMs, pts[0].t, 'noData');
  for (let n = 0; n + 1 < pts.length; n++) {
    const a = pts[n], b = pts[n + 1];
    if (stayOf[n] >= 0 && stayOf[n] === stayOf[n + 1]) {
      add(a.t, b.t, stays[stayOf[n]].kind, stayOf[n]);
      continue;
    }
    const m = metersBetween(a, b);
    if (b.t - a.t > GAP_MS && m > STAY_RADIUS_M) {
      add(a.t, b.t, 'noData');
    } else {
      add(a.t, b.t, 'driving');
      // Jitter while standing still isn't distance.
      if (m > Math.max(30, (a.accuracy || 0) + (b.accuracy || 0))) drivingM += m;
    }
  }
  add(pts.length > 0 ? pts[pts.length - 1].t : startMs, endMs, 'noData');

  // 3. Lunch: the first 60 minutes of stops elsewhere around midday.
  let lunchLeft = LUNCH_MS;
  for (let k = 0; k < segments.length && lunchLeft > 0; k++) {
    const s = segments[k];
    if (s.kind !== 'stopped') continue;
    const mid = saudiMinute((s.from + s.to) / 2);
    if (mid < LUNCH_FROM_MIN || mid > LUNCH_TO_MIN) continue;
    const take = Math.min(lunchLeft, s.to - s.from);
    lunchLeft -= take;
    if (take === s.to - s.from) {
      s.kind = 'lunch';
    } else {
      segments.splice(k + 1, 0, { from: s.from + take, to: s.to, kind: 'stopped', stay: s.stay });
      s.to = s.from + take;
      s.kind = 'lunch';
      k++;
    }
  }

  // 4. Totals for the day and for the stretch from the first client to the last.
  const minutes = (from, to) => {
    const out = Object.fromEntries(KINDS.map((k) => [k, 0]));
    for (const s of segments) {
      const a = Math.max(s.from, from), b = Math.min(s.to, to);
      if (b > a) out[s.kind] += (b - a) / MINUTE;
    }
    for (const k of KINDS) out[k] = Math.round(out[k]);
    return out;
  };
  const clientStays = stays.filter((s) => s.kind === 'client');
  const firstClientAt = clientStays.length ? clientStays[0].from : null;
  const lastClientAt = clientStays.length ? clientStays[clientStays.length - 1].to : null;
  let betweenDrivingM = 0;
  if (firstClientAt !== null) {
    for (let n = 0; n + 1 < pts.length; n++) {
      const a = pts[n], b = pts[n + 1];
      if (a.t < firstClientAt || b.t > lastClientAt) continue;
      if (stayOf[n] >= 0 && stayOf[n] === stayOf[n + 1]) continue;
      const m = metersBetween(a, b);
      if (b.t - a.t > GAP_MS && m > STAY_RADIUS_M) continue;
      if (m > Math.max(30, (a.accuracy || 0) + (b.accuracy || 0))) betweenDrivingM += m;
    }
  }

  return {
    start: startMs,
    end: endMs,
    points: pts.length,
    minutes: minutes(startMs, endMs),
    drivingKm: Math.round(drivingM / 100) / 10,
    clientStays: clientStays.map((s) => ({ clientId: s.clientId, visitId: s.visitId, from: s.from, to: s.to })),
    stops: segments
      .filter((s) => s.kind === 'stopped' || s.kind === 'lunch' || s.kind === 'office')
      .map((s) => ({
        from: s.from, to: s.to, kind: s.kind,
        lat: stays[s.stay]?.lat ?? null, lng: stays[s.stay]?.lng ?? null, siteId: stays[s.stay]?.siteId ?? null,
      })),
    firstClientAt,
    lastClientAt,
    between: firstClientAt === null ? null : { ...minutes(firstClientAt, lastClientAt), drivingKm: Math.round(betweenDrivingM / 100) / 10 },
  };
}

module.exports = { buildDayTimeline, KINDS };
