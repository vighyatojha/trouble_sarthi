import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'auth/login_screen.dart';
import 'auth/signup_screen.dart';

Color _darken(Color c, [double amount = 0.18]) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
}

Color _lighten(Color c, [double amount = 0.18]) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
}

PageRoute<T> _fadeSlideRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 260),
  );
}

class _MockHelper {
  final String name;
  final Color color;
  const _MockHelper(this.name, this.color);
  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0][0].toUpperCase();
  }
}

const _kMockHelpers = [
  _MockHelper('Raj Kumar', Color(0xFF7C3AED)),
  _MockHelper('Amit Patel', Color(0xFF0891B2)),
  _MockHelper('Suresh Mehta', Color(0xFF059669)),
  _MockHelper('Priya Joshi', Color(0xFFDB2777)),
  _MockHelper('Vikram Shah', Color(0xFFD97706)),
  _MockHelper('Neha Singh', Color(0xFF4338CA)),
];

class _GuestSubService {
  final String name;
  final IconData icon;
  const _GuestSubService(this.name, this.icon);
}

class _GuestCategory {
  final String title;
  final IconData categoryIcon;
  final Color color;
  final Color bgColor;
  final String subtitle;
  final List<_GuestSubService> subs;
  const _GuestCategory({
    required this.title,
    required this.categoryIcon,
    required this.color,
    required this.bgColor,
    required this.subtitle,
    required this.subs,
  });
}

