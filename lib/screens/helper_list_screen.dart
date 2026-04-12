import 'dart:async';
import 'dart:math' show pi, cos, sin;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/service_model.dart';
import 'booking_screen.dart' show showBookNowSheet;

// ─────────────────────────────────────────────────────────────────────────────
// SUB-SERVICE ITEM
// ─────────────────────────────────────────────────────────────────────────────

class SubServiceItem {
  final String name;
  final IconData icon;
  const SubServiceItem(this.name, this.icon);
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE TYPE ALIAS MAP  (all 37 entries)
// ─────────────────────────────────────────────────────────────────────────────

const Map<String, String> _kServiceTypeAliases = {
  'plumber': 'Plumbing',
  'plumbing': 'Plumbing',           // ← FIX 1: reverse alias added
  'electrician': 'Electrical',
  'electrical': 'Electrical',       // ← FIX 1: reverse alias added
  'carpenter': 'Carpentry',
  'carpentry': 'Carpentry',         // ← FIX 1: reverse alias added
  'painter': 'Painting',
  'painting': 'Painting',           // ← FIX 1: reverse alias added
  'cleaner': 'Cleaning',
  'cleaning': 'Cleaning',           // ← FIX 1: reverse alias added
  'ac repair': 'AC Repair',
  'ro repair': 'RO Repair',
  'appliance repair': 'Appliance Repair',
  'car mechanic': 'Car Mechanic',
  'bike mechanic': 'Bike Mechanic',
  'towing service': 'Towing Service',
  'puncture repair': 'Puncture Repair',
  'car wash': 'Car Wash',
  'mobile repair': 'Mobile Repair',
  'laptop repair': 'Laptop Repair',
  'cctv install': 'CCTV Install',
  'wifi install': 'WiFi Install',
  'software help': 'Software Help',
  'deep cleaning': 'Deep Cleaning',
  'pest control': 'Pest Control',
  'battery jump start': 'Battery Jump Start',
  'home tutor': 'Home Tutor',
  'fitness trainer': 'Fitness Trainer',
  'yoga instructor': 'Yoga Instructor',
  'caretaker': 'Caretaker',
  'babysitter': 'Babysitter',
  'photographer': 'Photographer',
  'videographer': 'Videographer',
  'dj': 'DJ',
  'decoration': 'Decoration',
  'catering': 'Catering',
  'ambulance': 'Ambulance',
  'first aid': 'First Aid',
  'blood donor': 'Blood Donor',
  'gardener': 'Gardener',
  'security guard': 'Security Guard',
  'driver on hire': 'Driver on Hire',
};

String _resolveServiceType(String name) {
  final key = name.trim().toLowerCase();
  return _kServiceTypeAliases[key] ?? name;
}

// ─────────────────────────────────────────────────────────────────────────────
// VERIFIED BADGE
// Circular badge (Twitter/Meta style), royal purple radial gradient,
// shiny gloss overlay, bold rounded white checkmark centred inside.
//
// HOW TO CONTROL:
//   • SIZE:    Change the `size` parameter — e.g. _VerifiedBadge(size: 18)
//              Bigger number = bigger badge. Default is 18.
//   • PADDING FROM NAME: Change the SizedBox(width: X) that sits between
//              the name Text and the _VerifiedBadge widget.
//              e.g. SizedBox(width: 4) = tight,  SizedBox(width: 8) = loose.
// ─────────────────────────────────────────────────────────────────────────────

class _VerifiedBadge extends StatelessWidget {
  final double size;
  const _VerifiedBadge({this.size = 18}); // ← change `size` to resize the badge

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _VerifiedBadgePainter(),
      ),
    );
  }
}

