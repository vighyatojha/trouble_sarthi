// lib/service/firebase_storage_service.dart
//
// Profile photo uploads. Firebase Storage needs the paid Blaze plan, so photos
// now go to Cloudinary (free plan) under sarthi/profiles/{uid}/.
// The class name is kept so existing screens keep working.

import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/cloudinary.dart';

class FirebaseStorageService {
  FirebaseStorageService._();
  static final instance = FirebaseStorageService._();

  /// Returns the public https URL on success, null on failure.
  Future<String?> uploadProfilePhoto({
    required String uid,
    required File file,
    void Function(double progress)? onProgress,
  }) async {
    try {
      return await Cloudinary.upload(file, folder: 'profiles/$uid', onProgress: onProgress);
    } on CloudinaryException catch (e) {
      debugPrint('[FirebaseStorageService] upload failed: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[FirebaseStorageService] unexpected error: $e');
      return null;
    }
  }

  /// Cloudinary deletes need a signed (server) call. Old photos are left in
  /// place; they are not linked from the profile any more.
  Future<void> deleteProfilePhoto(String uid) async {}
}