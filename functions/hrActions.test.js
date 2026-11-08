const test = require('node:test');
const assert = require('node:assert');
const { hrActionEvents } = require('./hrActions');

const rec = (extra = {}) => ({ uid: 'w', kind: 'warning', sent: true, cancelled: false, acceptedAt: null, ...extra });
const T = { seconds: 1 };

test('a new record sent to the employee: issued', () => {
  assert.deepStrictEqual(hrActionEvents(null, rec()), { issued: true, accepted: false });
});

test('an internal note: nothing; sent later: issued', () => {
  assert.deepStrictEqual(hrActionEvents(null, rec({ kind: 'note', sent: false })), { issued: false, accepted: false });
  assert.strictEqual(hrActionEvents(rec({ sent: false }), rec()).issued, true);
});

test('edits while waiting do not notify again', () => {
  assert.deepStrictEqual(hrActionEvents(rec(), rec({ title: 'x' })), { issued: false, accepted: false });
});

test('accepted: HR told once; asked again after an edit: issued again', () => {
  assert.deepStrictEqual(hrActionEvents(rec(), rec({ acceptedAt: T })), { issued: false, accepted: true });
  assert.deepStrictEqual(hrActionEvents(rec({ acceptedAt: T }), rec({ acceptedAt: T, notes: 'n' })), { issued: false, accepted: false });
  assert.deepStrictEqual(hrActionEvents(rec({ acceptedAt: T }), rec()), { issued: true, accepted: false });
});

test('cancelled: no longer waiting; restored: issued again; deleted: nothing', () => {
  assert.strictEqual(hrActionEvents(rec(), rec({ cancelled: true })).issued, false);
  assert.strictEqual(hrActionEvents(rec({ cancelled: true }), rec()).issued, true);
  assert.deepStrictEqual(hrActionEvents(rec(), null), { issued: false, accepted: false });
});
