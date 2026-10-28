// Attendance (user rules 2026-10-19). Phones only record events on
// `attendance/{uid}_{yyyy-MM-dd}.events` [{type, at, siteId, source}]:
//   in       – arrived at a work site (geofence)
//   out      – left the work site (geofence)
//   checkIn  – "Check in" button (only inside a site)
//   checkOut – "Check out" button
//   seen     – still at the site, from a site check (2026-10-25: after the
//              end of the work day the server asks the phone every 30 min
//              with a silent push; it answers with one GPS fix)
//   out with `check: true` – a site check found them gone
//   otStart  – "Start overtime" (2026-10-25: asked at the end + 10 min)
//   otDecline – "Not today" to that question
// The day's result is worked out here (same rules as attendance_rules.dart):
// - checked in at the first arrival, whatever the time;
// - leaving after the end of the work day (17:00) checks out at that time;
// - a manual check-out checks out at once;
// - people not allowed to leave the site (user form "Allowed to leave the
//   site", default: everyone outside the sales team and drivers; 2026-10-22)
//   who leave before the end and stay away longer than the grace time (App
//   settings `awayGraceMin`, 30 min) are checked out at the time they left;
//   coming back to the site before the end checks them in again, and the
//   time away doesn't count. Leaving within the last half hour: checked out
//   at the time they left once the work day ends;
// - people allowed to leave the site (sales team, drivers by default) stay
//   checked in when they leave early; the day closes at the end of the work day;
// - a manual check-in reopens a closed day; the time between the check-out
//   and coming back doesn't count (awayMin);
// - still open late in the evening (no exit seen): closed at the end of the
//   work day, marked 'auto' — with overtime allowed, at the last time they
//   were seen at the site instead (an arrival event, or a GPS fix the server
//   passes as lastSeenAt; 2026-10-24: a phone that stopped reporting lost the
//   evening's overtime), at most the overtime cap after the end;
// - site checks (2026-10-25, after Worker Number Two's 24 Oct: phone silent
//   from 08:04, day closed at 17:00 without overtime): `seen` moves the last
//   time seen at the site; a check that finds them gone checks out at the
//   last time they were seen there (not the time of the check: they left
//   somewhere in between). A day closed 'auto' with overtime allowed whose
//   check-out is before end + cap is `overtimeUnconfirmed` (nobody can tell
//   when they left; HR corrects it if they stayed);
// - overtime must be started (user decision 2026-10-25): site staff are
//   asked 10 min after their end ("Start overtime?", reminded once after
//   30 min) and only a confirmation (otStart, while still checked in) makes
//   the time after the end count — from the end, whenever they confirm.
//   Drivers aren't asked: on the road at end + 10 min their overtime starts
//   by itself (server, `o.drive`) and ends when they arrive home
//   (`users.homeLocation`) or at a work site; a driver at a site / home then
//   gets none. While driving, phone events after the end are ignored except
//   a manual check-out;
// - overtime allowed and started: time after the end counts (overtime) up to the
//   person's cap (`users.overtimeMaxMin`, default 3 h — user decision
//   2026-10-24); time beyond the cap and, without overtime, all time stayed
//   after the end is recorded as afterHoursMin, not counted (2026-10-20);
// - HR correction (2026-10-22, `correction` on the day, see correctedEvents):
//   replaces what the phone recorded; checkOutType 'hr';
// - arrived earlier than the check-in (2026-10-28, after Driver Number Two's
//   27 Oct: GPS at the Dammam site from 08:42, the geofence never fired, he
//   pressed Check in at 09:22): the day's first check-in starts at the
//   arrival of that stay seen by GPS (`o.arrivedAt`, server: `siteArrival`
//   over location_history; tracked people only); checkInEventAt keeps the
//   event's own time;
// - lateMin: minutes after the start of the work day they checked in
//   (startMs null = not a work day for them: no lateness); up to 15 minutes
//   is on time (grace period).

const MINUTE = 60 * 1000;

/** Check-ins up to this many whole minutes after the start aren't late (user decision 2026-10-20: 8:15 on time, 8:16 late). */
const LATE_GRACE_MIN = 15;

