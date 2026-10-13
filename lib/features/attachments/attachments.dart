import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Max upload size, same limit as `storage.rules`.
const maxAttachmentBytes = 20 * 1024 * 1024;

/// Photos and files belong to a client or a visit.
enum AttachmentParent { clients, visits }

/// A key for one parent's attachments: (`clients` | `visits`, doc id).
typedef AttachmentOwner = ({AttachmentParent parent, String id});

class Attachment {
  const Attachment({
    required this.id,
    required this.storagePath,
    required this.url,
    required this.fileName,
    required this.contentType,
    required this.size,
    required this.uploadedBy,
    required this.createdAt,
  });

  final String id;
  final String storagePath;
  final String url;
  final String fileName;
  final String contentType;
  final int size;
  final String uploadedBy;
  final DateTime? createdAt;

  bool get isImage => contentType.startsWith('image/');

  factory Attachment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Attachment(
      id: doc.id,
      storagePath: d['storagePath'] as String? ?? '',
      url: d['url'] as String? ?? '',
      fileName: d['fileName'] as String? ?? '',
      contentType: d['contentType'] as String? ?? '',
      size: (d['size'] as num?)?.toInt() ?? 0,
      uploadedBy: d['uploadedBy'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// A picked file waiting to be uploaded.
class PendingFile {
  const PendingFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;

  String get contentType => contentTypeOf(name);
}

String contentTypeOf(String fileName) {
  final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
  return switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    'gif' => 'image/gif',
    'pdf' => 'application/pdf',
    'doc' => 'application/msword',
    'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls' => 'application/vnd.ms-excel',
    'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'txt' => 'text/plain',
    _ => 'application/octet-stream',
  };
}

CollectionReference<Map<String, dynamic>> _collection(AttachmentOwner owner) => FirebaseFirestore.instance
    .collection(owner.parent.name)
    .doc(owner.id)
    .collection('attachments');

final attachmentsProvider = StreamProvider.family<List<Attachment>, AttachmentOwner>((ref, owner) =>
    _collection(owner).orderBy('createdAt', descending: true).snapshots().map(
          (s) => s.docs.map(Attachment.fromDoc).toList(),
        ));

final attachmentsRepositoryProvider = Provider((ref) => AttachmentsRepository());

/// Files in Storage at `{clients|visits}/{id}/{file}`, listed in Firestore
/// `{clients|visits}/{id}/attachments`.
class AttachmentsRepository {
  final _storage = FirebaseStorage.instance;

  Future<void> upload(AttachmentOwner owner, PendingFile file, String userId) async {
    final safeName = file.name.replaceAll(RegExp(r'[^\w.\-]+'), '_');
    final path = '${owner.parent.name}/${owner.id}/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    final ref = _storage.ref(path);
    await ref.putData(file.bytes, SettableMetadata(contentType: file.contentType));
    await _collection(owner).add({
      'storagePath': path,
      'url': await ref.getDownloadURL(),
      'fileName': file.name,
      'contentType': file.contentType,
      'size': file.bytes.length,
      'uploadedBy': userId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(AttachmentOwner owner, Attachment attachment) async {
    try {
      await _storage.ref(attachment.storagePath).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
    await _collection(owner).doc(attachment.id).delete();
  }
}
