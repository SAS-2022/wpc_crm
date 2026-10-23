/// Sign-in with a username instead of an email (2026-10-23). Firebase Auth
/// needs an email, so a username account gets a hidden one,
/// `<username>@[usernameDomain]`; people only ever type the username. The
/// domain has no mailboxes: such accounts can't get a reset email, an admin
/// sets a new password instead (`setUserPassword` Cloud Function).
/// The `setUserPassword` comment in functions/index.js names the domain too.
const usernameDomain = 'staff.wpc-crm-a9247.web.app';

/// What a username may contain: 3–30 lowercase letters, digits, `.`, `_`
/// or `-`, starting and ending with a letter or digit.
final _username = RegExp(r'^[a-z0-9](?:[a-z0-9._-]{1,28})[a-z0-9]$');

String normalizeUsername(String input) => input.trim().toLowerCase();

bool isValidUsername(String input) {
  final u = normalizeUsername(input);
  return _username.hasMatch(u) && !u.contains('..');
}

/// The Auth email for what was typed on the login screen: an email as it
/// is, a username as its hidden email.
String loginEmailFor(String input) {
  final t = input.trim();
  return t.contains('@') ? t : '${normalizeUsername(t)}@$usernameDomain';
}

/// The username of a hidden email, null for a real email.
String? usernameOf(String email) {
  final e = email.trim().toLowerCase();
  const suffix = '@$usernameDomain';
  return e.endsWith(suffix) ? e.substring(0, e.length - suffix.length) : null;
}

/// What to show for an account: its username, else its email.
String loginNameOf(String email) => usernameOf(email) ?? email;

/// Arabic letters in Latin, for suggesting a username from an Arabic name
/// (no vowels are written, so "محمد" gives "mhmd"; the admin can edit it).
const _arabicLatin = {
  'ا': 'a', 'أ': 'a', 'إ': 'i', 'آ': 'a', 'ب': 'b', 'ت': 't', 'ث': 'th', 'ج': 'j', 'ح': 'h', 'خ': 'kh',
  'د': 'd', 'ذ': 'th', 'ر': 'r', 'ز': 'z', 'س': 's', 'ش': 'sh', 'ص': 's', 'ض': 'd', 'ط': 't', 'ظ': 'z',
  'ع': 'a', 'غ': 'gh', 'ف': 'f', 'ق': 'q', 'ك': 'k', 'ل': 'l', 'م': 'm', 'ن': 'n', 'ه': 'h', 'و': 'w',
  'ي': 'y', 'ى': 'a', 'ة': 'a', 'ئ': 'e', 'ؤ': 'o',
};

/// A free username from a person's name: first and last word joined by a
/// dot ("Ali Hassan Omar" → "ali.omar"), Arabic written in Latin letters,
/// with 2, 3, … added when [taken] has it already. Null when the name gives
/// nothing usable.
String? suggestUsername(String name, Set<String> taken) {
  final words = [
    for (final w in name.toLowerCase().split(RegExp(r'\s+')))
      w.split('').map((c) => _arabicLatin[c] ?? c).join().replaceAll(RegExp(r'[^a-z0-9]'), ''),
  ].where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return null;
  var base = words.length == 1 ? words.first : '${words.first}.${words.last}';
  if (base.length > 27) base = base.substring(0, 27).replaceAll(RegExp(r'\.+$'), '');
  if (base.length < 3) base = base.padRight(3, '0');
  if (!isValidUsername(base)) return null;
  var candidate = base;
  for (var n = 2; taken.contains(candidate); n++) {
    candidate = '$base$n';
  }
  return candidate;
}

/// The usernames already used by these accounts' emails.
Set<String> usernamesOf(Iterable<String> emails) => {for (final e in emails) ?usernameOf(e)};