/** Away from the site longer than this (not allowed to leave) → checked out when they left. */
const AWAY_GRACE_MIN = 30;

/** Most overtime counted a day unless the user form sets more (user decision 2026-10-24). */
const OVERTIME_MAX_MIN = 180;

/** `users.overtimeMaxMin` when set (1 min – 24 h), else [OVERTIME_MAX_MIN]. Same as AppUser.overtimeCapMin. */
const overtimeCap = (v) => (typeof v === 'number' && v > 0 && v <= 1440 ? Math.round(v) : OVERTIME_MAX_MIN);

/** Whole minutes after the start (seconds dropped); 0 within the grace period. Same as lateMinutes in attendance_rules.dart. */
function lateMinutes(ms, graceMin = LATE_GRACE_MIN) {
  const m = Math.floor(ms / MINUTE);
  return m > graceMin ? m : 0;
}

/** Epoch ms of [minutes] past midnight, Saudi time (UTC+3), on 'yyyy-MM-dd'. */
function saudiTime(date, minutes) {
  const [y, m, d] = date.split('-').map(Number);
  return Date.UTC(y, m - 1, d) + minutes * MINUTE - 3 * 60 * MINUTE;
}

/**
 * @param {Array<{type: string, at: number, siteId?: string, source?: string, check?: boolean}>} events
 * @param {{startMs?: number|null, endMs: number, closeAllMs: number, now: number, leavesSite: boolean, overtimeAllowed: boolean, overtimeMaxMin?: number, lastSeenAt?: number|null, graceMin?: number, awayGraceMin?: number, drive?: {startAt: number, endAt?: number|null, place?: string|null}|null}} o
 *   drive: driver overtime (server: `driveOvertime` running / done on the day); place 'home' | 'site' | 'cap' | null (end unknown).
 *   graceMin: App settings `lateGraceMin` (default LATE_GRACE_MIN); awayGraceMin: `awayGraceMin` (AWAY_GRACE_MIN);
 *   overtimeMaxMin: the person's cap (OVERTIME_MAX_MIN); lastSeenAt: last GPS fix at the site (server only);
 *   arrivedAt: GPS arrival of the stay the day's first check-in falls in (server: `siteArrival`).
 */
