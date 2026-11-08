// Security rules for payroll (`payroll`, 2026-11-07): one account only.
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, doc, getDoc, getDocs, setDoc } from 'firebase/firestore';

let env;
const users = {
  wissam: { role: 'sales_manager', email: 'wissam.b@woodpanelsco.com' },
  sm2: { role: 'sales_manager', email: 'other.sm@woodpanelsco.com' },
  gm: { role: 'gm', email: 'gm@woodpanelsco.com' },
  hr: { role: 'hr', email: 'hr@woodpanelsco.com' },
  worker: { role: 'worker', email: 'worker@woodpanelsco.com' },
};

before(async () => {
  env = await initializeTestEnvironment({ projectId: 'demo-wpc-rules', firestore: { rules: readFileSync('../firestore.rules', 'utf8') } });
});
after(() => env.cleanup());
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    for (const [uid, u] of Object.entries(users)) await setDoc(doc(ctx.firestore(), 'users', uid), { name: uid, active: true, ...u });
    await setDoc(doc(ctx.firestore(), 'payroll', 'worker'), { uid: 'worker', basic: 3000 });
  });
});

const fs = (uid) => env.authenticatedContext(uid, { email: users[uid].email }).firestore();

test('the payroll account reads and writes', async () => {
  await assertSucceeds(getDocs(collection(fs('wissam'), 'payroll')));
  await assertSucceeds(setDoc(doc(fs('wissam'), 'payroll/worker'), { uid: 'worker', basic: 3500 }));
});

test('nobody else, not even the GM, HR or the person', async () => {
  for (const uid of ['sm2', 'gm', 'hr', 'worker']) {
    await assertFails(getDoc(doc(fs(uid), 'payroll/worker')));
    await assertFails(setDoc(doc(fs(uid), 'payroll/worker'), { uid: 'worker', basic: 1 }));
  }
});

test('the right email on an inactive account is refused', async () => {
  await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'users', 'wissam'), { ...users.wissam, active: false }));
  await assertFails(getDoc(doc(fs('wissam'), 'payroll/worker')));
});
