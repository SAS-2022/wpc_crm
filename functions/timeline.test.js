const test = require('node:test');
const assert = require('node:assert');
const { buildDayTimeline } = require('./timeline');
const { saudiTime } = require('./attendance');

const day = '2026-10-20';
const t = (h, m = 0) => saudiTime(day, h * 60 + m);
// ~0.009° latitude ≈ 1 km.
const office = { lat: 24.70, lng: 46.68 };
const clientA = { lat: 24.75, lng: 46.68 }; // ~5.5 km north
const clientB = { lat: 24.75, lng: 46.73 }; // ~5 km east of A
const cafe = { lat: 24.72, lng: 46.70 };

/** A point every 30 s while staying at [place] from [a] to [b] (ms). */
function stay(place, a, b) {
  const out = [];
  for (let x = a; x <= b; x += 30000) out.push({ t: x, ...place, accuracy: 10 });
  return out;
}
/** Points every 30 s moving in a straight line from [p] to [q]. */
function drive(p, q, a, b) {
  const out = [];
  const n = Math.max(1, Math.round((b - a) / 30000));
  for (let k = 1; k < n; k++) {
    out.push({ t: a + k * 30000, lat: p.lat + ((q.lat - p.lat) * k) / n, lng: p.lng + ((q.lng - p.lng) * k) / n, accuracy: 10 });
  }
  return out;
}

const points = [
  ...stay(office, t(8), t(8, 30)),
  ...drive(office, clientA, t(8, 30), t(8, 50)),
  ...stay(clientA, t(8, 50), t(9, 30)),
  ...drive(clientA, cafe, t(9, 30), t(9, 45)),
  ...stay(cafe, t(9, 45), t(13, 20)), // 215 min: lunch 60 + stopped 155
  ...drive(cafe, clientB, t(13, 20), t(13, 40)),
  ...stay(clientB, t(13, 40), t(14, 10)),
];
const visits = [
  { id: 'v1', clientId: 'A', at: t(8, 55), ...clientA },
  { id: 'v2', clientId: 'B', at: t(13, 45), ...clientB },
];
const sites = [{ id: 'hq', ...office, radius: 100 }];

test('a day split into office, client, driving, lunch, stopped and no data', () => {
  const d = buildDayTimeline({ points, visits, sites, startMs: t(8), endMs: t(17) });
  const near = (actual, expected, label) => assert.ok(Math.abs(actual - expected) <= 2, `${label} ${actual} ≠ ${expected}`);
  near(d.minutes.office, 30, 'office');
  near(d.minutes.client, 70, 'client');
  assert.equal(d.minutes.lunch, 60);
  near(d.minutes.stopped, 155, 'stopped');
  assert.ok(d.minutes.driving >= 48 && d.minutes.driving <= 55, `driving ${d.minutes.driving}`); // stay edges take a little
  near(d.minutes.noData, 170, 'noData'); // nothing after 14:10
  const total = Object.values(d.minutes).reduce((s, n) => s + n, 0);
  near(total, 540, 'total');
  assert.deepEqual(d.clientStays.map((s) => s.clientId), ['A', 'B']);
  near((d.firstClientAt - t(8, 50)) / 60000, 0, 'first client');
  near((d.lastClientAt - t(14, 10)) / 60000, 0, 'last client');
  assert.ok(d.drivingKm > 13 && d.drivingKm < 20, `km ${d.drivingKm}`);
  assert.ok(d.between.drivingKm > 7 && d.between.drivingKm < 10, `between km ${d.between.drivingKm}`);
  assert.equal(d.between.lunch, 60);
});

test('a long gap while moving is unknown time, not driving', () => {
  const pts = [...stay(clientA, t(9), t(9, 30)), ...stay(clientB, t(11), t(11, 30))];
  const d = buildDayTimeline({ points: pts, visits: [], sites: [], startMs: t(9), endMs: t(11, 30) });
  assert.equal(d.minutes.noData, 90);
});

test('a quiet phone that stays in one place is still a stay', () => {
  const pts = [{ t: t(10), ...clientA }, { t: t(10, 40), ...clientA }];
  const d = buildDayTimeline({ points: pts, visits: [{ id: 'v', clientId: 'A', at: t(10, 5), ...clientA }], sites: [], startMs: t(10), endMs: t(10, 40) });
  assert.equal(d.minutes.client, 40);
});

test('a stray GPS fix doesn\'t break a stay into driving', () => {
  const pts = stay(clientA, t(10), t(10, 30));
  pts[20] = { ...pts[20], lat: clientA.lat + 0.004 }; // one fix ~450 m off
  const d = buildDayTimeline({ points: pts, visits: [{ id: 'v', clientId: 'A', at: t(10, 5), ...clientA }], sites: [], startMs: t(10), endMs: t(10, 30) });
  assert.equal(d.minutes.client, 30);
  assert.equal(d.minutes.driving, 0);
});
