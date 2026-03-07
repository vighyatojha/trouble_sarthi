import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

enum BookingStatus { pending, active, completed, cancelled }

class BookingModel {
  final String id;
  final String firestoreId;
  final String serviceName;
  final String categoryName;
  final IconData serviceIcon;
  final Color serviceColor;
  final Color serviceBgColor;
  final BookingStatus status;
  final String helperName;
  final double? helperRating;
  final String address;
  final DateTime scheduledAt;
  final DateTime? completedAt;
  final double baseAmount;
  final double? totalAmount;
  final String? helperImageUrl;
  final int? helperJobCount;
  final String? helperEmployeeId;
  final List<String>? tasksDone;
  final String? helperId;

  const BookingModel({
    required this.id,
    this.firestoreId = '',
    required this.serviceName,
    required this.categoryName,
    required this.serviceIcon,
    required this.serviceColor,
    required this.serviceBgColor,
    required this.status,
    required this.helperName,
    this.helperRating,
    required this.address,
    required this.scheduledAt,
    this.completedAt,
    required this.baseAmount,
    this.totalAmount,
    this.helperImageUrl,
    this.helperJobCount,
    this.helperEmployeeId,
    this.tasksDone,
    this.helperId,
  });

  factory BookingModel.fromFirestore(
      Map<String, dynamic> data, String docId) {
    BookingStatus status;
    switch (data['status'] as String? ?? 'pending') {
      case 'active':
        status = BookingStatus.active;
        break;
      case 'completed':
        status = BookingStatus.completed;
        break;
      case 'cancelled':
        status = BookingStatus.cancelled;
        break;
      default:
        status = BookingStatus.pending;
    }

    final colorVal = data['serviceColor'] as int? ?? 0xFF7C3AED;
    final bgColorVal = data['serviceBgColor'] as int? ?? 0xFFEDE9FE;

    return BookingModel(
      id: data['bookingCode'] as String? ?? docId.substring(0, 8).toUpperCase(),
      firestoreId: docId,
      serviceName: data['serviceName'] as String? ?? '',
      categoryName: data['categoryName'] as String? ?? '',
      serviceIcon: Icons.build_rounded,
      serviceColor: Color(colorVal),
      serviceBgColor: Color(bgColorVal),
      status: status,
      helperName: data['helperName'] as String? ?? 'Awaiting Assignment',
      helperRating: (data['helperRating'] as num?)?.toDouble(),
      address: data['address'] as String? ?? '',
      scheduledAt: (data['scheduledAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      baseAmount: (data['baseAmount'] as num?)?.toDouble() ?? 0,
      totalAmount: (data['totalAmount'] as num?)?.toDouble(),
      helperJobCount: data['helperJobCount'] as int?,
      helperEmployeeId: data['helperEmployeeId'] as String?,
      tasksDone: (data['tasksDone'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      helperId: data['helperId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'bookingCode': id,
      'serviceName': serviceName,
      'categoryName': categoryName,
      'serviceColor': serviceColor.value,
      'serviceBgColor': serviceBgColor.value,
      'status': status.name,
      'helperName': helperName,
      'helperRating': helperRating,
      'address': address,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'completedAt':
      completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'baseAmount': baseAmount,
      'totalAmount': totalAmount,
      'helperJobCount': helperJobCount,
      'helperEmployeeId': helperEmployeeId,
      'tasksDone': tasksDone,
      'helperId': helperId,
      'userId': FirebaseAuth.instance.currentUser?.uid,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SAVED ADDRESS MODEL
// ─────────────────────────────────────────────────────────────────────────────

class SavedAddress {
  final String id;
  final String label;       // Home, Work, Other
  final String area;
  final String houseNo;
  final String societyName;
  final String fullAddress;

  const SavedAddress({
    required this.id,
    required this.label,
    required this.area,
    required this.houseNo,
    required this.societyName,
    required this.fullAddress,
  });

  factory SavedAddress.fromFirestore(Map<String, dynamic> data, String docId) {
    return SavedAddress(
      id: docId,
      label: data['label'] as String? ?? 'Home',
      area: data['area'] as String? ?? '',
      houseNo: data['houseNo'] as String? ?? '',
      societyName: data['societyName'] as String? ?? '',
      fullAddress: data['fullAddress'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
    'label': label,
    'area': area,
    'houseNo': houseNo,
    'societyName': societyName,
    'fullAddress': fullAddress,
    'createdAt': FieldValue.serverTimestamp(),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// BOOKING SERVICE — Firestore CRUD
// ─────────────────────────────────────────────────────────────────────────────

class BookingService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String get _uid => _auth.currentUser?.uid ?? '';

  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(_uid).collection('bookings');

  static CollectionReference<Map<String, dynamic>> get _addressCol =>
      _db.collection('users').doc(_uid).collection('savedAddresses');

  /// Create a new booking in Firestore and send a notification
  static Future<String?> createBooking(BookingModel booking) async {
    try {
      final ref = await _col.add(booking.toFirestore());
      await _sendBookingConfirmedNotification(booking);
      return ref.id;
    } catch (e) {
      debugPrint('[BookingService] createBooking error: $e');
      return null;
    }
  }

  /// Sends a booking confirmed notification to the notifications collection
  static Future<void> _sendBookingConfirmedNotification(BookingModel booking) async {
    if (_uid.isEmpty) return;
    try {
      await _db
          .collection('notifications')
          .doc(_uid)
          .collection('items')
          .add({
        'type': 'booking_confirmed',
        'title': 'Booking Confirmed! 🎉',
        'body':
        'Your "${booking.serviceName}" booking with ${booking.helperName} is confirmed. Code: #${booking.id}',
        'bookingId': booking.id,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[BookingService] notification error: $e');
    }
  }

  /// Cancel a booking
  static Future<bool> cancelBooking(String firestoreId) async {
    try {
      await _col.doc(firestoreId).update({'status': 'cancelled'});
      return true;
    } catch (e) {
      debugPrint('[BookingService] cancelBooking error: $e');
      return false;
    }
  }

  /// Stream of all bookings for the current user
  static Stream<List<BookingModel>> bookingsStream() {
    if (_uid.isEmpty) return const Stream.empty();
    return _col
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
        .map((doc) {
      try {
        return BookingModel.fromFirestore(doc.data(), doc.id);
      } catch (e) {
        debugPrint('[BookingService] parse error: $e');
        return null;
      }
    })
        .whereType<BookingModel>()
        .toList());
  }

  /// Fetch saved addresses for the current user
  static Future<List<SavedAddress>> getSavedAddresses() async {
    if (_uid.isEmpty) return [];
    try {
      final snap = await _addressCol
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs
          .map((d) => SavedAddress.fromFirestore(d.data(), d.id))
          .toList();
    } catch (e) {
      debugPrint('[BookingService] getSavedAddresses error: $e');
      return [];
    }
  }

  /// Save a new address to Firestore
  static Future<String?> saveAddress(SavedAddress address) async {
    try {
      final ref = await _addressCol.add(address.toFirestore());
      return ref.id;
    } catch (e) {
      debugPrint('[BookingService] saveAddress error: $e');
      return null;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHIMMER BOX (local – kept self-contained)
// ─────────────────────────────────────────────────────────────────────────────

class _Shimmer extends StatefulWidget {
  final double width, height;
  final BorderRadius? borderRadius;
  const _Shimmer({required this.width, required this.height, this.borderRadius});

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
    _ctrl =
    AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
    _anim = Tween<double>(begin: -1.5, end: 2.5)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine));
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
            colors: const [Color(0xFFEEEEF8), Color(0xFFF8F8FF), Color(0xFFEEEEF8)],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SKELETON — Bookings Screen
// ─────────────────────────────────────────────────────────────────────────────

class _BookingsSkeleton extends StatelessWidget {
  const _BookingsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      itemCount: 4,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: icon + title + status badge
              Row(
                children: [
                  _Shimmer(
                      width: 50,
                      height: 50,
                      borderRadius: BorderRadius.circular(14)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Shimmer(
                            width: 140,
                            height: 14,
                            borderRadius: BorderRadius.circular(6)),
                        const SizedBox(height: 8),
                        _Shimmer(
                            width: 100,
                            height: 11,
                            borderRadius: BorderRadius.circular(4)),
                      ],
                    ),
                  ),
                  _Shimmer(
                      width: 70,
                      height: 26,
                      borderRadius: BorderRadius.circular(20)),
                ],
              ),
              const SizedBox(height: 14),
              Container(height: 1, color: const Color(0xFFF3F4F6)),
              const SizedBox(height: 12),
              // Row 2: date + amount
              Row(
                children: [
                  _Shimmer(width: 90, height: 11, borderRadius: BorderRadius.circular(4)),
                  const Spacer(),
                  _Shimmer(width: 60, height: 14, borderRadius: BorderRadius.circular(4)),
                ],
              ),
              // Row 3: action buttons on first card only
              if (i == 0) ...[
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                      child: _Shimmer(
                          width: double.infinity,
                          height: 38,
                          borderRadius: BorderRadius.circular(14))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _Shimmer(
                          width: double.infinity,
                          height: 38,
                          borderRadius: BorderRadius.circular(14))),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NO INTERNET WIDGET (inline, for tabs)
// ─────────────────────────────────────────────────────────────────────────────

class _NoInternetView extends StatefulWidget {
  final VoidCallback onRetry;
  const _NoInternetView({required this.onRetry});

  @override
  State<_NoInternetView> createState() => _NoInternetViewState();
}

class _NoInternetViewState extends State<_NoInternetView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse =
    AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
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
              builder: (_, __) => Stack(
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
                            width: 2),
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
                            offset: const Offset(0, 5))
                      ],
                    ),
                    child: const Icon(Icons.wifi_off_rounded,
                        size: 34, color: Color(0xFFDC2626)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('No Internet Connection',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937))),
            const SizedBox(height: 8),
            const Text(
              'Your bookings will load\nonce you\'re back online.',
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
                label: const Text('Try Again',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(23)),
                  padding: const EdgeInsets.symmetric(horizontal: 28),
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
// DEMO BOOKINGS — 3 examples shown when no real data exists
// ─────────────────────────────────────────────────────────────────────────────

final List<BookingModel> _demoBookings = [
  BookingModel(
    id: 'TS-001234',
    firestoreId: 'demo_1',
    serviceName: 'Plumbing',
    categoryName: 'Home Repair',
    serviceIcon: Icons.water_drop_rounded,
    serviceColor: const Color(0xFF7C3AED),
    serviceBgColor: const Color(0xFFEDE9FE),
    status: BookingStatus.active,
    helperName: 'Ramesh Kumar',
    helperRating: 4.8,
    address: 'B-204, Sunshine Society, Vesu, Surat',
    scheduledAt: DateTime.now().subtract(const Duration(hours: 1)),
    baseAmount: 350,
    totalAmount: 385.80,
    helperJobCount: 128,
    helperEmployeeId: 'HLP-5821',
  ),
  BookingModel(
    id: 'TS-001198',
    firestoreId: 'demo_2',
    serviceName: 'Electrical',
    categoryName: 'Home Repair',
    serviceIcon: Icons.electrical_services_rounded,
    serviceColor: const Color(0xFF7C3AED),
    serviceBgColor: const Color(0xFFEDE9FE),
    status: BookingStatus.completed,
    helperName: 'Suresh Patel',
    helperRating: 4.5,
    address: 'A-12, Raj Residency, Adajan, Surat',
    scheduledAt: DateTime.now().subtract(const Duration(days: 2)),
    completedAt: DateTime.now().subtract(const Duration(days: 2, hours: -2)),
    baseAmount: 500,
    totalAmount: 535.80,
    helperJobCount: 210,
    tasksDone: [
      'Fixed faulty wiring in bedroom',
      'Replaced switchboard in kitchen',
      'Installed new ceiling fan',
    ],
  ),
  BookingModel(
    id: 'TS-001045',
    firestoreId: 'demo_3',
    serviceName: 'AC Repair',
    categoryName: 'Appliance',
    serviceIcon: Icons.ac_unit_rounded,
    serviceColor: const Color(0xFF7C3AED),
    serviceBgColor: const Color(0xFFEDE9FE),
    status: BookingStatus.pending,
    helperName: 'Awaiting Assignment',
    address: 'C-7, Green Park, Katargam, Surat',
    scheduledAt: DateTime.now().add(const Duration(hours: 3)),
    baseAmount: 400,
    totalAmount: 435.80,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// BOOKINGS SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  // Connectivity
  bool _hasInternet = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() =>
      _hasInternet = results.any((r) => r != ConnectivityResult.none));
    }
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((results) {
          if (!mounted) return;
          setState(() =>
          _hasInternet = results.any((r) => r != ConnectivityResult.none));
        });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _connectivitySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FB),
        body: Column(
          children: [
            _BookingsHeader(tabController: _tabController),
            Expanded(
              child: !_hasInternet
                  ? _NoInternetView(
                onRetry: () async {
                  final r = await Connectivity().checkConnectivity();
                  if (mounted) {
                    setState(() => _hasInternet =
                        r.any((x) => x != ConnectivityResult.none));
                  }
                },
              )
                  : StreamBuilder<List<BookingModel>>(
                stream: BookingService.bookingsStream(),
                builder: (context, snap) {
                  // Loading
                  if (snap.connectionState == ConnectionState.waiting) {
                    return TabBarView(
                      controller: _tabController,
                      children: const [
                        _BookingsSkeleton(),
                        _BookingsSkeleton(),
                        _BookingsSkeleton(),
                      ],
                    );
                  }

                  final realBookings = snap.data ?? [];
                  // Show demos when no real data
                  final all = realBookings.isEmpty ? _demoBookings : realBookings;

                  final current = all
                      .where((b) =>
                  b.status == BookingStatus.active ||
                      b.status == BookingStatus.pending)
                      .toList();
                  final completed = all
                      .where((b) => b.status == BookingStatus.completed)
                      .toList();
                  final cancelled = all
                      .where((b) => b.status == BookingStatus.cancelled)
                      .toList();

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _BookingsList(
                        bookings: current,
                        emptyLabel: 'No active or pending bookings',
                        isDemo: realBookings.isEmpty,
                      ),
                      _BookingsList(
                        bookings: completed,
                        emptyLabel: 'No completed bookings yet',
                        isDemo: realBookings.isEmpty,
                      ),
                      _BookingsList(
                        bookings: cancelled,
                        emptyLabel: 'No cancelled bookings',
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER WITH TAB BAR
// ─────────────────────────────────────────────────────────────────────────────

class _BookingsHeader extends StatelessWidget {
  final TabController tabController;
  const _BookingsHeader({required this.tabController});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E0640), Color(0xFF3B0764), Color(0xFF5B21B6)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'My Bookings',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Track & manage your service requests',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.6)),
                        ),
                      ],
                    ),
                  ),
                  // Active bookings count badge
                  StreamBuilder<List<BookingModel>>(
                    stream: BookingService.bookingsStream(),
                    builder: (_, snap) {
                      final allData = snap.data ?? [];
                      final activeCount = allData.isEmpty
                          ? _demoBookings
                          .where((b) =>
                      b.status == BookingStatus.active ||
                          b.status == BookingStatus.pending)
                          .length
                          : allData
                          .where((b) =>
                      b.status == BookingStatus.active ||
                          b.status == BookingStatus.pending)
                          .length;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.18)),
                        ),
                        child: Column(
                          children: [
                            Text('$activeCount',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20)),
                            Text('Active',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 10)),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TabBar(
              controller: tabController,
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF9D8EC7),
              labelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500),
              indicator: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Current'),
                Tab(text: 'Completed'),
                Tab(text: 'Cancelled'),
              ],
            ),
            Container(
              height: 22,
              decoration: const BoxDecoration(
                color: Color(0xFFF4F6FB),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
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
// BOOKINGS LIST
// ─────────────────────────────────────────────────────────────────────────────

class _BookingsList extends StatelessWidget {
  final List<BookingModel> bookings;
  final String emptyLabel;
  final bool isDemo;
  const _BookingsList({
    required this.bookings,
    required this.emptyLabel,
    this.isDemo = false,
  });

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) return _EmptyState(label: emptyLabel);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
      itemCount: bookings.length + (isDemo ? 1 : 0),
      itemBuilder: (_, i) {
        // Demo info banner at top
        if (isDemo && i == 0) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFFFBBF24).withOpacity(0.4)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded,
                  size: 16, color: Color(0xFFD97706)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Sample bookings shown for demo purposes',
                  style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFD97706),
                      fontWeight: FontWeight.w500),
                ),
              ),
            ]),
          );
        }