function deriveDay(events, o) {
  const s = {
    checkInAt: null, checkInSource: null, siteId: null, inside: false, lastExitAt: null,
    checkOutAt: null, checkOutType: null, closed: false, checkInEventAt: null,
  };
  const close = (at, type) => {
    s.checkOutAt = at;
    s.checkOutType = type;
    s.closed = true;
  };
  // Time between a check-out and coming back, before / after the end of the work day.
  let awayBefore = 0, awayAfter = 0;
  const reopen = (at) => {
    awayBefore += Math.max(0, Math.min(at, o.endMs) - s.checkOutAt);
    awayAfter += Math.max(0, at - Math.max(s.checkOutAt, o.endMs));
    s.closed = false;
    s.checkOutAt = null;
    s.checkOutType = null;
  };
  const graceMs = (o.awayGraceMin ?? AWAY_GRACE_MIN) * MINUTE;
  const capMs = (o.overtimeMaxMin ?? OVERTIME_MAX_MIN) * MINUTE;
  // Last time the person was seen at the site (arrival / check-in events, GPS).
  let seenAt = typeof o.lastSeenAt === 'number' ? o.lastSeenAt : null;
  // Not allowed to leave, left before the end and away longer than the grace time at [t].
  const awayTooLong = (t) => !o.leavesSite && s.checkInAt !== null && !s.closed && !s.inside
    && s.lastExitAt !== null && s.lastExitAt < o.endMs && t >= s.lastExitAt + graceMs;
  const drive = o.drive && typeof o.drive.startAt === 'number' ? o.drive : null;
  // Overtime started ("Start overtime") / declined.
  let confirmedAt = null, declined = false;
  const sorted = [...events].filter((e) => typeof e.at === 'number')
    // Driving overtime: only a check-out counts after it started.
    .filter((e) => !drive || e.at <= drive.startAt || e.type === 'checkOut' || e.type === 'hrOut')
    .sort((a, b) => a.at - b.at);
  for (const e of sorted) {
    if (awayTooLong(e.at)) close(s.lastExitAt, 'leftSite');
    if (e.type === 'in' || e.type === 'checkIn' || e.type === 'hrIn') {
      seenAt = Math.max(seenAt ?? 0, e.at);
      if (s.checkInAt === null) {
        s.checkInAt = e.at;
        // At the site before the check-in (GPS): the day starts then.
        if (e.type !== 'hrIn' && typeof o.arrivedAt === 'number' && o.arrivedAt < e.at) {
          s.checkInAt = o.arrivedAt;
          s.checkInEventAt = e.at;
        }
        s.checkInSource = e.type === 'checkIn' ? 'manual' : e.type === 'hrIn' ? 'hr' : 'auto';
        s.siteId = e.siteId || null;
      } else if (s.closed) {
        // Back after the day closed: a manual check-in opens it again, and so
        // does arriving before the end after being checked out for leaving.
        const back = e.type !== 'in' || (s.checkOutType === 'leftSite' && e.at < o.endMs);
        if (!back) { s.inside = true; continue; }
        reopen(e.at);
      }
      s.inside = true;
      s.lastExitAt = null;
    } else if (e.type === 'otStart') {
      if (s.checkInAt !== null && !s.closed && confirmedAt === null) confirmedAt = e.at;
    } else if (e.type === 'otDecline') {
      if (s.checkInAt !== null && !s.closed) declined = true;
    } else if (e.type === 'seen') {
      seenAt = Math.max(seenAt ?? 0, e.at);
      if (s.checkInAt !== null && !s.closed) {
        s.inside = true;
        s.lastExitAt = null;
      }
    } else if (e.type === 'out') {
      const wasInside = s.inside;
      s.inside = false;
      if (s.checkInAt === null || s.closed) continue;
      // Already away when the end came (allowed to leave): the day closed at
      // the end; a later exit (e.g. geofences registered again) doesn't move it.
      if (!wasInside && o.leavesSite && !drive && e.at >= o.endMs) {
        close(Math.max(o.endMs, s.checkInAt), 'endOfDay');
        continue;
      }
      // Found gone by a site check: left after they were last seen.
      const at = e.check === true && seenAt !== null ? Math.min(e.at, Math.max(seenAt, o.endMs, s.checkInAt)) : e.at;
      s.lastExitAt = at;
      if (e.at >= o.endMs) close(at, 'left');
    } else if (e.type === 'checkOut' || e.type === 'hrOut') {
      if (s.checkInAt !== null && !s.closed) close(e.at, e.type === 'hrOut' ? 'hr' : 'manual');
    }
  }
  const overtimeOn = o.overtimeAllowed && (drive !== null || confirmedAt !== null);
  if (drive && s.checkInAt !== null && !s.closed) {
    // Driving: open until the server finds the arrival (or the cap).
    if (typeof drive.endAt === 'number') {
      const type = { home: 'arrivedHome', site: 'arrivedSite', cap: 'overtimeCap' }[drive.place] || 'auto';
      close(Math.max(drive.endAt, o.endMs, s.checkInAt), type);
    }
  } else {
    if (awayTooLong(o.now)) close(s.lastExitAt, 'leftSite');
    if (s.checkInAt !== null && !s.closed && o.now >= o.endMs && !s.inside) {
      if (o.leavesSite) close(Math.max(o.endMs, s.checkInAt), 'endOfDay');
      else close(s.lastExitAt ?? o.endMs, 'leftEarly');
    }
    if (s.checkInAt !== null && !s.closed && o.now >= o.closeAllMs) {
      // No exit seen: the end of the work day, or with overtime started the
      // last time they were seen at the site (up to the cap).
      const from = Math.max(o.endMs, s.checkInAt);
      close(overtimeOn && seenAt !== null ? Math.min(Math.max(seenAt, from), from + capMs) : from, 'auto');
    }
  }
  let workedMin = null, countedMin = null, overtimeMin = null, afterHoursMin = null;
  if (s.closed) {
    workedMin = Math.max(0, Math.round((s.checkOutAt - s.checkInAt - awayBefore - awayAfter) / MINUTE));
    const extra = Math.max(0, s.checkOutAt - Math.max(o.endMs, s.checkInAt) - awayAfter);
    const overtime = overtimeOn ? Math.min(extra, capMs) : 0;
    overtimeMin = Math.round(overtime / MINUTE);
    afterHoursMin = Math.round((extra - overtime) / MINUTE);
    countedMin = overtimeOn
      ? Math.max(0, workedMin - afterHoursMin)
      : Math.max(0, Math.round((Math.min(s.checkOutAt, o.endMs) - s.checkInAt - awayBefore) / MINUTE));
  }
  const awayMin = Math.round((awayBefore + awayAfter) / MINUTE);
  // Overtime started, no exit / arrival seen and not seen up to the cap: when it ended is unknown.
  const overtimeEndUnknown = s.closed && s.checkOutType === 'auto' && overtimeOn
    && s.checkOutAt < Math.max(o.endMs, s.checkInAt) + capMs;
  const lateMin = s.checkInAt === null || o.startMs === null || o.startMs === undefined
    ? null : lateMinutes(s.checkInAt - o.startMs, o.graceMin ?? LATE_GRACE_MIN);
  return { ...s, workedMin, countedMin, overtimeMin, afterHoursMin, lateMin, awayMin, lastSeenAt: seenAt,
    overtimeOn, overtimeConfirmedAt: confirmedAt, overtimeDeclined: declined, overtimeEndUnknown };
}

