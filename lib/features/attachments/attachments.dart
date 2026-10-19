import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'image_shrink.dart';
import '../../core/saving.dart';

/// Max upload size, same limit as `storage.rules`.
const maxAttachmentBytes = 20 * 1024 * 1024;

/// Photos and files belong to a client, a visit or a leave request (e.g. a
/// hospital report).
enum AttachmentParent {
  clients('clients'),
  visits('visits'),
  leaveRequests('leave_requests');

  const AttachmentParent(this.collection);

  /// Firestore collection and Storage folder.
  final String collection;
}

/// A key for one parent's attachments: (parent, doc id).
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
    this.thumbPath = '',
    this.thumbUrl = '',
    this.docType = '',
  });

  final String id;
  final String storagePath;
  final String url;
  final String fileName;
  final String contentType;
  final int size;
  final String uploadedBy;
  final DateTime? createdAt;

  /// Small JPEG for photo grids ('' for files and older photos).
  final String thumbPath;
  final String thumbUrl;

  /// Client documents: 'cr' | 'vat' | 'nationalAddress' ('' = other file).
  final String docType;

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
      thumbPath: d['thumbPath'] as String? ?? '',
      thumbUrl: d['thumbUrl'] as String? ?? '',
      docType: d['docType'] as String? ?? '',
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
    .collection(owner.parent.collection)
    .doc(owner.id)
    .collection('attachments');

final attachmentsProvider = StreamProvider.family<List<Attachment>, AttachmentOwner>((ref, owner) =>
    _collection(owner).orderBy('createdAt', descending: true).snapshots().map(
          (s) => s.docs.map(Attachment.fromDoc).toList(),
        ));

final attachmentsRepositoryProvider = Provider((ref) => AttachmentsRepository());

/// Files in Storage at `{collection}/{id}/{file}`, listed in Firestore
/// `{collection}/{id}/attachments`.
class AttachmentsRepository {
  final _storage = FirebaseStorage.instance;

  /// Photos are scaled down (max 1600 px, JPEG) and get a small thumbnail
  /// next to them (`…_thumb.jpg`). [docType]: a client document ('cr', …).
  Future<void> upload(AttachmentOwner owner, PendingFile file, String userId, {String docType = ''}) => saving(() async {
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
    final path = '${owner.parent.collection}/${owner.id}/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    final ref = _storage.ref(path);
    await ref.putData(bytes, SettableMetadata(contentType: contentType, cacheControl: 'public, max-age=31536000'));
    String? thumbPath, thumbUrl;
    if (shrunk != null) {
      try {
        thumbPath = '${path}_thumb.jpg';
        final thumbRef = _storage.ref(thumbPath);
        await thumbRef.putData(shrunk.thumb, SettableMetadata(contentType: 'image/jpeg', cacheControl: 'public, max-age=31536000'));
        thumbUrl = await thumbRef.getDownloadURL();
      } catch (_) {
        // The grid then shows the full photo.
        thumbPath = null;
      }
    }
    await _collection(owner).add({
      'storagePath': path,
      'url': await ref.getDownloadURL(),
      'fileName': name,
      'contentType': contentType,
      'size': bytes.length,
      'uploadedBy': userId,
      'createdAt': FieldValue.serverTimestamp(),
      'thumbPath': ?thumbPath,
      'thumbUrl': ?thumbUrl,
      if (docType.isNotEmpty) 'docType': docType,
    });
  });

  Future<void> delete(AttachmentOwner owner, Attachment attachment) => saving(() async {
    try {
      await _storage.ref(attachment.storagePath).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
    if (attachment.thumbPath.isNotEmpty) {
      try {
        await _storage.ref(attachment.thumbPath).delete();
      } on FirebaseException catch (_) {
        // A missing thumbnail doesn't stop the delete.
      }
    }
    await _collection(owner).doc(attachment.id).delete();
  });
}