// ── 12 categories mirroring home_screen.dart exactly ──────────────────────────
const _kGuestCategories = <_GuestCategory>[
  _GuestCategory(
    title: 'Home Services',
    categoryIcon: Icons.home_repair_service_rounded,
    color: Color(0xFF7C3AED),
    bgColor: Color(0xFFEDE9FE),
    subtitle: 'Plumber · AC · Electric',
    subs: [
      _GuestSubService('Plumber', Icons.water_drop_outlined),
      _GuestSubService('Electrician', Icons.bolt_outlined),
      _GuestSubService('Carpenter', Icons.carpenter),
      _GuestSubService('AC Repair', Icons.ac_unit_outlined),
      _GuestSubService('RO Repair', Icons.water_outlined),
      _GuestSubService('Appliance Repair', Icons.kitchen_outlined),
      _GuestSubService('Painter', Icons.format_paint_outlined),
      _GuestSubService('Cleaner', Icons.cleaning_services_outlined),
    ],
  ),
  _GuestCategory(
    title: 'Vehicle Services',
    categoryIcon: Icons.directions_car_rounded,
    color: Color(0xFF0284C7),
    bgColor: Color(0xFFE0F2FE),
    subtitle: 'Car · Bike · Towing',
    subs: [
      _GuestSubService('Car Mechanic', Icons.car_repair),
      _GuestSubService('Bike Mechanic', Icons.two_wheeler),
      _GuestSubService('Towing Service', Icons.local_shipping_outlined),
      _GuestSubService('Puncture Repair', Icons.tire_repair),
      _GuestSubService('Car Wash', Icons.local_car_wash_outlined),
      _GuestSubService('Battery Jump Start', Icons.battery_charging_full_outlined),
    ],
  ),
  _GuestCategory(
    title: 'Emergency',
    categoryIcon: Icons.local_hospital_rounded,
    color: Color(0xFFDC2626),
    bgColor: Color(0xFFFEE2E2),
    subtitle: 'Ambulance · First Aid · 24×7',
    subs: [
      _GuestSubService('Ambulance', Icons.local_hospital_outlined),
      _GuestSubService('First Aid', Icons.medical_services_outlined),
      _GuestSubService('Blood Donor', Icons.bloodtype_outlined),
      _GuestSubService('Fire Help', Icons.local_fire_department_outlined),
      _GuestSubService('Disaster Support', Icons.warning_amber_outlined),
      _GuestSubService('Mid-Night Vehicle Emergency', Icons.nights_stay_rounded),
    ],
  ),
  _GuestCategory(
    title: 'Delivery & Pickup',
    categoryIcon: Icons.local_shipping_rounded,
    color: Color(0xFFD97706),
    bgColor: Color(0xFFFEF3C7),
    subtitle: 'Parcels · Grocery · Meds',
    subs: [
      _GuestSubService('Parcel Pickup', Icons.local_post_office_outlined),
      _GuestSubService('Grocery Delivery', Icons.shopping_basket_outlined),
      _GuestSubService('Medicine Delivery', Icons.medication_outlined),
      _GuestSubService('Document Courier', Icons.description_outlined),
      _GuestSubService('Local Shifting', Icons.move_to_inbox_outlined),
    ],
  ),
  _GuestCategory(
    title: 'Technical Services',
    categoryIcon: Icons.build_rounded,
    color: Color(0xFF0891B2),
    bgColor: Color(0xFFCFFAFE),
    subtitle: 'Mobile · Laptop · WiFi',
    subs: [
      _GuestSubService('Mobile Repair', Icons.phone_android_outlined),
      _GuestSubService('Laptop Repair', Icons.laptop_outlined),
      _GuestSubService('CCTV Install', Icons.videocam_outlined),
      _GuestSubService('WiFi Install', Icons.wifi_outlined),
      _GuestSubService('Software Help', Icons.code_outlined),
    ],
  ),
  _GuestCategory(
    title: 'Personal Assistance',
    categoryIcon: Icons.school_rounded,
    color: Color(0xFF059669),
    bgColor: Color(0xFFD1FAE5),
    subtitle: 'Tutor · Trainer · Care',
    subs: [
      _GuestSubService('Home Tutor', Icons.school_outlined),
      _GuestSubService('Fitness Trainer', Icons.fitness_center_outlined),
      _GuestSubService('Yoga Instructor', Icons.self_improvement_outlined),
      _GuestSubService('Caretaker', Icons.elderly_outlined),
      _GuestSubService('Babysitter', Icons.child_care_outlined),
    ],
  ),
  _GuestCategory(
    title: 'Events & Occasions',
    categoryIcon: Icons.celebration_rounded,
    color: Color(0xFFDB2777),
    bgColor: Color(0xFFFCE7F3),
    subtitle: 'Photo · DJ · Decor',
    subs: [
      _GuestSubService('Photographer', Icons.camera_alt_outlined),
      _GuestSubService('Videographer', Icons.videocam_outlined),
      _GuestSubService('DJ', Icons.music_note_outlined),
      _GuestSubService('Decoration', Icons.auto_awesome_outlined),
      _GuestSubService('Catering', Icons.restaurant_outlined),
    ],
  ),
  _GuestCategory(
    title: 'Construction',
    categoryIcon: Icons.foundation_rounded,
    color: Color(0xFF92400E),
    bgColor: Color(0xFFFDE68A),
    subtitle: 'Mason · Interior · Tiles',
    subs: [
      _GuestSubService('Mason', Icons.foundation_outlined),
      _GuestSubService('Interior Design', Icons.design_services_outlined),
      _GuestSubService('Tiles Worker', Icons.grid_on_outlined),
      _GuestSubService('Architect Help', Icons.architecture_outlined),
      _GuestSubService('Fabrication', Icons.handyman_outlined),
    ],
  ),
  _GuestCategory(
    title: 'Cleaning',
    categoryIcon: Icons.cleaning_services_rounded,
    color: Color(0xFF0D9488),
    bgColor: Color(0xFFCCFBF1),
    subtitle: 'Deep · Pest · Tank',
    subs: [
      _GuestSubService('Deep Cleaning', Icons.clean_hands_outlined),
      _GuestSubService('Bathroom Clean', Icons.bathroom_outlined),
      _GuestSubService('Sofa Cleaning', Icons.chair_outlined),
      _GuestSubService('Pest Control', Icons.pest_control_outlined),
      _GuestSubService('Water Tank', Icons.water_outlined),
    ],
  ),
  _GuestCategory(
    title: 'Professional',
    categoryIcon: Icons.gavel_rounded,
    color: Color(0xFF4338CA),
    bgColor: Color(0xFFE0E7FF),
    subtitle: 'Legal · CA · Insurance',
    subs: [
      _GuestSubService('Lawyer Consult', Icons.gavel_outlined),
      _GuestSubService('CA / Tax Help', Icons.calculate_outlined),
      _GuestSubService('Insurance', Icons.shield_outlined),
      _GuestSubService('Real Estate', Icons.apartment_outlined),
    ],
  ),
  _GuestCategory(
    title: 'Outdoor & More',
    categoryIcon: Icons.park_rounded,
    color: Color(0xFF16A34A),
    bgColor: Color(0xFFDCFCE7),
    subtitle: 'Garden · Guard · Driver',
    subs: [
      _GuestSubService('Gardener', Icons.yard_outlined),
      _GuestSubService('Security Guard', Icons.security_outlined),
      _GuestSubService('Driver on Hire', Icons.directions_car_outlined),
      _GuestSubService('Scrap Collector', Icons.recycling_outlined),
    ],
  ),
  _GuestCategory(
    title: 'Community Help',
    categoryIcon: Icons.volunteer_activism_rounded,
    color: Color(0xFF7C3AED),
    bgColor: Color(0xFFF3E8FF),
    subtitle: 'Volunteer · NGO · Senior',
    subs: [
      _GuestSubService('Volunteer Help', Icons.volunteer_activism_outlined),
      _GuestSubService('Senior Support', Icons.elderly_outlined),
      _GuestSubService('Student Helper', Icons.school_outlined),
      _GuestSubService('NGO Support', Icons.favorite_border),
    ],
  ),
];

