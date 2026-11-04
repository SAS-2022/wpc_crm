// Department heads (factory manager, logistics manager) list the overtime
// waiting for approval (Home "Overtime to approve" query) and approve it.
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, doc, getDocs, query, setDoc, updateDoc, where } from 'firebase/firestore';

let env;
const users = {
  fm: { role: 'factory_manager', department: 'production' },
  lm: { role: 'logistics_manager' },
  op: { role: 'operator', department: 'production' },
  driver: { role: 'driver', department: 'logistics' },
  worker: { role: 'worker' },
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
    for (const uid of ['op', 'driver', 'fm']) {
      await setDoc(doc(ctx.firestore(), `attendance/${uid}_2026-11-02`),
        { uid, date: '2026-11-02', month: '2026-11', events: [], overtimeStatus: 'pending', overtimeMin: 30 });
    }
  });
});

const fs = (uid) => env.authenticatedContext(uid).firestore();
const pending = (uid) => getDocs(query(collection(fs(uid), 'attendance'), where('overtimeStatus', '==', 'pending')));

describe('overtime approvals', () => {
  test('factory and logistics managers list every pending overtime day', async () => {
    for (const uid of ['fm', 'lm']) {
      const s = await assertSucceeds(pending(uid));
      assert(s.size === 3, `${uid} got ${s.size}`);
    }
  });
  test('a worker cannot list them', async () => {
    await assertFails(pending('worker'));
  });
  test('they approve someone else, never their own day', async () => {
    const review = { overtimeReview: { minutes: 30, byId: 'fm', note: '', rejected: false, at: new Date() } };
    await assertSucceeds(updateDoc(doc(fs('fm'), 'attendance/op_2026-11-02'), review));
    await assertSucceeds(updateDoc(doc(fs('lm'), 'attendance/driver_2026-11-02'), { overtimeReview: { ...review.overtimeReview, byId: 'lm' } }));
    await assertFails(updateDoc(doc(fs('fm'), 'attendance/fm_2026-11-02'), review));
  });
});

function assert(ok, msg) { if (!ok) throw new Error(msg); }
