import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:trouble_sarthi/screens/messages_screen.dart'
    show NotificationCountNotifier, MessagesScreen;
import 'package:trouble_sarthi/screens/profile_screen.dart';
import 'auth/login_screen.dart';
import 'messages_screen.dart' show NotificationCountNotifier, ServicesScreen;
import 'about_screen.dart';
import 'booking_screen.dart';
import 'location_picker_screen.dart';
import 'helper_list_screen.dart';
import 'midnight_emergency_screen.dart';
import 'home_skeleton.dart'; // ← your skeleton file

// ─────────────────────────────────────────────────────────────────────────────
// COLOR HELPERS
// ─────────────────────────────────────────────────────────────────────────────

Color _darken(Color c, [double amount = 0.18]) {
  final hsl = HSLColor.fromColor(c);
  return hsl
      .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
      .toColor();
}

Color _lighten(Color c, [double amount = 0.18]) {
  final hsl = HSLColor.fromColor(c);
  return hsl
      .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
      .toColor();
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

class _SubService {
  final String name;
  final IconData icon;
  const _SubService(this.name, this.icon);
}

class _Category {
  final String title;
  final IconData categoryIcon;
  final Color color;
  final Color bgColor;
  final List<_SubService> subs;
  final String tagline;

  const _Category({
    required this.title,
    required this.categoryIcon,
    required this.color,
    required this.bgColor,
    required this.subs,
    required this.tagline,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// CATEGORIES DATA
// ─────────────────────────────────────────────────────────────────────────────

const _kCategories = <_Category>[
  _Category(
    title: 'Home Services',
    tagline: 'Plumber · AC · Electric',
    categoryIcon: Icons.home_repair_service_rounded,
    color: Color(0xFF7C3AED),
    bgColor: Color(0xFFEDE9FE),
    subs: [
      _SubService('Plumber', Icons.water_drop_outlined),
      _SubService('Electrician', Icons.bolt_outlined),
      _SubService('Carpenter', Icons.carpenter),
      _SubService('AC Repair', Icons.ac_unit_outlined),
      _SubService('RO Repair', Icons.water_outlined),
      _SubService('Appliance Repair', Icons.kitchen_outlined),
      _SubService('Painter', Icons.format_paint_outlined),
      _SubService('Cleaner', Icons.cleaning_services_outlined),
    ],
  ),
  _Category(
    title: 'Vehicle Services',
    tagline: 'Car · Bike · Towing',
    categoryIcon: Icons.directions_car_rounded,
    color: Color(0xFF0284C7),
    bgColor: Color(0xFFE0F2FE),
    subs: [
      _SubService('Car Mechanic', Icons.car_repair),
      _SubService('Bike Mechanic', Icons.two_wheeler),
      _SubService('Towing Service', Icons.local_shipping_outlined),
      _SubService('Puncture Repair', Icons.tire_repair),
      _SubService('Car Wash', Icons.local_car_wash_outlined),
      _SubService('Battery Jump Start', Icons.battery_charging_full_outlined),
    ],
  ),
  _Category(
    title: 'Emergency',
    tagline: 'Ambulance · First Aid · 24×7',
    categoryIcon: Icons.local_hospital_rounded,
    color: Color(0xFFDC2626),
    bgColor: Color(0xFFFEE2E2),
    subs: [
      _SubService('Ambulance', Icons.local_hospital_outlined),
      _SubService('First Aid', Icons.medical_services_outlined),
      _SubService('Blood Donor', Icons.bloodtype_outlined),
      _SubService('Fire Help', Icons.local_fire_department_outlined),
      _SubService('Disaster Support', Icons.warning_amber_outlined),
      _SubService('Mid-Night Vehicle Emergency', Icons.nights_stay_rounded),
    ],
  ),
  _Category(
    title: 'Delivery & Pickup',
    tagline: 'Parcels · Grocery · Meds',
    categoryIcon: Icons.local_shipping_rounded,
    color: Color(0xFFD97706),
    bgColor: Color(0xFFFEF3C7),
    subs: [
      _SubService('Parcel Pickup', Icons.local_post_office_outlined),
      _SubService('Grocery Delivery', Icons.shopping_basket_outlined),
      _SubService('Medicine Delivery', Icons.medication_outlined),
      _SubService('Document Courier', Icons.description_outlined),
      _SubService('Local Shifting', Icons.move_to_inbox_outlined),
    ],
  ),
  _Category(
    title: 'Technical Services',
    tagline: 'Mobile · Laptop · WiFi',
    categoryIcon: Icons.build_rounded,
    color: Color(0xFF0891B2),
    bgColor: Color(0xFFCFFAFE),
    subs: [
      _SubService('Mobile Repair', Icons.phone_android_outlined),
      _SubService('Laptop Repair', Icons.laptop_outlined),
      _SubService('CCTV Install', Icons.videocam_outlined),
      _SubService('WiFi Install', Icons.wifi_outlined),
      _SubService('Software Help', Icons.code_outlined),
    ],
  ),
  _Category(
    title: 'Personal Assistance',
    tagline: 'Tutor · Trainer · Care',
    categoryIcon: Icons.school_rounded,
    color: Color(0xFF059669),
    bgColor: Color(0xFFD1FAE5),
    subs: [
      _SubService('Home Tutor', Icons.school_outlined),
      _SubService('Fitness Trainer', Icons.fitness_center_outlined),
      _SubService('Yoga Instructor', Icons.self_improvement_outlined),
      _SubService('Caretaker', Icons.elderly_outlined),
      _SubService('Babysitter', Icons.child_care_outlined),
    ],
  ),
  _Category(
    title: 'Events & Occasions',
    tagline: 'Photo · DJ · Decor',
    categoryIcon: Icons.celebration_rounded,
    color: Color(0xFFDB2777),
    bgColor: Color(0xFFFCE7F3),
    subs: [
      _SubService('Photographer', Icons.camera_alt_outlined),
      _SubService('Videographer', Icons.videocam_outlined),
      _SubService('DJ', Icons.music_note_outlined),
      _SubService('Decoration', Icons.auto_awesome_outlined),
      _SubService('Catering', Icons.restaurant_outlined),
    ],
  ),
  _Category(
    title: 'Construction',
    tagline: 'Mason · Interior · Tiles',
    categoryIcon: Icons.foundation_rounded,
    color: Color(0xFF92400E),
    bgColor: Color(0xFFFDE68A),
    subs: [
      _SubService('Mason', Icons.foundation_outlined),
      _SubService('Interior Design', Icons.design_services_outlined),
      _SubService('Tiles Worker', Icons.grid_on_outlined),
      _SubService('Architect Help', Icons.architecture_outlined),
      _SubService('Fabrication', Icons.handyman_outlined),
    ],
  ),
  _Category(
    title: 'Cleaning',
    tagline: 'Deep · Pest · Tank',
    categoryIcon: Icons.cleaning_services_rounded,
    color: Color(0xFF0D9488),
    bgColor: Color(0xFFCCFBF1),
    subs: [
      _SubService('Deep Cleaning', Icons.clean_hands_outlined),
      _SubService('Bathroom Clean', Icons.bathroom_outlined),
      _SubService('Sofa Cleaning', Icons.chair_outlined),
      _SubService('Pest Control', Icons.pest_control_outlined),
      _SubService('Water Tank', Icons.water_outlined),
    ],
  ),
  _Category(
    title: 'Professional',
    tagline: 'Legal · CA · Insurance',
    categoryIcon: Icons.gavel_rounded,
    color: Color(0xFF4338CA),
    bgColor: Color(0xFFE0E7FF),
    subs: [
      _SubService('Lawyer Consult', Icons.gavel_outlined),
      _SubService('CA / Tax Help', Icons.calculate_outlined),
      _SubService('Insurance', Icons.shield_outlined),
      _SubService('Real Estate', Icons.apartment_outlined),
    ],
  ),
  _Category(
    title: 'Outdoor & More',
    tagline: 'Garden · Guard · Driver',
    categoryIcon: Icons.park_rounded,
    color: Color(0xFF16A34A),
    bgColor: Color(0xFFDCFCE7),
    subs: [
      _SubService('Gardener', Icons.yard_outlined),
      _SubService('Security Guard', Icons.security_outlined),
      _SubService('Driver on Hire', Icons.directions_car_outlined),
      _SubService('Scrap Collector', Icons.recycling_outlined),
    ],
  ),
  _Category(
    title: 'Community Help',
    tagline: 'Volunteer · NGO · Senior',
    categoryIcon: Icons.volunteer_activism_rounded,
    color: Color(0xFF7C3AED),
    bgColor: Color(0xFFF3E8FF),
    subs: [
      _SubService('Volunteer Help', Icons.volunteer_activism_outlined),
      _SubService('Senior Support', Icons.elderly_outlined),
      _SubService('Student Helper', Icons.school_outlined),
      _SubService('NGO Support', Icons.favorite_border),
    ],
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// HOME SCREEN SHELL
// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeContent(),
    const ServicesScreen(),
    const BookingsScreen(),
    const AboutScreen(),
    const ProfileScreen(),
  ];

  void _onNavTap(int i) {
    if (_selectedIndex == i) return;
    setState(() => _selectedIndex = i);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FB),
        extendBody: true,
        body: IndexedStack(index: _selectedIndex, children: _screens),
        bottomNavigationBar: _FloatingBottomNav(
          selectedIndex: _selectedIndex,
          onTap: _onNavTap,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FLOATING PILL BOTTOM NAV
// ─────────────────────────────────────────────────────────────────────────────

class _FloatingBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  const _FloatingBottomNav(
      {required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
        child: Container(
          height: 62,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(34),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withOpacity(0.12),
                blurRadius: 24,
                spreadRadius: 0,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(34),
            child: Row(
              children: [
                _NavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                  idx: 0,
                  sel: selectedIndex,
                  onTap: onTap,
                ),
                _MessageNavItem(sel: selectedIndex, onTap: onTap),
                _BookingNavItem(
                    idx: 2, sel: selectedIndex, onTap: onTap),
                _NavItem(
                  icon: Icons.verified_user_outlined,
                  activeIcon: Icons.verified_user_rounded,
                  label: 'Trust',
                  idx: 3,
                  sel: selectedIndex,
                  onTap: onTap,
                ),
                _NavItem(
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Profile',
                  idx: 4,
                  sel: selectedIndex,
                  onTap: onTap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NAV ITEMS
// ─────────────────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final int idx, sel;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.idx,
    required this.sel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = idx == sel;
    const activeColor = Color(0xFF7C3AED);
    const inactiveColor = Color(0xFFB0B8C8);
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(idx),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFFEDE9FE)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                active ? activeIcon : icon,
                color: active ? activeColor : inactiveColor,
                size: 21,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 9,
                color: active ? activeColor : inactiveColor,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageNavItem extends StatelessWidget {
  final int sel;
  final ValueChanged<int> onTap;
  const _MessageNavItem({required this.sel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = sel == 1;
    const activeColor = Color(0xFF7C3AED);
    const inactiveColor = Color(0xFFB0B8C8);
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(1),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ValueListenableBuilder<int>(
              valueListenable: NotificationCountNotifier.instance,
              builder: (_, count, __) => Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFFEDE9FE)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      active
                          ? Icons.chat_bubble_rounded
                          : Icons.chat_bubble_outline_rounded,
                      color: active ? activeColor : inactiveColor,
                      size: 21,
                    ),
                  ),
                  if (count > 0)
                    Positioned(
                      top: 0,
                      right: 6,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          shape: BoxShape.circle,
                          border:
                          Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 9,
                color: active ? activeColor : inactiveColor,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
              child: const Text('Messages'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingNavItem extends StatelessWidget {
  final int idx, sel;
  final ValueChanged<int> onTap;
  const _BookingNavItem(
      {required this.idx, required this.sel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = idx == sel;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(idx),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: active
                    ? const LinearGradient(
                  colors: [
                    Color(0xFF7C3AED),
                    Color(0xFFEC4899),
                    Color(0xFFF59E0B),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
                    : const LinearGradient(
                  colors: [
                    Color(0xFFB8A4E8),
                    Color(0xFFF0ABCB),
                    Color(0xFFFCD5A0),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: active
                    ? [
                  BoxShadow(
                    color:
                    const Color(0xFF7C3AED).withOpacity(0.40),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                  BoxShadow(
                    color:
                    const Color(0xFFEC4899).withOpacity(0.20),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
                    : null,
              ),
              child: Icon(
                Icons.calendar_today_rounded,
                color: active ? Colors.white : Colors.white.withOpacity(0.9),
                size: 19,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 9,
                color: active
                    ? const Color(0xFF7C3AED)
                    : const Color(0xFFB0B8C8),
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
              child: const Text('Bookings'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOME CONTENT  ← CONNECTIVITY + SKELETON INTEGRATED HERE
// ─────────────────────────────────────────────────────────────────────────────

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // ── Connectivity state ──────────────────────────────────────────────────────
  bool _isLoading = true;
  bool _hasInternet = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  bool _locationChecked = false;
  static final _emergencyCategory =
  _kCategories.firstWhere((c) => c.title == 'Emergency');

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _checkLocation());
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  // ── Connectivity check ──────────────────────────────────────────────────────
  Future<void> _checkConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      final hasNet = results.any((r) => r != ConnectivityResult.none);
      if (mounted) {
        setState(() {
          _hasInternet = hasNet;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }

    // Listen for live changes
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      if (!mounted) return;
      final hasNet = results.any((r) => r != ConnectivityResult.none);
      setState(() => _hasInternet = hasNet);
    });
  }

  // ── Location dialog ─────────────────────────────────────────────────────────
  Future<void> _checkLocation() async {
    if (_locationChecked) return;
    _locationChecked = true;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!doc.exists || !mounted) return;
      final data = doc.data()!;
      final locSet = data['locationSet'] == true;
      final hasPrimary =
          (data['primaryLocation'] as Map<String, dynamic>?)?['city']
              ?.toString()
              .isNotEmpty ==
              true;
      if (!locSet && !hasPrimary) _showLocationDialog();
    } catch (_) {}
  }

  void _showLocationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0x73000000),
      builder: (_) => _LocationAlertDialog(
        onSetNow: () {
          Navigator.pop(context);
          _pushFade(context, const LocationPickerScreen());
        },
        onLater: () => Navigator.pop(context),
      ),
    );
  }

  void _openSubs(_Category cat) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SubServicesSheet(cat: cat),
    );
  }

  void _openSearch() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => const SearchScreen(),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
              parent: animation, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity:
            Tween<double>(begin: 0.0, end: 1.0).animate(curved),
            child: SlideTransition(
              position: Tween<Offset>(
                  begin: const Offset(0, 0.06), end: Offset.zero)
                  .animate(curved),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    super.build(context);

    // ── Show skeleton while checking connectivity / loading ──────────────────
    if (_isLoading) {
      return const HomeSkeletonScreen();
    }

    // ── Show no-internet screen ──────────────────────────────────────────────
    if (!_hasInternet) {
      return HomeNoInternetScreen(
        onRetry: () async {
          setState(() => _isLoading = true);
          await _checkConnectivity();
        },
      );
    }

    // ── Normal home content ──────────────────────────────────────────────────
    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: _Header()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _SearchBarTrigger(onTap: _openSearch),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: _SosBanner(
                onTap: () => _openSubs(_emergencyCategory)),
          ),
        ),
        const SliverToBoxAdapter(child: _FeatureBanners()),
        const SliverToBoxAdapter(child: _StatsRow()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                const Text(
                  'All Categories',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_kCategories.length}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverGrid(
            gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.32,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate(
                  (context, i) => RepaintBoundary(
                child: _CategoryCard(
                  cat: _kCategories[i],
                  onTap: () => _openSubs(_kCategories[i]),
                ),
              ),
              childCount: _kCategories.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: _HowItWorksSection()),
        const SliverToBoxAdapter(child: _AppFooter()),
        const SliverToBoxAdapter(child: SizedBox(height: 75)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E0640),
            Color(0xFF3B0764),
            Color(0xFF5B21B6),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 16, 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: _HeaderContent()),
                  const SizedBox(width: 12),
                  const _ProfileAvatar(),
                ],
              ),
            ),
            Container(
              height: 24,
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

class _HeaderContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const _GuestHeaderContent();
    return _AuthHeaderContent(uid: user.uid);
  }
}

class _GuestHeaderContent extends StatelessWidget {
  const _GuestHeaderContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Welcome to',
            style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.60),
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        const _GradientAppName(fontSize: 26),
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.location_on_rounded,
              size: 13, color: Color(0xFFC4B5FD)),
          const SizedBox(width: 4),
          Text('Surat, Gujarat',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.72))),
        ]),
      ],
    );
  }
}

class _AuthHeaderContent extends StatelessWidget {
  final String uid;
  const _AuthHeaderContent({required this.uid});

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning ☀️';
    if (h < 17) return 'Good Afternoon 🌤';
    return 'Good Evening 🌙';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snap) {
        String firstName = '';
        String location = 'Tap to set location';
        if (snap.hasData && snap.data!.exists) {
          final d = snap.data!.data() as Map<String, dynamic>;
          final fn = d['fullName'] as String? ?? '';
          if (fn.isNotEmpty) firstName = fn.split(' ').first;
          final pl = d['primaryLocation'] as Map<String, dynamic>?;
          if (pl != null) {
            final city = pl['city'] as String? ?? '';
            final sub = pl['subLocality'] as String? ?? '';
            if (sub.isNotEmpty) {
              location = '$sub, $city';
            } else if (city.isNotEmpty) {
              location = city;
            }
          }
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('WELCOME BACK',
                  style: TextStyle(
                      fontSize: 9,
                      color: Colors.white.withOpacity(0.70),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0)),
            ),
            const SizedBox(height: 5),
            Text(
              firstName.isNotEmpty
                  ? '$_greeting, $firstName'
                  : _greeting,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.1),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () =>
                  _pushFade(context, const LocationPickerScreen()),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on_rounded,
                        size: 13, color: Color(0xFFC4B5FD)),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(location,
                          style: TextStyle(
                              fontSize: 11,
                              color:
                              Colors.white.withOpacity(0.85),
                              fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 3),
                    const Icon(Icons.expand_more_rounded,
                        size: 14, color: Color(0xFFC4B5FD)),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GradientAppName extends StatelessWidget {
  final double fontSize;
  const _GradientAppName({required this.fontSize});

  static const _gradient = LinearGradient(
    colors: [
      Color(0xFFEDE9FE),
      Color(0xFFC4B5FD),
      Color(0xFFA78BFA),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => _gradient.createShader(bounds),
      child: Text(
        'Trouble Sarthi',
        style: TextStyle(
          fontFamily: 'Saman',
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final photo = user?.photoURL ?? '';
    final name = user?.displayName ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: () => _showMenu(context),
      child: Stack(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFA78BFA), Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                  color: Colors.white.withOpacity(0.5), width: 2),
              image: photo.isNotEmpty
                  ? DecorationImage(
                  image: NetworkImage(photo),
                  fit: BoxFit.cover)
                  : null,
            ),
            child: photo.isEmpty
                ? Center(
                child: Text(initial,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 19)))
                : null,
          ),
          Positioned(
            right: 1,
            top: 1,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.my_location_rounded,
                    color: Color(0xFF7C3AED)),
                title: const Text('Update Location',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _pushFade(context, const LocationPickerScreen());
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout_rounded,
                    color: Color(0xFFDC2626)),
                title: const Text('Log Out',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFDC2626))),
                onTap: () async {
                  Navigator.pop(context);
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) =>
                        const LoginScreen(),
                        transitionsBuilder: (_, a, __, child) =>
                            FadeTransition(
                                opacity: a, child: child),
                        transitionDuration:
                        const Duration(milliseconds: 250),
                      ),
                          (r) => false,
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH BAR TRIGGER
// ─────────────────────────────────────────────────────────────────────────────

class _SearchBarTrigger extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchBarTrigger({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 14,
                offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            const Icon(Icons.search_rounded,
                color: Color(0xFF7C3AED), size: 22),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                  'Search services, mechanics nearby...',
                  style: TextStyle(
                      color: Color(0xFFADB5BD), fontSize: 13)),
            ),
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEDE9FE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.tune_rounded,
                  color: Color(0xFF7C3AED), size: 16),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SOS BANNER
