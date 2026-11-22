// Security rules for KAM meetings (`kam_meetings`, `kam_tasks`, 2026-11-22).
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, deleteDoc, doc, getDoc, getDocs, query, serverTimestamp, setDoc, updateDoc, where } from 'firebase/firestore';

let env;

const users = {
  kam: { role: 'kam' },
  kam2: { role: 'kam' },
  exec: { role: 'sales_exec' },
  sm: { role: 'sales_manager' },
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
    await setDoc(doc(ctx.firestore(), 'kam_meetings/m1'), { kamId: 'kam', conclusion: 'x', createdBy: 'sm' });
    await setDoc(doc(ctx.firestore(), 'kam_tasks/t1'), { meetingId: 'm1', kamId: 'kam', text: 'Call X', status: 'open', comment: '' });
  });
});

const fs = (uid) => env.authenticatedContext(uid).firestore();

test('SM / GM write meetings and tasks; KAMs and execs cannot', async () => {
  await assertSucceeds(setDoc(doc(fs('sm'), 'kam_meetings/m2'), { kamId: 'kam2', conclusion: '' }));
  await assertSucceeds(setDoc(doc(fs('gm'), 'kam_tasks/t2'), { meetingId: 'm2', kamId: 'kam2', text: 'a', status: 'open' }));
  await assertFails(setDoc(doc(fs('kam'), 'kam_meetings/m3'), { kamId: 'kam', conclusion: '' }));
  await assertFails(setDoc(doc(fs('kam'), 'kam_tasks/t3'), { meetingId: 'm1', kamId: 'kam', text: 'a', status: 'open' }));
  await assertFails(updateDoc(doc(fs('kam'), 'kam_meetings/m1'), { conclusion: 'changed' }));
  await assertFails(deleteDoc(doc(fs('kam'), 'kam_tasks/t1')));
});

test('a KAM reads only their own', async () => {
  await assertSucceeds(getDoc(doc(fs('kam'), 'kam_meetings/m1')));
  await assertSucceeds(getDocs(query(collection(fs('kam'), 'kam_tasks'), where('kamId', '==', 'kam'))));
  await assertFails(getDoc(doc(fs('kam2'), 'kam_meetings/m1')));
  await assertFails(getDoc(doc(fs('exec'), 'kam_tasks/t1')));
  await assertFails(getDocs(collection(fs('kam'), 'kam_tasks')));
  await assertSucceeds(getDocs(collection(fs('sm'), 'kam_tasks')));
});

test('the KAM marks a task done only with a comment', async () => {
  await assertFails(updateDoc(doc(fs('kam'), 'kam_tasks/t1'), { status: 'done', comment: '  ', doneAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(fs('kam'), 'kam_tasks/t1'), { status: 'done', comment: 'ok', doneAt: serverTimestamp(), text: 'other' }));
  await assertFails(updateDoc(doc(fs('kam2'), 'kam_tasks/t1'), { status: 'done', comment: 'ok', doneAt: serverTimestamp() }));
  await assertSucceeds(updateDoc(doc(fs('kam'), 'kam_tasks/t1'), { status: 'done', comment: 'Called, order next week', doneAt: serverTimestamp() }));
  // Done: the KAM can't change it again; the SM reopens.
  await assertFails(updateDoc(doc(fs('kam'), 'kam_tasks/t1'), { status: 'open' }));
  await assertSucceeds(updateDoc(doc(fs('sm'), 'kam_tasks/t1'), { status: 'open', doneAt: null }));
});
