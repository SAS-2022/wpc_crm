const test = require('node:test');
const assert = require('node:assert');
const { leaveReminderDue, awaitingUids, DAY_MS } = require('./leaveReminders');

const H = 60 * 60 * 1000;
const t0 = Date.parse('2026-10-30T09:00:00Z');
const req = (o = {}) => ({ status: 'pending', awaitingKey: 'uid:m', stepIndex: 0, createdAt: t0, steps: [{}, {}], ...o });

test('first reminder 24 h after the request, then every 24 h', () => {
  assert.deepStrictEqual(leaveReminderDue(req(), t0 + 23 * H), { due: false, days: 0 });
  assert.deepStrictEqual(leaveReminderDue(req(), t0 + 24 * H), { due: true, days: 1 });
  const reminded = req({ reminded: { step: 0, at: t0 + 25 * H } });
  assert.strictEqual(leaveReminderDue(reminded, t0 + 48 * H).due, false);
  assert.deepStrictEqual(leaveReminderDue(reminded, t0 + 49 * H), { due: true, days: 2 });
});

test('the next step counts from the previous approval, not the old reminder', () => {
  const r = req({ stepIndex: 1, awaitingKey: 'role:hr', steps: [{ at: t0 + 30 * H }, {}], reminded: { step: 0, at: t0 + 24 * H } });
  assert.strictEqual(leaveReminderDue(r, t0 + 53 * H).due, false);
  assert.deepStrictEqual(leaveReminderDue(r, t0 + 54 * H), { due: true, days: 1 });
});

test('decided or cancelled requests are never reminded', () => {
  for (const status of ['approved', 'rejected', 'cancelled']) {
    assert.strictEqual(leaveReminderDue(req({ status }), t0 + 5 * DAY_MS).due, false);
  }
  assert.strictEqual(leaveReminderDue(req({ awaitingKey: null }), t0 + 5 * DAY_MS).due, false);
});

test('approvers: the person, or everyone active with the role but the requester', () => {
  const users = [
    { id: 'm', role: 'kam', active: true },
    { id: 'hr1', role: 'hr', active: true },
    { id: 'hr2', role: 'hr', active: false },
    { id: 'me', role: 'hr', active: true },
  ];
  assert.deepStrictEqual(awaitingUids('uid:m', 'me', users), ['m']);
  assert.deepStrictEqual(awaitingUids('role:hr', 'me', users), ['hr1']);
  assert.deepStrictEqual(awaitingUids('uid:gone', 'me', users), []);
});