/**
 * The day's events with HR's correction applied (`attendance.correction`
 * {checkInAt, checkOutAt?, siteId?} in epoch ms): checked in at checkInAt;
 * out at checkOutAt when given, else the phone's events after the check-in
 * go on as usual. Events of the HR types never come from phones.
 */
function correctedEvents(events, c) {
  const phone = events.filter((e) => e.type !== 'hrIn' && e.type !== 'hrOut');
  if (!c || typeof c.checkInAt !== 'number') return phone;
  const first = { type: 'hrIn', at: c.checkInAt, siteId: c.siteId || null };
  if (typeof c.checkOutAt === 'number') return [first, { type: 'hrOut', at: c.checkOutAt }];
  return [first, ...phone.filter((e) => e.at > c.checkInAt)];
}

/** Site checks this often after the end of the work day (a little early: the schedule runs every 10 min). */
const SITE_CHECK_EVERY_MS = 30 * MINUTE;
const SITE_CHECK_SLACK_MS = 5 * MINUTE;

/**
 * Whether to send a site check now (2026-10-25): overtime started, still
 * checked in and inside after the end of the work day, the overtime cap not
 * reached yet, and the last check (lastCheckAt) 30 min ago or more.
 * @param {object} d deriveDay's result
 * @param {{now: number, endMs: number, closeAllMs: number, overtimeAllowed: boolean, overtimeMaxMin?: number, lastCheckAt?: number|null}} o
 */
function siteCheckDue(d, o) {
  if (!o.overtimeAllowed || d.checkInAt === null || d.closed || !d.inside || d.overtimeConfirmedAt === null) return false;
  if (o.drive) return false;
  const from = Math.max(o.endMs, d.checkInAt);
  const capMs = (o.overtimeMaxMin ?? OVERTIME_MAX_MIN) * MINUTE;
  if (o.now < from || o.now > from + capMs || o.now >= o.closeAllMs) return false;
  return typeof o.lastCheckAt !== 'number' || o.now - o.lastCheckAt >= SITE_CHECK_EVERY_MS - SITE_CHECK_SLACK_MS;
}

/** "Start overtime?" this long after the end (user decision 2026-10-25), reminded once this much later. */
const ASK_AFTER_MS = 10 * MINUTE;
const REMIND_AFTER_MS = 30 * MINUTE;

/**
 * 'ask' | 'remind' | null (2026-10-25): site staff with overtime allowed,
 * still checked in and inside 10 min after the end, who haven't started or
 * declined overtime; asked once, reminded once 30 min later, never after
 * the cap. Drivers are never asked.
 * @param {object} d deriveDay's result
 * @param {{now: number, endMs: number, closeAllMs: number, overtimeAllowed: boolean, overtimeMaxMin?: number, driver?: boolean, askedAt?: number|null, remindedAt?: number|null}} o
 */
