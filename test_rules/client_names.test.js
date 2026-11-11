// Clients added in the app need a name, a type (tag), a contact person, a
// phone or mobile and a location; a name can't be cleared later.
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
const client = (name, more = {}) => ({
  name, assignedTo: 'exec', source: 'manual', tagIds: ['factory'], contactPerson: 'Abu Ahmed',
  phone: '', mobile: '0505904368', lat: 24.8, lng: 46.6, ...more,
});

test('a client added in the app needs a name', async () => {
  for (const uid of ['kam', 'exec']) {
    await assertFails(setDoc(doc(fs(uid), `clients/e_${uid}`), client('')));
    await assertFails(setDoc(doc(fs(uid), `clients/s_${uid}`), client('   ')));
    await assertFails(setDoc(doc(fs(uid), `clients/m_${uid}`), { assignedTo: 'exec', source: 'manual' }));
    await assertSucceeds(setDoc(doc(fs(uid), `clients/ok_${uid}`), client('Master Craft')));
    await assertSucceeds(setDoc(doc(fs(uid), `clients/ph_${uid}`), client('A', { phone: '011 435 9633', mobile: '' })));
  }
});

test('type, contact person, phone and location are required', async () => {
  const missing = [
    { tagIds: [] }, { tagIds: null }, { contactPerson: ' ' }, { phone: '', mobile: '' },
    { lat: null }, { lng: null }, { lat: '24.8' },
  ];
  for (const [i, m] of missing.entries()) {
    await assertFails(setDoc(doc(fs('exec'), `clients/x${i}`), client('Master Craft', m)));
    await assertFails(setDoc(doc(fs('kam'), `clients/k${i}`), client('Master Craft', m)));
  }
});

test('a sales exec may set the type of their own client', async () => {
  await assertSucceeds(updateDoc(doc(fs('exec'), 'clients/c1'), { tagIds: ['showroom'] }));
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
