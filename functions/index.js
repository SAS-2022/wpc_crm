const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentCreated, onDocumentDeleted } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onValueWritten } = require('firebase-functions/v2/database');
const admin = require('firebase-admin');
const { findMatches } = require('./duplicates');
const { coordsFromPlusCode } = require('./plusCode');

const SALES_ROLES = ['sales_exec', 'kam', 'sales_manager', 'gm'];

admin.initializeApp();

// Only Google Maps short links are followed, so this can't be used to fetch arbitrary URLs.
const ALLOWED_HOSTS = new Set([
  'maps.app.goo.gl', 'goo.gl', 'share.google', 'g.co',
  'www.google.com', 'google.com', 'maps.google.com', 'www.google.com.sa', 'google.com.sa',
]);
const NUM = '(-?\\d{1,3}\\.\\d+)';
const PATTERNS = [
  new RegExp(`!3d${NUM}!4d${NUM}`),
  new RegExp(`[?&](?:q|query|ll|destination|center)=${NUM},\\s*${NUM}`),
  new RegExp(`@${NUM},${NUM}`),
];

function coordsFromUrl(url) {
  let s = url.replace(/\+/g, ' ');
  try { s = decodeURIComponent(s); } catch (_) { /* keep raw */ }
  for (const re of PATTERNS) {
    const m = s.match(re);
    if (!m) continue;
    const lat = Number(m[1]);
    const lng = Number(m[2]);
    if (Math.abs(lat) <= 90 && Math.abs(lng) <= 180) return { lat, lng };
  }
  // Place links shared without coordinates carry a Plus Code instead.
  return coordsFromPlusCode(s);
}

async function resolve(url) {
  let current = url;
  for (let hop = 0; hop < 6; hop++) {
    let parsed;
    try { parsed = new URL(current); } catch (_) { return null; }
    if (!ALLOWED_HOSTS.has(parsed.hostname)) return null;
    const coords = coordsFromUrl(current);
    if (coords) return coords;
    const res = await fetch(current, { redirect: 'manual', signal: AbortSignal.timeout(8000) });
    const next = res.headers.get('location');
    if (!next) return null;
    current = new URL(next, current).toString();
  }
  return null;
}

/**
 * Turns Google Maps short links into coordinates, for the web app (browsers
 * can't follow them). Any active user: KAMs and sales execs paste a client's
 * link on the dashboard; imports (sales manager / GM) send up to 50 at once.
 */
exports.resolvePins = onCall({ timeoutSeconds: 120, maxInstances: 2 }, async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in first');
  const me = await admin.firestore().doc(`users/${req.auth.uid}`).get();
  if (!me.exists || me.get('active') !== true) throw new HttpsError('permission-denied', 'Active users only');
  const max = ['sales_manager', 'gm'].includes(me.get('role')) ? 50 : 5;
  const urls = Array.isArray(req.data?.urls) ? req.data.urls.filter((u) => typeof u === 'string').slice(0, max) : [];
  const results = {};
  await Promise.all(urls.map(async (url) => {
    try { results[url] = await resolve(url); } catch (_) { results[url] = null; }
  }));
  return results;
});

/**
 * Before a client is added in the app: clients that look like it (see
 * duplicates.js). Runs on the server because a sales exec can only read
 * their own clients. Returns {matches: [{id, name, city, assignedTo,
 * ownerName, reasons}]}, at most 5.
 */
exports.findClientDuplicates = onCall({ maxInstances: 5 }, async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in first');
  const db = admin.firestore();
  const me = await db.doc(`users/${req.auth.uid}`).get();
  if (!me.exists || me.get('active') !== true || !SALES_ROLES.includes(me.get('role'))) {
    throw new HttpsError('permission-denied', 'Sales users only');
  }
  const d = req.data || {};
  const str = (v) => (typeof v === 'string' ? v.slice(0, 200) : '');
  const num = (v) => (typeof v === 'number' && Number.isFinite(v) ? v : null);
  const draft = {
    name: str(d.name), vat: str(d.vat), companyId: str(d.companyId),
    phone: str(d.phone), mobile: str(d.mobile), lat: num(d.lat), lng: num(d.lng),
  };
  if (!draft.name.trim()) return { matches: [] };
  const snap = await db.collection('clients')
    .select('name', 'aliases', 'vat', 'companyId', 'phone', 'mobile', 'lat', 'lng', 'city', 'assignedTo')
    .get();
  const clients = snap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
  const matches = findMatches(draft, clients);
  const owners = new Map();
  await Promise.all([...new Set(matches.map((m) => m.client.assignedTo).filter(Boolean))].map(async (uid) => {
    owners.set(uid, (await db.doc(`users/${uid}`).get()).get('name') || '');
  }));
  return {
    matches: matches.map(({ client: c, reasons }) => ({
      id: c.id,
      name: c.name || '',
      city: c.city || '',
      assignedTo: c.assignedTo || null,
      ownerName: owners.get(c.assignedTo) || '',
      reasons,
    })),
  };
});

