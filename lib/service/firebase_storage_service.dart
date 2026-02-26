// lib/service/firebase_storage_service.dart
//
// Uploads profile photos to Firebase Storage under:
//   profile_photos/{uid}/profile.jpg
//
// Required packages in pubspec.yaml:
//   firebase_storage: ^12.3.0

import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseStorageService {
  FirebaseStorageService._();
  static final instance = FirebaseStorageService._();

  final _storage = FirebaseStorage.instance;

  // ── Upload profile photo ──────────────────────────────────────────────────
  // Returns the public download URL on success, null on failure.
  // onProgress callback receives 0.0 → 1.0 as the upload proceeds.
  Future<String?> uploadProfilePhoto({
    required String uid,
    required File file,
    void Function(double progress)? onProgress,
  }) async {
    try {
      // Always overwrite the same path so old photos are replaced automatically
      final ref = _storage
          .ref()
          .child('profile_photos')
          .child(uid)
          .child('profile.jpg');

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uid': uid,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      final task = ref.putFile(file, metadata);

      // Listen for progress updates
      if (onProgress != null) {
        task.snapshotEvents.listen((snap) {
          if (snap.totalBytes > 0) {
            onProgress(snap.bytesTransferred / snap.totalBytes);
          }
        });
      }

      // Wait for upload to finish
      final snapshot = await task;

      // Return the public HTTPS download URL
      final url = await snapshot.ref.getDownloadURL();
      return url;
    } on FirebaseException catch (e) {
      // Log the full Firebase error so it's visible in debug console
      // ignore: avoid_print
      print('[FirebaseStorageService] upload failed: ${e.code} — ${e.message}');
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('[FirebaseStorageService] unexpected error: $e');
      return null;
    }
  }

  // ── Delete profile photo (e.g. on account deletion) ───────────────────────
  Future<void> deleteProfilePhoto(String uid) async {
    try {
      await _storage
          .ref()
          .child('profile_photos')
          .child(uid)
          .child('profile.jpg')
          .delete();
    } catch (_) {
      // File may not exist — ignore
    }
  }
}