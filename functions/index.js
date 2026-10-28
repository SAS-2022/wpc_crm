const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentCreated, onDocumentDeleted, onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onValueWritten } = require('firebase-functions/v2/database');
const admin = require('firebase-admin');
const { findMatches } = require('./duplicates');
const { coordsFromPlusCode } = require('./plusCode');
const {
  deriveDay, correctedEvents, siteCheckDue, siteArrival, atSiteReminderDue, overtimeAskDue, driveDecide, driveEnd, HOME_RADIUS_M, DRIVE_HOME_GRACE_MIN, saudiTime, overtimeCap,
  LATE_GRACE_MIN, AWAY_GRACE_MIN,
} = require('./attendance');

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
    tracking_noAnswer: (n, c, d, o, x) => `${n}'s phone has sent nothing since ${x.time} (${c} min) and didn't answer a wake-up check – the app may be closed, or the phone off or without signal`,
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
    attendanceAtSite: (n, c, d, o, x) => `You're at ${x.site || 'your work site'} since ${x.time} but not checked in – open the app and check in.`,
    overtimeStarted: (n, c, d, o, x) => (x.driving
      ? (x.self
        ? `Your shift ended at ${x.time} while you're on the road – overtime started. It ends when you arrive home or at the work site.`
        : `${n} is still driving after the end of the shift (${x.time}) – overtime started, until they arrive home or at the work site`)
      : `${n} started overtime${x.site ? ` at ${x.site}` : ''} (counted from ${x.time}) – approve it later on the Attendance page`),
    overtimeAsk: (n, c, d, o, x) => `${c > 0 ? 'Reminder: ' : ''}Your shift ended at ${x.time} and you're still at ${x.site || 'the work site'}. Working overtime? Open the app and tap "Start overtime" – it counts from ${x.time}.`,
    absenceReported: (n, c, d, o, x) => `${o} won't be at work on ${d} – ${x.reason}${x.note ? `: ${x.note}` : ''}`,
    status: { active: 'Active', closed: 'Closed', notWorking: 'Not working' },
    absence: { sick: 'Sick', tired: 'Tired', cantCome: "Can't come" },
    absenceAccepted: (n, c, d, o, x) => `${n} accepted your absence on ${d} as ${x.leave}`,
    absenceRejected: (n, c, d) => `${n} didn't accept your absence on ${d} – it counts as an absence day`,
    teamOnLeave: (n, c, d, o, x) => `${o} is on leave: ${x.range}`,
    leave: { sick: 'sick leave', annual: 'annual leave' },
    earlyCheckoutRequested: (n, c, d, o, x) => `${o} asks to leave early today${x.note ? ` – ${x.note}` : ''}`,
    earlyCheckoutApproved: (n) => `${n} approved your early check-out – you can check out now`,
    earlyCheckoutRejected: (n, c, d, o, x) => `${n} didn't approve your early check-out${x.note ? ` – ${x.note}` : ''}`,
    vehicleRenewalDue: (n, c, d, o, x) => (c > 0
      ? `${x.vehicle}: ${x.renewal} expires in ${c} days (${d})`
      : `${x.vehicle}: ${x.renewal} has expired (${d})`),
    renewal: { registration: 'registration (Istimara)', insurance: 'insurance', inspection: 'periodic inspection (Fahas)', operatingCard: 'operating card (work permit)' },
    vehicleOilDue: (n, c, d, o, x) => (c > 0
      ? `${x.vehicle}: oil change due in ${c} km (at ${x.km} km)`
      : `${x.vehicle}: oil change is due (was due at ${x.km} km)`),
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
    tracking_noAnswer: (n, c, d, o, x) => `لم يرسل هاتف ${n} شيئاً منذ الساعة ${x.time} (${c} دقيقة) ولم يستجب لفحص التنبيه – قد يكون التطبيق مغلقاً أو الهاتف مطفأً أو بلا شبكة`,
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
    attendanceAtSite: (n, c, d, o, x) => `أنت في ${x.site || 'موقع العمل'} منذ الساعة ${x.time} ولم تسجّل حضورك – افتح التطبيق وسجّل الحضور.`,
    overtimeStarted: (n, c, d, o, x) => (x.driving
      ? (x.self
        ? `انتهى دوامك الساعة ${x.time} وأنت في الطريق – بدأ العمل الإضافي. ينتهي عند وصولك إلى المنزل أو موقع العمل.`
        : `${n} ما زال يقود بعد نهاية الدوام (${x.time}) – بدأ العمل الإضافي حتى يصل إلى المنزل أو موقع العمل`)
      : `بدأ ${n} العمل الإضافي${x.site ? ` في ${x.site}` : ''} (يُحتسب من ${x.time}) – اعتمده لاحقاً من صفحة الحضور`),
    overtimeAsk: (n, c, d, o, x) => `${c > 0 ? 'تذكير: ' : ''}انتهى دوامك الساعة ${x.time} وما زلت في ${x.site || 'موقع العمل'}. هل ستعمل وقتاً إضافياً؟ افتح التطبيق واضغط «بدء العمل الإضافي» – يُحتسب من ${x.time}.`,
    absenceReported: (n, c, d, o, x) => `${o} لن يحضر إلى العمل يوم ${d} – ${x.reason}${x.note ? `: ${x.note}` : ''}`,
    status: { active: 'نشط', closed: 'مغلق', notWorking: 'لا يتعامل معنا' },
    absence: { sick: 'مريض', tired: 'متعب', cantCome: 'لا أستطيع الحضور' },
    absenceAccepted: (n, c, d, o, x) => `قبل ${n} غيابك يوم ${d} ك${x.leave}`,
    absenceRejected: (n, c, d) => `لم يقبل ${n} غيابك يوم ${d} – يُحتسب يوم غياب`,
    teamOnLeave: (n, c, d, o, x) => `${o} في إجازة: ${x.range}`,
    leave: { sick: 'إجازة مرضية', annual: 'إجازة سنوية' },
    earlyCheckoutRequested: (n, c, d, o, x) => `يطلب ${o} الانصراف مبكراً اليوم${x.note ? ` – ${x.note}` : ''}`,
    earlyCheckoutApproved: (n) => `وافق ${n} على انصرافك المبكر – يمكنك تسجيل الانصراف الآن`,
    earlyCheckoutRejected: (n, c, d, o, x) => `لم يوافق ${n} على انصرافك المبكر${x.note ? ` – ${x.note}` : ''}`,
    vehicleRenewalDue: (n, c, d, o, x) => (c > 0
      ? `${x.vehicle}: ينتهي ${x.renewal} بعد ${c} يوماً (${d})`
      : `${x.vehicle}: انتهى ${x.renewal} (${d})`),
    renewal: { registration: 'تسجيل المركبة (الاستمارة)', insurance: 'التأمين', inspection: 'الفحص الدوري', operatingCard: 'بطاقة التشغيل' },
    vehicleOilDue: (n, c, d, o, x) => (c > 0
      ? `${x.vehicle}: تغيير الزيت بعد ${c} كم (عند ${x.km} كم)`
      : `${x.vehicle}: حان موعد تغيير الزيت (كان عند ${x.km} كم)`),
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
/**
 * Overtime alerts (user request 2026-10-25): their own sound and a
 * high-importance Android channel 'overtime' (created by the app,
 * MainActivity.kt; sound res/raw/overtime_alert), shown on the lock screen;
 * iOS plays Library/Sounds/overtime_alert.caf (copied there by the app).
 */
const OVERTIME_PUSH = {
  android: {
    priority: 'high',
    notification: {
      channelId: 'overtime', sound: 'overtime_alert', visibility: 'public',
      priority: 'max', defaultVibrateTimings: true,
    },
  },
  apns: { headers: { 'apns-priority': '10' }, payload: { aps: { sound: 'overtime_alert.caf' } } },
};

