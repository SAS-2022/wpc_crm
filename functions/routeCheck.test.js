const test = require('node:test');
const assert = require('node:assert');
const { spikeTimes, pathMeters, roadPlausible, legFixes, legValue, recheckLeg } = require('./routeCheck');

// About 111 m per 0.001° of latitude; a fix every 27 s.
const p = (i, lat, accuracy = 5) => ({ t: i * 27000, lat, lng: 50.1, accuracy });
// 5 fixes, 4 × 555 m north = 2.2 km in 108 s (~75 km/h), like 10:00 on 25 Oct.
const drive = [0, 1, 2, 3, 4].map((i) => p(i, 26.3 + i * 0.005));

test('pathMeters follows the fixes and ignores jitter', () => {
  assert.strictEqual(Math.round(pathMeters(drive) / 10), 222);
  assert.strictEqual(pathMeters([p(0, 26.3), p(1, 26.30005), p(2, 26.3)]), 0);
});

test('a road route a little longer than the fixes is kept', () => {
  assert.strictEqual(roadPlausible({ meters: 2500, seconds: 120, fixes: drive }), true);
  // Short city move round corners: within 1.4× + 400 m.
  const city = [0, 1, 2, 3, 4].map((i) => p(i, 26.3 + i * 0.001));
  assert.strictEqual(roadPlausible({ meters: 1000, seconds: 120, fixes: city }), true);
});

test('a detour the fixes never made is refused', () => {
  // 25 Oct 10:00: 2.2 km of fixes routed as 5.0 km (would be 165 km/h).
  assert.strictEqual(roadPlausible({ meters: 4985, seconds: 200, fixes: drive }), false);
  assert.deepStrictEqual(legValue({ p: 'x', m: 4985, seconds: 200 }, { fixes: drive, spike: false }), { s: true, m: 2224 });
});

test('sparse fixes keep the older, looser check', () => {
  const sparse = [p(0, 26.3), p(10, 26.32)]; // 270 s apart, 2.2 km straight
  assert.strictEqual(roadPlausible({ meters: 4000, seconds: 300, fixes: sparse }), true);
  assert.strictEqual(roadPlausible({ meters: 6000, seconds: 300, fixes: sparse }), false);
});

test('a rough fix jumping out and back is a spike', () => {
  // 25 Oct 11:58: one 100 m-accuracy fix 257 m south, then back.
  const path = [p(0, 26.25416, 18), p(1, 26.25185, 100), p(2, 26.25416, 5), p(3, 26.25416, 6)];
  const spikes = spikeTimes(path);
  assert.deepStrictEqual([...spikes], [27000]);
  // The leg to the spike is never road-routed, and its distance is ~0.
  const info = legFixes(path, spikes, path[0], path[1]);
  assert.strictEqual(info.spike, true);
  assert.deepStrictEqual(legValue({ p: 'x', m: 300, seconds: 60 }, info), { s: true, m: 0 });
  // A good fix that far out is a real move, not a spike.
  assert.strictEqual(spikeTimes([p(0, 26.25416), p(1, 26.25185, 10), p(2, 26.25416)]).size, 0);
});

test('recheckLeg turns stored loops straight and updates straight distances', () => {
  const info = { fixes: drive, spike: false };
  assert.deepStrictEqual(recheckLeg({ p: 'x', m: 4985 }, info), { s: true, m: 2224 });
  assert.strictEqual(recheckLeg({ p: 'x', m: 2400 }, info), null);
  assert.deepStrictEqual(recheckLeg({ s: true, m: 2200 }, info), { s: true, m: 2224 });
  assert.strictEqual(recheckLeg({ s: true, m: 2224 }, info), null);
});
