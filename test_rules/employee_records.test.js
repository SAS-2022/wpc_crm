// Security rules for employee records (`employee_records`, 2026-11-03):
// Iqama / ID, nationality, insurance class — HR area and the person only.
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, deleteDoc, doc, getDoc, getDocs, setDoc, updateDoc } from 'firebase/firestore';

let env;

const users = {
  sm: { role: 'sales_manager' },
  gm: { role: 'gm' },
  hr: { role: 'hr' },
  kam: { role: 'kam' },
  fm: { role: 'factory_manager' },
  worker: { role: 'worker', department: 'production' },
  exec: { role: 'sales_exec' },
  oldHr: { role: 'hr', active: false },
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
    await setDoc(doc(ctx.firestore(), 'employee_records', 'worker'),
      { uid: 'worker', idType: 'iqama', idNumber: '2123456789', idExpiry: '2026-12-01', nationality: 'Bangladeshi' });
  });
});

const fs = (uid) => env.authenticatedContext(uid).firestore();

test('HR, GM and SM read and write every record', async () => {
  for (const uid of ['hr', 'gm', 'sm']) {
    await assertSucceeds(getDoc(doc(fs(uid), 'employee_records/worker')));
    await assertSucceeds(getDocs(collection(fs(uid), 'employee_records')));
    await assertSucceeds(updateDoc(doc(fs(uid), 'employee_records/worker'), { insuranceClass: `B-${uid}` }));
    await assertSucceeds(setDoc(doc(fs(uid), 'employee_records/exec'), { uid: 'exec', nationality: 'Saudi', idType: 'nationalId' }));
  }
});

test('the person reads their own record but never changes it', async () => {
  await assertSucceeds(getDoc(doc(fs('worker'), 'employee_records/worker')));
  await assertFails(updateDoc(doc(fs('worker'), 'employee_records/worker'), { idExpiry: '2030-01-01' }));
  await assertFails(deleteDoc(doc(fs('worker'), 'employee_records/worker')));
});

test('other people, managers included, read nothing', async () => {
  for (const uid of ['kam', 'fm', 'exec', 'oldHr']) {
    await assertFails(getDoc(doc(fs(uid), 'employee_records/worker')));
    await assertFails(getDocs(collection(fs(uid), 'employee_records')));
    await assertFails(setDoc(doc(fs(uid), 'employee_records/worker'), { uid: 'worker', idNumber: '1' }));
  }
});

test('a record is saved under its own uid', async () => {
  await assertFails(setDoc(doc(fs('hr'), 'employee_records/exec'), { uid: 'worker' }));
});
