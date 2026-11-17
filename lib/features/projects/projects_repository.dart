import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/saving.dart';
import 'project.dart';

CollectionReference<Map<String, dynamic>> get _projects => FirebaseFirestore.instance.collection('projects');

String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

/// Every project, newest first. The sales team, SM and GM (rules); nobody
/// else listens.
final projectsProvider = StreamProvider<List<Project>>((ref) {
  final uid = ref.watch(currentUserProvider.select((u) => canUseProjects(u.value) ? u.value!.id : null));
  if (uid == null) return Stream.value(const []);
  return _projects.snapshots().map((s) {
    final list = s.docs.map(Project.fromDoc).toList();
    list.sort((a, b) => (b.createdAt ?? DateTime(3000)).compareTo(a.createdAt ?? DateTime(3000)));
    return list;
  });
});

final projectProvider = Provider.family<Project?, String>((ref, id) {
  for (final p in ref.watch(projectsProvider).value ?? const <Project>[]) {
    if (p.id == id) return p;
  }
  return null;
});

/// The projects a client is linked to.
final clientProjectsProvider = Provider.family<List<Project>, String>((ref, clientId) => [
      for (final p in ref.watch(projectsProvider).value ?? const <Project>[])
        if (p.clientIds.contains(clientId)) p,
    ]);

/// Project filter shared by the client list and map: clients linked to any
/// of these projects; empty = no project filter.
final projectFilterProvider = NotifierProvider<ProjectIdFilter, Set<String>>(ProjectIdFilter.new);

class ProjectIdFilter extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void toggle(String id) => state = state.contains(id) ? ({...state}..remove(id)) : {...state, id};

  void clear() => state = const {};
}

/// Clients linked to a project in any of these stages; empty = any.
final projectStageFilterProvider = NotifierProvider<ProjectStageFilter, Set<ProjectStage>>(ProjectStageFilter.new);

class ProjectStageFilter extends Notifier<Set<ProjectStage>> {
  @override
  Set<ProjectStage> build() => const {};

  void toggle(ProjectStage s) => state = state.contains(s) ? ({...state}..remove(s)) : {...state, s};

  void clear() => state = const {};
}

/// Adds ([id] null; the signed-in user becomes the lead) or updates the
/// project's details; returns its id.
Future<String> saveProject({
  String? id,
  required String name,
  required List<ProjectParty> parties,
  required double? lat,
  required double? lng,
  required String address,
  required String notes,
  required List<String> clientIds,
  required Map<String, String> clientNames,
}) =>
    saving(() async {
      final contractor = mainContractorName(parties);
      if (name.trim().isEmpty || contractor.isEmpty) throw ArgumentError('A project needs a name and a contractor');
      final ref = id == null ? _projects.doc() : _projects.doc(id);
      final details = {
        'name': name.trim(),
        'contractor': contractor,
        'parties': [for (final p in parties) if (p.name.trim().isNotEmpty) p.toMap()],
        'lat': lat,
        'lng': lng,
        'address': address.trim(),
        'notes': notes.trim(),
        'clientIds': clientIds,
        'clientNames': {for (final c in clientIds) c: clientNames[c] ?? ''},
        'updatedBy': _uid,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (id == null) {
        await ref.set({
          ...details,
          'leadId': _uid,
          'leadLog': <Object>[],
          'stage': ProjectStage.initiated.name,
          'stageLog': [
            {'stage': ProjectStage.initiated.name, 'byId': _uid, 'at': Timestamp.now(), 'note': ''},
          ],
          'materials': <Object>[],
          'samples': <Object>[],
          'createdBy': _uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await ref.update(details);
      }
      return ref.id;
    });

Map<String, Object> _touched() => {'updatedBy': _uid, 'updatedAt': FieldValue.serverTimestamp()};

Future<void> setProjectStage(Project p, ProjectStage stage, {String note = ''}) => saving(() => _projects.doc(p.id).update({
      'stage': stage.name,
      'stageLog': FieldValue.arrayUnion([
        {'stage': stage.name, 'byId': _uid, 'at': Timestamp.now(), 'note': note.trim()},
      ]),
      ..._touched(),
    }));

/// SM / GM only (rules).
Future<void> setProjectLead(Project p, String leadId) => saving(() => _projects.doc(p.id).update({
      'leadId': leadId,
      'leadLog': FieldValue.arrayUnion([
        {'fromId': p.leadId, 'toId': leadId, 'byId': _uid, 'at': Timestamp.now()},
      ]),
      ..._touched(),
    }));

Future<void> saveProjectMaterials(Project p, List<ProjectMaterial> materials) => saving(() => _projects.doc(p.id).update({
      'materials': [for (final m in materials) m.toMap()],
      ..._touched(),
    }));

Future<void> addProjectMaterial(Project p, String decor, MaterialStatus status, {String productId = '', String note = ''}) {
  final now = DateTime.now();
  final m = ProjectMaterial(
      id: '${now.millisecondsSinceEpoch}', materialId: decor, productId: productId, status: status, note: note.trim(), byId: _uid, at: now);
  return saveProjectMaterials(p, [...p.materials, m]);
}

/// Records samples; an initiated project moves to "samples submitted"
/// ([stageAfterSample]). Returns the new stage when it changed.
Future<ProjectStage?> addProjectSample(Project p,
        {required String materialId, String productId = '', required String day, required int qty, String note = ''}) =>
    saving(() async {
      final now = DateTime.now();
      final s = ProjectSample(
          id: '${now.millisecondsSinceEpoch}', materialId: materialId, productId: productId, day: day, qty: qty, note: note.trim(), byId: _uid, at: now);
      final next = stageAfterSample(p.stage);
      await _projects.doc(p.id).update({
        'samples': FieldValue.arrayUnion([s.toMap()]),
        if (next != p.stage) ...{
          'stage': next.name,
          'stageLog': FieldValue.arrayUnion([
            {'stage': next.name, 'byId': _uid, 'at': Timestamp.now(), 'note': ''},
          ]),
        },
        ..._touched(),
      });
      return next != p.stage ? next : null;
    });

Future<void> deleteProjectSample(Project p, String sampleId) => saving(() => _projects.doc(p.id).update({
      'samples': [
        for (final s in p.samples)
          if (s.id != sampleId) s.toMap(),
      ],
      ..._touched(),
    }));

/// SM / GM only (rules).
Future<void> deleteProject(String id) => saving(() => _projects.doc(id).delete());
