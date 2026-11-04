import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/app_user.dart';
import '../../core/search_text.dart';

// Company documents (user request 2026-11-01): the company's own files in a
// tree — Official (CR, VAT, National Address … per company of the group),
// Expiring (Moqeem, employee insurance … with an expiry date and reminders)
// and Product (profile, datasheets, certificates). The sales team (sales
// execs, KAMs) views and shares Official and Product items not marked
// "Management only"; the GM and sales manager edit everything; HR views
// everything and edits the Expiring section (renewals). Firestore
// `company_docs/{id}` holds folders and files alike; `restricted` = the
// item or a folder above it is management only (always true in Expiring),
// stored on every item so the rules can check it.
//
// 2026-11-03 (user): Expiring is shown as "Services that expire" (health
// insurance, …; key stays 'expiring'); a health insurance service is synced
// to every employee (`employee_records`, class per person). New section
// Subscriptions: website logins (URL, how to log in, user name, password)
// with an expiry. Both can hold items without a file (`hasFile`), are
// management only (GM / SM / HR) and HR edits them.

enum DocSection {
  official,
  expiring,
  subscription,
  product;

  /// Shown to the sales team (unless management only).
  bool get salesVisible => this == official || this == product;

  /// Items carry an expiry date (required) and are reminded.
  bool get expires => this == expiring || this == subscription;
}

/// A service that is health insurance (`serviceType`).
const healthInsuranceService = 'healthInsurance';

/// Sections [role] may open, in order.
List<DocSection> docSectionsFor(UserRole role) => [
      if (role.seesCompanyDocs)
        for (final s in DocSection.values)
          if (s.salesVisible || role.seesAllCompanyDocs) s,
    ];

/// [role] may add, change and delete items in [section].
bool canEditDocSection(UserRole role, DocSection section) =>
    role.isAdmin || (role == UserRole.hr && section.expires);

/// Shown as "due soon" (reminded, and on Home until renewed) this many days
/// before the expiry: App settings `docRenewalDays` (default 30), set by
/// `AppSettings.apply`.
var docDueSoonDays = 30;

enum DocExpiryState { none, ok, dueSoon, expired }

/// 'yyyy-MM-dd' of a date.
String docDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Whole days from [today] to [expiry]; negative once past.
int docDaysLeft(String expiry, DateTime today) {
  final e = DateTime.tryParse(expiry);
  if (e == null) return 0;
  return DateTime.utc(e.year, e.month, e.day).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
}

DocExpiryState docExpiryState(String expiry, DateTime today) {
  if (DateTime.tryParse(expiry) == null) return DocExpiryState.none;
  final days = docDaysLeft(expiry, today);
  if (days <= 0) return DocExpiryState.expired;
  if (days <= docDueSoonDays) return DocExpiryState.dueSoon;
  return DocExpiryState.ok;
}

/// The expiry offered when renewing: a year after the old one, or a year
/// from today when it ran out over 30 days ago or wasn't set.
String nextDocExpiry(String expiry, DateTime today) {
  final e = DateTime.tryParse(expiry);
  final base = e == null || docDaysLeft(expiry, today) < -30 ? today : e;
  final next = DateTime(base.year + 1, base.month, base.day);
  // 29 Feb → 28 Feb.
  return docDay(next.month == base.month ? next : DateTime(base.year + 1, base.month + 1, 0));
}

/// An earlier file of a document, kept when it was replaced or renewed.
class DocVersion {
  const DocVersion({
    required this.storagePath,
    required this.url,
    required this.fileName,
    this.contentType = '',
    this.size = 0,
    this.expiry = '',
    this.replacedAt,
    this.byId = '',
  });

  final String storagePath;
  final String url;
  final String fileName;
  final String contentType;
  final int size;

  /// The expiry it had ('' = none).
  final String expiry;
  final DateTime? replacedAt;
  final String byId;

  factory DocVersion.fromMap(Map<String, dynamic> m) => DocVersion(
        storagePath: m['storagePath'] as String? ?? '',
        url: m['url'] as String? ?? '',
        fileName: m['fileName'] as String? ?? '',
        contentType: m['contentType'] as String? ?? '',
        size: (m['size'] as num?)?.toInt() ?? 0,
        expiry: m['expiry'] as String? ?? '',
        replacedAt: (m['replacedAt'] as Timestamp?)?.toDate(),
        byId: m['byId'] as String? ?? '',
      );

  Map<String, Object> toMap() => {
        'storagePath': storagePath,
        'url': url,
        'fileName': fileName,
        'contentType': contentType,
        'size': size,
        'expiry': expiry,
        'replacedAt': ?(replacedAt == null ? null : Timestamp.fromDate(replacedAt!)),
        'byId': byId,
      };
}

