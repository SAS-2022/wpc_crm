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
// - office staff who leave before the end and don't come back are checked
//   out at the time they left (applied at the end of the day);
// - people who leave the site for work (sales team, drivers) stay checked in
//   when they leave early; the day closes at the end of the work day;
// - still open late in the evening (no exit seen): closed at the end of the
//   work day, marked 'auto';
// - overtime allowed: time after the end counts (overtime); not allowed: the
//   day counts only up to the end of the work day, and the time stayed after
//   it is recorded as afterHoursMin (2026-10-20);
// - lateMin: minutes after the start of the work day they checked in
//   (startMs null = not a work day for them: no lateness); up to 15 minutes
//   is on time (grace period).

const MINUTE = 60 * 1000;

/** Check-ins up to this many whole minutes after the start aren't late (user decision 2026-10-20: 8:15 on time, 8:16 late). */
const LATE_GRACE_MIN = 15;

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
 * @param {{startMs?: number|null, endMs: number, closeAllMs: number, now: number, leavesSite: boolean, overtimeAllowed: boolean, graceMin?: number}} o
 *   graceMin: App settings `lateGraceMin` (default LATE_GRACE_MIN).
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
  const sorted = [...events].filter((e) => typeof e.at === 'number').sort((a, b) => a.at - b.at);
  for (const e of sorted) {
    if (e.type === 'in' || e.type === 'checkIn') {
      if (s.checkInAt === null) {
        s.checkInAt = e.at;
        s.checkInSource = e.type === 'checkIn' ? 'manual' : 'auto';
        s.siteId = e.siteId || null;
      } else if (s.closed) {
        // Back after the day closed: only a manual check-in opens it again.
        if (e.type !== 'checkIn') { s.inside = true; continue; }
        s.closed = false;
        s.checkOutAt = null;
        s.checkOutType = null;
      }
      s.inside = true;
      s.lastExitAt = null;
    } else if (e.type === 'out') {
      s.inside = false;
      if (s.checkInAt === null || s.closed) continue;
      s.lastExitAt = e.at;
      if (e.at >= o.endMs) close(e.at, 'left');
    } else if (e.type === 'checkOut') {
      if (s.checkInAt !== null && !s.closed) close(e.at, 'manual');
    }
  }
  if (s.checkInAt !== null && !s.closed && o.now >= o.endMs && !s.inside) {
    if (o.leavesSite) close(Math.max(o.endMs, s.checkInAt), 'endOfDay');
    else close(s.lastExitAt ?? o.endMs, 'leftEarly');
  }
  if (s.checkInAt !== null && !s.closed && o.now >= o.closeAllMs) {
    close(Math.max(o.endMs, s.checkInAt), 'auto');
  }
  let workedMin = null, countedMin = null, overtimeMin = null, afterHoursMin = null;
  if (s.closed) {
    workedMin = Math.max(0, Math.round((s.checkOutAt - s.checkInAt) / MINUTE));
    const extra = Math.max(0, s.checkOutAt - Math.max(o.endMs, s.checkInAt));
    overtimeMin = o.overtimeAllowed ? Math.round(extra / MINUTE) : 0;
    afterHoursMin = o.overtimeAllowed ? 0 : Math.round(extra / MINUTE);
    countedMin = o.overtimeAllowed
      ? workedMin
      : Math.max(0, Math.round((Math.min(s.checkOutAt, o.endMs) - s.checkInAt) / MINUTE));
  }
  const lateMin = s.checkInAt === null || o.startMs === null || o.startMs === undefined
    ? null : lateMinutes(s.checkInAt - o.startMs, o.graceMin ?? LATE_GRACE_MIN);
  return { ...s, workedMin, countedMin, overtimeMin, afterHoursMin, lateMin };
}

module.exports = { deriveDay, saudiTime, LATE_GRACE_MIN };
