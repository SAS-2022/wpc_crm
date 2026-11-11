import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/saving.dart';
import '../attachments/attachments.dart' show PendingFile;
import '../attachments/image_shrink.dart';
import 'company_docs.dart';

/// Max file size, same limit as `storage.rules` (company profiles can be large).
const maxCompanyDocBytes = 50 * 1024 * 1024;

CollectionReference<Map<String, dynamic>> get _docs => FirebaseFirestore.instance.collection('company_docs');

String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

/// Every item the signed-in user may read: the GM / sales manager / HR read
/// all; the sales team only Official and Product items that aren't
/// management only (the query must say so, the rules check it).
final companyDocsProvider = StreamProvider<List<CompanyDoc>>((ref) {
  final me = ref.watch(currentUserProvider.select((u) => u.value?.active == true
      ? (sees: u.value!.can.seesCompanyDocs, all: u.value!.can.seesAllCompanyDocs)
      : null));
  if (me == null || !me.sees) return Stream.value(const []);
  final Query<Map<String, dynamic>> query = me.all
      ? _docs
      : _docs.where('restricted', isEqualTo: false).where('section', whereIn: [
          for (final s in DocSection.values)
            if (s.salesVisible) s.name,
        ]);
  return query.snapshots().map((s) => s.docs.map(CompanyDoc.fromDoc).toList());
});

final companyDocProvider = Provider.family<CompanyDoc?, String>((ref, id) {
  for (final d in ref.watch(companyDocsProvider).value ?? const <CompanyDoc>[]) {
    if (d.id == id) return d;
  }
  return null;
});

typedef _Stored = ({String path, String url, String fileName, String contentType, int size, String? thumbPath, String? thumbUrl});

/// Uploads [file] to `company_docs/{id}/…`; photos are scaled down and get a
/// thumbnail, like attachments.
Future<_Stored> _put(String id, PendingFile file) async {
  final storage = FirebaseStorage.instance;
  var name = file.name;
  var bytes = file.bytes;
  var contentType = file.contentType;
  ShrunkPhoto? shrunk;
  if (const {'image/jpeg', 'image/png', 'image/webp'}.contains(contentType)) {
    try {
      shrunk = await shrinkPhotoAsync(bytes);
    } catch (_) {
      // Unreadable photo: uploaded as it is.
    }
    if (shrunk != null && shrunk.reencoded) {
      bytes = shrunk.photo;
      contentType = 'image/jpeg';
      if (!RegExp(r'\.jpe?g$', caseSensitive: false).hasMatch(name)) name = '${name.replaceAll(RegExp(r'\.\w+$'), '')}.jpg';
    }
  }
  final safeName = name.replaceAll(RegExp(r'[^\w.\-]+'), '_');
  final path = 'company_docs/$id/${DateTime.now().millisecondsSinceEpoch}_$safeName';
  final ref = storage.ref(path);
  await ref.putData(bytes, SettableMetadata(contentType: contentType, contentDisposition: 'inline; filename="$safeName"'));
  String? thumbPath, thumbUrl;
  if (shrunk != null) {
    try {
      thumbPath = '${path}_thumb.jpg';
      final thumbRef = storage.ref(thumbPath);
      await thumbRef.putData(shrunk.thumb, SettableMetadata(contentType: 'image/jpeg'));
      thumbUrl = await thumbRef.getDownloadURL();
    } catch (_) {
      thumbPath = null;
    }
  }
  return (
    path: path,
    url: await ref.getDownloadURL(),
    fileName: name,
    contentType: contentType,
    size: bytes.length,
    thumbPath: thumbPath,
    thumbUrl: thumbUrl,
  );
}

Map<String, Object?> _fileFields(_Stored s) => {
      'storagePath': s.path,
      'url': s.url,
      'fileName': s.fileName,
      'contentType': s.contentType,
      'size': s.size,
      'thumbPath': s.thumbPath ?? '',
      'thumbUrl': s.thumbUrl ?? '',
    };

Future<void> _removeFile(String path) async {
  if (path.isEmpty) return;
  try {
    await FirebaseStorage.instance.ref(path).delete();
  } on FirebaseException catch (_) {
    // Already gone: nothing to do.
  }
}

