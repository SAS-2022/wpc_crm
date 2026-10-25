// Leave years (user request 2026-10-24): each person's leave year runs from
// the anniversary of their joining date (`users.joiningDate`) to the day
// before the next one; without a joining date, the calendar year. When a
// year ends its numbers are kept (`leave_history/{uid}_{year}`) and the
// annual leave left moves to the next year: overdrawn days always, days left
// only when HR allows carrying over. Same as leave_rules.dart — keep in sync.

const ANNUAL = 'annual';

/** Types that keep a balance, until HR saves `settings/leaveTypes` (= LeaveType.defaults). */
const DEFAULT_TYPES = [
  { id: 'annual', yearlyDays: 21 },
  { id: 'sick', yearlyDays: 120 },
  { id: 'emergency', yearlyDays: 5 },
  { id: 'marriage', yearlyDays: 5 },
  { id: 'bereavement', yearlyDays: 5 },
  { id: 'paternity', yearlyDays: 3 },
  { id: 'maternity', yearlyDays: 84 },
  { id: 'hajj', yearlyDays: 15 },
];

const pad = (n) => String(n).padStart(2, '0');
const key = (y, m, d) => `${y}-${pad(m)}-${pad(d)}`;
const daysInMonth = (y, m) => new Date(Date.UTC(y, m, 0)).getUTCDate();

/** The joining day and month in [year] ('yyyy-MM-dd'; 29 Feb → 28 Feb). */
function anniversary(joining, year) {
  const [, m, d] = joining.split('-').map(Number);
  return key(year, m, Math.min(d, daysInMonth(year, m)));
}

function validDay(s) {
  return typeof s === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(s) ? s : null;
}

/** The leave year (named by the calendar year it starts in) that [day] falls in. */
function leaveYearOf(joining, day) {
  const year = Number(day.slice(0, 4));
  if (!validDay(joining)) return year;
  return day < anniversary(joining, year) ? year - 1 : year;
}

/** {from, to} of leave year [year], both included. */
function leaveYearRange(joining, year) {
  if (!validDay(joining)) return { from: key(year, 1, 1), to: key(year, 12, 31) };
  const next = anniversary(joining, year + 1);
  const end = new Date(Date.parse(`${next}T00:00:00Z`) - 86400000).toISOString().slice(0, 10);
  return { from: anniversary(joining, year), to: end };
}

/**
 * The closed year's numbers: per type that keeps a balance, entitled (HR's
 * number or the type's, plus adjustments), carried in, used (approved
 * requests whose first day is in the year), remaining; and the annual days
 * moved to the next year.
 */
function closeYear({ types, balance = {}, requests, joining, year, carryOver }) {
  const inYear = (r) => (validDay(r.from) ? leaveYearOf(joining, r.from) === year : r.year === year);
  const out = {};
  for (const t of types) {
    if (t.isLeave === false || typeof t.yearlyDays !== 'number') continue;
    const override = balance.entitled?.[t.id];
    const adjustments = (balance.adjustments || [])
      .filter((a) => a?.typeId === t.id && typeof a.days === 'number')
      .reduce((s, a) => s + a.days, 0);
    const entitled = (typeof override === 'number' ? override : t.yearlyDays) + adjustments;
    const carried = typeof balance.carried?.[t.id] === 'number' ? balance.carried[t.id] : 0;
    const used = requests
      .filter((r) => r.typeId === t.id && r.status === 'approved' && inYear(r))
      .reduce((s, r) => s + (typeof r.days === 'number' ? r.days : 0), 0);
    out[t.id] = { entitled, carried, used, remaining: entitled + carried - used };
  }
  const left = out[ANNUAL]?.remaining ?? 0;
  return { ...leaveYearRange(joining, year), types: out, carriedOut: left < 0 ? left : (carryOver ? left : 0) };
}

module.exports = { leaveYearOf, leaveYearRange, closeYear, DEFAULT_TYPES, ANNUAL };
