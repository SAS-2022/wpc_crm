// Security rules for HR actions (`hr_actions`, 2026-11-07): warnings,
// deductions, rewards, notes — the HR area only, not the employee.
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, deleteDoc, doc, getDoc, getDocs, query, serverTimestamp, setDoc, updateDoc, where } from 'firebase/firestore';

let env;

const users = {
  sm: { role: 'sales_manager' },
  gm: { role: 'gm' },
  hr: { role: 'hr' },
  kam: { role: 'kam' },
  fm: { role: 'factory_manager' },
  worker: { role: 'worker' },
  oldHr: { role: 'hr', active: false },
};

const action = { uid: 'worker', kind: 'warning', level: 'verbal', date: '2026-11-07', title: 'Late' };

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
    await setDoc(doc(ctx.firestore(), 'hr_actions', 'a1'), action);
    await setDoc(doc(ctx.firestore(), 'hr_actions/a1/attachments/f1'), { fileName: 'x.pdf' });
  });
});

const fs = (uid) => env.authenticatedContext(uid).firestore();

test('only HR writes; GM and SM read', async () => {
  await assertSucceeds(setDoc(doc(fs('hr'), 'hr_actions', 'n1'), { ...action, kind: 'deduction', amount: 100, sent: true }));
  await assertSucceeds(updateDoc(doc(fs('hr'), 'hr_actions/a1'), { title: 'Late twice' }));
  for (const uid of ['gm', 'sm']) {
    await assertSucceeds(getDoc(doc(fs(uid), 'hr_actions/a1')));
    await assertSucceeds(getDoc(doc(fs(uid), 'hr_actions/a1/attachments/f1')));
    await assertFails(setDoc(doc(fs(uid), 'hr_actions', `n_${uid}`), action));
    await assertFails(updateDoc(doc(fs(uid), 'hr_actions/a1'), { title: 'x' }));
    await assertFails(deleteDoc(doc(fs(uid), 'hr_actions/a1')));
  }
  await assertSucceeds(deleteDoc(doc(fs('hr'), 'hr_actions/a1')));
});

test('HR never on their own record', async () => {
  await assertFails(setDoc(doc(fs('hr'), 'hr_actions', 'own'), { ...action, uid: 'hr' }));
  await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'hr_actions', 'own'), { ...action, uid: 'hr', sent: true }));
  await assertFails(updateDoc(doc(fs('hr'), 'hr_actions/own'), { title: 'gone' }));
  await assertFails(deleteDoc(doc(fs('hr'), 'hr_actions/own')));
});

test('the employee reads what was sent to them and accepts it once, nothing else', async () => {
  // Not sent (internal): hidden.
  await assertFails(getDoc(doc(fs('worker'), 'hr_actions/a1')));
  await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'hr_actions', 's1'), { ...action, sent: true, acceptedAt: null }));
  const w = fs('worker');
  await assertSucceeds(getDoc(doc(w, 'hr_actions/s1')));
  await assertSucceeds(getDocs(query(collection(w, 'hr_actions'), where('uid', '==', 'worker'), where('sent', '==', true))));
  await assertFails(updateDoc(doc(w, 'hr_actions/s1'), { title: 'Not late' }));
  await assertFails(updateDoc(doc(w, 'hr_actions/s1'), { acceptedAt: serverTimestamp(), title: 'x' }));
  await assertSucceeds(updateDoc(doc(w, 'hr_actions/s1'), { acceptedAt: serverTimestamp() }));
  // Once accepted it can't be changed or accepted again.
  await assertFails(updateDoc(doc(w, 'hr_actions/s1'), { acceptedAt: serverTimestamp() }));
  await assertFails(deleteDoc(doc(w, 'hr_actions/s1')));
  // Someone else can't read or accept it.
  await assertFails(getDoc(doc(fs('kam'), 'hr_actions/s1')));
});

test('a cancelled record can not be accepted', async () => {
  await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'hr_actions', 'c1'), { ...action, sent: true, cancelled: true }));
  await assertFails(updateDoc(doc(fs('worker'), 'hr_actions/c1'), { acceptedAt: serverTimestamp() }));
});

test('other managers and inactive HR can do nothing', async () => {
  for (const uid of ['kam', 'fm', 'oldHr']) {
    await assertFails(getDoc(doc(fs(uid), 'hr_actions/a1')));
    await assertFails(setDoc(doc(fs(uid), 'hr_actions', 'x'), action));
    await assertFails(updateDoc(doc(fs(uid), 'hr_actions/a1'), { title: 'x' }));
  }
});

test('an unknown kind is refused', async () => {
  await assertFails(setDoc(doc(fs('hr'), 'hr_actions', 'x'), { ...action, kind: 'fine' }));
});
