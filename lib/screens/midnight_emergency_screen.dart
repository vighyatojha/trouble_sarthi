// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Replace the EmergencyScreen stub at the bottom with your real one:
//   import 'package:trouble_sarthi/screens/profile_screen.dart' show EmergencyScreen;
// ─────────────────────────────────────────────────────────────────────────────

// ═══════════════════════════════════════════════════════════════════════════
// DATA MODELS
// ═══════════════════════════════════════════════════════════════════════════

class _EmType {
  final String label, serviceName;
  final IconData icon;
  _EmType(this.label, this.icon, this.serviceName);
}

class _SosContact {
  final String name, phone;
  const _SosContact({required this.name, required this.phone});
  factory _SosContact.fromMap(Map<String, dynamic> m) =>
      _SosContact(name: m['name'] as String? ?? '', phone: m['phone'] as String? ?? '');
  Map<String, dynamic> toMap() => {'name': name, 'phone': phone};
}

class _HelperData {
  final String id, name, serviceType, experience, location, phoneNumber;
  final double rating, pricePerHour;
  final int completedJobs;
  final bool isAvailable;
  final String? profileImage;
  final List<String> skills;
  const _HelperData({
    required this.id,
    required this.name,
    required this.serviceType,
    required this.experience,
    required this.location,
    required this.phoneNumber,
    required this.rating,
    required this.pricePerHour,
    required this.completedJobs,
    required this.isAvailable,
    required this.profileImage,
    required this.skills,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// MIDNIGHT EMERGENCY SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class MidNightEmergencyScreen extends StatefulWidget {
  const MidNightEmergencyScreen({super.key});
  @override
  State<MidNightEmergencyScreen> createState() => _MidNightEmergencyScreenState();
}

class _MidNightEmergencyScreenState extends State<MidNightEmergencyScreen>
    with TickerProviderStateMixin {

  late final AnimationController _sosCtrl;
  late final AnimationController _glowCtrl;
  late final AnimationController _entryCtrl;
  late final Animation<double>   _entryAnim;

  String  _locationLabel   = 'Tap to detect your location';
  double? _lat;
  double? _lng;
  bool    _locationLoading = false;
  bool    _locationSet     = false;

  int? _selectedCard;

  int  _helperSubIndex = 0;
  bool _showHelpers    = false;

  List<_SosContact> _sosContacts = [];

  final _emergencies = [
    _EmType('Car\nBreakdown',     Icons.car_crash_rounded,             'Car Breakdown'),
    _EmType('Bike\nBreakdown',    Icons.two_wheeler_rounded,           'Bike Breakdown'),
    _EmType('Puncture',           Icons.tire_repair_rounded,           'Puncture Repair'),
    _EmType('Battery\nJumpstart', Icons.battery_charging_full_rounded, 'Battery Jumpstart'),
    _EmType('Fuel\nDelivery',     Icons.local_gas_station_rounded,     'Fuel Delivery'),
    _EmType('Towing',             Icons.local_shipping_rounded,        'Towing Service'),
  ];

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  DocumentReference<Map<String, dynamic>> get _locRef =>
      FirebaseFirestore.instance.collection('emergency_locations').doc(_uid);

  @override
  void initState() {
    super.initState();
    _sosCtrl   = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _glowCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat(reverse: true);
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _entryAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutBack);
    _entryCtrl.forward();
    _loadSavedLocation();
    _loadSosContacts();
  }

  @override
  void dispose() {
    _sosCtrl.dispose();
    _glowCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSavedLocation() async {
    if (_uid.isEmpty) return;
    try {
      final doc = await _locRef.get();
      if (!doc.exists || !mounted) return;
      final d = doc.data()!;
      setState(() {
        _lat           = (d['lat'] as num?)?.toDouble();
        _lng           = (d['lng'] as num?)?.toDouble();
        _locationLabel = d['label'] as String? ?? 'Location saved';
        _locationSet   = _lat != null && _lng != null;
      });
    } catch (_) {}
  }

  Future<void> _detectLocation() async {
    setState(() => _locationLoading = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) { setState(() => _locationLoading = false); _showPermDenied(); }
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) { setState(() => _locationLoading = false); _showServiceOff(); }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 12));

