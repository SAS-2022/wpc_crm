// Security rules for break requests (`break_requests/{uid}_{date}_{ms}`) and
// department heads allowing overtime (2026-11-05).
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, deleteDoc, doc, getDocs, query, setDoc, updateDoc, where } from 'firebase/firestore';

let env;

const users = {
  worker: { role: 'worker', department: 'production', supervisorId: 'ws' },
  other: { role: 'worker' },
  ws: { role: 'warehouse_supervisor' },
  fm: { role: 'factory_manager' },
  acc: { role: 'accounting' },
  accBoss: { role: 'accounting', isManager: true },
  chosen: { role: 'procurement', isManager: true },
  picked: { role: 'engineer', managerId: 'chosen' },
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
      await setDoc(doc(ctx.firestore(), 'users', uid), { name: uid, active: true, overtimeAllowed: false, ...u });
    }
  });
});

const fs = (uid) => env.authenticatedContext(uid).firestore();
const ask = (uid, extra = {}) => ({
  uid, date: '2026-11-05', month: '2026-11', minutes: 30, reason: '', approverIds: ['ws', 'fm'], status: 'pending', ...extra,
});
const id = 'worker_2026-11-05_1762329600000';
const seed = (data) => env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), `break_requests/${id}`), data));

describe('break requests', () => {
  test('the person asks for themselves, own id, pending, sane length', async () => {
    await assertSucceeds(setDoc(doc(fs('worker'), `break_requests/${id}`), ask('worker')));
    await assertFails(setDoc(doc(fs('other'), 'break_requests/other_2026-11-05_1'), ask('worker')));
    await assertFails(setDoc(doc(fs('worker'), 'break_requests/worker_2026-11-06_1'), ask('worker')));
    await assertFails(setDoc(doc(fs('worker'), 'break_requests/worker_2026-11-05_2'), ask('worker', { status: 'approved' })));
    await assertFails(setDoc(doc(fs('worker'), 'break_requests/worker_2026-11-05_3'), ask('worker', { minutes: 600 })));
    await assertFails(setDoc(doc(fs('worker'), 'break_requests/worker_2026-11-05_4'), ask('worker', { approverIds: ['worker'] })));
  });

  test('only an approver decides, once', async () => {
    await seed(ask('worker'));
    await assertFails(updateDoc(doc(fs('worker'), `break_requests/${id}`), { status: 'approved', decidedBy: 'worker' }));
    await assertFails(updateDoc(doc(fs('acc'), `break_requests/${id}`), { status: 'approved', decidedBy: 'acc' }));
    await assertSucceeds(updateDoc(doc(fs('ws'), `break_requests/${id}`), { status: 'approved', decidedBy: 'ws', comment: '' }));
    await assertFails(updateDoc(doc(fs('fm'), `break_requests/${id}`), { status: 'rejected', decidedBy: 'fm' }));
  });

  test('cancelled only while waiting; read by the person and the approvers', async () => {
    await seed(ask('worker'));
    await assertSucceeds(getDocs(query(collection(fs('worker'), 'break_requests'), where('uid', '==', 'worker'), where('date', '==', '2026-11-05'))));
    await assertSucceeds(getDocs(query(collection(fs('fm'), 'break_requests'), where('approverIds', 'array-contains', 'fm'))));
    await assertFails(getDocs(query(collection(fs('acc'), 'break_requests'), where('uid', '==', 'worker'))));
    await assertSucceeds(deleteDoc(doc(fs('worker'), `break_requests/${id}`)));
    await seed(ask('worker', { status: 'approved', decidedBy: 'ws' }));
    await assertFails(deleteDoc(doc(fs('worker'), `break_requests/${id}`)));
  });
});

describe('overtime permission', () => {
  test('a manager of the same department sets overtime, nothing else', async () => {
    await assertSucceeds(updateDoc(doc(fs('accBoss'), 'users/acc'), { overtimeAllowed: true, overtimeMaxMin: 120 }));
    await assertFails(updateDoc(doc(fs('accBoss'), 'users/acc'), { overtimeAllowed: true, monthlyTarget: 5 }));
    await assertFails(updateDoc(doc(fs('accBoss'), 'users/worker'), { overtimeAllowed: true })); // other department
    await assertFails(updateDoc(doc(fs('acc'), 'users/acc'), { overtimeAllowed: false })); // not a manager, own (was set true above)
    await assertFails(updateDoc(doc(fs('accBoss'), 'users/accBoss'), { overtimeAllowed: true })); // never themselves
  });

  test('the chosen direct manager; the warehouse supervisor is no department head', async () => {
    await assertSucceeds(updateDoc(doc(fs('chosen'), 'users/picked'), { overtimeAllowed: true }));
    await assertFails(updateDoc(doc(fs('ws'), 'users/acc'), { overtimeAllowed: true }));
  });
});
