const test = require('node:test');
const assert = require('node:assert');
const { alertId, newAlert, escalationTargets, escalationStep, escalated, autoAction, checkedIn } = require('./teamAlerts');

// Small stand-in for directManagers: chosen managerId, else GM.
const managersOf = (u, uid, users) => {
  if (u.role === 'gm') return [];
  const m = users.find((x) => x.id === u.managerId);
  return m ? [m.id] : users.filter((x) => x.role === 'gm' && x.id !== uid).map((x) => x.id);
};
const users = [
  { id: 'gm', role: 'gm' },
  { id: 'lm', role: 'logistics_manager', managerId: 'gm' },
  { id: 'ws', role: 'warehouse_supervisor', managerId: 'lm' },
  { id: 'w', role: 'worker', managerId: 'ws' },
];

test('new alert: told people, never the employee, escalates after the delay', () => {
  const a = newAlert({ kind: 'late', uid: 'w', date: '2026-11-11', ref: 'w', toIds: ['ws', 'w', 'ws'] }, 1000, 30);
  assert.deepStrictEqual(a.toIds, ['ws']);
  assert.deepStrictEqual(a.allIds, ['ws']);
  assert.strictEqual(a.nextAt, 1000 + 30 * 60000);
  assert.strictEqual(a.status, 'open');
  assert.strictEqual(alertId('late', 'w_2026-11-11'), 'late_w_2026-11-11');
});

test('escalates one level at a time up to the top', () => {
  let a = newAlert({ kind: 'late', uid: 'w', date: '2026-11-11', ref: 'w', toIds: ['ws'] }, 0, 30);
  assert.deepStrictEqual(escalationTargets(a, users, managersOf), ['lm']);
  a = { ...a, ...escalated(a, ['lm'], 10, 30) };
  assert.strictEqual(a.level, 1);
  assert.deepStrictEqual(a.allIds, ['ws', 'lm']);
  assert.deepStrictEqual(escalationTargets(a, users, managersOf), ['gm']);
  a = { ...a, ...escalated(a, ['gm'], 20, 30) };
  assert.deepStrictEqual(escalationTargets(a, users, managersOf), []);
  assert.deepStrictEqual(escalated(a, [], 30, 30), { nextAt: null, topReached: true });
});

test('told people who left the company: goes up from the employee', () => {
  const a = { uid: 'w', toIds: ['gone'], allIds: ['gone'] };
  assert.deepStrictEqual(escalationTargets(a, users, managersOf), ['ws']);
});

test('escalation step: waits, escalates when due, stops after its day', () => {
  const a = { status: 'open', nextAt: 100, date: '2026-11-11' };
  assert.strictEqual(escalationStep(a, 50, '2026-11-11'), 'wait');
  assert.strictEqual(escalationStep(a, 100, '2026-11-11'), 'escalate');
  assert.strictEqual(escalationStep(a, 100, '2026-11-12'), 'stop');
  assert.strictEqual(escalationStep({ ...a, status: 'done' }, 100, '2026-11-11'), 'wait');
  assert.strictEqual(escalationStep({ ...a, nextAt: null }, 100, '2026-11-11'), 'wait');
});

test('a decision on the request counts as the action', () => {
  assert.deepStrictEqual(
    autoAction('break', { status: 'pending' }, { status: 'approved', decidedBy: 'ws' }),
    { taken: true, auto: 'approved', byId: 'ws', note: '' },
  );
  assert.strictEqual(autoAction('break', { status: 'pending' }, { status: 'pending' }), null);
  assert.strictEqual(autoAction('earlyCheckout', null, { status: 'pending' }), null);
  assert.strictEqual(autoAction('earlyCheckout', { status: 'pending' }, null).auto, 'cancelled');
  assert.strictEqual(
    autoAction('absence', { status: 'pending' }, { status: 'pending', managerStep: { status: 'approved', byId: 'lm' } }).byId,
    'lm',
  );
  assert.strictEqual(autoAction('absence', { status: 'pending' }, { status: 'rejected', decidedBy: 'hr' }).auto, 'rejected');
  assert.strictEqual(autoAction('late', { a: 1 }, { a: 2 }), null);
});

test('late: checked in = the follow-up ends (any arrival, also HR)', () => {
  assert.strictEqual(checkedIn(null), false);
  assert.strictEqual(checkedIn({ events: [] }), false);
  assert.strictEqual(checkedIn({ events: [{ type: 'out' }, { type: 'seen' }] }), false);
  assert.strictEqual(checkedIn({ events: [{ type: 'in' }] }), true);
  assert.strictEqual(checkedIn({ events: [{ type: 'checkIn' }] }), true);
  assert.strictEqual(checkedIn({ checkInAt: new Date() }), true);
  assert.strictEqual(checkedIn({ correction: { checkInAt: new Date() } }), true);
});