        final idx = isDemo ? i - 1 : i;
        final b = bookings[idx];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: b.status == BookingStatus.active
              ? _ActiveBookingCard(booking: b)
              : b.status == BookingStatus.completed
              ? _CompletedBookingCard(booking: b)
              : _BookingCard(booking: b),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVE BOOKING CARD
// ─────────────────────────────────────────────────────────────────────────────

class _ActiveBookingCard extends StatefulWidget {
  final BookingModel booking;
  const _ActiveBookingCard({required this.booking});

  @override
  State<_ActiveBookingCard> createState() => _ActiveBookingCardState();
}

class _ActiveBookingCardState extends State<_ActiveBookingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    return GestureDetector(
      onTap: () => _openDetails(context, b),
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, child) => Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1E0640),
                Color(0xFF3B0764),
                Color(0xFF6D28D9),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED)
                    .withOpacity(0.28 + 0.14 * _pulse.value),
                blurRadius: 22 + 8 * _pulse.value,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: child,
        ),
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            Positioned(
              left: -10,
              bottom: -20,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.04),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: icon + name + status + booking code
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Icon(b.serviceIcon,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b.serviceName,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                            const SizedBox(height: 4),
                            Row(children: [
                              _PulseDot(),
                              const SizedBox(width: 6),
                              const Text('IN PROGRESS',
                                  style: TextStyle(
                                      color: Color(0xFF86EFAC),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0)),
                            ]),
                          ],
                        ),
                      ),
                      _GlassChip(label: '#${b.id}'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                      height: 1,
                      color: Colors.white.withOpacity(0.15)),
                  const SizedBox(height: 16),
                  // Row 2: helper name + rating + employee ID
                  _IconRow(
                    icon: Icons.person_outline_rounded,
                    child: Row(children: [
                      Text(b.helperName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                      if (b.helperRating != null) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.star_rounded,
                            color: Color(0xFFFBBF24), size: 13),
                        const SizedBox(width: 2),
                        Text('${b.helperRating}',
                            style: const TextStyle(
                                color: Color(0xFFFBBF24),
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ],
                      const Spacer(),
                      if (b.helperEmployeeId != null)
                        Text(b.helperEmployeeId!,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 10)),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  // Row 3: address
                  _IconRow(
                    icon: Icons.location_on_outlined,
                    child: Text(b.address,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.72),
                            fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(height: 6),
                  // Row 4: scheduled time
                  _IconRow(
                    icon: Icons.access_time_rounded,
                    child: Text(
                        '${_formatDate(b.scheduledAt)} · ${_formatTime(b.scheduledAt)}',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.72),
                            fontSize: 12)),
                  ),
                  const SizedBox(height: 18),
                  // Row 5: Track + View Details buttons
                  Row(
                    children: [
                      Expanded(
                        child: _OutlineButton(
                          label: 'Track Helper',
                          icon: Icons.near_me_outlined,
                          onTap: () {},
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _FilledButton(
                          label: 'View Details',
                          icon: Icons.info_outline_rounded,
                          onTap: () => _openDetails(context, b),
                        ),
                      ),
                    ],
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
// PULSE DOT
// ─────────────────────────────────────────────────────────────────────────────

class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: Color.lerp(
              const Color(0xFF22C55E), const Color(0xFF86EFAC), _c.value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PENDING / CANCELLED BOOKING CARD
// ─────────────────────────────────────────────────────────────────────────────

class _BookingCard extends StatelessWidget {
  final BookingModel booking;
  const _BookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final isPending = b.status == BookingStatus.pending;

    return GestureDetector(
      onTap: () => _openDetails(context, b),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: b.serviceColor.withOpacity(0.07),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Row 1: icon + service/helper name + status badge
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: b.serviceBgColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(b.serviceIcon,
                        color: b.serviceColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.serviceName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFF1F2937))),
                        const SizedBox(height: 4),
                        Text(b.helperName,
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280))),
                      ],
                    ),
                  ),
                  _StatusBadge(status: b.status),
                ],
              ),
              const SizedBox(height: 14),
              Container(height: 1, color: const Color(0xFFF3F4F6)),
              const SizedBox(height: 12),
              // Row 2: date + time + amount
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 13, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 5),
                  Text(_formatDate(b.scheduledAt),
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280))),
                  const SizedBox(width: 12),
                  const Icon(Icons.access_time_rounded,
                      size: 13, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 5),
                  Text(_formatTime(b.scheduledAt),
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280))),
                  const Spacer(),
                  Text(
                      '₹${b.totalAmount?.toStringAsFixed(0) ?? b.baseAmount.toStringAsFixed(0)}',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: b.serviceColor)),
                ],
              ),
              // Row 3: Cancel + View Details (pending only)
              if (isPending) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: _ActionButton(
                      label: 'Cancel',
                      icon: Icons.cancel_outlined,
                      color: const Color(0xFFDC2626),
                      bgColor: const Color(0xFFFEE2E2),
                      onTap: () => _confirmCancel(context, b),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionButton(
                      label: 'View Details',
                      icon: Icons.info_outline_rounded,
                      color: b.serviceColor,
                      bgColor: b.serviceBgColor,
                      onTap: () => _openDetails(context, b),
                    ),
                  ),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPLETED BOOKING CARD
