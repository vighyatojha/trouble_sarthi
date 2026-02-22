import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'email_login_screen.dart';
import 'signup_screen.dart';
import 'otp_verification_screen.dart';
import 'complete_profile_screen.dart';
import 'package:trouble_sarthi/screens/home_screen.dart';
import 'package:trouble_sarthi/service/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  String _selectedCountryCode = '+91';
  String? _phoneError;
  bool _googleLoading = false;
  bool _facebookLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _navigateTo(Widget screen) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => screen,
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero).animate(curved),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 280),
      ),
    );
  }

  void _sendOTP() {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _phoneError = 'Please enter your phone number');
      return;
    }
    if (phone.length < 10) {
      setState(() => _phoneError = 'Enter a valid 10-digit phone number');
      return;
    }
    setState(() => _phoneError = null);
    final fullPhone = '$_selectedCountryCode$phone';
    _navigateTo(OtpVerificationScreen(phoneNumber: fullPhone, isSignUp: false));
  }

  void _handleAuthResult(AuthResult result) {
    if (!mounted) return;
    if (result.cancelled) return;

    if (result.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.error!),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
      return;
    }

    if (result.isSuccess) {
      if (result.isNewUser || !result.profileComplete) {
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (_, a, __) => const CompleteProfileScreen(),
            transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
            transitionDuration: const Duration(milliseconds: 350),
          ),
              (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (_, a, __) => const HomeScreen(),
            transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
            transitionDuration: const Duration(milliseconds: 350),
          ),
              (route) => false,
        );
      }
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _googleLoading = true);
    final result = await AuthService.instance.signInWithGoogle();
    if (mounted) setState(() => _googleLoading = false);
    _handleAuthResult(result);
  }

  Future<void> _facebookSignIn() async {
    setState(() => _facebookLoading = true);
    final result = await AuthService.instance.signInWithFacebook();
    if (mounted) setState(() => _facebookLoading = false);
    _handleAuthResult(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F5),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Color(0xFF4F46E5)),
                      onPressed: () => Navigator.pop(context),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                    const Expanded(child: Center(child: _AppBarTitle())),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: _LoginCard(
                    phoneController: _phoneController,
                    selectedCountryCode: _selectedCountryCode,
                    phoneError: _phoneError,
                    googleLoading: _googleLoading,
                    facebookLoading: _facebookLoading,
                    onCountryChanged: (v) => setState(() => _selectedCountryCode = v),
                    onPhoneChanged: (_) => setState(() => _phoneError = null),
                    onSendOTP: _sendOTP,
                    onEmailLogin: () => _navigateTo(const EmailLoginScreen()),
                    onGoogleLogin: _googleSignIn,
                    onFacebookLogin: _facebookSignIn,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? ",
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 15)),
                  GestureDetector(
                    onTap: () => Navigator.pushReplacement(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => const SignUpScreen(),
                        transitionsBuilder: (_, animation, __, child) =>
                            FadeTransition(opacity: animation, child: child),
                        transitionDuration: const Duration(milliseconds: 200),
                      ),
                    ),
                    child: const Text('Sign up',
                        style: TextStyle(
                            color: Color(0xFF4F46E5), fontSize: 15, fontWeight: FontWeight.bold)),
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

// ─── Login Card ───────────────────────────────────────────────────────────────
class _LoginCard extends StatelessWidget {
  final TextEditingController phoneController;
  final String selectedCountryCode;
  final String? phoneError;
  final bool googleLoading, facebookLoading;
  final ValueChanged<String> onCountryChanged;
  final ValueChanged<String> onPhoneChanged;
  final VoidCallback onSendOTP, onEmailLogin, onGoogleLogin, onFacebookLogin;

