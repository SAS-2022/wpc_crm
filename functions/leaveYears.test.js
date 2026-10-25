const test = require('node:test');
const assert = require('node:assert');
const { leaveYearOf, leaveYearRange, closeYear, DEFAULT_TYPES } = require('./leaveYears');

test('leave years follow the joining anniversary, else the calendar', () => {
  assert.strictEqual(leaveYearOf(null, '2026-03-01'), 2026);
  assert.deepStrictEqual(leaveYearRange(null, 2026), { from: '2026-01-01', to: '2026-12-31' });
  assert.strictEqual(leaveYearOf('2023-03-15', '2026-03-14'), 2025);
  assert.strictEqual(leaveYearOf('2023-03-15', '2026-03-15'), 2026);
  assert.deepStrictEqual(leaveYearRange('2023-03-15', 2026), { from: '2026-03-15', to: '2027-03-14' });
  assert.deepStrictEqual(leaveYearRange('2024-02-29', 2025), { from: '2025-02-28', to: '2026-02-27' });
});

const req = (from, days, extra = {}) => ({ typeId: 'annual', status: 'approved', from, days, ...extra });

test('overdrawn annual days move to the next year even without carry-over', () => {
  const r = closeYear({
    types: DEFAULT_TYPES, joining: '2023-03-15', year: 2025, carryOver: false,
    requests: [req('2025-04-01', 20), req('2026-01-10', 4), req('2026-03-20', 9), req('2025-05-01', 5, { status: 'rejected' })],
  });
  assert.deepStrictEqual(r.types.annual, { entitled: 21, carried: 0, used: 24, remaining: -3 });
  assert.strictEqual(r.carriedOut, -3);
  assert.strictEqual(r.from, '2025-03-15');
  assert.strictEqual(r.to, '2026-03-14');
});

test('days left: carried over only when allowed', () => {
  const base = { types: DEFAULT_TYPES, joining: null, year: 2026, requests: [req('2026-06-01', 6)] };
  assert.strictEqual(closeYear({ ...base, carryOver: false }).carriedOut, 0);
  assert.strictEqual(closeYear({ ...base, carryOver: true }).carriedOut, 15);
});

test("HR's numbers, adjustments and last year's carry count", () => {
  const r = closeYear({
    types: DEFAULT_TYPES, joining: null, year: 2026, carryOver: true,
    balance: { entitled: { annual: 30 }, adjustments: [{ typeId: 'annual', days: 2 }, { typeId: 'sick', days: 1 }], carried: { annual: -4 } },
    requests: [req('2026-02-01', 10), { typeId: 'sick', status: 'approved', from: '2026-02-01', days: 3 }],
  });
  assert.deepStrictEqual(r.types.annual, { entitled: 32, carried: -4, used: 10, remaining: 18 });
  assert.deepStrictEqual(r.types.sick, { entitled: 121, carried: 0, used: 3, remaining: 118 });
  assert.strictEqual(r.carriedOut, 18);
});

test('types without a yearly limit and non-leave requests keep no record', () => {
  const r = closeYear({ types: [...DEFAULT_TYPES, { id: 'unpaid' }, { id: 'letter', isLeave: false, yearlyDays: 1 }], joining: null, year: 2026, carryOver: false, requests: [] });
  assert.ok(!('unpaid' in r.types));
  assert.ok(!('letter' in r.types));
});
