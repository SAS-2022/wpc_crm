// Security rules for leaving early (`checkout_requests/{uid}_{date}`).
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, deleteDoc, doc, getDoc, getDocs, query, setDoc, updateDoc, where } from 'firebase/firestore';

let env;

const users = {
  worker: { role: 'worker' },
  other: { role: 'worker' },
  boss: { role: 'accounting', isManager: true },
  gm: { role: 'gm' },
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
  });
});

const fs = (uid) => env.authenticatedContext(uid).firestore();
const ask = (uid, extra = {}) => ({
  uid, date: '2026-10-23', month: '2026-10', reason: 'doctor', approverIds: ['boss'], status: 'pending', ...extra,
});
const id = 'worker_2026-10-23';
const seed = (data) => env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), `checkout_requests/${id}`), data));

describe('early check-out requests', () => {
  test('the person asks for themselves, today\'s id, not approving it themselves', async () => {
    await assertSucceeds(setDoc(doc(fs('worker'), `checkout_requests/${id}`), ask('worker')));
    await assertFails(setDoc(doc(fs('other'), `checkout_requests/${id}`), ask('worker')));
    await assertFails(setDoc(doc(fs('worker'), 'checkout_requests/worker_2026-10-24'), ask('worker')));
    await assertFails(setDoc(doc(fs('worker'), `checkout_requests/${id}`), ask('worker', { status: 'approved' })));
    await assertFails(setDoc(doc(fs('worker'), `checkout_requests/${id}`), ask('worker', { approverIds: ['worker'] })));
  });

  test('only an approver decides, once', async () => {
    await seed(ask('worker'));
    await assertFails(updateDoc(doc(fs('worker'), `checkout_requests/${id}`), { status: 'approved', decidedBy: 'worker' }));
    await assertFails(updateDoc(doc(fs('gm'), `checkout_requests/${id}`), { status: 'approved', decidedBy: 'gm' }));
    await assertSucceeds(updateDoc(doc(fs('boss'), `checkout_requests/${id}`), { status: 'approved', decidedBy: 'boss', comment: '' }));
    await assertFails(updateDoc(doc(fs('boss'), `checkout_requests/${id}`), { status: 'rejected', decidedBy: 'boss' }));
  });

  test('asking again after a rejection; cancelling only while waiting', async () => {
    await seed(ask('worker', { status: 'rejected', decidedBy: 'boss' }));
    await assertFails(deleteDoc(doc(fs('worker'), `checkout_requests/${id}`)));
    await assertSucceeds(setDoc(doc(fs('worker'), `checkout_requests/${id}`), ask('worker')));
    await assertSucceeds(deleteDoc(doc(fs('worker'), `checkout_requests/${id}`)));
  });

  test('read: the person and the approvers (query by approver too), not others', async () => {
    await seed(ask('worker'));
    await assertSucceeds(getDoc(doc(fs('worker'), `checkout_requests/${id}`)));
    await assertSucceeds(getDocs(query(collection(fs('boss'), 'checkout_requests'), where('approverIds', 'array-contains', 'boss'))));
    await assertFails(getDoc(doc(fs('other'), `checkout_requests/${id}`)));
  });
});
