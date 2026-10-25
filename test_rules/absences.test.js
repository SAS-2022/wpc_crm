// Security rules for "not coming to work" reports (`absences/{uid}_{date}`).
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { addDoc, collection, deleteDoc, doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

let env;

const users = {
  worker: { role: 'worker' },
  other: { role: 'worker' },
  exec: { role: 'sales_exec', kamId: 'kam' },
  kam: { role: 'kam' },
  hr: { role: 'hr' },
  gm: { role: 'gm' },
  sm: { role: 'sales_manager' },
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
const absence = (uid, extra = {}) => ({
  uid, date: '2026-10-22', month: '2026-10', reason: 'sick', note: 'fever', status: 'pending', ...extra,
});

describe('absences', () => {
  test('the person reports their own day and takes it back', async () => {
    await assertSucceeds(setDoc(doc(fs('worker'), 'absences/worker_2026-10-22'), absence('worker')));
    await assertSucceeds(getDoc(doc(fs('worker'), 'absences/worker_2026-10-22')));
    await assertSucceeds(deleteDoc(doc(fs('worker'), 'absences/worker_2026-10-22')));
  });

  test('not for someone else, not under another id, only known reasons and fields', async () => {
    await assertFails(setDoc(doc(fs('other'), 'absences/worker_2026-10-22'), absence('worker')));
    await assertFails(setDoc(doc(fs('worker'), 'absences/worker_2026-10-23'), absence('worker')));
    await assertFails(setDoc(doc(fs('worker'), 'absences/worker_2026-10-22'), absence('worker', { reason: 'holiday' })));
    await assertFails(setDoc(doc(fs('worker'), 'absences/worker_2026-10-22'), absence('worker', { approved: true })));
  });

  test('others read it only from the HR area or as a supervisor', async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'absences/exec_2026-10-22'), absence('exec')));
    await assertSucceeds(getDoc(doc(fs('hr'), 'absences/exec_2026-10-22')));
    await assertSucceeds(getDoc(doc(fs('kam'), 'absences/exec_2026-10-22')));
    await assertFails(getDoc(doc(fs('worker'), 'absences/exec_2026-10-22')));
    await assertFails(deleteDoc(doc(fs('worker'), 'absences/exec_2026-10-22')));
  });

  test('the person can\'t decide; only HR / the GM, never on their own', async () => {
    await assertFails(setDoc(doc(fs('worker'), 'absences/worker_2026-10-22'), absence('worker', { status: 'accepted' })));
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'absences/worker_2026-10-22'), absence('worker')));
    const decision = { status: 'accepted', countAs: 'annual', comment: '', decidedBy: 'hr', leaveRequestId: 'r1' };
    await assertFails(updateDoc(doc(fs('worker'), 'absences/worker_2026-10-22'), { ...decision, decidedBy: 'worker' }));
    await assertFails(updateDoc(doc(fs('exec'), 'absences/worker_2026-10-22'), { ...decision, decidedBy: 'exec' }));
    await assertFails(updateDoc(doc(fs('hr'), 'absences/worker_2026-10-22'), { ...decision, decidedBy: 'gm' }));
    // The sales manager acts as HR for now (testing).
    await assertSucceeds(updateDoc(doc(fs('sm'), 'absences/worker_2026-10-22'), { ...decision, decidedBy: 'sm' }));
    // Decided: the person can no longer change or take it back.
    await assertFails(deleteDoc(doc(fs('worker'), 'absences/worker_2026-10-22')));
  });

  test('HR / GM save the approved leave for an accepted absence, not for themselves', async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'absences/worker_2026-10-22'), absence('worker')));
    const leave = (uid) => ({ uid, status: 'approved', absenceId: `${uid}_2026-10-22`, stepIndex: 0, steps: [{ role: 'hr' }] });
    await assertSucceeds(addDoc(collection(fs('hr'), 'leave_requests'), leave('worker')));
    await assertFails(addDoc(collection(fs('worker'), 'leave_requests'), leave('worker')));
    await assertFails(addDoc(collection(fs('hr'), 'leave_requests'), { ...leave('worker'), absenceId: 'nope' }));
  });

  test('HR area corrects an attendance day; the person can\'t', async () => {
    const day = { uid: 'worker', date: '2026-10-22', month: '2026-10', correction: { note: 'forgot phone' } };
    await assertFails(setDoc(doc(fs('worker'), 'attendance/worker_2026-10-22'), day));
    await assertSucceeds(setDoc(doc(fs('hr'), 'attendance/worker_2026-10-22'), day));
    await assertFails(updateDoc(doc(fs('hr'), 'attendance/worker_2026-10-22'), { closed: true }));
    await assertFails(setDoc(doc(fs('hr'), 'attendance/other_2026-10-22'), day)); // id must match
  });

  test('overtime approval: HR area / managers, never their own, only overtimeReview', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'attendance/worker_2026-10-25'), { uid: 'worker', date: '2026-10-25', overtimeMin: 90 });
      await setDoc(doc(ctx.firestore(), 'attendance/kam_2026-10-25'), { uid: 'kam', date: '2026-10-25', overtimeMin: 30 });
    });
    const review = { overtimeReview: { minutes: 60, byId: 'x', note: '' } };
    await assertSucceeds(updateDoc(doc(fs('hr'), 'attendance/worker_2026-10-25'), review));
    await assertSucceeds(updateDoc(doc(fs('kam'), 'attendance/worker_2026-10-25'), review));
    await assertFails(updateDoc(doc(fs('kam'), 'attendance/kam_2026-10-25'), review)); // own
    const changed = { overtimeReview: { minutes: 90, byId: 'y', note: '' } }; // (an unchanged write changes nothing)
    await assertFails(updateDoc(doc(fs('worker'), 'attendance/worker_2026-10-25'), changed));
    await assertFails(updateDoc(doc(fs('other'), 'attendance/worker_2026-10-25'), changed));
    await assertFails(updateDoc(doc(fs('hr'), 'attendance/worker_2026-10-25'), { ...review, overtimeMin: 200 }));
  });
});