      String label = '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
      try {
        final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final parts = <String>[
            if ((p.subLocality ?? '').isNotEmpty) p.subLocality!,
            if ((p.locality    ?? '').isNotEmpty) p.locality!,
          ];
          if (parts.isNotEmpty) label = parts.join(', ');
        }
      } catch (_) {}

      await _locRef.set({
        'lat':     pos.latitude,
        'lng':     pos.longitude,
        'label':   label,
        'uid':     _uid,
        'savedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) setState(() {
        _lat = pos.latitude; _lng = pos.longitude;
        _locationLabel = label; _locationSet = true; _locationLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _locationLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(_redSnack('Could not get location: $e'));
      }
    }
  }

  Future<void> _deleteLocation() async {
    try { await _locRef.delete(); } catch (_) {}
    if (mounted) setState(() {
      _lat = null; _lng = null;
      _locationLabel = 'Tap to detect your location';
      _locationSet   = false;
    });
  }

  void _showPermDenied() => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: const Text('Location permission denied. Enable in Settings.'),
    backgroundColor: const Color(0xFFDC2626), behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), margin: const EdgeInsets.all(16),
    action: SnackBarAction(label: 'Settings', textColor: Colors.white, onPressed: () => Geolocator.openAppSettings()),
  ));

  void _showServiceOff() => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: const Text('GPS is disabled. Please enable location services.'),
    backgroundColor: const Color(0xFFDC2626), behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), margin: const EdgeInsets.all(16),
    action: SnackBarAction(label: 'Enable', textColor: Colors.white, onPressed: () => Geolocator.openLocationSettings()),
  ));

  SnackBar _redSnack(String msg) => SnackBar(
    content: Text(msg), backgroundColor: const Color(0xFFDC2626),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), margin: const EdgeInsets.all(16),
  );

  Future<void> _loadSosContacts() async {
    if (_uid.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
      if (!doc.exists || !mounted) return;
      final raw = (doc.data()!['sosContacts'] as List<dynamic>?) ?? [];
      setState(() { _sosContacts = raw.map((e) => _SosContact.fromMap(e as Map<String,dynamic>)).toList(); });
    } catch (_) {}
  }

  Future<void> _saveSosContacts() async {
    if (_uid.isEmpty) return;
    await FirebaseFirestore.instance.collection('users').doc(_uid).set(
      {'sosContacts': _sosContacts.map((c) => c.toMap()).toList()},
      SetOptions(merge: true),
    );
  }

  void _onFindHelpers() {
    if (_selectedCard == null) {
      ScaffoldMessenger.of(context).showSnackBar(_redSnack('Please select an emergency type'));
      return;
    }
    if (!_locationSet) {
      ScaffoldMessenger.of(context).showSnackBar(_redSnack('Please set your location first'));
      return;
    }
    setState(() { _helperSubIndex = _selectedCard!; _showHelpers = true; });
  }

  void _goToHelpline() {
    Navigator.push(context, PageRouteBuilder(
      pageBuilder: (_, __, ___) => const EmergencyScreen(),
      transitionsBuilder: (_, anim, __, child) {
        final c = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
            opacity: Tween<double>(begin: 0, end: 1).animate(c),
            child: ScaleTransition(scale: Tween<double>(begin: 0.96, end: 1).animate(c), child: child));
      },
      transitionDuration: const Duration(milliseconds: 480),
    ));
  }

  void _showSosSheet() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      isScrollControlled: true, useSafeArea: true,
      builder: (_) => _SosSheet(
        locationLabel: _locationLabel, lat: _lat, lng: _lng,
        contacts: _sosContacts,
        onContactsChanged: (u) { setState(() => _sosContacts = u); _saveSosContacts(); },
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      body: Stack(children: [
        Positioned.fill(child: _ShinyBg(glowCtrl: _glowCtrl)),
        SafeArea(child: _showHelpers ? _buildHelperPanel() : _buildMain()),
      ]),
    );
  }

  Widget _buildMain() {
    return Column(children: [
      _buildTopBar(),
      Expanded(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ScaleTransition(scale: _entryAnim, child: _buildLocationCard()),
            const SizedBox(height: 26),
            _buildSectionLabel('Select Emergency Type'),
            const SizedBox(height: 14),
            _buildGrid(),
            const SizedBox(height: 30),
            _buildFindBtn(),
            const SizedBox(height: 18),
            _buildHelplineTile(),
          ]),
        ),
      ),
    ]);
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(children: [
        _GlassBtn(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 17)),
        const Spacer(),
        Column(children: [
          const Text('Emergency Help', style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.3)),
          const SizedBox(height: 4),
          Container(height: 2, width: 36,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(2),
                  gradient: const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFFFF6B6B)]))),
        ]),
        const Spacer(),
        AnimatedBuilder(
          animation: _sosCtrl,
          builder: (_, __) => GestureDetector(
            onTap: _showSosSheet,
            child: Container(
              width: 54, height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                    colors: [Color(0xFFFF4040), Color(0xFFB91C1C)],
                    center: Alignment(-0.3, -0.3), radius: 0.9),
                boxShadow: [BoxShadow(
                    color: const Color(0xFFDC2626).withOpacity(0.30 + 0.45 * _sosCtrl.value),
                    blurRadius: 12 + 16 * _sosCtrl.value,
                    spreadRadius: 2 * _sosCtrl.value)],
              ),
              child: Stack(alignment: Alignment.center, children: [
                Container(width: 44, height: 44,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.22), width: 1))),
                const Text('SOS', style: TextStyle(
                    color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xFF0F0F0F),
        border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.28), width: 1.2),
        boxShadow: [
          BoxShadow(color: const Color(0xFFDC2626).withOpacity(0.10), blurRadius: 22, spreadRadius: -4),
          const BoxShadow(color: Color(0xFF000000), blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Row(children: [
        GestureDetector(
          onTap: _locationLoading ? null : _detectLocation,
          child: AnimatedBuilder(
            animation: _glowCtrl,
            builder: (_, __) => Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle, color: const Color(0xFF1A0505),
                boxShadow: [BoxShadow(
                    color: const Color(0xFFDC2626).withOpacity(0.20 + 0.22 * _glowCtrl.value),
                    blurRadius: 14 + 8 * _glowCtrl.value, spreadRadius: 1)],
              ),
              child: _locationLoading
                  ? const Padding(padding: EdgeInsets.all(13),
                  child: CircularProgressIndicator(color: Color(0xFFFF4444), strokeWidth: 2.5))
                  : Icon(_locationSet ? Icons.my_location_rounded : Icons.location_searching_rounded,
                  color: const Color(0xFFFF4444), size: 22),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: GestureDetector(
            onTap: _locationLoading ? null : _detectLocation,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Emergency Location', style: TextStyle(
                  fontSize: 10, color: Color(0xFF6B7280), fontWeight: FontWeight.w600, letterSpacing: 0.6)),
              const SizedBox(height: 3),
              Text(
                _locationLoading ? 'Detecting GPS…' : _locationLabel,
                style: TextStyle(fontSize: 14,
                    color: _locationSet ? Colors.white : const Color(0xFF6B7280),
                    fontWeight: _locationSet ? FontWeight.w700 : FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 5),
              Row(children: [
                Container(width: 7, height: 7,
                    decoration: BoxDecoration(
                        color: _locationSet ? const Color(0xFF22C55E) : const Color(0xFF4B5563),
                        shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text(_locationSet ? 'Tap pin to refresh  ·  tap 🗑 to remove'
                    : 'Tap anywhere here to auto-detect via GPS',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF4B5563))),
              ]),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        if (_locationSet)
          Column(mainAxisSize: MainAxisSize.min, children: [
            _miniBtn(Icons.map_rounded, const Color(0xFF3B82F6), () => _openMap(_lat!, _lng!)),
            const SizedBox(height: 6),
            _miniBtn(Icons.refresh_rounded, const Color(0xFFDC2626), _detectLocation),
            const SizedBox(height: 6),
            _miniBtn(Icons.delete_outline_rounded, const Color(0xFF6B7280), _deleteLocation),
          ])
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
            decoration: BoxDecoration(
                color: const Color(0xFF1A0505), borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.35))),
            child: const Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.gps_fixed_rounded, size: 15, color: Color(0xFFFF4444)),
              SizedBox(height: 2),
              Text('GPS', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold,
                  color: Color(0xFFDC2626), letterSpacing: 0.6)),
            ]),
          ),
      ]),
    );
  }

  Widget _miniBtn(IconData icon, Color color, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Icon(icon, size: 14, color: color),
    ),
  );

  Widget _buildSectionLabel(String label) {
    return Row(children: [
      Container(width: 3, height: 20,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(2),
              gradient: const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFFFF6B6B)],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter))),
      const SizedBox(width: 10),
      Text(label, style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.2)),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: const Color(0xFF1A0505), borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.40))),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.access_time_rounded, size: 10, color: Color(0xFFDC2626)),
          SizedBox(width: 4),
          Text('24×7', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
        ]),
      ),
    ]);
  }

  Widget _buildGrid() {
    return GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, childAspectRatio: 1.05, crossAxisSpacing: 12, mainAxisSpacing: 12),
      itemCount: _emergencies.length,
      itemBuilder: (_, i) => _EmCard(
        type: _emergencies[i], selected: _selectedCard == i, glowCtrl: _glowCtrl,
        onTap: () => setState(() => _selectedCard = _selectedCard == i ? null : i),
      ),
    );
  }

  Widget _buildFindBtn() {
    final fullyReady = _selectedCard != null && _locationSet;
    final needsLoc   = _selectedCard != null && !_locationSet;
    return AnimatedBuilder(
      animation: _glowCtrl,
      builder: (_, __) => GestureDetector(
        onTap: _onFindHelpers,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: double.infinity, height: 62,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: fullyReady
                ? const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                begin: Alignment.topLeft, end: Alignment.bottomRight)
                : const LinearGradient(colors: [Color(0xFF141414), Color(0xFF0D0D0D)]),
            border: Border.all(
                color: fullyReady ? const Color(0xFFFF5555).withOpacity(0.7) : const Color(0xFF222222),
                width: 1.2),
            boxShadow: fullyReady ? [BoxShadow(
                color: const Color(0xFFDC2626).withOpacity(0.32 + 0.16 * _glowCtrl.value),
                blurRadius: 22 + 10 * _glowCtrl.value, spreadRadius: -2, offset: const Offset(0, 6))] : [],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 38, height: 38,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: fullyReady ? Colors.white.withOpacity(0.15) : const Color(0xFF1A1A1A)),
                child: Icon(Icons.person_search_rounded,
                    color: fullyReady ? Colors.white : const Color(0xFF4B5563), size: 21)),
            const SizedBox(width: 12),
            Text(fullyReady ? 'Find Night Helpers Now'
                : needsLoc ? 'Set Location First'
                : 'Select Emergency First',
                style: TextStyle(
                    color: fullyReady ? Colors.white : const Color(0xFF4B5563),
                    fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
            if (fullyReady) ...[
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _buildHelplineTile() {
    return GestureDetector(
      onTap: _goToHelpline,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
            color: const Color(0xFF0E0E0E), border: Border.all(color: const Color(0xFF1E1E1E))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF1A0505),
                  border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.30))),
              child: const Icon(Icons.phone_rounded, size: 15, color: Color(0xFFDC2626))),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Text('Need direct assistance?',
                style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
            Row(children: [
              Text('Call our 24×7 Helpline',
                  style: TextStyle(fontSize: 13, color: Color(0xFFDC2626),
                      fontWeight: FontWeight.w700, letterSpacing: 0.2)),
              SizedBox(width: 6),
              Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Color(0xFFDC2626)),
            ]),
          ]),
        ]),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // HELPER PANEL
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildHelperPanel() {
    return Column(children: [
      _buildHelperTopBar(),
      Expanded(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildSidebar(),
          Expanded(child: _buildHelperList()),
        ]),
      ),
    ]);
  }

  Widget _buildHelperTopBar() {
    final em = _emergencies[_helperSubIndex];
    return Container(
      color: const Color(0xFF0D0D0D),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Row(children: [
          IconButton(
            onPressed: () => setState(() => _showHelpers = false),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
            padding: const EdgeInsets.all(8), constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Night Emergency Helpers',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              Text(em.serviceName,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
            ]),
          ),
          // Location chip — tapping opens map
          GestureDetector(
            onTap: _locationSet ? () => _openMap(_lat!, _lng!) : null,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.25))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.location_on_rounded, size: 12, color: Color(0xFFFF4444)),
                const SizedBox(width: 4),
                Text(
                  _locationLabel.length > 16
                      ? '${_locationLabel.substring(0, 16)}…'
                      : _locationLabel,
                  style: const TextStyle(fontSize: 10, color: Color(0xFFFF4444), fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.open_in_new_rounded, size: 9, color: Color(0xFFFF4444)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 80,
      decoration: const BoxDecoration(
          color: Color(0xFF0A0A0A),
          border: Border(right: BorderSide(color: Color(0xFF1A1A1A)))),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _emergencies.length,
        itemBuilder: (_, i) {
          final active = i == _helperSubIndex;
          final em     = _emergencies[i];
          return GestureDetector(
            onTap: () => setState(() => _helperSubIndex = i),
            child: Stack(alignment: Alignment.centerLeft, children: [
              // Active left accent bar
              if (active)
                Positioned(
                  left: 0, top: 6, bottom: 6,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(4))),
                  ),
                ),
              // Card
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.fromLTRB(6, 3, 6, 3),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
                decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFFDC2626).withOpacity(0.10)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Icon box — centered inside full width
                    Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                            color: active
                                ? const Color(0xFFDC2626).withOpacity(0.22)
                                : const Color(0xFF1A0505),
                            borderRadius: BorderRadius.circular(13),
                            border: active
                                ? Border.all(
                                color: const Color(0xFFDC2626).withOpacity(0.40),
                                width: 1)
                                : null),
                        child: Icon(em.icon, size: 21,
                            color: active ? Colors.white : const Color(0xFF6B7280)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Label — always 2 lines so height is stable
                    SizedBox(
                      width: double.infinity,
                      child: Text(
                        em.label.replaceAll('\n', '\n').toUpperCase(),
                        style: TextStyle(
                            fontSize: 7,
                            fontWeight: FontWeight.w800,
                            color: active
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF4B5563),
                            letterSpacing: 0.4,
                            height: 1.4),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.visible,
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _buildHelperList() {
    final serviceName = _emergencies[_helperSubIndex].serviceName;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('helpers')
          .where('serviceType', isEqualTo: serviceName)
          .snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(width: 34, height: 34,
                child: CircularProgressIndicator(color: Color(0xFFDC2626), strokeWidth: 2.5)),
            const SizedBox(height: 12),
            Text('Finding helpers…',
                style: TextStyle(fontSize: 13,
                    color: const Color(0xFFDC2626).withOpacity(0.7), fontWeight: FontWeight.w500)),
          ]));
        }

        if (snap.hasError) return Center(
            child: Text('Error: ${snap.error}', style: const TextStyle(color: Colors.white54)));

        final helpers = (snap.data?.docs ?? []).map((doc) {
          final d = doc.data() as Map<String, dynamic>;
          return _HelperData(
            id:            doc.id,
            name:          d['name']           as String? ?? 'Helper',
            serviceType:   d['serviceType']    as String? ?? '',
            experience:    d['experience']     as String? ?? '',
            rating:        (d['rating']        as num?)?.toDouble() ?? 0.0,
            pricePerHour:  (d['pricePerHour']  as num?)?.toDouble() ?? 0.0,
            completedJobs: (d['completedJobs'] as num?)?.toInt()    ?? 0,
            isAvailable:   (d['isAvailable']   as bool?) ?? false,
            phoneNumber:   d['phoneNumber']    as String? ?? '',
            location:      d['location']       as String? ?? '',
            profileImage:  d['profileImage']   as String?,
            skills:        List<String>.from(d['skills'] as List? ?? []),
          );
        }).toList()..sort((a, b) {
          // Available first, then by rating
          if (a.isAvailable != b.isAvailable) return a.isAvailable ? -1 : 1;
          return b.rating.compareTo(a.rating);
        });

        if (helpers.isEmpty) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 68, height: 68,
                  decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withOpacity(0.10), shape: BoxShape.circle),
                  child: const Icon(Icons.search_off_rounded, size: 32, color: Color(0xFFDC2626))),
              const SizedBox(height: 14),
              Text('No helpers for\n"$serviceName"', textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 6),
              const Text('Check back soon — helpers are being onboarded.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            ]),
          ));
        }

        final available = helpers.where((h) => h.isAvailable).length;

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Stats header ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: const BoxDecoration(
                color: Color(0xFF0A0A0A),
                border: Border(bottom: BorderSide(color: Color(0xFF161616)))),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('HELPERS NEARBY', style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w800,
                    color: Color(0xFF4B5563), letterSpacing: 1.2)),
                const SizedBox(height: 2),
                RichText(text: TextSpan(children: [
                  TextSpan(text: '${helpers.length}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                  const TextSpan(text: ' found',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                ])),
              ]),
              const SizedBox(width: 16),
              // Divider
              Container(width: 1, height: 32, color: const Color(0xFF1E1E1E)),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('AVAILABLE NOW', style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w800,
                    color: Color(0xFF4B5563), letterSpacing: 1.2)),
                const SizedBox(height: 2),
                RichText(text: TextSpan(children: [
                  TextSpan(text: '$available',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                          color: Color(0xFF22C55E))),
                  const TextSpan(text: ' online',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                ])),
              ]),
              const Spacer(),
              // Map button
              if (_locationSet)
                GestureDetector(
                  onTap: () => _openMap(_lat!, _lng!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                        color: const Color(0xFF0D1A2E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.35))),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.map_rounded, size: 13, color: Color(0xFF60A5FA)),
                      SizedBox(width: 5),
                      Text('My Location', style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF60A5FA))),
                    ]),
                  ),
                ),
            ]),
          ),
          // ── List ──────────────────────────────────────────────────────
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              physics: const ClampingScrollPhysics(),
              itemCount: helpers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _EmbeddedHelperCard(
                helper: helpers[i],
                userLat: _lat,
                userLng: _lng,
                locationLabel: _locationLabel,
                onTap: () => _showHelperProfile(helpers[i]),
              ),
            ),
          ),
        ]);
      },
    );
  }

  void _showHelperProfile(_HelperData h) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      isScrollControlled: true, useSafeArea: true,
      builder: (_) => _HelperProfileSheet(
        helper: h, userLat: _lat, userLng: _lng, locationLabel: _locationLabel,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// OPEN MAP UTILITY
// ══════════════════════════════════════════════════════════════════════════

Future<void> _openMap(double lat, double lng) async {
  // Try Google Maps first, fall back to Apple Maps / geo URI
  final googleUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
  final geoUri    = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
  if (await canLaunchUrl(googleUrl)) {
    await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
  } else if (await canLaunchUrl(geoUri)) {
    await launchUrl(geoUri, mode: LaunchMode.externalApplication);
  }
}

// ══════════════════════════════════════════════════════════════════════════
// AUTO-SEND WHATSAPP HELPER
// Opens WhatsApp immediately — no confirmation, no dialog.
// ══════════════════════════════════════════════════════════════════════════

Future<void> _autoSendHelperWhatsApp({
  required String helperPhone,
  required String helperName,
  required double? lat,
  required double? lng,
  required String locationLabel,
  required String serviceType,
}) async {
  final phone = helperPhone.replaceAll(RegExp(r'[^\d+]'), '');
  if (phone.isEmpty) return;

  final locationText = lat != null && lng != null
      ? 'https://maps.google.com/?q=$lat,$lng'
      : 'Location not available';

  final message = Uri.encodeComponent(
    '🚨 *EMERGENCY BOOKING REQUEST* 🚨\n\n'
        'I need urgent help for: *$serviceType*\n\n'
        '📍 *My Exact Location:*\n$locationText\n'
        '📌 Area: $locationLabel\n\n'
        '⚠️ Please respond IMMEDIATELY — this is an emergency.\n\n'
        '_Sent via Trouble Sarthi Emergency_',
  );

  final url = Uri.parse('https://wa.me/$phone?text=$message');
  try {
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  } catch (_) {}
}

// ═══════════════════════════════════════════════════════════════════════════
// EMERGENCY CARD WIDGET
// ═══════════════════════════════════════════════════════════════════════════

class _EmCard extends StatefulWidget {
  final _EmType type;
  final bool selected;
  final AnimationController glowCtrl;
  final VoidCallback onTap;
  const _EmCard({required this.type, required this.selected,
    required this.glowCtrl, required this.onTap});
  @override
  State<_EmCard> createState() => _EmCardState();
}

class _EmCardState extends State<_EmCard> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: ()  => setState(() => _pressed = false),
      child: AnimatedBuilder(
        animation: widget.glowCtrl,
        builder: (_, __) => AnimatedContainer(
          duration: const Duration(milliseconds: 150), curve: Curves.easeOutCubic,
          transform: Matrix4.identity()..scale(_pressed ? 0.91 : 1.0),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: widget.selected
                ? const LinearGradient(colors: [Color(0xFFE03333), Color(0xFF991B1B)],
                begin: Alignment.topLeft, end: Alignment.bottomRight)
                : const LinearGradient(colors: [Color(0xFF141414), Color(0xFF0F0F0F)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            border: Border.all(
                color: widget.selected ? const Color(0xFFFF5555) : const Color(0xFF1E1E1E),
                width: widget.selected ? 1.5 : 1),
            boxShadow: widget.selected
                ? [BoxShadow(
                color: const Color(0xFFDC2626).withOpacity(0.28 + 0.22 * widget.glowCtrl.value),
                blurRadius: 18 + 8 * widget.glowCtrl.value, spreadRadius: -2,
                offset: const Offset(0, 4))]
                : [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 8,
                offset: const Offset(0, 3))],
          ),
          child: Stack(children: [
            if (widget.selected) ...[
              Positioned(top: 0, right: 0, child: Container(width: 48, height: 48,
                  decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(topRight: Radius.circular(18)),
                      gradient: LinearGradient(
                          colors: [Colors.white.withOpacity(0.14), Colors.transparent],
                          begin: Alignment.topRight, end: Alignment.center)))),
              Positioned(top: 8, right: 8, child: Container(width: 8, height: 8,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))),
            ],
            Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              AnimatedBuilder(
                animation: widget.glowCtrl,
                builder: (_, __) => Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.selected ? Colors.white.withOpacity(0.18) : const Color(0xFF1A0505),
                    boxShadow: widget.selected
                        ? [BoxShadow(
                        color: Colors.white.withOpacity(0.10 + 0.10 * widget.glowCtrl.value),
                        blurRadius: 10 + 6 * widget.glowCtrl.value)]
                        : [BoxShadow(
                        color: const Color(0xFFDC2626).withOpacity(0.08 + 0.10 * widget.glowCtrl.value),
                        blurRadius: 8 + 4 * widget.glowCtrl.value)],
                  ),
                  child: Icon(widget.type.icon, size: 21, color: Colors.white),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(widget.type.label, textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10,
                        fontWeight: widget.selected ? FontWeight.w800 : FontWeight.w600,
                        color: Colors.white.withOpacity(widget.selected ? 1.0 : 0.70),
                        height: 1.25)),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// EMBEDDED HELPER CARD — polished UI + instant book
// ═══════════════════════════════════════════════════════════════════════════

class _EmbeddedHelperCard extends StatefulWidget {
  final _HelperData helper;
  final double? userLat;
  final double? userLng;
  final String locationLabel;
  final VoidCallback onTap;
  const _EmbeddedHelperCard({
    required this.helper,
    required this.userLat,
    required this.userLng,
    required this.locationLabel,
    required this.onTap,
  });
  @override
  State<_EmbeddedHelperCard> createState() => _EmbeddedHelperCardState();
}

class _EmbeddedHelperCardState extends State<_EmbeddedHelperCard> {
  bool _pressed  = false;
  bool _booking  = false;

  Future<void> _instantBook() async {
    if (_booking) return;
    setState(() => _booking = true);
    // Fire WhatsApp immediately — no confirm, no dialog
    await _autoSendHelperWhatsApp(
      helperPhone:   widget.helper.phoneNumber,
      helperName:    widget.helper.name,
      lat:           widget.userLat,
      lng:           widget.userLng,
      locationLabel: widget.locationLabel,
      serviceType:   widget.helper.serviceType,
    );
    if (mounted) {
      setState(() => _booking = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text('Request sent to ${widget.helper.name} via WhatsApp',
              style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final h       = widget.helper;
    final initial = h.name.isNotEmpty ? h.name[0].toUpperCase() : '?';

    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: ()  => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120), curve: Curves.easeOutCubic,
        transform: Matrix4.identity()..scale(_pressed ? 0.97 : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F0F),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: h.isAvailable
                  ? const Color(0xFF16A34A).withOpacity(0.20)
                  : const Color(0xFF1E1E1E)),
          boxShadow: [BoxShadow(
              color: h.isAvailable
                  ? const Color(0xFF16A34A).withOpacity(0.06)
                  : Colors.black.withOpacity(0.45),
              blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── TOP BANNER: availability stripe ──────────────────────────
          Container(
            height: 3,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              gradient: LinearGradient(
                colors: h.isAvailable
                    ? [const Color(0xFF16A34A), const Color(0xFF4ADE80)]
                    : [const Color(0xFF374151), const Color(0xFF374151)],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── ROW 1: Avatar + Name + Availability ──────────────────
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Avatar with online ring
                Stack(children: [
                  Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1A0505),
                        border: Border.all(
                            color: h.isAvailable
                                ? const Color(0xFF16A34A).withOpacity(0.50)
                                : const Color(0xFFDC2626).withOpacity(0.25),
                            width: 2)),
                    child: h.profileImage != null
                        ? ClipOval(child: Image.network(h.profileImage!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                            child: Text(initial, style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold,
                                color: Color(0xFFDC2626))))))
                        : Center(child: Text(initial, style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold,
                        color: Color(0xFFDC2626)))),
                  ),
                  if (h.isAvailable)
                    Positioned(bottom: 2, right: 2,
                        child: Container(width: 12, height: 12,
                            decoration: BoxDecoration(
                                color: const Color(0xFF22C55E), shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF0F0F0F), width: 2)))),
                ]),
                const SizedBox(width: 12),

                // Name + service + rating
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(h.name,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                          color: Colors.white, letterSpacing: -0.2),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                          color: const Color(0xFF1A0505), borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.30))),
                      child: Text(h.serviceType, style: const TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w700,
                          color: Color(0xFFDC2626), letterSpacing: 0.3)),
                    ),
                    const SizedBox(width: 6),
                    Text(h.experience, style: const TextStyle(
                        fontSize: 10, color: Color(0xFF6B7280))),
                  ]),
                  const SizedBox(height: 6),
                  // Rating + jobs
                  Row(children: [
                    const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFBBF24)),
                    const SizedBox(width: 3),
                    Text(h.rating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(width: 10),
                    const Icon(Icons.check_circle_outline_rounded, size: 11,
                        color: Color(0xFF4B5563)),
                    const SizedBox(width: 3),
                    Text('${h.completedJobs} jobs',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                  ]),
                ])),

                // Availability badge
                _AvailPill(isAvailable: h.isAvailable),
              ]),

              const SizedBox(height: 12),

              // ── ROW 2: Location + Phone ───────────────────────────────
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: const Color(0xFF0A0A0A), borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1A1A1A))),
                child: Column(children: [
                  if (h.phoneNumber.isNotEmpty)
                    Row(children: [
                      const Icon(Icons.phone_outlined, size: 11, color: Color(0xFF4B5563)),
                      const SizedBox(width: 6),
                      Text(h.phoneNumber,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                    ]),
                  if (h.phoneNumber.isNotEmpty && h.location.isNotEmpty)
                    const SizedBox(height: 5),
                  if (h.location.isNotEmpty)
                    Row(children: [
                      const Icon(Icons.location_on_outlined, size: 11, color: Color(0xFF4B5563)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(h.location, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)))),
                    ]),
                ]),
              ),

              const SizedBox(height: 12),

              // ── ROW 3: Price chip + Map + Book ────────────────────────
              Row(children: [
                // Price
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withOpacity(0.10),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.25))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.currency_rupee_rounded, size: 10, color: Color(0xFFDC2626)),
                    Text('${h.pricePerHour.toInt()}/hr',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                            color: Color(0xFFDC2626))),
                  ]),
                ),
                const SizedBox(width: 8),

                // Open Map button
                GestureDetector(
                  onTap: () {
                    if (widget.userLat != null && widget.userLng != null) {
                      _openMap(widget.userLat!, widget.userLng!);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                        color: const Color(0xFF0D1A2E),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.35))),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.map_rounded, size: 11, color: Color(0xFF60A5FA)),
                      SizedBox(width: 4),
                      Text('Map', style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF60A5FA))),
                    ]),
                  ),
                ),

                const Spacer(),

                // BOOK / NOTIFY — instant send, no dialog
                GestureDetector(
                  onTap: _booking ? null : _instantBook,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: h.isAvailable
                          ? const LinearGradient(
                          colors: [Color(0xFF16A34A), Color(0xFF15803D)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight)
                          : null,
                      color: h.isAvailable ? null : const Color(0xFF1E1E1E),
                      boxShadow: h.isAvailable && !_booking
                          ? [BoxShadow(color: const Color(0xFF16A34A).withOpacity(0.35),
                          blurRadius: 12, offset: const Offset(0, 4))]
                          : [],
                    ),
                    child: _booking
                        ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                        : Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(h.isAvailable ? 'BOOK' : 'NOTIFY',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                              color: h.isAvailable ? Colors.white : const Color(0xFF4B5563))),
                      Text(h.isAvailable ? 'NOW' : 'ME',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                              color: h.isAvailable ? Colors.white : const Color(0xFF4B5563))),
                    ]),
                  ),
                ),
              ]),

              const SizedBox(height: 14),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HELPER PROFILE SHEET — instant send on Book tap
