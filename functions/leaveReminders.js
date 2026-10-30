// Leave approval reminders (user request 2026-10-30): while a request waits
// at one approval step, the people of that step are reminded every 24 hours
// (counted from when the step started: the request's creation, or the
// previous step's approval). The last reminder is stored on the request as
// `reminded` {step, at}, so a new step starts its own count.

const DAY_MS = 24 * 60 * 60 * 1000;

const ms = (t) => (t == null ? null : typeof t === 'number' ? t : t.toMillis ? t.toMillis() : new Date(t).getTime());

/**
 * Whether request [r] (a leave_requests doc's data) is due a reminder now.
 * @returns {{due: boolean, days: number}} days = whole days the step has waited
 */
function leaveReminderDue(r, now) {
  if (r.status !== 'pending' || !r.awaitingKey) return { due: false, days: 0 };
  const index = r.stepIndex || 0;
  const start = index > 0 ? ms(r.steps?.[index - 1]?.at) ?? ms(r.updatedAt) : ms(r.createdAt);
  if (start == null) return { due: false, days: 0 };
  const last = r.reminded?.step === index ? ms(r.reminded.at) ?? start : start;
  return { due: now - last >= DAY_MS, days: Math.floor((now - start) / DAY_MS) };
}

/** Who takes the current step: 'uid:<id>' → that person; 'role:<r>' → every active user with the role but the requester. */
function awaitingUids(awaitingKey, requesterId, users) {
  if (!awaitingKey) return [];
  const [kind, value] = [awaitingKey.slice(0, awaitingKey.indexOf(':')), awaitingKey.slice(awaitingKey.indexOf(':') + 1)];
  return users
    .filter((u) => u.active === true && u.id !== requesterId && (kind === 'uid' ? u.id === value : u.role === value))
    .map((u) => u.id);
}

module.exports = { leaveReminderDue, awaitingUids, DAY_MS };