// ═══════════════════════════════════════════════════════════════════════════
//  GUEST LANDING PAGE
// ═══════════════════════════════════════════════════════════════════════════
class GuestLandingPage extends StatefulWidget {
  const GuestLandingPage({super.key});
  @override
  State<GuestLandingPage> createState() => _GuestLandingPageState();
}

class _GuestLandingPageState extends State<GuestLandingPage>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _showAuthDialog = false;

  void _onItemTapped(int index) {
    if (index == 0) {
      setState(() { _selectedIndex = 0; _showAuthDialog = false; });
    } else {
      setState(() => _selectedIndex = index);
      _showAuthOverlay();
    }
  }

  void _navigateToLogin() => Navigator.push(context, _fadeSlideRoute(const LoginScreen()));
  void _navigateToSignUp() => Navigator.push(context, _fadeSlideRoute(const SignUpScreen()));

  void _closeAndLogin() {
    setState(() { _showAuthDialog = false; _selectedIndex = 0; });
    Future.delayed(const Duration(milliseconds: 80), _navigateToLogin);
  }

  void _closeAndSignUp() {
    setState(() { _showAuthDialog = false; _selectedIndex = 0; });
    Future.delayed(const Duration(milliseconds: 80), _navigateToSignUp);
  }

  void _showAuthOverlay() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _showAuthDialog = true);
    });
  }

  void _openSubServices(_GuestCategory cat) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _GuestSubServicesSheet(cat: cat, onAuthRequired: _showAuthOverlay),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F8),
      body: Stack(
        children: [
          CustomScrollView(
            physics: const ClampingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _HeroHeader(onLogin: _navigateToLogin)),
              const SliverToBoxAdapter(child: _QuickStatsStrip()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Our Services', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF111827))),
                      Text('${_kGuestCategories.length} categories', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF7C3AED))),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _ServiceGrid(onCategoryTap: _openSubServices)),
              SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 24, 20, 0), child: _GetHelpButton(onTap: _navigateToLogin))),
              SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 0), child: _EmergencyBanner(onTap: _navigateToLogin))),
              SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 24, 20, 14), child: Text('Popular near you', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF111827))))),
              SliverToBoxAdapter(child: _PopularSection(onTap: _navigateToLogin)),
              const SliverToBoxAdapter(child: _TrustFooter()),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
          Positioned(
            left: 16, right: 16, bottom: 20,
            child: SafeArea(top: false, child: _FloatingNav(selectedIndex: _selectedIndex, onTap: _onItemTapped)),
          ),
          if (_showAuthDialog)
            GestureDetector(
              onTap: () => setState(() { _showAuthDialog = false; _selectedIndex = 0; }),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(
                  color: Colors.black.withOpacity(0.22),
                  child: Center(child: _AuthDialog(onLogin: _closeAndLogin, onSignUp: _closeAndSignUp)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Hero Header ──────────────────────────────────────────────────────────────
class _HeroHeader extends StatelessWidget {
  final VoidCallback onLogin;
  const _HeroHeader({required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF1A0533), Color(0xFF2D1060), Color(0xFF4C1D95)]),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned(top: -30, right: -50, child: Container(width: 200, height: 200, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.04)))),
            Positioned(top: 40, right: 30, child: Container(width: 90, height: 90, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF7C3AED).withOpacity(0.25)))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.15))),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF4ADE80), shape: BoxShape.circle)),
                              const SizedBox(width: 5),
                              Text('GUEST MODE', style: GoogleFonts.nunito(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
                            ]),
                          ),
                          const SizedBox(height: 8),
                          ShaderMask(
                            shaderCallback: (b) => const LinearGradient(colors: [Color(0xFFE0D0FF), Color(0xFFFFFFFF)]).createShader(b),
                            child: const Text('Trouble Sarthi', style: TextStyle(fontFamily: 'Saman', fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.3)),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: onLogin,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF9D6FFF)]),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withOpacity(0.45), blurRadius: 16, offset: const Offset(0, 6))],
                          ),
                          child: Text('Login', style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('What can we\nfix for you today?', style: GoogleFonts.nunito(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2)),
                  const SizedBox(height: 6),
                  Text('Browse helpers — free, no login needed.', style: GoogleFonts.nunito(fontSize: 13, color: Colors.white.withOpacity(0.55), fontWeight: FontWeight.w500)),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: onLogin,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.15))),
                      child: Row(children: [
                        Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.5), size: 20),
                        const SizedBox(width: 10),
                        Text('Search for a service...', style: GoogleFonts.nunito(fontSize: 14, color: Colors.white.withOpacity(0.4), fontWeight: FontWeight.w500)),
                      ]),
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

