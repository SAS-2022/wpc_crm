// Security rules for payroll (`payroll`, 2026-11-07): one account only.
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, deleteDoc, doc, getDoc, getDocs, setDoc } from 'firebase/firestore';

let env;
const users = {
  wissam: { role: 'sales_manager', email: 'wissam.b@woodpanelsco.com' },
  sm2: { role: 'sales_manager', email: 'other.sm@woodpanelsco.com' },
  gm: { role: 'gm', email: 'gm@woodpanelsco.com' },
  hr: { role: 'hr', email: 'hr@woodpanelsco.com' },
  worker: { role: 'worker', email: 'worker@woodpanelsco.com' },
};

before(async () => {
  env = await initializeTestEnvironment({ projectId: 'demo-wpc-rules', firestore: { rules: readFileSync('../firestore.rules', 'utf8') } });
});
after(() => env.cleanup());
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    for (const [uid, u] of Object.entries(users)) await setDoc(doc(ctx.firestore(), 'users', uid), { name: uid, active: true, ...u });
    await setDoc(doc(ctx.firestore(), 'payroll', 'worker'), { uid: 'worker', basic: 3000 });
  });
});

const fs = (uid) => env.authenticatedContext(uid, { email: users[uid].email }).firestore();

test('the payroll account reads and writes', async () => {
  await assertSucceeds(getDocs(collection(fs('wissam'), 'payroll')));
  await assertSucceeds(setDoc(doc(fs('wissam'), 'payroll/worker'), { uid: 'worker', basic: 3500 }));
});

test('nobody else, not even the GM, HR or the person', async () => {
  for (const uid of ['sm2', 'gm', 'hr', 'worker']) {
    await assertFails(getDoc(doc(fs(uid), 'payroll/worker')));
    await assertFails(setDoc(doc(fs(uid), 'payroll/worker'), { uid: 'worker', basic: 1 }));
  }
});

test('the right email on an inactive account is refused', async () => {
  await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'users', 'wissam'), { ...users.wissam, active: false }));
  await assertFails(getDoc(doc(fs('wissam'), 'payroll/worker')));
});

// Employment contracts (2026-11-13): HR writes the parts read from a contract
// without reading payroll.
const fromContract = (by, extra = {}) => ({
  uid: 'worker', basic: 5000, housing: 1250, contractFields: ['basic', 'housing'],
  contractPath: 'employee_contracts/worker/1_c.pdf', updatedBy: by, ...extra,
});

test('HR fills a salary from a contract but still cannot read it', async () => {
  await assertSucceeds(setDoc(doc(fs('hr'), 'payroll/worker'), fromContract('hr'), { merge: true }));
  await assertSucceeds(setDoc(doc(fs('hr'), 'payroll/newbie'), {
    ...fromContract('hr'), uid: 'newbie', contractPath: 'employee_contracts/newbie/1_c.pdf',
  }));
  await assertFails(getDoc(doc(fs('hr'), 'payroll/worker')));
});

test('HR from a contract: only salary fields, as themselves, never their own', async () => {
  await assertFails(setDoc(doc(fs('hr'), 'payroll/worker'), fromContract('hr', { bonus: 1 }), { merge: true }));
  await assertFails(setDoc(doc(fs('hr'), 'payroll/worker'), fromContract('gm'), { merge: true }));
  await assertFails(setDoc(doc(fs('hr'), 'payroll/hr'), { ...fromContract('hr'), uid: 'hr' }));
});

test('the GM and others cannot write from a contract', async () => {
  for (const uid of ['gm', 'sm2', 'worker']) {
    await assertFails(setDoc(doc(fs(uid), 'payroll/worker'), fromContract(uid), { merge: true }));
  }
});

// Locked parts (2026-11-13): amounts from a contract change only with a new contract.
const lockWorker = () => env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'payroll', 'worker'), {
  uid: 'worker', basic: 5000, housing: 1250, transport: 300, contractFields: ['basic', 'housing'],
  contractPath: 'employee_contracts/worker/1_c.pdf',
}));

test('contract amounts are locked against manual edits, even for the payroll account', async () => {
  await lockWorker();
  const w = doc(fs('wissam'), 'payroll/worker');
  await assertFails(setDoc(w, { basic: 6000 }, { merge: true }));
  await assertFails(setDoc(w, { housing: 0 }, { merge: true }));
  await assertFails(setDoc(w, { contractFields: [] }, { merge: true }));
  await assertFails(setDoc(w, { contractPath: 'employee_contracts/other/2_x.pdf', basic: 1 }, { merge: true }));
  // Parts not from the contract stay editable; the same values may be re-saved.
  await assertSucceeds(setDoc(w, { transport: 400, basic: 5000 }, { merge: true }));
  await assertFails(deleteDoc(w));
});

test('a new contract changes locked amounts; a fake path does not', async () => {
  await lockWorker();
  await assertSucceeds(setDoc(doc(fs('hr'), 'payroll/worker'), {
    ...fromContract('hr', { basic: 7000, contractPath: 'employee_contracts/worker/2_new.pdf' }),
  }, { merge: true }));
  await assertFails(setDoc(doc(fs('wissam'), 'payroll/worker'), {
    basic: 1, contractPath: 'somewhere/else.pdf',
  }, { merge: true }));
  // HR re-sending the same contract path can't change amounts either.
  await assertFails(setDoc(doc(fs('hr'), 'payroll/worker'), fromContract('hr', {
    basic: 1, contractPath: 'employee_contracts/worker/2_new.pdf',
  }), { merge: true }));
  await assertSucceeds(setDoc(doc(fs('wissam'), 'payroll/worker'), {
    basic: 8000, contractFields: ['basic'], contractPath: 'employee_contracts/worker/3_w.pdf',
  }, { merge: true }));
});
