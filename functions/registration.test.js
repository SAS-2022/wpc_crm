const test = require('node:test');
const assert = require('node:assert');
const { registrationRecord, callerIp } = require('./registration');

test('takes the first forwarded address', () => {
  assert.strictEqual(callerIp({ 'x-forwarded-for': '5.1.2.3, 10.0.0.1' }, '10.0.0.1'), '5.1.2.3');
  assert.strictEqual(callerIp({}, '7.7.7.7'), '7.7.7.7');
  assert.strictEqual(callerIp({}, undefined), null);
});

test('keeps known fields only, cut and trimmed', () => {
  const r = registrationRecord(
    { platform: 'android', model: ' SM-A546E ', maker: 'samsung', role: 'gm', emulator: true, os: 'x'.repeat(400) },
    { 'user-agent': 'okhttp', 'x-forwarded-for': '1.2.3.4' },
    null,
  );
  assert.deepStrictEqual(Object.keys(r).sort(), ['emulator', 'ip', 'maker', 'model', 'os', 'platform', 'userAgent']);
  assert.strictEqual(r.model, 'SM-A546E');
  assert.strictEqual(r.os.length, 300);
  assert.strictEqual(r.userAgent, 'okhttp');
});

test('the browser user agent from the app wins', () => {
  const r = registrationRecord({ platform: 'web', userAgent: 'Mozilla/5.0' }, { 'user-agent': 'other' }, '9.9.9.9');
  assert.strictEqual(r.userAgent, 'Mozilla/5.0');
  assert.strictEqual(r.ip, '9.9.9.9');
  assert.strictEqual(r.emulator, undefined);
});