class _VerifiedBadgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // 1. Soft drop shadow underneath the circle
    canvas.drawCircle(
      Offset(cx, cy + size.height * 0.07),
      r * 0.85,
      Paint()
        ..color = const Color(0xFF5B21B6).withOpacity(0.32)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // 2. Royal purple radial gradient fill (bright centre → deep edge)
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 1.0,
          colors: const [
            Color(0xFFBB7EF7), // bright highlight
            Color(0xFF7C3AED), // mid purple
            Color(0xFF4C1D95), // deep violet edge
          ],
          stops: const [0.0, 0.52, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
    );

    // 3. Shiny gloss — semi-transparent white on the top half only
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, cy * 0.96));
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy * 0.52),
        width: size.width * 0.78,
        height: cy * 0.72,
      ),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.42),
            Colors.white.withOpacity(0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, cy)),
    );
    canvas.restore();

    // 4. Subtle white ring border for depth
    canvas.drawCircle(
      Offset(cx, cy),
      r - 0.7,
      Paint()
        ..color = Colors.white.withOpacity(0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // 5. Bold rounded white checkmark
    final ts = size.width * 0.215;
    canvas.drawPath(
      Path()
        ..moveTo(cx - ts * 0.58, cy + ts * 0.05)
        ..lineTo(cx - ts * 0.02, cy + ts * 0.63)
        ..lineTo(cx + ts * 0.80, cy - ts * 0.56),
      Paint()
        ..color = Colors.white
        ..strokeWidth = size.width * 0.135
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _VerifiedBadgePainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// SHIMMER  (self-contained, no external package)
// ─────────────────────────────────────────────────────────────────────────────

class _Shimmer extends StatefulWidget {
  final double width, height;
  final BorderRadius? borderRadius;
  const _Shimmer({
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
    _anim = Tween<double>(begin: -1.5, end: 2.5).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: [
              (_anim.value - 0.5).clamp(0.0, 1.0),
              _anim.value.clamp(0.0, 1.0),
              (_anim.value + 0.5).clamp(0.0, 1.0),
            ],
            colors: const [
              Color(0xFFEEEEF5),
              Color(0xFFF8F8FF),
              Color(0xFFEEEEF5),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SKELETON — HELPER CARD
// ─────────────────────────────────────────────────────────────────────────────

class _HelperCardSkeleton extends StatelessWidget {
  const _HelperCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _Shimmer(
                            width: 130,
                            height: 16,
                            borderRadius: BorderRadius.circular(6)),
                        const SizedBox(width: 6),
                        _Shimmer(
                            width: 18,
                            height: 18,
                            borderRadius: BorderRadius.circular(9)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _Shimmer(
                        width: double.infinity,
                        height: 11,
                        borderRadius: BorderRadius.circular(4)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _Shimmer(
                            width: 72,
                            height: 18,
                            borderRadius: BorderRadius.circular(9)),
                        const SizedBox(width: 8),
                        _Shimmer(
                            width: 80,
                            height: 22,
                            borderRadius: BorderRadius.circular(11)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              _Shimmer(
                  width: 72,
                  height: 72,
                  borderRadius: BorderRadius.circular(16)),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: const Color(0xFFF3F4F6)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    _Shimmer(
                        width: 14,
                        height: 14,
                        borderRadius: BorderRadius.circular(7)),
                    const SizedBox(width: 6),
                    _Shimmer(
                        width: 80,
                        height: 12,
                        borderRadius: BorderRadius.circular(4)),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    _Shimmer(
                        width: 14,
                        height: 14,
                        borderRadius: BorderRadius.circular(7)),
                    const SizedBox(width: 6),
                    _Shimmer(
                        width: 80,
                        height: 12,
                        borderRadius: BorderRadius.circular(4)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: const Color(0xFFF3F4F6)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Shimmer(
                      width: 60,
                      height: 10,
                      borderRadius: BorderRadius.circular(4)),
                  const SizedBox(height: 4),
                  _Shimmer(
                      width: 70,
                      height: 16,
                      borderRadius: BorderRadius.circular(4)),
                ],
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Shimmer(
                      width: 55,
                      height: 10,
                      borderRadius: BorderRadius.circular(4)),
                  const SizedBox(height: 4),
                  _Shimmer(
                      width: 30,
                      height: 16,
                      borderRadius: BorderRadius.circular(4)),
                ],
              ),
              const Spacer(),
              _Shimmer(
                  width: 110,
                  height: 42,
                  borderRadius: BorderRadius.circular(21)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SKELETON — LIST  (3 placeholder cards)
// ─────────────────────────────────────────────────────────────────────────────

class _HelperListSkeleton extends StatelessWidget {
  const _HelperListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, __) => const _HelperCardSkeleton(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NO INTERNET VIEW
// ─────────────────────────────────────────────────────────────────────────────

class _NoInternetView extends StatefulWidget {
  final VoidCallback onRetry;
  final Color color;
  const _NoInternetView({required this.onRetry, required this.color});

  @override
  State<_NoInternetView> createState() => _NoInternetViewState();
}

class _NoInternetViewState extends State<_NoInternetView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1800))
      ..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => SizedBox(
                width: 110,
                height: 110,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: (1 - _pulse.value).clamp(0.0, 0.25),
                      child: Container(
                        width: 100 * (0.7 + 0.3 * _pulse.value),
                        height: 100 * (0.7 + 0.3 * _pulse.value),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFDC2626).withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFEE2E2), Color(0xFFFFCDD2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFDC2626).withOpacity(0.18),
                            blurRadius: 18,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.wifi_off_rounded,
                          size: 34, color: Color(0xFFDC2626)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'No Internet Connection',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Helpers will load automatically\nwhen you\'re back online.',
              style: TextStyle(
                  fontSize: 13, color: Color(0xFF6B7280), height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                onPressed: widget.onRetry,
                icon: const Icon(Icons.refresh_rounded,
                    size: 18, color: Colors.white),
                label: const Text('Retry',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.color,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(23)),
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER LIST SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class HelperListScreen extends StatefulWidget {
  final String serviceName;
  final String categoryName;
  final List<SubServiceItem> subServices;
  final Color serviceColor;
  final Color serviceBgColor;
  final String categoryEmoji;

  const HelperListScreen({
    super.key,
    required this.serviceName,
    required this.categoryName,
    required this.subServices,
    required this.serviceColor,
    required this.serviceBgColor,
    required this.categoryEmoji,
  });

  @override
  State<HelperListScreen> createState() => _HelperListScreenState();
}

class _HelperListScreenState extends State<HelperListScreen>
    with SingleTickerProviderStateMixin {
  late int _selectedSubIndex;
  String _sortBy = 'Rating';

  // Connectivity
  bool _hasInternet = true;
  bool _isCheckingInternet = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  // Header fade animation
  late final AnimationController _headerAnim;
  late final Animation<double> _headerFade;

  String get _activeService =>
      widget.subServices[_selectedSubIndex].name;

  @override
  void initState() {
    super.initState();
    _selectedSubIndex = widget.subServices
        .indexWhere((s) => s.name == widget.serviceName);
    if (_selectedSubIndex < 0) _selectedSubIndex = 0;

    _headerAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _headerFade =
        CurvedAnimation(parent: _headerAnim, curve: Curves.easeOut);
    _headerAnim.forward();

    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    setState(() => _isCheckingInternet = true);
    try {
      final results = await Connectivity().checkConnectivity();
      if (mounted) {
        setState(() {
          _hasInternet =
              results.any((r) => r != ConnectivityResult.none);
          _isCheckingInternet = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isCheckingInternet = false);
    }
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((results) {
          if (!mounted) return;
          setState(() => _hasInternet =
              results.any((r) => r != ConnectivityResult.none));
        });
  }

  @override
  void dispose() {
    _headerAnim.dispose();
    _connectivitySub?.cancel();
    super.dispose();
  }

  // ── Firestore stream ────────────────────────────────────────────────
  //
  // FIX 2 of 3: The original query used .where('approved', isEqualTo: true)
  // which NEVER matches anything — the admin panel does not write an 'approved'
  // field. It writes:
  //   • kycStatus = 'approved'   when admin approves KYC
  //   • isAvailable = true       when admin activates the helper
  // Both must be true for a helper to appear in the user-facing list.
  //
  // IMPORTANT — Composite index required in Firebase Console:
  //   Firestore → Indexes → Composite → Add index
  //   Collection: helpers
  //   Fields:     serviceType (Ascending)
  //               kycStatus   (Ascending)
  //               isAvailable (Ascending)
  // ───────────────────────────────────────────────────────────────────

  Stream<List<HelperModel>> _helpersStream(String sidebarName) {
    final normalized = sidebarName.trim().toLowerCase();

    // Fetch ALL helpers with no filter — match everything in-memory
    // This avoids any Firestore field name / value mismatch
    return FirebaseFirestore.instance
        .collection('helpers')
        .snapshots()
        .asyncMap((snap) async {
      final matched = snap.docs.where((doc) {
        final d = doc.data();

        // ── KYC check: accept any approved variation
        final kyc = (d['kycStatus'] as String? ?? '').toLowerCase();
        final isKycOk = kyc == 'approved' ||
            kyc == 'verified' ||
            kyc == 'active' ||
            (d['isApproved'] == true) ||
            (d['kycApproved'] == true);

        if (!isKycOk) return false;

        // ── Service match: case-insensitive across all service fields
        final services = List<String>.from(d['services'] ?? []);
        final serviceMatch = services.any(
              (s) => s.trim().toLowerCase() == normalized,
        );

        final serviceType =
        (d['serviceType'] as String? ?? '').trim().toLowerCase();
        final typeMatch = serviceType == normalized;

        final subcategory =
        (d['subcategory'] as String? ?? '').trim().toLowerCase();
        final subMatch = subcategory == normalized;

        // ── Partial match fallback: e.g. "plumber" matches "plumbing"
        final partialMatch = services.any((s) =>
        s.trim().toLowerCase().contains(normalized) ||
            normalized.contains(s.trim().toLowerCase())) ||
            serviceType.contains(normalized) ||
            normalized.contains(serviceType);

        return serviceMatch || typeMatch || subMatch || partialMatch;
      }).toList();

      // Debug — remove after confirming helpers show
      debugPrint('=== HELPER DEBUG ===');
      debugPrint('Total docs in helpers: ${snap.docs.length}');
      debugPrint('Matched for "$sidebarName": ${matched.length}');
      if (snap.docs.isNotEmpty) {
        final sample = snap.docs.first.data();
        debugPrint('Sample doc fields: kycStatus=${sample['kycStatus']}, '
            'isOnline=${sample['isOnline']}, '
            'services=${sample['services']}, '
            'serviceType=${sample['serviceType']}');
      }

      return matched.map((doc) {
        try {
          final data = Map<String, dynamic>.from(doc.data());

          // Normalize location
          if (data['location'] is! String ||
              (data['location'] as String).isEmpty ||
              (data['location'] as String).contains('[object')) {
            data['location'] = data['area'] ?? 'Location not set';
          }

          // Normalize completedJobs
          data['completedJobs'] =
              data['completedJobs'] ?? data['totalJobs'] ?? 0;

          // Normalize phone
          data['phoneNumber'] =
              data['phoneNumber'] ?? data['phone'] ?? '';

          // Normalize profileImage
          data['profileImage'] = data['profileImage'] ??
              data['profileUrl'] ??
              data['photoUrl'];

          // Sync isOnline → isAvailable
          if (data['isOnline'] == true) {
            data['isAvailable'] = true;
          }

          // Normalize experience to string
          if (data['experience'] is int || data['experience'] is double) {
            data['experience'] = '${data['experience']} yrs';
          }

          // Normalize pricePerVisit
          data['pricePerVisit'] =
              data['pricePerVisit'] ?? data['pricePerHour'] ?? 0;

          return HelperModel.fromFirestore(data, doc.id);
        } catch (e) {
          debugPrint('Error parsing helper ${doc.id}: $e');
          return null;
        }
      }).whereType<HelperModel>().toList();
    });
  }

  // ── Sort helpers ────────────────────────────────────────────────────

  List<HelperModel> _sorted(List<HelperModel> list) {
    final copy = List<HelperModel>.from(list);
    switch (_sortBy) {
      case 'Rating':
        copy.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'Price':
        copy.sort((a, b) => a.pricePerVisit.compareTo(b.pricePerVisit));
        break;
      case 'Experience':
        copy.sort((a, b) {
          int parse(String s) =>
              int.tryParse(
                  RegExp(r'(\d+)').firstMatch(s)?.group(1) ?? '0') ??
                  0;
          return parse(b.experience).compareTo(parse(a.experience));
        });
        break;
    }
    return copy;
  }

  // ── Open profile sheet ──────────────────────────────────────────────

  void _openProfile(HelperModel helper) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _HelperProfileSheet(
        helper: helper,
        serviceColor: widget.serviceColor,
        serviceBgColor: widget.serviceBgColor,
        categoryName: widget.categoryName,
        subServices: widget.subServices,
      ),
    );
  }

  // ── Sort bottom sheet ───────────────────────────────────────────────

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Sort By',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937))),
                const SizedBox(height: 12),
                for (final opt in ['Rating', 'Price', 'Experience'])
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Radio<String>(
                      value: opt,
                      groupValue: _sortBy,
                      activeColor: widget.serviceColor,
                      onChanged: (v) {
                        setState(() => _sortBy = v!);
                        setSheet(() {});
                        Navigator.pop(ctx);
                      },
                    ),
                    title: Text(opt,
                        style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1F2937))),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F4F8),
        body: Column(
          children: [
            // ── Top Bar ──────────────────────────────────────────────
            FadeTransition(
              opacity: _headerFade,
              child: _TopBar(
                title: widget.categoryName,
                serviceColor: widget.serviceColor,
                serviceBgColor: widget.serviceBgColor,
                onBack: () => Navigator.pop(context),
                onFilter: _showSortSheet,
              ),
            ),

            // ── Body ─────────────────────────────────────────────────
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Sidebar ─────────────────────────────────────
                  _SideBar(
                    items: widget.subServices,
                    selected: _selectedSubIndex,
                    serviceColor: widget.serviceColor,
                    onSelect: (i) =>
                        setState(() => _selectedSubIndex = i),
                  ),

                  // ── Main content area ────────────────────────────
                  Expanded(
                    child: _isCheckingInternet
                        ? const _HelperListSkeleton()
                        : !_hasInternet
                        ? _NoInternetView(
                      color: widget.serviceColor,
                      onRetry: _initConnectivity,
                    )
                        : StreamBuilder<List<HelperModel>>(
                      stream: _helpersStream(_activeService),
                      builder: (context, snap) {
                        // Loading
                        if (snap.connectionState ==
                            ConnectionState.waiting) {
                          return const _HelperListSkeleton();
                        }
                        // Error
                        if (snap.hasError) {
                          return _ErrorState(
                            error: snap.error.toString(),
                            color: widget.serviceColor,
                          );
                        }

                        final helpers =
                        _sorted(snap.data ?? []);

                        // Empty
                        if (helpers.isEmpty) {
                          return _EmptyState(
                            serviceName: _activeService,
                            serviceColor: widget.serviceColor,
                          );
                        }

                        final availableCount = helpers
                            .where((h) => h.isAvailable)
                            .length;

                        return Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            _CountBar(
                              total: helpers.length,
                              available: availableCount,
                              serviceColor: widget.serviceColor,
                            ),
                            Expanded(
                              child: ListView.separated(
                                padding:
                                const EdgeInsets.fromLTRB(
                                    14, 0, 14, 100),
                                physics:
                                const ClampingScrollPhysics(),
                                itemCount: helpers.length,
                                separatorBuilder: (_, __) =>
                                const SizedBox(height: 14),
                                itemBuilder: (_, i) =>
                                    RepaintBoundary(
                                      child: _HelperCard(
                                        helper: helpers[i],
                                        serviceColor:
                                        widget.serviceColor,
                                        serviceBgColor:
                                        widget.serviceBgColor,
                                        onTap: () =>
                                            _openProfile(helpers[i]),
                                      ),
                                    ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP BAR
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final String title;
  final Color serviceColor;
  final Color serviceBgColor;
  final VoidCallback onBack, onFilter;

  const _TopBar({
    required this.title,
    required this.serviceColor,
    required this.serviceBgColor,
    required this.onBack,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: serviceColor.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 12, 10),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: serviceBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      size: 16, color: serviceColor),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827))),
                    Text('Browse & book verified helpers',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onFilter,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: serviceBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.tune_rounded,
                      size: 18, color: serviceColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COUNT BAR
// ─────────────────────────────────────────────────────────────────────────────

class _CountBar extends StatelessWidget {
  final int total, available;
  final Color serviceColor;

  const _CountBar({
    required this.total,
    required this.available,
    required this.serviceColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AVAILABLE HELPERS',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey.shade500,
                      letterSpacing: 1.2)),
              const SizedBox(height: 2),
              Text('$total found nearby',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937))),
            ],
          ),
          const Spacer(),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: serviceColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border:
              Border.all(color: serviceColor.withOpacity(0.18)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                      color: serviceColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text('$available Online',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: serviceColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SIDEBAR  — 72 px wide, icons perfectly centred
// ─────────────────────────────────────────────────────────────────────────────

class _SideBar extends StatelessWidget {
  final List<SubServiceItem> items;
  final int selected;
  final Color serviceColor;
  final ValueChanged<int> onSelect;

  const _SideBar({
    required this.items,
    required this.selected,
    required this.serviceColor,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 10),
        physics: const ClampingScrollPhysics(),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final active = i == selected;
          final item = items[i];
          return GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(
                  vertical: 2, horizontal: 6),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: active
                    ? serviceColor.withOpacity(0.09)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: active
                                ? serviceColor.withOpacity(0.14)
                                : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Center(
                            child: Icon(item.icon,
                                size: 20,
                                color: active
                                    ? serviceColor
                                    : const Color(0xFF9CA3AF)),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4),
                          child: Text(
                            item.name.toUpperCase(),
                            style: TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.w800,
                                color: active
                                    ? serviceColor
                                    : const Color(0xFFB0B8C8),
                                letterSpacing: 0.3),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Active left-edge accent bar
                  if (active)
                    Positioned(
                      left: -6,
                      top: 6,
                      bottom: 6,
                      child: Container(
                        width: 3,
                        decoration: BoxDecoration(
                          color: serviceColor,
                          borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(4)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER CARD  — all internal widgets scaled 20% smaller
// ─────────────────────────────────────────────────────────────────────────────

class _HelperCard extends StatefulWidget {
  final HelperModel helper;
  final Color serviceColor;
  final Color serviceBgColor;
  final VoidCallback onTap;

  const _HelperCard({
    required this.helper,
    required this.serviceColor,
    required this.serviceBgColor,
    required this.onTap,
  });

  @override
  State<_HelperCard> createState() => _HelperCardState();
}

class _HelperCardState extends State<_HelperCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final h = widget.helper;
    final color = widget.serviceColor;
    final bgColor = widget.serviceBgColor;
    final initial = h.name.isNotEmpty ? h.name[0].toUpperCase() : '?';

    // ── Resolve display label: prefer subcategory → serviceType → 'Helper'
    final serviceLabel = (h.subcategory?.isNotEmpty == true
        ? h.subcategory!
        : h.serviceType.isNotEmpty
        ? h.serviceType
        : 'Helper')
        .toUpperCase();

    // ── Resolve experience display
    final expLabel = h.experience.isNotEmpty ? h.experience.toUpperCase() : '—';

    // ── Resolve location display
    final locationLabel = (h.location.isNotEmpty &&
        !h.location.contains('[object'))
        ? h.location
        : 'Location not set';

    // ── Resolve phone display
    final phoneLabel = h.phoneNumber.isNotEmpty
        ? h.phoneNumber
        : '—';

    // ── Resolve jobs count: completedJobs or totalJobs
    final jobsDone = h.completedJobs;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        if (h.isAvailable) {
          widget.onTap();
        } else if (!h.isBookingBlocked) {
          widget.onTap();
        }
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()..scale(_pressed ? 0.97 : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_pressed ? 0.04 : 0.07),
              blurRadius: _pressed ? 4 : 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── SECTION 1: Name + badge  |  Avatar ─────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                h.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF111827),
                                  letterSpacing: -0.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const _VerifiedBadge(size: 15),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$serviceLabel • $expLabel',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500,
                            letterSpacing: 0.1,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 13, color: Color(0xFFFBBF24)),
                            const SizedBox(width: 2),
                            Text(
                              h.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            Text(
                              ' Rating',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade400),
                            ),
                            const SizedBox(width: 6),
                            _AvailabilityPill(
                              isAvailable: h.isAvailable,
                              isBlocked: h.isBookingBlocked,
                              bookableFrom: h.bookableFrom,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 11),
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                          color: color.withOpacity(0.15), width: 1.5),
                    ),
                    child: h.profileImage != null
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        h.profileImage!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(initial,
                              style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.bold,
                                  color: color)),
                        ),
                      ),
                    )
                        : Center(
                      child: Text(initial,
                          style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                              color: color)),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 11),
              Container(height: 1, color: const Color(0xFFF0F0F5)),
              const SizedBox(height: 10),

              // ── SECTION 2: Phone  |  Location ───────────────────────
              Row(
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(Icons.phone_outlined,
                            size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            phoneLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            locationLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),
              Container(height: 1, color: const Color(0xFFF0F0F5)),
              const SizedBox(height: 10),

              // ── SECTION 3: Starting At  |  Jobs Done  |  Book Now ───
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PRICE/VISIT',
                          style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade500,
                              letterSpacing: 0.5)),
                      const SizedBox(height: 2),
                      Text(
                        '₹${h.pricePerVisit.toInt()}/visit',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('JOBS DONE',
                          style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade500,
                              letterSpacing: 0.5)),
                      const SizedBox(height: 2),
                      Text(
                        '$jobsDone',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),

                  // ── Book Now / Blocked / Notify Me button ───────────
                  GestureDetector(
                    onTap: () {
                      if (h.isAvailable) {
                        widget.onTap();
                      } else if (h.isBookingBlocked) {
                        final remaining = 60 - h.offlineDuration.inMinutes;
                        final bookableAt = h.bookableFrom != null
                            ? '${h.bookableFrom!.hour}:${h.bookableFrom!.minute.toString().padLeft(2, '0')}'
                            : 'later';
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${h.name} is offline. Booking available after $bookableAt ($remaining min remaining).',
                            ),
                            backgroundColor: const Color(0xFFDC2626),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                        );
                      } else {
                        // Offline but 1 hour passed — allow booking
                        widget.onTap();
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 130),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        gradient: h.isAvailable
                            ? LinearGradient(
                          colors: [
                            color,
                            Color.lerp(color,
                                const Color(0xFF4C1D95), 0.45)!,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                            : h.isBookingBlocked
                            ? const LinearGradient(
                          colors: [
                            Color(0xFFDC2626),
                            Color(0xFFEF4444),
                          ],
                        )
                            : const LinearGradient(
                          colors: [
                            Color(0xFFD1D5DB),
                            Color(0xFFE5E7EB),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: h.isAvailable
                            ? [
                          BoxShadow(
                            color: color.withOpacity(0.32),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ]
                            : h.isBookingBlocked
                            ? [
                          BoxShadow(
                            color: const Color(0xFFDC2626)
                                .withOpacity(0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                            : [],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            h.isAvailable
                                ? Icons.calendar_month_rounded
                                : h.isBookingBlocked
                                ? Icons.lock_clock_outlined
                                : Icons.notifications_outlined,
                            size: 13,
                            color: h.isAvailable || h.isBookingBlocked
                                ? Colors.white
                                : const Color(0xFF9CA3AF),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            h.isAvailable
                                ? 'Book Now'
                                : h.isBookingBlocked
                                ? 'Blocked'
                                : 'Notify Me',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: h.isAvailable || h.isBookingBlocked
                                  ? Colors.white
                                  : const Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER PROFILE SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _HelperProfileSheet extends StatelessWidget {
  final HelperModel helper;
  final Color serviceColor;
  final Color serviceBgColor;
  final String categoryName;
  final List<SubServiceItem> subServices;

  const _HelperProfileSheet({
    required this.helper,
    required this.serviceColor,
    required this.serviceBgColor,
    required this.categoryName,
    required this.subServices,
  });

  @override
  Widget build(BuildContext context) {
    final h = helper;
    final color = serviceColor;
    final bgColor = serviceBgColor;
    final initial = h.name.isNotEmpty ? h.name[0].toUpperCase() : '?';

    // ── FIX 3: Resolve display label: subcategory → serviceType → 'Helper'
    final serviceLabel = h.subcategory?.isNotEmpty == true
        ? h.subcategory!
        : h.serviceType.isNotEmpty
        ? h.serviceType
        : 'Helper';

    // ── FIX: Sanitize location
    final locationLabel =
    (h.location.isNotEmpty && !h.location.contains('[object'))
        ? h.location
        : 'Location not set';

    // ── FIX: Normalize phone
    final phoneLabel = h.phoneNumber.isNotEmpty ? h.phoneNumber : '—';

    // ── FIX: Normalize jobs
    final jobsDone = h.completedJobs;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      snap: true,
      snapSizes: const [0.88, 0.95],
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
                color: Color(0x14000000),
                blurRadius: 30,
                offset: Offset(0, -4)),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                controller: scrollCtrl,
                physics: const ClampingScrollPhysics(),
                slivers: [
                  // Handle bar
                  SliverToBoxAdapter(
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 10, bottom: 4),
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                  ),

                  // Close + title
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(ctx),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                  color: Color(0xFFF3F4F6),
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.close_rounded,
                                  size: 18, color: Color(0xFF4B5563)),
                            ),
                          ),
                          const Expanded(
                            child: Text('Helper Profile',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1F2937))),
                          ),
                          const SizedBox(width: 36),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(
                      child: Divider(height: 1, color: Color(0xFFF3F4F6))),

                  // Hero card
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [bgColor, Colors.white],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border:
                          Border.all(color: color.withOpacity(0.12)),
                          boxShadow: [
                            BoxShadow(
                                color: color.withOpacity(0.08),
                                blurRadius: 16,
                                offset: const Offset(0, 5)),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  // Name + verified badge
                                  Row(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        child: Text(h.name,
                                            style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color:
                                                Color(0xFF111827))),
                                      ),
                                      const SizedBox(width: 7),
                                      const _VerifiedBadge(size: 22),
                                    ],
                                  ),
                                  const SizedBox(height: 5),

                                  // ── FIX 3: subcategory → serviceType → 'Helper'
                                  Text(
                                    '$serviceLabel specialist with ${h.experience} of experience',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                        height: 1.5),
                                  ),
                                  const SizedBox(height: 10),

                                  // Rating + availability
                                  Row(children: [
                                    const Icon(Icons.star_rounded,
                                        size: 15,
                                        color: Color(0xFFFBBF24)),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${h.rating.toStringAsFixed(1)} Rating',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1F2937)),
                                    ),
                                    const SizedBox(width: 10),
                                    _AvailabilityPill(
                                        isAvailable: h.isAvailable),
                                  ]),

                                  // Phone — FIX: normalized
                                  if (phoneLabel != '—') ...[
                                    const SizedBox(height: 8),
                                    Row(children: [
                                      Icon(Icons.phone_outlined,
                                          size: 13,
                                          color: Colors.grey.shade500),
                                      const SizedBox(width: 6),
                                      Text(phoneLabel,
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade700,
                                              fontWeight:
                                              FontWeight.w500)),
                                    ]),
                                  ],

                                  const SizedBox(height: 5),

                                  // Location — FIX: sanitized
                                  Row(children: [
                                    Icon(Icons.location_on_outlined,
                                        size: 13,
                                        color: Colors.grey.shade500),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(locationLabel,
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade700,
                                              fontWeight:
                                              FontWeight.w500)),
                                    ),
                                  ]),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Avatar
                            Stack(
                              children: [
                                Container(
                                  width: 88,
                                  height: 88,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: bgColor,
                                    border: Border.all(
                                        color: color.withOpacity(0.2),
                                        width: 2.5),
                                    boxShadow: [
                                      BoxShadow(
                                          color: color.withOpacity(0.12),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4)),
                                    ],
                                  ),
                                  child: h.profileImage != null
                                      ? ClipOval(
                                    child: Image.network(
                                      h.profileImage!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          Center(
                                            child: Text(initial,
                                                style: TextStyle(
                                                    fontSize: 30,
                                                    fontWeight:
                                                    FontWeight.bold,
                                                    color: color)),
                                          ),
                                    ),
                                  )
                                      : Center(
                                    child: Text(initial,
                                        style: TextStyle(
                                            fontSize: 30,
                                            fontWeight:
                                            FontWeight.bold,
                                            color: color)),
                                  ),
                                ),
                                if (h.isAvailable)
                                  Positioned(
                                    right: 3,
                                    bottom: 3,
                                    child: Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF22C55E),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 2),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 18)),

                  // Stats row — FIX: jobsDone normalized
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        children: [
                          _StatBubble(
                            label: 'RATING',
                            value: h.rating.toStringAsFixed(1),
                            sub: 'out of 5',
                            color: const Color(0xFFFBBF24),
                            icon: Icons.star_rounded,
                          ),
                          const SizedBox(width: 10),
                          _StatBubble(
                            label: 'EXPERIENCE',
                            value: h.experience.isNotEmpty
                                ? h.experience
                                : '—',
                            sub: 'in field',
                            color: color,
                            icon: Icons.workspace_premium_rounded,
                          ),
                          const SizedBox(width: 10),
                          _StatBubble(
                            label: 'JOBS',
                            value: '$jobsDone', // ── FIX: normalized
                            sub: 'completed',
                            color: const Color(0xFF16A34A),
                            icon: Icons.check_circle_outline_rounded,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Skills & Specialties
                  if (h.skills.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Skills & Specialties',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1F2937))),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: h.skills
                                  .map((s) => Container(
                                padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 7),
                                decoration: BoxDecoration(
                                  color:
                                  color.withOpacity(0.08),
                                  borderRadius:
                                  BorderRadius.circular(20),
                                  border: Border.all(
                                      color: color
                                          .withOpacity(0.2)),
                                ),
                                child: Text(s,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight:
                                        FontWeight.w600,
                                        color: color)),
                              ))
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Pricing card
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              color.withOpacity(0.06),
                              color.withOpacity(0.02),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: color.withOpacity(0.14)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(Icons.currency_rupee_rounded,
                                  size: 22, color: color),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text('Price per Visit',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: color,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 2),
                                  const Text(
                                      'Final price depends on job complexity',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF9CA3AF))),
                                ],
                              ),
                            ),
                            Text(
                              '₹${h.pricePerVisit.toInt()}',
                              style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: color),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Fixed bottom — Book Now button
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 16,
                      offset: Offset(0, -4)),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      if (h.isAvailable) {
                        showBookNowSheet(
                          context: context,
                          helperName: h.name,
                          helperId: h.id,
                          helperRating: h.rating,
                          helperJobCount: jobsDone, // ── FIX: normalized
                          serviceName: serviceLabel, // ── FIX: subcategory label
                          categoryName: categoryName,
                          serviceColor: serviceColor,
                          serviceBgColor: serviceBgColor,
                          serviceIcon: Icons.build_rounded,
                          pricePerHour: h.pricePerVisit,
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                '${h.name} is currently busy. You\'ll be notified when available.'),
                            backgroundColor: const Color(0xFF6B7280),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                        );
                      }
                    },
                    icon: Icon(
                      h.isAvailable
                          ? Icons.calendar_month_rounded
                          : Icons.notifications_outlined,
                      size: 20,
                      color: Colors.white,
                    ),
                    label: Text(
                      h.isAvailable
                          ? 'Book Now'
                          : 'Notify Me When Available',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: h.isAvailable
                          ? serviceColor
                          : const Color(0xFF6B7280),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AVAILABILITY PILL
// ─────────────────────────────────────────────────────────────────────────────

class _AvailabilityPill extends StatelessWidget {
  final bool isAvailable;
  final bool isBlocked;
  final DateTime? bookableFrom;

  const _AvailabilityPill({
    required this.isAvailable,
    this.isBlocked = false,
    this.bookableFrom,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color borderColor;
    final Color dotColor;
    final Color textColor;
    final String label;

    if (isAvailable) {
      bgColor = const Color(0xFFEFF6FF);
      borderColor = const Color(0xFFBFDBFE);
      dotColor = const Color(0xFF22C55E);
      textColor = const Color(0xFF16A34A);
      label = 'AVAILABLE';
    } else if (isBlocked) {
      bgColor = const Color(0xFFFEF2F2);
      borderColor = const Color(0xFFFECACA);
      dotColor = const Color(0xFFDC2626);
      textColor = const Color(0xFFDC2626);
      final t = bookableFrom;
      label = t != null
          ? 'FROM ${t.hour}:${t.minute.toString().padLeft(2, '0')}'
          : 'BLOCKED';
    } else {
      bgColor = const Color(0xFFFFF7ED);
      borderColor = const Color(0xFFFED7AA);
      dotColor = const Color(0xFFF97316);
      textColor = const Color(0xFFF97316);
      label = 'BUSY';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STAT BUBBLE  (used in profile sheet)
// ─────────────────────────────────────────────────────────────────────────────

class _StatBubble extends StatelessWidget {
  final String label, value, sub;
  final Color color;
  final IconData icon;

  const _StatBubble({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding:
        const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF0F0F0)),
        ),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9CA3AF),
                    letterSpacing: 0.8)),
            const SizedBox(height: 6),
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937)),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(sub,
                style: const TextStyle(
                    fontSize: 9, color: Color(0xFF9CA3AF))),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String serviceName;
  final Color serviceColor;
  const _EmptyState(
      {required this.serviceName, required this.serviceColor});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                  color: serviceColor.withOpacity(0.10),
                  shape: BoxShape.circle),
              child: Icon(Icons.search_off_rounded,
                  size: 38, color: serviceColor),
            ),
            const SizedBox(height: 20),
            Text('No helpers for\n"$serviceName"',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937)),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
                'Check back soon or try a different service.',
                style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF9CA3AF),
                    height: 1.5),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ERROR STATE
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String error;
  final Color color;
  const _ErrorState({required this.error, required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                  color: Color(0xFFFEE2E2), shape: BoxShape.circle),
              child: const Icon(Icons.cloud_off_rounded,
                  size: 36, color: Color(0xFFDC2626)),
            ),
            const SizedBox(height: 16),
            const Text('Could not load helpers',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937))),
            const SizedBox(height: 8),
            Text(error,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF9CA3AF)),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}