// Plus Codes in Google Maps place links that carry no coordinates. Same logic
// as lib/features/import/plus_code.dart — keep both in sync.

const ALPHABET = '23456789CFGHJMPQRVWX';
const C = '[23456789CFGHJMPQRVWX]';
const FULL = new RegExp(`(?<![0-9A-Z])(${C}{8})\\+(${C}{2,3})(?![0-9A-Z])`);
const SHORT = new RegExp(`(?<![0-9A-Z+])(${C}{4})\\+(${C}{2,3})(?![0-9A-Z])`);

const CITIES = [
  [['riyadh', 'الرياض'], 24.7136, 46.6753],
  [['jeddah', 'jiddah', 'جده'], 21.5433, 39.1728],
  [['makkah', 'mecca', 'مكه'], 21.3891, 39.8579],
  [['madinah', 'medina', 'المدينه المنوره'], 24.5247, 39.5692],
  [['dammam', 'الدمام'], 26.4207, 50.0888],
  [['khobar', 'الخبر'], 26.2172, 50.1971],
  [['dhahran', 'الظهران'], 26.2361, 50.0393],
  [['jubail', 'الجبيل'], 27.0174, 49.6225],
  [['qatif', 'القطيف'], 26.5196, 50.0115],
  [['hofuf', 'ahsa', 'hasa', 'الهفوف', 'الاحساء'], 25.3830, 49.5866],
  [['buraidah', 'buraydah', 'بريده'], 26.3260, 43.9750],
  [['unaizah', 'unayzah', 'عنيزه'], 26.0840, 43.9940],
  [['taif', 'الطايف', 'الطائف'], 21.2703, 40.4158],
  [['abha', 'ابها'], 18.2164, 42.5053],
  [['khamis mushait', 'خميس مشيط'], 18.3000, 42.7333],
  [['tabuk', 'تبوك'], 28.3838, 36.5550],
  [['hail', 'حائل', 'حايل'], 27.5114, 41.6900],
  [['jazan', 'jizan', 'جازان'], 16.8892, 42.5511],
  [['najran', 'نجران'], 17.5650, 44.2289],
  [['yanbu', 'ينبع'], 24.0895, 38.0618],
  [['kharj', 'الخرج'], 24.1556, 47.3346],
  [['hafar al batin', 'حفر الباطن'], 28.4328, 45.9708],
  [['arar', 'عرعر'], 30.9753, 41.0381],
  [['sakaka', 'سكاكا'], 29.9697, 40.2064],
  [['baha', 'الباحه'], 20.0129, 41.4677],
];

const normalize = (s) => s.toLowerCase().replace(/[أإآ]/g, 'ا').replace(/ة/g, 'ه').replace(/ى/g, 'ي');
const escape = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

function cityReference(text) {
  const s = normalize(text);
  let best = null;
  let at = -1;
  for (const [names, lat, lng] of CITIES) {
    for (const name of names) {
      const word = new RegExp(`(?<![a-z\\u0621-\\u064A])${escape(normalize(name))}(?![a-z\\u0621-\\u064A])`, 'g');
      for (const m of s.matchAll(word)) {
        if (m.index > at) { at = m.index; best = [lat, lng]; }
      }
    }
  }
  return best;
}

function decode(code) {
  const d = code.replace('+', '');
  let lat = 0; let lng = 0; let res = 20;
  for (let i = 0; i < 10 && i + 1 < d.length; i += 2) {
    lat += ALPHABET.indexOf(d[i]) * res;
    lng += ALPHABET.indexOf(d[i + 1]) * res;
    res /= 20;
  }
  let latSize = res * 20; let lngSize = res * 20;
  for (let i = 10; i < d.length; i++) {
    latSize /= 5; lngSize /= 4;
    const x = ALPHABET.indexOf(d[i]);
    lat += Math.floor(x / 4) * latSize;
    lng += (x % 4) * lngSize;
  }
  return [lat - 90 + latSize / 2, lng - 180 + lngSize / 2];
}

function prefix(lat, lng) {
  let a = lat + 90; let b = lng + 180; let res = 20; let out = '';
  for (let i = 0; i < 2; i++) {
    out += ALPHABET[Math.min(19, Math.floor(a / res))] + ALPHABET[Math.min(19, Math.floor(b / res))];
    a %= res; b %= res; res /= 20;
  }
  return out;
}

function recover(short, refLat, refLng) {
  let [lat, lng] = decode(prefix(refLat, refLng) + short);
  if (lat - refLat > 0.5) lat -= 1;
  if (refLat - lat > 0.5) lat += 1;
  if (lng - refLng > 0.5) lng -= 1;
  if (refLng - lng > 0.5) lng += 1;
  return [lat, lng];
}

/** {lat, lng} from a Plus Code in [text] (decoded URL or address), or null. */
function coordsFromPlusCode(text) {
  const upper = text.toUpperCase();
  const full = upper.match(FULL);
  if (full) {
    const [lat, lng] = decode(`${full[1]}+${full[2]}`);
    return { lat, lng };
  }
  const short = SHORT.exec(upper);
  if (!short) return null;
  const rest = text.slice(short.index + short[0].length).split(/[/?&]/)[0];
  const ref = cityReference(rest);
  if (!ref) return null;
  const [lat, lng] = recover(`${short[1]}+${short[2]}`, ref[0], ref[1]);
  return { lat, lng };
}

module.exports = { coordsFromPlusCode, cityReference };
