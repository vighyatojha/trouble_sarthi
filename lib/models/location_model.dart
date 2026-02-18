// lib/models/location_model.dart

class LocationModel {
  final String id;
  final double latitude;
  final double longitude;
  final String streetAddress;
  final String subLocality;   // e.g. "Kips Bay"
  final String city;          // e.g. "New York"
  final String state;         // e.g. "NY"
  final String postalCode;    // e.g. "10010"
  final String country;       // e.g. "USA"
  final String label;         // "home" | "office" | "other"
  final DateTime savedAt;

  const LocationModel({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.streetAddress,
    required this.subLocality,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.country,
    this.label = 'other',
    required this.savedAt,
  });

  // ── Display helpers ────────────────────────────────────────────────────────

  /// Primary line: "245 East 23rd Street, Kips Bay"
  String get primaryLine {
    final parts = <String>[
      if (streetAddress.isNotEmpty) streetAddress,
      if (subLocality.isNotEmpty) subLocality,
    ];
    return parts.isEmpty ? 'Unknown address' : parts.join(', ');
  }

  /// Secondary line: "New York, NY 10010, USA"
  String get secondaryLine {
    final parts = <String>[
      if (city.isNotEmpty) city,
      if (state.isNotEmpty && postalCode.isNotEmpty)
        '$state $postalCode'
      else if (state.isNotEmpty)
        state,
      if (country.isNotEmpty) country,
    ];
    return parts.join(', ');
  }

  // ── Firestore ──────────────────────────────────────────────────────────────

  Map<String, dynamic> toFirestore() => {
    'id': id,
    'latitude': latitude,
    'longitude': longitude,
    'streetAddress': streetAddress,
    'subLocality': subLocality,
    'city': city,
    'state': state,
    'postalCode': postalCode,
    'country': country,
    'label': label,
    'savedAt': savedAt.toIso8601String(),
  };

  factory LocationModel.fromFirestore(Map<String, dynamic> map) =>
      LocationModel(
        id: map['id'] as String? ?? '',
        latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
        streetAddress: map['streetAddress'] as String? ?? '',
        subLocality: map['subLocality'] as String? ?? '',
        city: map['city'] as String? ?? '',
        state: map['state'] as String? ?? '',
        postalCode: map['postalCode'] as String? ?? '',
        country: map['country'] as String? ?? '',
        label: map['label'] as String? ?? 'other',
        savedAt: DateTime.tryParse(map['savedAt'] as String? ?? '') ??
            DateTime.now(),
      );

  LocationModel copyWith({String? label}) => LocationModel(
    id: id,
    latitude: latitude,
    longitude: longitude,
    streetAddress: streetAddress,
    subLocality: subLocality,
    city: city,
    state: state,
    postalCode: postalCode,
    country: country,
    label: label ?? this.label,
    savedAt: savedAt,
  );
}