// ─────────────────────────────────────────────────────────────────────────────

class _CompletedBookingCard extends StatelessWidget {
  final BookingModel booking;
  const _CompletedBookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    return GestureDetector(
      onTap: () => _openDetails(context, b),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: icon + service/helper + rating + status badge
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: b.serviceBgColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(b.serviceIcon,
                        color: b.serviceColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.serviceName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFF1F2937))),
                        const SizedBox(height: 3),
                        Row(children: [
                          const Icon(Icons.person_outline_rounded,
                              size: 12, color: Color(0xFF9CA3AF)),
                          const SizedBox(width: 4),
                          Text(b.helperName,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280))),
                          if (b.helperRating != null) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.star_rounded,
                                size: 12,
                                color: Color(0xFFFBBF24)),
                            const SizedBox(width: 2),
                            Text('${b.helperRating}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFBBF24))),
                          ],
                        ]),
                      ],
                    ),
                  ),
                  const _StatusBadge(status: BookingStatus.completed),
                ],
              ),
              // Tasks done (up to 2)
              if (b.tasksDone != null && b.tasksDone!.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...b.tasksDone!.take(2).map((task) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded,
                            size: 11, color: Color(0xFF059669)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(task,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF374151)))),
                    ],
                  ),
                )),
              ],
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFF3F4F6)),
              const SizedBox(height: 12),
              // Row: total paid + Rebook + Invoice
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TOTAL PAID',
                          style: TextStyle(
                              fontSize: 9,
                              color: Color(0xFF9CA3AF),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8)),
                      const SizedBox(height: 2),
                      Text(
                          '₹${b.totalAmount?.toStringAsFixed(2) ?? b.baseAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937))),
                    ],
                  ),
                  const Spacer(),
                  _SmallButton(
                    label: 'Rebook',
                    icon: Icons.replay_rounded,
                    color: b.serviceColor,
                    onTap: () {},
                  ),
                  const SizedBox(width: 8),
                  _SmallButton(
                    label: 'Invoice',
                    icon: Icons.download_outlined,
                    color: const Color(0xFF6B7280),
                    onTap: () {},
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
// CANCEL CONFIRM DIALOG
// ─────────────────────────────────────────────────────────────────────────────

Future<void> _confirmCancel(BuildContext context, BookingModel b) async {
  if (b.firestoreId.isEmpty || b.firestoreId.startsWith('demo_')) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Demo booking — cannot cancel'),
      behavior: SnackBarBehavior.floating,
    ));
    return;
  }
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Cancel Booking?',
          style: TextStyle(fontWeight: FontWeight.bold)),
      content: Text(
          'Are you sure you want to cancel the booking for "${b.serviceName}"?',
          style: const TextStyle(color: Color(0xFF6B7280))),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep It')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          child: const Text('Yes, Cancel',
              style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    final ok = await BookingService.cancelBooking(b.firestoreId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? 'Booking cancelled successfully'
            : 'Failed to cancel. Try again.'),
        backgroundColor:
        ok ? const Color(0xFF059669) : const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOOKING DETAILS BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────

