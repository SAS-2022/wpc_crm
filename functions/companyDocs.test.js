const test = require('node:test');
const assert = require('node:assert');
const { docExpiryAlerts, expiryAlerts, keptNotified } = require('./companyDocs');

const doc = (expiry, more = {}) => ({ kind: 'file', section: 'expiring', expiry, ...more });

test('nothing while more than the reminder days are left', () => {
  assert.deepStrictEqual(docExpiryAlerts(doc('2026-12-15'), '2026-11-01'), []);
});

test('reminds once when it enters the last 30 days', () => {
  assert.deepStrictEqual(docExpiryAlerts(doc('2026-12-01'), '2026-11-01'),
    [{ expiry: '2026-12-01', days: 30, key: 'soon:2026-12-01' }]);
  assert.deepStrictEqual(docExpiryAlerts(doc('2026-12-01'), '2026-11-10', ['soon:2026-12-01']), []);
});

test('reminds again 15 days before, once', () => {
  assert.deepStrictEqual(docExpiryAlerts(doc('2026-12-01'), '2026-11-16', ['soon:2026-12-01']),
    [{ expiry: '2026-12-01', days: 15, key: 'd15:2026-12-01' }]);
  assert.deepStrictEqual(docExpiryAlerts(doc('2026-12-01'), '2026-11-25', ['soon:2026-12-01', 'd15:2026-12-01']), []);
});

test('every day from the expiry day on', () => {
  const sent = ['soon:2026-12-01', 'd15:2026-12-01'];
  assert.deepStrictEqual(docExpiryAlerts(doc('2026-12-01'), '2026-12-01', sent),
    [{ expiry: '2026-12-01', days: 0, key: 'expired:2026-12-01:2026-12-01' }]);
  assert.deepStrictEqual(docExpiryAlerts(doc('2026-12-01'), '2026-12-01', [...sent, 'expired:2026-12-01:2026-12-01']), []);
  assert.deepStrictEqual(docExpiryAlerts(doc('2026-12-01'), '2026-12-02', [...sent, 'expired:2026-12-01:2026-12-01']),
    [{ expiry: '2026-12-01', days: -1, key: 'expired:2026-12-01:2026-12-02' }]);
});

test('added late: only the step it is in', () => {
  assert.deepStrictEqual(docExpiryAlerts(doc('2026-11-10'), '2026-11-01'),
    [{ expiry: '2026-11-10', days: 9, key: 'd15:2026-11-10' }]);
  assert.deepStrictEqual(docExpiryAlerts(doc('2026-10-01'), '2026-11-01'),
    [{ expiry: '2026-10-01', days: -31, key: 'expired:2026-10-01:2026-11-01' }]);
});

test('a renewed date starts again', () => {
  assert.strictEqual(docExpiryAlerts(doc('2027-11-20'), '2027-11-01', ['soon:2026-12-01', 'expired:2026-12-01:2026-12-05']).length, 1);
});

test('uses the reminder days setting', () => {
  assert.deepStrictEqual(docExpiryAlerts(doc('2026-11-20'), '2026-11-01', [], 14), []);
  assert.strictEqual(docExpiryAlerts(doc('2026-11-10'), '2026-11-01', [], 14).length, 1);
});

test('services and subscriptions with a date only', () => {
  assert.strictEqual(docExpiryAlerts(doc('2026-11-05', { section: 'subscription' }), '2026-11-01').length, 1);
  assert.deepStrictEqual(docExpiryAlerts(doc('2026-11-05', { section: 'official' }), '2026-11-01'), []);
  assert.deepStrictEqual(docExpiryAlerts(doc('2026-11-05', { kind: 'folder' }), '2026-11-01'), []);
  assert.deepStrictEqual(docExpiryAlerts(doc(''), '2026-11-01'), []);
});

test('Iqama / ID dates use the same steps', () => {
  assert.deepStrictEqual(expiryAlerts('2026-12-01', '2026-11-01'), [{ expiry: '2026-12-01', days: 30, key: 'soon:2026-12-01' }]);
  assert.deepStrictEqual(expiryAlerts(undefined, '2026-11-01'), []);
});

test('earlier daily keys are dropped from the stored list', () => {
  assert.deepStrictEqual(
    keptNotified(['soon:2026-12-01', 'd15:2026-12-01', 'expired:2026-12-01:2026-12-01', 'expired:2026-12-01:2026-12-02'], '2026-12-02'),
    ['soon:2026-12-01', 'd15:2026-12-01', 'expired:2026-12-01:2026-12-02'],
  );
});
