// "Also visited by" (2026-11-21): a sales exec asked to visit someone else's
// client reads it, records visits / calls / catalogs there, and nothing more;
// the client's own sales exec reads visits others made to their client.
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, doc, getDoc, getDocs, query, setDoc, updateDoc, where, serverTimestamp, arrayUnion } from 'firebase/firestore';

let env;

const users = {
  owner: { role: 'sales_exec' },
  visitor: { role: 'sales_exec' },
  other: { role: 'sales_exec' },
  kam: { role: 'kam' },
  sm: { role: 'sales_manager' },
};

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-wpc-rules',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});

after(() => env.cleanup());

const client = {
  name: 'Kitchen Co', assignedTo: 'owner', lat: 24.6, lng: 46.7,
  visitAssignments: [{ uid: 'visitor', locationIds: ['l2'], byId: 'sm' }], visitorIds: ['visitor'],
};

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    for (const [uid, u] of Object.entries(users)) {
      await setDoc(doc(ctx.firestore(), 'users', uid), { name: uid, active: true, ...u });
    }
    await setDoc(doc(ctx.firestore(), 'clients/c1'), client);
    await setDoc(doc(ctx.firestore(), 'visits/v0'), { clientId: 'c1', salesExecId: 'visitor', clientOwnerId: 'owner' });
    await setDoc(doc(ctx.firestore(), 'visits/v0/comments/k1'), { authorId: 'visitor', body: 'hi' });
  });
});

const fs = (uid) => env.authenticatedContext(uid).firestore();

test('the visitor reads the client and finds it by visitorIds; others do not', async () => {
  await assertSucceeds(getDoc(doc(fs('visitor'), 'clients/c1')));
  await assertSucceeds(getDocs(query(collection(fs('visitor'), 'clients'), where('visitorIds', 'array-contains', 'visitor'))));
  await assertFails(getDoc(doc(fs('other'), 'clients/c1')));
});

test('the visitor marks the visit and catalogs, but edits nothing else', async () => {
  await assertSucceeds(updateDoc(doc(fs('visitor'), 'clients/c1'), {
    lastVisitAt: serverTimestamp(), givenLog: arrayUnion({ id: 'g1', item: 'switchCatalog', qty: 1 }),
  }));
  await assertFails(updateDoc(doc(fs('visitor'), 'clients/c1'), { name: 'Other' }));
  await assertFails(updateDoc(doc(fs('visitor'), 'clients/c1'), { assignedTo: 'visitor' }));
  await assertFails(updateDoc(doc(fs('visitor'), 'clients/c1'), { visitorIds: ['visitor', 'other'] }));
  await assertFails(updateDoc(doc(fs('visitor'), 'clients/c1'), { lat: 1 }));
  await assertFails(updateDoc(doc(fs('other'), 'clients/c1'), { lastVisitAt: serverTimestamp() }));
});

test('KAM / managers set the visitors', async () => {
  await assertSucceeds(updateDoc(doc(fs('sm'), 'clients/c1'), { visitorIds: ['visitor', 'other'] }));
  await assertSucceeds(updateDoc(doc(fs('kam'), 'clients/c1'), { visitorIds: [] }));
  await assertFails(updateDoc(doc(fs('owner'), 'clients/c1'), { visitorIds: ['other'] }));
});

test('a visit to someone else\'s client names its real salesperson', async () => {
  const v = { clientId: 'c1', salesExecId: 'visitor', notes: '' };
  await assertSucceeds(setDoc(doc(fs('visitor'), 'visits/v1'), { ...v, clientOwnerId: 'owner' }));
  await assertFails(setDoc(doc(fs('visitor'), 'visits/v2'), { ...v, clientOwnerId: 'other' }));
});

test('the client\'s salesperson reads visits others made to it, with comments', async () => {
  await assertSucceeds(getDoc(doc(fs('owner'), 'visits/v0')));
  await assertSucceeds(getDocs(query(collection(fs('owner'), 'visits'), where('clientId', '==', 'c1'), where('clientOwnerId', '==', 'owner'))));
  await assertSucceeds(getDocs(collection(fs('owner'), 'visits/v0/comments')));
  await assertFails(getDoc(doc(fs('other'), 'visits/v0')));
});

test('the client\'s own sales exec names its locations; a visitor can\'t', async () => {
  await assertSucceeds(updateDoc(doc(fs('owner'), 'clients/c1'), { mainLocationName: 'Olaya showroom' }));
  await assertSucceeds(updateDoc(doc(fs('owner'), 'clients/c1'), { extraLocations: [{ id: 'l2', typeId: 'showroom', lat: 26.4, lng: 50.1, address: '', name: 'Dammam' }] }));
  await assertFails(updateDoc(doc(fs('visitor'), 'clients/c1'), { mainLocationName: 'x' }));
});
