// Attendance (user rules 2026-10-19). Phones only record events on
// `attendance/{uid}_{yyyy-MM-dd}.events` [{type, at, siteId, source}]:
//   in       – arrived at a work site (geofence)
//   out      – left the work site (geofence)
//   checkIn  – "Check in" button (only inside a site)
//   checkOut – "Check out" button
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
//   work day, marked 'auto';
// - overtime allowed: time after the end counts (overtime); not allowed: the
//   day counts only up to the end of the work day, and the time stayed after
//   it is recorded as afterHoursMin (2026-10-20);
// - HR correction (2026-10-22, `correction` on the day, see correctedEvents):
//   replaces what the phone recorded; checkOutType 'hr';
// - lateMin: minutes after the start of the work day they checked in
//   (startMs null = not a work day for them: no lateness); up to 15 minutes
//   is on time (grace period).

const MINUTE = 60 * 1000;

/** Check-ins up to this many whole minutes after the start aren't late (user decision 2026-10-20: 8:15 on time, 8:16 late). */
const LATE_GRACE_MIN = 15;

/** Away from the site longer than this (not allowed to leave) → checked out when they left. */
const AWAY_GRACE_MIN = 30;

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
 * @param {Array<{type: string, at: number, siteId?: string, source?: string}>} events
 * @param {{startMs?: number|null, endMs: number, closeAllMs: number, now: number, leavesSite: boolean, overtimeAllowed: boolean, graceMin?: number, awayGraceMin?: number}} o
 *   graceMin: App settings `lateGraceMin` (default LATE_GRACE_MIN); awayGraceMin: `awayGraceMin` (AWAY_GRACE_MIN).
 */
function deriveDay(events, o) {
  const s = {
    checkInAt: null, checkInSource: null, siteId: null, inside: false, lastExitAt: null,
    checkOutAt: null, checkOutType: null, closed: false,
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
  // Not allowed to leave, left before the end and away longer than the grace time at [t].
  const awayTooLong = (t) => !o.leavesSite && s.checkInAt !== null && !s.closed && !s.inside
    && s.lastExitAt !== null && s.lastExitAt < o.endMs && t >= s.lastExitAt + graceMs;
  const sorted = [...events].filter((e) => typeof e.at === 'number').sort((a, b) => a.at - b.at);
  for (const e of sorted) {
    if (awayTooLong(e.at)) close(s.lastExitAt, 'leftSite');
    if (e.type === 'in' || e.type === 'checkIn' || e.type === 'hrIn') {
      if (s.checkInAt === null) {
        s.checkInAt = e.at;
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
    } else if (e.type === 'out') {
      s.inside = false;
      if (s.checkInAt === null || s.closed) continue;
      s.lastExitAt = e.at;
      if (e.at >= o.endMs) close(e.at, 'left');
    } else if (e.type === 'checkOut' || e.type === 'hrOut') {
      if (s.checkInAt !== null && !s.closed) close(e.at, e.type === 'hrOut' ? 'hr' : 'manual');
    }
  }
  if (awayTooLong(o.now)) close(s.lastExitAt, 'leftSite');
  if (s.checkInAt !== null && !s.closed && o.now >= o.endMs && !s.inside) {
    if (o.leavesSite) close(Math.max(o.endMs, s.checkInAt), 'endOfDay');
    else close(s.lastExitAt ?? o.endMs, 'leftEarly');
  }
  if (s.checkInAt !== null && !s.closed && o.now >= o.closeAllMs) {
    close(Math.max(o.endMs, s.checkInAt), 'auto');
  }
  let workedMin = null, countedMin = null, overtimeMin = null, afterHoursMin = null;
  if (s.closed) {
    workedMin = Math.max(0, Math.round((s.checkOutAt - s.checkInAt - awayBefore - awayAfter) / MINUTE));
    const extra = Math.max(0, s.checkOutAt - Math.max(o.endMs, s.checkInAt) - awayAfter);
    overtimeMin = o.overtimeAllowed ? Math.round(extra / MINUTE) : 0;
    afterHoursMin = o.overtimeAllowed ? 0 : Math.round(extra / MINUTE);
    countedMin = o.overtimeAllowed
      ? workedMin
      : Math.max(0, Math.round((Math.min(s.checkOutAt, o.endMs) - s.checkInAt - awayBefore) / MINUTE));
  }
  const awayMin = Math.round((awayBefore + awayAfter) / MINUTE);
  const lateMin = s.checkInAt === null || o.startMs === null || o.startMs === undefined
    ? null : lateMinutes(s.checkInAt - o.startMs, o.graceMin ?? LATE_GRACE_MIN);
  return { ...s, workedMin, countedMin, overtimeMin, afterHoursMin, lateMin, awayMin };
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

module.exports = { deriveDay, correctedEvents, saudiTime, LATE_GRACE_MIN, AWAY_GRACE_MIN };
