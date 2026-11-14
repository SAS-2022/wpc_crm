// Where a self-registration came from (2026-11-12): `noteRegistration`
// saves `users/{uid}.registeredFrom` once, from the app's device details
// plus the caller's IP and user agent seen by the server.

const FIELDS = ['platform', 'app', 'maker', 'model', 'os', 'browser', 'language', 'userAgent'];
const MAX_LEN = 300;

/** First address of an x-forwarded-for header, else [ip]; null when none. */
function callerIp(headers, ip) {
  const fwd = headers?.['x-forwarded-for'];
  const first = (Array.isArray(fwd) ? fwd[0] : fwd)?.split(',')[0]?.trim();
  return first || ip || null;
}

/**
 * The `registeredFrom` map from the app's [data] (strings cut to 300 chars,
 * unknown keys dropped), the request [headers] and [ip]. The server's user
 * agent is kept when the app sent none (phones).
 */
function registrationRecord(data, headers, ip) {
  const out = {};
  for (const f of FIELDS) {
    const v = data?.[f];
    if (typeof v === 'string' && v.trim() !== '') out[f] = v.trim().slice(0, MAX_LEN);
  }
  if (data?.emulator === true) out.emulator = true;
  const agent = headers?.['user-agent'];
  if (!out.userAgent && typeof agent === 'string' && agent !== '') out.userAgent = agent.slice(0, MAX_LEN);
  const addr = callerIp(headers, ip);
  if (addr) out.ip = addr;
  return out;
}

module.exports = { registrationRecord, callerIp };
