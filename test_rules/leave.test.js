// Security rules tests for leave requests and balances (cd test_rules && npm test).
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, deleteDoc, deleteField, doc, getDoc, getDocs, query, setDoc, updateDoc, where } from 'firebase/firestore';

let env;

const users = {
  exec: { role: 'sales_exec', kamId: 'kam' },
  exec2: { role: 'sales_exec', kamId: 'kam2' },
  kam: { role: 'kam' },
  kam2: { role: 'kam' },
  sm: { role: 'sales_manager' },
  gm: { role: 'gm' },
  hr: { role: 'hr' },
  acc: { role: 'accounting' },
};

const steps = [
  { role: 'kam', uid: 'kam', status: 'pending' },
  { role: 'sales_manager', uid: null, status: 'pending' },
  { role: 'gm', uid: null, status: 'pending' },
  { role: 'hr', uid: null, status: 'pending' },
];
const request = (uid, over = {}) => ({
  uid, kamId: 'kam', typeId: 'annual', status: 'pending', steps, stepIndex: 0, awaitingKey: 'uid:kam', days: 2, year: 2026, ...over,
});

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
    const db = ctx.firestore();
    for (const [uid, u] of Object.entries(users)) await setDoc(doc(db, 'users', uid), { name: uid, active: true, ...u });
    await setDoc(doc(db, 'leave_requests', 'r1'), request('exec'));
    await setDoc(doc(db, 'leave_balances', 'exec_2026'), { uid: 'exec', year: 2026, entitled: { annual: 21 } });
  });
});

const fs = (uid) => env.authenticatedContext(uid).firestore();
const r1 = (uid) => doc(fs(uid), 'leave_requests/r1');
const approveKamStep = { stepIndex: 1, awaitingKey: 'role:sales_manager', steps: steps.map((s, i) => (i === 0 ? { ...s, status: 'approved', byId: 'kam' } : s)) };

describe('sending and reading requests', () => {
  test('anyone sends their own pending request; not for someone else, not pre-approved', async () => {
    await assertSucceeds(setDoc(doc(fs('acc'), 'leave_requests/n1'), request('acc')));
    await assertFails(setDoc(doc(fs('acc'), 'leave_requests/n2'), request('exec')));
    await assertFails(setDoc(doc(fs('acc'), 'leave_requests/n3'), request('acc', { status: 'approved' })));
    await assertFails(setDoc(doc(fs('acc'), 'leave_requests/n4'), request('acc', { steps: [] })));
    // The chain must end with HR or the GM, not a friend.
    await assertFails(setDoc(doc(fs('acc'), 'leave_requests/n5'),
      request('acc', { steps: [{ role: 'kam', uid: 'exec', status: 'pending' }], awaitingKey: 'uid:exec' })));
  });

  test('owner, their KAM and the HR area read; other employees and KAMs don\'t', async () => {
    for (const uid of ['exec', 'kam', 'sm', 'gm', 'hr']) await assertSucceeds(getDoc(r1(uid)));
    for (const uid of ['exec2', 'kam2', 'acc']) await assertFails(getDoc(r1(uid)));
  });

  test('queries the app runs are allowed', async () => {
    await assertSucceeds(getDocs(query(collection(fs('exec'), 'leave_requests'), where('uid', '==', 'exec'))));
    await assertSucceeds(getDocs(query(collection(fs('kam'), 'leave_requests'), where('kamId', '==', 'kam'))));
    await assertSucceeds(getDocs(query(collection(fs('hr'), 'leave_requests'), where('awaitingKey', 'in', ['uid:hr', 'role:hr']))));
    await assertFails(getDocs(query(collection(fs('acc'), 'leave_requests'), where('awaitingKey', 'in', ['uid:acc', 'role:accounting']))));
  });
});

