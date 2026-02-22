import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/location_model.dart';
import 'location_service.dart';
import 'firestore_service.dart';

class LocationController extends ChangeNotifier {
  final _locSvc = LocationService.instance;
  final _dbSvc  = FirestoreService.instance;

  LocationModel? _resolvedLocation;
  bool    _isGeocoding  = false;
  bool    _isSaving     = false;
  String? _errorMessage;
  LatLng  _mapCenter    = const LatLng(20.5937, 78.9629);
  String  _selectedLabel = 'other';

  bool    get isLoading     => _isGeocoding;
  bool    get isSaving      => _isSaving;
  String? get errorMessage  => _errorMessage;
  String  get selectedLabel => _selectedLabel;

  String get displayAddress =>
      _isGeocoding
          ? 'Locating…'
          : (_resolvedLocation?.primaryLine ?? 'Tap map to pick location');

  String get displaySubAddress =>
      _isGeocoding ? '' : (_resolvedLocation?.secondaryLine ?? '');

  LocationModel? get selectedLocation => _resolvedLocation;
  LocationModel? get currentLocation  => _resolvedLocation;

  // ── Get current Firebase uid safely ──────────────────────────────────────

  String get _currentUserId {
    return FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
  }

  // ── Initialize ────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    _setGeocoding(true);
    try {
      final model = await _locSvc.currentLocationModel();
      if (model != null) {
        _resolvedLocation = model;
        _mapCenter = LatLng(model.latitude, model.longitude);
        _errorMessage = null;
      } else {
        _errorMessage = 'Could not get location. Check permissions.';
      }
    } catch (e) {
      _errorMessage = 'Location error: $e';
    } finally {
      _setGeocoding(false);
    }
  }

  Future<void> onCameraIdle(LatLng center) async {
    _mapCenter = center;
    _setGeocoding(true);
    try {
      final model = await _locSvc.reverseGeocode(
          center.latitude, center.longitude);
      _resolvedLocation = model;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Could not resolve address.';
    } finally {
      _setGeocoding(false);
    }
  }

  Future<void> fetchCurrentLocation() async {
    _setGeocoding(true);
    try {
      final model = await _locSvc.currentLocationModel();
      if (model != null) {
        _resolvedLocation = model;
        _mapCenter = LatLng(model.latitude, model.longitude);
        _errorMessage = null;
      } else {
        _errorMessage = 'Could not fetch current location.';
      }
    } catch (e) {
      _errorMessage = 'GPS error: $e';
    } finally {
      _setGeocoding(false);
    }
  }

  void selectLabel(String label) {
    _selectedLabel = label;
    notifyListeners();
  }

  // ── confirmLocation: always uses real Firebase uid ────────────────────────

  Future<bool> confirmLocation() async {
    if (_resolvedLocation == null) return false;

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    final uid = _currentUserId;

    try {
      final locationToSave = _resolvedLocation!.copyWith(label: _selectedLabel);

      final ok = await _dbSvc.saveActiveLocation(
        userId: uid,
        location: locationToSave,
      );

      if (_selectedLabel != 'other') {
        await _dbSvc.savePinnedPlace(
          userId: uid,
          location: locationToSave,
        );
      }

      if (!ok) _errorMessage = 'Save failed. Check your connection.';
      return ok;
    } on FirebaseException catch (e) {
      _errorMessage = 'Firebase error: ${e.message}';
      return false;
    } catch (e) {
      _errorMessage = 'Save error: $e';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void _setGeocoding(bool v) {
    _isGeocoding = v;
    notifyListeners();
  }
}