// ─── Quick Stats Strip ────────────────────────────────────────────────────────
class _QuickStatsStrip extends StatelessWidget {
  const _QuickStatsStrip();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF4C1D95),
      child: Container(
        decoration: const BoxDecoration(color: Color(0xFFF2F3F8), borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28))),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Row(children: [
          _StatPill(icon: Icons.verified_rounded, value: '500+', label: 'Verified Helpers', color: const Color(0xFF7C3AED)),
          const SizedBox(width: 10),
          _StatPill(icon: Icons.star_rounded, value: '4.9★', label: 'Avg Rating', color: const Color(0xFFF59E0B)),
          const SizedBox(width: 10),
          _StatPill(icon: Icons.bolt_rounded, value: '30 min', label: 'Avg Response', color: const Color(0xFF059669)),
        ]),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color color;
  const _StatPill({required this.icon, required this.value, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 3))]),
        child: Column(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF111827))),
          Text(label, textAlign: TextAlign.center, style: GoogleFonts.nunito(fontSize: 9, color: const Color(0xFF9CA3AF), fontWeight: FontWeight.w600, height: 1.2)),
        ]),
      ),
    );
  }
}

// ─── Service Grid ─────────────────────────────────────────────────────────────
class _ServiceGrid extends StatelessWidget {
  final void Function(_GuestCategory) onCategoryTap;
  const _ServiceGrid({required this.onCategoryTap});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.0, crossAxisSpacing: 14, mainAxisSpacing: 14),
        itemCount: _kGuestCategories.length,
        itemBuilder: (_, i) => _ServiceCard(cat: _kGuestCategories[i], onTap: () => onCategoryTap(_kGuestCategories[i])),
      ),
    );
  }
}

