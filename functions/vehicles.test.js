const test = require('node:test');
const assert = require('node:assert');
const { dayKm, daysLeft, renewalAlerts } = require('./vehicles');

// About 111 m per 0.001° of latitude.
const p = (t, lat, accuracy = 10) => ({ t, lat, lng: 46.7, accuracy });

test('dayKm adds the moves between fixes', () => {
  assert.strictEqual(dayKm([p(0, 24.7), p(1, 24.71), p(2, 24.72)]), 2.2);
});

test('dayKm ignores jitter while standing still', () => {
  // 11 m moves, and a 33 m move within two rough fixes' accuracy.
  assert.strictEqual(dayKm([p(0, 24.7), p(1, 24.7001), p(2, 24.7), p(3, 24.7003, 20), p(4, 24.7, 20)]), 0);
});

test('dayKm counts across gaps without fixes', () => {
  assert.strictEqual(dayKm([p(0, 24.7), p(7200000, 24.8)]), 11.1);
});

test('dayKm of no or one fix is 0', () => {
  assert.strictEqual(dayKm([]), 0);
  assert.strictEqual(dayKm([p(0, 24.7)]), 0);
});

test('daysLeft', () => {
  assert.strictEqual(daysLeft('2026-11-23', '2026-10-24'), 30);
  assert.strictEqual(daysLeft('2026-10-24', '2026-10-24'), 0);
  assert.strictEqual(daysLeft('2026-10-20', '2026-10-24'), -4);
});

const car = (expiries, extra = {}) => ({ expiries, ...extra });

test('reminds once, 14 days before the expiry', () => {
  const v = car({ insurance: '2026-11-07', registration: '2027-05-01' });
  assert.deepStrictEqual(renewalAlerts(v, '2026-10-23'), []);
  const due = renewalAlerts(v, '2026-10-24');
  assert.deepStrictEqual(due, [{ item: 'insurance', expiry: '2026-11-07', days: 14, key: 'insurance:2026-11-07' }]);
  assert.deepStrictEqual(renewalAlerts(v, '2026-11-01', [due[0].key]), []);
  assert.deepStrictEqual(renewalAlerts(v, '2026-11-20', [due[0].key]), []);
});

test('a renewed date starts again', () => {
  const v = car({ insurance: '2027-11-07' });
  assert.deepStrictEqual(renewalAlerts(v, '2027-10-24', ['insurance:2026-11-07']).map((a) => a.key), ['insurance:2027-11-07']);
});

test('added already close or expired: one reminder', () => {
  assert.deepStrictEqual(renewalAlerts(car({ inspection: '2026-10-01' }), '2026-10-24').map((a) => a.days), [-23]);
  assert.deepStrictEqual(renewalAlerts(car({ inspection: '2026-10-30' }), '2026-10-24').map((a) => a.days), [6]);
});

test('inactive vehicles and missing dates: nothing', () => {
  assert.deepStrictEqual(renewalAlerts(car({ insurance: '2026-10-01' }, { active: false }), '2026-10-24'), []);
  assert.deepStrictEqual(renewalAlerts(car({ insurance: null }), '2026-10-24'), []);
  assert.deepStrictEqual(renewalAlerts({}, '2026-10-24'), []);
});

test('the number of days comes from App settings', () => {
  const v = car({ insurance: '2026-11-23' });
  assert.deepStrictEqual(renewalAlerts(v, '2026-10-24'), []);
  assert.deepStrictEqual(renewalAlerts(v, '2026-10-24', [], 30).map((a) => a.days), [30]);
});
