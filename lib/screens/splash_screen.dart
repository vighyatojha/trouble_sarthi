import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:trouble_sarthi/screens/guest_landing_page.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();

    Timer(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF5B6FED),
              Color(0xFF4A5FE8),
            ],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // Shield Icon with Animation
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.verified_user,
                      size: 60,
                      color: Color(0xFF5B6FED),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Title
              Text(
                'Trouble Sarthi',
                style: GoogleFonts.poppins(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 16),

              // Subtitle
              Text(
                'Your Trusted Sarthi for Every\nNeed',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.white,
                  height: 1.5,
                  letterSpacing: 0.3,
                ),
              ),

              const Spacer(flex: 2),

              // Page Indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildIndicator(true),
                  const SizedBox(width: 8),
                  _buildIndicator(false),
                  const SizedBox(width: 8),
                  _buildIndicator(false),
                ],
              ),

              const SizedBox(height: 24),

              // Version
              Text(
                'V 2.0.1',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.7),
                  letterSpacing: 1,
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIndicator(bool isActive) {
    return Container(
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(isActive ? 1.0 : 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// Onboarding Screen
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      image: 'assets/images/helper1.jpg',
      title: 'Find Trusted',
      highlightedTitle: 'Local Helpers',
      description:
      'Connect with verified and skilled professionals in your neighborhood instantly. Safety and quality guaranteed.',
      backgroundColor: const Color(0xFFF5F5F8),
      isCustom: false,
    ),
    OnboardingPage(
      image: 'assets/images/helper2.jpg',
      title: 'Quick',
      highlightedTitle: 'Service Booking',
      description:
      'Book services in just a few taps. Get instant confirmation and real-time updates on your service status.',
      backgroundColor: const Color(0xFFF5F5F8),
      isCustom: false,
    ),
    OnboardingPage(
      image: '',
      title: 'Safe, Transparent,',
      highlightedTitle: 'Reliable',
      description:
      'Your peace of mind matters. Every \'Sarthi\' helper is verified, and our pricing is always upfront—no hidden fees, ever.',
      backgroundColor: const Color(0xFFE8F5F0),
      isCustom: true,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pages[_currentPage].backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation (Back and Skip)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button (show only if not on first page)
                  if (_currentPage > 0)
                    IconButton(
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        color: Color(0xFF6B7280),
                      ),
                    )
                  else
                    const SizedBox(width: 48),

                  // Skip Button
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                      );
                    },
                    child: Text(
                      'Skip',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF6B7280),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _pages[index].isCustom
                      ? _buildCustomPage(_pages[index])
                      : _buildPage(_pages[index]);
                },
              ),
            ),

            // Page Indicators
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                      (index) => _buildIndicator(index == _currentPage),
                ),
              ),
            ),

            // Next/Get Started Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () {
                    if (_currentPage < _pages.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const GuestLandingPage()),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentPage == 2
                        ? const Color(0xFF00D68F)
                        : const Color(0xFF7C3FED),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _currentPage < _pages.length - 1
                            ? 'Next'
                            : 'Get Started',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Regular page (for pages 1 and 2)
  Widget _buildPage(OnboardingPage page) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Image Container
            Container(
              height: MediaQuery.of(context).size.height * 0.45,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  page.image,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFF9CA3AF),
                      child: const Center(
                        child: Icon(
                          Icons.person,
                          size: 100,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 30),
            // Title
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1F2937),
                  height: 1.2,
                ),
                children: [
                  TextSpan(text: '${page.title}\n'),
                  TextSpan(
                    text: page.highlightedTitle,
                    style: const TextStyle(
                      color: Color(0xFF7C3FED),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Description
            Text(
              page.description,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: const Color(0xFF6B7280),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Custom page (for page 3) - FIXED OVERFLOW
  Widget _buildCustomPage(OnboardingPage page) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Shield Icon with floating badges
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background soft circle
                  Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD0F5E8).withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                  ),

                  // Main Container
                  Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD0F5E8),
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00D68F).withOpacity(0.1),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Center(
                      child: CustomPaint(
                        size: const Size(120, 140),
                        painter: ShieldPainter(),
                      ),
                    ),
                  ),

                  // Top Right - Check Circle
                  Positioned(
                    top: 35,
                    right: 35,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D68F),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00D68F).withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 30,
                        weight: 4,
                      ),
                    ),
                  ),

                  // Top Right Corner - Tilted Card Badge
                  Positioned(
                    top: 15,
                    right: 10,
                    child: Transform.rotate(
                      angle: 0.2,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: const Color(0xFFB8EFD9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Transform.rotate(
                          angle: -0.15,
                          child: const Icon(
                            Icons.credit_card_rounded,
                            color: Color(0xFF00D68F),
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Bottom Left - Lock Badge
                  Positioned(
                    bottom: 50,
                    left: 15,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: Color(0xFFFFC107),
                        size: 38,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Title - REMOVED UNDERLINE
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1F2937),
                  height: 1.3,
                ),
                children: [
                  TextSpan(text: '${page.title}\n'),
                  TextSpan(
                    text: page.highlightedTitle,
                    style: const TextStyle(
                      color: Color(0xFF00D68F),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                page.description,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: const Color(0xFF6B7280),
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 32 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive
            ? (_currentPage == 2 ? const Color(0xFF00D68F) : const Color(0xFF7C3FED))
            : const Color(0xFFD1D5DB),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// Custom Shield Painter - PERFECT SHIELD SHAPE WITH CHECKMARK
class ShieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00D68F)
      ..style = PaintingStyle.fill;

    final path = Path();

    // Create proper shield shape
    final width = size.width;
    final height = size.height;

    // Start from top center
    path.moveTo(width / 2, 0);

    // Top right curve
    path.lineTo(width * 0.9, height * 0.15);
    path.lineTo(width, height * 0.35);

    // Right side
    path.lineTo(width, height * 0.6);

    // Bottom right curve to bottom point
    path.quadraticBezierTo(
      width * 0.85, height * 0.85,
      width / 2, height,
    );

    // Bottom left curve from bottom point
    path.quadraticBezierTo(
      width * 0.15, height * 0.85,
      0, height * 0.6,
    );

    // Left side
    path.lineTo(0, height * 0.35);
    path.lineTo(width * 0.1, height * 0.15);

    // Close the path
    path.close();

    canvas.drawPath(path, paint);

    // Draw checkmark
    final checkPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final checkPath = Path();
    // Start point of check
    checkPath.moveTo(width * 0.25, height * 0.5);
    // Middle point (bottom of check)
    checkPath.lineTo(width * 0.42, height * 0.68);
    // End point (top right of check)
    checkPath.lineTo(width * 0.75, height * 0.35);

    canvas.drawPath(checkPath, checkPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Onboarding Page Model
class OnboardingPage {
  final String image;
  final String title;
  final String highlightedTitle;
  final String description;
  final Color backgroundColor;
  final bool isCustom;

  OnboardingPage({
    required this.image,
    required this.title,
    required this.highlightedTitle,
    required this.description,
    required this.backgroundColor,
    required this.isCustom,
  });
}