/// A "Renewed" entry: the new expiry and the one before.
typedef DocRenewal = ({String expiry, String previous, String byId, DateTime? at});

/// A folder or a file of the tree.
class CompanyDoc {
  const CompanyDoc({
    required this.id,
    required this.isFolder,
    required this.section,
    required this.name,
    this.parentId = '',
    this.companyId = '',
    this.ownRestricted = false,
    this.restricted = false,
    this.storagePath = '',
    this.url = '',
    this.fileName = '',
    this.contentType = '',
    this.size = 0,
    this.thumbUrl = '',
    this.thumbPath = '',
    this.docNumber = '',
    this.personId = '',
    this.issueDate = '',
    this.expiry = '',
    this.notes = '',
    this.serviceType = '',
    this.insuranceClass = '',
    this.loginUrl = '',
    this.loginSteps = '',
    this.username = '',
    this.password = '',
    this.versions = const [],
    this.renewals = const [],
    this.createdBy = '',
    this.createdAt,
    this.updatedBy = '',
    this.updatedAt,
  });

  final String id;
  final bool isFolder;
  final DocSection section;
  final String name;

  /// The folder it's in ('' = the section's top, or the company's top).
  final String parentId;

  /// Official documents: the group company they belong to ('' = none).
  final String companyId;

  /// Marked "Management only" itself.
  final bool ownRestricted;

  /// Hidden from the sales team: [ownRestricted], a folder above it is, or
  /// it's in Expiring.
  final bool restricted;

  // Files.
  final String storagePath;
  final String url;
  final String fileName;
  final String contentType;
  final int size;
  final String thumbUrl;
  final String thumbPath;

  /// Document number (CR number, Iqama number, policy number …).
  final String docNumber;

  /// Expiring documents: the employee it belongs to ('' = the company).
  final String personId;
  final String issueDate;

  /// 'yyyy-MM-dd' ('' = doesn't expire).
  final String expiry;
  final String notes;

  /// Services: '' or [healthInsuranceService].
  final String serviceType;

  /// Health insurance: the class most employees have (each person's own
  /// class is in their employee record).
  final String insuranceClass;

  // Subscriptions: where and how to log in (all optional).
  final String loginUrl;
  final String loginSteps;
  final String username;
  final String password;

  /// Earlier files, newest first.
  final List<DocVersion> versions;

  /// "Renewed" entries, oldest first.
  final List<DocRenewal> renewals;
  final String createdBy;
  final DateTime? createdAt;
  final String updatedBy;
  final DateTime? updatedAt;

  bool get isImage => contentType.startsWith('image/');
  bool get isPdf => contentType == 'application/pdf';

  /// A file is attached (services and subscriptions may have none).
  bool get hasFile => !isFolder && url.isNotEmpty;

  bool get isHealthInsurance => !isFolder && section == DocSection.expiring && serviceType == healthInsuranceService;

  DocExpiryState expiryState(DateTime today) =>
      isFolder || !section.expires ? DocExpiryState.none : docExpiryState(expiry, today);

  /// Expired or due soon.
  bool needsRenewal(DateTime today) => expiryState(today).index >= DocExpiryState.dueSoon.index;