  const _LoginCard({
    required this.phoneController,
    required this.selectedCountryCode,
    required this.phoneError,
    required this.googleLoading,
    required this.facebookLoading,
    required this.onCountryChanged,
    required this.onPhoneChanged,
    required this.onSendOTP,
    required this.onEmailLogin,
    required this.onGoogleLogin,
    required this.onFacebookLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFF8F7FF), Color(0xFFF3F1FF)],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(color: Color(0x144F46E5), blurRadius: 30, offset: Offset(0, 10)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 6),
            const _LogoBanner(),
            const SizedBox(height: 22),
            const Text('Welcome Back!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
            const SizedBox(height: 6),
            const Text('Enter your phone number to login',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            const SizedBox(height: 22),
            _PhoneField(
              controller: phoneController,
              selectedCountryCode: selectedCountryCode,
              error: phoneError,
              onCountryChanged: onCountryChanged,
              onChanged: onPhoneChanged,
            ),
            const SizedBox(height: 18),
            _PrimaryButton(label: 'Send OTP', icon: Icons.arrow_forward, onTap: onSendOTP),
            const SizedBox(height: 22),
            const _Divider(label: 'Or continue with'),
            const SizedBox(height: 14),
            _EmailButton(onTap: onEmailLogin),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _GoogleButton(loading: googleLoading, onTap: onGoogleLogin),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _FacebookButton(loading: facebookLoading, onTap: onFacebookLogin),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const _TermsText(action: 'signing in'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── AppBar Title ─────────────────────────────────────────────────────────────
class _AppBarTitle extends StatelessWidget {
  const _AppBarTitle();
  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFF7C3FED), Color(0xFF9D6FFF), Color(0xFF6B28EA)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      child: const Text('Trouble Sarthi',
          style: TextStyle(
              color: Colors.white, fontFamily: 'Saman', fontSize: 19, fontWeight: FontWeight.bold)),
    );
  }
}

// ─── Logo Banner ──────────────────────────────────────────────────────────────
class _LogoBanner extends StatelessWidget {
  const _LogoBanner();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8E4FF), Color(0xFFD4CEFF)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: Color(0xFF4F46E5), shape: BoxShape.circle),
            child: SizedBox(
              width: 84,
              height: 84,
              child: Center(child: Icon(Icons.verified_user, size: 42, color: Colors.white)),
            ),
          ),
          SizedBox(height: 10),
          Text('ASSISTANCE SIMPLIFIED',
              style: TextStyle(
                  color: Color(0xFF4F46E5),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5)),
        ],
      ),
    );
  }
}

// ─── Phone Field ──────────────────────────────────────────────────────────────
class _PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final String selectedCountryCode;
  final String? error;
  final ValueChanged<String> onCountryChanged;
  final ValueChanged<String> onChanged;

  const _PhoneField({
    required this.controller,
    required this.selectedCountryCode,
    required this.error,
    required this.onCountryChanged,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = error != null ? const Color(0xFFDC2626) : const Color(0xFFE5E7EB);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedCountryCode,
                  icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF6B7280)),
                  isDense: true,
                  items: const ['+91', '+1', '+44', '+971', '+61']
                      .map((code) => DropdownMenuItem(
                    value: code,
                    child: Text(code,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937))),
                  ))
                      .toList(),
                  onChanged: (v) => onCountryChanged(v!),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                onChanged: onChanged,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Phone Number',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: borderColor)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2)),
                ),
              ),
            ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(error!,
                style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
          ),
        ],
      ],
    );
  }
}

// ─── Primary Button ───────────────────────────────────────────────────────────
class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PrimaryButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF6366F1)]),
        borderRadius: BorderRadius.circular(25),
        boxShadow: const [BoxShadow(color: Color(0x4D4F46E5), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(25),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(width: 8),
              Icon(icon, size: 18, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Divider ──────────────────────────────────────────────────────────────────
class _Divider extends StatelessWidget {
  final String label;
  const _Divider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFE5E7EB), thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
        ),
        const Expanded(child: Divider(color: Color(0xFFE5E7EB), thickness: 1)),
      ],
    );
  }
}

// ─── Email Button ─────────────────────────────────────────────────────────────
class _EmailButton extends StatelessWidget {
  final VoidCallback onTap;
  const _EmailButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _InteractiveSocialButton(
      onTap: onTap,
      defaultColor: Colors.white,
      pressedColor: const Color(0xFFF0EFFF),
      borderColor: const Color(0xFFE5E7EB),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.email_outlined, color: Color(0xFF4F46E5), size: 20),
          SizedBox(width: 8),
          Text('Continue with Email',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF4F46E5))),
        ],
      ),
    );
  }
}

