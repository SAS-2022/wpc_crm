const test = require('node:test');
const assert = require('node:assert');
const {
  deriveDay, correctedEvents, siteCheckDue, overtimeAskDue, driveStart, driveEnd, saudiTime, overtimeCap,
} = require('./attendance');

const day = '2026-10-20';
const t = (h, m = 0) => saudiTime(day, h * 60 + m);
const base = { endMs: t(17), closeAllMs: t(23, 55), leavesSite: false, overtimeAllowed: false };
// With overtime allowed the tests confirm it at 17:01 ("Start overtime", 2026-10-25) unless `confirm: false`.
const run = (events, o = {}) => deriveDay(
  o.overtimeAllowed && o.confirm !== false ? [...events, { type: 'otStart', at: t(17, 1) }] : events,
  { ...base, now: t(12), ...o },
);

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

// Site checks (2026-10-25): Worker Number Two's 24 Oct — arrived 06:56, phone
// silent from 08:04, never left; closed at 17:00 without overtime.
test('silent phone, no site check answered: closed at the end, overtime unconfirmed', () => {
  const ot = { overtimeAllowed: true, now: t(23, 55) };
  const d = run([{ type: 'in', at: t(6, 56) }], { ...ot, lastSeenAt: t(8, 4) });
  assert.deepEqual([d.checkOutAt, d.checkOutType, d.overtimeMin, d.overtimeEndUnknown, d.lastSeenAt],
    [t(17), 'auto', 0, true, t(8, 4)]);
  // Without overtime there is nothing to confirm.
  assert.equal(run([{ type: 'in', at: t(6, 56) }], { now: t(23, 55) }).overtimeEndUnknown, false);
});

test('site checks answered "still here": overtime up to the last one', () => {
  const events = [{ type: 'in', at: t(6, 56) }, { type: 'seen', at: t(17, 2) }, { type: 'seen', at: t(17, 32) },
    { type: 'seen', at: t(18, 2) }];
  const open = run(events, { overtimeAllowed: true, now: t(18, 10) });
  assert.deepEqual([open.closed, open.inside], [false, true]);
  const d = run(events, { overtimeAllowed: true, now: t(23, 55) });
  assert.deepEqual([d.checkOutAt, d.checkOutType, d.overtimeMin, d.overtimeEndUnknown], [t(18, 2), 'auto', 62, true]);
  // Seen up to the cap: nothing left to confirm.
  const capped = run([...events, { type: 'seen', at: t(20, 5) }], { overtimeAllowed: true, now: t(23, 55) });
  assert.deepEqual([capped.checkOutAt, capped.overtimeMin, capped.overtimeEndUnknown], [t(20), 180, false]);
});

test('a site check that finds them gone checks out at the last time seen', () => {
  const events = [{ type: 'in', at: t(8) }, { type: 'seen', at: t(17, 2) }, { type: 'out', at: t(17, 32), check: true }];
  const d = run(events, { overtimeAllowed: true, now: t(17, 40) });
  assert.deepEqual([d.checkOutAt, d.checkOutType, d.overtimeMin, d.overtimeEndUnknown], [t(17, 2), 'left', 2, false]);
  // Not seen since the end: the end of the work day.
  const early = run([{ type: 'in', at: t(8) }, { type: 'out', at: t(17, 2), check: true }], { overtimeAllowed: true, now: t(17, 5) });
  assert.deepEqual([early.checkOutAt, early.overtimeMin], [t(17), 0]);
  // A geofence exit keeps its own time.
  assert.equal(run([{ type: 'in', at: t(8) }, { type: 'out', at: t(18) }], { now: t(19) }).checkOutAt, t(18));
});

