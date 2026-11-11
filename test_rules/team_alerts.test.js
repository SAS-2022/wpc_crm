// Security rules for team follow-ups (`team_alerts`, 2026-11-11): written by
// the Cloud Functions; the people told record the action once.
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, deleteDoc, deleteField, doc, getDoc, getDocs, query, serverTimestamp, setDoc, updateDoc, where } from 'firebase/firestore';

let env;

const users = {
  worker: { role: 'worker' },
  ws: { role: 'warehouse_supervisor' },
  lm: { role: 'logistics_manager' },
  other: { role: 'accounting' },
  hr: { role: 'hr' },
};

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-wpc-rules',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});

after(() => env.cleanup());

const id = 'late_worker_2026-11-11';
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    for (const [uid, u] of Object.entries(users)) {
      await setDoc(doc(ctx.firestore(), 'users', uid), { name: uid, active: true, ...u });
    }
    await setDoc(doc(ctx.firestore(), `team_alerts/${id}`), {
      uid: 'worker', kind: 'late', date: '2026-11-11', ref: 'worker_2026-11-11', level: 1,
      toIds: ['lm'], allIds: ['ws', 'lm'], status: 'open', nextAt: new Date(),
    });
  });
});

const fs = (uid) => env.authenticatedContext(uid).firestore();
const act = (uid, extra = {}) => ({
  status: 'done', nextAt: deleteField(),
  action: { taken: true, note: 'Called him', byId: uid, at: serverTimestamp(), ...extra },
});

describe('team alerts', () => {
  test('read by the people told and the HR area only', async () => {
    await assertSucceeds(getDoc(doc(fs('ws'), `team_alerts/${id}`)));
    await assertSucceeds(getDoc(doc(fs('lm'), `team_alerts/${id}`)));
    await assertSucceeds(getDoc(doc(fs('hr'), `team_alerts/${id}`)));
    await assertFails(getDoc(doc(fs('other'), `team_alerts/${id}`)));
    await assertFails(getDoc(doc(fs('worker'), `team_alerts/${id}`)));
    await assertSucceeds(getDocs(query(collection(fs('ws'), 'team_alerts'), where('allIds', 'array-contains', 'ws'))));
  });

  test('nobody creates or deletes them', async () => {
    await assertFails(setDoc(doc(fs('lm'), 'team_alerts/x'), { uid: 'worker', allIds: ['lm'], status: 'open' }));
    await assertFails(deleteDoc(doc(fs('lm'), `team_alerts/${id}`)));
  });

  test('anyone told records the action once, as themselves', async () => {
    await assertFails(updateDoc(doc(fs('other'), `team_alerts/${id}`), act('other')));
    await assertFails(updateDoc(doc(fs('ws'), `team_alerts/${id}`), act('lm')));
    await assertFails(updateDoc(doc(fs('ws'), `team_alerts/${id}`), { ...act('ws'), level: 0 }));
    await assertFails(updateDoc(doc(fs('ws'), `team_alerts/${id}`), act('ws', { taken: 'yes' })));
    await assertSucceeds(updateDoc(doc(fs('ws'), `team_alerts/${id}`), act('ws', { preset: 'called' })));
    await assertFails(updateDoc(doc(fs('lm'), `team_alerts/${id}`), act('lm', { taken: false })));
  });

  test('"no action taken" is a valid answer', async () => {
    await assertSucceeds(updateDoc(doc(fs('lm'), `team_alerts/${id}`), act('lm', { taken: false, note: '' })));
  });
});
