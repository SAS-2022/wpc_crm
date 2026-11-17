import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/app_user.dart';
import '../../core/search_text.dart';

// Projects (user request 2026-11-17): a building / fit-out project the sales
// team follows, linked to several clients (contractor, designer office,
// showroom …). The sales team, SM and GM add, view and edit every project;
// the person who added it is the project lead, and only the SM / GM change
// the lead. Firestore `projects/{id}`: name, contractor (first contractor's
// name, for the rules and lists), parties [{id, kind contractor|designer|
// consultant, name, contacts [{name, title, phone, email}]}] (2026-11-17,
// user: each company a card with several contacts), lat?, lng?, address,
// notes, clientIds[], clientNames {id: name} (sales execs read
// only their own clients, so names are kept for the others), leadId,
// leadLog [{fromId, toId, byId, at}], stage, stageLog [{stage, byId, at,
// note}], materials [{id, materialId, status, note, byId, at}], samples [{id,
// materialId, qty, day, note, byId, at}], createdBy, createdAt, updatedBy,
// updatedAt. Materials / samples are decors of our collection (imported
// Odoo products, `products/{id}.decor`) + optionally one product (`productId`).

enum ProjectStage { initiated, samplesSubmitted, approved, rejected }

/// A material of our collection on the project: proposed to the client or
/// approved by them.
enum MaterialStatus { proposed, approved }

/// The companies on a project: contracting company, designer office,
/// consultant. A project may have several of each.
enum PartyKind { contractor, designer, consultant }

class PartyContact {
  const PartyContact({required this.name, this.title = '', this.phone = '', this.email = ''});

  final String name;

  /// Job title / role (e.g. Project manager).
  final String title;
  final String phone;
  final String email;

  bool get isEmpty => name.trim().isEmpty && phone.trim().isEmpty && email.trim().isEmpty;

  static PartyContact? fromMap(Object? m) {
    if (m is! Map) return null;
    return PartyContact(
      name: m['name'] as String? ?? '',
      title: m['title'] as String? ?? '',
      phone: m['phone'] as String? ?? '',
      email: m['email'] as String? ?? '',
    );
  }

  Map<String, Object?> toMap() => {'name': name.trim(), 'title': title.trim(), 'phone': phone.trim(), 'email': email.trim()};
}

class ProjectParty {
  const ProjectParty({required this.id, required this.kind, required this.name, this.contacts = const []});

  final String id;
  final PartyKind kind;

  /// Company / office name.
  final String name;
  final List<PartyContact> contacts;

  static ProjectParty? fromMap(Object? m) {
    if (m is! Map) return null;
    final kind = PartyKind.values.asNameMap()['${m['kind']}'];
    if (kind == null) return null;
    return ProjectParty(
      id: m['id'] as String? ?? '${m['name']}',
      kind: kind,
      name: m['name'] as String? ?? '',
      contacts: [
        for (final c in m['contacts'] as List? ?? const [])
          ?PartyContact.fromMap(c),
      ],
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'kind': kind.name,
        'name': name.trim(),
        'contacts': [for (final c in contacts) if (!c.isEmpty) c.toMap()],
      };
}

/// The name kept in `projects.contractor`: the first contractor with a name.
String mainContractorName(List<ProjectParty> parties) {
  for (final p in parties) {
    if (p.kind == PartyKind.contractor && p.name.trim().isNotEmpty) return p.name.trim();
  }
  return '';
}

ProjectStage projectStageOf(Object? v) => ProjectStage.values.asNameMap()['$v'] ?? ProjectStage.initiated;

DateTime? _date(Object? v) => v is Timestamp ? v.toDate() : null;

class ProjectMaterial {
  const ProjectMaterial({
    required this.id,
    required this.materialId,
    this.productId = '',
    this.status = MaterialStatus.proposed,
    this.note = '',
    this.byId = '',
    this.at,
  });

  final String id;

  /// Decor key of our collection (`products.decor`, the Odoo colour code).
  final String materialId;

  /// One product of that decor; '' = the decor in general.
  final String productId;
  final MaterialStatus status;
  final String note;
  final String byId;
  final DateTime? at;

