import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseStorageService {
  FirebaseStorageService._();
  static final FirebaseStorageService instance = FirebaseStorageService._();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ── Upload profile photo ──────────────────────────────────────────────────

  /// Uploads [file] to users/{uid}/profile.jpg
  /// Returns the download URL or null on failure
  Future<String?> uploadProfilePhoto({
    required String uid,
    required File file,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final ref = _storage.ref().child('users/$uid/profile.jpg');

      final uploadTask = ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // Listen to progress if callback provided
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((snapshot) {
          final progress =
              snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        });
      }

      await uploadTask;
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } on FirebaseException catch (e) {
      // ignore: avoid_print
      print('[Storage] Upload failed: ${e.code} — ${e.message}');
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('[Storage] Unexpected error: $e');
      return null;
    }
  }

  // ── Delete profile photo ──────────────────────────────────────────────────

  Future<bool> deleteProfilePhoto({required String uid}) async {
    try {
      await _storage.ref().child('users/$uid/profile.jpg').delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Get download URL ──────────────────────────────────────────────────────

  Future<String?> getProfilePhotoUrl({required String uid}) async {
    try {
      return await _storage.ref().child('users/$uid/profile.jpg').getDownloadURL();
    } catch (_) {
      return null;
    }
  }
}