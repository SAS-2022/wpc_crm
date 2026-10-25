const test = require('node:test');
const assert = require('node:assert');
const { wakeStep, MAX_PINGS } = require('./wakePing');

const M = 60 * 1000;
const t0 = Date.parse('2026-10-24T09:00:00Z');
const at = (min) => t0 + min * M;

/** Runs the 5-minute check from [from] to [to] minutes with the phone last heard at [last]. */
function run(from, to, lastSignAt, o = {}) {
  let state = null;
  const pings = [], log = [], notify = [];
  for (let m = from; m <= to; m += 5) {
    const r = wakeStep({ now: at(m), on: true, inHours: true, lastSign: lastSignAt(m), state, ...o });
    state = r.state;
    if (r.ping) pings.push(m);
    log.push(...r.log.map((e) => `${e.type}@${(e.t - t0) / M}`));
    if (r.notify) notify.push(`${m}:${r.notify.minutes}`);
  }
  return { state, pings, log, notify };
}

test('a phone that keeps sending is left alone', () => {
  const r = run(0, 60, (m) => at(m - 1));
  assert.deepEqual([r.pings, r.log, r.notify, r.state], [[], [], [], null]);
});

test('quiet phone: pinged after 10 min, managers told at 30 min when it never answers', () => {
  const r = run(0, 60, () => at(0));
  assert.deepEqual(r.pings, [10, 40]);
  assert.deepEqual(r.notify, ['30:30']); // once a spell
  assert.deepEqual(r.log, ['quiet@0', 'noAnswer@30']);
});

test('a ping that wakes the phone: logged as woken, nobody told', () => {
  // Answers 2 minutes after the ping at 10.
  const r = run(0, 30, (m) => (m >= 15 ? at(m - 1) : at(0)));
  assert.deepEqual(r.pings, [10]);
  assert.deepEqual(r.notify, []);
  assert.deepEqual(r.log, ['quiet@0', 'woken@14']);
  assert.equal(r.state, null);
});

test('outside the person\'s hours: pinged, but nothing logged or sent', () => {
  const r = run(0, 60, () => at(0), { inHours: false });
  assert.deepEqual(r.pings, [10, 40]);
  assert.deepEqual([r.log, r.notify], [[], []]);
});

test('not supposed to share (off duty): no ping, state cleared', () => {
  const r = wakeStep({ now: at(60), on: false, inHours: false, lastSign: at(0), state: { quietSince: at(0), pings: 1, pingAt: at(10) } });
  assert.deepEqual([r.ping, r.state, r.log], [false, null, []]);
});

test('scheduled people: quiet time counts from the start of tracking, not overnight', () => {
  const r = wakeStep({ now: at(5), on: true, inHours: true, lastSign: at(-600), windowStart: at(0), state: null });
  assert.equal(r.ping, false);
  const later = wakeStep({ now: at(10), on: true, inHours: true, lastSign: at(-600), windowStart: at(0), state: null });
  assert.equal(later.ping, true);
});

test('a phone off overnight: logged from the start of the day, managers told 30 min into it', () => {
  // Hours start at 0; the phone has been quiet since 10 hours before.
  const r = run(0, 40, () => at(-600), { hoursStart: at(0) });
  assert.deepEqual(r.notify, ['30:630']);
  assert.deepEqual(r.log, ['quiet@0', 'noAnswer@30']);
});

test('quiet outside hours, back before they start: nothing logged', () => {
  let r = wakeStep({ now: at(0), on: true, inHours: false, lastSign: at(-60), state: null });
  assert.ok(r.ping);
  r = wakeStep({ now: at(5), on: true, inHours: true, lastSign: at(4), hoursStart: at(5), state: r.state });
  assert.deepEqual([r.log, r.state], [[], null]);
});

test('pings stop after the limit in a long spell', () => {
  const r = run(0, 600, () => at(0));
  assert.equal(r.pings.length, MAX_PINGS);
});