// Push texts, same wording as the in-app list (app_en.arb / app_ar.arb).
const TEXTS = {
  en: {
    title: 'WPC CRM',
    planSubmitted: (n, c, d) => `${n} added ${c} items to their plan for ${d} – waiting for your approval`,
    planApproved: (n, c, d) => `${n} approved your plan for ${d}`,
    planRejected: (n, c, d) => `${n} rejected an item in your plan for ${d}`,
    planChanged: (n, c, d) => `${n} changed your plan for ${d}`,
    planItemsAdded: (n, c, d) => `${n} added ${c} item(s) to your plan for ${d}`,
    clientsTransferredIn: (n, c) => `${n} moved ${c} clients to you`,
    clientsTransferredOut: (n, c, d, o) => `${n} moved ${c} of your clients to ${o || 'Unassigned'}`,
    tracking_gpsOff: (n) => `${n} turned off location (GPS)`,
    tracking_locationDenied: (n) => `${n} removed the app's location permission`,
    tracking_notAlways: (n) => `${n} allowed location only while using the app – tracking stops in the background`,
    tracking_battery: (n) => `${n} turned on battery optimization for WPC CRM – tracking may stop`,
    tracking_notificationsOff: (n) => `${n} turned off notifications for WPC CRM`,
    tracking_offline: (n) => `${n} has been offline for over 30 minutes during work hours`,
    leaveRequested: (n, c, d, o) => `Leave request from ${o} – waiting for your approval`,
    leaveApproved: (n) => `${n} approved your request`,
    leaveRejected: (n) => `${n} rejected your request`,
  },
  ar: {
    title: 'WPC CRM',
    planSubmitted: (n, c, d) => `أضاف ${n} ${c} عنصر إلى خطته ليوم ${d} – بانتظار موافقتك`,
    planApproved: (n, c, d) => `وافق ${n} على خطتك ليوم ${d}`,
    planRejected: (n, c, d) => `رفض ${n} عنصراً في خطتك ليوم ${d}`,
    planChanged: (n, c, d) => `عدّل ${n} خطتك ليوم ${d}`,
    planItemsAdded: (n, c, d) => `أضاف ${n} ${c} عنصر إلى خطتك ليوم ${d}`,
    clientsTransferredIn: (n, c) => `نقل ${n} ${c} عميل إليك`,
    clientsTransferredOut: (n, c, d, o) => `نقل ${n} ${c} من عملائك إلى ${o || 'غير مُسند'}`,
    tracking_gpsOff: (n) => `أوقف ${n} خدمة الموقع (GPS)`,
    tracking_locationDenied: (n) => `ألغى ${n} إذن الموقع للتطبيق`,
    tracking_notAlways: (n) => `سمح ${n} بالموقع أثناء استخدام التطبيق فقط – يتوقف التتبع في الخلفية`,
    tracking_battery: (n) => `فعّل ${n} تحسين البطارية لتطبيق WPC CRM – قد يتوقف التتبع`,
    tracking_notificationsOff: (n) => `أوقف ${n} الإشعارات لتطبيق WPC CRM`,
    tracking_offline: (n) => `${n} غير متصل منذ أكثر من 30 دقيقة خلال ساعات العمل`,
    leaveRequested: (n, c, d, o) => `طلب من ${o} – بانتظار موافقتك`,
    leaveApproved: (n) => `وافق ${n} على طلبك`,
    leaveRejected: (n) => `رفض ${n} طلبك`,
  },
};

function formatDay(date, lang) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date || '')) return date || '';
  return new Intl.DateTimeFormat(lang, { weekday: 'short', month: 'short', day: 'numeric', timeZone: 'UTC' })
    .format(new Date(`${date}T00:00:00Z`));
}

