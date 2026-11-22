// Overtime away from the site (2026-11-21): people allowed overtime set their
// own home location once (like drivers); others can't.
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc, serverTimestamp } from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({ projectId: 'demo-wpc-rules', firestore: { rules: readFileSync('../firestore.rules', 'utf8') } });
});
after(() => env.cleanup());

const users = {
  op: { role: 'operator', overtimeAllowed: true },
  opHome: { role: 'operator', overtimeAllowed: true, homeLocation: { lat: 1, lng: 2 } },
  worker: { role: 'worker', overtimeAllowed: false },
};
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    for (const [uid, u] of Object.entries(users)) await setDoc(doc(ctx.firestore(), 'users', uid), { name: uid, active: true, ...u });
  });
});
const fs = (uid) => env.authenticatedContext(uid).firestore();
const stamp = (uid) => ({ changedBy: uid, changedAt: serverTimestamp() });

test('allowed overtime: sets own home once; without overtime or already set: no', async () => {
  await assertSucceeds(updateDoc(doc(fs('op'), 'users/op'), { homeLocation: { lat: 24.7, lng: 46.7 }, ...stamp('op') }));
  await assertFails(updateDoc(doc(fs('opHome'), 'users/opHome'), { homeLocation: { lat: 24.7, lng: 46.7 }, ...stamp('opHome') }));
  await assertFails(updateDoc(doc(fs('worker'), 'users/worker'), { homeLocation: { lat: 24.7, lng: 46.7 }, ...stamp('worker') }));
  await assertFails(updateDoc(doc(fs('op'), 'users/op'), { homeLocation: { lat: 24.7, lng: 46.7 }, overtimeMaxMin: 900, ...stamp('op') }));
});
