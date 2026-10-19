// Security rules tests for the roles (run: cd test_rules && npm test).
// Uses the local emulators with a demo project: nothing reaches Firebase.
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, serverTimestamp, updateDoc } from 'firebase/firestore';
import { ref, get, set } from 'firebase/database';

let env;

const users = {
  exec: { role: 'sales_exec', kamId: 'kam' },
  kam: { role: 'kam' },
  sm: { role: 'sales_manager' },
  gm: { role: 'gm' },
  hr: { role: 'hr' },
  acc: { role: 'accounting' },
  proc: { role: 'procurement' },
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
    const db = ctx.firestore();
    for (const [uid, u] of Object.entries(users)) {
      await setDoc(doc(db, 'users', uid), { name: uid, active: true, ...u });
      await set(ref(ctx.database(), `roles/${uid}`), u.role);
    }
    await setDoc(doc(db, 'clients', 'c1'), { name: 'Client', assignedTo: 'exec' });
    await setDoc(doc(db, 'visits', 'v1'), { clientId: 'c1', salesExecId: 'exec' });
    await set(ref(ctx.database(), 'live_locations/exec'), { lat: 1, lng: 2, updatedAt: 1 });
  });
});

const fs = (uid) => env.authenticatedContext(uid).firestore();
const rtdb = (uid) => env.authenticatedContext(uid).database();

const visit = (uid) => ({ clientId: 'c1', clientName: 'Client', salesExecId: uid, checkedInAt: serverTimestamp() });
const client = (uid) => ({ name: 'New', assignedTo: uid, source: 'manual' });
const task = (uid) => ({ ownerId: uid, createdBy: uid, approval: 'pending', date: '2026-10-17' });

describe('back-office roles see and create no sales data', () => {
  for (const uid of ['hr', 'acc', 'proc']) {
    test(`${uid}: no clients, visits or live locations`, async () => {
      await assertFails(getDoc(doc(fs(uid), 'clients/c1')));
      await assertFails(getDoc(doc(fs(uid), 'visits/v1')));
      await assertFails(get(ref(rtdb(uid), 'live_locations')));
      await assertFails(get(ref(rtdb(uid), 'location_history')));
    });

    test(`${uid}: can't add clients, visits or plan items for themselves`, async () => {
      await assertFails(setDoc(doc(fs(uid), 'clients/new'), client(uid)));
      await assertFails(setDoc(doc(fs(uid), 'visits/new'), visit(uid)));
      await assertFails(setDoc(doc(fs(uid), 'tasks/new'), task(uid)));
    });

    test(`${uid}: reads own profile, can't change own role`, async () => {
      await assertSucceeds(getDoc(doc(fs(uid), `users/${uid}`)));
      await assertFails(setDoc(doc(fs(uid), `users/${uid}`), { role: 'gm' }, { merge: true }));
    });
  }
});

