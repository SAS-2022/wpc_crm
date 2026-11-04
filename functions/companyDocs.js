// Company documents (2026-11-01): reminders for services that expire
// (health insurance, Moqeem …) and, since 2026-11-03, subscriptions and
// employees' Iqamas / national IDs (`employee_records`). Same states as
// lib/features/documents/company_docs.dart — keep in sync.

/** Reminded this many days before an expiry: default of App settings `docRenewalDays`. */
const DOC_DUE_SOON_DAYS = 30;

/** The second reminder, this many days before (user decision 2026-11-03). */
const SECOND_REMINDER_DAYS = 15;

/** Sections whose items expire and are reminded. */
const EXPIRING_SECTIONS = ['expiring', 'subscription'];

/** Whole days from [today] to [expiry] ('yyyy-MM-dd'); negative once past. */
function daysLeft(expiry, today) {
  return Math.round((Date.parse(`${expiry}T00:00:00Z`) - Date.parse(`${today}T00:00:00Z`)) / 86400000);
}

/**
 * The reminder due on [today] for an [expiry] date (user decision
 * 2026-11-03): once when it enters the last [dueSoonDays] (30), once more
 * 15 days before, then every day from the expiry day on until it's renewed
 * (a new date starts again). [notified] = keys already sent (stored on the
 * item); a step that was missed (added late) is skipped, never sent twice.
 * Returns [{expiry, days, key}] (empty or one).
 */
function expiryAlerts(expiry, today, notified = [], dueSoonDays = DOC_DUE_SOON_DAYS) {
  if (typeof expiry !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(expiry)) return [];
  const days = daysLeft(expiry, today);
  if (days > dueSoonDays) return [];
  const key = days <= 0 ? `expired:${expiry}:${today}`
    : days <= SECOND_REMINDER_DAYS ? `d15:${expiry}`
    : `soon:${expiry}`;
  return new Set(notified).has(key) ? [] : [{ expiry, days, key }];
}

/** [expiryAlerts] for a company document (files / items of the expiring sections). */
function docExpiryAlerts(doc, today, notified = [], dueSoonDays = DOC_DUE_SOON_DAYS) {
  if (doc.kind !== 'file' || !EXPIRING_SECTIONS.includes(doc.section)) return [];
  return expiryAlerts(doc.expiry, today, notified, dueSoonDays);
}

/**
 * Keys of [notified] worth keeping on [today]: daily expired keys of earlier
 * days are dropped, so the stored list doesn't grow every day.
 */
function keptNotified(notified, today) {
  return notified.filter((k) => !/^expired:\d{4}-\d{2}-\d{2}:/.test(k) || k.endsWith(`:${today}`));
}

module.exports = { expiryAlerts, docExpiryAlerts, keptNotified, daysLeft, DOC_DUE_SOON_DAYS, SECOND_REMINDER_DAYS, EXPIRING_SECTIONS };