/// Adds a folder in [place]'s folder (or top).
Future<void> createDocFolder(List<CompanyDoc> all, DocPlace place, {required String name, required bool ownRestricted}) =>
    saving(() => _docs.add({
          'kind': 'folder',
          'section': place.section.name,
          'parentId': place.folderId,
          'companyId': place.companyId,
          'name': name.trim(),
          'ownRestricted': ownRestricted,
          'restricted': docRestrictedUnder(all, place.section, place.folderId, ownRestricted),
          'createdBy': _uid,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedBy': _uid,
          'updatedAt': FieldValue.serverTimestamp(),
        }));

/// The details of a file form.
typedef DocDetails = ({
  String name,
  String companyId,
  String docNumber,
  String personId,
  String issueDate,
  String expiry,
  String notes,
  bool ownRestricted,
  // Services / subscriptions (2026-11-03); '' elsewhere.
  String serviceType,
  String insuranceClass,
  String loginUrl,
  String loginSteps,
  String username,
  String password,
});

/// [details] with only a name (several files uploaded at once).
DocDetails plainDocDetails(String name, String companyId) => (
      name: name,
      companyId: companyId,
      docNumber: '',
      personId: '',
      issueDate: '',
      expiry: '',
      notes: '',
      ownRestricted: false,
      serviceType: '',
      insuranceClass: '',
      loginUrl: '',
      loginSteps: '',
      username: '',
      password: '',
    );

Map<String, Object> _extraFields(DocSection section, DocDetails d) => {
      if (section == DocSection.expiring) ...{
        'serviceType': d.serviceType,
        'insuranceClass': d.serviceType == healthInsuranceService ? d.insuranceClass.trim() : '',
      },
      if (section == DocSection.subscription) ...{
        'loginUrl': d.loginUrl.trim(),
        'loginSteps': d.loginSteps.trim(),
        'username': d.username.trim(),
        'password': d.password,
      },
    };