/**
 * Turns each new in-app notification into a phone push to every device of the
 * recipient (tokens in `users/{uid}/devices/{token}`, saved by the app).
 */
exports.sendPush = onDocumentCreated({ document: 'notifications/{id}', maxInstances: 5 }, async (event) => {
  const n = event.data?.data();
  if (!n?.toId) return;
  const db = admin.firestore();
  // For client transfers ownerId is the other sales executive (empty = unassigned);
  // for leave requests it is the person who asked.
  const other = ['clientsTransferredOut', 'leaveRequested'].includes(n.type) && n.ownerId ? `users/${n.ownerId}` : null;
  const [to, from, devices, otherUser] = await Promise.all([
    db.doc(`users/${n.toId}`).get(),
    db.doc(`users/${n.fromId}`).get(),
    db.collection(`users/${n.toId}/devices`).get(),
    other ? db.doc(other).get() : null,
  ]);
  if (to.get('active') !== true || devices.empty) return;

  const fromName = from.get('name') || '';
  const byLang = {};
  for (const d of devices.docs) {
    const lang = d.get('lang') === 'ar' ? 'ar' : 'en';
    (byLang[lang] ||= []).push(d.id);
  }

  const stale = [];
  await Promise.all(Object.entries(byLang).map(async ([lang, tokens]) => {
    const t = TEXTS[lang];
    const key = n.type === 'trackingIssue' ? `tracking_${n.issue}` : n.type;
    const body = (t[key] || t.planChanged)(fromName, n.count || 0, formatDay(n.date, lang), otherUser?.get('name') || '');
    const res = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: { title: t.title, body },
      data: { route: n.ref && n.type.startsWith('leave') ? `/leave/${n.ref}` : '/notifications', notificationId: event.params.id },
      android: { priority: 'high' },
      apns: { payload: { aps: { sound: 'default' } } },
    });
    res.responses.forEach((r, i) => {
      const code = r.error?.code;
      if (code === 'messaging/registration-token-not-registered' || code === 'messaging/invalid-registration-token') {
        stale.push(tokens[i]);
      }
    });
  }));
  await Promise.all(stale.map((token) => db.doc(`users/${n.toId}/devices/${token}`).delete()));
});

// Tracking problems of a sales exec or KAM, from their presence (written by the phone).
// Only while online and on duty: outside work hours location may be off.
function trackingIssues(p) {
  if (!p || p.online === false || p.onDuty !== true) return [];
  const issues = [];
  if (p.gpsOn === false) issues.push('gpsOff');
  if (p.permission === 'denied' || p.permission === 'deniedForever') issues.push('locationDenied');
  else if (p.permission === 'whileInUse') issues.push('notAlways');
  if (p.batteryOptimized === true) issues.push('battery');
  if (p.notifications === false) issues.push('notificationsOff');
  return issues;
}

/** Tracking log days kept (user decision: 30). */
const EVENT_DAYS = 30;

const saudiDay = (ms) => new Date(ms + 3 * 3600 * 1000).toISOString().slice(0, 10);

// What changed between two presence values, for the tracking log. GPS,
// permission and battery are logged only when a previous value existed
// (a first report is not a change).
function presenceEvents(before, after) {
  if (!after) return [];
  const b = before || {};
  const events = [];
  if (typeof after.online === 'boolean' && b.online !== after.online) events.push({ type: after.online ? 'online' : 'offline' });
  if (typeof after.onDuty === 'boolean' && b.onDuty !== undefined && b.onDuty !== after.onDuty) {
    events.push({ type: after.onDuty ? 'onDuty' : 'offDuty' });
  }
  if (typeof after.gpsOn === 'boolean' && b.gpsOn !== undefined && b.gpsOn !== after.gpsOn) {
    events.push({ type: after.gpsOn ? 'gpsOn' : 'gpsOff' });
  }
  if (after.permission && b.permission && b.permission !== after.permission) {
    events.push({ type: 'permission', value: after.permission });
  }
  if (typeof after.batteryOptimized === 'boolean' && typeof b.batteryOptimized === 'boolean'
    && b.batteryOptimized !== after.batteryOptimized) {
    events.push({ type: after.batteryOptimized ? 'batteryOn' : 'batteryOff' });
  }
  if (typeof after.notifications === 'boolean' && typeof b.notifications === 'boolean'
    && b.notifications !== after.notifications) {
    events.push({ type: after.notifications ? 'notificationsOn' : 'notificationsOff' });
  }
  return events;
}

