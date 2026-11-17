// Security rules for projects (`projects`, 2026-11-17).
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { deleteDoc, doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

let env;

const users = {
  exec: { role: 'sales_exec' },
  exec2: { role: 'sales_exec' },
  kam: { role: 'kam' },
  sm: { role: 'sales_manager' },
  gm: { role: 'gm' },
  hr: { role: 'hr' },
  worker: { role: 'worker' },
  oldExec: { role: 'sales_exec', active: false },
};

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-wpc-rules',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});

after(() => env.cleanup());

const project = { name: 'Tower A', contractor: 'Build Co', leadId: 'exec', createdBy: 'exec', leadLog: [], clientIds: [] };

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    for (const [uid, u] of Object.entries(users)) {
      await setDoc(doc(ctx.firestore(), 'users', uid), { name: uid, active: true, ...u });
    }
    await setDoc(doc(ctx.firestore(), 'projects/p1'), project);
  });
});

const fs = (uid) => env.authenticatedContext(uid).firestore();

test('the sales team, SM and GM read, add and edit projects', async () => {
  for (const uid of ['exec', 'exec2', 'kam', 'sm', 'gm']) {
    await assertSucceeds(getDoc(doc(fs(uid), 'projects/p1')));
    await assertSucceeds(updateDoc(doc(fs(uid), 'projects/p1'), { stage: 'samplesSubmitted', notes: uid }));
    await assertSucceeds(setDoc(doc(fs(uid), `projects/new_${uid}`), { ...project, leadId: uid, createdBy: uid }));
  }
});

test('nobody else reads or writes projects', async () => {
  for (const uid of ['hr', 'worker', 'oldExec']) {
    await assertFails(getDoc(doc(fs(uid), 'projects/p1')));
    await assertFails(updateDoc(doc(fs(uid), 'projects/p1'), { notes: 'x' }));
    await assertFails(setDoc(doc(fs(uid), `projects/new_${uid}`), { ...project, leadId: uid, createdBy: uid }));
  }
});

test('the person who adds a project is its lead', async () => {
  await assertFails(setDoc(doc(fs('exec2'), 'projects/n1'), { ...project, leadId: 'exec', createdBy: 'exec2' }));
  await assertFails(setDoc(doc(fs('exec2'), 'projects/n2'), { ...project, leadId: 'exec2', createdBy: 'exec' }));
});

test('name and contracting company are required', async () => {
  await assertFails(setDoc(doc(fs('exec'), 'projects/n3'), { ...project, name: '  ' }));
  await assertFails(setDoc(doc(fs('exec'), 'projects/n4'), { ...project, contractor: '' }));
  await assertFails(updateDoc(doc(fs('exec'), 'projects/p1'), { name: '' }));
});

test('only the SM / GM change the lead', async () => {
  for (const uid of ['exec', 'exec2', 'kam']) {
    await assertFails(updateDoc(doc(fs(uid), 'projects/p1'), { leadId: uid === 'exec' ? 'exec2' : uid }));
    await assertFails(updateDoc(doc(fs(uid), 'projects/p1'), { leadLog: [{ fromId: 'exec', toId: uid }] }));
  }
  await assertSucceeds(updateDoc(doc(fs('sm'), 'projects/p1'), { leadId: 'kam', leadLog: [{ fromId: 'exec', toId: 'kam' }] }));
  await assertSucceeds(updateDoc(doc(fs('gm'), 'projects/p1'), { leadId: 'exec2' }));
  await assertFails(updateDoc(doc(fs('gm'), 'projects/p1'), { createdBy: 'gm' }));
});

test('only the SM / GM delete projects', async () => {
  await assertFails(deleteDoc(doc(fs('exec'), 'projects/p1')));
  await assertFails(deleteDoc(doc(fs('kam'), 'projects/p1')));
  await assertSucceeds(deleteDoc(doc(fs('sm'), 'projects/p1')));
});

test('the sales team reads products; only the SM / GM write them and see import records', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'products/x1'), { name: 'SW 139 Kumtasi Naturel MFC 280*210*18', price: 285 });
    await setDoc(doc(ctx.firestore(), 'product_imports/i1'), { added: 1 });
  });
  for (const uid of ['exec', 'kam', 'sm', 'gm']) {
    await assertSucceeds(getDoc(doc(fs(uid), 'products/x1')));
  }
  for (const uid of ['hr', 'worker', 'oldExec']) {
    await assertFails(getDoc(doc(fs(uid), 'products/x1')));
  }
  for (const uid of ['exec', 'kam']) {
    await assertFails(updateDoc(doc(fs(uid), 'products/x1'), { price: 1 }));
    await assertFails(setDoc(doc(fs(uid), 'products/x2'), { name: 'x' }));
    await assertFails(getDoc(doc(fs(uid), 'product_imports/i1')));
  }
  for (const uid of ['sm', 'gm']) {
    await assertSucceeds(updateDoc(doc(fs(uid), 'products/x1'), { price: 270 }));
    await assertSucceeds(getDoc(doc(fs(uid), 'product_imports/i1')));
  }
});
