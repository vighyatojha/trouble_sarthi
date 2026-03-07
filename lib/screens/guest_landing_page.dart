import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'auth/login_screen.dart';
import 'auth/signup_screen.dart';

// ─── Smooth transition helper ─────────────────────────────────────────────────
PageRoute<T> _fadeSlideRoute<T>(Widget page) {
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
    transitionDuration: const Duration(milliseconds: 260),
  );
}

class GuestLandingPage extends StatefulWidget {
  const GuestLandingPage({super.key});

  @override
  State<GuestLandingPage> createState() => _GuestLandingPageState();
}

class _GuestLandingPageState extends State<GuestLandingPage>
    with SingleTickerProviderStateMixin {
  int _selectedIndex   = 0;
  bool _showAuthDialog = false;

  // ── All navigation logic unchanged ─────────────────────────────────────────
  void _onItemTapped(int index) {
    if (index == 0) {
      setState(() { _selectedIndex = 0; _showAuthDialog = false; });
    } else if (index == 2) {
      _navigateToLogin();
    } else {
      setState(() { _selectedIndex = index; _showAuthDialog = true; });
    }
  }

  void _navigateToLogin()  => Navigator.push(context, _fadeSlideRoute(const LoginScreen()));
  void _navigateToSignUp() => Navigator.push(context, _fadeSlideRoute(const SignUpScreen()));

  void _closeAndLogin() {
    setState(() { _showAuthDialog = false; _selectedIndex = 0; });
    Future.delayed(const Duration(milliseconds: 80), _navigateToLogin);
  }

  void _closeAndSignUp() {
    setState(() { _showAuthDialog = false; _selectedIndex = 0; });
    Future.delayed(const Duration(milliseconds: 80), _navigateToSignUp);
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F8),
      body: Stack(
        children: [
          CustomScrollView(
            physics: const ClampingScrollPhysics(),
            slivers: [
              // ── Hero header as SliverToBoxAdapter ──────────────────────
              SliverToBoxAdapter(child: _HeroHeader(onLogin: _navigateToLogin)),

              // ── Quick stats strip ───────────────────────────────────────
              const SliverToBoxAdapter(child: _QuickStatsStrip()),

              // ── Section label ───────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Our Services',
                          style: GoogleFonts.nunito(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF111827))),
                      Text('View all',
                          style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF7C3FED))),
                    ],
                  ),
                ),
              ),

              // ── Service grid ─────────────────────────────────────────────
              const SliverToBoxAdapter(child: _ServiceGrid()),

              // ── Get Help CTA ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: _GetHelpButton(onTap: _navigateToLogin),
                ),
              ),

              // ── Emergency banner ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _EmergencyBanner(onTap: _navigateToLogin),
                ),
              ),

              // ── Popular section ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
                  child: Text('Popular near you',
                      style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF111827))),
                ),
              ),

              SliverToBoxAdapter(
                child: _PopularSection(onTap: _navigateToLogin),
              ),

              // ── Trust footer ─────────────────────────────────────────────
              const SliverToBoxAdapter(child: _TrustFooter()),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),

          // ── Floating nav bar ─────────────────────────────────────────────
          Positioned(
            left:   16,
            right:  16,
            bottom: 20,
            child: SafeArea(
              top: false,
              child: _FloatingNav(
                selectedIndex: _selectedIndex,
                onTap:         _onItemTapped,
              ),
            ),
          ),

          // ── Auth dialog overlay ───────────────────────────────────────────
          if (_showAuthDialog)
            GestureDetector(
              onTap: () => setState(
                      () { _showAuthDialog = false; _selectedIndex = 0; }),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(
                  color: Colors.black.withOpacity(0.22),
                  child: Center(
                    child: _AuthDialog(
                        onLogin: _closeAndLogin,
                        onSignUp: _closeAndSignUp),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  HERO HEADER
// ═══════════════════════════════════════════════════════════════════════════
class _HeroHeader extends StatelessWidget {
  final VoidCallback onLogin;
  const _HeroHeader({required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A0533), Color(0xFF2D1060), Color(0xFF4C1D95)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // ── Decorative circles ──────────────────────────────────────
            Positioned(
              top: -30, right: -50,
              child: Container(
                width: 200, height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.04),
                ),
              ),
            ),
            Positioned(
              top: 40, right: 30,
              child: Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF7C3FED).withOpacity(0.25),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Brand
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.15)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6, height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF4ADE80),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text('GUEST MODE',
                                    style: GoogleFonts.nunito(
                                        fontSize: 10,
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.1)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          ShaderMask(
                            shaderCallback: (b) => const LinearGradient(
                              colors: [
                                Color(0xFFE0D0FF),
                                Color(0xFFFFFFFF),
                              ],
                            ).createShader(b),
                            child: const Text(
                              'Trouble Sarthi',
                              style: TextStyle(
                                fontFamily: 'Saman',
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Login button
                      GestureDetector(
                        onTap: onLogin,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 11),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF7C3FED), Color(0xFF9D6FFF)],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                  color: const Color(0xFF7C3FED)
                                      .withOpacity(0.45),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6))
                            ],
                          ),
                          child: Text('Login',
                              style: GoogleFonts.nunito(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Headline
                  Text('What can we\nfix for you today?',
                      style: GoogleFonts.nunito(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.2)),

                  const SizedBox(height: 6),
                  Text('Expert help, just a tap away.',
                      style: GoogleFonts.nunito(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.55),
                          fontWeight: FontWeight.w500)),

                  const SizedBox(height: 20),

                  // Fake search bar
                  GestureDetector(
                    onTap: onLogin,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.15)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded,
                              color: Colors.white.withOpacity(0.5),
                              size: 20),
                          const SizedBox(width: 10),
                          Text('Search for a service...',
                              style: GoogleFonts.nunito(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.4),
                                  fontWeight: FontWeight.w500)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.location_on_rounded,
                                    color: Colors.white.withOpacity(0.7),
                                    size: 12),
                                const SizedBox(width: 3),
                                Text('Surat',
                                    style: GoogleFonts.nunito(
                                        fontSize: 11,
                                        color: Colors.white.withOpacity(0.7),
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ],
                      ),
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