  factory CompanyDoc.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return CompanyDoc(
      id: doc.id,
      isFolder: d['kind'] == 'folder',
      section: DocSection.values.asNameMap()[d['section']] ?? DocSection.product,
      name: d['name'] as String? ?? '',
      parentId: d['parentId'] as String? ?? '',
      companyId: d['companyId'] as String? ?? '',
      ownRestricted: d['ownRestricted'] == true,
      restricted: d['restricted'] == true,
      storagePath: d['storagePath'] as String? ?? '',
      url: d['url'] as String? ?? '',
      fileName: d['fileName'] as String? ?? '',
      contentType: d['contentType'] as String? ?? '',
      size: (d['size'] as num?)?.toInt() ?? 0,
      thumbUrl: d['thumbUrl'] as String? ?? '',
      thumbPath: d['thumbPath'] as String? ?? '',
      docNumber: d['docNumber'] as String? ?? '',
      personId: d['personId'] as String? ?? '',
      issueDate: d['issueDate'] as String? ?? '',
      expiry: d['expiry'] as String? ?? '',
      notes: d['notes'] as String? ?? '',
      serviceType: d['serviceType'] as String? ?? '',
      insuranceClass: d['insuranceClass'] as String? ?? '',
      loginUrl: d['loginUrl'] as String? ?? '',
      loginSteps: d['loginSteps'] as String? ?? '',
      username: d['username'] as String? ?? '',
      password: d['password'] as String? ?? '',
      versions: [
        for (final v in d['versions'] as List? ?? const [])
          if (v is Map) DocVersion.fromMap(Map<String, dynamic>.from(v)),
      ],
      renewals: [
        for (final r in d['renewalLog'] as List? ?? const [])
          if (r is Map)
            (
              expiry: r['expiry'] as String? ?? '',
              previous: r['previous'] as String? ?? '',
              byId: r['byId'] as String? ?? '',
              at: (r['at'] as Timestamp?)?.toDate(),
            ),
      ],
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedBy: d['updatedBy'] as String? ?? '',
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Where in the tree a list is: a section, maybe a company (Official) and
/// maybe a folder.
typedef DocPlace = ({DocSection section, String companyId, String folderId});

/// Items directly in [place]: folders first, then files, by name. At the top
/// of Official, items of a company are inside that company's folder.
List<CompanyDoc> docsIn(List<CompanyDoc> all, DocPlace place) {
  final list = [
    for (final d in all)
      if (d.section == place.section &&
          d.parentId == place.folderId &&
          (place.folderId.isNotEmpty || place.section != DocSection.official || d.companyId == place.companyId))
        d,
  ];
  return list..sort(compareDocs);
}

int compareDocs(CompanyDoc a, CompanyDoc b) {
  if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

/// The folders from the top down to [folderId] (included).
List<CompanyDoc> docPath(List<CompanyDoc> all, String folderId) {
  final byId = {for (final d in all) d.id: d};
  final path = <CompanyDoc>[];
  var id = folderId;
  while (id.isNotEmpty && path.length < 50) {
    final d = byId[id];
    if (d == null) break;
    path.insert(0, d);
    id = d.parentId;
  }
  return path;
}

/// Everything inside [folderId], at any depth.
List<CompanyDoc> docDescendants(List<CompanyDoc> all, String folderId) {
  final out = <CompanyDoc>[];
  final queue = [folderId];
  while (queue.isNotEmpty) {
    final id = queue.removeLast();
    for (final d in all) {
      if (d.parentId == id && d.id != folderId && !out.contains(d)) {
        out.add(d);
        if (d.isFolder) queue.add(d.id);
      }
    }
  }
  return out;
}

/// Whether an item placed in [parentId] is hidden from the sales team.
bool docRestrictedUnder(List<CompanyDoc> all, DocSection section, String parentId, bool ownRestricted) =>
    !section.salesVisible || ownRestricted || docPath(all, parentId).any((f) => f.ownRestricted);

/// The new `restricted` and `companyId` of [folder]'s contents after it
/// changed (marked / unmarked management only, or moved): only items whose
/// values change. [folder] is the folder as it is now.
Map<String, ({bool restricted, String companyId})> docSubtreeChanges(List<CompanyDoc> all, CompanyDoc folder) {
  final changes = <String, ({bool restricted, String companyId})>{};
  final restrictedById = <String, bool>{folder.id: folder.restricted};
  // Breadth first, so a parent's value is known before its children.
  final queue = [folder.id];
  while (queue.isNotEmpty) {
    final parentId = queue.removeAt(0);
    for (final d in all) {
      if (d.parentId != parentId || d.id == folder.id) continue;
      final restricted = !d.section.salesVisible || d.ownRestricted || restrictedById[parentId]!;
      restrictedById[d.id] = restricted;
      if (restricted != d.restricted || d.companyId != folder.companyId) {
        changes[d.id] = (restricted: restricted, companyId: folder.companyId);
      }
      if (d.isFolder) queue.add(d.id);
    }
  }
  return changes;
}

/// Folders an item may move into: the same section, not itself or inside
/// itself.
List<CompanyDoc> docMoveTargets(List<CompanyDoc> all, CompanyDoc item) {
  final inside = item.isFolder ? {for (final d in docDescendants(all, item.id)) d.id} : const <String>{};
  return [
    for (final d in all)
      if (d.isFolder && d.section == item.section && d.id != item.id && !inside.contains(d.id)) d,
  ];
}

/// Files matching [query] in name, file name, number, notes or the
/// employee's name ([personNames] by uid); every word must match somewhere.
List<CompanyDoc> searchDocs(List<CompanyDoc> all, String query, Map<String, String> personNames) {
  final words = foldSearch(query).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return const [];
  final out = [
    for (final d in all)
      if (!d.isFolder)
        if (foldSearch([d.name, d.fileName, d.docNumber, d.notes, d.loginUrl, d.insuranceClass, personNames[d.personId] ?? ''].join(' '))
            case final text when words.every(text.contains))
          d,
  ];
  return out..sort(compareDocs);
}