class _ServiceCard extends StatefulWidget {
  final _GuestCategory cat;
  final VoidCallback onTap;
  const _ServiceCard({required this.cat, required this.onTap});
  @override
  State<_ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<_ServiceCard> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final cat = widget.cat;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), boxShadow: [BoxShadow(color: cat.color.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4))]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(children: [
              Positioned(top: -28, right: -28, child: Container(width: 90, height: 90, decoration: BoxDecoration(shape: BoxShape.circle, color: cat.bgColor.withOpacity(0.6)))),
              Positioned(top: 8, right: -10, child: Container(width: 55, height: 55, decoration: BoxDecoration(shape: BoxShape.circle, color: cat.bgColor.withOpacity(0.35)))),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: 50, height: 50, decoration: BoxDecoration(color: cat.bgColor, borderRadius: BorderRadius.circular(15)), child: Icon(cat.categoryIcon, color: cat.color, size: 24)),
                  const Spacer(),
                  Text(cat.title, style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w900, color: const Color(0xFF111827))),
                  const SizedBox(height: 2),
                  Text(cat.subtitle, style: GoogleFonts.nunito(fontSize: 10, color: const Color(0xFF9CA3AF), fontWeight: FontWeight.w600, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: cat.bgColor, borderRadius: BorderRadius.circular(8)),
                    child: Text('${cat.subs.length} services', style: GoogleFonts.nunito(fontSize: 9, fontWeight: FontWeight.w700, color: cat.color)),
                  ),
                  const SizedBox(height: 8),
                  Container(height: 3, width: 32, decoration: BoxDecoration(color: cat.color, borderRadius: BorderRadius.circular(2))),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── Sub-Services Sheet ───────────────────────────────────────────────────────
class _GuestSubServicesSheet extends StatelessWidget {
  final _GuestCategory cat;
  final VoidCallback onAuthRequired;
  const _GuestSubServicesSheet({required this.cat, required this.onAuthRequired});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.58, minChildSize: 0.38, maxChildSize: 0.92, expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28)), boxShadow: [BoxShadow(color: Color(0x1A000000), blurRadius: 30, offset: Offset(0, -4))]),
        child: Column(children: [
          Container(margin: const EdgeInsets.only(top: 12), width: 42, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_lighten(cat.color, 0.04), _darken(cat.color, 0.10)]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: cat.color.withOpacity(0.28), blurRadius: 16, spreadRadius: -2, offset: const Offset(0, 6))],
            ),
            child: Row(children: [
              Container(width: 54, height: 54, decoration: BoxDecoration(color: Colors.white.withOpacity(0.20), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.28))), child: Icon(cat.categoryIcon, color: Colors.white, size: 26)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(cat.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.1)),
                const SizedBox(height: 4),
                Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3), decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), borderRadius: BorderRadius.circular(20)), child: Text('${cat.subs.length} services available', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white))),
              ])),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.30))), child: const Icon(Icons.close_rounded, size: 16, color: Colors.white)),
              ),
            ]),
          ),
          Expanded(
            child: GridView.builder(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              physics: const ClampingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.86, crossAxisSpacing: 10, mainAxisSpacing: 10),
              itemCount: cat.subs.length,
              itemBuilder: (_, i) => _GuestSubServiceItem(sub: cat.subs[i], cat: cat, onAuthRequired: onAuthRequired),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Sub-Service Item ─────────────────────────────────────────────────────────
class _GuestSubServiceItem extends StatefulWidget {
  final _GuestSubService sub;
  final _GuestCategory cat;
  final VoidCallback onAuthRequired;
  const _GuestSubServiceItem({required this.sub, required this.cat, required this.onAuthRequired});
  @override
  State<_GuestSubServiceItem> createState() => _GuestSubServiceItemState();
}

class _GuestSubServiceItemState extends State<_GuestSubServiceItem> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true, useSafeArea: true,
            builder: (_) => _GuestHelperListSheet(serviceName: widget.sub.name, cat: widget.cat, onAuthRequired: widget.onAuthRequired));
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()..scale(_pressed ? 0.92 : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: _pressed
              ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_lighten(widget.cat.color, 0.06), _darken(widget.cat.color, 0.08)])
              : LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white, widget.cat.bgColor.withOpacity(0.55)]),
          border: Border.all(color: _pressed ? Colors.transparent : widget.cat.color.withOpacity(0.14), width: 1),
          boxShadow: [BoxShadow(color: widget.cat.color.withOpacity(_pressed ? 0.20 : 0.07), blurRadius: _pressed ? 6 : 10, spreadRadius: -2, offset: const Offset(0, 4))],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _pressed
                  ? LinearGradient(colors: [Colors.white.withOpacity(0.25), Colors.white.withOpacity(0.12)])
                  : LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [widget.cat.bgColor, _lighten(widget.cat.color, 0.28)]),
              boxShadow: [BoxShadow(color: widget.cat.color.withOpacity(0.12), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Icon(widget.sub.icon, color: _pressed ? Colors.white : widget.cat.color, size: 22),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Text(widget.sub.name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _pressed ? Colors.white : widget.cat.color, letterSpacing: 0.1, height: 1.2), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ]),
      ),
    );
  }
}

