// Security rules for joining date / department, leave policy and leave history.
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

let env;

const users = {
  hr: { role: 'hr' },
  worker: { role: 'worker' },
  other: { role: 'worker' },
  exec: { role: 'sales_exec' },
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
    await setDoc(doc(ctx.firestore(), 'leave_history/worker_2025'), { uid: 'worker', year: 2025 });
  });
});

const fs = (uid) => env.authenticatedContext(uid).firestore();

test('HR sets joining date and department, nothing else of a user', async () => {
  await assertSucceeds(updateDoc(doc(fs('hr'), 'users/worker'), { joiningDate: '2023-03-15', department: 'admin' }));
  await assertFails(updateDoc(doc(fs('hr'), 'users/worker'), { role: 'gm' }));
  await assertFails(updateDoc(doc(fs('worker'), 'users/worker'), { joiningDate: '2020-01-01' }));
});

test('HR sets the leave policy and departments; others not', async () => {
  await assertSucceeds(setDoc(doc(fs('hr'), 'settings/leavePolicy'), { annualCarryOver: true }));
  await assertSucceeds(setDoc(doc(fs('hr'), 'settings/departments'), { tags: [] }));
  await assertFails(setDoc(doc(fs('exec'), 'settings/leavePolicy'), { annualCarryOver: true }));
  await assertSucceeds(getDoc(doc(fs('exec'), 'settings/leavePolicy')));
});

test('leave history: the person and HR read, nobody writes', async () => {
  await assertSucceeds(getDoc(doc(fs('worker'), 'leave_history/worker_2025')));
  await assertSucceeds(getDoc(doc(fs('hr'), 'leave_history/worker_2025')));
  await assertFails(getDoc(doc(fs('other'), 'leave_history/worker_2025')));
  await assertFails(setDoc(doc(fs('hr'), 'leave_history/worker_2026'), { uid: 'worker', year: 2026 }));
});
