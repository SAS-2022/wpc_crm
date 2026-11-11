/**
 * Team follow-ups (user request 2026-11-11): when an employee is late, asks
 * for a break, asks to leave early or reports they won't come, the people
 * they report to must act. Firestore `team_alerts/{kind}_{ref}`:
 * {uid, kind late|break|earlyCheckout|absence, date 'yyyy-MM-dd', ref (the
 * request id; late: the uid), note, count (break minutes), time ('HH:mm',
 * late: start), level (0 = the first people told), toIds (told at this
 * level), allIds (everyone told so far — they may record the action),
 * steps [{level, toIds, at}], status open|done, nextAt (escalate then),
 * action {taken, note, byId, at, auto?}, createdAt}.
 *
 * Not handled within App setting `alertEscalateMin` (30) → the people the
 * current ones report to are told (next level), and so on to the top. A
 * decision on the request itself (break / leaving early approved or
 * rejected, absence decided) closes it automatically, and so does the
 * employee checking in for a late one (HR follows it up through
 * attendance); otherwise the action is recorded on the action page
 * (`/team-alerts/:id`). Escalation
 * stops at the end of the alert's day. Same app model: team_alerts.dart.
 */

const KINDS = ['late', 'break', 'earlyCheckout', 'absence'];

/** Document id: one alert per request (late: per person and day). */
function alertId(kind, ref) {
  return `${kind}_${ref}`;
}

/** A new open alert told to [toIds] now. */
function newAlert({ kind, uid, date, ref, note = '', count = 0, time = '', toIds }, nowMs, delayMin) {
  const ids = [...new Set(toIds)].filter((id) => id && id !== uid);
  return {
    uid, kind, date, ref, note: String(note || '').slice(0, 300), count, time,
    level: 0, toIds: ids, allIds: ids,
    steps: [{ level: 0, toIds: ids, at: nowMs }],
    status: 'open', nextAt: nowMs + delayMin * 60000,
    createdAt: nowMs,
  };
}

/**
 * Who is told next: the direct managers of the people told now, minus
 * the employee and anyone told before. Empty = the top was reached.
 * `managersOf(user, uid, users)` = `directManagers` in index.js.
 */
function escalationTargets(alert, users, managersOf) {
  const told = new Set([...(alert.allIds || []), alert.uid]);
  const byId = new Map(users.map((u) => [u.id, u]));
  const next = new Set();
  for (const id of alert.toIds || []) {
    const u = byId.get(id);
    if (!u) continue;
    for (const m of managersOf(u, id, users)) {
      if (!told.has(m)) next.add(m);
    }
  }
  // Nobody of this level is an active user any more: go up from the employee.
  if (next.size === 0 && !(alert.toIds || []).some((id) => byId.has(id))) {
    const person = byId.get(alert.uid);
    if (person) for (const m of managersOf(person, alert.uid, users)) if (!told.has(m)) next.add(m);
  }
  return [...next];
}

/**
 * What the escalation job does with [alert] at [nowMs]:
 * 'wait' | 'stop' (day over or open without nextAt) | 'escalate'.
 */
function escalationStep(alert, nowMs, today) {
  if (!alert || alert.status !== 'open' || !alert.nextAt) return 'wait';
  if (alert.nextAt > nowMs) return 'wait';
  if (alert.date && alert.date < today) return 'stop';
  return 'escalate';
}

/** The alert after escalating to [toIds] (null = top reached: no more steps). */
function escalated(alert, toIds, nowMs, delayMin) {
  if (toIds.length === 0) return { nextAt: null, topReached: true };
  const level = (alert.level || 0) + 1;
  return {
    level, toIds,
    allIds: [...new Set([...(alert.allIds || []), ...toIds])],
    steps: [...(alert.steps || []), { level, toIds, at: nowMs }],
    nextAt: nowMs + delayMin * 60000,
  };
}

/**
 * The request behind an alert changed ([before] → [after], null = deleted):
 * the action it counts as, or null. Break / leaving early: approved or
 * rejected by `decidedBy`; absence: a manager's step or a final decision;
 * a request taken back by the employee closes it with no action needed.
 */
function autoAction(kind, before, after) {
  if (!before) return null;
  if (!after) return { taken: false, auto: 'cancelled', byId: null, note: '' };
  if (kind === 'break' || kind === 'earlyCheckout') {
    if (before.status === 'pending' && ['approved', 'rejected'].includes(after.status)) {
      return { taken: true, auto: after.status, byId: after.decidedBy || null, note: after.comment || '' };
    }
    return null;
  }
  if (kind === 'absence') {
    if (before.status === 'pending' && after.status && after.status !== 'pending') {
      return { taken: true, auto: after.status, byId: after.decidedBy || null, note: after.comment || '' };
    }
    if (!before.managerStep && after.managerStep) {
      return {
        taken: true, auto: after.managerStep.status === 'rejected' ? 'rejected' : 'approved',
        byId: after.managerStep.byId || null, note: after.managerStep.comment || '',
      };
    }
  }
  return null;
}

/**
 * A late follow-up ends when the employee checks in (user decision
 * 2026-11-11): the manager has nothing to do, nobody above is told, and HR
 * handles the late arrival through attendance. [day] = the attendance day
 * doc: checked in = `checkInAt`, or an arrival / check-in event (also HR's).
 */
function checkedIn(day) {
  if (!day) return false;
  if (day.checkInAt) return true;
  return (day.events || []).some((e) => ['in', 'checkIn', 'hrIn'].includes(e?.type))
    || Boolean(day.correction?.checkInAt);
}

/** The action stored when a late follow-up closes by the check-in. */
function checkedInAction() {
  return { taken: false, auto: 'checkedIn', byId: null, note: '' };
}

module.exports = { KINDS, alertId, newAlert, escalationTargets, escalationStep, escalated, autoAction, checkedIn, checkedInAction };