function overtimeAskDue(d, o) {
  if (!o.overtimeAllowed || o.driver || d.checkInAt === null || d.closed || !d.inside) return null;
  if (d.overtimeConfirmedAt !== null || d.overtimeDeclined) return null;
  const from = Math.max(o.endMs, d.checkInAt);
  const capMs = (o.overtimeMaxMin ?? OVERTIME_MAX_MIN) * MINUTE;
  if (o.now < o.endMs + ASK_AFTER_MS || o.now > from + capMs || o.now >= o.closeAllMs) return null;
  if (typeof o.askedAt !== 'number') return 'ask';
  if (typeof o.remindedAt !== 'number' && o.now - o.askedAt >= REMIND_AFTER_MS - SITE_CHECK_SLACK_MS) return 'remind';
  return null;
}

/** Home counts within this radius (m) for drivers' overtime. */
const HOME_RADIUS_M = 150;
/** No position near the end by the decision time + this long: not decided, no overtime. */
const DRIVE_DECIDE_UNTIL_MS = 60 * MINUTE;
/** A fix this close to the end tells where the driver was at the end. */
const DRIVE_FRESH_MS = 15 * MINUTE;
/** Arriving home this soon after the end is the drive home, not overtime (App setting `driveHomeGraceMin`). */
const DRIVE_HOME_GRACE_MIN = 30;

/** Meters between two {lat, lng}. */
function meters(a, b) {
  const rad = Math.PI / 180;
  const dLat = (b.lat - a.lat) * rad, dLng = (b.lng - a.lng) * rad;
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(a.lat * rad) * Math.cos(b.lat * rad) * Math.sin(dLng / 2) ** 2;
  return 2 * 6371000 * Math.asin(Math.sqrt(h));
}

/** 'home' | 'site' when [p] (with accuracy) is at one of [places] [{lat, lng, radius, kind}], else null. */
function placeAt(p, places) {
  const margin = Math.min(Math.max(p.accuracy || 0, 0), 100);
  for (const pl of places) {
    if (typeof pl?.lat === 'number' && typeof pl.lng === 'number' && meters(p, pl) <= pl.radius + margin) return pl.kind;
  }
  return null;
}

/**
 * A driver's overtime (user rules 2026-10-27), from the day's GPS points
 * ({lat, lng, accuracy, t}), decided at end + the home grace (at least 10 min):
 * - at a work site or home at the end → 'none' (a drive home afterwards is
 *   not overtime);
 * - still driving at the end: arriving home within the grace → 'none' (the
 *   drive home); arriving at a site, or home later → {status: 'done', endAt,
 *   place} (overtime = end → arrival); not arrived yet → {status: 'running'}
 *   (`driveEnd` finds the arrival later);
 * - 'wait' (too early, or no fix near the end yet), 'late' (still no fix
 *   near the end an hour after the decision time: no overtime).
 * @param {{points: Array, endMs: number, now: number, homeGraceMs: number, places: Array}} o
 */
function driveDecide({ points, endMs, now, homeGraceMs, places }) {
  const decideAt = endMs + Math.max(ASK_AFTER_MS, homeGraceMs);
  if (now < decideAt) return 'wait';
  const pts = points.filter((p) => typeof p?.t === 'number' && typeof p.lat === 'number' && (p.accuracy ?? 0) <= 100)
    .sort((a, b) => a.t - b.t);
  // Where they were at the end: the last fix in the 15 min before it, else the first in the 15 min after.
  const atEnd = pts.filter((p) => p.t <= endMs && p.t >= endMs - DRIVE_FRESH_MS).at(-1)
    ?? pts.find((p) => p.t > endMs && p.t <= endMs + DRIVE_FRESH_MS);
  if (!atEnd) return now > decideAt + DRIVE_DECIDE_UNTIL_MS ? 'late' : 'wait';
  if (placeAt(atEnd, places)) return 'none';
  const arrival = firstArrival(pts.filter((p) => p.t >= endMs), places);
  if (!arrival) return { status: 'running' };
  if (arrival.place === 'home' && arrival.endAt <= endMs + homeGraceMs) return 'none';
  return { status: 'done', ...arrival };
}

