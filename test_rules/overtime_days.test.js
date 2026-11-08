// Security rules for overtime on a chosen day (`overtime_days/{uid}_{date}`, 2026-11-08).
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, deleteDoc, doc, getDoc, getDocs, setDoc } from 'firebase/firestore';

let env;

const users = {
  worker: { role: 'worker', department: 'production' },
  worker2: { role: 'worker' },
  fm: { role: 'factory_manager' },
  sm: { role: 'sales_manager' },
  hr: { role: 'hr' },
  acc: { role: 'accounting' },
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
    for (const [uid, u] of Object.entries(users)) await setDoc(doc(ctx.firestore(), 'users', uid), { name: uid, active: true, ...u });
  });
});

const fs = (uid) => env.authenticatedContext(uid).firestore();
const day = (uid, byId, date = '2026-11-13') => ({ uid, date, month: date.slice(0, 7), note: '', byId });

test('managers, HR and the SM allow overtime on a day for someone else; not employees, not themselves', async () => {
  await assertSucceeds(setDoc(doc(fs('fm'), 'overtime_days/worker_2026-11-13'), day('worker', 'fm')));
  await assertSucceeds(setDoc(doc(fs('sm'), 'overtime_days/worker2_2026-11-13'), day('worker2', 'sm')));
  await assertSucceeds(setDoc(doc(fs('hr'), 'overtime_days/acc_2026-11-13'), day('acc', 'hr')));
  await assertFails(setDoc(doc(fs('acc'), 'overtime_days/worker_2026-11-14'), day('worker', 'acc', '2026-11-14')));
  await assertFails(setDoc(doc(fs('worker'), 'overtime_days/worker_2026-11-14'), day('worker', 'worker', '2026-11-14')));
  await assertFails(setDoc(doc(fs('fm'), 'overtime_days/fm_2026-11-14'), day('fm', 'fm', '2026-11-14')));
  // The id must match the person and date, and byId is the writer.
  await assertFails(setDoc(doc(fs('fm'), 'overtime_days/worker_2026-11-15'), day('worker', 'fm', '2026-11-16')));
  await assertFails(setDoc(doc(fs('fm'), 'overtime_days/worker_2026-11-17'), day('worker', 'sm', '2026-11-17')));
});

test('the person reads their own (also before it exists); others do not', async () => {
  await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'overtime_days/worker_2026-11-13'), day('worker', 'fm')));
  await assertSucceeds(getDoc(doc(fs('worker'), 'overtime_days/worker_2026-11-13')));
  await assertSucceeds(getDoc(doc(fs('worker'), 'overtime_days/worker_2026-11-20')));
  await assertFails(getDoc(doc(fs('worker2'), 'overtime_days/worker_2026-11-13')));
  await assertSucceeds(getDocs(collection(fs('fm'), 'overtime_days')));
  await assertFails(getDocs(collection(fs('acc'), 'overtime_days')));
  await assertFails(deleteDoc(doc(fs('worker'), 'overtime_days/worker_2026-11-13')));
  await assertSucceeds(deleteDoc(doc(fs('fm'), 'overtime_days/worker_2026-11-13')));
});