describe('sales team keeps its access', () => {
  test('sales exec reads own client and adds own visit, client and plan item', async () => {
    await assertSucceeds(getDoc(doc(fs('exec'), 'clients/c1')));
    await assertSucceeds(setDoc(doc(fs('exec'), 'visits/new'), visit('exec')));
    await assertSucceeds(setDoc(doc(fs('exec'), 'clients/new'), client('exec')));
    await assertSucceeds(setDoc(doc(fs('exec'), 'tasks/new'), task('exec')));
  });

  test('sales exec adds locations to own clients only, never changes the category', async () => {
    const locations = { mainLocationType: 'office', extraLocations: [{ id: 'l1', typeId: 'factory', lat: 24.8, lng: 46.8, address: '' }] };
    await assertSucceeds(updateDoc(doc(fs('exec'), 'clients/c1'), locations));
    await assertFails(updateDoc(doc(fs('exec'), 'clients/c1'), { category: 'A' }));
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'clients/c2'), { name: 'Other', assignedTo: 'someoneElse' }));
    await assertFails(updateDoc(doc(fs('exec'), 'clients/c2'), locations));
  });

  test('sales exec records catalogs / stands given on own clients only', async () => {
    const given = { 'given.switchCatalog.at': serverTimestamp(), 'given.switchCatalog.qty': 2, lastVisitAt: serverTimestamp() };
    await assertSucceeds(updateDoc(doc(fs('exec'), 'clients/c1'), given));
    const log = { givenLog: [{ id: 'm1', item: 'bookletCatalog', qty: 1, at: new Date('2026-03-01'), byId: 'exec' }] };
    await assertSucceeds(updateDoc(doc(fs('exec'), 'clients/c1'), log));
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'clients/c2'), { name: 'Other', assignedTo: 'someoneElse' }));
    await assertFails(updateDoc(doc(fs('exec'), 'clients/c2'), given));
    await assertFails(updateDoc(doc(fs('exec'), 'clients/c2'), log));
  });

  test('a new account registers itself: inactive, pending, no role — nothing more', async () => {
    const reg = { name: 'New', email: 'n@x.com', phone: '1', position: 'Driver', companyId: 'c1', role: '', active: false, approval: 'pending', registeredAt: serverTimestamp() };
    await assertSucceeds(setDoc(doc(fs('newbie'), 'users/newbie'), reg));
    await assertFails(setDoc(doc(fs('newbie2'), 'users/newbie2'), { ...reg, role: 'gm' }));
    await assertFails(setDoc(doc(fs('newbie3'), 'users/newbie3'), { ...reg, active: true }));
    await assertFails(setDoc(doc(fs('newbie4'), 'users/someoneElse'), reg));
    // Pending: no sales data, can read companies even signed out.
    await assertFails(getDoc(doc(fs('newbie'), 'clients/c1')));
    await assertSucceeds(getDoc(doc(env.unauthenticatedContext().firestore(), 'companies/x')));
    await assertSucceeds(getDoc(doc(env.unauthenticatedContext().firestore(), 'settings/positions')));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'settings/visitRules')));
    await assertFails(setDoc(doc(fs('exec'), 'settings/positions'), { tags: [] }));
    await assertFails(setDoc(doc(fs('exec'), 'companies/x'), { name: 'X' }));
    await assertSucceeds(setDoc(doc(fs('sm'), 'companies/x'), { name: 'X' }));
  });

  test('attendance: own day, events only; HR area reads; results only by the server', async () => {
    const ev = { uid: 'acc', date: '2026-10-20', month: '2026-10', events: [{ type: 'in', at: new Date(), siteId: 's' }] };
    await assertSucceeds(setDoc(doc(fs('acc'), 'attendance/acc_2026-10-20'), ev));
    await assertFails(setDoc(doc(fs('acc'), 'attendance/exec_2026-10-20'), { ...ev, uid: 'exec' }));
    await assertFails(setDoc(doc(fs('acc'), 'attendance/acc_2026-10-21'), ev)); // id ≠ date
    await assertFails(updateDoc(doc(fs('acc'), 'attendance/acc_2026-10-20'), { checkOutAt: new Date() }));
    await assertSucceeds(updateDoc(doc(fs('acc'), 'attendance/acc_2026-10-20'), { events: [] }));
    await assertSucceeds(getDoc(doc(fs('hr'), 'attendance/acc_2026-10-20')));
    await assertFails(getDoc(doc(fs('proc'), 'attendance/acc_2026-10-20')));
    await assertFails(setDoc(doc(fs('exec'), 'work_sites/s'), { name: 'HQ' }));
    await assertSucceeds(setDoc(doc(fs('gm'), 'work_sites/s'), { name: 'HQ' }));
  });

  test('everyone saves their own app version, not others\' and not the reminder time', async () => {
    const v = { 'appVersions.android': { version: '1.0.4', build: 9, at: serverTimestamp() } };
    await assertSucceeds(updateDoc(doc(fs('exec'), 'users/exec'), v));
    await assertSucceeds(updateDoc(doc(fs('hr'), 'users/hr'), v));
    await assertFails(updateDoc(doc(fs('exec'), 'users/kam'), v));
    await assertFails(updateDoc(doc(fs('exec'), 'users/exec'), { updateRemindedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(doc(fs('gm'), 'users/exec'), { updateRemindedAt: serverTimestamp() }));
  });

  test('sales exec asks to close own client, never sets the status or asks as someone else', async () => {
    const ask = { statusRequest: { status: 'closed', byId: 'exec', at: serverTimestamp(), note: 'Shop shut' } };
    await assertSucceeds(updateDoc(doc(fs('exec'), 'clients/c1'), ask));
    await assertSucceeds(updateDoc(doc(fs('exec'), 'clients/c1'), { statusRequest: null }));
    await assertFails(updateDoc(doc(fs('exec'), 'clients/c1'), { status: 'closed' }));
    await assertFails(updateDoc(doc(fs('exec'), 'clients/c1'), { statusRequest: { status: 'closed', byId: 'kam' } }));
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'clients/c2'), { name: 'Other', assignedTo: 'someoneElse' }));
    await assertFails(updateDoc(doc(fs('exec'), 'clients/c2'), ask));
  });

  test('KAM and managers approve: set the status and clear the request', async () => {
    for (const uid of ['kam', 'sm', 'gm']) {
      await assertSucceeds(updateDoc(doc(fs(uid), 'clients/c1'), {
        status: 'notWorking', statusAt: serverTimestamp(), statusRequest: null,
      }));
    }
  });

    test('KAM and managers read clients, visits and live locations', async () => {
    for (const uid of ['kam', 'sm', 'gm']) {
      await assertSucceeds(getDoc(doc(fs(uid), 'clients/c1')));
      await assertSucceeds(getDoc(doc(fs(uid), 'visits/v1')));
      await assertSucceeds(get(ref(rtdb(uid), 'live_locations')));
    }
  });
});

describe('RTDB role mirror', () => {
  test('GM can set the new roles, not made-up ones', async () => {
    for (const role of ['hr', 'accounting', 'procurement', 'sales_exec']) {
      await assertSucceeds(set(ref(rtdb('gm'), 'roles/someone'), role));
    }
    await assertFails(set(ref(rtdb('gm'), 'roles/someone'), 'boss'));
    await assertFails(set(ref(rtdb('gm'), 'roles/someone'), ''));
  });

  test('HR can\'t set roles', async () => {
    await assertFails(set(ref(rtdb('hr'), 'roles/hr'), 'gm'));
  });
});
