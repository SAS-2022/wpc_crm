/** The same warning about one person is sent at most this often. */
const ALERT_COOLDOWN_MS = 30 * 60 * 1000;

/**
 * Which of the `current` tracking issues (person online and on duty) to warn
 * about. `active` = {issue: Saudi day it was reported} for problems not fixed
 * since: an issue is reported once while it lasts (again on a new day), and
 * again only after it was fixed and came back — so a phone that keeps going
 * offline and reconnecting with GPS still off is not reported every time.
 * `sent` = {issue: last sent ms} keeps the ALERT_COOLDOWN_MS limit.
 * Returns the issues to send and the new `active`.
 */
function issuesToReport(current, active, sent, now, today) {
  const issues = current.filter((i) => active[i] !== today && !(sent[i] > now - ALERT_COOLDOWN_MS));
  const next = {};
  for (const i of current) {
    if (issues.includes(i)) next[i] = today;
    else if (active[i]) next[i] = active[i];
  }
  return { issues, active: next };
}

module.exports = { ALERT_COOLDOWN_MS, issuesToReport };
