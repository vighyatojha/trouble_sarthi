// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/location_model.dart';


class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final _db = FirebaseFirestore.instance;

  // ── References ─────────────────────────────────────────────────────────────

  DocumentReference _userLocationDoc(String userId) =>
      _db.collection('user_locations').doc(userId);

  CollectionReference _savedPlacesCol(String userId) =>
      _db.collection('user_locations').doc(userId).collection('saved_places');

  // ── Active location ────────────────────────────────────────────────────────

  /// Overwrites (merge) the user's current active location.
  Future<bool> saveActiveLocation({
    required String userId,
    required LocationModel location,
  }) async {
    try {
      await _userLocationDoc(userId).set(
        {
          ...location.toFirestore(),
          'userId': userId,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      debugPrint('FirestoreService: active location saved ✓');
      return true;
    } catch (e) {
      debugPrint('FirestoreService.saveActiveLocation error: $e');
      return false;
    }
  }

  /// One-time fetch of the user's active location.
  Future<LocationModel?> fetchActiveLocation(String userId) async {
    try {
      final doc = await _userLocationDoc(userId).get();
      if (!doc.exists) return null;
      return LocationModel.fromFirestore(doc.data() as Map<String, dynamic>);
    } catch (e) {
      debugPrint('FirestoreService.fetchActiveLocation error: $e');
      return null;
    }
  }

  /// Real-time stream — rebuilds UI whenever the active location changes.
  Stream<LocationModel?> activeLocationStream(String userId) {
    return _userLocationDoc(userId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return LocationModel.fromFirestore(snap.data() as Map<String, dynamic>);
    });
  }

  // ── Saved places (Home / Office / Other) ──────────────────────────────────

  /// Saves a named place under the user's saved_places sub-collection.
  Future<bool> savePinnedPlace({
    required String userId,
    required LocationModel location,
  }) async {
    try {
      await _savedPlacesCol(userId).doc(location.label).set(
        {
          ...location.toFirestore(),
          'userId': userId,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      debugPrint('FirestoreService: pinned place (${location.label}) saved ✓');
      return true;
    } catch (e) {
      debugPrint('FirestoreService.savePinnedPlace error: $e');
      return false;
    }
  }

  /// Fetch all saved places for a user.
  Future<List<LocationModel>> fetchSavedPlaces(String userId) async {
    try {
      final snap = await _savedPlacesCol(userId).get();
      return snap.docs
          .map((d) =>
          LocationModel.fromFirestore(d.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('FirestoreService.fetchSavedPlaces error: $e');
      return [];
    }
  }

  /// Delete a named place.
  Future<void> deletePinnedPlace({
    required String userId,
    required String label,
  }) async {
    try {
      await _savedPlacesCol(userId).doc(label).delete();
    } catch (e) {
      debugPrint('FirestoreService.deletePinnedPlace error: $e');
    }
  }
}