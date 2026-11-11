// Main role + extra roles (user request 2026-11-11, `users.extraRoles`, RTDB
// `role_extras/{uid}`): an extra role grants what that role may do; only the
// sales manager / GM set them, only a GM gives GM.
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, serverTimestamp, setDoc, updateDoc } from 'firebase/firestore';
import { get, ref, set } from 'firebase/database';

let env;

const users = {
  gm: { role: 'gm' },
  sm: { role: 'sales_manager' },
  lm: { role: 'logistics_manager' },
  acc: { role: 'accounting' },
  accHr: { role: 'accounting', extraRoles: ['hr'] },
  worker: { role: 'worker' },
  procKam: { role: 'procurement', extraRoles: ['kam'] },
};

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-wpc-rules',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
    database: { rules: readFileSync('../database.rules.json', 'utf8') },
  });
});

after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.clearDatabase();
  await env.withSecurityRulesDisabled(async (ctx) => {
    for (const [uid, u] of Object.entries(users)) {
      await setDoc(doc(ctx.firestore(), 'users', uid), { name: uid, active: true, ...u });
      await set(ref(ctx.database(), `roles/${uid}`), u.role);
      if (u.extraRoles) {
        await set(ref(ctx.database(), `role_extras/${uid}`), Object.fromEntries(u.extraRoles.map((r) => [r, true])));
      }
    }
    await setDoc(doc(ctx.firestore(), 'user_log/x'), { action: 'updated' });
    await set(ref(ctx.database(), 'live_locations/worker'), { lat: 1, lng: 2 });
  });
});

const fs = (uid) => env.authenticatedContext(uid).firestore();
const db = (uid) => env.authenticatedContext(uid).database();
const stamp = (uid) => ({ changedBy: uid, changedAt: serverTimestamp() });

describe('extra roles: Firestore', () => {
  test('an extra HR role opens what HR reads', async () => {
    await assertFails(getDoc(doc(fs('acc'), 'user_log/x')));
    await assertSucceeds(getDoc(doc(fs('accHr'), 'user_log/x')));
  });

  test('the sales manager adds extra roles, but never GM; the GM may', async () => {
    await assertSucceeds(updateDoc(doc(fs('sm'), 'users/worker'), { extraRoles: ['procurement'], ...stamp('sm') }));
    await assertFails(updateDoc(doc(fs('sm'), 'users/worker'), { extraRoles: ['gm'], ...stamp('sm') }));
    await assertSucceeds(updateDoc(doc(fs('gm'), 'users/worker'), { extraRoles: ['gm'], ...stamp('gm') }));
  });

  test('logistics manager / HR edit their people but not their extra roles', async () => {
    await assertSucceeds(updateDoc(doc(fs('lm'), 'users/worker'), { name: 'W', ...stamp('lm') }));
    await assertFails(updateDoc(doc(fs('lm'), 'users/worker'), { extraRoles: ['hr'], ...stamp('lm') }));
    await assertFails(updateDoc(doc(fs('accHr'), 'users/worker'), { extraRoles: ['accounting'], ...stamp('accHr') }));
    await assertFails(setDoc(doc(fs('lm'), 'users/newW'), { name: 'n', role: 'worker', active: true, extraRoles: ['kam'], ...stamp('lm') }));
  });

  test('nobody gives themselves extra roles from the profile', async () => {
    await assertFails(updateDoc(doc(fs('acc'), 'users/acc'), { extraRoles: ['hr'], ...stamp('acc') }));
  });
});

describe('extra roles: RTDB', () => {
  test('an extra KAM role reads live locations like a KAM', async () => {
    await assertFails(get(ref(db('acc'), 'live_locations')));
    await assertSucceeds(get(ref(db('procKam'), 'live_locations')));
  });

  test('role_extras: the sales manager writes it (not GM), others not', async () => {
    await assertSucceeds(set(ref(db('sm'), 'role_extras/worker'), { procurement: true }));
    await assertFails(set(ref(db('sm'), 'role_extras/worker'), { gm: true }));
    await assertSucceeds(set(ref(db('gm'), 'role_extras/worker'), { gm: true }));
    await assertFails(set(ref(db('lm'), 'role_extras/worker'), { hr: true }));
    await assertFails(set(ref(db('accHr'), 'role_extras/accHr'), { gm: true }));
  });
});
