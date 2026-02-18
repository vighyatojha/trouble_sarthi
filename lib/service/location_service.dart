// lib/services/location_service.dart

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/location_model.dart';

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  final _uuid = const Uuid();

  // ── Permission ─────────────────────────────────────────────────────────────

  /// Returns true when location access is granted.
  Future<bool> ensurePermission() async {
    // Check if service is enabled at OS level
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('LocationService: GPS disabled on device.');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      debugPrint('LocationService: permission denied.');
      return false;
    }

    return true;
  }

  // ── Get current GPS position ───────────────────────────────────────────────

  Future<Position?> currentPosition() async {
    if (!await ensurePermission()) return null;
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      debugPrint('LocationService.currentPosition error: $e');
      // fallback to last known
      return Geolocator.getLastKnownPosition();
    }
  }

  // ── Reverse geocode a LatLng → LocationModel ───────────────────────────────

  Future<LocationModel> reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;

        final street = [
          p.subThoroughfare ?? '',
          p.thoroughfare ?? '',
        ].where((s) => s.isNotEmpty).join(' ').trim();

        return LocationModel(
          id: _uuid.v4(),
          latitude: lat,
          longitude: lng,
          streetAddress: street,
          subLocality: p.subLocality ?? '',
          city: p.locality ?? '',
          state: p.administrativeArea ?? '',
          postalCode: p.postalCode ?? '',
          country: p.country ?? '',
          savedAt: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('LocationService.reverseGeocode error: $e');
    }

    // Return a stub if geocoding fails
    return LocationModel(
      id: _uuid.v4(),
      latitude: lat,
      longitude: lng,
      streetAddress: '',
      subLocality: '',
      city: '',
      state: '',
      postalCode: '',
      country: '',
      savedAt: DateTime.now(),
    );
  }

  /// Full pipeline: GPS → reverse geocode → LocationModel
  Future<LocationModel?> currentLocationModel() async {
    final pos = await currentPosition();
    if (pos == null) return null;
    return reverseGeocode(pos.latitude, pos.longitude);
  }

  LatLng toLatLng(Position pos) => LatLng(pos.latitude, pos.longitude);
}