// ═══════════════════════════════════════════════════════════════════════════

class _HelperProfileSheet extends StatefulWidget {
  final _HelperData helper;
  final double?     userLat;
  final double?     userLng;
  final String      locationLabel;
  const _HelperProfileSheet({
    required this.helper,
    required this.userLat,
    required this.userLng,
    required this.locationLabel,
  });
  @override
  State<_HelperProfileSheet> createState() => _HelperProfileSheetState();
}

class _HelperProfileSheetState extends State<_HelperProfileSheet> {
  bool _booking = false;

  Future<void> _instantBook(BuildContext ctx) async {
    if (_booking) return;
    setState(() => _booking = true);
    await _autoSendHelperWhatsApp(
      helperPhone:   widget.helper.phoneNumber,
      helperName:    widget.helper.name,
      lat:           widget.userLat,
      lng:           widget.userLng,
      locationLabel: widget.locationLabel,
      serviceType:   widget.helper.serviceType,
    );
    if (mounted) {
      setState(() => _booking = false);
      Navigator.pop(ctx);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(
              widget.helper.isAvailable
                  ? 'Booking sent to ${widget.helper.name} via WhatsApp!'
                  : 'Notification sent to ${widget.helper.name} via WhatsApp!',
              style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
        backgroundColor: widget.helper.isAvailable
            ? const Color(0xFF16A34A)
            : const Color(0xFF4B5563),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final h       = widget.helper;
    final initial = h.name.isNotEmpty ? h.name[0].toUpperCase() : '?';

    return DraggableScrollableSheet(
      initialChildSize: 0.88, minChildSize: 0.5, maxChildSize: 0.95,
      expand: false, snap: true, snapSizes: const [0.88, 0.95],
      builder: (ctx, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0D0D0D),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [BoxShadow(color: Color(0xAADC2626), blurRadius: 40, offset: Offset(0, -4))],
        ),
        child: Column(children: [
          Container(margin: const EdgeInsets.only(top: 10, bottom: 4), width: 42, height: 4,
              decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Color(0xFF1A1A1A), shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF6B7280))),
              ),
              const Expanded(child: Text('Helper Profile', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white))),
              // Map button in profile header
              if (widget.userLat != null && widget.userLng != null)
                GestureDetector(
                  onTap: () => _openMap(widget.userLat!, widget.userLng!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                        color: const Color(0xFF0D1A2E), borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.35))),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.map_rounded, size: 13, color: Color(0xFF60A5FA)),
                      SizedBox(width: 5),
                      Text('My Location', style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF60A5FA))),
                    ]),
                  ),
                )
              else
                const SizedBox(width: 36),
            ]),
          ),
          Expanded(
            child: ListView(controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                        color: const Color(0xFF111111), borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.20)),
                        boxShadow: [BoxShadow(color: const Color(0xFFDC2626).withOpacity(0.08),
                            blurRadius: 16, spreadRadius: -4)]),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(h.name, style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 5),
                        Text('${h.serviceType} specialist · ${h.experience} experience',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.5)),
                        const SizedBox(height: 10),
                        Row(children: [
                          const Icon(Icons.star_rounded, size: 15, color: Color(0xFFFBBF24)),
                          const SizedBox(width: 4),
                          Text('${h.rating.toStringAsFixed(1)} Rating',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                          const SizedBox(width: 10),
                          _AvailPill(isAvailable: h.isAvailable),
                        ]),
                        const SizedBox(height: 10),
                        if (h.phoneNumber.isNotEmpty) ...[
                          Row(children: [
                            const Icon(Icons.phone_outlined, size: 13, color: Color(0xFF4B5563)),
                            const SizedBox(width: 5),
                            Text(h.phoneNumber, style: const TextStyle(
                                fontSize: 12, color: Color(0xFF9CA3AF))),
                          ]),
                          const SizedBox(height: 4),
                        ],
                        Row(children: [
                          const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF4B5563)),
                          const SizedBox(width: 5),
                          Flexible(child: Text(h.location,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)))),
                        ]),
                      ])),
                      const SizedBox(width: 14),
                      Container(
                        width: 86, height: 86,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF1A0505),
                            border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.25), width: 2)),
                        child: h.profileImage != null
                            ? ClipOval(child: Image.network(h.profileImage!, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(child: Text(initial,
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold,
                                    color: Color(0xFFDC2626))))))
                            : Center(child: Text(initial, style: const TextStyle(
                            fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)))),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    _StatBubble(label: 'RATING', value: h.rating.toStringAsFixed(1), sub: 'out of 5',
                        color: const Color(0xFFFBBF24), icon: Icons.star_rounded),
                    const SizedBox(width: 10),
                    _StatBubble(label: 'EXP', value: h.experience, sub: 'in field',
                        color: const Color(0xFFDC2626), icon: Icons.workspace_premium_rounded),
                    const SizedBox(width: 10),
                    _StatBubble(label: 'JOBS', value: '${h.completedJobs}', sub: 'completed',
                        color: const Color(0xFF16A34A), icon: Icons.check_circle_outline_rounded),
                  ]),
                  const SizedBox(height: 16),
                  if (h.skills.isNotEmpty) ...[
                    const Text('Skills', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                        color: Colors.white)),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8,
                        children: h.skills.map((s) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: const Color(0xFF1A0505),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.3))),
                          child: Text(s, style: const TextStyle(fontSize: 12,
                              fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                        )).toList()),
                    const SizedBox(height: 16),
                  ],
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFF1A0505),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.20))),
                    child: Row(children: [
                      const Icon(Icons.currency_rupee_rounded, size: 20, color: Color(0xFFDC2626)),
                      const SizedBox(width: 10),
                      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Starting Price / Hour', style: TextStyle(fontSize: 13,
                            color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
                        Text('Final price depends on job complexity',
                            style: TextStyle(fontSize: 10, color: Color(0xFF4B5563))),
                      ])),
                      Text('₹${h.pricePerHour.toInt()}', style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                    ]),
                  ),
                ]),
          ),
          // Book / Notify — instant send
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(color: const Color(0xFF0D0D0D),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3),
                    blurRadius: 16, offset: const Offset(0, -4))]),
            child: SafeArea(top: false,
              child: SizedBox(width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: _booking ? null : () => _instantBook(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: h.isAvailable
                        ? const Color(0xFF16A34A)
                        : const Color(0xFF374151),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  child: _booking
                      ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(h.isAvailable
                        ? Icons.send_rounded
                        : Icons.notifications_outlined,
                        size: 20, color: Colors.white),
                    const SizedBox(width: 10),
                    Text(
                      h.isAvailable
                          ? 'Book Now — Send Location via WhatsApp'
                          : 'Notify Me When Available',
                      style: const TextStyle(fontSize: 14,
                          fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SOS BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════════════════

class _SosSheet extends StatefulWidget {
  final String locationLabel;
  final double? lat, lng;
  final List<_SosContact> contacts;
  final ValueChanged<List<_SosContact>> onContactsChanged;
  const _SosSheet({required this.locationLabel, required this.lat, required this.lng,
    required this.contacts, required this.onContactsChanged});
  @override
  State<_SosSheet> createState() => _SosSheetState();
}

class _SosSheetState extends State<_SosSheet> {
  late List<_SosContact> _contacts;
  bool _sending = false;

  @override
  void initState() { super.initState(); _contacts = List.from(widget.contacts); }

  void _addContact() {
    final nameCtrl  = TextEditingController();
    final phoneCtrl = TextEditingController();
    showDialog(
      context: context, barrierColor: Colors.black87,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add SOS Contact', style: TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _darkField(nameCtrl, 'Full Name', Icons.person_outline_rounded),
          const SizedBox(height: 12),
          _darkField(phoneCtrl, 'WhatsApp number (+91…)', Icons.phone_outlined, isPhone: true),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
            onPressed: () {
              final name = nameCtrl.text.trim(); final phone = phoneCtrl.text.trim();
              if (name.isNotEmpty && phone.isNotEmpty) {
                setState(() => _contacts.add(_SosContact(name: name, phone: phone)));
                widget.onContactsChanged(_contacts);
                Navigator.pop(context);
              }
            },
            child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _darkField(TextEditingController ctrl, String hint, IconData icon, {bool isPhone = false}) {
    return TextField(
      controller: ctrl, style: const TextStyle(color: Colors.white),
      keyboardType: isPhone ? TextInputType.phone : TextInputType.name,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF4B5563), fontSize: 13),
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF6B7280)),
        filled: true, fillColor: const Color(0xFF1A1A1A), isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
        border:        OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2A2A2A))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2A2A2A))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFDC2626))),
      ),
    );
  }

  Future<void> _sendSos() async {
    if (_contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Add at least one SOS contact first'),
          backgroundColor: Color(0xFFDC2626)));
      return;
    }
    setState(() => _sending = true);

    final locationText = widget.lat != null && widget.lng != null
        ? 'https://maps.google.com/?q=${widget.lat},${widget.lng}'
        : 'Location not available — please share manually';

    final message = Uri.encodeComponent(
      '🚨 *EMERGENCY ALERT* 🚨\n\n'
          'I am in an emergency and need immediate help!\n\n'
          '📍 *My Live Location:*\n$locationText\n\n'
          '⚠️ Please contact me or send help immediately!\n\n'
          '_Sent via Trouble Sarthi SOS_',
    );

    bool anyOpened = false;
    for (final contact in _contacts) {
      final phone = contact.phone.replaceAll(RegExp(r'[^\d+]'), '');
      final url   = Uri.parse('https://wa.me/$phone?text=$message');
      try {
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
          anyOpened = true;
          await Future.delayed(const Duration(milliseconds: 700));
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() => _sending = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(anyOpened
            ? '🚨 SOS sent to ${_contacts.length} contact(s) via WhatsApp!'
            : '⚠️ Could not open WhatsApp. Check numbers.'),
        backgroundColor: anyOpened ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasGps = widget.lat != null && widget.lng != null;
    return DraggableScrollableSheet(
      initialChildSize: 0.72, minChildSize: 0.45, maxChildSize: 0.94,
      expand: false, snap: true, snapSizes: const [0.72, 0.94],
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
            color: Color(0xFF0D0D0D),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [BoxShadow(color: Color(0xAADC2626),
                blurRadius: 50, spreadRadius: -10, offset: Offset(0, -2))]),
        child: Column(children: [
          Container(margin: const EdgeInsets.only(top: 12, bottom: 6), width: 42, height: 4,
              decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
            child: Row(children: [
              Container(width: 50, height: 50,
                  decoration: const BoxDecoration(shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [Color(0xFFFF4040), Color(0xFFB91C1C)],
                          center: Alignment(-0.3, -0.3), radius: 0.9)),
                  child: const Center(child: Text('SOS', style: TextStyle(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)))),
              const SizedBox(width: 14),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('SOS Emergency Alert', style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                Text('Sends your live GPS link via WhatsApp', style: TextStyle(
                    fontSize: 11, color: Color(0xFF6B7280))),
              ])),
              GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF1A1A1A),
                          border: Border.all(color: const Color(0xFF2A2A2A))),
                      child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF9CA3AF)))),
            ]),
          ),
          Divider(height: 1, color: Colors.white.withOpacity(0.05)),
          Expanded(
            child: ListView(controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
                  // GPS status
                  GestureDetector(
                    onTap: hasGps ? () => _openMap(widget.lat!, widget.lng!) : null,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: hasGps ? const Color(0xFF0A1A0A) : const Color(0xFF1A0A0A),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: hasGps
                              ? const Color(0xFF16A34A).withOpacity(0.30)
                              : const Color(0xFFDC2626).withOpacity(0.30))),
                      child: Row(children: [
                        Icon(hasGps ? Icons.my_location_rounded : Icons.location_off_rounded,
                            color: hasGps ? const Color(0xFF22C55E) : const Color(0xFFDC2626), size: 18),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(hasGps ? 'Live GPS Ready — Tap to open map' : 'No GPS Location',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                  color: hasGps ? const Color(0xFF22C55E) : const Color(0xFFDC2626))),
                          Text(hasGps ? widget.locationLabel
                              : 'Go back → tap location card to detect GPS first',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                        ])),
                        if (hasGps)
                          const Icon(Icons.open_in_new_rounded, size: 14, color: Color(0xFF22C55E)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(children: [
                    const Text('SOS Contacts', style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                    const Spacer(),
                    GestureDetector(
                        onTap: _addContact,
                        child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(color: const Color(0xFF1A0505),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.45))),
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.person_add_rounded, size: 14, color: Color(0xFFDC2626)),
                              SizedBox(width: 5),
                              Text('Add Contact', style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                            ]))),
                  ]),
                  const SizedBox(height: 12),
                  if (_contacts.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                      decoration: BoxDecoration(color: const Color(0xFF0F0F0F),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF1E1E1E))),
                      child: Column(children: [
                        Icon(Icons.contacts_outlined, size: 36, color: Colors.white.withOpacity(0.10)),
                        const SizedBox(height: 10),
                        const Text('No contacts yet', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                        const SizedBox(height: 4),
                        const Text('Add WhatsApp contacts to receive\nyour live GPS location in an emergency',
                            style: TextStyle(color: Color(0xFF4B5563), fontSize: 11, height: 1.5),
                            textAlign: TextAlign.center),
                      ]),
                    )
                  else
                    ..._contacts.asMap().entries.map((e) {
                      final i = e.key; final c = e.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        decoration: BoxDecoration(color: const Color(0xFF0F0F0F),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF1E1E1E))),
                        child: Row(children: [
                          Container(width: 38, height: 38,
                              decoration: BoxDecoration(shape: BoxShape.circle,
                                  color: const Color(0xFF25D366).withOpacity(0.12),
                                  border: Border.all(color: const Color(0xFF25D366).withOpacity(0.28))),
                              child: const Center(child: FaIcon(FontAwesomeIcons.whatsapp,
                                  color: Color(0xFF25D366), size: 18))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(c.name, style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                            Text(c.phone, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                          ])),
                          GestureDetector(
                            onTap: () {
                              setState(() => _contacts.removeAt(i));
                              widget.onContactsChanged(_contacts);
                            },
                            child: Container(padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(shape: BoxShape.circle,
                                    color: const Color(0xFF1A1A1A),
                                    border: Border.all(color: const Color(0xFF2A2A2A))),
                                child: const Icon(Icons.close_rounded, size: 13, color: Color(0xFF6B7280))),
                          ),
                        ]),
                      );
                    }),
                  const SizedBox(height: 28),
                  GestureDetector(
                    onTap: _sending ? null : _sendSos,
                    child: Container(
                      width: double.infinity, height: 60,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: _sending
                              ? const LinearGradient(colors: [Color(0xFF374151), Color(0xFF1F2937)])
                              : const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                              begin: Alignment.topLeft, end: Alignment.bottomRight),
                          boxShadow: _sending ? [] : [BoxShadow(
                              color: const Color(0xFFDC2626).withOpacity(0.38),
                              blurRadius: 20, offset: const Offset(0, 6))]),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        if (_sending)
                          const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        else
                          const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Text(_sending ? 'Sending SOS…' : 'Send SOS via WhatsApp',
                            style: const TextStyle(color: Colors.white, fontSize: 15,
                                fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(child: Text(
                    hasGps ? '📍 Live GPS coordinates will be shared'
                        : '⚠️  Set location first for accurate GPS sharing',
                    style: TextStyle(
                        color: hasGps ? const Color(0xFF4B5563)
                            : const Color(0xFFDC2626).withOpacity(0.7),
                        fontSize: 11),
                    textAlign: TextAlign.center,
                  )),
                ]),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SHINY BACKGROUND
