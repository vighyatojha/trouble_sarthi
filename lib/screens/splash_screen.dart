import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:trouble_sarthi/screens/guest_landing_page.dart';
import 'home_screen.dart';

// ── Smooth route helpers ───────────────────────────────────────────────────────
Route<T> smoothFadeRoute<T>(Widget page, {int ms = 280}) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
    transitionDuration: Duration(milliseconds: ms),
  );
}

Route<T> smoothSlideRoute<T>(Widget page, {int ms = 260}) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      final curved =
      CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
              begin: const Offset(0.04, 0), end: Offset.zero)
              .animate(curved),
          child: child,
        ),
      );
    },
    transitionDuration: Duration(milliseconds: ms),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Splash Screen
// ─────────────────────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 900), vsync: this);
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );
    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve:
          const Interval(0.0, 0.7, curve: Curves.easeOutBack)),
    );
    _ctrl.forward();
    Timer(const Duration(milliseconds: 2000), _navigate);
  }

  void _navigate() {
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
        user != null ? const HomeScreen() : const OnboardingScreen(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity:
          CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF5B6FED),
              Color(0xFF4A5FE8),
              Color(0xFF3B4FD8)
            ],
          ),
        ),
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              ScaleTransition(
                scale: _scale,
                child: RepaintBoundary(
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.verified_user,
                          size: 54, color: Color(0xFF5B6FED)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Trouble Sarthi',
                style: GoogleFonts.poppins(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your Trusted Sarthi for Every Need',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 15, color: Colors.white70, height: 1.4),
              ),
              const Spacer(flex: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _dot(true),
                  const SizedBox(width: 6),
                  _dot(false),
                  const SizedBox(width: 6),
                  _dot(false),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'v 2.0.1',
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.white38,
                    letterSpacing: 1),
              ),
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot(bool active) => Container(
    width: active ? 22 : 7,
    height: 7,
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(active ? 1.0 : 0.35),
      borderRadius: BorderRadius.circular(4),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Onboarding Screen
// ─────────────────────────────────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static final List<_OnboardingData> _pages = [
    _OnboardingData(
      title: 'Book in',
      highlight: 'Just 3 Taps',
      description:
      'Choose a service, pick a time, and confirm. Get instant updates and live tracking right to your door.',
      bgColor: const Color(0xFFF0EDFF),
      accentColor: const Color(0xFF7C3FED),
      pageType: _PageType.booking,
    ),
    _OnboardingData(
      title: 'Verified, Rated &',
      highlight: 'Always Safe',
      description:
      'Every helper is background-checked, skill-tested, and continuously rated — so you\'re always in safe hands.',
      bgColor: const Color(0xFFE8F5F0),
      accentColor: const Color(0xFF00C97A),
      pageType: _PageType.trust,
    ),
  ];

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic);
    } else {
      _goToHome();
    }
  }

  void _goToHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const GuestLandingPage(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity:
          CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: page.bgColor,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // Top row
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentPage > 0)
                      IconButton(
                        icon: const Icon(
                            Icons.arrow_back_ios_new,
                            size: 20,
                            color: Color(0xFF6B7280)),
                        onPressed: () => _pageController.previousPage(
                            duration:
                            const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic),
                      )
                    else
                      const SizedBox(width: 48),
                    TextButton(
                      onPressed: _goToHome,
                      child: const Text('Skip',
                          style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),

              // Pages
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (i) =>
                      setState(() => _currentPage = i),
                  itemCount: _pages.length,
                  itemBuilder: (_, i) {
                    switch (_pages[i].pageType) {
                      case _PageType.booking:
                        return _BookingPage(data: _pages[i]);
                      case _PageType.trust:
                        return _TrustPage(data: _pages[i]);
                    }
                  },
                ),
              ),

              // Indicators
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                        (i) => _Indicator(
                      active: i == _currentPage,
                      color: _pages[_currentPage].accentColor,
                    ),
                  ),
                ),
              ),

              // CTA button
              Padding(
                padding:
                const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: _OnboardingButton(
                  label: _currentPage < _pages.length - 1
                      ? 'Next'
                      : 'Get Started',
                  color: page.accentColor,
                  onTap: _next,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Data model ───────────────────────────────────────────────────────────────
enum _PageType { booking, trust }

class _OnboardingData {
  final String title;
  final String highlight;
  final String description;
  final Color bgColor;
  final Color accentColor;
  final _PageType pageType;

  const _OnboardingData({
    required this.title,
    required this.highlight,
    required this.description,
    required this.bgColor,
    required this.accentColor,
    required this.pageType,
  });
}

// ─── Page 1: Booking illustration ────────────────────────────────────────────
class _BookingPage extends StatefulWidget {
  final _OnboardingData data;
  const _BookingPage({required this.data});

  @override
  State<_BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<_BookingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeCard;
  late final Animation<double> _fadeSteps;
  late final Animation<double> _fadeConfirm;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..forward();
    _fadeCard = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut));
    _fadeSteps = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.3, 0.65, curve: Curves.easeOut));
    _fadeConfirm = CurvedAnimation(
        parent: _ctrl,
        curve:
        const Interval(0.6, 1.0, curve: Curves.easeOutBack));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          SizedBox(
            height: size.height * 0.40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // ── Background circle glow ──────────────────────────
                Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF7C3FED).withOpacity(0.07),
                  ),
                ),

                // ── Service category chips at top ───────────────────
                Positioned(
                  top: 0,
                  child: FadeTransition(
                    opacity: _fadeCard,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        _ServiceChip(
                            icon: Icons.plumbing_rounded,
                            label: 'Plumbing',
                            active: false),
                        SizedBox(width: 8),
                        _ServiceChip(
                            icon: Icons.electrical_services_rounded,
                            label: 'Electrical',
                            active: true),
                        SizedBox(width: 8),
                        _ServiceChip(
                            icon: Icons.carpenter_rounded,
                            label: 'Carpentry',
                            active: false),
                      ],
                    ),
                  ),
                ),

                // ── Main booking card ────────────────────────────────
                Positioned(
                  top: 60,
                  child: FadeTransition(
                    opacity: _fadeCard,
                    child: SlideTransition(
                      position: Tween<Offset>(
                          begin: const Offset(0, 0.15),
                          end: Offset.zero)
                          .animate(_fadeCard),
                      child: _BookingCard(),
                    ),
                  ),
                ),

                // ── Step indicators below card ───────────────────────
                Positioned(
                  bottom: 38,
                  child: FadeTransition(
                    opacity: _fadeSteps,
                    child: _StepsRow(),
                  ),
                ),

                // ── Confirmed badge ──────────────────────────────────
                Positioned(
                  bottom: 0,
                  right: 16,
                  child: ScaleTransition(
                    scale: _fadeConfirm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF059669)
                                .withOpacity(0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          )
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text('Confirmed!',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── ETA badge top-left ───────────────────────────────
                Positioned(
                  top: 56,
                  left: 8,
                  child: FadeTransition(
                    opacity: _fadeSteps,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 14,
                              color: Color(0xFF7C3FED)),
                          SizedBox(width: 5),
                          Text('~15 min',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1F2937))),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _PageText(
              title: widget.data.title,
              highlight: widget.data.highlight,
              description: widget.data.description,
              accentColor: widget.data.accentColor),
        ],
      ),
    );
  }
}

