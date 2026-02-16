import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'auth/login_screen.dart';

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
      if (_selectedIndex != 0 || _showAuthDialog) {
        setState(() {
          _selectedIndex = 0;
          _showAuthDialog = false;
        });
      }
    } else if (index == 2) {
      // SOS button - navigate to login directly
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      setState(() {
        _selectedIndex = index;
        _showAuthDialog = true;
      });
    }
  }

  void _navigateToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _closeDialogAndNavigateToLogin() {
    setState(() {
      _showAuthDialog = false;
      _selectedIndex = 0;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    });
  }

  void _closeDialogAndNavigateToSignUp() {
    setState(() {
      _showAuthDialog = false;
      _selectedIndex = 0;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SignUpPage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F8),
      body: Stack(
        children: [
          // Main Content
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 20),
              physics: const ClampingScrollPhysics(),
              children: [
                // Header
                _buildHeader(),
                const SizedBox(height: 12),
                // Service Grid
                _buildServiceGrid(),
                const SizedBox(height: 20),
                // Get Help Now Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _GetHelpButton(onTap: _navigateToLogin),
                ),
                const SizedBox(height: 24),
                // Popular Near You Section
                _buildPopularSection(),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // Blur Overlay with Auth Dialog
          if (_showAuthDialog)
            GestureDetector(
              onTap: () {
                setState(() {
                  _showAuthDialog = false;
                  _selectedIndex = 0;
                });
              },
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                child: Container(
                  color: Colors.black.withOpacity(0.2),
                  child: Center(
                    child: _AuthDialog(
                      onLogin: _closeDialogAndNavigateToLogin,
                      onSignUp: _closeDialogAndNavigateToSignUp,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GUEST MODE',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF9CA3AF),
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome to',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                        height: 1.3,
                      ),
                    ),
                    const Text(
                      'Trouble Sarthi',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7C3FED),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              _LoginButton(onTap: _navigateToLogin),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Expert help, just a tap away.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'What do you need help with today?',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF1F2937),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: const [
          _ServiceRow(
            card1: _ServiceCardData(
              icon: Icons.home_outlined,
              iconColor: Color(0xFF6B28EA),
              iconBgColor: Color(0xFFDDD0F8),
              waveColor: Color(0xFFDDD0F8),
              title: 'Household',
              subtitle: 'Cleaning, repairs &\nmore',
            ),
            card2: _ServiceCardData(
              icon: Icons.factory_outlined,
              iconColor: Color(0xFFD14700),
              iconBgColor: Color(0xFFFFDAB8),
              waveColor: Color(0xFFFFDAB8),
              title: 'Industrial',
              subtitle: 'Heavy machinery\nsupport',
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
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Popular near you',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF1F2937),
              fontWeight: FontWeight.w600,
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
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF7C3FED),
        unselectedItemColor: const Color(0xFF9CA3AF),
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Icon(Icons.home_outlined, size: 26),
            ),
            activeIcon: Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Icon(Icons.home, size: 26),
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: _NotificationDot(
                child: Icon(Icons.calendar_today_outlined, size: 24),
              ),
            ),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: _SOSButton(),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: _NotificationDot(
                child: Icon(Icons.notifications_outlined, size: 26),
              ),
            ),
            label: 'Alerts',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: _NotificationDot(
                child: Icon(Icons.person_outline, size: 26),
              ),
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// Optimized Widgets

class _LoginButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LoginButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
          ),
          child: const Text(
            'Login',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF7C3FED),
            ),
          ),
        ),
      ),
    );
  }
}

class _GetHelpButton extends StatelessWidget {
  final VoidCallback onTap;
  const _GetHelpButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              colors: [Color(0xFF00D68F), Color(0xFF00C782)],
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text(
                'Get Help Now',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceCardData {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final Color waveColor;
  final String title;
  final String subtitle;

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
  final _ServiceCardData card1;
  final _ServiceCardData card2;

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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        },
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
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: data.waveColor.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 20,
                    right: -20,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: data.waveColor.withOpacity(0.35),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: data.iconBgColor,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(data.icon, color: data.iconColor, size: 26),
                        ),
                        const Spacer(),
                        Text(
                          data.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data.subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                            height: 1.4,
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
    );
  }
}

class _PopularServiceCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Available',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthDialog extends StatelessWidget {
  final VoidCallback onLogin;
  final VoidCallback onSignUp;
  const _AuthDialog({required this.onLogin, required this.onSignUp});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: Color(0xFFDDD0F8),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_outline, size: 40, color: Color(0xFF6B28EA)),
          ),
          const SizedBox(height: 24),
          const Text(
            'Login Required',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Please login or sign up to access this feature',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: onLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3FED),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              child: const Text(
                'Login',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: onSignUp,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF7C3FED),
                side: const BorderSide(color: Color(0xFF7C3FED), width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              child: const Text(
                'Sign Up',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationDot extends StatelessWidget {
  final Widget child;
  const _NotificationDot({required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        const Positioned(
          right: -2,
          top: -2,
          child: SizedBox(
            width: 8,
            height: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFFEF4444),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SOSButton extends StatelessWidget {
  const _SOSButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
        ),
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Text(
          'SOS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

// Placeholder SignUp Page
class SignUpPage extends StatelessWidget {
  const SignUpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: const Center(child: Text('Sign Up Page')),
    );
  }
}