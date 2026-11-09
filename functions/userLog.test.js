const test = require('node:test');
const assert = require('node:assert');
const { userLogEntry } = require('./userLog');

const ts = (ms) => ({ toMillis: () => ms });

test('self-registration: the person themselves', () => {
  const e = userLogEntry(null, { name: 'Eddy K', email: 'e@x.com', role: '', active: false, approval: 'pending', registeredAt: ts(1) }, 'u1');
  assert.strictEqual(e.action, 'registered');
  assert.strictEqual(e.actorId, 'u1');
  assert.deepStrictEqual(e.changes.map((c) => c.field), ['active', 'approval', 'email', 'name', 'role']);
});

test('created by an admin: the stamp', () => {
  const e = userLogEntry(null, { name: 'A', role: 'driver', changedBy: 'admin', changedAt: ts(5) }, 'u2');
  assert.strictEqual(e.action, 'created');
  assert.strictEqual(e.actorId, 'admin');
  assert.strictEqual(e.stamped, true);
});

test('approved / rejected', () => {
  const before = { name: 'A', role: '', active: false, approval: 'pending', changedAt: null };
  const ok = userLogEntry(before, { ...before, role: 'sales_exec', active: true, approval: '', changedBy: 'sm', changedAt: ts(9) }, 'u');
  assert.strictEqual(ok.action, 'approved');
  assert.strictEqual(ok.actorId, 'sm');
  assert.deepStrictEqual(ok.changes.find((c) => c.field === 'role'), { field: 'role', from: '', to: 'sales_exec' });
  const no = userLogEntry(before, { ...before, approval: 'rejected', changedBy: 'gm', changedAt: ts(9) }, 'u');
  assert.strictEqual(no.action, 'rejected');
});

test('old stamp kept = not this writer; own fields = the person', () => {
  const before = { name: 'A', phone: '1', role: 'driver', changedBy: 'sm', changedAt: ts(1) };
  const own = userLogEntry(before, { ...before, phone: '2' }, 'u');
  assert.strictEqual(own.actorId, 'u');
  assert.strictEqual(own.stamped, false);
  const unknown = userLogEntry(before, { ...before, role: 'worker' }, 'u');
  assert.strictEqual(unknown.actorId, null);
});

test('only ignored fields: nothing logged; values made plain', () => {
  const before = { name: 'A', appVersions: { android: { build: 1 } } };
  assert.strictEqual(userLogEntry(before, { ...before, appVersions: { android: { build: 2 } }, menuOrder: ['/'], bottomTabs: ['/map'] }, 'u'), null);
  const e = userLogEntry({ workSchedule: null, joined: null }, {
    workSchedule: { days: [1, 2], start: 480, end: 1020 }, joined: ts(Date.UTC(2026, 0, 1)), changedBy: 'hr', changedAt: ts(3),
  }, 'u');
  assert.deepStrictEqual(e.changes, [
    { field: 'joined', from: null, to: '2026-01-01T00:00:00.000Z' },
    { field: 'workSchedule', from: null, to: '{"days":[1,2],"start":480,"end":1020}' },
  ]);
});
