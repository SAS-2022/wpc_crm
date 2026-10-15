const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentCreated, onDocumentDeleted } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onValueWritten } = require('firebase-functions/v2/database');
const admin = require('firebase-admin');

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
  return null;
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
    tracking_offline: (n) => `${n} has been offline for over 30 minutes during work hours`,
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
    tracking_offline: (n) => `${n} غير متصل منذ أكثر من 30 دقيقة خلال ساعات العمل`,
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
  // For client transfers ownerId is the other sales executive (empty = unassigned).
  const other = n.type === 'clientsTransferredOut' && n.ownerId ? `users/${n.ownerId}` : null;
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
      data: { route: '/notifications', notificationId: event.params.id },
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

// Tracking problems of a sales exec, from their presence (written by the phone).
// Only while online and on duty: outside work hours location may be off.
function trackingIssues(p) {
  if (!p || p.online === false || p.onDuty !== true) return [];
  const issues = [];
  if (p.gpsOn === false) issues.push('gpsOff');
  if (p.permission === 'denied' || p.permission === 'deniedForever') issues.push('locationDenied');
  else if (p.permission === 'whileInUse') issues.push('notAlways');
  if (p.batteryOptimized === true) issues.push('battery');
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
  return events;
}

/** The same warning about one person is sent at most this often. */
const ALERT_COOLDOWN_MS = 30 * 60 * 1000;

/**
 * On every presence change: writes the tracking log (RTDB
 * `tracking_events/{uid}/{day}`, kept EVENT_DAYS), and warns the sales exec's
 * KAM and the sales managers (in-app + push through sendPush) when the exec
 * turns off GPS, reduces the location permission or turns on battery
 * optimization during work hours. Going offline is warned about by
 * offlineAlerts, only after OFFLINE_ALERT_MS. Outside work hours (server
 * clock, RTDB settings/workHours) nothing is logged or sent.
 */
exports.trackingAlerts = onValueWritten({ ref: '/presence/{uid}', maxInstances: 5 }, async (event) => {
  const beforeVal = event.data.before.val();
  const afterVal = event.data.after.val();
  const changes = presenceEvents(beforeVal, afterVal);
  const freshIssues = trackingIssues(afterVal).filter((i) => !trackingIssues(beforeVal).includes(i));
  if (changes.length === 0 && freshIssues.length === 0) return;

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

  const fresh = working ? freshIssues : [];
  if (fresh.length === 0) return;

  const uid = event.params.uid;
  const db = admin.firestore();
  const user = await db.doc(`users/${uid}`).get();
  if (user.get('role') !== 'sales_exec' || user.get('active') !== true) return;

  const sentRef = admin.database().ref(`tracking_alerts/${uid}`);
  const sent = (await sentRef.get()).val() || {};
  const now = Date.now();
  const issues = fresh.filter((i) => !(sent[i] > now - ALERT_COOLDOWN_MS));
  if (issues.length === 0) return;

  const managers = await db.collection('users').where('role', '==', 'sales_manager').where('active', '==', true).get();
  const to = new Set(managers.docs.map((d) => d.id));
  const kamId = user.get('kamId');
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
      for (const [path, days] of [['location_history', ROUTE_DAYS], ['tracking_events', EVENT_DAYS]]) {
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