// ── Service chip ──────────────────────────────────────────────────────────────
class _ServiceChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  const _ServiceChip(
      {required this.icon, required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF7C3FED) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: active
                  ? const Color(0xFF7C3FED).withOpacity(0.3)
                  : Colors.black.withOpacity(0.07),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 14,
              color: active
                  ? Colors.white
                  : const Color(0xFF7C3FED)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? Colors.white
                      : const Color(0xFF374151))),
        ],
      ),
    );
  }
}

// ── Booking card ──────────────────────────────────────────────────────────────
class _BookingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 270,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 24,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Icon(Icons.electrical_services_rounded,
                      color: Color(0xFF7C3FED), size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Electrical Repair',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827))),
                    const SizedBox(height: 2),
                    Text('Today, 4:00 PM',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500])),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(8)),
                child: const Text('₹350',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7C3FED))),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 12),

          // Helper row
          Row(
            children: [
              // Avatar
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF7C3FED), Color(0xFF9D6FFF)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('R',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Rajesh Kumar',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937))),
                    Row(children: [
                      const Icon(Icons.star_rounded,
                          size: 12, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 2),
                      Text('4.9  ·  127 jobs',
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey[500])),
                    ]),
                  ],
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                    color: const Color(0xFF059669),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.verified_rounded,
                    color: Colors.white, size: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Steps progress row ────────────────────────────────────────────────────────
class _StepsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepDot(label: 'Choose', done: true),
        _StepLine(done: true),
        _StepDot(label: 'Schedule', done: true),
        _StepLine(done: true),
        _StepDot(label: 'Confirm', done: true, active: true),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  final String label;
  final bool done;
  final bool active;
  const _StepDot(
      {required this.label, required this.done, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done
                ? const Color(0xFF7C3FED)
                : const Color(0xFFE5E7EB),
            boxShadow: active
                ? [
              BoxShadow(
                  color:
                  const Color(0xFF7C3FED).withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 3))
            ]
                : [],
          ),
          child: Icon(
            done ? Icons.check_rounded : Icons.circle,
            color: done ? Colors.white : const Color(0xFF9CA3AF),
            size: done ? 14 : 8,
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: done
                    ? const Color(0xFF7C3FED)
                    : const Color(0xFF9CA3AF))),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  final bool done;
  const _StepLine({required this.done});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 2,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: done
            ? const Color(0xFF7C3FED)
            : const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// ─── Page 3: Trust illustration ───────────────────────────────────────────────
class _TrustPage extends StatefulWidget {
  final _OnboardingData data;
  const _TrustPage({required this.data});

  @override
  State<_TrustPage> createState() => _TrustPageState();
}