// ─────────────────────────────────────────────────────────────────────────────

class _SosBanner extends StatefulWidget {
  final VoidCallback onTap;
  const _SosBanner({required this.onTap});

  @override
  State<_SosBanner> createState() => _SosBannerState();
}

class _SosBannerState extends State<_SosBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, child) => GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0F3460),
                Color(0xFF16213E),
                Color(0xFF0D7377),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Color.fromRGBO(
                    13, 115, 119, 0.22 + 0.18 * _pulse.value),
                blurRadius: 18 + 10 * _pulse.value,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: child,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -16,
            top: -16,
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0D7377).withOpacity(0.20),
              ),
            ),
          ),
          Positioned(
            left: -8,
            bottom: -18,
            child: Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color:
                          const Color(0xFF0D7377).withOpacity(0.28),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: const Color(0xFF14FFEC)
                                  .withOpacity(0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle,
                                size: 6, color: Color(0xFF14FFEC)),
                            SizedBox(width: 5),
                            Text(
                              'LIVE EMERGENCY SUPPORT',
                              style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF14FFEC),
                                  letterSpacing: 0.8),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        '24/7 Rapid Assistance',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.2),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Professional help in under 15 min',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.60)),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.check_circle_rounded,
                              size: 10,
                              color: const Color(0xFF14FFEC)
                                  .withOpacity(0.85)),
                          const SizedBox(width: 4),
                          Text(
                            'All services available 24×7 for everyone',
                            style: TextStyle(
                                fontSize: 10,
                                color: const Color(0xFF14FFEC)
                                    .withOpacity(0.85),
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D7377), Color(0xFF14FFEC)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0D7377).withOpacity(0.50),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.emergency_rounded,
                          color: Colors.white, size: 20),
                      SizedBox(height: 3),
                      Text(
                        'SOS',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FEATURE BANNERS
// ─────────────────────────────────────────────────────────────────────────────

class _FeatureBanners extends StatelessWidget {
  const _FeatureBanners();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              child: _FeatureCard(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF4338CA), Color(0xFF7C3AED)],
                ),
                shadowColor: const Color(0xFF4338CA),
                icon: Icons.chat_bubble_outline_rounded,
                bgIcon: Icons.chat_bubble_rounded,
                title: 'Live Chat',
                subtitle: 'User ↔ Helper, real-time',
              )),
          const SizedBox(width: 12),
          Expanded(
              child: _FeatureCard(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0891B2), Color(0xFF059669)],
                ),
                shadowColor: const Color(0xFF0891B2),
                icon: Icons.location_on_rounded,
                bgIcon: Icons.bolt_rounded,
                title: 'Local & Fast',
                subtitle: 'Near you, always quick',
              )),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final LinearGradient gradient;
  final Color shadowColor;
  final IconData icon, bgIcon;
  final String title, subtitle;

  const _FeatureCard({
    required this.gradient,
    required this.shadowColor,
    required this.icon,
    required this.bgIcon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: gradient,
          boxShadow: [
            BoxShadow(
              color: shadowColor.withOpacity(0.22),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -6,
              bottom: -8,
              child: Icon(bgIcon,
                  size: 50, color: Colors.white.withOpacity(0.10)),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Colors.white, size: 16),
                ),
                const SizedBox(height: 10),
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.72)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATS ROW
// ─────────────────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          _StatChip(
              value: '500+',
              label: 'Helpers',
              icon: Icons.people_alt_outlined,
              color: Color(0xFF7C3AED)),
          SizedBox(width: 10),
          _StatChip(
              value: '12',
              label: 'Categories',
              icon: Icons.grid_view_rounded,
              color: Color(0xFF0891B2)),
          SizedBox(width: 10),
          _StatChip(
              value: '4.8★',
              label: 'Avg Rating',
              icon: Icons.star_rate_rounded,
              color: Color(0xFFD97706)),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  const _StatChip(
      {required this.value,
        required this.label,
        required this.icon,
        required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding:
        const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: color)),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 9, color: Color(0xFF9CA3AF))),
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
// CATEGORY CARD
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryCard extends StatefulWidget {
  final _Category cat;
  final VoidCallback onTap;
  const _CategoryCard({required this.cat, required this.onTap});

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cat = widget.cat;
    final gradientStart = _lighten(cat.color, 0.06);
    final gradientEnd = _darken(cat.color, 0.12);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()..scale(_pressed ? 0.955 : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [gradientStart, gradientEnd],
          ),
          boxShadow: [
            BoxShadow(
              color: cat.color.withOpacity(_pressed ? 0.20 : 0.32),
              blurRadius: _pressed ? 6 : 20,
              spreadRadius: -3,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Positioned(
                right: -18,
                top: -18,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.10),
                  ),
                ),
              ),
              Positioned(
                left: -10,
                bottom: -20,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.06),
                  ),
                ),
              ),
              Positioned(
                right: -8,
                bottom: -8,
                child: Icon(
                  cat.categoryIcon,
                  size: 80,
                  color: Colors.white.withOpacity(0.10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 12, 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.20),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.25),
                          width: 1,
                        ),
                      ),
                      child: Icon(cat.categoryIcon,
                          color: Colors.white, size: 20),
                    ),
                    const Spacer(),
                    Text(
                      cat.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.30),
                            width: 0.8),
                      ),
                      child: Text(
                        '${cat.subs.length} services',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
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
// HOW IT WORKS SECTION
// ─────────────────────────────────────────────────────────────────────────────

class _HowItWorksSection extends StatelessWidget {
  const _HowItWorksSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'How It Works',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '3 easy steps',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF7C3AED)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C3AED).withOpacity(0.07),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Column(
              children: [
                _StepTile(
                  icon: Icons.search_rounded,
                  color: Color(0xFF7C3AED),
                  bgColor: Color(0xFFEDE9FE),
                  title: 'Search a Service',
                  desc:
                  'Pick from 12 categories or search directly by name.',
                  isLast: false,
                ),
                _StepTile(
                  icon: Icons.person_pin_circle_rounded,
                  color: Color(0xFF0891B2),
                  bgColor: Color(0xFFCFFAFE),
                  title: 'Choose a Helper',
                  desc:
                  'Browse verified, rated helpers available near you.',
                  isLast: false,
                ),
                _StepTile(
                  icon: Icons.check_circle_rounded,
                  color: Color(0xFF059669),
                  bgColor: Color(0xFFD1FAE5),
                  title: 'Get It Done',
                  desc:
                  'Book instantly, chat live, and rate your experience.',
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final String title, desc;
  final IconData icon;
  final Color color, bgColor;
  final bool isLast;

  const _StepTile({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.title,
    required this.desc,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 30,
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      color.withOpacity(0.35),
                      color.withOpacity(0.08),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color)),
                const SizedBox(height: 3),
                Text(desc,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        height: 1.45)),
                if (!isLast) const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APP FOOTER
// ─────────────────────────────────────────────────────────────────────────────

class _AppFooter extends StatelessWidget {
  const _AppFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E0640),
            Color(0xFF3B0764),
            Color(0xFF5B21B6),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withOpacity(0.28),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -22,
            top: -22,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            left: -12,
            bottom: -26,
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.22)),
                    ),
                    child: const Icon(
                        Icons.volunteer_activism_rounded,
                        color: Colors.white,
                        size: 22),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _GradientAppName(fontSize: 19),
                      const SizedBox(height: 2),
                      Text(
                        'Your neighbourhood helper',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.52)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.0),
                      Colors.white.withOpacity(0.15),
                      Colors.white.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: const [
                  _FooterBadge(
                      icon: Icons.verified_rounded,
                      label: 'Verified\nHelpers'),
                  _FooterBadge(
                      icon: Icons.lock_outline_rounded,
                      label: 'Secure\nPayments'),
                  _FooterBadge(
                      icon: Icons.support_agent_rounded,
                      label: '24/7\nSupport'),
                  _FooterBadge(
                      icon: Icons.star_rate_rounded,
                      label: 'Rated\n4.8★'),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.11)),
                ),
                child: Text(
                  '© 2025 Trouble Sarthi  ·  Made with ❤️ in Surat',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.50),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FooterBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FooterBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child:
          Icon(icon, color: const Color(0xFFC4B5FD), size: 18),
        ),
        const SizedBox(height: 7),
        Text(
          label,
          style: TextStyle(
              fontSize: 9.5,
              color: Colors.white.withOpacity(0.62),
              fontWeight: FontWeight.w600,
              height: 1.45),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _focusNode = FocusNode();
  final _ctrl = TextEditingController();
  String _query = '';
  List<_Category> _results = _kCategories;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    final q = v.trim().toLowerCase();
    setState(() {
      _query = v;
      _results = q.isEmpty
          ? _kCategories
          : _kCategories
          .where((c) =>
      c.title.toLowerCase().contains(q) ||
          c.subs
              .any((s) => s.name.toLowerCase().contains(q)))
          .toList();
    });
  }

  void _openSubs(_Category cat) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SubServicesSheet(cat: cat),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _query.isNotEmpty;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1E0640),
                  Color(0xFF3B0764),
                  Color(0xFF5B21B6),
                ],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding:
                    const EdgeInsets.fromLTRB(8, 10, 16, 16),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 20),
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                              BorderRadius.circular(14),
                              boxShadow: const [
                                BoxShadow(
                                    color: Color(0x1A000000),
                                    blurRadius: 8,
                                    offset: Offset(0, 2))
                              ],
                            ),
                            child: TextField(
                              controller: _ctrl,
                              focusNode: _focusNode,
                              onChanged: _onChanged,
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF1F2937)),
                              textAlignVertical:
                              TextAlignVertical.center,
                              decoration: InputDecoration(
                                hintText:
                                'Search services, plumber...',
                                hintStyle: const TextStyle(
                                    color: Color(0xFFADB5BD),
                                    fontSize: 13),
                                prefixIcon: const Icon(
                                    Icons.search_rounded,
                                    color: Color(0xFF7C3AED),
                                    size: 20),
                                suffixIcon: hasQuery
                                    ? GestureDetector(
                                  onTap: () {
                                    _ctrl.clear();
                                    _onChanged('');
                                  },
                                  child: const Icon(
                                      Icons.close_rounded,
                                      color:
                                      Color(0xFF9CA3AF),
                                      size: 18),
                                )
                                    : null,
                                border: InputBorder.none,
                                contentPadding:
                                const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 4),
                                isDense: true,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF4F6FB),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _results.isEmpty
                ? _EmptySearch(query: _query)
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                  16, 4, 16, 100),
              physics: const ClampingScrollPhysics(),
              itemCount: _results.length,
              itemBuilder: (_, i) {
                final cat = _results[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: RepaintBoundary(
                    child: _SearchResultCard(
                      cat: cat,
                      query: _query,
                      onTap: () => _openSubs(cat),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResultCard extends StatefulWidget {
  final _Category cat;
  final String query;
  final VoidCallback onTap;
  const _SearchResultCard(
      {required this.cat, required this.query, required this.onTap});

  @override
  State<_SearchResultCard> createState() => _SearchResultCardState();
}

class _SearchResultCardState extends State<_SearchResultCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cat = widget.cat;
    final matchedSubs = widget.query.isEmpty
        ? cat.subs
        : cat.subs
        .where((s) => s.name
        .toLowerCase()
        .contains(widget.query.toLowerCase()))
        .toList();

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.identity()..scale(_pressed ? 0.97 : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cat.bgColor, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: cat.color.withOpacity(_pressed ? 0.12 : 0.06),
              blurRadius: _pressed ? 4 : 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: cat.color.withOpacity(0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 2))
                      ],
                    ),
                    child: Icon(cat.categoryIcon,
                        color: cat.color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cat.title,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: cat.color),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text('${cat.subs.length} services',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF9CA3AF))),
                      ],
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                        color: cat.color, shape: BoxShape.circle),
                    child: const Icon(Icons.chevron_right_rounded,
                        color: Colors.white, size: 18),
                  ),
                ],
              ),
              if (widget.query.isNotEmpty &&
                  matchedSubs.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: matchedSubs
                      .take(4)
                      .map((s) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                      BorderRadius.circular(20),
                      border: Border.all(
                          color:
                          cat.color.withOpacity(0.20)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(s.icon,
                            size: 12, color: cat.color),
                        const SizedBox(width: 4),
                        Text(s.name,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: cat.color)),
                      ],
                    ),
                  ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  final String query;
  const _EmptySearch({required this.query});

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
              child: const Icon(Icons.search_off_rounded,
                  size: 38, color: Color(0xFF7C3AED)),
            ),
            const SizedBox(height: 20),
            Text('No results for "$query"',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937)),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
              'Try a different keyword like\n"plumber", "AC repair" or "tutor"',
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
// LOCATION ALERT DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _LocationAlertDialog extends StatelessWidget {
  final VoidCallback onSetNow, onLater;
  const _LocationAlertDialog(
      {required this.onSetNow, required this.onLater});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
                color: Color(0x1A7C3AED),
                blurRadius: 40,
                offset: Offset(0, 16))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6D28D9), Color(0xFF9D5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Color(0x597C3AED),
                      blurRadius: 20,
                      offset: Offset(0, 8))
                ],
              ),
              child: const Icon(Icons.location_on_rounded,
                  size: 40, color: Colors.white),
            ),
            const SizedBox(height: 20),
            const Text('Set Your Location',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937)),
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            const Text(
              'Enable your location so we can connect you with nearby helpers and show services available in your area.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                  height: 1.55),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(16)),
              child: const Column(
                children: [
                  _Perk(
                      icon: Icons.people_outline_rounded,
                      text:
                      'Find verified helpers near you instantly'),
                  SizedBox(height: 10),
                  _Perk(
                      icon: Icons.timelapse_rounded,
                      text: 'Get accurate arrival time estimates'),
                  SizedBox(height: 10),
                  _Perk(
                      icon: Icons.local_offer_outlined,
                      text: 'Discover local deals and offers'),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: onSetNow,
                icon: const Icon(Icons.my_location_rounded,
                    size: 20, color: Colors.white),
                label: const Text('Set Location Now',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: onLater,
              child: const Text('Maybe Later',
                  style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Perk extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Perk({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
              color: const Color(0xFFEDE9FE),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: const Color(0xFF7C3AED)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(text,
                style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF374151),
                    fontWeight: FontWeight.w500)),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUB-SERVICES BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _SubServicesSheet extends StatelessWidget {
  final _Category cat;
  const _SubServicesSheet({required this.cat});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.60,
      minChildSize: 0.40,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 30,
                offset: Offset(0, -4)),
          ],
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2)),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _lighten(cat.color, 0.04),
                    _darken(cat.color, 0.10),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: cat.color.withOpacity(0.28),
                    blurRadius: 16,
                    spreadRadius: -2,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.28)),
                    ),
                    child: Icon(cat.categoryIcon,
                        color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cat.title,
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.1)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${cat.subs.length} services available near you',
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.22),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withOpacity(0.30)),
                      ),
                      child: const Icon(Icons.close_rounded,
                          size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                physics: const ClampingScrollPhysics(),
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.86,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: cat.subs.length,
                itemBuilder: (_, i) => RepaintBoundary(
                  child: _SubServiceItem(
                    sub: cat.subs[i],
                    allSubs: cat.subs,
                    color: cat.color,
                    bgColor: cat.bgColor,
                    categoryTitle: cat.title,
                    categoryIcon: cat.categoryIcon,
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
// SUB SERVICE ITEM
// ─────────────────────────────────────────────────────────────────────────────

class _SubServiceItem extends StatefulWidget {
  final _SubService sub;
  final List<_SubService> allSubs;
  final Color color, bgColor;
  final String categoryTitle;
  final IconData categoryIcon;
  const _SubServiceItem({
    required this.sub,
    required this.allSubs,
    required this.color,
    required this.bgColor,
    required this.categoryTitle,
    required this.categoryIcon,
  });

  @override
  State<_SubServiceItem> createState() => _SubServiceItemState();
}

class _SubServiceItemState extends State<_SubServiceItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        if (widget.sub.name == 'Mid-Night Vehicle Emergency') {
          Navigator.pop(context);
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) =>
              const MidNightEmergencyScreen(),
              transitionsBuilder: (_, animation, __, child) {
                final curved = CurvedAnimation(
                    parent: animation, curve: Curves.easeOutCubic);
                return FadeTransition(
                  opacity: Tween<double>(begin: 0.0, end: 1.0)
                      .animate(curved),
                  child: SlideTransition(
                    position: Tween<Offset>(
                        begin: const Offset(0, 0.04),
                        end: Offset.zero)
                        .animate(curved),
                    child: child,
                  ),
                );
              },
              transitionDuration: const Duration(milliseconds: 280),
            ),
          );
          return;
        }
        Navigator.pop(context);
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => HelperListScreen(
              serviceName: widget.sub.name,
              categoryName: widget.categoryTitle,
              subServices: widget.allSubs
                  .map((s) => SubServiceItem(s.name, s.icon))
                  .toList(),
              serviceColor: widget.color,
              serviceBgColor: widget.bgColor,
              categoryEmoji: '',
            ),
            transitionsBuilder: (_, animation, __, child) {
              final curved = CurvedAnimation(
                  parent: animation, curve: Curves.easeOutCubic);
              return FadeTransition(
                opacity: Tween<double>(begin: 0.0, end: 1.0)
                    .animate(curved),
                child: SlideTransition(
                  position: Tween<Offset>(
                      begin: const Offset(0.04, 0),
                      end: Offset.zero)
                      .animate(curved),
                  child: child,
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 260),
          ),
        );
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()
          ..scale(_pressed ? 0.92 : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: _pressed
              ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _lighten(widget.color, 0.06),
              _darken(widget.color, 0.08),
            ],
          )
              : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              widget.bgColor.withOpacity(0.55),
            ],
          ),
          border: Border.all(
            color: _pressed
                ? Colors.transparent
                : widget.color.withOpacity(0.14),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.color
                  .withOpacity(_pressed ? 0.20 : 0.07),
              blurRadius: _pressed ? 6 : 10,
              spreadRadius: -2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _pressed
                    ? LinearGradient(colors: [
                  Colors.white.withOpacity(0.25),
                  Colors.white.withOpacity(0.12),
                ])
                    : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    widget.bgColor,
                    _lighten(widget.color, 0.28),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                widget.sub.icon,
                color: _pressed ? Colors.white : widget.color,
                size: 22,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Text(
                widget.sub.name,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _pressed ? Colors.white : widget.color,
                  letterSpacing: 0.1,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED HELPERS
// ─────────────────────────────────────────────────────────────────────────────

void _pushFade(BuildContext context, Widget page, {int ms = 260}) {
  Navigator.push(
    context,
    PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(
              parent: animation, curve: Curves.easeOut),
          child: child),
      transitionDuration: Duration(milliseconds: ms),
    ),
  );
}