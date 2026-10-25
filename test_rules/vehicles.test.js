// Security rules for vehicles (`vehicles`, `driver_km`).
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

let env;

const users = {
  lm: { role: 'logistics_manager' },
  sm: { role: 'sales_manager' },
  gm: { role: 'gm' },
  driver: { role: 'driver' },
  exec: { role: 'sales_exec' },
  ws: { role: 'warehouse_supervisor' },
  oldLm: { role: 'logistics_manager', active: false },
};

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-wpc-rules',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});

after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    for (const [uid, u] of Object.entries(users)) {
      await setDoc(doc(ctx.firestore(), 'users', uid), { name: uid, active: true, ...u });
    }
    await setDoc(doc(ctx.firestore(), 'vehicles/v1'), { plate: 'ABC 1234', driverIds: ['driver'] });
    await setDoc(doc(ctx.firestore(), 'driver_km/driver_2026-10-23'), { uid: 'driver', day: '2026-10-23', km: 42 });
  });
});

const fs = (uid) => env.authenticatedContext(uid).firestore();

test('logistics manager, sales manager and GM keep vehicles', async () => {
  for (const uid of ['lm', 'sm', 'gm']) {
    await assertSucceeds(getDoc(doc(fs(uid), 'vehicles/v1')));
    await assertSucceeds(updateDoc(doc(fs(uid), 'vehicles/v1'), { readings: [{ km: 1000, day: '2026-10-24' }] }));
    await assertSucceeds(setDoc(doc(fs(uid), `vehicles/new_${uid}`), { plate: 'X' }));
    await assertSucceeds(getDoc(doc(fs(uid), 'driver_km/driver_2026-10-23')));
  }
});

test('nobody else reads or writes vehicles', async () => {
  for (const uid of ['driver', 'exec', 'ws', 'oldLm']) {
    await assertFails(getDoc(doc(fs(uid), 'vehicles/v1')));
    await assertFails(updateDoc(doc(fs(uid), 'vehicles/v1'), { plate: 'Y' }));
    await assertFails(getDoc(doc(fs(uid), 'driver_km/driver_2026-10-23')));
  }
});

test('driver km are written by the server only', async () => {
  await assertFails(setDoc(doc(fs('gm'), 'driver_km/driver_2026-10-24'), { uid: 'driver', day: '2026-10-24', km: 1 }));
});
