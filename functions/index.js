const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
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

/** Turns Google Maps short links into coordinates. Sales manager / GM only. */
exports.resolvePins = onCall({ timeoutSeconds: 120, maxInstances: 2 }, async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in first');
  const me = await admin.firestore().doc(`users/${req.auth.uid}`).get();
  if (!me.exists || me.get('active') !== true || !['sales_manager', 'gm'].includes(me.get('role'))) {
    throw new HttpsError('permission-denied', 'Managers only');
  }
  const urls = Array.isArray(req.data?.urls) ? req.data.urls.filter((u) => typeof u === 'string').slice(0, 50) : [];
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
    clientsTransferredIn: (n, c) => `${n} moved ${c} clients to you`,
    clientsTransferredOut: (n, c, d, o) => `${n} moved ${c} of your clients to ${o || 'Unassigned'}`,
    tracking_gpsOff: (n) => `${n} turned off location (GPS)`,
    tracking_locationDenied: (n) => `${n} removed the app's location permission`,
    tracking_notAlways: (n) => `${n} allowed location only while using the app – tracking stops in the background`,
    tracking_battery: (n) => `${n} turned on battery optimization for WPC CRM – tracking may stop`,
  },
  ar: {
    title: 'WPC CRM',
    planSubmitted: (n, c, d) => `أضاف ${n} ${c} عنصر إلى خطته ليوم ${d} – بانتظار موافقتك`,
    planApproved: (n, c, d) => `وافق ${n} على خطتك ليوم ${d}`,
    planRejected: (n, c, d) => `رفض ${n} عنصراً في خطتك ليوم ${d}`,
    planChanged: (n, c, d) => `عدّل ${n} خطتك ليوم ${d}`,
    clientsTransferredIn: (n, c) => `نقل ${n} ${c} عميل إليك`,
    clientsTransferredOut: (n, c, d, o) => `نقل ${n} ${c} من عملائك إلى ${o || 'غير مُسند'}`,
    tracking_gpsOff: (n) => `أوقف ${n} خدمة الموقع (GPS)`,
    tracking_locationDenied: (n) => `ألغى ${n} إذن الموقع للتطبيق`,
    tracking_notAlways: (n) => `سمح ${n} بالموقع أثناء استخدام التطبيق فقط – يتوقف التتبع في الخلفية`,
    tracking_battery: (n) => `فعّل ${n} تحسين البطارية لتطبيق WPC CRM – قد يتوقف التتبع`,
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

/** The same warning about one person is sent at most this often. */
const ALERT_COOLDOWN_MS = 30 * 60 * 1000;

/**
 * Warns the sales exec's KAM and the sales managers (in-app + push through
 * sendPush) when the exec turns off GPS, reduces the location permission or
 * turns on battery optimization during work hours.
 */
exports.trackingAlerts = onValueWritten({ ref: '/presence/{uid}', maxInstances: 5 }, async (event) => {
  const before = trackingIssues(event.data.before.val());
  const fresh = trackingIssues(event.data.after.val()).filter((i) => !before.includes(i));
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

/** Route points are kept this many days (user decision), visits are kept. */
const ROUTE_DAYS = 90;

/**
 * Every night deletes RTDB `location_history/{uid}/{yyyy-MM-dd}` days older
 * than ROUTE_DAYS (Saudi time). Day keys sort as dates, so one key-range
 * query per person finds the old days. People come from Firestore `users`
 * and RTDB `roles`, which also covers deleted users whose role is still there.
 */
exports.cleanRouteHistory = onSchedule(
  { schedule: '0 3 * * *', timeZone: 'Asia/Riyadh', maxInstances: 1 },
  async () => {
    const saudiNow = new Date(Date.now() + 3 * 3600 * 1000);
    saudiNow.setUTCDate(saudiNow.getUTCDate() - ROUTE_DAYS - 1);
    const lastOldDay = saudiNow.toISOString().slice(0, 10);

    const rtdb = admin.database();
    const [users, roles] = await Promise.all([
      admin.firestore().collection('users').select().get(),
      rtdb.ref('roles').get(),
    ]);
    const uids = new Set([...users.docs.map((d) => d.id), ...Object.keys(roles.val() || {})]);

    let removed = 0;
    for (const uid of uids) {
      const ref = rtdb.ref(`location_history/${uid}`);
      const old = await ref.orderByKey().endAt(lastOldDay).get();
      const updates = {};
      old.forEach((day) => { updates[day.key] = null; });
      const count = Object.keys(updates).length;
      if (count === 0) continue;
      await ref.update(updates);
      removed += count;
    }
    console.log(`cleanRouteHistory: removed ${removed} day(s) up to ${lastOldDay}`);
  },
);
