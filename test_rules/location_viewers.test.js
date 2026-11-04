// Employee map (2026-11-04): department heads and warehouse supervisors read
// the location data of the people under them via RTDB `location_viewers`
// (written by the syncLocationViewers function), nobody else's.
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { ref, get, set } from 'firebase/database';

let env;

const roles = { fm: 'factory_manager', ws: 'warehouse_supervisor', worker: 'worker', op: 'operator', acc: 'accounting' };

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-wpc-rules',
    database: { rules: readFileSync('../database.rules.json', 'utf8') },
  });
});

after(() => env.cleanup());

beforeEach(async () => {
  await env.clearDatabase();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.database();
    for (const [uid, role] of Object.entries(roles)) await set(ref(db, `roles/${uid}`), role);
    for (const uid of ['worker', 'op']) {
      await set(ref(db, `live_locations/${uid}`), { lat: 1, lng: 2, updatedAt: 1 });
      await set(ref(db, `presence/${uid}`), { online: true });
      await set(ref(db, `location_history/${uid}/2026-11-04/p1`), { lat: 1, lng: 2, t: 1 });
      await set(ref(db, `device_status/${uid}`), { platform: 'android', at: 1 });
    }
    // The worker is under the warehouse supervisor; the operator under the factory manager.
    await set(ref(db, 'location_viewers'), { worker: { ws: true }, op: { fm: true } });
  });
});

const rtdb = (uid) => env.authenticatedContext(uid).database();
const paths = (uid) => [`live_locations/${uid}`, `presence/${uid}`, `location_history/${uid}`, `device_status/${uid}`];

describe('location_viewers', () => {
  test('a warehouse supervisor reads the people they supervise, not others', async () => {
    for (const p of paths('worker')) await assertSucceeds(get(ref(rtdb('ws'), p)));
    for (const p of paths('op')) await assertFails(get(ref(rtdb('ws'), p)));
  });

  test('a department head reads their department, not others', async () => {
    for (const p of paths('op')) await assertSucceeds(get(ref(rtdb('fm'), p)));
    for (const p of [`live_locations/worker`, `presence/worker`, `location_history/worker`]) {
      await assertFails(get(ref(rtdb('fm'), p)));
    }
  });

  test('others read nothing; nobody reads or writes the list itself', async () => {
    for (const p of paths('worker')) await assertFails(get(ref(rtdb('acc'), p)));
    await assertFails(get(ref(rtdb('ws'), 'live_locations')));
    await assertFails(get(ref(rtdb('ws'), 'location_viewers')));
    await assertFails(set(ref(rtdb('ws'), 'location_viewers/op/ws'), true));
  });
});