void _openDetails(BuildContext context, BookingModel b) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (_) => _BookingDetailsSheet(booking: b),
  );
}

class _BookingDetailsSheet extends StatelessWidget {
  final BookingModel booking;
  const _BookingDetailsSheet({required this.booking});

  @override
  Widget build(BuildContext context) {
    final b = booking;

    return DraggableScrollableSheet(
      initialChildSize: 0.74,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            // Title + order ID + status
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Booking Details',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937))),
                      const SizedBox(height: 3),
                      Text('Order #${b.id}',
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9CA3AF))),
                    ],
                  ),
                ),
                _StatusBadge(status: b.status),
              ],
            ),
            const SizedBox(height: 20),
            // Service info
            _DetailSection(
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: b.serviceBgColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(b.serviceIcon,
                        color: b.serviceColor, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.serviceName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(b.categoryName,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Helper info
            _DetailSection(
              label: 'ASSIGNED HELPER',
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: b.serviceBgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person_rounded,
                        color: b.serviceColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.helperName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        if (b.helperJobCount != null)
                          Text('${b.helperJobCount}+ jobs done',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280))),
                      ],
                    ),
                  ),
                  if (b.helperRating != null)
                    Column(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: Color(0xFFFBBF24), size: 18),
                        Text('${b.helperRating}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF1F2937))),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Address + scheduled time + completed time
            _DetailSection(
              child: Column(
                children: [
                  _DetailRow(
                    icon: Icons.location_on_outlined,
                    label: 'SERVICE ADDRESS',
                    value: b.address,
                    color: b.serviceColor,
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  const SizedBox(height: 14),
                  _DetailRow(
                    icon: Icons.access_time_rounded,
                    label: 'REQUESTED TIME',
                    value:
                    '${_formatDate(b.scheduledAt)} · ${_formatTime(b.scheduledAt)}',
                    color: b.serviceColor,
                  ),
                  if (b.completedAt != null) ...[
                    const SizedBox(height: 14),
                    const Divider(
                        height: 1, color: Color(0xFFF3F4F6)),
                    const SizedBox(height: 14),
                    _DetailRow(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'COMPLETED AT',
                      value:
                      '${_formatDate(b.completedAt!)} · ${_formatTime(b.completedAt!)}',
                      color: const Color(0xFF059669),
                    ),
                  ],
                ],
              ),
            ),
            // Tasks done
            if (b.tasksDone != null && b.tasksDone!.isNotEmpty) ...[
              const SizedBox(height: 14),
              _DetailSection(
                label: 'TASKS COMPLETED',
                child: Column(
                  children: b.tasksDone!
                      .map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669)
                                .withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                              Icons.check_rounded,
                              size: 13,
                              color: Color(0xFF059669)),
                        ),
                        const SizedBox(width: 10),
                        Text(t,
                            style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF374151),
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ))
                      .toList(),
                ),
              ),
            ],
            const SizedBox(height: 14),
            // Payment summary
            _DetailSection(
              label: 'PAYMENT SUMMARY',
              child: Column(
                children: [
                  _PayRow(
                      label: '${b.serviceName} Base Fee',
                      value: '₹${b.baseAmount.toStringAsFixed(2)}'),
                  const SizedBox(height: 8),
                  const _PayRow(
                      label: 'Taxes & Fees', value: '₹35.80'),
                  const SizedBox(height: 12),
                  const Divider(
                      height: 1, color: Color(0xFFF3F4F6)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF1F2937))),
                      Text(
                          '₹${b.totalAmount?.toStringAsFixed(2) ?? b.baseAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: b.serviceColor)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text('To be paid after service',
                        style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF9CA3AF))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Bottom action buttons
            if (b.status == BookingStatus.pending ||
                b.status == BookingStatus.active) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _confirmCancel(context, b);
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: Color(0xFFE5E7EB)),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(
                            vertical: 14),
                      ),
                      child: const Text('Cancel Request',
                          style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.edit_outlined,
                          size: 16, color: Colors.white),
                      label: const Text('Edit Request',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(
                            vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (b.status == BookingStatus.completed) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.replay_rounded,
                          size: 16, color: Colors.white),
                      label: const Text('Rebook Service',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(16)),
                        padding:
                        const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.help_outline_rounded,
                          size: 16, color: Color(0xFF6B7280)),
                      label: const Text('Get Support',
                          style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: Color(0xFFE5E7EB)),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(16)),
                        padding:
                        const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOOK NOW SHEET — called from helper_list_screen.dart
