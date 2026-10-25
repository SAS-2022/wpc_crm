// Quiet phones (user request 2026-10-24, replaces the presence-based offline
// alert): a phone that should be sharing its location but has sent nothing
// (no position, no heartbeat) for QUIET_MS gets a silent "wake" push. If the
// app wakes, it answers and tracking goes on ("woken" in the tracking log);
// if it stays quiet, the person's managers are told once per quiet spell,
// within the person's hours only. State per person in RTDB
// `tracking_alerts/{uid}/wake` {quietSince, pingAt, pings, notifiedAt}.

const MINUTE = 60 * 1000;

/** Nothing received this long → the phone is quiet and gets a ping. */
const QUIET_MS = 10 * MINUTE;
/** Time the phone has to answer a ping before the managers are told. */
const ANSWER_MS = 10 * MINUTE;
/** Pinged again this often while quiet, at most MAX_PINGS times a spell. */
const REPING_MS = 30 * MINUTE;
const MAX_PINGS = 6;

/**
 * One step for one person, every few minutes.
 * @param {object} o
 * @param {number} o.now
 * @param {boolean} o.on the phone should be sharing now (tracking schedule)
 * @param {boolean} o.inHours within the person's hours: log + notify only then
 * @param {number|null} o.lastSign last position / heartbeat / wake answer (ms)
 * @param {number|null} [o.windowStart] start of today's tracking (scheduled
 *   people): quiet time is counted from here, not from last night
 * @param {number|null} [o.hoursStart] start of the person's hours now (inHours):
 *   quiet time before it (e.g. a phone off overnight) isn't held against them
 * @param {object|null} o.state the stored state
 * @param {number} [o.alertMs] quiet this long (and a ping unanswered) → managers told
 * @returns {{state: object|null, ping: boolean, log: Array<{type: string, t: number}>, notify: {since: number, minutes: number}|null}}
 */
function wakeStep({ now, on, inHours, lastSign, windowStart = null, hoursStart = null, state, alertMs = 30 * MINUTE }) {
  const out = { state: null, ping: false, log: [], notify: null };
  if (!on) return out;
  const since = Math.max(lastSign ?? 0, windowStart ?? 0);
  if (since === 0) return out; // never seen: nothing to compare with
  if (now - since < QUIET_MS) {
    // Sending again: after a ping it's the ping that woke it.
    if (state?.logged && inHours) {
      out.log.push({ type: state.pingAt && lastSign >= state.pingAt ? 'woken' : 'resumed', t: lastSign ?? now });
    }
    return out;
  }
  const next = { pings: 0, ...state };
  // Within the person's hours, counted from their start at the earliest.
  const quietFrom = Math.max(since, hoursStart ?? 0);
  if (!next.quietSince) next.quietSince = since;
  if (inHours && !next.logged) {
    next.logged = true;
    out.log.push({ type: 'quiet', t: quietFrom });
  }
  // The last ping went unanswered (checked before pinging again).
  if (!next.notifiedAt && inHours && next.pings > 0 && now - next.pingAt >= ANSWER_MS && now - quietFrom >= alertMs) {
    next.notifiedAt = now;
    out.notify = { since, minutes: Math.round((now - since) / MINUTE) };
    out.log.push({ type: 'noAnswer', t: now });
  }
  if (next.pings < MAX_PINGS && (!next.pingAt || now - next.pingAt >= REPING_MS)) {
    out.ping = true;
    next.pingAt = now;
    next.pings += 1;
  }
  out.state = next;
  return out;
}

module.exports = { wakeStep, QUIET_MS, ANSWER_MS, REPING_MS, MAX_PINGS };
