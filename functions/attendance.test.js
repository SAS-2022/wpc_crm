const test = require('node:test');
const assert = require('node:assert');
const { deriveDay, saudiTime } = require('./attendance');

const day = '2026-10-20';
const t = (h, m = 0) => saudiTime(day, h * 60 + m);
const base = { endMs: t(17), closeAllMs: t(23, 55), leavesSite: false, overtimeAllowed: false };
const run = (events, o = {}) => deriveDay(events, { ...base, now: t(12), ...o });

test('checked in at the first arrival, whatever the time', () => {
  const d = run([{ type: 'in', at: t(9, 40), siteId: 'hq' }, { type: 'in', at: t(10) }]);
  assert.equal(d.checkInAt, t(9, 40));
  assert.equal(d.siteId, 'hq');
  assert.equal(d.checkInSource, 'auto');
  assert.equal(d.closed, false);
});

test('leaving after 5 pm checks out at that time; overtime counts only when allowed', () => {
  const events = [{ type: 'in', at: t(8) }, { type: 'out', at: t(18, 30) }];
  const no = run(events, { now: t(19) });
  assert.deepEqual([no.checkOutAt, no.checkOutType, no.workedMin, no.countedMin, no.overtimeMin],
    [t(18, 30), 'left', 630, 540, 0]);
  const yes = run(events, { now: t(19), overtimeAllowed: true });
  assert.deepEqual([yes.countedMin, yes.overtimeMin], [630, 90]);
});

test('office: left at 2:40 pm and never came back → checked out at 2:40 once the day ends', () => {
  const events = [{ type: 'in', at: t(8) }, { type: 'out', at: t(14, 40) }];
  assert.equal(run(events, { now: t(16) }).closed, false); // could still come back
  const d = run(events, { now: t(17, 5) });
  assert.deepEqual([d.checkOutAt, d.checkOutType, d.workedMin], [t(14, 40), 'leftEarly', 400]);
});

test('office: out for lunch and back → stays checked in', () => {
  const d = run([{ type: 'in', at: t(8) }, { type: 'out', at: t(12) }, { type: 'in', at: t(13) }], { now: t(16) });
  assert.equal(d.inside, true);
  assert.equal(d.lastExitAt, null);
  assert.equal(d.closed, false);
});

test('sales / drivers: leaving during the day keeps them in; closed at 5 pm', () => {
  const events = [{ type: 'in', at: t(8) }, { type: 'out', at: t(9) }];
  const d = run(events, { now: t(17, 5), leavesSite: true });
  assert.deepEqual([d.checkOutAt, d.checkOutType, d.workedMin], [t(17), 'endOfDay', 540]);
});

test('still at the site at 5 pm: open until they leave', () => {
  const d = run([{ type: 'in', at: t(8) }], { now: t(17, 30) });
  assert.equal(d.closed, false);
});

test('no exit seen by the evening: closed at the end of the work day, marked auto', () => {
  const d = run([{ type: 'in', at: t(8) }], { now: t(23, 56) });
  assert.deepEqual([d.checkOutAt, d.checkOutType], [t(17), 'auto']);
});

test('manual check-out at once; arriving again later doesn\'t reopen, a manual check-in does', () => {
  const events = [{ type: 'in', at: t(8) }, { type: 'checkOut', at: t(15) }, { type: 'in', at: t(15, 30) }];
  const d = run(events, { now: t(16) });
  assert.deepEqual([d.checkOutAt, d.checkOutType, d.closed], [t(15), 'manual', true]);
  const again = run([...events, { type: 'checkIn', at: t(15, 31) }], { now: t(16) });
  assert.equal(again.closed, false);
  assert.equal(again.checkInAt, t(8));
});

test('leaving before any check-in is ignored; events are taken in time order', () => {
  const d = run([{ type: 'in', at: t(9) }, { type: 'out', at: t(7) }], { now: t(10) });
  assert.equal(d.checkInAt, t(9));
  assert.equal(d.inside, true);
});

test('arriving after 5 pm: counted 0 without overtime', () => {
  const d = run([{ type: 'in', at: t(18) }, { type: 'out', at: t(19) }], { now: t(20) });
  assert.deepEqual([d.workedMin, d.countedMin, d.overtimeMin], [60, 0, 0]);
});