const { issuesToReport } = require('./trackingAlerts');

/**
 * On every presence change: writes the tracking log (RTDB
 * `tracking_events/{uid}/{day}`, kept EVENT_DAYS), and warns the sales
 * managers, the GM and, for a sales exec, their KAM (in-app + push through
 * sendPush) when a sales exec or KAM turns off GPS, reduces the location
 * permission, turns off notifications or turns on battery optimization during
 * work hours. Going offline is warned about by
 * offlineAlerts, only after OFFLINE_ALERT_MS. Outside work hours (server
 * clock, RTDB settings/workHours) nothing is logged or sent.
 */
exports.trackingAlerts = onValueWritten({ ref: '/presence/{uid}', maxInstances: 5 }, async (event) => {
  const beforeVal = event.data.before.val();
  const afterVal = event.data.after.val();
  const changes = presenceEvents(beforeVal, afterVal);
  // Issues are judged only while online and on duty; the problems already
  // reported are kept in tracking_alerts/{uid}/active, so a phone that keeps
  // reconnecting with GPS still off is not reported again on every reconnect.
  const checkIssues = !!afterVal && afterVal.online !== false && afterVal.onDuty === true;
  if (changes.length === 0 && !checkIssues) return;

  // Silent outside work hours (user decision): nothing is logged or sent
  // except the start / end of duty itself.
  const hours = workHours((await admin.database().ref('settings/workHours').get()).val());
  const working = workStartToday(hours, Date.now()) !== null;
  const events = working ? changes : changes.filter((e) => e.type === 'onDuty' || e.type === 'offDuty');
  if (events.length > 0) {
    // Going offline is stamped when the server noticed it (lastSeen).
    const t = typeof afterVal.lastSeen === 'number' && afterVal.online === false ? afterVal.lastSeen : Date.now();
    const dayRef = admin.database().ref(`tracking_events/${event.params.uid}/${saudiDay(t)}`);
    await Promise.all(events.map((e) => dayRef.push({ ...e, t })));
  }

  if (!working || !checkIssues) return;

  const uid = event.params.uid;
  const now = Date.now();
  const today = saudiDay(now);
  const current = trackingIssues(afterVal);
  const sentRef = admin.database().ref(`tracking_alerts/${uid}`);
  const sent = (await sentRef.get()).val() || {};
  const active = sent.active || {};
  const { issues, active: nextActive } = issuesToReport(current, active, sent, now, today);
  if (JSON.stringify(nextActive) !== JSON.stringify(active)) await sentRef.child('active').set(nextActive);
  if (issues.length === 0) return;

  const db = admin.firestore();
  const user = await db.doc(`users/${uid}`).get();
  const role = user.get('role');
  if ((role !== 'sales_exec' && role !== 'kam') || user.get('active') !== true) return;

  const managers = await db.collection('users').where('role', 'in', ['sales_manager', 'gm']).where('active', '==', true).get();
  const to = new Set(managers.docs.map((d) => d.id));
  const kamId = role === 'sales_exec' ? user.get('kamId') : null;
  if (kamId) {
    const kam = await db.doc(`users/${kamId}`).get();
    if (kam.get('active') === true) to.add(kamId);
  }
  to.delete(uid);
  if (to.size === 0) return;

  const day = new Date(now + 3 * 3600 * 1000).toISOString().slice(0, 10); // Saudi date
  const batch = db.batch();
  for (const toId of to) {
    for (const issue of issues) {
      batch.set(db.collection('notifications').doc(), {
        toId,
        type: 'trackingIssue',
        issue,
        fromId: uid,
        ownerId: uid,
        date: day,
        count: 0,
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  }
  await batch.commit();
  await sentRef.update(Object.fromEntries(issues.map((i) => [i, now])));
});

/** A sales exec offline this long during work hours is reported (user decision: 30 min). */
const OFFLINE_ALERT_MS = 30 * 60 * 1000;

// Saturday to Thursday 08:00–17:00 Saudi time; same as WorkHours.defaults.
const DEFAULT_WORK_HOURS = { days: [6, 7, 1, 2, 3, 4], start: 8 * 60, end: 17 * 60 };

/** Work hours from RTDB settings/workHours (same rules as work_hours.dart). */
function workHours(v) {
  if (!v || !Array.isArray(v.days) || typeof v.start !== 'number' || typeof v.end !== 'number' || v.end <= v.start) {
    return DEFAULT_WORK_HOURS;
  }
  return { days: v.days.filter((d) => d >= 1 && d <= 7), start: v.start, end: v.end };
}

/** Today's work start (ms) when [now] is within work hours, else null. */
function workStartToday(hours, now) {
  const saudi = new Date(now + 3 * 3600 * 1000);
  const weekday = saudi.getUTCDay() === 0 ? 7 : saudi.getUTCDay(); // Monday = 1 … Sunday = 7
  const minute = saudi.getUTCHours() * 60 + saudi.getUTCMinutes();
  if (!hours.days.includes(weekday) || minute < hours.start || minute >= hours.end) return null;
  return now - (minute - hours.start) * 60 * 1000 - saudi.getUTCSeconds() * 1000 - saudi.getUTCMilliseconds();
}

/**
 * Every 5 minutes during work hours: a sales exec whose phone has been
 * offline for OFFLINE_ALERT_MS of work time is reported once per offline
 * spell to their KAM (to the sales managers when they have no KAM). Coming
 * back online is only logged, not notified (user decision: not too many
 * notifications).
 */
exports.offlineAlerts = onSchedule(
  { schedule: 'every 5 minutes', timeZone: 'Asia/Riyadh', maxInstances: 1 },
  async () => {
    const rtdb = admin.database();
    const now = Date.now();
    const hours = workHours((await rtdb.ref('settings/workHours').get()).val());
    const start = workStartToday(hours, now);
    if (start === null) return;

    const [presence, sentSnap] = await Promise.all([rtdb.ref('presence').get(), rtdb.ref('tracking_alerts').get()]);
    const sent = sentSnap.val() || {};
    const due = [];
    presence.forEach((p) => {
      const v = p.val() || {};
      if (v.online !== false || typeof v.lastSeen !== 'number') return;
      // Only work time counts: offline overnight is reported 30 min into the day.
      if (now - Math.max(v.lastSeen, start) < OFFLINE_ALERT_MS) return;
      if (sent[p.key]?.offlineSince === v.lastSeen) return;
      due.push({ uid: p.key, since: v.lastSeen });
    });
    if (due.length === 0) return;

    const db = admin.firestore();
    const users = new Map((await db.collection('users').get()).docs.map((d) => [d.id, d.data()]));
    const managers = [...users].filter(([, u]) => u.role === 'sales_manager' && u.active === true).map(([id]) => id);
    const batch = db.batch();
    const marks = {};
    for (const { uid, since } of due) {
      const user = users.get(uid);
      marks[`${uid}/offlineSince`] = since;
      if (user?.role !== 'sales_exec' || user.active !== true) continue;
      const kam = users.get(user.kamId);
      const to = kam?.active === true ? [user.kamId] : managers;
      for (const toId of to) {
        batch.set(db.collection('notifications').doc(), {
          toId,
          type: 'trackingIssue',
          issue: 'offline',
          fromId: uid,
          ownerId: uid,
          date: saudiDay(now),
          count: 0,
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }
    await batch.commit();
    await rtdb.ref('tracking_alerts').update(marks);
  },
);

/** Route points are kept this many days (user decision), visits are kept. */
const ROUTE_DAYS = 90;

/**
 * Every night deletes RTDB `location_history/{uid}/{yyyy-MM-dd}` days older
 * than ROUTE_DAYS and `tracking_events/{uid}/{yyyy-MM-dd}` days older than
 * EVENT_DAYS (Saudi time). Day keys sort as dates, so one key-range
 * query per person finds the old days. People come from Firestore `users`
 * and RTDB `roles`, which also covers deleted users whose role is still there.
 */
exports.cleanRouteHistory = onSchedule(
  { schedule: '0 3 * * *', timeZone: 'Asia/Riyadh', maxInstances: 1 },
  async () => {
    // Last day to delete for a retention of [days].
    const lastOld = (days) => saudiDay(Date.now() - (days + 1) * 24 * 3600 * 1000);

    const rtdb = admin.database();
    const [users, roles] = await Promise.all([
      admin.firestore().collection('users').select().get(),
      rtdb.ref('roles').get(),
    ]);
    const uids = new Set([...users.docs.map((d) => d.id), ...Object.keys(roles.val() || {})]);

    let removed = 0;
    for (const uid of uids) {
      for (const [path, days] of [['location_history', ROUTE_DAYS], ['route_snapped', ROUTE_DAYS], ['tracking_events', EVENT_DAYS]]) {
        const ref = rtdb.ref(`${path}/${uid}`);
        const old = await ref.orderByKey().endAt(lastOld(days)).get();
        const updates = {};
        old.forEach((day) => { updates[day.key] = null; });
        const count = Object.keys(updates).length;
        if (count === 0) continue;
        await ref.update(updates);
        removed += count;
      }
    }
    console.log(`cleanRouteHistory: removed ${removed} day(s) of routes / tracking log`);
  },
);

/**
 * When a sales manager / GM deletes a visit, removes its comments and
 * attachment records and the attachment files in Storage.
 */
exports.cleanDeletedVisit = onDocumentDeleted({ document: 'visits/{id}', maxInstances: 5 }, async (event) => {
  const id = event.params.id;
  await admin.firestore().recursiveDelete(admin.firestore().doc(`visits/${id}`));
  await admin.storage().bucket().deleteFiles({ prefix: `visits/${id}/` });
});

// --- Road-following route history ---------------------------------------

const ROUTE_MAX_ACCURACY = 100; // same as _maxAccuracy in report.dart
const ROUTE_GAP_MS = 15 * 60 * 1000; // same as routeGap in report.dart
const ROUTE_MIN_MOVE = 150; // closer fixes count as standing still (no routing between them)
// Fixes come every 30 s (2 min before 2026-10-18); routing between waypoints
// at least this far apart in time keeps the Routes API calls as before.
const ROUTE_MIN_GAP_MS = 100 * 1000;
const ROUTE_LEGS_PER_CALL = 10; // ≤10 intermediate waypoints stays on the cheaper Routes SKU
const ROUTE_MAX_LEGS = 400; // per call, a safety cap on cost

function metersBetween(a, b) {
  const rad = (d) => (d * Math.PI) / 180;
  const dLat = rad(b.lat - a.lat);
  const dLng = rad(b.lng - a.lng);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * 6371000 * Math.asin(Math.sqrt(h));
}

const TRACK_MAX_KMH = 200; // same as _maxTrackKmh in report.dart

/**
 * The points of one continuous track (same as mainTrack in report.dart):
 * drops a second phone signed in to the same account elsewhere, and far
 * GPS glitches. [path] is sorted by time.
 */
function mainTrack(path) {
  const tracks = [];
  for (const p of path) {
    let best = null;
    for (const track of tracks) {
      const last = track[track.length - 1];
      const m = metersBetween(last, p);
      const hours = (p.t - last.t) / 3600000;
      const ok = m <= 5000 || m / 1000 <= TRACK_MAX_KMH * hours; // 5 km: queued offline points share one time
      if (ok && (!best || last.t > best[best.length - 1].t)) best = track;
    }
    if (best) best.push(p); else tracks.push([p]);
  }
  if (tracks.length < 2) return path;
  tracks.sort((a, b) => b.length - a.length);
  const main = tracks[0];
  const first = main[0].t;
  const last = main[main.length - 1].t;
  return [
    ...main,
    ...tracks.slice(1).filter((t) => t.length >= 5 && (t[t.length - 1].t < first || t[0].t > last)).flat(),
  ].sort((a, b) => a.t - b.t);
}

/** Fixes worth routing between: good accuracy, one phone's track, per run of continuous tracking, stops collapsed. */
function routeLegs(raw) {
  const path = mainTrack(Object.values(raw || {})
    .filter((p) => typeof p?.lat === 'number' && typeof p?.lng === 'number' && typeof p?.t === 'number')
    .filter((p) => (p.accuracy || 0) <= ROUTE_MAX_ACCURACY)
    .sort((a, b) => a.t - b.t));
  const legs = [];
  let last = null; // last kept fix
  let prev = null; // last fix seen
  for (const p of path) {
    if (!prev || p.t - prev.t > ROUTE_GAP_MS) {
      last = p; // new run
    } else if (p.t - last.t >= ROUTE_MIN_GAP_MS
      && metersBetween(last, p) > Math.max(ROUTE_MIN_MOVE, (last.accuracy || 0) + (p.accuracy || 0))) {
      legs.push([last, p]);
      last = p;
    }
    prev = p;
  }
  return legs;
}

/** Drives through [points]; returns one {p, m, s} per leg, or null when no route was found. */
async function computeRoute(points, token) {
  const wp = (p) => ({ location: { latLng: { latitude: p.lat, longitude: p.lng } } });
  const res = await fetch('https://routes.googleapis.com/directions/v2:computeRoutes', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
      'X-Goog-FieldMask': 'routes.legs.polyline.encodedPolyline,routes.legs.distanceMeters,routes.legs.duration',
    },
    body: JSON.stringify({
      origin: wp(points[0]),
      destination: wp(points[points.length - 1]),
      intermediates: points.slice(1, -1).map(wp),
      travelMode: 'DRIVE',
      routingPreference: 'TRAFFIC_UNAWARE',
    }),
    signal: AbortSignal.timeout(15000),
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok) {
    // No route between some of the points: drawn straight. Anything else (API off, no permission) is an error.
    if (res.status === 400 || res.status === 404) return null;
    throw new HttpsError('failed-precondition', `Routes API ${res.status}: ${body?.error?.message || ''}`);
  }
  return body.routes?.[0]?.legs || null;
}

/**
 * Snaps one person's day of `location_history` to roads with the Routes API
 * and saves it in RTDB `route_snapped/{uid}/{day}` {n: history points handled,
 * legs: {"<fromT>_<toT>": {p: encoded polyline, m: meters} | {s: true, m}}}.
 * Legs already saved are not asked again, so each stretch is paid for once.
 * A road route much longer or slower than the time between the fixes allows
 * is replaced by a straight line (s: true). Callable by supervisors (KAM for
 * their team) and the person themselves.
 */
exports.snapRoute = onCall({ timeoutSeconds: 120, maxInstances: 3 }, async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in first');
  const { uid, day } = req.data || {};
  if (typeof uid !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(day || '')) throw new HttpsError('invalid-argument', 'uid and day');
  const db = admin.firestore();
  const me = await db.doc(`users/${req.auth.uid}`).get();
  if (!me.exists || me.get('active') !== true) throw new HttpsError('permission-denied', 'Active users only');
  const role = me.get('role');
  if (uid !== req.auth.uid && !['sales_manager', 'gm'].includes(role)) {
    const target = await db.doc(`users/${uid}`).get();
    if (role !== 'kam' || target.get('kamId') !== req.auth.uid) throw new HttpsError('permission-denied', 'Not your team');
  }

  const rtdb = admin.database();
  const outRef = rtdb.ref(`route_snapped/${uid}/${day}`);
  const [history, saved] = await Promise.all([rtdb.ref(`location_history/${uid}/${day}`).get(), outRef.child('legs').get()]);
  const raw = history.val() || {};
  const done = saved.val() || {};
  const key = ([a, b]) => `${a.t}_${b.t}`;
  const missing = routeLegs(raw).filter((leg) => !done[key(leg)]).slice(0, ROUTE_MAX_LEGS);

  // Consecutive missing legs (sharing a fix) go into one request.
  const chains = [];
  for (const leg of missing) {
    const chain = chains[chains.length - 1];
    if (chain && chain.length < ROUTE_LEGS_PER_CALL && chain[chain.length - 1][1] === leg[0]) chain.push(leg);
    else chains.push([leg]);
  }

  const updates = {};
  if (chains.length) {
    const { access_token: token } = await admin.credential.applicationDefault().getAccessToken();
    await Promise.all(chains.map(async (chain) => {
      const legs = await computeRoute([chain[0][0], ...chain.map((l) => l[1])], token);
      chain.forEach(([a, b], i) => {
        const straight = Math.round(metersBetween(a, b));
        const r = legs?.[i];
        const meters = r?.distanceMeters ?? 0;
        const seconds = parseInt(r?.duration || '0', 10);
        const elapsed = (b.t - a.t) / 1000;
        const plausible = r?.polyline?.encodedPolyline &&
          meters <= Math.max(2.5 * straight, straight + 2000) &&
          seconds <= Math.max(2 * elapsed, elapsed + 300);
        updates[`legs/${a.t}_${b.t}`] = plausible ? { p: r.polyline.encodedPolyline, m: meters } : { s: true, m: straight };
      });
    }));
  }
  updates.n = Object.keys(raw).length;
  await outRef.update(updates);
  return { snapped: Object.keys(updates).length - 1 };
});

// For tests.
exports._mainTrack = mainTrack;
