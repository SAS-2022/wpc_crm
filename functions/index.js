const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentCreated, onDocumentDeleted, onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onValueWritten } = require('firebase-functions/v2/database');
const admin = require('firebase-admin');
const { findMatches } = require('./duplicates');
const { coordsFromPlusCode } = require('./plusCode');
const { deriveDay, saudiTime } = require('./attendance');

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
    clientStatusRequested: (n, c, d, o, x) => `${n} asked to mark ${x.client} as ${x.status} – waiting for your approval`,
    clientStatusApproved: (n, c, d, o, x) => `${n} approved: ${x.client} is now ${x.status}`,
    clientStatusRejected: (n, c, d, o, x) => `${n} rejected marking ${x.client} as ${x.status}`,
    updateReminder: (n) => `${n} asks you to update WPC CRM to the latest version – tap to update`,
    registrationRequested: (n, c, d, o) => `${o} registered an account – waiting for your approval`,
    attendanceCheckedIn: (n, c, d, o, x) => `${x.self ? 'You are checked in' : `${n} checked in`}${x.site ? ` at ${x.site}` : ''} at ${x.time}${c > 0 ? ` – ${c} min late` : ''}`,
    attendanceLate: (n, c, d, o, x) => `You haven't checked in yet – your work day started at ${x.time}. Please be at work soon.`,
    status: { active: 'Active', closed: 'Closed', notWorking: 'Not working' },
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
    clientStatusRequested: (n, c, d, o, x) => `طلب ${n} تحويل ${x.client} إلى ${x.status} – بانتظار موافقتك`,
    clientStatusApproved: (n, c, d, o, x) => `وافق ${n}: ${x.client} أصبح ${x.status}`,
    clientStatusRejected: (n, c, d, o, x) => `رفض ${n} تحويل ${x.client} إلى ${x.status}`,
    updateReminder: (n) => `يطلب ${n} تحديث تطبيق WPC CRM إلى أحدث إصدار – اضغط للتحديث`,
    registrationRequested: (n, c, d, o) => `سجّل ${o} حساباً – بانتظار موافقتك`,
    attendanceCheckedIn: (n, c, d, o, x) => `${x.self ? 'تم تسجيل حضورك' : `سجّل ${n} حضوره`}${x.site ? ` في ${x.site}` : ''} الساعة ${x.time}${c > 0 ? ` – متأخر ${c} دقيقة` : ''}`,
    attendanceLate: (n, c, d, o, x) => `لم تسجّل حضورك بعد – بدأ يوم عملك الساعة ${x.time}. يرجى الحضور إلى العمل قريباً.`,
    status: { active: 'نشط', closed: 'مغلق', notWorking: 'لا يتعامل معنا' },
  },
};

function formatDay(date, lang) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date || '')) return date || '';
  return new Intl.DateTimeFormat(lang, { weekday: 'short', month: 'short', day: 'numeric', timeZone: 'UTC' })
    .format(new Date(`${date}T00:00:00Z`));
}