class _TrustPageState extends State<_TrustPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeMain;
  late final Animation<double> _fadeBadges;
  late final Animation<double> _fadeEscrow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..forward();
    _fadeMain = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut));
    _fadeBadges = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.3, 0.7, curve: Curves.easeOutBack));
    _fadeEscrow = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOutBack));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          SizedBox(
            height: size.height * 0.40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // ── Soft glow ───────────────────────────────────────
                Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF00C97A).withOpacity(0.08),
                  ),
                ),

                // ── Main verified helper card ────────────────────────
                Positioned(
                  top: 10,
                  child: FadeTransition(
                    opacity: _fadeMain,
                    child: SlideTransition(
                      position: Tween<Offset>(
                          begin: const Offset(0, 0.12),
                          end: Offset.zero)
                          .animate(_fadeMain),
                      child: _HelperProfileCard(),
                    ),
                  ),
                ),

                // ── Trust badges row ─────────────────────────────────
                Positioned(
                  bottom: 52,
                  child: FadeTransition(
                    opacity: _fadeBadges,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        _TrustBadge(
                          icon: Icons.verified_user_rounded,
                          label: 'Background\nChecked',
                          color: Color(0xFF7C3FED),
                          bgColor: Color(0xFFEDE9FE),
                        ),
                        SizedBox(width: 10),
                        _TrustBadge(
                          icon: Icons.workspace_premium_rounded,
                          label: 'Skill\nCertified',
                          color: Color(0xFFF59E0B),
                          bgColor: Color(0xFFFEF3C7),
                        ),
                        SizedBox(width: 10),
                        _TrustBadge(
                          icon: Icons.shield_rounded,
                          label: 'Insured\nWork',
                          color: Color(0xFF00C97A),
                          bgColor: Color(0xFFD1FAE5),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Escrow payment badge ─────────────────────────────
                Positioned(
                  bottom: 0,
                  child: ScaleTransition(
                    scale: _fadeEscrow,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 16,
                              offset: const Offset(0, 5))
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD1FAE5),
                              borderRadius:
                              BorderRadius.circular(10),
                            ),
                            child: const Icon(
                                Icons.lock_rounded,
                                color: Color(0xFF059669),
                                size: 16),
                          ),
                          const SizedBox(width: 10),
                          const Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Escrow Payment',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1F2937))),
                              Text(
                                  'Paid only after job is done ✓',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF6B7280))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _PageText(
              title: widget.data.title,
              highlight: widget.data.highlight,
              description: widget.data.description,
              accentColor: widget.data.accentColor),
        ],
      ),
    );
  }
}

// ── Helper profile card ───────────────────────────────────────────────────────
class _HelperProfileCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 268,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.09),
              blurRadius: 24,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Stack(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [
                            Color(0xFF00C97A),
                            Color(0xFF059669)
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Center(
                      child: Text('P',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 22)),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3FED),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.check,
                          color: Colors.white, size: 10),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Priya Sharma',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827))),
                    const SizedBox(height: 2),
                    const Text('Electrician · 6 yrs exp',
                        style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280))),
                    const SizedBox(height: 5),
                    Row(children: [
                      ...List.generate(
                          5,
                              (i) => const Icon(Icons.star_rounded,
                              size: 13,
                              color: Color(0xFFF59E0B))),
                      const SizedBox(width: 4),
                      const Text('5.0',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937))),
                    ]),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 12),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(
                  value: '342',
                  label: 'Jobs',
                  color: const Color(0xFF7C3FED)),
              _StatItem(
                  value: '100%',
                  label: 'Safe',
                  color: const Color(0xFF00C97A)),
              _StatItem(
                  value: '4.9★',
                  label: 'Rating',
                  color: const Color(0xFFF59E0B)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatItem(
      {required this.value,
        required this.label,
        required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                fontSize: 10, color: Color(0xFF9CA3AF))),
      ],
    );
  }
}

// ── Trust badge ───────────────────────────────────────────────────────────────
class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;

  const _TrustBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78,
      padding:
      const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 6),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                  height: 1.3)),
        ],
      ),
    );
  }
}

// ─── Shared text block ────────────────────────────────────────────────────────
class _PageText extends StatelessWidget {
  final String title;
  final String highlight;
  final String description;
  final Color accentColor;

  const _PageText({
    required this.title,
    required this.highlight,
    required this.description,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1F2937),
              height: 1.25,
            ),
            children: [
              TextSpan(text: '$title\n'),
              TextSpan(
                  text: highlight,
                  style: TextStyle(color: accentColor)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          description,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color(0xFF6B7280),
              height: 1.55),
        ),
      ],
    );
  }
}

// ─── Animated dot indicator ───────────────────────────────────────────────────
class _Indicator extends StatelessWidget {
  final bool active;
  final Color color;
  const _Indicator({required this.active, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: active ? 28 : 7,
      height: 7,
      decoration: BoxDecoration(
        color: active ? color : const Color(0xFFD1D5DB),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// ─── CTA Button ───────────────────────────────────────────────────────────────
class _OnboardingButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OnboardingButton(
      {required this.label,
        required this.color,
        required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward,
                color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}