test('site checks are sent after the end, every 30 min, until the cap', () => {
  const inside = { checkInAt: t(8), closed: false, inside: true, overtimeConfirmedAt: t(17, 5) };
  const o = { endMs: t(17), closeAllMs: t(23, 55), overtimeAllowed: true };
  assert.equal(siteCheckDue({ ...inside, overtimeConfirmedAt: null }, { ...o, now: t(17, 13) }), false); // not started
  assert.equal(siteCheckDue(inside, { ...o, now: t(16, 55) }), false);
  assert.equal(siteCheckDue(inside, { ...o, now: t(17, 3) }), true);
  assert.equal(siteCheckDue(inside, { ...o, now: t(17, 13), lastCheckAt: t(17, 3) }), false);
  assert.equal(siteCheckDue(inside, { ...o, now: t(17, 30), lastCheckAt: t(17, 3) }), true); // schedule jitter
  assert.equal(siteCheckDue(inside, { ...o, now: t(20, 5) }), false); // past the 3 h cap
  assert.equal(siteCheckDue(inside, { ...o, now: t(21), overtimeMaxMin: 300 }), true);
  assert.equal(siteCheckDue(inside, { ...o, now: t(17, 3), overtimeAllowed: false }), false);
  assert.equal(siteCheckDue({ ...inside, inside: false }, { ...o, now: t(17, 3) }), false);
  assert.equal(siteCheckDue({ ...inside, closed: true }, { ...o, now: t(17, 3) }), false);
});

// Overtime has to be started (user decisions 2026-10-25).
test('site staff: staying without "Start overtime" counts nothing after the end', () => {
  const events = [{ type: 'in', at: t(8) }, { type: 'out', at: t(18, 30) }];
  const d = run(events, { overtimeAllowed: true, confirm: false, now: t(19) });
  assert.deepEqual([d.overtimeOn, d.overtimeMin, d.afterHoursMin, d.countedMin], [false, 0, 90, 540]);
  // Silent phone, never confirmed: no "end unknown" either.
  assert.equal(run([{ type: 'in', at: t(8) }], { overtimeAllowed: true, confirm: false, now: t(23, 55) }).overtimeEndUnknown, false);
});

test('confirmed at 6 pm, still on site → overtime counts from 5 pm', () => {
  const events = [{ type: 'in', at: t(8) }, { type: 'otStart', at: t(18) }, { type: 'out', at: t(18, 40) }];
  const d = run(events, { overtimeAllowed: true, confirm: false, now: t(19) });
  assert.deepEqual([d.overtimeConfirmedAt, d.overtimeMin, d.checkOutType], [t(18), 100, 'left']);
  // Confirming after leaving the site doesn't count.
  const after = run([{ type: 'in', at: t(8) }, { type: 'out', at: t(18) }, { type: 'otStart', at: t(18, 10) }],
    { overtimeAllowed: true, confirm: false, now: t(19) });
  assert.deepEqual([after.overtimeConfirmedAt, after.overtimeMin], [null, 0]);
  // Without overtime allowed a confirmation changes nothing.
  assert.equal(run(events, { now: t(19) }).overtimeMin, 0);
});

test('"Not today" then "Start overtime" (pressed by mistake) → overtime counts from the end', () => {
  const events = [{ type: 'in', at: t(8) }, { type: 'otDecline', at: t(17, 12) }, { type: 'otStart', at: t(17, 40) },
    { type: 'out', at: t(18) }];
  const d = run(events, { overtimeAllowed: true, confirm: false, now: t(19) });
  assert.deepEqual([d.overtimeOn, d.overtimeDeclined, d.overtimeConfirmedAt, d.overtimeMin], [true, true, t(17, 40), 60]);
});

test('"Start overtime?" asked at end + 10 min, reminded once 30 min later', () => {
  const d = { checkInAt: t(8), closed: false, inside: true, overtimeConfirmedAt: null, overtimeDeclined: false };
  const o = { endMs: t(17), closeAllMs: t(23, 55), overtimeAllowed: true };
  assert.equal(overtimeAskDue(d, { ...o, now: t(17, 5) }), null);
  assert.equal(overtimeAskDue(d, { ...o, now: t(17, 10) }), 'ask');
  assert.equal(overtimeAskDue(d, { ...o, now: t(17, 20), askedAt: t(17, 10) }), null);
  assert.equal(overtimeAskDue(d, { ...o, now: t(17, 40), askedAt: t(17, 10) }), 'remind');
  assert.equal(overtimeAskDue(d, { ...o, now: t(18, 30), askedAt: t(17, 10), remindedAt: t(17, 40) }), null);
  assert.equal(overtimeAskDue({ ...d, overtimeConfirmedAt: t(17, 12) }, { ...o, now: t(17, 40), askedAt: t(17, 10) }), null);
  assert.equal(overtimeAskDue({ ...d, overtimeDeclined: true }, { ...o, now: t(17, 40), askedAt: t(17, 10) }), null);
  assert.equal(overtimeAskDue({ ...d, inside: false }, { ...o, now: t(17, 10) }), null);
  assert.equal(overtimeAskDue(d, { ...o, now: t(17, 10), driver: true }), null);
  assert.equal(overtimeAskDue(d, { ...o, now: t(17, 10), overtimeAllowed: false }), null);
});

