const test = require('node:test');
const assert = require('node:assert');
const { deriveDay, correctedEvents, saudiTime, overtimeCap } = require('./attendance');

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

test('office: left at 2:40 pm and away over 30 min → checked out at 2:40', () => {
  const events = [{ type: 'in', at: t(8) }, { type: 'out', at: t(14, 40) }];
  assert.equal(run(events, { now: t(15, 5) }).closed, false); // could still come back
  const d = run(events, { now: t(15, 10) });
  assert.deepEqual([d.checkOutAt, d.checkOutType, d.workedMin], [t(14, 40), 'leftSite', 400]);
  assert.equal(run(events, { now: t(15, 20), awayGraceMin: 45 }).closed, false); // App settings
});

test('office: left at 4:45 pm → checked out at 4:45 once the day ends', () => {
  const d = run([{ type: 'in', at: t(8) }, { type: 'out', at: t(16, 45) }], { now: t(17, 5) });
  assert.deepEqual([d.checkOutAt, d.checkOutType], [t(16, 45), 'leftEarly']);
});

test('office: out 20 min and back → stays checked in, the time counts', () => {
  const events = [{ type: 'in', at: t(8) }, { type: 'out', at: t(12) }, { type: 'in', at: t(12, 20) }];
  const d = run(events, { now: t(16) });
  assert.deepEqual([d.inside, d.lastExitAt, d.closed, d.awayMin], [true, null, false, 0]);
  const out = run([...events, { type: 'out', at: t(17, 10) }], { now: t(18) });
  assert.equal(out.countedMin, 540);
});

test('office: out for an hour and back → checked in again, the hour away does not count', () => {
  const events = [{ type: 'in', at: t(8) }, { type: 'out', at: t(12) }, { type: 'in', at: t(13) }];
  const d = run(events, { now: t(16) });
  assert.deepEqual([d.inside, d.closed, d.checkInAt, d.awayMin], [true, false, t(8), 60]);
  const out = run([...events, { type: 'out', at: t(17, 10) }], { now: t(18) });
  assert.deepEqual([out.checkOutType, out.countedMin, out.workedMin, out.afterHoursMin], ['left', 480, 490, 10]);
});

test('office: checked out for leaving, back only after 5 pm → stays checked out', () => {
  const d = run([{ type: 'in', at: t(8) }, { type: 'out', at: t(15) }, { type: 'in', at: t(17, 20) }], { now: t(18) });
  assert.deepEqual([d.checkOutAt, d.checkOutType], [t(15), 'leftSite']);
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
  // The 31 minutes between the check-out and the check-in don't count.
  const out = run([...events, { type: 'checkIn', at: t(15, 31) }, { type: 'checkOut', at: t(16) }], { now: t(16) });
  assert.deepEqual([out.awayMin, out.countedMin], [31, 449]);
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

test('lateness from the start of the work day; none on a day off', () => {
  const events = [{ type: 'in', at: t(8, 22) }];
  assert.equal(run(events, { startMs: t(8) }).lateMin, 22);
  assert.equal(run([{ type: 'in', at: t(8, 15) + 59000 }], { startMs: t(8) }).lateMin, 0); // 8:15:59 – grace
  assert.equal(run([{ type: 'in', at: t(8, 16) }], { startMs: t(8) }).lateMin, 16);
  assert.equal(run([{ type: 'in', at: t(7, 50) }], { startMs: t(8) }).lateMin, 0);
  assert.equal(run(events, { startMs: null }).lateMin, null);
  assert.equal(run([], { startMs: t(8) }).lateMin, null);
});

test('without overtime the time stayed after the end is recorded, not counted', () => {
  const events = [{ type: 'in', at: t(8) }, { type: 'out', at: t(17, 45) }];
  const no = run(events, { now: t(19) });
  assert.deepEqual([no.countedMin, no.overtimeMin, no.afterHoursMin], [540, 0, 45]);
  const yes = run(events, { now: t(19), overtimeAllowed: true });
  assert.deepEqual([yes.countedMin, yes.overtimeMin, yes.afterHoursMin], [585, 45, 0]);
});

test('HR correction replaces the phone\'s events', () => {
  const phone = [{ type: 'in', at: t(9, 30) }, { type: 'out', at: t(12) }, { type: 'in', at: t(14) }];
  const full = run(correctedEvents(phone, { checkInAt: t(8), checkOutAt: t(17), siteId: 'hq' }), { now: t(18) });
  assert.deepEqual([full.checkInAt, full.checkInSource, full.siteId, full.checkOutAt, full.checkOutType, full.countedMin],
    [t(8), 'hr', 'hq', t(17), 'hr', 540]);
  // Only the check-in corrected: the phone's later events go on.
  const inOnly = run(correctedEvents(phone.slice(0, 2), { checkInAt: t(8) }), { now: t(13) });
  assert.deepEqual([inOnly.checkInAt, inOnly.closed, inOnly.checkOutType], [t(8), true, 'leftSite']);
  // No correction: HR event types written by a phone are dropped.
  assert.deepEqual(correctedEvents([...phone, { type: 'hrOut', at: t(10) }], null), phone);
});

test('overtime is capped at 3 hours unless the person has a higher cap', () => {
  const events = [{ type: 'in', at: t(8) }, { type: 'out', at: t(21, 30) }];
  const d = run(events, { now: t(22), overtimeAllowed: true });
  assert.deepEqual([d.workedMin, d.overtimeMin, d.afterHoursMin, d.countedMin], [810, 180, 90, 720]);
  const more = run(events, { now: t(22), overtimeAllowed: true, overtimeMaxMin: 300 });
  assert.deepEqual([more.overtimeMin, more.afterHoursMin, more.countedMin], [270, 0, 810]);
  assert.equal(overtimeCap(undefined), 180);
  assert.equal(overtimeCap(300), 300);
  assert.equal(overtimeCap(0), 180);
});

test('no exit seen, overtime allowed: closed when last seen at the site (GPS), within the cap', () => {
  const events = [{ type: 'in', at: t(8) }];
  const seen = run(events, { now: t(23, 55), overtimeAllowed: true, lastSeenAt: t(19, 10) });
  assert.deepEqual([seen.checkOutAt, seen.checkOutType, seen.overtimeMin], [t(19, 10), 'auto', 130]);
  const late = run(events, { now: t(23, 55), overtimeAllowed: true, lastSeenAt: t(23) });
  assert.deepEqual([late.checkOutAt, late.overtimeMin], [t(20), 180]);
  // Last seen before the end (the phone went quiet): the end of the work day, as before.
  const quiet = run([...events, { type: 'in', at: t(11, 20) }], { now: t(23, 55), overtimeAllowed: true, lastSeenAt: t(12, 10) });
  assert.deepEqual([quiet.checkOutAt, quiet.overtimeMin], [t(17), 0]);
  // Without overtime the evidence doesn't matter.
  const no = run(events, { now: t(23, 55), lastSeenAt: t(19, 10) });
  assert.deepEqual([no.checkOutAt, no.overtimeMin], [t(17), 0]);
});

test('an arrival event after the end counts as being seen there', () => {
  const d = run([{ type: 'in', at: t(8) }, { type: 'in', at: t(18, 30) }], { now: t(23, 55), overtimeAllowed: true });
  assert.deepEqual([d.checkOutAt, d.overtimeMin], [t(18, 30), 90]);
});