exports.sendPush = onDocumentCreated({ document: 'notifications/{id}', maxInstances: 5 }, async (event) => {
  const n = event.data?.data();
  if (!n?.toId) return;
  const db = admin.firestore();
  // For client transfers ownerId is the other sales executive (empty = unassigned);
  // for leave requests it is the person who asked.
  const other = ['clientsTransferredOut', 'leaveRequested', 'registrationRequested', 'absenceReported', 'teamOnLeave', 'earlyCheckoutRequested'].includes(n.type) && n.ownerId ? `users/${n.ownerId}` : null;
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

  // The person's own overtime alerts (2026-10-25): their own sound and channel.
  const overtimeAlert = n.type === 'overtimeAsk' || n.type === 'attendanceAtSite' || (n.type === 'overtimeStarted' && n.toId === n.ownerId);
  const stale = [];
  await Promise.all(Object.entries(byLang).map(async ([lang, tokens]) => {
    const t = TEXTS[lang];
    const key = n.type === 'trackingIssue' ? `tracking_${n.issue}` : n.type;
    const extra = {
      client: n.clientName || '', status: t.status[n.issue] || n.issue || '',
      site: n.siteName || '', time: formatClock(n.time, lang), self: n.toId === n.fromId, driving: n.issue === 'driving',
      reason: t.absence[n.issue] || '', note: n.note || '', leave: t.leave[n.issue] || '',
      vehicle: n.vehicleName || '', renewal: t.renewal[n.issue] || '', km: String(n.note || ''),
      range: n.note && n.note !== n.date ? `${formatDay(n.date, lang)} – ${formatDay(n.note, lang)}` : formatDay(n.date, lang),
    };
    const body = (t[key] || t.planChanged)(fromName, n.count || 0, formatDay(n.date, lang), otherUser?.get('name') || '', extra);
    const res = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: { title: t.title, body },
      data: {
        route: n.type === 'registrationRequested' ? `/users/${n.ownerId}`
          : n.type.startsWith('absence') && n.ref ? `/absence/${n.ref}`
          : n.type === 'teamOnLeave' && n.ref ? `/leave/${n.ref}`
          : n.type.startsWith('earlyCheckout') ? '/'
          : n.type === 'overtimeStarted' ? (n.toId === n.ownerId ? '/' : '/attendance')
          : n.type === 'overtimeAsk' || n.type === 'attendanceAtSite' ? '/'
          : !n.ref ? '/notifications'
          : n.type.startsWith('leave') ? `/leave/${n.ref}`
          : n.type.startsWith('clientStatus') ? `/clients/${n.ref}`
          : (n.type === 'vehicleRenewalDue' || n.type === 'vehicleOilDue') ? `/vehicles/${n.ref}`
          : '/notifications',
        notificationId: event.params.id,
      },
      ...(overtimeAlert ? OVERTIME_PUSH : { android: { priority: 'high' }, apns: { payload: { aps: { sound: 'default' } } } }),
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
  const [companySnap, scheduleSnap] = await Promise.all([
    admin.database().ref('settings/workHours').get(),
    admin.database().ref(`settings/trackingSchedules/${event.params.uid}`).get(),
  ]);
  const hours = trackingHours(workHours(companySnap.val()), scheduleSnap.val());
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

/**
 * Limits edited in App settings (RTDB `settings/app`, app_settings.dart):
 * [key] when it's a number within [min, max], else [def].
 */
async function appSetting(key, def, min, max) {
  const v = (await admin.database().ref(`settings/app/${key}`).get()).val();
  return typeof v === 'number' && v >= min && v <= max ? Math.floor(v) : def;
}

/**
 * Hours a person's tracking log and alerts follow: their own schedule (App
 * settings → Tracking schedules, {mode: 'own', days, start, end}), else the
 * company work hours — also for 'allDay', as for drivers. Same as
 * tracking_schedule.dart.
 */
function trackingHours(company, schedule) {
  const own = schedule?.mode === 'own' && Array.isArray(schedule.days) && schedule.days.length > 0
    && typeof schedule.start === 'number' && typeof schedule.end === 'number' && schedule.end > schedule.start;
  return own ? workHours(schedule) : company;
}

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

const { wakeStep, REPING_MS } = require('./wakePing');

/**
 * Silent push to a person's phones (no title or text: nothing is shown):
 * "wake" by default, or a site check ({type: 'siteCheck'}, attendance).
 */
async function sendWakePing(uid, data = { type: 'wake' }) {
  const devices = await admin.firestore().collection(`users/${uid}/devices`).get();
  const tokens = devices.docs.filter((d) => ['android', 'iOS', 'ios'].includes(d.get('platform'))).map((d) => d.id);
  if (tokens.length === 0) return;
  await admin.messaging().sendEachForMulticast({
    tokens,
    data,
    // Kept until the next ping (2026-10-26, was 10 min): a phone without
    // signal gets it as soon as it's back online.
    android: { priority: 'high', ttl: REPING_MS },
    apns: {
      headers: { 'apns-push-type': 'background', 'apns-priority': '5', 'apns-expiration': String(Math.floor((Date.now() + REPING_MS) / 1000)) },
      payload: { aps: { 'content-available': 1 } },
    },
  });
}

/**
 * Every 5 minutes (user request 2026-10-24, replaces the presence-based
 * offline alert): every tracked person whose phone should be sharing but has
 * sent nothing for 10 minutes (no position, heartbeat or wake answer) gets a
 * silent wake push; the app answers (`presence.wokenAt`), restarts tracking
 * if Android stopped it and sends a position. No answer and quiet for the
 * App setting `offlineAlertMin` (30) → one `trackingIssue` / `noAnswer`
 * notification per quiet spell to their managers (sales exec: KAM, else the
 * sales managers; KAM: sales managers; driver: sales managers, GMs, logistics
 * managers and their warehouse supervisor). Logged and notified only within
 * the person's hours (tracking hours, or their own attendance schedule — a
 * driver working Fridays); pings go out whenever the phone should share
 * (drivers / "all day": always). Logic in wakePing.js.
 */
exports.offlineAlerts = onSchedule(
  { schedule: 'every 5 minutes', timeZone: 'Asia/Riyadh', maxInstances: 1 },
  async () => {
    const rtdb = admin.database();
    const db = admin.firestore();
    const now = Date.now();
    const [hoursSnap, schedulesSnap, presenceSnap, liveSnap, deviceSnap, alertsSnap, usersSnap, alertMin] = await Promise.all([
      rtdb.ref('settings/workHours').get(),
      rtdb.ref('settings/trackingSchedules').get(),
      rtdb.ref('presence').get(),
      rtdb.ref('live_locations').get(),
      rtdb.ref('tracking_device').get(),
      rtdb.ref('tracking_alerts').get(),
      db.collection('users').get(),
      appSetting('offlineAlertMin', OFFLINE_ALERT_MS / 60000, 10, 240),
    ]);
    const company = workHours(hoursSnap.val());
    const schedules = schedulesSnap.val() || {};
    const presence = presenceSnap.val() || {};
    const live = liveSnap.val() || {};
    const phones = deviceSnap.val() || {};
    const alerts = alertsSnap.val() || {};
    const users = usersSnap.docs.map((d) => ({ id: d.id, ...d.data() }));
    const active = (role) => users.filter((u) => u.role === role && u.active === true).map((u) => u.id);

    const updates = {};
    const batch = db.batch();
    let notes = 0;
    const pings = [];
    for (const user of users) {
      const uid = user.id;
      if (user.active !== true || !['sales_exec', 'kam', 'driver'].includes(user.role) || !phones[uid]) continue;
      const schedule = schedules[uid];
      const hours = trackingHours(company, schedule);
      const started = workStartToday(hours, now);
      const allDay = schedule?.mode === 'allDay' || (schedule?.mode !== 'own' && user.role === 'driver');
      const on = allDay || started !== null;
      const own = user.workSchedule ? scheduleOf(user, company) : null;
      const ownStart = own === null ? null : workStartToday(own, now);
      const inHours = started !== null || ownStart !== null;
      const p = presence[uid] || {};
      const signs = [live[uid]?.updatedAt, p.lastSeen, p.wokenAt].filter((v) => typeof v === 'number');
      const state = alerts[uid]?.wake || null;
      const r = wakeStep({
        now, on, inHours,
        lastSign: signs.length ? Math.max(...signs) : null,
        windowStart: allDay ? null : started,
        hoursStart: inHours ? Math.min(...[started, ownStart].filter((v) => v !== null)) : null,
        state,
        alertMs: alertMin * 60000,
      });
      if (JSON.stringify(r.state) !== JSON.stringify(state)) updates[`tracking_alerts/${uid}/wake`] = r.state;
      for (const e of r.log) updates[`tracking_events/${uid}/${saudiDay(e.t)}/${rtdb.ref().push().key}`] = e;
      if (r.ping) pings.push(uid);
      if (r.notify) {
        const kam = user.role === 'sales_exec' ? users.find((u) => u.id === user.kamId && u.active === true) : null;
        const to = new Set(kam ? [kam.id]
          : user.role === 'driver'
            ? [...active('sales_manager'), ...active('gm'), ...active('logistics_manager'),
              ...users.filter((u) => u.id === user.supervisorId && u.active === true).map((u) => u.id)]
            : active('sales_manager'));
        to.delete(uid);
        for (const toId of to) {
          notes++;
          batch.set(db.collection('notifications').doc(), {
            toId, type: 'trackingIssue', issue: 'noAnswer', fromId: uid, ownerId: uid,
            date: saudiDay(now), count: r.notify.minutes, time: saudiClock(r.notify.since),
            read: false, createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }
    }
    await Promise.all(pings.map((uid) => sendWakePing(uid).catch((e) => console.warn('wake ping', uid, e.message))));
    if (Object.keys(updates).length > 0) await rtdb.ref().update(updates);
    if (notes > 0) await batch.commit();
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
// Loops the car never drove are refused, single rough spikes ignored (2026-10-26).
const { spikeTimes, legFixes, legValue, recheckLeg } = require('./routeCheck');

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

/** A day's usable fixes: good accuracy, one phone's track, sorted. */
function routePath(raw) {
  return mainTrack(Object.values(raw || {})
    .filter((p) => typeof p?.lat === 'number' && typeof p?.lng === 'number' && typeof p?.t === 'number')
    .filter((p) => (p.accuracy || 0) <= ROUTE_MAX_ACCURACY)
    .sort((a, b) => a.t - b.t));
}

/** Fixes of [path] worth routing between, per run of continuous tracking, stops collapsed. */
function routeLegs(path) {
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
 * Whether a caller (not SM / GM) may see this person's route: a KAM their
 * team, the logistics manager every driver, a warehouse supervisor their
 * own drivers (`supervisorId`, 2026-10-23).
 */
function followsPerson(role, callerId, target) {
  return (role === 'kam' && target.get('kamId') === callerId)
    || (role === 'logistics_manager' && target.get('role') === 'driver')
    || (role === 'warehouse_supervisor' && target.get('role') === 'driver' && target.get('supervisorId') === callerId);
}

/**
 * Snaps one person's day of `location_history` to roads with the Routes API
 * and saves it in RTDB `route_snapped/{uid}/{day}` {n: history points handled,
 * legs: {"<fromT>_<toT>": {p: encoded polyline, m: meters} | {s: true, m}}}.
 * Legs already saved are not asked again, so each stretch is paid for once.
 * A road route much longer than the path through the phone's fixes, or
 * slower than the time between them allows, is replaced by the fixes'
 * path (s: true, m = distance along the fixes; routeCheck.js), and saved
 * legs are re-checked the same way. Callable by supervisors (KAM for
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
    if (!followsPerson(role, req.auth.uid, target)) throw new HttpsError('permission-denied', 'Not your team');
  }

  const rtdb = admin.database();
  const outRef = rtdb.ref(`route_snapped/${uid}/${day}`);
  const [history, saved] = await Promise.all([rtdb.ref(`location_history/${uid}/${day}`).get(), outRef.child('legs').get()]);
  const raw = history.val() || {};
  const done = saved.val() || {};
  const key = ([a, b]) => `${a.t}_${b.t}`;
  const path = routePath(raw);
  const spikes = spikeTimes(path);
  const legs = routeLegs(path);
  const missing = legs.filter((leg) => !done[key(leg)]).slice(0, ROUTE_MAX_LEGS);

  // Legs saved before are checked again with today's rules (no API call).
  const updates = {};
  for (const leg of legs) {
    const stored = done[key(leg)];
    const next = stored && recheckLeg(stored, legFixes(path, spikes, leg[0], leg[1]));
    if (next) updates[`legs/${key(leg)}`] = next;
  }

  // Consecutive missing legs (sharing a fix) go into one request.
  const chains = [];
  for (const leg of missing) {
    const chain = chains[chains.length - 1];
    if (chain && chain.length < ROUTE_LEGS_PER_CALL && chain[chain.length - 1][1] === leg[0]) chain.push(leg);
    else chains.push([leg]);
  }

  if (chains.length) {
    const { access_token: token } = await admin.credential.applicationDefault().getAccessToken();
    await Promise.all(chains.map(async (chain) => {
      const legs = await computeRoute([chain[0][0], ...chain.map((l) => l[1])], token);
      chain.forEach(([a, b], i) => {
        const r = legs?.[i];
        const route = r?.polyline?.encodedPolyline
          ? { p: r.polyline.encodedPolyline, m: r.distanceMeters ?? 0, seconds: parseInt(r.duration || '0', 10) }
          : null;
        updates[`legs/${a.t}_${b.t}`] = legValue(route, legFixes(path, spikes, a, b));
      });
    }));
  }
  updates.n = Object.keys(raw).length;
  await outRef.update(updates);
  return { snapped: Object.keys(updates).length - 1 };
});

// For tests and one-off scripts.
exports._mainTrack = mainTrack;
exports._routePath = routePath;
exports._routeLegs = routeLegs;

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
  'closed', 'workedMin', 'countedMin', 'overtimeMin', 'lateMin', 'afterHoursMin', 'awayMin', 'lastSeenAt',
  'overtimeOn', 'overtimeConfirmedAt', 'overtimeDeclined', 'overtimeEndUnknown', 'overtimeStatus', 'checkInEventAt'];
const TIME_FIELDS = ['checkInAt', 'lastExitAt', 'checkOutAt', 'lastSeenAt', 'overtimeConfirmedAt', 'checkInEventAt'];

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

/**
 * Last GPS fix at the site on [date] (location_history; tracked people only),
 * for a day with no exit seen (2026-10-24). Null without one.
 */
async function lastSeenAtSite(uid, date, siteId) {
  if (!siteId) return null;
  const [history, site] = await Promise.all([
    admin.database().ref(`location_history/${uid}/${date}`).get(),
    admin.firestore().doc(`work_sites/${siteId}`).get(),
  ]);
  const lat = site.get('lat'), lng = site.get('lng');
  if (typeof lat !== 'number' || typeof lng !== 'number') return null;
  const radius = (site.get('radius') || 100) + 50;
  let last = null;
  for (const p of Object.values(history.val() || {})) {
    if (typeof p?.t !== 'number' || typeof p.lat !== 'number' || (p.accuracy || 0) > ROUTE_MAX_ACCURACY) continue;
    if (metersBetween(p, { lat, lng }) <= radius && (last === null || p.t > last)) last = p.t;
  }
  return last;
}

/** A site's {lat, lng, radius}, or null. */
async function siteOf(siteId) {
  if (!siteId) return null;
  const site = await admin.firestore().doc(`work_sites/${siteId}`).get();
  const lat = site.get('lat'), lng = site.get('lng');
  return typeof lat === 'number' && typeof lng === 'number' ? { lat, lng, radius: site.get('radius') || 100 } : null;
}

/**
 * GPS arrival (2026-10-28) of the stay the day's first check-in event
 * falls in, from location_history (tracked people; others have none).
 * Worked out once per first event: `arrivalFor` = that event's time,
 * `arrivedAt` = the arrival (null = none earlier). Returns {arrivedAt, update}.
 */
async function gpsArrival(data, events) {
  const ms = (v) => (v?.toMillis ? v.toMillis() : v);
  const first = events.filter((e) => ['in', 'checkIn', 'hrIn'].includes(e.type) && typeof e.at === 'number')
    .sort((a, b) => a.at - b.at)[0];
  if (!first || first.type === 'hrIn') return { arrivedAt: null, update: {} };
  if (ms(data.arrivalFor) === first.at) return { arrivedAt: ms(data.arrivedAt) ?? null, update: {} };
  const [history, site] = await Promise.all([
    admin.database().ref(`location_history/${data.uid}/${data.date}`).get(),
    siteOf(first.siteId),
  ]);
  const found = site ? siteArrival(Object.values(history.val() || {}), site, first.at) : null;
  const arrivedAt = found !== null && found < first.at ? found : null;
  const ts = admin.firestore.Timestamp.fromMillis;
  return { arrivedAt, update: { arrivalFor: ts(first.at), arrivedAt: arrivedAt === null ? null : ts(arrivedAt) } };
}

/**
 * Overtime started (2026-10-25): site staff confirmed it (issue 'site') →
 * their direct manager(s), who approve it later on the Attendance page; a
 * driver still on the road at end + 10 min (issue 'driving') → the driver
 * too (overtime sound). Once a day (fixed ids).
 */
async function announceOvertime(data, siteId, user, endMs, issue) {
  const db = admin.firestore();
  const users = (await db.collection('users').where('active', '==', true).get()).docs
    .map((x) => ({ id: x.id, ...x.data() }));
  const site = siteId ? (await db.doc(`work_sites/${siteId}`).get()).get('name') || '' : '';
  const to = new Set([...(issue === 'driving' ? [data.uid] : []), ...directManagers(user, data.uid, users)]);
  await Promise.all([...to].map((toId) => db.doc(`notifications/overtime_${data.uid}_${data.date}_${toId}`).create({
    toId, fromId: data.uid, ownerId: data.uid, type: 'overtimeStarted', issue, date: data.date,
    siteName: site, time: saudiClock(endMs), count: 0, read: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  }).catch((e) => { if (e.code !== 6) throw e; }))); // 6 = already exists
}

/** "Start overtime?" to the person (2026-10-25; count 1 = the reminder). */
async function askOvertime(data, siteId, endMs, remind) {
  const db = admin.firestore();
  const site = siteId ? (await db.doc(`work_sites/${siteId}`).get()).get('name') || '' : '';
  await db.doc(`notifications/${remind ? 'otAsk2' : 'otAsk'}_${data.uid}_${data.date}`).create({
    toId: data.uid, fromId: data.uid, ownerId: data.uid, type: 'overtimeAsk', date: data.date,
    siteName: site, time: saudiClock(endMs), count: remind ? 1 : 0, read: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  }).catch((e) => { if (e.code !== 6) throw e; });
}

/** Shift-end notices only this soon after the end (not for days recalculated later). */
const OVERTIME_NOTICE_MS = 2 * 3600 * 1000;

/** Works the day out from its events (see attendance.js) and saves the result when it changed. */
async function updateAttendance(ref, data, hours, now, { graceMin, awayGraceMin }) {
  if (!data?.uid || !/^\d{4}-\d{2}-\d{2}$/.test(data.date || '')) return;
  const user = (await admin.firestore().doc(`users/${data.uid}`).get()).data() || {};
  const mine = scheduleOf(user, hours);
  const ms = (v) => (v?.toMillis ? v.toMillis() : v);
  const c = data.correction;
  const events = correctedEvents(
    (data.events || []).map((e) => ({ ...e, at: ms(e.at) })),
    c ? { checkInAt: ms(c.checkInAt), checkOutAt: ms(c.checkOutAt), siteId: c.siteId } : null,
  );
  const options = {
    startMs: mine.days.includes(weekdayOf(data.date)) ? saudiTime(data.date, mine.start) : null,
    endMs: saudiTime(data.date, mine.end),
    closeAllMs: saudiTime(data.date, 23 * 60 + 55),
    now,
    // User form "Allowed to leave the site" (2026-10-22); not set = sales team and drivers.
    leavesSite: typeof user.leaveSiteAllowed === 'boolean' ? user.leaveSiteAllowed : LEAVES_SITE_ROLES.includes(user.role),
    overtimeAllowed: user.overtimeAllowed === true,
    overtimeMaxMin: overtimeCap(user.overtimeMaxMin),
    graceMin,
    awayGraceMin,
    driver: user.role === 'driver',
    // Driver overtime (driverOvertime below): running or done.
    drive: ['running', 'done'].includes(data.driveOvertime?.status) && ms(data.driveOvertime.startAt)
      ? { startAt: ms(data.driveOvertime.startAt), endAt: ms(data.driveOvertime.endAt) ?? null, place: data.driveOvertime.place ?? null }
      : null,
  };
  // At the site before the first check-in event (GPS): the day starts then (2026-10-28).
  const arrival = await gpsArrival(data, events);
  options.arrivedAt = arrival.arrivedAt;
  let d = deriveDay(events, options);
  // Closed with no exit seen: with overtime, the last GPS fix at the site
  // tells how long they stayed.
  if (d.checkOutType === 'auto' && options.overtimeAllowed) {
    const lastSeenAt = await lastSeenAtSite(data.uid, data.date, d.siteId);
    if (lastSeenAt !== null) d = deriveDay(events, { ...options, lastSeenAt });
  }
  // For the managers' approval (Attendance page, Home card): 'pending' until
  // a manager saves `overtimeReview` {minutes, byId, at, note, rejected?}
  // (rejected 2026-10-27: minutes 0).
  d.overtimeStatus = d.closed && d.overtimeMin > 0
    ? (data.overtimeReview ? (data.overtimeReview.rejected === true ? 'rejected' : 'approved') : 'pending')
    : d.overtimeOn && !d.closed ? 'running' : null;
  const update = { ...arrival.update };
  if (data.overtimeUnconfirmed !== undefined) update.overtimeUnconfirmed = admin.firestore.FieldValue.delete();
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
  // "Start overtime?" 10 min after the end, reminded once (site staff, 2026-10-25).
  const ask = options.startMs === null ? null : overtimeAskDue(d, {
    ...options, askedAt: ms(data.overtimeAskedAt) ?? null, remindedAt: ms(data.overtimeRemindedAt) ?? null,
  });
  if (ask) {
    update[ask === 'ask' ? 'overtimeAskedAt' : 'overtimeRemindedAt'] = admin.firestore.Timestamp.fromMillis(now);
    await askOvertime(data, d.siteId, options.endMs, ask === 'remind');
  }
  // Confirmed: the direct managers are told (they approve it later).
  if (d.overtimeConfirmedAt !== null && !options.drive && data.overtimeNotified !== true) {
    update.overtimeNotified = true;
    if (now - d.overtimeConfirmedAt < OVERTIME_NOTICE_MS) await announceOvertime(data, d.siteId, user, options.endMs, 'site');
  }
  // Still inside after the end with overtime: ask the phone (silent push)
  // whether they're still at the site, every 30 min up to the cap
  // (2026-10-25; a sleeping phone sends no exit, so the overtime was lost).
  if (siteCheckDue(d, { ...options, lastCheckAt: ms(data.siteCheckAt) ?? null })) {
    update.siteCheckAt = admin.firestore.Timestamp.fromMillis(now);
    update.siteChecks = (data.siteChecks || 0) + 1;
    await sendWakePing(data.uid, { type: 'siteCheck', date: data.date })
      .catch((e) => console.warn('site check', data.uid, e.message));
  }
  if (Object.keys(update).length > 0) await ref.update(update);
}

/** App settings the day rules use (same ranges as `AppSetting` in app_settings.dart). */
async function attendanceSettings() {
  const [graceMin, awayGraceMin] = await Promise.all([
    appSetting('lateGraceMin', LATE_GRACE_MIN, 0, 60),
    appSetting('awayGraceMin', AWAY_GRACE_MIN, 5, 240),
  ]);
  return { graceMin, awayGraceMin };
}

/** Recalculates a day whenever a phone adds an event. */
exports.attendanceUpdated = onDocumentWritten('attendance/{id}', async (event) => {
  const after = event.data?.after;
  if (!after?.exists) return;
  const hours = workHours((await admin.database().ref('settings/workHours').get()).val());
  await updateAttendance(after.ref, after.data(), hours, Date.now(), await attendanceSettings());
});

/** Every 10 minutes: closes open days whose time has come (end of the work day, late evening). */
exports.closeAttendance = onSchedule(
  { schedule: 'every 10 minutes', timeZone: 'Asia/Riyadh', maxInstances: 1 },
  async () => {
    const open = await admin.firestore().collection('attendance').where('closed', '==', false).get();
    const hours = workHours((await admin.database().ref('settings/workHours').get()).val());
    const now = Date.now();
    if (!open.empty) {
      const settings = await attendanceSettings();
      for (const d of open.docs) await updateAttendance(d.ref, d.data(), hours, now, settings);
    }
    // Also with no open day: a driver who left the site earlier is closed at
    // the end ('endOfDay') and still has to be checked for driving overtime
    // (26 Oct: Worker Number Two's overtime never started because of that).
    await driverOvertime(hours, now).catch((e) => console.error('driver overtime', e));
  },
);

/** A driver's places that end their overtime: their work sites (else every active one) and home. */
async function driverPlaces(user) {
  const sites = (await admin.firestore().collection('work_sites').where('active', '==', true).get()).docs
    .map((d) => ({ id: d.id, ...d.data() }));
  const ids = Array.isArray(user.workSiteIds) ? user.workSiteIds : [];
  const mine = sites.filter((x) => ids.includes(x.id));
  const places = (mine.length ? mine : sites).map((x) => ({ lat: x.lat, lng: x.lng, radius: x.radius || 100, kind: 'site' }));
  const h = user.homeLocation;
  if (typeof h?.lat === 'number' && typeof h.lng === 'number') places.push({ lat: h.lat, lng: h.lng, radius: HOME_RADIUS_M, kind: 'home' });
  return places;
}

/**
 * Driver overtime (user decisions 2026-10-25, rules 2026-10-27), run with
 * closeAttendance, decided at end + `driveHomeGraceMin` (App settings, 30;
 * at least 10 min) from location_history (`driveDecide`):
 * - at a work site or home at the end, or still driving and home within the
 *   grace (the drive home) → {status 'none'};
 * - still driving at the end and already arrived at a site (or home after
 *   the grace) → {status 'done', startAt = end, endAt, place};
 * - still driving, not arrived → {status 'running'}, the driver and their
 *   direct managers told; `driveEnd` later finds the arrival → 'done';
 * - no fix near the end by an hour after the decision time → {status 'late'}.
 * The day closes at the arrival; the manager approves / changes / rejects it.
 */
async function driverOvertime(hours, now) {
  const db = admin.firestore();
  const rtdb = admin.database();
  const drivers = await db.collection('users').where('role', '==', 'driver').where('overtimeAllowed', '==', true).get();
  // Arriving home this soon after the end = the drive home (App settings, 2026-10-27).
  const homeGraceMs = (await appSetting('driveHomeGraceMin', DRIVE_HOME_GRACE_MIN, 0, 120)) * 60000;
  const decideAfterMs = Math.max(10 * 60000, homeGraceMs);
  for (const u of drivers.docs) {
    const user = u.data();
    if (user.active !== true) continue;
    const date = saudiDay(now);
    const mine = scheduleOf(user, hours);
    if (!mine.days.includes(weekdayOf(date))) continue;
    const endMs = saudiTime(date, mine.end);
    if (now < endMs + decideAfterMs || now > endMs + decideAfterMs + 70 * 60000) continue;
    const ref = db.doc(`attendance/${u.id}_${date}`);
    const day = await ref.get();
    if (!day.exists || !day.get('checkInAt') || day.get('driveOvertime')) continue;
    const [history, places] = await Promise.all([rtdb.ref(`location_history/${u.id}/${date}`).get(), driverPlaces(user)]);
    const r = driveDecide({ points: Object.values(history.val() || {}), endMs, now, homeGraceMs, places });
    if (r === 'wait') continue;
    const ts = admin.firestore.Timestamp.fromMillis;
    if (r.status === 'running') {
      await ref.update({ driveOvertime: { status: 'running', startAt: ts(endMs), startedAt: ts(now) } });
      await announceOvertime({ uid: u.id, date }, null, user, endMs, 'driving');
    } else if (r.status === 'done') {
      // Already back (e.g. at the site at 17:25): recorded, waits for the manager's approval.
      await ref.update({ driveOvertime: { status: 'done', startAt: ts(endMs), startedAt: ts(now), endAt: ts(r.endAt), place: r.place } });
    } else {
      await ref.update({ driveOvertime: { status: r } });
    }
  }
  const running = await db.collection('attendance').where('driveOvertime.status', '==', 'running').get();
  for (const doc of running.docs) {
    const data = doc.data();
    const startAt = data.driveOvertime.startAt?.toMillis?.();
    if (!startAt || !data.uid) continue;
    const user = (await db.doc(`users/${data.uid}`).get()).data() || {};
    const capMs = overtimeCap(user.overtimeMaxMin) * 60000;
    // The cap can run past midnight.
    const days = [...new Set([data.date, saudiDay(Math.min(now, startAt + capMs))])];
    const [places, ...histories] = await Promise.all([
      driverPlaces(user),
      ...days.map((day) => rtdb.ref(`location_history/${data.uid}/${day}`).get()),
    ]);
    const points = histories.flatMap((h) => Object.values(h.val() || {}));
    const r = driveEnd({ points, startAt, now, capMs, places });
    if (!r) continue;
    await doc.ref.update({
      'driveOvertime.status': 'done',
      'driveOvertime.endAt': admin.firestore.Timestamp.fromMillis(r.endAt),
      'driveOvertime.place': r.place,
    });
  }
}

/**
 * A person's direct manager(s) (user decision 2026-10-22): a sales exec's
 * KAM, else the sales managers; a KAM's sales managers; everyone else's GMs
 * (also when no one fits). Same as `directManagersOf` in notifications.dart.
 */
function directManagers(person, uid, users) {
  // Chosen on the user form (2026-10-23).
  const chosen = users.find((u) => u.id === person.managerId && u.active === true && u.id !== uid);
  if (chosen) return [chosen.id];
  const withRole = (r) => users.filter((u) => u.active === true && u.role === r && u.id !== uid).map((u) => u.id);
  if (person.role === 'gm') return [];
  let found = [];
  if (person.role === 'sales_exec') {
    found = users.filter((u) => u.id === person.kamId && u.active === true && u.role === 'kam').map((u) => u.id);
    if (found.length === 0) found = withRole('sales_manager');
  } else if (person.role === 'kam') {
    found = withRole('sales_manager');
  } else if (person.role === 'driver' || person.role === 'warehouse_supervisor') {
    found = withRole('logistics_manager');
  } else {
    found = withRole('gm');
  }
  return found.length > 0 ? found : withRole('gm');
}

/**
 * "Not coming to work" reported on the attendance card (2026-10-22,
 * `absences/{uid}_{date}`): tells HR and every GM (who decide it) and the
 * person's direct manager. `ref` = the absence id.
 */
/** The sales manager acts as HR until HR has an account (user request 2026-10-22, testing; `smActsAsHr` in absence.dart). */
const SM_ACTS_AS_HR = true;

exports.absenceReported = onDocumentCreated('absences/{id}', async (event) => {
  const a = event.data?.data();
  if (!a?.uid || !a.date) return;
  const db = admin.firestore();
  const users = (await db.collection('users').where('active', '==', true).get()).docs
    .map((d) => ({ id: d.id, ...d.data() }));
  const person = users.find((u) => u.id === a.uid) || {};
  const to = new Set([
    ...users.filter((u) => u.role === 'hr' || u.role === 'gm' || (SM_ACTS_AS_HR && u.role === 'sales_manager')).map((u) => u.id),
    ...directManagers(person, a.uid, users),
  ]);
  to.delete(a.uid);
  const batch = db.batch();
  for (const toId of to) {
    batch.set(db.collection('notifications').doc(), {
      toId, fromId: a.uid, ownerId: a.uid, type: 'absenceReported', date: a.date, count: 0,
      issue: a.reason || '', note: String(a.note || '').slice(0, 300), ref: event.params.id, read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
});

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

    const [sentSnap, daySnap, leaveSnap, absentSnap] = await Promise.all([
      rtdb.ref('attendance_reminders').get(),
      db.collection('attendance').where('date', '==', today).get(),
      db.collection('leave_requests').where('to', '>=', today).get(),
      db.collection('absences').where('date', '==', today).get(),
    ]);
    const sent = sentSnap.val() || {};
    const checkedIn = new Set(daySnap.docs
      .filter((d) => d.get('checkInAt') || (d.get('events') || []).some((e) => e.type === 'in' || e.type === 'checkIn'))
      .map((d) => d.get('uid')));
    const onLeave = new Set(leaveSnap.docs
      .filter((d) => d.get('status') === 'approved' && d.get('isLeave') !== false && d.get('from') <= today)
      .map((d) => d.get('uid')));
    // Told the company beforehand they won't come (2026-10-22).
    const absent = new Set(absentSnap.docs.map((d) => d.get('uid')));

    const batch = db.batch();
    const marks = {};
    for (const u of users) {
      if (sent[u.id] === today || checkedIn.has(u.id) || onLeave.has(u.id) || absent.has(u.id)) continue;
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

/**
 * Every 5 minutes (2026-10-28, after Driver Number Two's 27 Oct: at the
 * site from 08:42, the geofence never fired, checked in by hand at 09:22):
 * tracked people (sales exec, KAM, driver) who need attendance, aren't
 * checked in and whose live position (≤15 min old) has been at one of their
 * sites (two fixes or more, `siteArrival`) are told to check in
 * (`attendanceAtSite`, alert sound, opens Home); reminded once 30 min later.
 * Work days, from 2 h before the start until the end; not on leave / absent.
 * Their check-in then starts at that GPS arrival anyway (`gpsArrival`).
 * Sent in RTDB `attendance_at_site/{uid}` {date, count, at} (admin only).
 */
exports.atSiteReminders = onSchedule(
  { schedule: 'every 5 minutes', timeZone: 'Asia/Riyadh', maxInstances: 1 },
  async () => {
    const now = Date.now();
    const today = saudiDay(now);
    const saudi = new Date(now + 3 * 3600 * 1000);
    const minute = saudi.getUTCHours() * 60 + saudi.getUTCMinutes();
    const db = admin.firestore();
    const rtdb = admin.database();
    const holidays = (await db.doc('settings/holidays').get()).get('dates') || [];
    if (holidays.includes(today)) return;
    const hours = workHours((await rtdb.ref('settings/workHours').get()).val());
    const users = (await db.collection('users').where('role', 'in', ['sales_exec', 'kam', 'driver']).get()).docs
      .filter((d) => checksAttendance(d.data()))
      .filter((d) => {
        const h = scheduleOf(d.data(), hours);
        return h.days.includes(weekdayOf(today)) && minute >= h.start - 120 && minute < h.end;
      });
    if (users.length === 0) return;
    const [live, sentSnap, sitesSnap] = await Promise.all([
      rtdb.ref('live_locations').get(),
      rtdb.ref('attendance_at_site').get(),
      db.collection('work_sites').where('active', '==', true).get(),
    ]);
    const sites = Object.fromEntries(sitesSnap.docs.map((d) => [d.id, { id: d.id, ...d.data(), radius: d.get('radius') || 100 }]));
    const sent = sentSnap.val() || {};
    for (const u of users) {
      const p = live.val()?.[u.id];
      const fixAt = p?.fixAt || p?.updatedAt;
      if (typeof p?.lat !== 'number' || typeof fixAt !== 'number' || now - fixAt > 15 * 60000 || (p.accuracy || 0) > 100) continue;
      const due = atSiteReminderDue(sent[u.id], today, now);
      if (!due) continue;
      const mine = (u.get('workSiteIds') || []).map((id) => sites[id]).filter(Boolean);
      const margin = Math.min(p.accuracy || 0, 100);
      const site = mine.find((x) => metersBetween(p, x) <= x.radius + margin);
      if (!site) continue;
      const [day, absence, leave, history] = await Promise.all([
        db.doc(`attendance/${u.id}_${today}`).get(),
        db.doc(`absences/${u.id}_${today}`).get(),
        db.collection('leave_requests').where('uid', '==', u.id).where('status', '==', 'approved').get(),
        rtdb.ref(`location_history/${u.id}/${today}`).get(),
      ]);
      if (day.get('checkInAt') || (day.get('events') || []).some((e) => e.type === 'in' || e.type === 'checkIn')) continue;
      if (absence.exists) continue;
      if (leave.docs.some((l) => l.get('isLeave') !== false && l.get('from') <= today && l.get('to') >= today)) continue;
      const points = Object.values(history.val() || {});
      const arrivedAt = siteArrival(points, site, now);
      // Two fixes there at least (one could be driving past).
      if (arrivedAt === null || points.filter((x) => x.t >= arrivedAt).length < 2) continue;
      await db.collection('notifications').add({
        toId: u.id, fromId: u.id, ownerId: u.id, type: 'attendanceAtSite', date: today, count: due === 'remind' ? 1 : 0,
        siteName: site.name || '', time: saudiClock(arrivedAt), read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      await rtdb.ref(`attendance_at_site/${u.id}`).set({ date: today, count: due === 'remind' ? 2 : 1, at: now });
    }
  },
);

// Day timelines (user request 2026-10-20; drivers' deliveries 2026-10-24): each salesperson's / driver's working day
// split into client / driving / office / lunch / stopped / no data from their
// GPS points, saved in Firestore `day_timelines/{uid}_{yyyy-MM-dd}` for the
// Reports routing section and Route history (see timeline.js).
const { buildDayTimeline } = require('./timeline');

/**
 * Builds and saves one person's day; null when there's nothing to build.
 * [places] = client locations for drivers (deliveries matched by distance,
 * 2026-10-24); null for salespeople, whose client time comes from check-ins.
 */
async function saveTimeline(uid, day, hours, sites, places = null) {
  const isDriver = places !== null;
  if (!isDriver && !hours.days.includes(weekdayOf(day))) return null;
  const db = admin.firestore();
  const [history, visitSnap] = await Promise.all([
    admin.database().ref(`location_history/${uid}/${day}`).get(),
    isDriver ? null : db.collection('visits').where('salesExecId', '==', uid).where('month', '==', day.slice(0, 7)).get(),
  ]);
  const points = mainTrack(Object.values(history.val() || {})
    .filter((p) => typeof p?.lat === 'number' && typeof p?.lng === 'number' && typeof p?.t === 'number')
    .filter((p) => (p.accuracy || 0) <= ROUTE_MAX_ACCURACY)
    .sort((a, b) => a.t - b.t));
  const visits = (visitSnap?.docs ?? [])
    .map((d) => ({ id: d.id, ...d.data() }))
    .filter((v) => v.type !== 'call' && v.checkedInAt?.toMillis && typeof v.checkInLat === 'number' && typeof v.checkInLng === 'number')
    .map((v) => ({ id: v.id, clientId: v.clientId, at: v.checkedInAt.toMillis(), lat: v.checkInLat, lng: v.checkInLng }))
    .filter((v) => saudiDay(v.at) === day)
    .sort((a, b) => a.at - b.at);
  if (points.length === 0 && visits.length === 0) return null;
  const now = Date.now();
  const workDay = hours.days.includes(weekdayOf(day));
  // Work hours, stretched to cover visits made a little before / after them.
  let startMs = saudiTime(day, hours.start);
  let endMs = saudiTime(day, hours.end);
  if (visits.length) {
    startMs = Math.min(startMs, visits[0].at - 30 * 60000);
    endMs = Math.max(endMs, visits[visits.length - 1].at + 60 * 60000);
  }
  if (isDriver) {
    // Drivers are tracked all day (they keep the car): find the deliveries
    // over the whole day, then stretch the work hours to cover them; off days
    // only from the first delivery to the last.
    const whole = buildDayTimeline({ points, visits, sites, places, startMs: saudiTime(day, 0), endMs: saudiTime(day, 1440) - 1 });
    const stays = whole.clientStays;
    if (!workDay && stays.length === 0) return null;
    if (stays.length) {
      startMs = workDay ? Math.min(startMs, stays[0].from) : stays[0].from;
      endMs = workDay ? Math.max(endMs, stays[stays.length - 1].to) : stays[stays.length - 1].to;
    }
  }
  endMs = Math.min(endMs, Math.max(startMs, now)); // today: up to now
  const t = buildDayTimeline({ points, visits, sites, places: places ?? [], startMs, endMs });
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

/** Client locations (main + extras) for drivers' deliveries; kept 10 minutes per instance. */
let clientPlacesCache = null;
async function clientPlaces() {
  if (clientPlacesCache && Date.now() - clientPlacesCache.at < 10 * 60000) return clientPlacesCache.places;
  const snap = await admin.firestore().collection('clients').select('name', 'lat', 'lng', 'extraLocations').get();
  const places = [];
  for (const d of snap.docs) {
    const c = d.data();
    if (typeof c.lat !== 'number' || typeof c.lng !== 'number') continue; // extras only count with a main
    places.push({ clientId: d.id, name: c.name ?? '', locationId: null, lat: c.lat, lng: c.lng });
    for (const x of Array.isArray(c.extraLocations) ? c.extraLocations : []) {
      if (typeof x?.lat === 'number' && typeof x?.lng === 'number') {
        places.push({ clientId: d.id, name: c.name ?? '', locationId: x.id ?? null, lat: x.lat, lng: x.lng });
      }
    }
  }
  clientPlacesCache = { at: Date.now(), places };
  return places;
}

/** Days kept for the benchmarks when back-filling. */
const TIMELINE_BACKFILL_DAYS = 30;

/** Nightly: yesterday's timelines, plus any missing day of the last 30 (first run back-fills). */
exports.buildTimelines = onSchedule(
  { schedule: '30 0 * * *', timeZone: 'Asia/Riyadh', timeoutSeconds: 540, memory: '512MiB', maxInstances: 1 },
  async () => {
    const db = admin.firestore();
    const { hours, sites } = await timelineContext();
    const users = (await db.collection('users').where('role', 'in', ['sales_exec', 'kam', 'driver']).get()).docs
      .filter((d) => d.get('active') === true);
    const people = users.map((d) => d.id);
    const drivers = new Set(users.filter((d) => d.get('role') === 'driver').map((d) => d.id));
    const places = drivers.size ? await clientPlaces() : null;
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
        await saveTimeline(uid, day, hours, sites, drivers.has(uid) ? places : null);
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
  const target = uid === req.auth.uid ? me : await db.doc(`users/${uid}`).get();
  if (uid !== req.auth.uid && !['sales_manager', 'gm'].includes(role)) {
    if (!followsPerson(role, req.auth.uid, target)) throw new HttpsError('permission-denied', 'Not your team');
  }
  const { hours, sites } = await timelineContext();
  const places = target.exists && target.get('role') === 'driver' ? await clientPlaces() : null;
  const doc = await saveTimeline(uid, day, hours, sites, places);
  return { built: doc !== null };
});

/**
 * Deletes a user for good (user request 2026-10-21; since 2026-10-23 only
 * the accounts in USER_DELETERS):
 * the login account (so the email can be used again), `users/{uid}` with its
 * push tokens, the RTDB role, live location, presence, tracking phone,
 * tracking schedule, route history and tracking log. Their clients become
 * unassigned and their team loses its KAM; visits, plans, attendance and
 * leave stay as history. Nobody deletes themselves.
 */
/** The only accounts that may delete users (user decision 2026-10-23); `userDeleterEmails` in app_user.dart. */
const USER_DELETERS = ['wissam.b@woodpanelsco.com'];

exports.deleteUser = onCall({ timeoutSeconds: 120, maxInstances: 2 }, async (req) => {
  const callerId = req.auth?.uid;
  if (!callerId) throw new HttpsError('unauthenticated', 'Sign in first.');
  const db = admin.firestore();
  const caller = (await db.doc(`users/${callerId}`).get()).data();
  // The signed-in account's own email (from Auth, not the profile, which admins can edit).
  const email = String(req.auth.token.email || '').toLowerCase();
  if (caller?.active !== true || !USER_DELETERS.includes(email)) {
    throw new HttpsError('permission-denied', 'You are not allowed to delete users.');
  }
  const uid = req.data?.uid;
  if (typeof uid !== 'string' || uid === '' || uid.includes('/')) throw new HttpsError('invalid-argument', 'uid missing.');
  if (uid === callerId) throw new HttpsError('invalid-argument', 'You cannot delete your own account.');
  const userRef = db.doc(`users/${uid}`);
  const target = (await userRef.get()).data();

  const [clients, team, devices] = await Promise.all([
    db.collection('clients').where('assignedTo', '==', uid).get(),
    db.collection('users').where('kamId', '==', uid).get(),
    userRef.collection('devices').get(),
  ]);
  const writes = [
    ...clients.docs.map((d) => (b) => b.update(d.ref, { assignedTo: null, updatedAt: admin.firestore.FieldValue.serverTimestamp() })),
    ...team.docs.map((d) => (b) => b.update(d.ref, { kamId: null })),
    ...devices.docs.map((d) => (b) => b.delete(d.ref)),
  ];
  for (let i = 0; i < writes.length; i += 400) {
    const batch = db.batch();
    writes.slice(i, i + 400).forEach((w) => w(batch));
    await batch.commit();
  }
  await userRef.delete();
  await admin.database().ref().update(Object.fromEntries([
    'roles', 'live_locations', 'presence', 'tracking_device', 'settings/trackingSchedules', 'location_history',
    'route_snapped', 'tracking_events', 'tracking_alerts', 'attendance_reminders', 'attendance_at_site',
  ].map((path) => [`${path}/${uid}`, null])));
  try {
    await admin.auth().deleteUser(uid);
  } catch (e) {
    if (e.code !== 'auth/user-not-found') throw e;
  }
  return { clients: clients.size };
});

/**
 * Sets another user's password (2026-10-23), mainly for username accounts:
 * their email is a hidden `<username>@staff.wpc-crm-a9247.web.app` with no
 * mailbox, so no reset email reaches them. GM: anyone; sales manager: not
 * GMs or sales managers; logistics manager: drivers. Never oneself (Profile
 * page does that with the current password).
 */
exports.setUserPassword = onCall({ maxInstances: 2 }, async (req) => {
  const callerId = req.auth?.uid;
  if (!callerId) throw new HttpsError('unauthenticated', 'Sign in first.');
  const db = admin.firestore();
  const caller = (await db.doc(`users/${callerId}`).get()).data();
  const uid = req.data?.uid;
  const password = req.data?.password;
  if (typeof uid !== 'string' || uid === '' || uid.includes('/')) throw new HttpsError('invalid-argument', 'uid missing.');
  if (typeof password !== 'string' || password.length < 6) throw new HttpsError('invalid-argument', 'At least 6 characters.');
  if (uid === callerId) throw new HttpsError('invalid-argument', 'Change your own password on the Profile page.');
  const target = (await db.doc(`users/${uid}`).get()).data();
  const allowed = caller?.active === true && (
    caller.role === 'gm' ||
    (caller.role === 'sales_manager' && !['gm', 'sales_manager'].includes(target?.role)) ||
    (caller.role === 'logistics_manager' && target?.role === 'driver'));
  if (!allowed) throw new HttpsError('permission-denied', 'You cannot change this user\'s password.');
  await admin.auth().updateUser(uid, { password });
  return { ok: true };
});

/**
 * A visit or call ticks the visitor's open plan items for that client on
 * that day (Saudi date), whichever screen it was saved from (user rule
 * 2026-10-21). The app ticks them itself right after saving; this is the
 * safety net for when that step never ran (3 items stayed open
 * 2026-10-18…20: lost signal or the app closed right after saving) and for
 * older app builds.
 */
exports.tickPlanOnVisit = onDocumentCreated({ document: 'visits/{id}', maxInstances: 5 }, async (event) => {
  const v = event.data?.data();
  if (!v?.clientId || !v.salesExecId) return;
  const at = v.checkedInAt?.toMillis ? v.checkedInAt.toMillis() : Date.now();
  const open = await admin.firestore().collection('tasks')
    .where('ownerId', '==', v.salesExecId)
    .where('date', '==', saudiDay(at))
    .where('clientId', '==', v.clientId)
    .where('done', '==', false)
    .get();
  await Promise.all(open.docs.map((d) => d.ref.update({
    done: true, doneAt: admin.firestore.Timestamp.fromMillis(at), visitId: event.params.id,
  })));
});

/**
 * The other way round: a client put on someone's plan for a day they
 * already visited or called that client is ticked at once.
 */
exports.tickPlanOnPlanned = onDocumentCreated({ document: 'tasks/{id}', maxInstances: 5 }, async (event) => {
  const t = event.data?.data();
  if (!t?.clientId || !t.ownerId || t.done === true || !/^\d{4}-\d{2}-\d{2}$/.test(t.date || '')) return;
  const visits = await admin.firestore().collection('visits')
    .where('clientId', '==', t.clientId)
    .where('salesExecId', '==', t.ownerId)
    .where('month', '==', t.date.slice(0, 7))
    .get();
  const done = visits.docs.find((d) => d.get('checkedInAt')?.toMillis && saudiDay(d.get('checkedInAt').toMillis()) === t.date);
  if (!done) return;
  await event.data.ref.update({ done: true, doneAt: done.get('checkedInAt'), visitId: done.id });
});

// --- Vehicles (2026-10-24) ------------------------------------------------
// Kilometres per driver per day from their GPS points, for the vehicles'
// odometer estimate: Firestore `driver_km/{uid}_{day}` {uid, day, km, points,
// final}. Renewal reminders for registration / insurance / inspection.
const { dayKm, renewalAlerts, lastReading, vehicleEstimate, oilAlerts, DUE_SOON_DAYS, OIL_DUE_SOON_KM } = require('./vehicles');

/** Days back that location history still has (cleanRouteHistory keeps 90). */
const DRIVER_KM_DAYS = 89;

async function saveDriverKm(uid, day, today) {
  const history = await admin.database().ref(`location_history/${uid}/${day}`).get();
  const points = mainTrack(Object.values(history.val() || {})
    .filter((p) => typeof p?.lat === 'number' && typeof p?.lng === 'number' && typeof p?.t === 'number')
    .filter((p) => (p.accuracy || 0) <= ROUTE_MAX_ACCURACY)
    .sort((a, b) => a.t - b.t));
  const spikes = spikeTimes(points);
  const doc = { uid, day, km: dayKm(points.filter((p) => !spikes.has(p.t))), points: points.length, final: day < today, builtAt: Date.now() };
  await admin.firestore().doc(`driver_km/${uid}_${day}`).set(doc);
  return doc;
}

/** Builds the missing or unfinished days of [uids] from [from] to today; at most [limit]. */
async function fillDriverKm(uids, from, limit) {
  const db = admin.firestore();
  const today = saudiDay(Date.now());
  const oldest = saudiDay(Date.parse(`${today}T12:00:00Z`) - DRIVER_KM_DAYS * 86400000);
  const start = from && from > oldest ? from : oldest;
  const days = [];
  for (let ms = Date.parse(`${start}T12:00:00Z`); saudiDay(ms) <= today; ms += 86400000) days.push(saudiDay(ms));
  if (!uids.length || !days.length) return 0;
  const refs = uids.flatMap((uid) => days.map((day) => db.doc(`driver_km/${uid}_${day}`)));
  const done = new Set();
  for (let i = 0; i < refs.length; i += 300) {
    for (const s of await db.getAll(...refs.slice(i, i + 300))) if (s.exists && s.get('final') === true) done.add(s.id);
  }
  let built = 0;
  for (const uid of uids) {
    for (const day of days) {
      if (done.has(`${uid}_${day}`)) continue;
      await saveDriverKm(uid, day, today);
      if (++built >= limit) return built;
    }
  }
  return built;
}

/** The drivers whose km are needed: active drivers and anyone on a vehicle. */
async function vehicleDrivers() {
  const db = admin.firestore();
  const [drivers, vehicles] = await Promise.all([
    db.collection('users').where('role', '==', 'driver').where('active', '==', true).get(),
    db.collection('vehicles').get(),
  ]);
  const uids = new Set(drivers.docs.map((d) => d.id));
  for (const v of vehicles.docs) for (const uid of v.get('driverIds') || []) uids.add(uid);
  return [...uids];
}

/** Nightly: yesterday's km, plus any day still missing (the first run back-fills 89 days). */
exports.driverKm = onSchedule(
  { schedule: '45 0 * * *', timeZone: 'Asia/Riyadh', timeoutSeconds: 540, memory: '512MiB', maxInstances: 1 },
  async () => {
    await fillDriverKm(await vehicleDrivers(), null, 1500);
  },
);

/** Vehicles page: today's km and missing days of these drivers, now. SM / GM / logistics manager. */
exports.refreshDriverKm = onCall({ timeoutSeconds: 120, maxInstances: 3 }, async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in first');
  const me = await admin.firestore().doc(`users/${req.auth.uid}`).get();
  if (me.get('active') !== true || !['sales_manager', 'gm', 'logistics_manager'].includes(me.get('role'))) {
    throw new HttpsError('permission-denied', 'Not allowed');
  }
  const { uids, from } = req.data || {};
  if (!Array.isArray(uids) || uids.length > 30 || uids.some((u) => typeof u !== 'string' || !u || u.includes('/'))) {
    throw new HttpsError('invalid-argument', 'uids');
  }
  const day = /^\d{4}-\d{2}-\d{2}$/.test(from || '') ? from : null;
  return { built: await fillDriverKm(uids, day, 300) };
});

/**
 * Every morning: reminds the GMs, sales managers and logistics managers
 * (user decisions 2026-10-24) once when a vehicle's registration, insurance, periodic
 * inspection or operating card is App settings `vehicleRenewalDays` (default 14) days from expiring (`vehicleRenewalDue`; count = days
 * left, date = the expiry). It stays on their Home until a new date is
 * entered. Sent keys are kept in `vehicles.renewalNotified`. Oil changes
 * (2026-10-26): `vehicleOilDue` once when the estimate is App settings
 * `oilDueSoonKm` (500) from the next change and once when it's reached
 * (count = km left, note = the km it's due at).
 */
exports.vehicleRenewals = onSchedule(
  { schedule: '0 8 * * *', timeZone: 'Asia/Riyadh', maxInstances: 1 },
  async () => {
    const db = admin.firestore();
    const today = saudiDay(Date.now());
    const [vehicles, managers, dueSoonDays, oilSoonKm] = await Promise.all([
      db.collection('vehicles').get(),
      db.collection('users').where('role', 'in', ['logistics_manager', 'sales_manager', 'gm']).where('active', '==', true).get(),
      appSetting('vehicleRenewalDays', DUE_SOON_DAYS, 1, 90),
      appSetting('oilDueSoonKm', OIL_DUE_SOON_KM, 100, 5000),
    ]);
    if (managers.empty) return;
    // Oil changes (2026-10-26): odometer estimate from the drivers' GPS km
    // (yesterday's were built at 00:45), one driver_km range read for all.
    const oilCars = vehicles.docs.filter((v) => v.get('oilIntervalKm') > 0 && (v.get('oilLog') || []).length && lastReading(v.data()));
    const since = oilCars.map((v) => lastReading(v.data()).day).sort()[0];
    const kmDocs = since
      ? (await db.collection('driver_km').where('day', '>', since).get()).docs.map((d) => d.data())
      : [];
    for (const v of vehicles.docs) {
      const notified = v.get('renewalNotified') || [];
      const alerts = renewalAlerts(v.data(), today, notified, dueSoonDays);
      const oil = oilCars.includes(v) ? oilAlerts(v.data(), vehicleEstimate(v.data(), kmDocs), notified, oilSoonKm) : [];
      if (!alerts.length && !oil.length) continue;
      const batch = db.batch();
      for (const a of oil) {
        for (const m of managers.docs) {
          batch.set(db.collection('notifications').doc(), {
            toId: m.id, fromId: m.id, ownerId: '', type: 'vehicleOilDue', date: today,
            count: a.kmLeft, note: String(a.nextKm), ref: v.id, vehicleName: v.get('plate') || '',
            read: false, createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }
      for (const a of alerts) {
        for (const m of managers.docs) {
          batch.set(db.collection('notifications').doc(), {
            toId: m.id, fromId: m.id, ownerId: '', type: 'vehicleRenewalDue', issue: a.item,
            date: a.expiry, count: a.days, ref: v.id, vehicleName: v.get('plate') || '',
            read: false, createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }
      batch.update(v.ref, { renewalNotified: admin.firestore.FieldValue.arrayUnion(...[...alerts, ...oil].map((a) => a.key)) });
      await batch.commit();
    }
  },
);

// --- Leave years (2026-10-24) ---------------------------------------------
const { leaveYearOf, leaveYearRange, closeYear, DEFAULT_TYPES: DEFAULT_LEAVE_TYPES, ANNUAL } = require('./leaveYears');

/** Only years ending from the day this was built are closed (no made-up history before it). */
const LEAVE_CLOSE_FROM = '2026-10-24';

/** Days after a year ends during which it is worked out again (late approvals). */
const LEAVE_RECLOSE_DAYS = 30;

/**
 * Every night: for each active person whose leave year ended in the last
 * 30 days, saves its numbers in `leave_history/{uid}_{year}` (days taken per
 * type) and moves the annual leave left into the new year's
 * `leave_balances/{uid}_{year+1}.carried.annual` — overdrawn days always,
 * days left only with `settings/leavePolicy.annualCarryOver`. Re-done each
 * night of those 30 days so requests approved late still count.
 */
exports.closeLeaveYears = onSchedule(
  { schedule: '15 1 * * *', timeZone: 'Asia/Riyadh', timeoutSeconds: 300, maxInstances: 1 },
  async () => {
    const db = admin.firestore();
    const today = saudiDay(Date.now());
    const [usersSnap, typesSnap, policySnap] = await Promise.all([
      db.collection('users').where('active', '==', true).get(),
      db.doc('settings/leaveTypes').get(),
      db.doc('settings/leavePolicy').get(),
    ]);
    const types = Array.isArray(typesSnap.get('types')) ? typesSnap.get('types') : DEFAULT_LEAVE_TYPES;
    const carryOver = policySnap.get('annualCarryOver') === true;
    const due = [];
    for (const u of usersSnap.docs) {
      if (!u.get('role')) continue;
      const joining = u.get('joiningDate') || null;
      const year = leaveYearOf(joining, today) - 1;
      const { from, to } = leaveYearRange(joining, year);
      const daysSince = (Date.parse(`${today}T00:00:00Z`) - Date.parse(`${to}T00:00:00Z`)) / 86400000;
      if (to < LEAVE_CLOSE_FROM || daysSince > LEAVE_RECLOSE_DAYS) continue;
      if (joining && from < joining) continue; // not employed yet then
      due.push({ uid: u.id, joining, year });
    }
    if (!due.length) return;
    const balances = await db.getAll(...due.map((d) => db.doc(`leave_balances/${d.uid}_${d.year}`)));
    for (const [i, d] of due.entries()) {
      const requests = (await db.collection('leave_requests').where('uid', '==', d.uid).get()).docs
        .map((r) => r.data())
        .filter((r) => r.isLeave !== false);
      const r = closeYear({ types, balance: balances[i].data() || {}, requests, joining: d.joining, year: d.year, carryOver });
      const batch = db.batch();
      batch.set(db.doc(`leave_history/${d.uid}_${d.year}`), {
        uid: d.uid, year: d.year, joiningDate: d.joining, ...r, carryOver,
        builtAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      batch.set(db.doc(`leave_balances/${d.uid}_${d.year + 1}`), {
        uid: d.uid, year: d.year + 1, carried: { [ANNUAL]: r.carriedOut },
      }, { merge: true });
      await batch.commit();
    }
  },
);
