// Security rules for company documents (`company_docs`, 2026-11-01).
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, deleteDoc, doc, getDoc, getDocs, query, setDoc, updateDoc, where } from 'firebase/firestore';

let env;

const users = {
  sm: { role: 'sales_manager' },
  gm: { role: 'gm' },
  hr: { role: 'hr' },
  kam: { role: 'kam' },
  exec: { role: 'sales_exec' },
  acc: { role: 'accounting' },
  oldExec: { role: 'sales_exec', active: false },
};

const items = {
  cr: { kind: 'file', section: 'official', name: 'CR', restricted: false, ownRestricted: false },
  audit: { kind: 'file', section: 'official', name: 'Audit', restricted: true, ownRestricted: true },
  sheet: { kind: 'file', section: 'product', name: 'Datasheet', restricted: false, ownRestricted: false },
  moqeem: { kind: 'file', section: 'expiring', name: 'Moqeem', restricted: true, ownRestricted: false, expiry: '2026-12-01' },
  portal: { kind: 'file', section: 'subscription', name: 'Portal', restricted: true, ownRestricted: false, expiry: '2026-12-01',
    loginUrl: 'https://example.com', username: 'wpc', password: 'secret' },
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
    for (const [id, d] of Object.entries(items)) {
      await setDoc(doc(ctx.firestore(), 'company_docs', id), d);
    }
  });
});

const fs = (uid) => env.authenticatedContext(uid).firestore();
const salesQuery = (uid) => query(collection(fs(uid), 'company_docs'),
  where('restricted', '==', false), where('section', 'in', ['official', 'product']));

test('the sales team reads Official / Product items that are not management only', async () => {
  for (const uid of ['exec', 'kam']) {
    await assertSucceeds(getDoc(doc(fs(uid), 'company_docs/cr')));
    await assertSucceeds(getDoc(doc(fs(uid), 'company_docs/sheet')));
    await assertSucceeds(getDocs(salesQuery(uid)));
    await assertFails(getDoc(doc(fs(uid), 'company_docs/audit')));
    await assertFails(getDoc(doc(fs(uid), 'company_docs/moqeem')));
    await assertFails(getDocs(collection(fs(uid), 'company_docs')));
  }
});

test('GM, sales manager and HR read everything; others nothing', async () => {
  for (const uid of ['sm', 'gm', 'hr']) await assertSucceeds(getDocs(collection(fs(uid), 'company_docs')));
  await assertFails(getDoc(doc(fs('acc'), 'company_docs/cr')));
  await assertFails(getDoc(doc(fs('oldExec'), 'company_docs/cr')));
});

test('the sales team never writes', async () => {
  await assertFails(updateDoc(doc(fs('kam'), 'company_docs/cr'), { name: 'x' }));
  await assertFails(setDoc(doc(fs('exec'), 'company_docs/new'), { ...items.sheet }));
  await assertFails(deleteDoc(doc(fs('exec'), 'company_docs/sheet')));
});

test('GM / sales manager edit any section', async () => {
  await assertSucceeds(setDoc(doc(fs('sm'), 'company_docs/n1'), { ...items.sheet }));
  await assertSucceeds(updateDoc(doc(fs('gm'), 'company_docs/cr'), { restricted: true, ownRestricted: true }));
  await assertSucceeds(updateDoc(doc(fs('sm'), 'company_docs/moqeem'), { expiry: '2027-12-01' }));
  await assertSucceeds(deleteDoc(doc(fs('gm'), 'company_docs/audit')));
});

test('HR edits only the Expiring section', async () => {
  await assertSucceeds(setDoc(doc(fs('hr'), 'company_docs/n2'), { ...items.moqeem }));
  await assertSucceeds(updateDoc(doc(fs('hr'), 'company_docs/moqeem'), { expiry: '2027-12-01' }));
  await assertSucceeds(deleteDoc(doc(fs('hr'), 'company_docs/n2')));
  await assertFails(updateDoc(doc(fs('hr'), 'company_docs/cr'), { name: 'x' }));
  await assertFails(setDoc(doc(fs('hr'), 'company_docs/n3'), { ...items.sheet }));
  await assertFails(deleteDoc(doc(fs('hr'), 'company_docs/sheet')));
  // Can't move an item out of Expiring (it would become visible to sales).
  await assertFails(updateDoc(doc(fs('hr'), 'company_docs/moqeem'), { section: 'official', restricted: false }));
});

test('Expiring items stay management only', async () => {
  await assertFails(setDoc(doc(fs('gm'), 'company_docs/n4'), { ...items.moqeem, restricted: false }));
  await assertFails(updateDoc(doc(fs('sm'), 'company_docs/moqeem'), { restricted: false }));
});

// Subscriptions (2026-11-03): logins with passwords, GM / SM / HR only.
test('subscriptions: GM / SM / HR read and edit, nobody else reads them', async () => {
  for (const uid of ['sm', 'gm', 'hr']) {
    await assertSucceeds(getDoc(doc(fs(uid), 'company_docs/portal')));
    await assertSucceeds(updateDoc(doc(fs(uid), 'company_docs/portal'), { password: `new-${uid}` }));
  }
  await assertSucceeds(setDoc(doc(fs('hr'), 'company_docs/new1'),
    { kind: 'file', section: 'subscription', name: 'X', restricted: true, ownRestricted: false, expiry: '2027-01-01' }));
  for (const uid of ['exec', 'kam', 'acc']) {
    await assertFails(getDoc(doc(fs(uid), 'company_docs/portal')));
    await assertFails(updateDoc(doc(fs(uid), 'company_docs/portal'), { password: 'x' }));
  }
});

test('subscriptions must stay management only', async () => {
  await assertFails(setDoc(doc(fs('gm'), 'company_docs/new2'),
    { kind: 'file', section: 'subscription', name: 'X', restricted: false, ownRestricted: false }));
  await assertFails(updateDoc(doc(fs('gm'), 'company_docs/portal'), { restricted: false }));
});
