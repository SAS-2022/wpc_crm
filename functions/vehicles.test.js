const test = require('node:test');
const assert = require('node:assert');
const { dayKm, dayDistances, daysLeft, renewalAlerts } = require('./vehicles');

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

// 0.0004° ≈ 44 m every 30 s = 1.5 m/s: walking pace.
const walk = (from, t0, n, lat0 = 24.7) => Array.from({ length: n }, (_, k) => p(t0 + k * 30000, lat0 + k * 0.0004));

test('walking (2+ min at walking pace) is not the car\'s km', () => {
  // Drive 2.2 km in 2 min, then walk 8 legs (4 min, ≈ 356 m).
  const pts = [p(0, 24.68), p(60000, 24.69), ...walk(0, 120000, 9)];
  pts[2].lat = 24.7;
  const d = dayDistances(pts);
  assert.strictEqual(d.km, 2.2);
  assert.strictEqual(d.walkKm, 0.4);
  assert.strictEqual(dayKm(pts), 2.2);
});

test('a short slow stretch (traffic) still counts', () => {
  // 1 min at walking pace between fast moves.
  const pts = [p(0, 24.68), p(60000, 24.69), p(90000, 24.6904), p(120000, 24.6908), p(180000, 24.7008)];
  assert.deepStrictEqual(dayDistances(pts), { km: 2.3, walkKm: 0 });
});

test('waiting at a red light does not make a slow crawl walking', () => {
  // Fast, 3 min standing, 1 min crawling, fast.
  const pts = [p(0, 24.68), p(60000, 24.69), p(120000, 24.69), p(180000, 24.69), p(240000, 24.69),
    p(270000, 24.6904), p(300000, 24.6908), p(360000, 24.7008)];
  assert.deepStrictEqual(dayDistances(pts), { km: 2.3, walkKm: 0 });
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

test('renewalAlerts covers the operating card', () => {
  const alerts = renewalAlerts({ expiries: { operatingCard: '2026-11-01' } }, '2026-10-26');
  assert.deepStrictEqual(alerts.map((a) => a.key), ['operatingCard:2026-11-01']);
});

const { vehicleEstimate, oilAlerts } = require('./vehicles');

test('vehicleEstimate adds drivers km after the last reading, inside their spells', () => {
  const v = {
    readings: [{ km: 1000, day: '2026-10-20' }, { km: 1200, day: '2026-10-22' }],
    driverLog: [{ driverId: 'a', from: '2026-10-01', to: '2026-10-24' }, { driverId: 'b', from: '2026-10-25', to: null }],
  };
  const km = [
    { uid: 'a', day: '2026-10-22', km: 50 }, // reading's day: left out
    { uid: 'a', day: '2026-10-23', km: 40.4 },
    { uid: 'a', day: '2026-10-25', km: 99 }, // after a's spell
    { uid: 'b', day: '2026-10-25', km: 10 },
    { uid: 'c', day: '2026-10-25', km: 77 }, // never on it
  ];
  assert.strictEqual(vehicleEstimate(v, km), 1250);
  assert.strictEqual(vehicleEstimate({ driverLog: v.driverLog }, km), null);
});

test('oilAlerts: soon once, due once, again after a new change', () => {
  const v = { oilIntervalKm: 5000, oilLog: [{ km: 10000, day: '2026-09-01' }] };
  assert.deepStrictEqual(oilAlerts(v, 14000), []);
  assert.deepStrictEqual(oilAlerts(v, 14600), [{ key: 'oil:15000:soon', nextKm: 15000, kmLeft: 400 }]);
  assert.deepStrictEqual(oilAlerts(v, 14600, ['oil:15000:soon']), []);
  assert.deepStrictEqual(oilAlerts(v, 15100, ['oil:15000:soon']), [{ key: 'oil:15000:due', nextKm: 15000, kmLeft: -100 }]);
  // Jumped straight past due: only the due one.
  assert.deepStrictEqual(oilAlerts(v, 15100).map((a) => a.key), ['oil:15000:due']);
  const changed = { ...v, oilLog: [...v.oilLog, { km: 15100, day: '2026-10-26' }] };
  assert.deepStrictEqual(oilAlerts(changed, 15100, ['oil:15000:soon', 'oil:15000:due']), []);
  assert.deepStrictEqual(oilAlerts(changed, 19700).map((a) => a.key), ['oil:20100:soon']);
});

test('oilAlerts needs an interval, a recorded change and an estimate', () => {
  assert.deepStrictEqual(oilAlerts({ oilLog: [{ km: 1, day: '2026-01-01' }] }, 99999), []);
  assert.deepStrictEqual(oilAlerts({ oilIntervalKm: 5000 }, 99999), []);
  assert.deepStrictEqual(oilAlerts({ oilIntervalKm: 5000, oilLog: [{ km: 1, day: '2026-01-01' }] }, null), []);
  assert.deepStrictEqual(oilAlerts({ active: false, oilIntervalKm: 5000, oilLog: [{ km: 1, day: '2026-01-01' }] }, 99999), []);
});