const site = { lat: 24.786, lng: 46.796, radius: 100, kind: 'site' };
const home = { lat: 24.70, lng: 46.70, radius: 150, kind: 'home' };
const road = { lat: 24.74, lng: 46.75 };

test('driver overtime starts on the road at end + 10 min, not at the site or home', () => {
  const o = { endMs: t(17), places: [site, home] };
  const live = (p, at = t(17, 9)) => ({ ...p, accuracy: 10, updatedAt: at });
  assert.equal(driveStart({ ...o, now: t(17, 5), live: live(road) }), 'wait');
  assert.equal(driveStart({ ...o, now: t(17, 10), live: live(road) }), 'start');
  assert.equal(driveStart({ ...o, now: t(17, 10), live: live(site) }), 'none');
  assert.equal(driveStart({ ...o, now: t(17, 10), live: live(home) }), 'none');
  assert.equal(driveStart({ ...o, now: t(17, 30), live: live(road, t(17, 5)) }), 'wait'); // 25 min old: too old
  assert.equal(driveStart({ ...o, now: t(17, 30), live: live(road, t(17, 20)) }), 'start');
  assert.equal(driveStart({ ...o, now: t(17, 30), live: live(road, t(17)) }), 'wait');
  assert.equal(driveStart({ ...o, now: t(18, 5), live: null }), 'late');
});

test('driver overtime ends on arriving home or at a site (two fixes there), else the cap', () => {
  const o = { startAt: t(17), capMs: 180 * 60000, places: [site, home] };
  const at = (p, h, m) => ({ ...p, accuracy: 10, t: t(h, m) });
  const points = [at(road, 17, 10), at(home, 18, 20), at(home, 18, 21)];
  assert.deepEqual(driveEnd({ ...o, points, now: t(18, 30) }), { endAt: t(18, 20), place: 'home' });
  // Driving past the site: one fix there doesn't end it.
  assert.equal(driveEnd({ ...o, points: [at(site, 17, 30), at(road, 17, 31)], now: t(17, 40) }), null);
  assert.deepEqual(driveEnd({ ...o, points: [at(road, 19, 50), at(road, 20, 1)], now: t(20, 5) }), { endAt: t(20), place: 'cap' });
  assert.deepEqual(driveEnd({ ...o, points: [at(road, 17, 40)], now: t(20, 5) }), { endAt: t(17, 40), place: null });
  assert.equal(driveEnd({ ...o, points: [at(road, 17, 40)], now: t(19) }), null);
});

test('driving overtime on the day: open while driving, closed at the arrival', () => {
  const events = [{ type: 'in', at: t(7) }, { type: 'out', at: t(15) }, { type: 'in', at: t(18, 30) }, { type: 'out', at: t(18, 40) }];
  const o = { overtimeAllowed: true, confirm: false, leavesSite: true };
  const driving = run(events, { ...o, now: t(18), drive: { startAt: t(17) } });
  assert.deepEqual([driving.closed, driving.overtimeOn], [false, true]);
  const home = run(events, { ...o, now: t(19), drive: { startAt: t(17), endAt: t(18, 50), place: 'home' } });
  assert.deepEqual([home.checkOutAt, home.checkOutType, home.overtimeMin, home.overtimeEndUnknown], [t(18, 50), 'arrivedHome', 110, false]);
  const unknown = run(events, { ...o, now: t(20, 5), drive: { startAt: t(17), endAt: t(17, 40), place: null } });
  assert.deepEqual([unknown.checkOutType, unknown.overtimeMin, unknown.overtimeEndUnknown], ['auto', 40, true]);
  // A check-out while driving ends it.
  const out = run([...events, { type: 'checkOut', at: t(17, 30) }], { ...o, now: t(18), drive: { startAt: t(17) } });
  assert.deepEqual([out.checkOutAt, out.checkOutType, out.overtimeMin], [t(17, 30), 'manual', 30]);
  // No driving overtime: the phone's events as before (back at the site, left at 18:40).
  assert.deepEqual([run(events, { ...o, now: t(19) }).checkOutType, run(events, { ...o, now: t(19) }).overtimeMin], ['left', 0]);
});