// ─────────────────────────────────────────────────────────────────────────────

/// Call this to show the booking confirmation bottom sheet.
void showBookNowSheet({
  required BuildContext context,
  required String helperName,
  required String helperId,
  required double helperRating,
  required int helperJobCount,
  required String serviceName,
  required String categoryName,
  required Color serviceColor,
  required Color serviceBgColor,
  required IconData serviceIcon,
  required double pricePerHour,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (_) => _BookNowSheet(
      helperName: helperName,
      helperId: helperId,
      helperRating: helperRating,
      helperJobCount: helperJobCount,
      serviceName: serviceName,
      categoryName: categoryName,
      serviceColor: serviceColor,
      serviceBgColor: serviceBgColor,
      serviceIcon: serviceIcon,
      pricePerHour: pricePerHour,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// PAYMENT METHOD ENUM
// ─────────────────────────────────────────────────────────────────────────────

enum PaymentMethod { cash, upi, card, wallet }

// ─────────────────────────────────────────────────────────────────────────────
// BOOK NOW SHEET — StatefulWidget
// ─────────────────────────────────────────────────────────────────────────────

class _BookNowSheet extends StatefulWidget {
  final String helperName;
  final String helperId;
  final double helperRating;
  final int helperJobCount;
  final String serviceName;
  final String categoryName;
  final Color serviceColor;
  final Color serviceBgColor;
  final IconData serviceIcon;
  final double pricePerHour;

  const _BookNowSheet({
    required this.helperName,
    required this.helperId,
    required this.helperRating,
    required this.helperJobCount,
    required this.serviceName,
    required this.categoryName,
    required this.serviceColor,
    required this.serviceBgColor,
    required this.serviceIcon,
    required this.pricePerHour,
  });

  @override
  State<_BookNowSheet> createState() => _BookNowSheetState();
}

class _BookNowSheetState extends State<_BookNowSheet> {
  // Address fields
  final _areaCtrl = TextEditingController();
  final _houseCtrl = TextEditingController();
  final _societyCtrl = TextEditingController();

  // Saved addresses
  List<SavedAddress> _savedAddresses = [];
  bool _loadingAddresses = true;
  String? _selectedAddressId;
  bool _showAddressForm = false;

  // Scheduling
  DateTime _scheduledDate = DateTime.now().add(const Duration(hours: 2));

  // Payment
  PaymentMethod _paymentMethod = PaymentMethod.cash;

  // Submission state
  bool _isSubmitting = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _loadSavedAddresses();
  }

  Future<void> _loadSavedAddresses() async {
    final addresses = await BookingService.getSavedAddresses();
    if (mounted) {
      setState(() {
        _savedAddresses = addresses;
        _loadingAddresses = false;
        // If no saved addresses, show the form immediately
        if (addresses.isEmpty) _showAddressForm = true;
      });
    }
  }

  @override
  void dispose() {
    _areaCtrl.dispose();
    _houseCtrl.dispose();
    _societyCtrl.dispose();
    super.dispose();
  }

  /// Builds the full address string from either selected saved or manual input
  String get _selectedFullAddress {
    if (_selectedAddressId != null) {
      try {
        final addr = _savedAddresses
            .firstWhere((a) => a.id == _selectedAddressId);
        return addr.fullAddress;
      } catch (_) {
        return '';
      }
    }
    if (_houseCtrl.text.isNotEmpty || _areaCtrl.text.isNotEmpty) {
      final parts = [
        _houseCtrl.text.trim(),
        _societyCtrl.text.trim(),
        _areaCtrl.text.trim(),
      ].where((p) => p.isNotEmpty).join(', ');
      return parts;
    }
    return '';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: widget.serviceColor,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledDate),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: widget.serviceColor,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (time == null) return;
    setState(() {
      _scheduledDate = DateTime(
          picked.year, picked.month, picked.day, time.hour, time.minute);
    });
  }

  Future<void> _submitBooking() async {
    final address = _selectedFullAddress;
    if (address.isEmpty) {
      setState(() =>
      _errorMsg = 'Please select or enter your service address.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMsg = null;
    });

    final bookingCode =
        'TS-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    final booking = BookingModel(
      id: bookingCode,
      serviceName: widget.serviceName,
      categoryName: widget.categoryName,
      serviceIcon: widget.serviceIcon,
      serviceColor: widget.serviceColor,
      serviceBgColor: widget.serviceBgColor,
      status: BookingStatus.pending,
      helperName: widget.helperName,
      helperId: widget.helperId,
      helperRating: widget.helperRating,
      helperJobCount: widget.helperJobCount,
      address: address,
      scheduledAt: _scheduledDate,
      baseAmount: widget.pricePerHour,
      totalAmount: widget.pricePerHour + 35.80,
    );

    // Save new address if entered manually and not already saved
    if (_selectedAddressId == null && _houseCtrl.text.isNotEmpty) {
      await BookingService.saveAddress(SavedAddress(
        id: '',
        label: 'Home',
        area: _areaCtrl.text.trim(),
        houseNo: _houseCtrl.text.trim(),
        societyName: _societyCtrl.text.trim(),
        fullAddress: address,
      ));
    }

    final docId = await BookingService.createBooking(booking);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (docId != null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(
                  'Booking confirmed! Code: $bookingCode',
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
        backgroundColor: const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        duration: const Duration(seconds: 4),
      ));
    } else {
      setState(() =>
      _errorMsg = 'Booking failed. Check your connection and try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.serviceColor;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(0, 0, 0, bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Text('Confirm Booking',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937))),
            const SizedBox(height: 4),
            const Text('Fill in the details to book your helper',
                style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
            const SizedBox(height: 20),

            // ── Helper summary card ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.06),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: widget.serviceBgColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(widget.serviceIcon, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.serviceName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFF1F2937))),
                        const SizedBox(height: 2),
                        Text(widget.helperName,
                            style: TextStyle(fontSize: 12, color: color)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('₹${widget.pricePerHour.toInt()}/hr',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: color)),
                      Row(children: [
                        const Icon(Icons.star_rounded,
                            size: 12, color: Color(0xFFFBBF24)),
                        const SizedBox(width: 2),
                        Text('${widget.helperRating}',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937))),
                      ]),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Service Address section ─────────────────────────────────
            Row(
              children: [
                const Text('Service Address',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF374151))),
                const Spacer(),
                if (!_showAddressForm)
                  GestureDetector(
                    onTap: () => setState(() {
                      _showAddressForm = true;
                      _selectedAddressId = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [color, color.withOpacity(0.8)]),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded,
                              size: 13, color: Colors.white),
                          SizedBox(width: 4),
                          Text('Add New',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Saved addresses list
            if (_loadingAddresses)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF7C3AED))))
            else if (_savedAddresses.isNotEmpty && !_showAddressForm) ...[
              ...List.generate(_savedAddresses.length, (i) {
                final addr = _savedAddresses[i];
                final isSelected = _selectedAddressId == addr.id;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedAddressId = addr.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withOpacity(0.06)
                          : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? color
                            : const Color(0xFFE5E7EB),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withOpacity(0.12)
                              : const Color(0xFFEEEEF5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_addressIcon(addr.label),
                            size: 18,
                            color: isSelected
                                ? color
                                : const Color(0xFF9CA3AF)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Text(addr.label,
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? color
                                              : const Color(0xFF1F2937))),
                                  if (i == 0) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: color.withOpacity(0.1),
                                          borderRadius:
                                          BorderRadius.circular(8)),
                                      child: Text('DEFAULT',
                                          style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: color)),
                                    ),
                                  ],
                                ]),
                                const SizedBox(height: 2),
                                Text(addr.fullAddress,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF6B7280)),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                              ])),
                      if (isSelected)
                        Icon(Icons.check_circle_rounded,
                            color: color, size: 20),
                    ]),
                  ),
                );
              }),
            ],

            // GPS + Manual address form
            if (_showAddressForm) ...[
              // GPS detect button
              GestureDetector(
                onTap: () {
                  // TODO: integrate geolocator to auto-fill area
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('Detecting your location...'),
                    backgroundColor: color,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    duration: const Duration(seconds: 2),
                  ));
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      color.withOpacity(0.08),
                      color.withOpacity(0.04)
                    ]),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.my_location_rounded,
                          color: color, size: 18),
                      const SizedBox(width: 8),
                      Text('Use Current Location (GPS)',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: color)),
                    ],
                  ),
                ),
              ),
              // OR divider
              const Row(children: [
                Expanded(child: Divider()),
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('OR ENTER MANUALLY',
                        style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF9CA3AF),
                            fontWeight: FontWeight.bold))),
                Expanded(child: Divider()),
              ]),
              const SizedBox(height: 12),
              // Area / Locality
              _AddressField(
                  controller: _areaCtrl,
                  label: 'Area / Locality',
                  hint: 'e.g. Vesu, Adajan, Katargam',
                  icon: Icons.location_city_outlined,
                  color: color),
              const SizedBox(height: 10),
              // House / Flat No
              _AddressField(
                  controller: _houseCtrl,
                  label: 'House / Flat No.',
                  hint: 'e.g. B-204, Flat 12',
                  icon: Icons.home_outlined,
                  color: color),
              const SizedBox(height: 10),
              // Society / Building
              _AddressField(
                  controller: _societyCtrl,
                  label: 'Society / Building Name',
                  hint: 'e.g. Sunshine Society',
                  icon: Icons.apartment_outlined,
                  color: color),
              const SizedBox(height: 10),
              // Back to saved addresses link
              if (_savedAddresses.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => _showAddressForm = false),
                  child: Center(
                    child: Text('← Back to saved addresses',
                        style: TextStyle(
                            fontSize: 12,
                            color: color,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
            ],

            const SizedBox(height: 16),

            // ── Schedule Date & Time ────────────────────────────────────
            const Text('Schedule Date & Time',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF374151))),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_rounded,
                        color: color, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${_formatDate(_scheduledDate)} · ${_formatTime(_scheduledDate)}',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937)),
                      ),
                    ),
                    Icon(Icons.edit_outlined, color: color, size: 16),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Payment Method ──────────────────────────────────────────
            const Text('Payment Method',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF374151))),
            const SizedBox(height: 10),
            _PaymentMethodSelector(
              selected: _paymentMethod,
              color: color,
              onChanged: (v) => setState(() => _paymentMethod = v),
            ),

            const SizedBox(height: 16),

            // ── Payment summary ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF3F4F6)),
              ),
              child: Column(
                children: [
                  _PayRow(
                      label: 'Base rate',
                      value:
                      '₹${widget.pricePerHour.toStringAsFixed(2)}'),
                  const SizedBox(height: 6),
                  const _PayRow(
                      label: 'Platform fee', value: '₹35.80'),
                  const Divider(
                      height: 16, color: Color(0xFFE5E7EB)),
                  _PayRow(
                      label: 'Total (est.)',
                      value:
                      '₹${(widget.pricePerHour + 35.80).toStringAsFixed(2)}'),
                ],
              ),
            ),

            // Error message
            if (_errorMsg != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline_rounded,
                      color: Color(0xFFDC2626), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(_errorMsg!,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFDC2626)))),
                ]),
              ),
            ],

            const SizedBox(height: 24),

            // ── Confirm Booking button ──────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitBooking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                    : const Text('Confirm Booking',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _addressIcon(String label) {
    switch (label.toLowerCase()) {
      case 'work':
        return Icons.work_outline_rounded;
      case 'other':
        return Icons.place_outlined;
      default:
        return Icons.home_outlined;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADDRESS FIELD WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class _AddressField extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final IconData icon;
  final Color color;

  const _AddressField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280))),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
            const TextStyle(color: Color(0xFFADB5BD), fontSize: 13),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            prefixIcon:
            Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: color, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAYMENT METHOD SELECTOR
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentMethodSelector extends StatelessWidget {
  final PaymentMethod selected;
  final Color color;
  final ValueChanged<PaymentMethod> onChanged;

  const _PaymentMethodSelector({
    required this.selected,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(children: [
          Expanded(
              child: _PaymentOption(
                  method: PaymentMethod.cash,
                  selected: selected,
                  color: color,
                  onChanged: onChanged,
                  icon: Icons.money_rounded,
                  label: 'Cash',
                  sub: 'Pay after service')),
          const SizedBox(width: 10),
          Expanded(
              child: _PaymentOption(
                  method: PaymentMethod.upi,
                  selected: selected,
                  color: color,
                  onChanged: onChanged,
                  icon: Icons.qr_code_rounded,
                  label: 'UPI',
                  sub: 'Instant payment')),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: _PaymentOption(
                  method: PaymentMethod.card,
                  selected: selected,
                  color: color,
                  onChanged: onChanged,
                  icon: Icons.credit_card_rounded,
                  label: 'Card',
                  sub: 'Debit / Credit')),
          const SizedBox(width: 10),
          Expanded(
              child: _PaymentOption(
                  method: PaymentMethod.wallet,
                  selected: selected,
                  color: color,
                  onChanged: onChanged,
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Wallet',
                  sub: 'Paytm / PhonePe')),
        ]),
      ],
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final PaymentMethod method, selected;
  final Color color;
  final ValueChanged<PaymentMethod> onChanged;
  final IconData icon;
  final String label, sub;

  const _PaymentOption({
    required this.method,
    required this.selected,
    required this.color,
    required this.onChanged,
    required this.icon,
    required this.label,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = method == selected;
    return GestureDetector(
      onTap: () => onChanged(method),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.07)
              : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isSelected ? color : const Color(0xFFE5E7EB),
              width: isSelected ? 1.5 : 1),
        ),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                  colors: [color, color.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight)
                  : const LinearGradient(
                  colors: [Color(0xFFEEEEF5), Color(0xFFE5E7EB)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                size: 17,
                color: isSelected
                    ? Colors.white
                    : const Color(0xFF9CA3AF)),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? color
                                : const Color(0xFF374151))),
                    Text(sub,
                        style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF9CA3AF))),
                  ])),
          if (isSelected)
            Icon(Icons.check_circle_rounded, color: color, size: 16),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REUSABLE SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final BookingStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    Color bg;
    String label;
    IconData icon;

    switch (status) {
      case BookingStatus.active:
        color = const Color(0xFF059669);
        bg = const Color(0xFFD1FAE5);
        label = 'ACTIVE';
        icon = Icons.circle;
        break;
      case BookingStatus.pending:
        color = const Color(0xFFD97706);
        bg = const Color(0xFFFEF3C7);
        label = 'PENDING';
        icon = Icons.circle;
        break;
      case BookingStatus.completed:
        color = const Color(0xFF2563EB);
        bg = const Color(0xFFDBEAFE);
        label = 'DONE';
        icon = Icons.check_circle_outline_rounded;
        break;
      case BookingStatus.cancelled:
        color = const Color(0xFFDC2626);
        bg = const Color(0xFFFEE2E2);
        label = 'CANCELLED';
        icon = Icons.cancel_outlined;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 7, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

class _GlassChip extends StatelessWidget {
  final String label;
  const _GlassChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    );
  }
}