// ═══════════════════════════════════════════════════════════════════════════

class _ShinyBg extends StatelessWidget {
  final AnimationController glowCtrl;
  const _ShinyBg({required this.glowCtrl});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: glowCtrl,
    builder: (_, __) => CustomPaint(painter: _ShinyBgPainter(glowCtrl.value)),
  );
}

class _ShinyBgPainter extends CustomPainter {
  final double t;
  _ShinyBgPainter(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(r, Paint()..color = const Color(0xFF080808));
    final gp = Paint()..color = Colors.white.withOpacity(0.018)..strokeWidth = 0.5;
    for (double x = 0; x <= size.width;  x += 30) canvas.drawLine(Offset(x, 0), Offset(x, size.height), gp);
    for (double y = 0; y <= size.height; y += 30) canvas.drawLine(Offset(0, y), Offset(size.width, y), gp);
    canvas.drawRect(r, Paint()..shader = RadialGradient(center: const Alignment(0, -1), radius: 1,
        colors: [const Color(0xFFDC2626).withOpacity(0.06 + 0.05 * t), Colors.transparent]).createShader(r));
    canvas.drawRect(r, Paint()..shader = RadialGradient(center: const Alignment(0, 1.3), radius: 0.85,
        colors: [const Color(0xFF3D0C0C).withOpacity(0.14 + 0.08 * t), Colors.transparent]).createShader(r));
    canvas.drawRect(r, Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Colors.white.withOpacity(0.014), Colors.transparent, Colors.white.withOpacity(0.008)],
        stops: const [0.0, 0.5, 1.0]).createShader(r));
  }
  @override bool shouldRepaint(_ShinyBgPainter old) => old.t != t;
}