/** '08:15' → '8:15 AM' / '8:15 ص'. */
function formatClock(hhmm, lang) {
  if (!/^\d{2}:\d{2}$/.test(hhmm || '')) return hhmm || '';
  return new Intl.DateTimeFormat(lang, { hour: 'numeric', minute: '2-digit', timeZone: 'UTC' })
    .format(new Date(`2026-01-01T${hhmm}:00Z`));
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
  const other = ['clientsTransferredOut', 'leaveRequested', 'registrationRequested'].includes(n.type) && n.ownerId ? `users/${n.ownerId}` : null;
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
    const extra = {
      client: n.clientName || '', status: t.status[n.issue] || n.issue || '',
      site: n.siteName || '', time: formatClock(n.time, lang), self: n.toId === n.fromId,
    };
    const body = (t[key] || t.planChanged)(fromName, n.count || 0, formatDay(n.date, lang), otherUser?.get('name') || '', extra);
    const res = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: { title: t.title, body },
      data: {
        route: n.type === 'registrationRequested' ? `/users/${n.ownerId}`
          : !n.ref ? '/notifications'
          : n.type.startsWith('leave') ? `/leave/${n.ref}`
          : n.type.startsWith('clientStatus') ? `/clients/${n.ref}`
          : '/notifications',
        notificationId: event.params.id,
      },
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
  // Drivers are tracked too (2026-10-20): reported to the sales managers and GMs.
  if (!['sales_exec', 'kam', 'driver'].includes(role) || user.get('active') !== true) return;

  // Drivers: also the logistics managers (2026-10-20).
  const managerRoles = role === 'driver' ? ['sales_manager', 'gm', 'logistics_manager'] : ['sales_manager', 'gm'];
  const managers = await db.collection('users').where('role', 'in', managerRoles).where('active', '==', true).get();
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
    const gms = [...users].filter(([, u]) => u.role === 'gm' && u.active === true).map(([id]) => id);
    const logistics = [...users].filter(([, u]) => u.role === 'logistics_manager' && u.active === true).map(([id]) => id);
    const batch = db.batch();
    const marks = {};
    for (const { uid, since } of due) {
      const user = users.get(uid);
      marks[`${uid}/offlineSince`] = since;
      if (!['sales_exec', 'driver'].includes(user?.role) || user.active !== true) continue;
      const kam = user.role === 'sales_exec' ? users.get(user.kamId) : null;
      // Drivers: the sales managers and GMs (2026-10-20).
      const to = kam?.active === true ? [user.kamId] : user.role === 'driver' ? [...managers, ...gms, ...logistics] : managers;
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
    // KAM: their team; logistics manager: drivers.
    const allowed = (role === 'kam' && target.get('kamId') === req.auth.uid)
      || (role === 'logistics_manager' && target.get('role') === 'driver');
    if (!allowed) throw new HttpsError('permission-denied', 'Not your team');
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

// ---------------------------------------------------------------------------
// Self-registration and attendance (user request 2026-10-19).

/**
 * A new self-registered account (`approval: 'pending'`) is announced to every
 * active sales manager and GM, who approve it on the Users page. Written
 * here because the pending user may not create notifications themselves.
 */
exports.registrationRequested = onDocumentCreated('users/{uid}', async (event) => {
  const u = event.data?.data();
  if (!u || u.approval !== 'pending') return;
  const db = admin.firestore();
  const admins = await db.collection('users').where('role', 'in', ['gm', 'sales_manager']).get();
  const batch = db.batch();
  for (const a of admins.docs) {
    if (a.get('active') !== true) continue;
    batch.set(db.collection('notifications').doc(), {
      toId: a.id, fromId: event.params.uid, ownerId: event.params.uid, type: 'registrationRequested',
      date: '', count: 0, read: false, createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
});

const LEAVES_SITE_ROLES = ['sales_exec', 'kam', 'driver'];
const DERIVED = ['checkInAt', 'checkInSource', 'siteId', 'inside', 'lastExitAt', 'checkOutAt', 'checkOutType',
  'closed', 'workedMin', 'countedMin', 'overtimeMin', 'lateMin', 'afterHoursMin'];
const TIME_FIELDS = ['checkInAt', 'lastExitAt', 'checkOutAt'];

/** The person's own schedule (`users.workSchedule`, user form) or the company work hours. */
function scheduleOf(user, hours) {
  const v = user.workSchedule;
  if (v && Array.isArray(v.days) && typeof v.start === 'number' && typeof v.end === 'number' && v.end > v.start) {
    return { days: v.days.filter((d) => d >= 1 && d <= 7), start: v.start, end: v.end };
  }
  return hours;
}

/** Monday = 1 … Sunday = 7 of 'yyyy-MM-dd'. */
const weekdayOf = (date) => {
  const d = new Date(`${date}T00:00:00Z`).getUTCDay();
  return d === 0 ? 7 : d;
};

/** 'HH:mm' Saudi time of epoch ms. */
const saudiClock = (ms) => new Date(ms + 3 * 3600 * 1000).toISOString().slice(11, 16);

/** Check-ins older than this aren't announced (e.g. days recalculated after a deploy). */
const CHECK_IN_NOTICE_MS = 3 * 3600 * 1000;

/**
 * First check-in of the day: tells the employee and every active GM (user
 * decision 2026-10-20). Fixed ids, so a day is announced once even when two
 * events are processed at the same time.
 */
async function announceCheckIn(data, d, user, now) {
  const db = admin.firestore();
  const site = d.siteId ? (await db.doc(`work_sites/${d.siteId}`).get()).get('name') || '' : '';
  const gms = await db.collection('users').where('role', '==', 'gm').get();
  const to = new Set([data.uid, ...gms.docs.filter((g) => g.get('active') === true).map((g) => g.id)]);
  await Promise.all([...to].map((toId) => db.doc(`notifications/checkIn_${data.uid}_${data.date}_${toId}`).create({
    toId, fromId: data.uid, ownerId: data.uid, type: 'attendanceCheckedIn', date: data.date,
    count: d.lateMin || 0, siteName: site, time: saudiClock(d.checkInAt), read: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  }).catch((e) => { if (e.code !== 6) throw e; }))); // 6 = already exists
}

/** Works the day out from its events (see attendance.js) and saves the result when it changed. */
async function updateAttendance(ref, data, hours, now) {
  if (!data?.uid || !/^\d{4}-\d{2}-\d{2}$/.test(data.date || '')) return;
  const user = (await admin.firestore().doc(`users/${data.uid}`).get()).data() || {};
  const mine = scheduleOf(user, hours);
  const events = (data.events || []).map((e) => ({ ...e, at: e.at?.toMillis ? e.at.toMillis() : e.at }));
  const d = deriveDay(events, {
    startMs: mine.days.includes(weekdayOf(data.date)) ? saudiTime(data.date, mine.start) : null,
    endMs: saudiTime(data.date, mine.end),
    closeAllMs: saudiTime(data.date, 23 * 60 + 55),
    now,
    leavesSite: LEAVES_SITE_ROLES.includes(user.role),
    overtimeAllowed: user.overtimeAllowed === true,
  });
  const update = {};
  for (const k of DERIVED) {
    const v = TIME_FIELDS.includes(k) && d[k] !== null ? admin.firestore.Timestamp.fromMillis(d[k]) : d[k];
    const old = data[k];
    const same = old?.toMillis && v?.toMillis ? old.toMillis() === v.toMillis() : old === v || (old === undefined && v === null);
    if (!same) update[k] = v;
  }
  if (d.checkInAt !== null && data.checkInNotified !== true) {
    update.checkInNotified = true;
    if (now - d.checkInAt < CHECK_IN_NOTICE_MS) await announceCheckIn(data, d, user, now);
  }
  if (Object.keys(update).length > 0) await ref.update(update);
}

/** Recalculates a day whenever a phone adds an event. */
exports.attendanceUpdated = onDocumentWritten('attendance/{id}', async (event) => {
  const after = event.data?.after;
  if (!after?.exists) return;
  const hours = workHours((await admin.database().ref('settings/workHours').get()).val());
  await updateAttendance(after.ref, after.data(), hours, Date.now());
});

/** Every 10 minutes: closes open days whose time has come (end of the work day, late evening). */
exports.closeAttendance = onSchedule(
  { schedule: 'every 10 minutes', timeZone: 'Asia/Riyadh', maxInstances: 1 },
  async () => {
    const open = await admin.firestore().collection('attendance').where('closed', '==', false).get();
    if (open.empty) return;
    const hours = workHours((await admin.database().ref('settings/workHours').get()).val());
    const now = Date.now();
    for (const d of open.docs) await updateAttendance(d.ref, d.data(), hours, now);
  },
);

/** Reminder this long after the start of the work day (user request 2026-10-20). */
const LATE_REMINDER_MIN = 15;

/** Needs attendance (user form switch; not set = anyone with a work site) and has a site. */
const checksAttendance = (u) => u.active === true && u.attendanceRequired !== false
  && Array.isArray(u.workSiteIds) && u.workSiteIds.length > 0;

/**
 * Every 5 minutes: anyone who needs attendance and isn't checked in 15
 * minutes after the start of their work day gets one reminder that day
 * (employee only, user decision 2026-10-20). Skips their days off, public
 * holidays (`settings/holidays`) and approved leave. Sent days in RTDB
 * `attendance_reminders/{uid}` = 'yyyy-MM-dd' (admin only).
 */
exports.attendanceReminders = onSchedule(
  { schedule: 'every 5 minutes', timeZone: 'Asia/Riyadh', maxInstances: 1 },
  async () => {
    const now = Date.now();
    const today = saudiDay(now);
    const saudi = new Date(now + 3 * 3600 * 1000);
    const minute = saudi.getUTCHours() * 60 + saudi.getUTCMinutes();
    const weekday = weekdayOf(today);
    const db = admin.firestore();
    const rtdb = admin.database();

    const holidays = (await db.doc('settings/holidays').get()).get('dates') || [];
    if (holidays.includes(today)) return;
    const hours = workHours((await rtdb.ref('settings/workHours').get()).val());
    const users = (await db.collection('users').where('active', '==', true).get()).docs
      .filter((d) => checksAttendance(d.data()))
      .filter((d) => {
        const h = scheduleOf(d.data(), hours);
        return h.days.includes(weekday) && minute >= h.start + LATE_REMINDER_MIN && minute < h.end;
      });
    if (users.length === 0) return;

    const [sentSnap, daySnap, leaveSnap] = await Promise.all([
      rtdb.ref('attendance_reminders').get(),
      db.collection('attendance').where('date', '==', today).get(),
      db.collection('leave_requests').where('to', '>=', today).get(),
    ]);
    const sent = sentSnap.val() || {};
    const checkedIn = new Set(daySnap.docs
      .filter((d) => d.get('checkInAt') || (d.get('events') || []).some((e) => e.type === 'in' || e.type === 'checkIn'))
      .map((d) => d.get('uid')));
    const onLeave = new Set(leaveSnap.docs
      .filter((d) => d.get('status') === 'approved' && d.get('isLeave') !== false && d.get('from') <= today)
      .map((d) => d.get('uid')));

    const batch = db.batch();
    const marks = {};
    for (const u of users) {
      if (sent[u.id] === today || checkedIn.has(u.id) || onLeave.has(u.id)) continue;
      const h = scheduleOf(u.data(), hours);
      marks[u.id] = today;
      batch.set(db.collection('notifications').doc(), {
        toId: u.id, fromId: u.id, ownerId: u.id, type: 'attendanceLate', date: today, count: 0,
        time: `${String(Math.floor(h.start / 60)).padStart(2, '0')}:${String(h.start % 60).padStart(2, '0')}`,
        read: false, createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    if (Object.keys(marks).length === 0) return;
    await batch.commit();
    await rtdb.ref('attendance_reminders').update(marks);
  },
);

// Day timelines (user request 2026-10-20): each salesperson's working day
// split into client / driving / office / lunch / stopped / no data from their
// GPS points, saved in Firestore `day_timelines/{uid}_{yyyy-MM-dd}` for the
// Reports routing section and Route history (see timeline.js).
const { buildDayTimeline } = require('./timeline');

/** Builds and saves one person's day; null when there's nothing to build. */
async function saveTimeline(uid, day, hours, sites) {
  if (!hours.days.includes(weekdayOf(day))) return null;
  const db = admin.firestore();
  const [history, visitSnap] = await Promise.all([
    admin.database().ref(`location_history/${uid}/${day}`).get(),
    db.collection('visits').where('salesExecId', '==', uid).where('month', '==', day.slice(0, 7)).get(),
  ]);
  const points = mainTrack(Object.values(history.val() || {})
    .filter((p) => typeof p?.lat === 'number' && typeof p?.lng === 'number' && typeof p?.t === 'number')
    .filter((p) => (p.accuracy || 0) <= ROUTE_MAX_ACCURACY)
    .sort((a, b) => a.t - b.t));
  const visits = visitSnap.docs
    .map((d) => ({ id: d.id, ...d.data() }))
    .filter((v) => v.type !== 'call' && v.checkedInAt?.toMillis && typeof v.checkInLat === 'number' && typeof v.checkInLng === 'number')
    .map((v) => ({ id: v.id, clientId: v.clientId, at: v.checkedInAt.toMillis(), lat: v.checkInLat, lng: v.checkInLng }))
    .filter((v) => saudiDay(v.at) === day)
    .sort((a, b) => a.at - b.at);
  if (points.length === 0 && visits.length === 0) return null;
  // Work hours, stretched to cover visits made a little before / after them.
  let startMs = saudiTime(day, hours.start);
  let endMs = saudiTime(day, hours.end);
  if (visits.length) {
    startMs = Math.min(startMs, visits[0].at - 30 * 60000);
    endMs = Math.max(endMs, visits[visits.length - 1].at + 60 * 60000);
  }
  const now = Date.now();
  endMs = Math.min(endMs, Math.max(startMs, now)); // today: up to now
  const t = buildDayTimeline({ points, visits, sites, startMs, endMs });
  const doc = { uid, day, month: day.slice(0, 7), ...t, final: now > endMs + 3600000, builtAt: now };
  await db.doc(`day_timelines/${uid}_${day}`).set(doc);
  return doc;
}

async function timelineContext() {
  const [hoursSnap, siteSnap] = await Promise.all([
    admin.database().ref('settings/workHours').get(),
    admin.firestore().collection('work_sites').get(),
  ]);
  const sites = siteSnap.docs
    .map((d) => ({ id: d.id, ...d.data() }))
    .filter((s) => s.active !== false && typeof s.lat === 'number' && typeof s.lng === 'number');
  return { hours: workHours(hoursSnap.val()), sites };
}

/** Days kept for the benchmarks when back-filling. */
const TIMELINE_BACKFILL_DAYS = 30;

/** Nightly: yesterday's timelines, plus any missing day of the last 30 (first run back-fills). */
exports.buildTimelines = onSchedule(
  { schedule: '30 0 * * *', timeZone: 'Asia/Riyadh', timeoutSeconds: 540, memory: '512MiB', maxInstances: 1 },
  async () => {
    const db = admin.firestore();
    const { hours, sites } = await timelineContext();
    const people = (await db.collection('users').where('role', 'in', ['sales_exec', 'kam']).get()).docs
      .filter((d) => d.get('active') === true).map((d) => d.id);
    const today = saudiDay(Date.now());
    const days = [];
    for (let k = 1; k <= TIMELINE_BACKFILL_DAYS; k++) {
      days.push(saudiDay(Date.parse(`${today}T12:00:00Z`) - k * 86400000));
    }
    const refs = people.flatMap((uid) => days.map((day) => db.doc(`day_timelines/${uid}_${day}`)));
    const existing = new Map((await db.getAll(...refs)).map((s) => [s.id, s]));
    let built = 0;
    for (const uid of people) {
      for (const day of days) {
        const old = existing.get(`${uid}_${day}`);
        if (old?.exists && old.get('final') === true) continue;
        await saveTimeline(uid, day, hours, sites);
        if (++built >= 400) return; // the rest tomorrow
      }
    }
  },
);

/** Route history: (re)builds one day now (today's is rebuilt as the day goes on). */
exports.buildTimeline = onCall({ timeoutSeconds: 60, maxInstances: 3 }, async (req) => {
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
  const { hours, sites } = await timelineContext();
  const doc = await saveTimeline(uid, day, hours, sites);
  return { built: doc !== null };
});
