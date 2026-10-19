const test = require('node:test');
const assert = require('node:assert');
const { ALERT_COOLDOWN_MS, issuesToReport } = require('./trackingAlerts');

const day = '2026-10-18';
const t0 = 1_000_000_000_000;

test('a new issue is reported once', () => {
  const r = issuesToReport(['gpsOff'], {}, {}, t0, day);
  assert.deepStrictEqual(r.issues, ['gpsOff']);
  assert.deepStrictEqual(r.active, { gpsOff: day });
});

test('an issue still active is not reported again, even after the cooldown (reconnects)', () => {
  const later = t0 + 3 * ALERT_COOLDOWN_MS;
  const r = issuesToReport(['gpsOff'], { gpsOff: day }, { gpsOff: t0 }, later, day);
  assert.deepStrictEqual(r.issues, []);
  assert.deepStrictEqual(r.active, { gpsOff: day });
});

test('a fixed issue leaves active and is reported when it comes back after the cooldown', () => {
  const fixed = issuesToReport([], { gpsOff: day }, { gpsOff: t0 }, t0 + 60_000, day);
  assert.deepStrictEqual(fixed.active, {});
  const back = issuesToReport(['gpsOff'], fixed.active, { gpsOff: t0 }, t0 + ALERT_COOLDOWN_MS + 1, day);
  assert.deepStrictEqual(back.issues, ['gpsOff']);
});

test('coming back within the cooldown is not reported yet', () => {
  const r = issuesToReport(['gpsOff'], {}, { gpsOff: t0 }, t0 + 60_000, day);
  assert.deepStrictEqual(r.issues, []);
  assert.deepStrictEqual(r.active, {});
});

test('an issue lasting into a new day is reported once that day', () => {
  const r = issuesToReport(['battery'], { battery: '2026-10-17' }, { battery: t0 }, t0 + 86_400_000, day);
  assert.deepStrictEqual(r.issues, ['battery']);
  assert.deepStrictEqual(r.active, { battery: day });
});