// ─── Google Button ────────────────────────────────────────────────────────────
class _GoogleButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _GoogleButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _InteractiveSocialButton(
      onTap: loading ? () {} : onTap,
      defaultColor: Colors.white,
      pressedColor: const Color(0xFFF1F3F4),
      borderColor: const Color(0xFFE5E7EB),
      child: loading
          ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4285F4)))
          : const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _GoogleGIcon(),
          SizedBox(width: 6),
          Text('Google',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF3C4043))),
        ],
      ),
    );
  }
}

// ─── Google G Icon ────────────────────────────────────────────────────────────
class _GoogleGIcon extends StatelessWidget {
  const _GoogleGIcon();
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(20, 20), painter: _GoogleGPainter());
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);
    final rect = Rect.fromCircle(center: center, radius: r);
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = r * 0.38;

    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.52, 1.57, false, paint);
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -2.09, 1.57, false, paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 2.62, 0.7, false, paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 1.05, 1.57, false, paint);

    final barPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = r * 0.38
      ..strokeCap = StrokeCap.butt;
    canvas.drawLine(Offset(r, r), Offset(size.width * 0.98, r), barPaint);

    final innerPaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    canvas.drawCircle(center, r * 0.62, innerPaint);

    final innerRect = Rect.fromCircle(center: center, radius: r * 0.72);
    final innerStroke = Paint()..style = PaintingStyle.stroke..strokeWidth = r * 0.30;
    innerStroke.color = const Color(0xFF4285F4);
    canvas.drawArc(innerRect, -0.52, 1.57, false, innerStroke);
    innerStroke.color = const Color(0xFFEA4335);
    canvas.drawArc(innerRect, -2.09, 1.57, false, innerStroke);
    innerStroke.color = const Color(0xFFFBBC05);
    canvas.drawArc(innerRect, 2.62, 0.7, false, innerStroke);
    innerStroke.color = const Color(0xFF34A853);
    canvas.drawArc(innerRect, 1.05, 1.57, false, innerStroke);

    final hBar = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = r * 0.30
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(r, r), Offset(r + r * 0.72, r), hBar);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Facebook Button ──────────────────────────────────────────────────────────
class _FacebookButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _FacebookButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _InteractiveSocialButton(
      onTap: loading ? () {} : onTap,
      defaultColor: const Color(0xFF1877F2),
      pressedColor: const Color(0xFF1565C0),
      borderColor: Colors.transparent,
      child: loading
          ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _FacebookFIcon(),
          SizedBox(width: 6),
          Text('Facebook',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
        ],
      ),
    );
  }
}

class _FacebookFIcon extends StatelessWidget {
  const _FacebookFIcon();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: const Center(
        child: Text('f',
            style: TextStyle(
                color: Color(0xFF1877F2), fontSize: 13, fontWeight: FontWeight.bold, height: 1.1)),
      ),
    );
  }
}

// ─── Interactive Social Button ────────────────────────────────────────────────
class _InteractiveSocialButton extends StatefulWidget {
  final VoidCallback onTap;
  final Color defaultColor, pressedColor, borderColor;
  final Widget child;

  const _InteractiveSocialButton({
    required this.onTap,
    required this.defaultColor,
    required this.pressedColor,
    required this.borderColor,
    required this.child,
  });

  @override
  State<_InteractiveSocialButton> createState() => _InteractiveSocialButtonState();
}

class _InteractiveSocialButtonState extends State<_InteractiveSocialButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 44,
        decoration: BoxDecoration(
          color: _pressed ? widget.pressedColor : widget.defaultColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: widget.borderColor),
          boxShadow: _pressed
              ? []
              : const [BoxShadow(color: Color(0x18000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Center(child: widget.child),
      ),
    );
  }
}

// ─── Terms Text ───────────────────────────────────────────────────────────────
class _TermsText extends StatelessWidget {
  final String action;
  const _TermsText({required this.action});

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), height: 1.5),
        children: [
          TextSpan(text: 'By $action, you agree to our '),
          const TextSpan(
              text: 'Terms of Service',
              style: TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.w600)),
          const TextSpan(text: ' and '),
          const TextSpan(
              text: 'Privacy Policy',
              style: TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.w600)),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }
}