// ═══════════════════════════════════════════════════════════════════════════
// SMALL REUSABLE WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _GlassBtn extends StatelessWidget {
  final Widget child; final VoidCallback onTap;
  const _GlassBtn({required this.child, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(width: 42, height: 42,
        decoration: BoxDecoration(shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.08),
            border: Border.all(color: Colors.white.withOpacity(0.13))),
        child: Center(child: child)),
  );
}

class _AvailPill extends StatelessWidget {
  final bool isAvailable;
  const _AvailPill({required this.isAvailable});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: isAvailable
            ? const Color(0xFF16A34A).withOpacity(0.15)
            : const Color(0xFF374151).withOpacity(0.40),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isAvailable
                ? const Color(0xFF16A34A).withOpacity(0.4)
                : const Color(0xFF4B5563).withOpacity(0.4))),
    child: Text(isAvailable ? 'Available' : 'Busy',
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
            color: isAvailable ? const Color(0xFF22C55E) : const Color(0xFF6B7280))),
  );
}

class _DarkChip extends StatelessWidget {
  final String label; final Color color; final IconData? icon;
  const _DarkChip({required this.label, required this.color, this.icon});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[Icon(icon, size: 10, color: color), const SizedBox(width: 4)],
      Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    ]),
  );
}

class _StatBubble extends StatelessWidget {
  final String label, value, sub; final Color color; final IconData icon;
  const _StatBubble({required this.label, required this.value, required this.sub,
    required this.color, required this.icon});
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
    decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.20))),
    child: Column(children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(height: 6),
      Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700,
          color: Color(0xFF4B5563), letterSpacing: 0.8)),
      Text(sub, style: const TextStyle(fontSize: 9, color: Color(0xFF6B7280))),
    ]),
  ));
}

// ═══════════════════════════════════════════════════════════════════════════
// EMERGENCY SCREEN STUB
// Replace with: import 'profile_screen.dart' show EmergencyScreen;
// ═══════════════════════════════════════════════════════════════════════════

class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080808), elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Emergency Helpline',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: const Center(child: Text('Replace this stub with your real EmergencyScreen',
          style: TextStyle(color: Colors.white54))),
    );
  }
}