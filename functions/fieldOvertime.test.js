// Overtime away from the work sites (2026-11-21).
const test = require('node:test');
const assert = require('node:assert');
const { fieldDecide, fieldEnd, staysOf, deriveDay } = require('./attendance');

const MIN = 60000;
const END = Date.UTC(2026, 10, 19, 14, 0); // 17:00 Riyadh
const home = { lat: 24.70, lng: 46.70 };
const showroom = { lat: 24.80, lng: 46.60 };
// A fix every minute at [place] from [from] to [to] (minutes from the end).
const at = (place, from, to) => Array.from({ length: to - from + 1 }, (_, i) => ({ ...place, accuracy: 10, t: END + (from + i) * MIN }));
// Driving between two places, a fix every minute.
const drive = (a, b, from, to) => Array.from({ length: to - from + 1 }, (_, i) => {
  const f = (i + 1) / (to - from + 2);
  return { lat: a.lat + (b.lat - a.lat) * f, lng: a.lng + (b.lng - a.lng) * f, accuracy: 10, t: END + (from + i) * MIN };
});

test('decided 10 min after the end: at home none, elsewhere running, no home only asked', () => {
  assert.strictEqual(fieldDecide({ points: at(showroom, -30, 9), endMs: END, now: END + 5 * MIN, home }), 'wait');
  assert.strictEqual(fieldDecide({ points: at(showroom, -30, 10), endMs: END, now: END + 10 * MIN, home }), 'running');
  assert.strictEqual(fieldDecide({ points: at(home, -30, 10), endMs: END, now: END + 10 * MIN, home }), 'none');
  assert.strictEqual(fieldDecide({ points: at(showroom, -30, 10), endMs: END, now: END + 10 * MIN, home: null }), 'ask');
  // No fix near the end: wait, then late.
  assert.strictEqual(fieldDecide({ points: [], endMs: END, now: END + 20 * MIN, home }), 'wait');
  assert.strictEqual(fieldDecide({ points: [], endMs: END, now: END + 90 * MIN, home }), 'late');
});

test('ends when they left the last job before going home; the drive home does not count', () => {
  const pts = [...at(showroom, -60, 120), ...drive(showroom, home, 121, 160), ...at(home, 161, 200)];
  const r = fieldEnd({ points: pts, startAt: END, now: END + 200 * MIN, capMs: 600 * MIN, home });
  assert.deepStrictEqual(r, { endAt: END + 120 * MIN, place: 'lastJob' }); // 19:00, left the showroom
});

test('two jobs after the end: the last one counts', () => {
  const site2 = { lat: 24.75, lng: 46.65 };
  const pts = [...at(showroom, -30, 30), ...drive(showroom, site2, 31, 50), ...at(site2, 51, 140), ...drive(site2, home, 141, 170), ...at(home, 171, 180)];
  const r = fieldEnd({ points: pts, startAt: END, now: END + 180 * MIN, capMs: 600 * MIN, home });
  assert.deepStrictEqual(r, { endAt: END + 140 * MIN, place: 'lastJob' });
});

test('driving straight home at the end: no overtime (ends at the start)', () => {
  const pts = [...at(showroom, -60, -5), ...drive(showroom, home, -4, 30), ...at(home, 31, 40)];
  const r = fieldEnd({ points: pts, startAt: END, now: END + 40 * MIN, capMs: 600 * MIN, home });
  assert.deepStrictEqual(r, { endAt: END, place: 'lastJob' });
});

test('still working: running; past the cap: the cap; phone silent: the last stay, end unknown', () => {
  const pts = at(showroom, -30, 100);
  assert.strictEqual(fieldEnd({ points: pts, startAt: END, now: END + 100 * MIN, capMs: 180 * MIN, home }), null);
  assert.deepStrictEqual(fieldEnd({ points: at(showroom, -30, 200), startAt: END, now: END + 200 * MIN, capMs: 180 * MIN, home }),
    { endAt: END + 180 * MIN, place: 'cap' });
  assert.deepStrictEqual(fieldEnd({ points: pts, startAt: END, now: END + 200 * MIN, capMs: 180 * MIN, home }),
    { endAt: END + 100 * MIN, place: null });
});

test('stays of 10+ min within 150 m', () => {
  const s = staysOf([...at(showroom, 0, 5), ...drive(showroom, home, 6, 20), ...at(home, 21, 40)]);
  assert.strictEqual(s.length, 1);
  assert.strictEqual(s[0].from, END + 21 * MIN);
});

test('the day stays open while it runs and closes at the last job', () => {
  const o = { startMs: END - 9 * 60 * MIN, endMs: END, closeAllMs: END + 6 * 60 * MIN + 55 * MIN, now: END + 3 * 60 * MIN,
    leavesSite: true, overtimeAllowed: true, overtimeMaxMin: 600 };
  const events = [{ type: 'in', at: END - 9 * 60 * MIN }, { type: 'out', at: END - 8 * 60 * MIN }];
  const running = deriveDay(events, { ...o, drive: { startAt: END, endAt: null, place: null } });
  assert.strictEqual(running.closed, false);
  assert.strictEqual(running.overtimeOn, true);
  const done = deriveDay(events, { ...o, drive: { startAt: END, endAt: END + 120 * MIN, place: 'lastJob' } });
  assert.strictEqual(done.checkOutType, 'lastJob');
  assert.strictEqual(done.overtimeMin, 120);
  // "End overtime" = check out.
  const button = deriveDay([...events, { type: 'checkOut', at: END + 90 * MIN }], { ...o, drive: { startAt: END, endAt: null, place: null } });
  assert.strictEqual(button.checkOutType, 'manual');
  assert.strictEqual(button.overtimeMin, 90);
});