// ═══════════════════════════════════════════════════════════════════════════
//  QUICK STATS STRIP
// ═══════════════════════════════════════════════════════════════════════════
class _QuickStatsStrip extends StatelessWidget {
  const _QuickStatsStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF4C1D95),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF2F3F8),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Row(
          children: [
            _StatPill(
              icon: Icons.verified_rounded,
              value: '500+',
              label: 'Verified Helpers',
              color: const Color(0xFF7C3FED),
            ),
            const SizedBox(width: 10),
            _StatPill(
              icon: Icons.star_rounded,
              value: '4.9★',
              label: 'Avg Rating',
              color: const Color(0xFFF59E0B),
            ),
            const SizedBox(width: 10),
            _StatPill(
              icon: Icons.bolt_rounded,
              value: '30 min',
              label: 'Avg Response',
              color: const Color(0xFF059669),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color color;
  const _StatPill(
      {required this.icon,
        required this.value,
        required this.label,
        required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(value,
                style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF111827))),
            Text(label,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                    fontSize: 9,
                    color: const Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w600,
                    height: 1.2)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SERVICE GRID
// ═══════════════════════════════════════════════════════════════════════════
class _ServiceGrid extends StatelessWidget {
  const _ServiceGrid();

  static const List<_ServiceCardData> _services = [
    _ServiceCardData(
      icon: Icons.home_outlined,
      iconColor: Color(0xFF6B28EA),
      iconBgColor: Color(0xFFEDE9FE),
      accentColor: Color(0xFF7C3FED),
      title: 'Household',
      subtitle: 'Cleaning & repairs',
    ),
    _ServiceCardData(
      icon: Icons.factory_outlined,
      iconColor: Color(0xFFD14700),
      iconBgColor: Color(0xFFFFEDD5),
      accentColor: Color(0xFFEA580C),
      title: 'Industrial',
      subtitle: 'Machinery support',
    ),
    _ServiceCardData(
      icon: Icons.directions_car_outlined,
      iconColor: Color(0xFF2563EB),
      iconBgColor: Color(0xFFDBEAFE),
      accentColor: Color(0xFF2563EB),
      title: 'Vehicle',
      subtitle: 'Roadside help',
    ),
    _ServiceCardData(
      icon: Icons.bolt_outlined,
      iconColor: Color(0xFFD97706),
      iconBgColor: Color(0xFFFEF3C7),
      accentColor: Color(0xFFF59E0B),
      title: 'Electrical',
      subtitle: 'Wiring & setup',
    ),
    _ServiceCardData(
      icon: Icons.plumbing_outlined,
      iconColor: Color(0xFF0891B2),
      iconBgColor: Color(0xFFCFFAFE),
      accentColor: Color(0xFF0891B2),
      title: 'Plumbing',
      subtitle: 'Leaks & pipes',
    ),
    _ServiceCardData(
      icon: Icons.carpenter_rounded,
      iconColor: Color(0xFF059669),
      iconBgColor: Color(0xFFD1FAE5),
      accentColor: Color(0xFF059669),
      title: 'Carpenter',
      subtitle: 'Furniture & fix',
    ),
    _ServiceCardData(
      icon: Icons.mode_fan_off_outlined,
      iconColor: Color(0xFF7C3AED),
      iconBgColor: Color(0xFFEDE9FE),
      accentColor: Color(0xFF7C3AED),
      title: 'AC/Cooler',
      subtitle: 'Install & repair',
    ),
    _ServiceCardData(
      icon: Icons.format_paint_outlined,
      iconColor: Color(0xFFDB2777),
      iconBgColor: Color(0xFFFCE7F3),
      accentColor: Color(0xFFDB2777),
      title: 'Painting',
      subtitle: 'Interior & exterior',
    ),
    _ServiceCardData(
      icon: Icons.pest_control_outlined,
      iconColor: Color(0xFF047857),
      iconBgColor: Color(0xFFD1FAE5),
      accentColor: Color(0xFF047857),
      title: 'Pest Control',
      subtitle: 'Safe & effective',
    ),
    _ServiceCardData(
      icon: Icons.more_horiz,
      iconColor: Color(0xFF4B5563),
      iconBgColor: Color(0xFFF3F4F6),
      accentColor: Color(0xFF6B7280),
      title: 'Others',
      subtitle: 'View all services',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:   2,
          childAspectRatio: 1.0,
          crossAxisSpacing: 14,
          mainAxisSpacing:  14,
        ),
        itemCount: _services.length,
        itemBuilder: (_, i) => _ServiceCard(data: _services[i]),
      ),
    );
  }
}

class _ServiceCardData {
  final IconData icon;
  final Color iconColor, iconBgColor, accentColor;
  final String title, subtitle;

  const _ServiceCardData({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.accentColor,
    required this.title,
    required this.subtitle,
  });
}

class _ServiceCard extends StatefulWidget {
  final _ServiceCardData data;
  const _ServiceCard({required this.data});

  @override
  State<_ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<_ServiceCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) {
        setState(() => _pressed = false);
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const LoginScreen(),
            transitionsBuilder: (_, a, __, child) =>
                FadeTransition(opacity: a, child: child),
            transitionDuration: const Duration(milliseconds: 220),
          ),
        );
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale:    _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                  color:      widget.data.accentColor.withOpacity(0.08),
                  blurRadius: 16,
                  offset:     const Offset(0, 4))
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                // Decorative top-right blob
                Positioned(
                  top: -28, right: -28,
                  child: Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.data.iconBgColor.withOpacity(0.6),
                    ),
                  ),
                ),
                Positioned(
                  top: 8, right: -10,
                  child: Container(
                    width: 55, height: 55,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.data.iconBgColor.withOpacity(0.35),
                    ),
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon box
                      Container(
                        width:  50, height: 50,
                        decoration: BoxDecoration(
                          color:        widget.data.iconBgColor,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(widget.data.icon,
                            color: widget.data.iconColor, size: 24),
                      ),

                      const Spacer(),

                      Text(widget.data.title,
                          style: GoogleFonts.nunito(
                              fontSize:   15,
                              fontWeight: FontWeight.w900,
                              color:      const Color(0xFF111827))),
                      const SizedBox(height: 2),
                      Text(widget.data.subtitle,
                          style: GoogleFonts.nunito(
                              fontSize:   10,
                              color:      const Color(0xFF9CA3AF),
                              fontWeight: FontWeight.w600,
                              height:     1.3),
                          maxLines:  2,
                          overflow:  TextOverflow.ellipsis),

                      const SizedBox(height: 10),

                      // Bottom accent bar
                      Container(
                        height:       3,
                        width:        32,
                        decoration:   BoxDecoration(
                          color:        widget.data.accentColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  GET HELP BUTTON
// ═══════════════════════════════════════════════════════════════════════════
class _GetHelpButton extends StatelessWidget {
  final VoidCallback onTap;
  const _GetHelpButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF7C3FED), Color(0xFF9D6FFF)],
              begin: Alignment.centerLeft,
              end:   Alignment.centerRight),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color:      const Color(0xFF7C3FED).withOpacity(0.38),
                blurRadius: 18,
                offset:     const Offset(0, 7))
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.flash_on_rounded,
                color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text('Get Help Now',
                style: GoogleFonts.nunito(
                    fontSize:   17,
                    fontWeight: FontWeight.w800,
                    color:      Colors.white)),
            const SizedBox(width: 10),
            Container(
              padding:    const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color:  Colors.white.withOpacity(0.2),
                shape:  BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_rounded,
                  color: Colors.white, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  EMERGENCY BANNER
// ═══════════════════════════════════════════════════════════════════════════
class _EmergencyBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _EmergencyBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7F1D1D), Color(0xFFDC2626)],
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color:      const Color(0xFFDC2626).withOpacity(0.3),
                blurRadius: 16,
                offset:     const Offset(0, 6))
          ],
        ),
        child: Row(
          children: [
            Container(
              width:  48, height: 48,
              decoration: BoxDecoration(
                color:  Colors.white.withOpacity(0.15),
                shape:  BoxShape.circle,
              ),
              child: const Center(
                child: Text('SOS',
                    style: TextStyle(
                        color:       Colors.white,
                        fontSize:    13,
                        fontWeight:  FontWeight.w900,
                        letterSpacing: 0.5)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('24×7 Emergency Help',
                      style: GoogleFonts.nunito(
                          fontSize:   15,
                          fontWeight: FontWeight.w900,
                          color:      Colors.white)),
                  Text('Tap to call for immediate assistance',
                      style: GoogleFonts.nunito(
                          fontSize: 11,
                          color:    Colors.white.withOpacity(0.75),
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Colors.white, size: 22),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  POPULAR SECTION
// ═══════════════════════════════════════════════════════════════════════════
class _PopularSection extends StatelessWidget {
  final VoidCallback onTap;
  const _PopularSection({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _PopularCard(
            icon:        Icons.directions_car_rounded,
            iconColor:   const Color(0xFF2563EB),
            iconBgColor: const Color(0xFFDBEAFE),
            title:       'Vehicle 24×7 Service',
            subtitle:    'Emergency roadside assistance anytime',
            tag:         'Most Booked',
            tagColor:    const Color(0xFF7C3FED),
            rating:      '4.9',
            jobs:        '1.2k+',
            onTap:       onTap,
          ),
          const SizedBox(height: 12),
          _PopularCard(
            icon:        Icons.plumbing_rounded,
            iconColor:   const Color(0xFF0891B2),
            iconBgColor: const Color(0xFFCFFAFE),
            title:       'Plumbing Service',
            subtitle:    'Expert plumbers for all your needs',
            tag:         'Quick Hire',
            tagColor:    const Color(0xFF059669),
            rating:      '4.8',
            jobs:        '900+',
            onTap:       onTap,
          ),
          const SizedBox(height: 12),
          _PopularCard(
            icon:        Icons.bolt_rounded,
            iconColor:   const Color(0xFFD97706),
            iconBgColor: const Color(0xFFFEF3C7),
            title:       'Electrical Repair',
            subtitle:    'Safe, certified electrical work',
            tag:         'Top Rated',
            tagColor:    const Color(0xFFD97706),
            rating:      '5.0',
            jobs:        '650+',
            onTap:       onTap,
          ),
        ],
      ),
    );
  }
}

class _PopularCard extends StatelessWidget {
  final IconData icon;
  final Color    iconColor, iconBgColor, tagColor;
  final String   title, subtitle, tag, rating, jobs;
  final VoidCallback onTap;

  const _PopularCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.tagColor,
    required this.rating,
    required this.jobs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color:      Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset:     const Offset(0, 3))
          ],
        ),
        child: Row(
          children: [
            Container(
              width:  58, height: 58,
              decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title,
                            style: GoogleFonts.nunito(
                                fontSize:   14,
                                fontWeight: FontWeight.w900,
                                color:      const Color(0xFF111827))),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color:        tagColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(tag,
                            style: GoogleFonts.nunito(
                                fontSize:   10,
                                fontWeight: FontWeight.w700,
                                color:      tagColor)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: GoogleFonts.nunito(
                          fontSize: 12,
                          color:    const Color(0xFF6B7280),
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          color: Color(0xFFF59E0B), size: 14),
                      const SizedBox(width: 3),
                      Text(rating,
                          style: GoogleFonts.nunito(
                              fontSize:   12,
                              fontWeight: FontWeight.w700,
                              color:      const Color(0xFF1F2937))),
                      const SizedBox(width: 8),
                      Text('·',
                          style: TextStyle(
                              color: Colors.grey[400], fontSize: 12)),
                      const SizedBox(width: 8),
                      Text('$jobs jobs',
                          style: GoogleFonts.nunito(
                              fontSize: 11,
                              color:    const Color(0xFF9CA3AF),
                              fontWeight: FontWeight.w600)),
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

// ═══════════════════════════════════════════════════════════════════════════
//  TRUST FOOTER
// ═══════════════════════════════════════════════════════════════════════════
class _TrustFooter extends StatelessWidget {
  const _TrustFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF5F3FF), Color(0xFFEDE9FE)],
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF7C3FED).withOpacity(0.12)),
      ),
      child: Column(
        children: [
          Text('Why Trouble Sarthi?',
              style: GoogleFonts.nunito(
                  fontSize:   15,
                  fontWeight: FontWeight.w900,
                  color:      const Color(0xFF1F2937))),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _TrustItem(
                  icon: Icons.verified_user_rounded,
                  label: 'Verified\nHelpers',
                  color: const Color(0xFF7C3FED)),
              _TrustItem(
                  icon: Icons.lock_rounded,
                  label: 'Escrow\nPayment',
                  color: const Color(0xFF059669)),
              _TrustItem(
                  icon: Icons.support_agent_rounded,
                  label: '24×7\nSupport',
                  color: const Color(0xFF0891B2)),
              _TrustItem(
                  icon: Icons.price_check_rounded,
                  label: 'Fixed\nPricing',
                  color: const Color(0xFFD97706)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrustItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _TrustItem(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width:  42, height: 42,
          decoration: BoxDecoration(
            color:  color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Text(label,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
                fontSize:   10,
                fontWeight: FontWeight.w700,
                color:      const Color(0xFF374151),
                height:     1.3)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  FLOATING NAV BAR  ← curved pill, floats 20px above bottom edge
// ═══════════════════════════════════════════════════════════════════════════
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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withOpacity(0.10),
              blurRadius: 24,
              spreadRadius: 0,
              offset:     const Offset(0, 6),
            ),
            BoxShadow(
              color:      const Color(0xFF7C3FED).withOpacity(0.08),
              blurRadius: 16,
              offset:     const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            _FloatNavItem(
              icon:       Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label:      'Home',
              selected:   selectedIndex == 0,
              onTap:      () => onTap(0),
            ),
            _FloatNavItem(
              icon:       Icons.calendar_today_outlined,
              activeIcon: Icons.calendar_today_rounded,
              label:      'Bookings',
              selected:   selectedIndex == 1,
              showDot:    true,
              onTap:      () => onTap(1),
            ),

            // ── SOS centre button — lifted above bar ──────────────────
            Expanded(
              child: GestureDetector(
                onTap: () => onTap(2),
                child: Center(
                  child: Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF4444), Color(0xFFDC2626)],
                        begin:  Alignment.topLeft,
                        end:    Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color:      const Color(0xFFDC2626).withOpacity(0.55),
                          blurRadius: 18,
                          spreadRadius: 1,
                          offset:     const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text('SOS',
                          style: TextStyle(
                              color:         Colors.white,
                              fontSize:      13,
                              fontWeight:    FontWeight.w900,
                              letterSpacing: 0.8)),
                    ),
                  ),
                ),
              ),
            ),

            _FloatNavItem(
              icon:       Icons.notifications_outlined,
              activeIcon: Icons.notifications_rounded,
              label:      'Alerts',
              selected:   selectedIndex == 3,
              showDot:    true,
              onTap:      () => onTap(3),
            ),
            _FloatNavItem(
              icon:       Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label:      'Profile',
              selected:   selectedIndex == 4,
              showDot:    true,
              onTap:      () => onTap(4),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatNavItem extends StatelessWidget {
  final IconData     icon, activeIcon;
  final String       label;
  final bool         selected, showDot;
  final VoidCallback onTap;

  const _FloatNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF7C3FED) : const Color(0xFF9CA3AF);
    return Expanded(
      child: GestureDetector(
        onTap:    onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Active glow pill behind icon
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve:    Curves.easeOutCubic,
              width:    selected ? 40 : 0,
              height:   selected ? 32 : 0,
              decoration: BoxDecoration(
                color:        selected
                    ? const Color(0xFF7C3FED).withOpacity(0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: selected
                  ? Icon(activeIcon, size: 20, color: const Color(0xFF7C3FED))
                  : const SizedBox.shrink(),
            ),
            if (!selected) ...[
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 20, color: color),
                  if (showDot)
                    Positioned(
                      right: -2, top: -2,
                      child: Container(
                        width: 6, height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: GoogleFonts.nunito(
                fontSize:   9,
                color:      color,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  AUTH DIALOG
// ═══════════════════════════════════════════════════════════════════════════
class _AuthDialog extends StatelessWidget {
  final VoidCallback onLogin, onSignUp;
  const _AuthDialog({required this.onLogin, required this.onSignUp});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
              color:      Color(0x28000000),
              blurRadius: 40,
              offset:     Offset(0, 20)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top purple banner
          Container(
            width:  double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2D1060), Color(0xFF7C3FED)],
                begin:  Alignment.topLeft,
                end:    Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft:  Radius.circular(28),
                topRight: Radius.circular(28),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width:  68, height: 68,
                  decoration: BoxDecoration(
                    color:  Colors.white.withOpacity(0.15),
                    shape:  BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_rounded,
                      color: Colors.white, size: 30),
                ),
                const SizedBox(height: 12),
                Text('Login Required',
                    style: GoogleFonts.nunito(
                        fontSize:   20,
                        fontWeight: FontWeight.w900,
                        color:      Colors.white)),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                    'Sign in or create an account to\naccess this feature and more.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                        fontSize: 13,
                        color:    const Color(0xFF6B7280),
                        height:   1.6,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 22),

                // Login button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: onLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3FED),
                      elevation:   0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text('Login',
                        style: GoogleFonts.nunito(
                            fontSize:   15,
                            fontWeight: FontWeight.w800,
                            color:      Colors.white)),
                  ),
                ),
                const SizedBox(height: 10),

                // Sign up button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: onSignUp,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF7C3FED),
                      side: const BorderSide(
                          color: Color(0xFF7C3FED), width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text('Create Account',
                        style: GoogleFonts.nunito(
                            fontSize:   15,
                            fontWeight: FontWeight.w800,
                            color:      const Color(0xFF7C3FED))),
                  ),
                ),

                const SizedBox(height: 14),
                Text('Continue browsing as guest',
                    style: GoogleFonts.nunito(
                        fontSize:   12,
                        color:      const Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}