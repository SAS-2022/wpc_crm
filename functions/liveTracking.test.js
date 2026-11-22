const test = require('node:test');
const assert = require('node:assert');
const { tracksLive } = require('./liveTracking');

test('sales execs, KAMs and drivers by role; SM / GM and office staff not alerted', () => {
  for (const role of ['sales_exec', 'kam', 'driver']) assert.equal(tracksLive({ role }), true, role);
  for (const role of ['sales_manager', 'gm', 'worker', 'hr', 'accounting']) assert.equal(tracksLive({ role }), false, role);
});

test('switched on or off per person (users.liveTracking)', () => {
  assert.equal(tracksLive({ role: 'worker', liveTracking: true }), true);
  assert.equal(tracksLive({ role: 'sales_exec', liveTracking: false }), false);
  assert.equal(tracksLive({ role: 'driver', liveTracking: null }), true);
  assert.equal(tracksLive(null), false);
});