describe('approval in order', () => {
  test('only the current step\'s approver decides', async () => {
    await assertFails(updateDoc(r1('sm'), approveKamStep)); // SM before the KAM
    await assertFails(updateDoc(r1('kam2'), approveKamStep)); // another KAM
    await assertFails(updateDoc(r1('exec'), approveKamStep)); // the requester
    await assertSucceeds(updateDoc(r1('kam'), approveKamStep));
    // Now the sales manager's turn, not the GM's.
    await assertFails(updateDoc(r1('gm'), { stepIndex: 2, awaitingKey: 'role:gm' }));
    await assertSucceeds(updateDoc(r1('sm'), { stepIndex: 2, awaitingKey: 'role:gm' }));
  });

  test('an approver can\'t change dates, days or the owner', async () => {
    await assertFails(updateDoc(r1('kam'), { ...approveKamStep, days: 30 }));
    await assertFails(updateDoc(r1('kam'), { ...approveKamStep, uid: 'kam' }));
  });

  test('a manager can\'t approve their own request at their step', async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), 'leave_requests/own'), request('sm', { awaitingKey: 'role:sales_manager', kamId: null })));
    await assertFails(updateDoc(doc(fs('sm'), 'leave_requests/own'), { status: 'approved', awaitingKey: null }));
  });

  test('owner cancels while pending, can\'t approve it', async () => {
    await assertFails(updateDoc(r1('exec'), { status: 'approved', awaitingKey: null }));
    await assertSucceeds(updateDoc(r1('exec'), { status: 'cancelled', awaitingKey: null }));
    await assertFails(updateDoc(r1('exec'), { status: 'pending', awaitingKey: 'uid:kam' }));
  });

  test('HR, GM and (for now) SM may correct a request, not other managers', async () => {
    await assertSucceeds(updateDoc(r1('hr'), { days: 1 }));
    await assertSucceeds(updateDoc(r1('gm'), { days: 2 }));
    await assertSucceeds(updateDoc(r1('sm'), { days: 3 }));
    await assertFails(updateDoc(r1('kam'), { days: 4 }));
  });
});

describe('balances and settings', () => {
  test('owner and HR area read a balance; only HR / GM / SM change it', async () => {
    await assertSucceeds(getDoc(doc(fs('exec'), 'leave_balances/exec_2026')));
    await assertSucceeds(getDoc(doc(fs('exec2'), 'leave_balances/exec2_2026'))); // not created yet
    await assertSucceeds(getDoc(doc(fs('sm'), 'leave_balances/exec_2026')));
    await assertFails(getDoc(doc(fs('exec2'), 'leave_balances/exec_2026')));
    await assertFails(setDoc(doc(fs('exec'), 'leave_balances/exec_2026'), { entitled: { annual: 99 } }, { merge: true }));
    await assertFails(setDoc(doc(fs('kam'), 'leave_balances/exec_2026'), { entitled: { annual: 99 } }, { merge: true }));
    await assertSucceeds(setDoc(doc(fs('sm'), 'leave_balances/exec_2026'), { entitled: { annual: 30 } }, { merge: true }));
    await assertSucceeds(setDoc(doc(fs('hr'), 'leave_balances/exec_2026'), { entitled: { annual: deleteField() } }, { merge: true }));
  });

  test('HR / GM / SM edit leave types and holidays; others only read', async () => {
    await assertSucceeds(setDoc(doc(fs('sm'), 'settings/leaveTypes'), { types: [] }));
    await assertFails(setDoc(doc(fs('kam'), 'settings/holidays'), { dates: [] }));
    await assertSucceeds(setDoc(doc(fs('hr'), 'settings/leaveTypes'), { types: [] }));
    await assertSucceeds(setDoc(doc(fs('gm'), 'settings/holidays'), { dates: ['2026-09-23'] }));
    await assertFails(setDoc(doc(fs('exec'), 'settings/leaveTypes'), { types: [] }));
    await assertSucceeds(getDoc(doc(fs('exec'), 'settings/leaveTypes')));
  });
});

describe('request documents', () => {
  const put = (status, uploadedBy) => env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'leave_requests/r1'), request('exec', { status }));
    await setDoc(doc(ctx.firestore(), 'leave_requests/r1/attachments/a1'), { uploadedBy, fileName: 'r.pdf' });
  });
  const file = (uid) => doc(fs(uid), 'leave_requests/r1/attachments/a1');

  test('the owner removes their own document while it waits', async () => {
    await put('pending', 'exec');
    await assertSucceeds(deleteDoc(file('exec')));
  });

  test('not once decided, not one HR added, not the approver', async () => {
    await put('approved', 'exec');
    await assertFails(deleteDoc(file('exec')));
    await put('pending', 'hr');
    await assertFails(deleteDoc(file('exec')));
    await put('pending', 'exec');
    await assertFails(deleteDoc(file('kam')));
    await assertSucceeds(deleteDoc(file('hr')));
  });
});
