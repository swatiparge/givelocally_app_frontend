// lib/services/storage_service.dart
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<FirebaseStorage> _storagesToTry() {
    final app = Firebase.app();
    final projectId = app.options.projectId;
    final fromOptions = app.options.storageBucket;

    final raw = <String>[
      // Current runtime bucket.
      _storage.bucket,

      // FirebaseOptions bucket.
      if (fromOptions != null && fromOptions.trim().isNotEmpty)
        fromOptions.trim(),

      // Common defaults.
      if (projectId.isNotEmpty) '$projectId.appspot.com',
      if (projectId.isNotEmpty) '$projectId.firebasestorage.app',
    ];

    final seen = <String>{};
    final buckets = <String>[];
    for (final r in raw) {
      final v = r.trim();
      if (v.isEmpty) continue;
      final gs = v.startsWith('gs://') ? v : 'gs://$v';
      if (seen.add(gs)) buckets.add(gs);
    }

    return buckets
        .map((b) => FirebaseStorage.instanceFor(app: app, bucket: b))
        .toList();
  }

  Future<String> _uploadAndGetUrl({
    required FirebaseStorage storage,
    required File file,
    required String filePath,
  }) async {
    final ref = storage.ref().child(filePath);
    final snapshot = await ref.putFile(file);
    return await snapshot.ref.getDownloadURL();
  }

  // Compresses and uploads an image, then returns the download URL
  Future<String> uploadImage(File imageFile, String donationId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User not logged in");

      final app = Firebase.app();
      debugPrint(
        'STORAGE_DEBUG: projectId=${app.options.projectId} optionsBucket=${app.options.storageBucket} runtimeBucket=${_storage.bucket}',
      );
      debugPrint(
        'STORAGE_DEBUG: bucketCandidates=${_storagesToTry().map((s) => s.bucket).toList()}',
      );

      // 1. Compress the image before uploading (as per AGENTS.md 1.5.4)
      File compressedFile = await _compressImage(imageFile);

      // 2. Define the storage path
      String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      String filePath = 'donations/${user.uid}/$donationId/$fileName';

      FirebaseException? last;
      for (final storage in _storagesToTry()) {
        try {
          debugPrint(
            'STORAGE_DEBUG: uploadImage trying bucket=${storage.bucket} path=$filePath',
          );
          final url = await _uploadAndGetUrl(
            storage: storage,
            file: compressedFile,
            filePath: filePath,
          );
          debugPrint(
            'STORAGE_DEBUG: uploadImage success bucket=${storage.bucket}',
          );
          return url;
        } on FirebaseException catch (e) {
          last = e;
          debugPrint(
            'STORAGE_DEBUG: uploadImage failed bucket=${storage.bucket} code=${e.code} message=${e.message}',
          );
          // For bucket/config problems, keep trying other buckets.
          if (e.code == 'object-not-found' ||
              e.code == 'unknown' ||
              e.code == 'canceled') {
            continue;
          }
          rethrow;
        }
      }

      throw Exception(
        'Storage upload failed (${last?.code ?? 'object-not-found'}). '
        'If this is a new Firebase project, open Firebase Console -> Storage -> Get started to create the bucket.',
      );
    } catch (e) {
      debugPrint('STORAGE_DEBUG: uploadImage exception=$e');
      rethrow;
    }
  }

  // Uploads a file as-is (no compression). Useful for documents.
  Future<String> uploadFile(File file, String donationId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User not logged in");

      final ext = file.path.contains('.')
          ? file.path.split('.').last.toLowerCase()
          : 'bin';
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final filePath = 'donations/${user.uid}/$donationId/$fileName';

      FirebaseException? last;
      for (final storage in _storagesToTry()) {
        try {
          debugPrint(
            'STORAGE_DEBUG: uploadFile trying bucket=${storage.bucket} path=$filePath',
          );
          final url = await _uploadAndGetUrl(
            storage: storage,
            file: file,
            filePath: filePath,
          );
          debugPrint(
            'STORAGE_DEBUG: uploadFile success bucket=${storage.bucket}',
          );
          return url;
        } on FirebaseException catch (e) {
          last = e;
          debugPrint(
            'STORAGE_DEBUG: uploadFile failed bucket=${storage.bucket} code=${e.code} message=${e.message}',
          );
          if (e.code == 'object-not-found' ||
              e.code == 'unknown' ||
              e.code == 'canceled') {
            continue;
          }
          rethrow;
        }
      }

      throw Exception(
        'Storage upload failed (${last?.code ?? 'object-not-found'}). '
        'If this is a new Firebase project, open Firebase Console -> Storage -> Get started to create the bucket.',
      );
    } catch (e) {
      debugPrint('STORAGE_DEBUG: uploadFile exception=$e');
      rethrow;
    }
  }

  // Helper function for image compression
  Future<File> _compressImage(File file) async {
    final tempDir = await getTemporaryDirectory();
    final path = tempDir.path;
    String targetPath =
        '$path/${DateTime.now().millisecondsSinceEpoch}-compressed.jpg';

    // Read the image file
    img.Image? image = img.decodeImage(await file.readAsBytes());
    if (image == null) return file;

    // Resize and encode as JPEG with quality 80 (~200KB target)
    img.Image resizedImage = img.copyResize(image, width: 1024);
    File compressedFile = File(targetPath)
      ..writeAsBytesSync(img.encodeJpg(resizedImage, quality: 80));

    return compressedFile;
  }
}