// ─── Helper List Sheet ────────────────────────────────────────────────────────
class _GuestHelperListSheet extends StatelessWidget {
  final String serviceName;
  final _GuestCategory cat;
  final VoidCallback onAuthRequired;
  const _GuestHelperListSheet({required this.serviceName, required this.cat, required this.onAuthRequired});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.70, minChildSize: 0.45, maxChildSize: 0.92, expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(color: Color(0xFFF4F6FB), borderRadius: BorderRadius.vertical(top: Radius.circular(28)), boxShadow: [BoxShadow(color: Color(0x1A000000), blurRadius: 30, offset: Offset(0, -4))]),
        child: Column(children: [
          Container(
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            child: Column(children: [
              Container(margin: const EdgeInsets.only(top: 12), width: 42, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(children: [
                  Container(width: 42, height: 42, decoration: BoxDecoration(color: cat.bgColor, borderRadius: BorderRadius.circular(12)), child: Icon(cat.categoryIcon, color: cat.color, size: 20)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(serviceName, style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF111827))),
                    Text('${_kMockHelpers.length} helpers available', style: GoogleFonts.nunito(fontSize: 12, color: const Color(0xFF9CA3AF), fontWeight: FontWeight.w600)),
                  ])),
                  GestureDetector(onTap: () => Navigator.pop(ctx), child: Container(padding: const EdgeInsets.all(7), decoration: const BoxDecoration(color: Color(0xFFF3F4F6), shape: BoxShape.circle), child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF6B7280)))),
                ]),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: const Color(0xFFF5F3FF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.18))),
                child: Row(children: [
                  const Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Login to see ratings, contact & book a helper', style: GoogleFonts.nunito(fontSize: 11, color: const Color(0xFF6D28D9), fontWeight: FontWeight.w600))),
                ]),
              ),
            ]),
          ),
          Expanded(
            child: GridView.builder(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              physics: const ClampingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.78, crossAxisSpacing: 12, mainAxisSpacing: 12),
              itemCount: _kMockHelpers.length,
              itemBuilder: (_, i) => _GuestHelperCard(helper: _kMockHelpers[i], onTap: onAuthRequired),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Helper Card ──────────────────────────────────────────────────────────────
class _GuestHelperCard extends StatefulWidget {
  final _MockHelper helper;
  final VoidCallback onTap;
  const _GuestHelperCard({required this.helper, required this.onTap});
  @override
  State<_GuestHelperCard> createState() => _GuestHelperCardState();
}

class _GuestHelperCardState extends State<_GuestHelperCard> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        transform: Matrix4.identity()..scale(_pressed ? 0.93 : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: widget.helper.color.withOpacity(_pressed ? 0.18 : 0.07), blurRadius: _pressed ? 6 : 12, offset: const Offset(0, 4))]),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Stack(children: [
              Container(
                width: 58, height: 58,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_lighten(widget.helper.color, 0.12), widget.helper.color]), boxShadow: [BoxShadow(color: widget.helper.color.withOpacity(0.30), blurRadius: 10, offset: const Offset(0, 4))]),
                child: Center(child: Text(widget.helper.initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 0.5))),
              ),
              Positioned(right: 2, bottom: 2, child: Container(width: 13, height: 13, decoration: BoxDecoration(color: const Color(0xFF22C55E), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
            ]),
            const SizedBox(height: 10),
            Text(widget.helper.name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF111827), height: 1.2)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFFF5F3FF), borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.lock_rounded, size: 8, color: Color(0xFF7C3AED)),
                const SizedBox(width: 3),
                Text('Book', style: GoogleFonts.nunito(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF7C3AED))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Get Help Button ──────────────────────────────────────────────────────────
