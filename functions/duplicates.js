// Duplicate check for a client about to be added. Same rules as
// lib/features/clients/duplicates.dart (keep both in sync): same Tax ID or
// CR number, same name / alias, same phone, similar names, or within 50 m
// sharing a name word; different Tax IDs only match on identical names.

const NOISE = new Set([
  'co', 'company', 'est', 'establishment', 'corp', 'corporation', 'llc', 'ltd', 'limited', 'inc', 'the', 'and',
  'for', 'of', 'شركه', 'مؤسسه', 'شركة', 'مؤسسة', 'و', 'ذ', 'م', 'م.', 'ش',
]);

function nameTokens(name) {
  const s = String(name || '')
    .toLowerCase()
    .replace(/[ً-ٰٟـ]/g, '') // harakat, tatweel
    .replace(/[أإآ]/g, 'ا')
    .replace(/ة/g, 'ه')
    .replace(/ى/g, 'ي')
    .replace(/[^\p{L}\p{N}]+/gu, ' ');
  return s.split(' ').filter((t) => t && !NOISE.has(t));
}

const compactName = (name) => nameTokens(name).join('');
const digits = (s) => String(s || '').replace(/\D/g, '');

function phoneKey(phone) {
  const d = digits(phone);
  return d.length < 9 ? '' : d.slice(-9);
}

function editDistance(a, b) {
  if (Math.abs(a.length - b.length) > 2) return 3;
  let prev = Array.from({ length: b.length + 1 }, (_, i) => i);
  for (let i = 1; i <= a.length; i++) {
    const cur = [i];
    for (let j = 1; j <= b.length; j++) {
      cur[j] = Math.min(cur[j - 1] + 1, prev[j] + 1, prev[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
    }
    prev = cur;
  }
  return prev[b.length];
}

function similarNames(a, b) {
  if (!a.length || !b.length) return false;
  const sa = new Set(a);
  const sb = new Set(b);
  const common = [...sa].filter((t) => sb.has(t)).length;
  const smaller = Math.min(sa.size, sb.size);
  if (smaller >= 2 && common === smaller) return true;
  if (common / new Set([...sa, ...sb]).size >= 0.75) return true;
  const ca = a.join('');
  const cb = b.join('');
  return Math.min(ca.length, cb.length) >= 8 && editDistance(ca, cb) <= 2;
}

function meters(a, b) {
  const rad = (d) => (d * Math.PI) / 180;
  const h = Math.sin(rad(b.lat - a.lat) / 2) ** 2
    + Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(rad(b.lng - a.lng) / 2) ** 2;
  return 2 * 6371000 * Math.asin(Math.sqrt(h));
}

const hasLocation = (c) => typeof c.lat === 'number' && typeof c.lng === 'number';

/**
 * Why [existing] looks like the [draft] client: a list of 'sameVat',
 * 'sameCompanyId', 'sameName', 'samePhone', 'similarName', 'nearby'; empty
 * when it doesn't. [crowdedPhones]: phone keys on more than 3 clients
 * (placeholders, ignored).
 */
function duplicateReasons(draft, existing, crowdedPhones = new Set()) {
  const reasons = [];
  const vatA = digits(draft.vat);
  const vatB = digits(existing.vat);
  const crA = digits(draft.companyId);
  const crB = digits(existing.companyId);
  if (vatA && vatA === vatB) reasons.push('sameVat');
  if (crA && crA === crB) reasons.push('sameCompanyId');
  const namesA = new Set([draft.name, ...(draft.aliases || [])].map(compactName).filter(Boolean));
  const namesB = [existing.name, ...(existing.aliases || [])].map(compactName).filter(Boolean);
  if (namesB.some((n) => namesA.has(n))) reasons.push('sameName');
  if (vatA && vatB && vatA !== vatB) return reasons; // different companies unless the names are identical
  const phonesA = [phoneKey(draft.phone), phoneKey(draft.mobile)].filter((p) => p && !crowdedPhones.has(p));
  const phonesB = new Set([phoneKey(existing.phone), phoneKey(existing.mobile)].filter(Boolean));
  if (phonesA.some((p) => phonesB.has(p))) reasons.push('samePhone');
  const tokA = nameTokens(draft.name);
  const tokB = nameTokens(existing.name);
  if (!reasons.includes('sameName') && similarNames(tokA, tokB)) reasons.push('similarName');
  if (hasLocation(draft) && hasLocation(existing)
    && tokA.some((t) => tokB.includes(t)) && meters(draft, existing) <= 50) {
    reasons.push('nearby');
  }
  return reasons;
}

/** Up to [limit] clients that look like [draft], identical ones first. */
function findMatches(draft, clients, limit = 5) {
  const phoneCount = new Map();
  for (const c of clients) {
    for (const p of new Set([phoneKey(c.phone), phoneKey(c.mobile)])) {
      if (p) phoneCount.set(p, (phoneCount.get(p) || 0) + 1);
    }
  }
  const crowded = new Set([...phoneCount].filter(([, n]) => n > 3).map(([p]) => p));
  const strong = new Set(['sameVat', 'sameCompanyId', 'sameName']);
  return clients
    .map((c) => ({ client: c, reasons: duplicateReasons(draft, c, crowded) }))
    .filter((m) => m.reasons.length > 0)
    .sort((a, b) => Number(b.reasons.some((r) => strong.has(r))) - Number(a.reasons.some((r) => strong.has(r))))
    .slice(0, limit);
}

module.exports = { nameTokens, compactName, phoneKey, similarNames, duplicateReasons, findMatches };