  static ProjectMaterial? fromMap(Object? m) {
    if (m is! Map || m['materialId'] is! String) return null;
    return ProjectMaterial(
      id: m['id'] as String? ?? m['materialId'] as String,
      materialId: m['materialId'] as String,
      productId: m['productId'] as String? ?? '',
      status: MaterialStatus.values.asNameMap()['${m['status']}'] ?? MaterialStatus.proposed,
      note: m['note'] as String? ?? '',
      byId: m['byId'] as String? ?? '',
      at: _date(m['at']),
    );
  }

  ProjectMaterial copyWith({MaterialStatus? status, String? note}) =>
      ProjectMaterial(id: id, materialId: materialId, productId: productId, status: status ?? this.status, note: note ?? this.note, byId: byId, at: at);

  Map<String, Object?> toMap() =>
      {'id': id, 'materialId': materialId, 'productId': productId, 'status': status.name, 'note': note, 'byId': byId, 'at': at};
}

/// Samples handed to the project ([day] 'yyyy-MM-dd', may be backdated).
class ProjectSample {
  const ProjectSample({
    required this.id,
    required this.materialId,
    this.productId = '',
    required this.day,
    this.qty = 1,
    this.note = '',
    this.byId = '',
    this.at,
  });

  final String id;

  /// Decor key; '' with no [productId] = not from the collection (see [note]).
  final String materialId;
  final String productId;
  final String day;
  final int qty;
  final String note;
  final String byId;
  final DateTime? at;

  static ProjectSample? fromMap(Object? m) {
    if (m is! Map || m['day'] is! String) return null;
    return ProjectSample(
      id: m['id'] as String? ?? '${m['day']}',
      materialId: m['materialId'] as String? ?? '',
      productId: m['productId'] as String? ?? '',
      day: m['day'] as String,
      qty: (m['qty'] as num?)?.toInt() ?? 1,
      note: m['note'] as String? ?? '',
      byId: m['byId'] as String? ?? '',
      at: _date(m['at']),
    );
  }

  Map<String, Object?> toMap() =>
      {'id': id, 'materialId': materialId, 'productId': productId, 'day': day, 'qty': qty, 'note': note, 'byId': byId, 'at': at};
}

class StageChange {
  const StageChange({required this.stage, this.byId = '', this.at, this.note = ''});

  final ProjectStage stage;
  final String byId;
  final DateTime? at;
  final String note;

  static StageChange? fromMap(Object? m) {
    if (m is! Map) return null;
    return StageChange(stage: projectStageOf(m['stage']), byId: m['byId'] as String? ?? '', at: _date(m['at']), note: m['note'] as String? ?? '');
  }
}

class LeadChange {
  const LeadChange({required this.fromId, required this.toId, this.byId = '', this.at});

  final String fromId;
  final String toId;
  final String byId;
  final DateTime? at;

  static LeadChange? fromMap(Object? m) {
    if (m is! Map || m['toId'] is! String) return null;
    return LeadChange(fromId: m['fromId'] as String? ?? '', toId: m['toId'] as String, byId: m['byId'] as String? ?? '', at: _date(m['at']));
  }
}

class Project {
  const Project({
    required this.id,
    required this.name,
    this.contractor = '',
    this.parties = const [],
    this.lat,
    this.lng,
    this.address = '',
    this.notes = '',
    this.clientIds = const [],
    this.clientNames = const {},
    this.leadId = '',
    this.leadLog = const [],
    this.stage = ProjectStage.initiated,
    this.stageLog = const [],
    this.materials = const [],
    this.samples = const [],
    this.createdBy = '',
    this.createdAt,
    this.updatedAt,
  });

  factory Project.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) => Project.fromMap(doc.id, doc.data() ?? const {});