class _GetHelpButton extends StatelessWidget {
  final VoidCallback onTap;
  const _GetHelpButton({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF9D6FFF)], begin: Alignment.centerLeft, end: Alignment.centerRight), borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withOpacity(0.38), blurRadius: 18, offset: const Offset(0, 7))]),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.flash_on_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Text('Get Help Now', style: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(width: 10),
          Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16)),
        ]),
      ),
    );
  }
}

// ─── Emergency Banner ─────────────────────────────────────────────────────────
class _EmergencyBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _EmergencyBanner({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF7F1D1D), Color(0xFFDC2626)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: const Color(0xFFDC2626).withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))]),
        child: Row(children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle), child: const Center(child: Text('SOS', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5)))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('24×7 Emergency Help', style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
            Text('Tap to call for immediate assistance', style: GoogleFonts.nunito(fontSize: 11, color: Colors.white.withOpacity(0.75), fontWeight: FontWeight.w500)),
          ])),
          const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 22),
        ]),
      ),
    );
  }
}

// ─── Popular Section ──────────────────────────────────────────────────────────
class _PopularSection extends StatelessWidget {
  final VoidCallback onTap;
  const _PopularSection({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(children: [
        _PopularCard(icon: Icons.directions_car_rounded, iconColor: const Color(0xFF0284C7), iconBgColor: const Color(0xFFE0F2FE), title: 'Vehicle 24×7 Service', subtitle: 'Emergency roadside assistance anytime', tag: 'Most Booked', tagColor: const Color(0xFF7C3AED), rating: '4.9', jobs: '1.2k+', onTap: onTap),
        const SizedBox(height: 12),
        _PopularCard(icon: Icons.plumbing_rounded, iconColor: const Color(0xFF0891B2), iconBgColor: const Color(0xFFCFFAFE), title: 'Plumbing Service', subtitle: 'Expert plumbers for all your needs', tag: 'Quick Hire', tagColor: const Color(0xFF059669), rating: '4.8', jobs: '900+', onTap: onTap),
        const SizedBox(height: 12),
        _PopularCard(icon: Icons.bolt_rounded, iconColor: const Color(0xFFD97706), iconBgColor: const Color(0xFFFEF3C7), title: 'Electrical Repair', subtitle: 'Safe, certified electrical work', tag: 'Top Rated', tagColor: const Color(0xFFD97706), rating: '5.0', jobs: '650+', onTap: onTap),
      ]),
    );
  }
}

class _PopularCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor, iconBgColor, tagColor;
  final String title, subtitle, tag, rating, jobs;
  final VoidCallback onTap;
  const _PopularCard({required this.icon, required this.iconColor, required this.iconBgColor, required this.title, required this.subtitle, required this.tag, required this.tagColor, required this.rating, required this.jobs, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 3))]),
        child: Row(children: [
          Container(width: 58, height: 58, decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: iconColor, size: 28)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(title, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF111827)))),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: tagColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Text(tag, style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700, color: tagColor))),
            ]),
            const SizedBox(height: 3),
            Text(subtitle, style: GoogleFonts.nunito(fontSize: 12, color: const Color(0xFF6B7280), fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
              const SizedBox(width: 3),
              Text(rating, style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1F2937))),
              const SizedBox(width: 8),
              Text('·', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              const SizedBox(width: 8),
              Text('$jobs jobs', style: GoogleFonts.nunito(fontSize: 11, color: const Color(0xFF9CA3AF), fontWeight: FontWeight.w600)),
            ]),
          ])),
        ]),
      ),
    );
  }
}

// ─── Trust Footer ─────────────────────────────────────────────────────────────
class _TrustFooter extends StatelessWidget {
  const _TrustFooter();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFF5F3FF), Color(0xFFEDE9FE)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.12))),
      child: Column(children: [
        Text('Why Trouble Sarthi?', style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w900, color: const Color(0xFF1F2937))),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _TrustItem(icon: Icons.verified_user_rounded, label: 'Verified\nHelpers', color: const Color(0xFF7C3AED)),
          _TrustItem(icon: Icons.lock_rounded, label: 'Escrow\nPayment', color: const Color(0xFF059669)),
          _TrustItem(icon: Icons.support_agent_rounded, label: '24×7\nSupport', color: const Color(0xFF0891B2)),
          _TrustItem(icon: Icons.price_check_rounded, label: 'Fixed\nPricing', color: const Color(0xFFD97706)),
        ]),
      ]),
    );
  }
}

