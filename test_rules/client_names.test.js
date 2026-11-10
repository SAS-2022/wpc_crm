// Clients added or renamed in the app must have a name (two were saved
// empty in Nov 2026 when the form skipped the scrolled-away name field).
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc } from 'firebase/firestore';

let env;
const users = { kam: { role: 'kam' }, exec: { role: 'sales_exec' } };

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
    await setDoc(doc(ctx.firestore(), 'clients/c1'), { name: 'Old', assignedTo: 'exec', source: 'manual' });
  });
});

const fs = (uid) => env.authenticatedContext(uid).firestore();
const client = (name, assignedTo = 'exec') => ({ name, assignedTo, source: 'manual' });

test('a client added in the app needs a name', async () => {
  for (const uid of ['kam', 'exec']) {
    await assertFails(setDoc(doc(fs(uid), `clients/e_${uid}`), client('')));
    await assertFails(setDoc(doc(fs(uid), `clients/s_${uid}`), client('   ')));
    await assertFails(setDoc(doc(fs(uid), `clients/m_${uid}`), { assignedTo: 'exec', source: 'manual' }));
    await assertSucceeds(setDoc(doc(fs(uid), `clients/ok_${uid}`), client('Master Craft')));
  }
});

test('imports may still create clients', async () => {
  await assertSucceeds(setDoc(doc(fs('kam'), 'clients/imp'), { name: '', vat: '300000000000003', source: 'import' }));
});

test('a name can not be cleared', async () => {
  for (const uid of ['kam', 'exec']) {
    await assertFails(updateDoc(doc(fs(uid), 'clients/c1'), { name: ' ' }));
    await assertSucceeds(updateDoc(doc(fs(uid), 'clients/c1'), { name: `New ${uid}` }));
    await assertSucceeds(updateDoc(doc(fs(uid), 'clients/c1'), { notes: 'x' }));
  }
});