/** Fixes further apart than this end a stay (nobody knows where they were in between). */
const STAY_GAP_MS = 30 * MINUTE;

/**
 * When the stay at [site] {lat, lng, radius} that [atMs] falls in began,
 * from GPS points {lat, lng, accuracy, t} (2026-10-28): walking back from
 * the last fix at or before [atMs], the earliest fix inside (radius + its
 * accuracy, up to 100 m) before a fix clearly outside (50 m more) or a gap
 * over 30 min. Rough fixes (worse than 100 m) and fixes at the edge are
 * skipped. Null when the last fix is clearly outside or older than 30 min.
 */
function siteArrival(points, site, atMs) {
  const pts = points.filter((p) => typeof p?.t === 'number' && typeof p.lat === 'number' && p.t <= atMs
    && (p.accuracy ?? 0) <= 100).sort((a, b) => b.t - a.t);
  let arrival = null, prevT = atMs;
  for (const p of pts) {
    if (prevT - p.t > STAY_GAP_MS) break;
    prevT = p.t;
    const margin = Math.min(Math.max(p.accuracy || 0, 0), 100);
    const d = meters(p, site);
    if (d <= site.radius + margin) arrival = p.t;
    else if (d - margin > site.radius + 50) break;
  }
  return arrival;
}

/** At-site reminder (not checked in) at most this often, twice a day (2026-10-28). */
const AT_SITE_REMIND_MS = 30 * MINUTE;

/**
 * Whether to tell someone who isn't checked in that they're at their site
 * (2026-10-28): 'ask' | 'remind' | null. [sent] = RTDB
 * `attendance_at_site/{uid}` {date, count, at}.
 */
function atSiteReminderDue(sent, date, now) {
  if (!sent || sent.date !== date) return 'ask';
  if ((sent.count || 0) < 2 && now - (sent.at || 0) >= AT_SITE_REMIND_MS - 2 * MINUTE) return 'remind';
  return null;
}

/** The first arrival in [pts] (sorted): two fixes in a row at the same place (one could be driving past). */
function firstArrival(pts, places, beforeMs = Infinity) {
  for (let i = 0; i + 1 < pts.length; i++) {
    if (pts[i].t >= beforeMs) break;
    const kind = placeAt(pts[i], places);
    if (kind && placeAt(pts[i + 1], places) === kind) return { endAt: pts[i].t, place: kind };
  }
  return null;
}

/**
 * The end of a driver's overtime from their GPS points ({lat, lng, accuracy,
 * t}): arriving home or at a work site = the first of two fixes in a row
 * there (one fix could be driving past); else the cap ('cap') once a fix
 * reaches it; else, past the cap with the phone silent, the last fix with
 * place null (end unknown). Null while still driving.
 * @returns {{endAt: number, place: string|null}|null}
 */
function driveEnd({ points, startAt, now, capMs, places }) {
  const pts = points.filter((p) => typeof p?.t === 'number' && p.t >= startAt && typeof p.lat === 'number'
    && (p.accuracy ?? 0) <= 100).sort((a, b) => a.t - b.t);
  const capAt = startAt + capMs;
  const arrival = firstArrival(pts, places, capAt);
  if (arrival) return arrival;
  if (pts.some((p) => p.t >= capAt)) return { endAt: capAt, place: 'cap' };
  if (now >= capAt) return { endAt: pts.length ? pts[pts.length - 1].t : startAt, place: null };
  return null;
}

module.exports = {
  siteArrival, atSiteReminderDue, overtimeAskDue, driveDecide, driveEnd, HOME_RADIUS_M, DRIVE_HOME_GRACE_MIN,
  deriveDay, correctedEvents, siteCheckDue, saudiTime, overtimeCap, LATE_GRACE_MIN, AWAY_GRACE_MIN, OVERTIME_MAX_MIN,
};