/// Uploads [file] as a new document in [place] (company: [details], which
/// may name another company at the top of Official). Services and
/// subscriptions may come without a file.
Future<void> uploadCompanyDoc(List<CompanyDoc> all, DocPlace place, PendingFile? file, DocDetails details) => saving(() async {
      final ref = _docs.doc();
      final stored = file == null ? null : await _put(ref.id, file);
      await ref.set({
        'kind': 'file',
        'section': place.section.name,
        'parentId': place.folderId,
        'companyId': place.folderId.isEmpty ? details.companyId : place.companyId,
        'name': details.name.trim().isEmpty ? stored?.fileName ?? '' : details.name.trim(),
        'docNumber': details.docNumber.trim(),
        'personId': details.personId,
        'issueDate': details.issueDate,
        'expiry': details.expiry,
        'notes': details.notes.trim(),
        'ownRestricted': details.ownRestricted,
        'restricted': docRestrictedUnder(all, place.section, place.folderId, details.ownRestricted),
        ..._extraFields(place.section, details),
        if (stored != null) ..._fileFields(stored),
        'versions': <Object>[],
        'createdBy': _uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedBy': _uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

/// Saves a file's details. At the top of Official the company can change.
Future<void> updateCompanyDoc(List<CompanyDoc> all, CompanyDoc doc, DocDetails details) => saving(() => _docs.doc(doc.id).update({
      'name': details.name.trim().isEmpty ? doc.name : details.name.trim(),
      if (doc.parentId.isEmpty) 'companyId': details.companyId,
      'docNumber': details.docNumber.trim(),
      'personId': details.personId,
      'issueDate': details.issueDate,
      'expiry': details.expiry,
      'notes': details.notes.trim(),
      'ownRestricted': details.ownRestricted,
      'restricted': docRestrictedUnder(all, doc.section, doc.parentId, details.ownRestricted),
      ..._extraFields(doc.section, details),
      'updatedBy': _uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }));

/// Renames a folder / marks it management only; its contents follow.
Future<void> updateDocFolder(List<CompanyDoc> all, CompanyDoc folder, {required String name, required bool ownRestricted}) =>
    saving(() async {
      final restricted = docRestrictedUnder(all, folder.section, folder.parentId, ownRestricted);
      final updated = CompanyDoc(
        id: folder.id,
        isFolder: true,
        section: folder.section,
        name: name,
        parentId: folder.parentId,
        companyId: folder.companyId,
        ownRestricted: ownRestricted,
        restricted: restricted,
      );
      final batch = FirebaseFirestore.instance.batch();
      batch.update(_docs.doc(folder.id), {
        'name': name.trim(),
        'ownRestricted': ownRestricted,
        'restricted': restricted,
        'updatedBy': _uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _applySubtree(batch, docSubtreeChanges(all, updated));
      await batch.commit();
    });

void _applySubtree(WriteBatch batch, Map<String, ({bool restricted, String companyId})> changes) {
  for (final e in changes.entries) {
    batch.update(_docs.doc(e.key), {'restricted': e.value.restricted, 'companyId': e.value.companyId});
  }
}

/// Moves [item] into [target] (null = the top of its section; at the top of
/// Official, into company [companyId]).
Future<void> moveCompanyDoc(List<CompanyDoc> all, CompanyDoc item, CompanyDoc? target, String companyId) => saving(() async {
      final parentId = target?.id ?? '';
      final company = target?.companyId ?? companyId;
      final restricted = docRestrictedUnder(all, item.section, parentId, item.ownRestricted);
      final batch = FirebaseFirestore.instance.batch();
      batch.update(_docs.doc(item.id), {
        'parentId': parentId,
        'companyId': company,
        'restricted': restricted,
        'updatedBy': _uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (item.isFolder) {
        final moved = CompanyDoc(
          id: item.id,
          isFolder: true,
          section: item.section,
          name: item.name,
          parentId: parentId,
          companyId: company,
          ownRestricted: item.ownRestricted,
          restricted: restricted,
        );
        _applySubtree(batch, docSubtreeChanges(all, moved));
      }
      await batch.commit();
    });

/// Replaces a document's file (or adds the first one); the old one stays in
/// its history.
Future<void> replaceCompanyDocFile(CompanyDoc doc, PendingFile file) => saving(() async {
      final stored = await _put(doc.id, file);
      await _docs.doc(doc.id).update({
        ..._fileFields(stored),
        if (doc.storagePath.isNotEmpty) 'versions': FieldValue.arrayUnion([_versionOf(doc).toMap()]),
        'updatedBy': _uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _removeFile(doc.thumbPath);
    });

DocVersion _versionOf(CompanyDoc doc) => DocVersion(
      storagePath: doc.storagePath,
      url: doc.url,
      fileName: doc.fileName,
      contentType: doc.contentType,
      size: doc.size,
      expiry: doc.expiry,
      replacedAt: DateTime.now(),
      byId: _uid,
    );

/// Renewed: a new expiry and, when given, the new document file (the old
/// one is kept in the history). Logged in `renewalLog`.
Future<void> renewCompanyDoc(CompanyDoc doc, String expiry, PendingFile? file) => saving(() async {
      final stored = file == null ? null : await _put(doc.id, file);
      await _docs.doc(doc.id).update({
        'expiry': expiry,
        if (stored != null) ..._fileFields(stored),
        if (stored != null && doc.storagePath.isNotEmpty) 'versions': FieldValue.arrayUnion([_versionOf(doc).toMap()]),
        'renewalLog': FieldValue.arrayUnion([
          {'expiry': expiry, 'previous': doc.expiry, 'byId': _uid, 'at': Timestamp.now()},
        ]),
        'updatedBy': _uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (stored != null) await _removeFile(doc.thumbPath);
    });

/// Deletes [item] (a folder with everything in it) and its files.
Future<void> deleteCompanyDoc(List<CompanyDoc> all, CompanyDoc item) => saving(() async {
      final items = [item, if (item.isFolder) ...docDescendants(all, item.id)];
      for (final d in items) {
        await _removeFile(d.storagePath);
        await _removeFile(d.thumbPath);
        for (final v in d.versions) {
          await _removeFile(v.storagePath);
        }
      }
      for (var i = 0; i < items.length; i += 400) {
        final batch = FirebaseFirestore.instance.batch();
        for (final d in items.skip(i).take(400)) {
          batch.delete(_docs.doc(d.id));
        }
        await batch.commit();
      }
    });