  factory Project.fromMap(String id, Map<String, dynamic> d) {
    List<T> list<T>(Object? v, T? Function(Object?) read) => [
          if (v is List)
            for (final m in v)
              if (read(m) case final T x) x,
        ];
    final names = d['clientNames'];
    return Project(
      id: id,
      name: d['name'] as String? ?? '',
      contractor: d['contractor'] as String? ?? '',
      parties: list(d['parties'], ProjectParty.fromMap),
      lat: (d['lat'] as num?)?.toDouble(),
      lng: (d['lng'] as num?)?.toDouble(),
      address: d['address'] as String? ?? '',
      notes: d['notes'] as String? ?? '',
      clientIds: [for (final c in d['clientIds'] as List? ?? const []) '$c'],
      clientNames: names is Map ? {for (final e in names.entries) '${e.key}': '${e.value}'} : const {},
      leadId: d['leadId'] as String? ?? d['createdBy'] as String? ?? '',
      leadLog: list(d['leadLog'], LeadChange.fromMap),
      stage: projectStageOf(d['stage']),
      stageLog: list(d['stageLog'], StageChange.fromMap),
      materials: list(d['materials'], ProjectMaterial.fromMap),
      samples: list(d['samples'], ProjectSample.fromMap),
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: _date(d['createdAt']),
      updatedAt: _date(d['updatedAt']),
    );
  }

  final String id;
  final String name;

  /// The (first) contracting company's name.
  final String contractor;

  /// Contractors, designer offices and consultants with their contacts.
  final List<ProjectParty> parties;

  List<ProjectParty> partiesOf(PartyKind kind) => [for (final p in parties) if (p.kind == kind) p];
  final double? lat;
  final double? lng;
  final String address;
  final String notes;
  final List<String> clientIds;

  /// Names of the linked clients when they were linked.
  final Map<String, String> clientNames;

  /// The project lead: who added it, unless the SM / GM changed it.
  final String leadId;
  final List<LeadChange> leadLog;
  final ProjectStage stage;
  final List<StageChange> stageLog;
  final List<ProjectMaterial> materials;
  final List<ProjectSample> samples;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasLocation => lat != null && lng != null;

  /// Total samples handed over.
  int get sampleCount => samples.fold(0, (n, s) => n + s.qty);

  /// Samples newest first.
  List<ProjectSample> get samplesNewestFirst => [...samples]..sort((a, b) => b.day.compareTo(a.day));
}

/// The sales team, SM and GM add, view and edit projects.
bool canUseProjects(AppUser? me) => me != null && me.active && me.can.isSales;

/// Only the SM / GM hand a project to another lead (and delete projects).
bool canChangeProjectLead(AppUser? me) => me != null && me.active && me.can.isAdmin;

/// The stage once a sample is recorded: an initiated project moves to
/// "samples submitted"; later stages stay.
ProjectStage stageAfterSample(ProjectStage stage) =>
    stage == ProjectStage.initiated ? ProjectStage.samplesSubmitted : stage;

/// Search on name, address, the companies and their contacts, client names
/// and (4+ digits) contact phones.
bool projectMatches(Project p, String query) {
  if (query.trim().isEmpty) return true;
  final contacts = [for (final party in p.parties) ...party.contacts];
  final digits = searchDigits(query);
  return [
    p.name,
    p.contractor,
    p.address,
    for (final party in p.parties) party.name,
    for (final c in contacts) c.name,
    ...p.clientNames.values,
  ].any((t) => searchHas(t, query)) ||
      (digits.length >= 4 && contacts.any((c) => searchDigits(c.phone).contains(digits)));
}

/// Clients map / list filter (user request 2026-11-17): a client passes when
/// it's linked to a project in [ids] (empty = any project) whose stage is in
/// [stages] (empty = any stage). No filter = every client.
bool Function(String clientId) projectClientFilter(List<Project> projects, Set<String> ids, Set<ProjectStage> stages) {
  if (ids.isEmpty && stages.isEmpty) return (_) => true;
  final keep = <String>{
    for (final p in projects)
      if ((ids.isEmpty || ids.contains(p.id)) && (stages.isEmpty || stages.contains(p.stage))) ...p.clientIds,
  };
  return keep.contains;
}

/// The projects the filter keeps (for their pins on the map).
List<Project> filteredProjects(List<Project> projects, Set<String> ids, Set<ProjectStage> stages) => [
      for (final p in projects)
        if ((ids.isNotEmpty || stages.isNotEmpty) &&
            (ids.isEmpty || ids.contains(p.id)) &&
            (stages.isEmpty || stages.contains(p.stage)))
          p,
    ];
