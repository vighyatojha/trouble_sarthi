import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:trouble_sarthi/screens/guest_landing_page.dart';
import 'home_screen.dart';

// ── Smooth route helper used across the whole app ─────────────────────────────
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
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
    transitionDuration: Duration(milliseconds: ms),
  );
}

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
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );

    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack)),
    );

    _ctrl.forward();

    // Check auth state after 2s then navigate smoothly
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
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
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
            colors: [Color(0xFF5B6FED), Color(0xFF4A5FE8), Color(0xFF3B4FD8)],
          ),
        ),
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // ── Logo ─────────────────────────────────────────────────────
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
                      child: Icon(
                        Icons.verified_user,
                        size: 54,
                        color: Color(0xFF5B6FED),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── Title ─────────────────────────────────────────────────────
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
                  fontSize: 15,
                  color: Colors.white70,
                  height: 1.4,
                ),
              ),

              const Spacer(flex: 2),

              // ── Dots ──────────────────────────────────────────────────────
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
                  letterSpacing: 1,
                ),
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
      image: 'assets/images/helper1.jpg',
      title: 'Find Trusted',
      highlight: 'Local Helpers',
      description:
      'Connect with verified and skilled professionals in your neighborhood instantly. Safety and quality guaranteed.',
      bgColor: const Color(0xFFF5F5F8),
      accentColor: const Color(0xFF7C3FED),
      isCustom: false,
    ),
    _OnboardingData(
      image: 'assets/images/helper2.jpg',
      title: 'Quick',
      highlight: 'Service Booking',
      description:
      'Book services in just a few taps. Get instant confirmation and real-time updates on your service status.',
      bgColor: const Color(0xFFF5F5F8),
      accentColor: const Color(0xFF7C3FED),
      isCustom: false,
    ),
    _OnboardingData(
      image: '',
      title: 'Safe, Transparent,',
      highlight: 'Reliable',
      description:
      "Your peace of mind matters. Every 'Sarthi' helper is verified, and our pricing is always upfront—no hidden fees, ever.",
      bgColor: const Color(0xFFE8F5F0),
      accentColor: const Color(0xFF00D68F),
      isCustom: true,
    ),
  ];

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      _goToHome();
    }
  }

  void _goToHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const GuestLandingPage(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
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
              // ── Top row ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentPage > 0)
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF6B7280)),
                        onPressed: () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                        ),
                      )
                    else
                      const SizedBox(width: 48),
                    TextButton(
                      onPressed: _goToHome,
                      child: const Text(
                        'Skip',
                        style: TextStyle(color: Color(0xFF6B7280), fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Pages ──────────────────────────────────────────────────
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemCount: _pages.length,
                  itemBuilder: (_, i) => _pages[i].isCustom
                      ? _CustomPage(data: _pages[i])
                      : _ImagePage(data: _pages[i]),
                ),
              ),

              // ── Indicators ─────────────────────────────────────────────
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

              // ── CTA button ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: _OnboardingButton(
                  label: _currentPage < _pages.length - 1 ? 'Next' : 'Get Started',
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

// ─── Onboarding data model ────────────────────────────────────────────────────
class _OnboardingData {
  final String image;
  final String title;
  final String highlight;
  final String description;
  final Color bgColor;
  final Color accentColor;
  final bool isCustom;

  const _OnboardingData({
    required this.image,
    required this.title,
    required this.highlight,
    required this.description,
    required this.bgColor,
    required this.accentColor,
    required this.isCustom,
  });
}

// ─── Image page (pages 1 & 2) ─────────────────────────────────────────────────
class _ImagePage extends StatelessWidget {
  final _OnboardingData data;
  const _ImagePage({required this.data});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              height: size.height * 0.40,
              width: double.infinity,
              color: Colors.white,
              child: Image.asset(
                data.image,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.person, size: 80, color: Color(0xFF9CA3AF)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          _PageText(title: data.title, highlight: data.highlight, description: data.description, accentColor: data.accentColor),
        ],
      ),
    );
  }
}

// ─── Custom page (page 3) ─────────────────────────────────────────────────────
class _CustomPage extends StatelessWidget {
  final _OnboardingData data;
  const _CustomPage({required this.data});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Shield illustration
          RepaintBoundary(
            child: SizedBox(
              height: size.height * 0.36,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Soft halo
                  Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD0F5E8).withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                  // Shield
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD0F5E8),
                      borderRadius: BorderRadius.circular(48),
                    ),
                    child: Center(
                      child: CustomPaint(
                        size: const Size(100, 120),
                        painter: _ShieldPainter(),
                      ),
                    ),
                  ),
                  // Check badge
                  Positioned(
                    top: 28,
                    right: 36,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D68F),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00D68F).withOpacity(0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 26),
                    ),
                  ),
                  // Lock badge
                  Positioned(
                    bottom: 44,
                    left: 20,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.lock_rounded, color: Color(0xFFFFC107), size: 32),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _PageText(title: data.title, highlight: data.highlight, description: data.description, accentColor: data.accentColor),
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
              TextSpan(text: highlight, style: TextStyle(color: accentColor)),
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
            height: 1.55,
          ),
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

  const _OnboardingButton({required this.label, required this.color, required this.onTap});

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Shield painter ───────────────────────────────────────────────────────────
class _ShieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final fill = Paint()
      ..color = const Color(0xFF00D68F)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(w / 2, 0)
      ..lineTo(w * 0.9, h * 0.15)
      ..lineTo(w, h * 0.35)
      ..lineTo(w, h * 0.6)
      ..quadraticBezierTo(w * 0.85, h * 0.85, w / 2, h)
      ..quadraticBezierTo(w * 0.15, h * 0.85, 0, h * 0.6)
      ..lineTo(0, h * 0.35)
      ..lineTo(w * 0.1, h * 0.15)
      ..close();

    canvas.drawPath(path, fill);

    final check = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final checkPath = Path()
      ..moveTo(w * 0.25, h * 0.5)
      ..lineTo(w * 0.42, h * 0.68)
      ..lineTo(w * 0.75, h * 0.35);

    canvas.drawPath(checkPath, check);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}