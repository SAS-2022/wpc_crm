/**
 * Log of who adds users and changes them (2026-11-08, user: a registration
 * came in and nobody could tell who added it). Every `users/{uid}` write
 * becomes one `user_log` entry, built here from before / after.
 *
 * Who made the change: the app stamps `changedBy` (the signed-in uid) and
 * `changedAt` (server time) on every write to a user (rules require
 * changedBy == the writer whenever the stamp changes). A write without a new
 * stamp (older app builds) is the person themselves when only fields they
 * may change on their own changed, else unknown.
 */

/** Written by the app or the server themselves, not worth a log line. */
const IGNORED = new Set(['appVersions', 'updateRemindedAt', 'menuOrder', 'bottomTabs', 'changedBy', 'changedAt', 'registeredAt']);

/** Fields a person changes on their own (firestore.rules self-updates). */
const SELF_KEYS = new Set(['name', 'phone', 'appVersions', 'menuOrder', 'bottomTabs', 'homeLocation']);

const MAX_VALUE = 300;

function millis(v) {
  if (v == null) return null;
  if (typeof v.toMillis === 'function') return v.toMillis();
  if (v instanceof Date) return v.getTime();
  if (typeof v === 'number') return v;
  return null;
}

/** A value as stored in the log: plain numbers / strings / booleans / lists, dates as ISO text. */
function plain(v) {
  if (v === undefined || v === null) return null;
  const ms = millis(v);
  if (ms != null && typeof v !== 'number') return new Date(ms).toISOString();
  if (['string', 'number', 'boolean'].includes(typeof v)) return v;
  if (Array.isArray(v) && v.every((x) => ['string', 'number', 'boolean'].includes(typeof x))) return v;
  const text = JSON.stringify(v, (k, x) => (x && typeof x.toMillis === 'function' ? new Date(x.toMillis()).toISOString() : x));
  return text.length > MAX_VALUE ? `${text.slice(0, MAX_VALUE)}…` : text;
}

function same(a, b) {
  return JSON.stringify(plain(a)) === JSON.stringify(plain(b));
}

/**
 * The log entry for one users write, or null when nothing worth logging
 * changed. {action: registered | created | approved | rejected | updated,
 * actorId (null = unknown), stamped, changes [{field, from, to}]}.
 * Deletes are logged by the deleteUser function itself.
 */
function userLogEntry(before, after, uid) {
  if (!after) return null;
  const b = before || {};
  const fields = [...new Set([...Object.keys(b), ...Object.keys(after)])].filter((f) => !IGNORED.has(f)).sort();
  const changes = fields
    .filter((f) => !same(b[f], after[f]))
    .map((f) => ({ field: f, from: plain(b[f]), to: plain(after[f]) }));
  const changedKeys = [...new Set([...Object.keys(b), ...Object.keys(after)])].filter((f) => !same(b[f], after[f]));
  const stamped = !!after.changedBy && millis(after.changedAt) != null && millis(after.changedAt) !== millis(b.changedAt);

  if (!before) {
    const registered = after.approval === 'pending' && !after.role;
    return {
      action: registered ? 'registered' : 'created',
      actorId: registered ? uid : stamped ? after.changedBy : null,
      stamped,
      changes,
    };
  }
  if (changes.length === 0) return null;
  let action = 'updated';
  if (b.approval === 'pending' && after.approval !== 'pending') {
    action = after.approval === 'rejected' ? 'rejected' : after.active === true ? 'approved' : 'updated';
  } else if (b.approval !== 'rejected' && after.approval === 'rejected') {
    action = 'rejected';
  }
  const actorId = stamped ? after.changedBy : changedKeys.every((k) => SELF_KEYS.has(k)) ? uid : null;
  return { action, actorId, stamped, changes };
}

module.exports = { userLogEntry, IGNORED, SELF_KEYS };