class _TrustItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _TrustItem({required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(width: 42, height: 42, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: color, size: 20)),
      const SizedBox(height: 6),
      Text(label, textAlign: TextAlign.center, style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF374151), height: 1.3)),
    ]);
  }
}

// ─── Floating Nav (pill animation matching home_screen.dart) ──────────────────
class _FloatingNav extends StatelessWidget {
  final int selectedIndex;
  final void Function(int) onTap;
  const _FloatingNav({required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: Container(
        height: 68,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 24, offset: const Offset(0, 6)),
          BoxShadow(color: const Color(0xFF7C3AED).withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4)),
        ]),
        child: Row(children: [
          _FloatNavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home', selected: selectedIndex == 0, onTap: () => onTap(0)),
          _FloatNavItem(icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today_rounded, label: 'Bookings', selected: selectedIndex == 1, showDot: true, onTap: () => onTap(1)),
          _FloatNavItem(icon: Icons.notifications_outlined, activeIcon: Icons.notifications_rounded, label: 'Alerts', selected: selectedIndex == 2, showDot: true, onTap: () => onTap(2)),
          _FloatNavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile', selected: selectedIndex == 3, showDot: true, onTap: () => onTap(3)),
        ]),
      ),
    );
  }
}

class _FloatNavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final bool selected, showDot;
  final VoidCallback onTap;
  const _FloatNavItem({required this.icon, required this.activeIcon, required this.label, required this.selected, required this.onTap, this.showDot = false});

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF7C3AED) : const Color(0xFF9CA3AF);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          // ── Pill shrinks to 0×0 when inactive ────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: selected ? 40 : 0,
            height: selected ? 32 : 0,
            decoration: BoxDecoration(color: selected ? const Color(0xFF7C3AED).withOpacity(0.12) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
            child: selected ? Icon(activeIcon, size: 20, color: const Color(0xFF7C3AED)) : const SizedBox.shrink(),
          ),
          if (!selected) Stack(clipBehavior: Clip.none, children: [
            Icon(icon, size: 20, color: color),
            if (showDot) Positioned(right: -2, top: -2, child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle))),
          ]),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: GoogleFonts.nunito(fontSize: 9, color: color, fontWeight: selected ? FontWeight.w800 : FontWeight.w500),
            child: Text(label),
          ),
        ]),
      ),
    );
  }
}

// ─── Auth Dialog ──────────────────────────────────────────────────────────────
class _AuthDialog extends StatelessWidget {
  final VoidCallback onLogin, onSignUp;
  const _AuthDialog({required this.onLogin, required this.onSignUp});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutBack,
      builder: (_, value, child) => Transform.scale(scale: value, child: Opacity(opacity: value.clamp(0.0, 1.0), child: child)),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 28),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: const [BoxShadow(color: Color(0x28000000), blurRadius: 40, offset: Offset(0, 20))]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF2D1060), Color(0xFF7C3AED)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28))),
            child: Column(children: [
              Container(width: 68, height: 68, decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.lock_rounded, color: Colors.white, size: 30)),
              const SizedBox(height: 12),
              Text('Login Required', style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Text('Sign in or create an account to\nbook helpers and access all features.', textAlign: TextAlign.center, style: GoogleFonts.nunito(fontSize: 13, color: const Color(0xFF6B7280), height: 1.6, fontWeight: FontWeight.w500)),
              const SizedBox(height: 22),
              SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: onLogin, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: Text('Login', style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)))),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, height: 50, child: OutlinedButton(onPressed: onSignUp, style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF7C3AED), side: const BorderSide(color: Color(0xFF7C3AED), width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: Text('Create Account', style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF7C3AED))))),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => Navigator.of(context, rootNavigator: true).pop(),
                child: Text('Continue browsing as guest', style: GoogleFonts.nunito(fontSize: 12, color: const Color(0xFF9CA3AF), fontWeight: FontWeight.w600, decoration: TextDecoration.underline)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}