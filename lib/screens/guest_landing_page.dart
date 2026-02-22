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

class GuestLandingPage extends StatefulWidget {
  const GuestLandingPage({super.key});

  @override
  State<GuestLandingPage> createState() => _GuestLandingPageState();
}

class _GuestLandingPageState extends State<GuestLandingPage> {
  int _selectedIndex = 0;
  bool _showAuthDialog = false;

  void _onItemTapped(int index) {
    if (index == 0) {
      setState(() {
        _selectedIndex = 0;
        _showAuthDialog = false;
      });
    } else if (index == 2) {
      _navigateToLogin();
    } else {
      setState(() {
        _selectedIndex = index;
        _showAuthDialog = true;
      });
    }
  }

  void _navigateToLogin() {
    Navigator.push(context, _fadeSlideRoute(const LoginScreen()));
  }

  void _navigateToSignUp() {
    Navigator.push(context, _fadeSlideRoute(const SignUpScreen()));
  }

  void _closeAndLogin() {
    setState(() {
      _showAuthDialog = false;
      _selectedIndex = 0;
    });
    Future.delayed(const Duration(milliseconds: 80), _navigateToLogin);
  }

  void _closeAndSignUp() {
    setState(() {
      _showAuthDialog = false;
      _selectedIndex = 0;
    });
    Future.delayed(const Duration(milliseconds: 80), _navigateToSignUp);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F8),
      body: Stack(
        children: [
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 20),
              physics: const ClampingScrollPhysics(),
              children: [
                _buildHeader(),
                const SizedBox(height: 12),
                _buildServiceGrid(),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _GetHelpButton(onTap: _navigateToLogin),
                ),
                const SizedBox(height: 24),
                _buildPopularSection(),
                const SizedBox(height: 20),
              ],
            ),
          ),

          if (_showAuthDialog)
            GestureDetector(
              onTap: () => setState(() {
                _showAuthDialog = false;
                _selectedIndex = 0;
              }),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: Container(
                  color: Colors.black.withOpacity(0.18),
                  child: Center(
                    child: _AuthDialog(
                      onLogin: _closeAndLogin,
                      onSignUp: _closeAndSignUp,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: RepaintBoundary(child: _buildBottomNav()),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEEEBFF), Color(0xFFE8E3FF), Color(0xFFEFF0FF)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x147C3FED), blurRadius: 20, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3FED).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'GUEST MODE',
              style: TextStyle(
                fontSize: 10,
                color: Color(0xFF7C3FED),
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to',
                      style: GoogleFonts.nunito(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1F2937),
                        height: 1.2,
                      ),
                    ),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF7C3FED), Color(0xFF9D6FFF), Color(0xFF6B28EA)],
                      ).createShader(bounds),
                      child: const Text(
                        'Trouble Sarthi',
                        style: TextStyle(
                          fontFamily: 'Saman',
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _navigateToLogin,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Color(0x267C3FED), blurRadius: 10, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Text(
                    'Login',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF7C3FED),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0x197C3FED), height: 1),
          const SizedBox(height: 14),
          Text(
            'Expert help, just a tap away.',
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: const Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'What do you need help with today?',
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: const Color(0xFF1F2937),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceGrid() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _ServiceRow(
            card1: _ServiceCardData(
              icon: Icons.home_outlined,
              iconColor: Color(0xFF6B28EA),
              iconBgColor: Color(0xFFDDD0F8),
              waveColor: Color(0xFFDDD0F8),
              title: 'Household',
              subtitle: 'Cleaning, repairs & more',
            ),
            card2: _ServiceCardData(
              icon: Icons.factory_outlined,
              iconColor: Color(0xFFD14700),
              iconBgColor: Color(0xFFFFDAB8),
              waveColor: Color(0xFFFFDAB8),
              title: 'Industrial',
              subtitle: 'Heavy machinery support',
            ),
          ),
          SizedBox(height: 12),
          _ServiceRow(
            card1: _ServiceCardData(
              icon: Icons.directions_car_outlined,
              iconColor: Color(0xFF2563EB),
              iconBgColor: Color(0xFFBFDBFE),
              waveColor: Color(0xFFBFDBFE),
              title: 'Vehicle',
              subtitle: 'Roadside assistance',
            ),
            card2: _ServiceCardData(
              icon: Icons.bolt_outlined,
              iconColor: Color(0xFFF59E0B),
              iconBgColor: Color(0xFFFEF3C7),
              waveColor: Color(0xFFFEF3C7),
              title: 'Electrical',
              subtitle: 'Wiring & installation',
            ),
          ),
          SizedBox(height: 12),
          _ServiceRow(
            card1: _ServiceCardData(
              icon: Icons.plumbing_outlined,
              iconColor: Color(0xFF0891B2),
              iconBgColor: Color(0xFFA5F3FC),
              waveColor: Color(0xFFA5F3FC),
              title: 'Plumbing',
              subtitle: 'Leaks & pipe fitting',
            ),
            card2: _ServiceCardData(
              icon: Icons.build_outlined,
              iconColor: Color(0xFF059669),
              iconBgColor: Color(0xFFA7F3D0),
              waveColor: Color(0xFFA7F3D0),
              title: 'Carpenter',
              subtitle: 'Furniture & repair',
            ),
          ),
          SizedBox(height: 12),
          _ServiceRow(
            card1: _ServiceCardData(
              icon: Icons.mode_fan_off_outlined,
              iconColor: Color(0xFF7C3AED),
              iconBgColor: Color(0xFFDDD6FE),
              waveColor: Color(0xFFDDD6FE),
              title: 'AC/Cooler',
              subtitle: 'Installation & repair',
            ),
            card2: _ServiceCardData(
              icon: Icons.format_paint_outlined,
              iconColor: Color(0xFFDB2777),
              iconBgColor: Color(0xFFFBCFE8),
              waveColor: Color(0xFFFBCFE8),
              title: 'Painting',
              subtitle: 'Interior & exterior',
            ),
          ),
          SizedBox(height: 12),
          _ServiceRow(
            card1: _ServiceCardData(
              icon: Icons.pest_control_outlined,
              iconColor: Color(0xFF047857),
              iconBgColor: Color(0xFF6EE7B7),
              waveColor: Color(0xFF6EE7B7),
              title: 'Pest Control',
              subtitle: 'Safe & effective',
            ),
            card2: _ServiceCardData(
              icon: Icons.more_horiz,
              iconColor: Color(0xFF4B5563),
              iconBgColor: Color(0xFFE5E7EB),
              waveColor: Color(0xFFE5E7EB),
              title: 'Others',
              subtitle: 'View all services',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Popular near you',
            style: GoogleFonts.nunito(
              fontSize: 17,
              color: const Color(0xFF1F2937),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _PopularServiceCard(
            icon: Icons.directions_car,
            iconColor: const Color(0xFF2563EB),
            iconBgColor: const Color(0xFFBFDBFE),
            title: 'Vehicle 24×7 Service',
            subtitle: 'Emergency roadside assistance anytime',
            onTap: _navigateToLogin,
          ),
          const SizedBox(height: 12),
          _PopularServiceCard(
            icon: Icons.plumbing,
            iconColor: const Color(0xFF0891B2),
            iconBgColor: const Color(0xFFA5F3FC),
            title: 'Plumbing Service',
            subtitle: 'Expert plumbers for all your needs',
            onTap: _navigateToLogin,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Home',
                selected: _selectedIndex == 0,
                onTap: () => _onItemTapped(0),
              ),
              _NavItem(
                icon: Icons.calendar_today_outlined,
                activeIcon: Icons.calendar_today,
                label: 'Bookings',
                selected: _selectedIndex == 1,
                showDot: true,
                onTap: () => _onItemTapped(1),
              ),
              // SOS
              Expanded(
                child: GestureDetector(
                  onTap: () => _onItemTapped(2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)]),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text(
                            'SOS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _NavItem(
                icon: Icons.notifications_outlined,
                activeIcon: Icons.notifications,
                label: 'Alerts',
                selected: _selectedIndex == 3,
                showDot: true,
                onTap: () => _onItemTapped(3),
              ),
              _NavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profile',
                selected: _selectedIndex == 4,
                showDot: true,
                onTap: () => _onItemTapped(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Nav Item ─────────────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final bool selected, showDot;
  final VoidCallback onTap;

  const _NavItem({
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
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(selected ? activeIcon : icon, size: 22, color: color),
                if (showDot && !selected)
                  const Positioned(
                    right: -2,
                    top: -2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                      child: SizedBox(width: 7, height: 7),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
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
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(colors: [Color(0xFF00D68F), Color(0xFF00C782)]),
          boxShadow: const [
            BoxShadow(color: Color(0x4D00D68F), blurRadius: 12, offset: Offset(0, 6)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
              'Get Help Now',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Service card data ────────────────────────────────────────────────────────
class _ServiceCardData {
  final IconData icon;
  final Color iconColor, iconBgColor, waveColor;
  final String title, subtitle;

  const _ServiceCardData({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.waveColor,
    required this.title,
    required this.subtitle,
  });
}

class _ServiceRow extends StatelessWidget {
  final _ServiceCardData card1, card2;
  const _ServiceRow({required this.card1, required this.card2});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _ServiceCard(data: card1)),
        const SizedBox(width: 12),
        Expanded(child: _ServiceCard(data: card2)),
      ],
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final _ServiceCardData data;
  const _ServiceCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const LoginScreen(),
              transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
              transitionDuration: const Duration(milliseconds: 220),
            ),
          ),
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    Positioned(
                      top: -40,
                      right: -40,
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: data.waveColor.withOpacity(0.45),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 20,
                      right: -16,
                      child: Container(
                        width: 75,
                        height: 75,
                        decoration: BoxDecoration(
                          color: data.waveColor.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: data.iconBgColor,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(data.icon, color: data.iconColor, size: 24),
                          ),
                          const Spacer(),
                          Text(
                            data.title,
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            data.subtitle,
                            style: GoogleFonts.nunito(
                              fontSize: 10,
                              color: const Color(0xFF9CA3AF),
                              height: 1.3,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PopularServiceCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor, iconBgColor;
  final String title, subtitle;
  final VoidCallback onTap;

  const _PopularServiceCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: const Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Available',
                  style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x1A000000), blurRadius: 30, offset: Offset(0, 15)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(color: Color(0xFFDDD0F8), shape: BoxShape.circle),
            child: const Icon(Icons.lock_outline, size: 36, color: Color(0xFF6B28EA)),
          ),
          const SizedBox(height: 20),
          Text(
            'Login Required',
            style: GoogleFonts.nunito(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Please login or sign up to access this feature',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: const Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: onLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3FED),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: Text(
                'Login',
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: onSignUp,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF7C3FED),
                side: const BorderSide(color: Color(0xFF7C3FED), width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: Text(
                'Sign Up',
                style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}