class _IconRow extends StatelessWidget {
  final IconData icon;
  final Widget child;
  const _IconRow({required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFC4B5FD), size: 14),
        const SizedBox(width: 8),
        Expanded(child: child),
      ],
    );
  }
}

class _DetailSection extends StatelessWidget {
  final Widget child;
  final String? label;
  const _DetailSection({required this.child, this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Text(label!,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF9CA3AF),
                    letterSpacing: 0.8)),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF9CA3AF),
                      letterSpacing: 0.8)),
              const SizedBox(height: 3),
              Text(value,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937))),
            ],
          ),
        ),
      ],
    );
  }
}

class _PayRow extends StatelessWidget {
  final String label;
  final String value;
  const _PayRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
            const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937))),
      ],
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _OutlineButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 15),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _FilledButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _FilledButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          // Shiny white button for dark purple card background
          gradient: const LinearGradient(
              colors: [Colors.white, Color(0xFFF5F0FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.white.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline_rounded,
                color: Color(0xFF7C3AED), size: 15),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF7C3AED),
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color, bgColor;
  final VoidCallback onTap;
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [color, color.withOpacity(0.85)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _SmallButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String label;
  const _EmptyState({required this.label});

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
              decoration: const BoxDecoration(
                  color: Color(0xFFEDE9FE), shape: BoxShape.circle),
              child: const Icon(Icons.calendar_today_outlined,
                  size: 36, color: Color(0xFF7C3AED)),
            ),
            const SizedBox(height: 18),
            Text(label,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937)),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
              'Your bookings will appear here\nonce you request a service.',
              style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF9CA3AF),
                  height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATE / TIME HELPERS
// ─────────────────────────────────────────────────────────────────────────────

String _formatDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}

String _formatTime(DateTime dt) {
  final h =
  dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
  final m = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  return '$h:$m $period';
}