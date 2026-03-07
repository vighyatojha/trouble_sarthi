// ignore_for_file: use_build_context_synchronously, deprecated_member_use
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'signup_screen.dart';
import 'complete_profile_screen.dart';
import 'package:trouble_sarthi/screens/home_screen.dart';
import 'package:trouble_sarthi/service/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl   = TextEditingController();

  bool _useUsername     = false;
  bool _obscurePassword = true;
  bool _googleLoading   = false;
  bool _facebookLoading = false;
  bool _signInLoading   = false;

  String? _identifierError;
  String? _passwordError;

  // Page entrance
  late final AnimationController _pageCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;

  // Field swap animation
  late final AnimationController _fieldCtrl;
  late final Animation<double>   _fieldFade;
  late final Animation<Offset>   _fieldSlide;

  @override
  void initState() {
    super.initState();

    _pageCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _fadeAnim  = CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOutCubic));

    _fieldCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _fieldFade  = CurvedAnimation(parent: _fieldCtrl, curve: Curves.easeInOut);
    _fieldSlide = Tween<Offset>(
        begin: const Offset(0.08, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _fieldCtrl, curve: Curves.easeOutCubic));
    _fieldCtrl.forward();
  }

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    _pageCtrl.dispose();
    _fieldCtrl.dispose();
    super.dispose();
  }

  // Animate field out → swap → animate in
  Future<void> _switchMode(bool toUsername) async {
    if (_useUsername == toUsername) return;
    await _fieldCtrl.reverse();
    setState(() {
      _useUsername     = toUsername;
      _identifierError = null;
      _identifierCtrl.clear();
    });
    _fieldCtrl.forward();
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
      final dest = (result.isNewUser || !result.profileComplete)
          ? const CompleteProfileScreen()
          : const HomeScreen();
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (_, a, __) => dest,
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 350),
        ),
            (route) => false,
      );
    }
  }

  Future<String?> _resolveEmailFromUsername(String username) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username.toLowerCase().trim())
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        return snap.docs.first.data()['email'] as String?;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _signIn() async {
    final identifier = _identifierCtrl.text.trim();
    final password   = _passwordCtrl.text;
    bool valid = true;

    if (identifier.isEmpty) {
      setState(() => _identifierError =
      _useUsername ? 'Enter your username' : 'Enter your email address');
      valid = false;
    } else if (!_useUsername && !identifier.contains('@')) {
      setState(() => _identifierError = 'Enter a valid email address');
      valid = false;
    }
    if (password.length < 6) {
      setState(() => _passwordError = 'Password must be at least 6 characters');
      valid = false;
    }
    if (!valid) return;

    setState(() => _signInLoading = true);
    try {
      String email = identifier;
      if (_useUsername) {
        final resolved = await _resolveEmailFromUsername(identifier);
        if (resolved == null) {
          setState(() => _identifierError = 'No account found with this username.');
          return;
        }
        email = resolved;
      }

      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      if (credential.user != null && mounted) {
        final isNew = credential.additionalUserInfo?.isNewUser ?? false;
        final dest  = isNew ? const CompleteProfileScreen() : const HomeScreen();
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (_, a, __) => dest,
            transitionsBuilder: (_, a, __, child) =>
                FadeTransition(opacity: a, child: child),
            transitionDuration: const Duration(milliseconds: 350),
          ),
              (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        final msg = switch (e.code) {
          'user-not-found'     => 'No account found with this email.',
          'wrong-password'     => 'Incorrect password. Please try again.',
          'invalid-email'      => 'Please enter a valid email.',
          'invalid-credential' => 'Incorrect email or password.',
          _                    => e.message ?? 'Login failed.',
        };
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } finally {
      if (mounted) setState(() => _signInLoading = false);
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

  void _forgotPassword() async {
    if (_useUsername) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Switch to email mode to reset your password.'),
        backgroundColor: Color(0xFFD97706),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final email = _identifierCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _identifierError = 'Enter your email above first');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Reset link sent to $email'),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      body: Stack(
        children: [
          const _LoginBackground(),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                      child: Row(children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.white54, size: 18),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        _TroubleSarthiLogo(),
                        const Spacer(),
                        const SizedBox(width: 40),
                      ]),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 8),
                            const _HeroSection(),
                            const SizedBox(height: 24),
                            _GlassCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [

                                  // ── TOGGLE ───────────────────────────
                                  _AnimatedModeToggle(
                                    useUsername: _useUsername,
                                    onToggle: _switchMode,
                                  ),
                                  const SizedBox(height: 16),

                                  // ── ANIMATED FIELD ───────────────────
                                  FadeTransition(
                                    opacity: _fieldFade,
                                    child: SlideTransition(
                                      position: _fieldSlide,
                                      child: _LoginField(
                                        key: ValueKey(_useUsername),
                                        controller: _identifierCtrl,
                                        hint: _useUsername ? 'Username' : 'Email address',
                                        icon: _useUsername
                                            ? Icons.alternate_email_rounded
                                            : Icons.mail_outline_rounded,
                                        error: _identifierError,
                                        keyboardType: _useUsername
                                            ? TextInputType.text
                                            : TextInputType.emailAddress,
                                        onChanged: (_) =>
                                            setState(() => _identifierError = null),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  _LoginField(
                                    controller: _passwordCtrl,
                                    hint: 'Password',
                                    icon: Icons.lock_outline_rounded,
                                    error: _passwordError,
                                    obscure: _obscurePassword,
                                    onChanged: (_) =>
                                        setState(() => _passwordError = null),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: Colors.white38,
                                        size: 18,
                                      ),
                                      onPressed: () => setState(
                                              () => _obscurePassword = !_obscurePassword),
                                    ),
                                  ),

                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: _forgotPassword,
                                      style: TextButton.styleFrom(
                                          padding: const EdgeInsets.only(top: 2)),
                                      child: const Text('Forgot password?',
                                          style: TextStyle(
                                              color: Color(0xFF818CF8),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500)),
                                    ),
                                  ),

                                  _PrimaryLoginButton(
                                    loading: _signInLoading,
                                    onTap: _signIn,
                                  ),

                                  const SizedBox(height: 20),

                                  Row(children: [
                                    Expanded(
                                        child: Divider(
                                            color: Colors.white.withOpacity(0.08),
                                            thickness: 1)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 14),
                                      child: Text('or continue with',
                                          style: TextStyle(
                                              color: Colors.white.withOpacity(0.3),
                                              fontSize: 11)),
                                    ),
                                    Expanded(
                                        child: Divider(
                                            color: Colors.white.withOpacity(0.08),
                                            thickness: 1)),
                                  ]),

                                  const SizedBox(height: 14),

                                  Row(children: [
                                    Expanded(
                                      child: _SocialButton(
                                        label: 'Google',
                                        loading: _googleLoading,
                                        onTap: _googleSignIn,
                                        icon: const _GoogleIcon(),
                                        bg: const Color(0xFF1C1C24),
                                        border: const Color(0xFF2A2A38),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _SocialButton(
                                        label: 'Facebook',
                                        loading: _facebookLoading,
                                        onTap: _facebookSignIn,
                                        icon: const _FacebookIcon(),
                                        bg: const Color(0xFF0D1E3D),
                                        border: const Color(0xFF1A3260),
                                      ),
                                    ),
                                  ]),

                                  const SizedBox(height: 16),

                                  Text(
                                    'By signing in, you agree to our Terms of Service and Privacy Policy.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white.withOpacity(0.2),
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text("Don't have an account? ",
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.4),
                                        fontSize: 13)),
                                GestureDetector(
                                  onTap: () => Navigator.pushReplacement(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder: (_, __, ___) =>
                                      const SignUpScreen(),
                                      transitionsBuilder: (_, a, __, child) =>
                                          FadeTransition(opacity: a, child: child),
                                      transitionDuration:
                                      const Duration(milliseconds: 200),
                                    ),
                                  ),
                                  child: const Text('Sign up',
                                      style: TextStyle(
                                          color: Color(0xFF818CF8),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ),
                  ],
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
//  ANIMATED MODE TOGGLE
// ═══════════════════════════════════════════════════════════════════════════
class _AnimatedModeToggle extends StatelessWidget {
  final bool useUsername;
  final Future<void> Function(bool) onToggle;

  const _AnimatedModeToggle({
    required this.useUsername,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07), width: 1),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            alignment:
            useUsername ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF6D6AFA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withOpacity(0.45),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(children: [
            _ToggleTab(
              label: 'Email',
              icon: Icons.mail_outline_rounded,
              active: !useUsername,
              onTap: () => onToggle(false),
            ),
            _ToggleTab(
              label: 'Username',
              icon: Icons.alternate_email_rounded,
              active: useUsername,
              onTap: () => onToggle(true),
            ),
          ]),
        ],
      ),
    );
  }
}

class _ToggleTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _ToggleTab({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            style: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? Colors.white : Colors.white.withOpacity(0.35),
              letterSpacing: active ? 0.1 : 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Icon(
                    icon,
                    key: ValueKey(active),
                    size: 15,
                    color: active
                        ? Colors.white
                        : Colors.white.withOpacity(0.35),
                  ),
                ),
                const SizedBox(width: 7),
                Text(label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  LOGIN FIELD
// ═══════════════════════════════════════════════════════════════════════════
class _LoginField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final String? error;
  final bool obscure;
  final TextInputType keyboardType;
  final ValueChanged<String> onChanged;
  final Widget? suffixIcon;

  const _LoginField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    required this.onChanged,
    this.error,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: hasError
              ? [
            BoxShadow(
              color: const Color(0xFFDC2626).withOpacity(0.18),
              blurRadius: 10,
              spreadRadius: 1,
            )
          ]
              : [],
        ),
        child: TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.25), fontSize: 14),
            prefixIcon:
            Icon(icon, color: const Color(0xFF6366F1), size: 18),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: const Color(0xFF0F0F14),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                  color: hasError
                      ? const Color(0xFFDC2626)
                      : Colors.white.withOpacity(0.08)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                  color: hasError
                      ? const Color(0xFFDC2626)
                      : Colors.white.withOpacity(0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                  color: hasError
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF6366F1),
                  width: 1.5),
            ),
          ),
        ),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: hasError
            ? Padding(
          padding: const EdgeInsets.only(left: 4, top: 5),
          child: Row(children: [
            const Icon(Icons.error_outline_rounded,
                size: 12, color: Color(0xFFDC2626)),
            const SizedBox(width: 4),
            Text(error!,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFFDC2626))),
          ]),
        )
            : const SizedBox.shrink(),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  BACKGROUND
// ═══════════════════════════════════════════════════════════════════════════
class _LoginBackground extends StatelessWidget {
  const _LoginBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Container(color: const Color(0xFF0F0F14)),
      Positioned(
        top: -80, left: -60,
        child: Container(
          width: 280, height: 280,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
                colors: [Color(0x334F46E5), Colors.transparent]),
          ),
        ),
      ),
      Positioned(
        bottom: -60, right: -40,
        child: Container(
          width: 220, height: 220,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
                colors: [Color(0x226366F1), Colors.transparent]),
          ),
        ),
      ),
      Opacity(
        opacity: 0.05,
        child: CustomPaint(
          size: MediaQuery.of(context).size,
          painter: _DotGridPainter(),
        ),
      ),
    ]);
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ═══════════════════════════════════════════════════════════════════════════
//  LOGO
// ═══════════════════════════════════════════════════════════════════════════
class _TroubleSarthiLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFF818CF8), Color(0xFF6366F1), Color(0xFFA5B4FC)],
      ).createShader(bounds),
      child: const Text('Trouble Sarthi',
          style: TextStyle(
              color: Colors.white,
              fontFamily: 'Saman',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  HERO  ← biometric param removed
// ═══════════════════════════════════════════════════════════════════════════
class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F46E5).withOpacity(0.4),
              blurRadius: 16, offset: const Offset(0, 6),
            )
          ],
        ),
        child: const Icon(Icons.verified_user_rounded,
            color: Colors.white, size: 26),
      ),
      const SizedBox(height: 14),
      const Text('Welcome\nback.',
          style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.05,
              letterSpacing: -1.2)),
      const SizedBox(height: 6),
      Text(
        'Sign in to continue',
        style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.4)),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  GLASS CARD
// ═══════════════════════════════════════════════════════════════════════════
class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16161F),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 30,
              offset: const Offset(0, 12)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: child,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  PRIMARY BUTTON
// ═══════════════════════════════════════════════════════════════════════════
class _PrimaryLoginButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _PrimaryLoginButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF4F46E5).withOpacity(0.35),
                blurRadius: 14,
                offset: const Offset(0, 5))
          ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
              : const Text('Sign In',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3)),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SOCIAL BUTTON
// ═══════════════════════════════════════════════════════════════════════════
class _SocialButton extends StatefulWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;
  final Widget icon;
  final Color bg, border;

  const _SocialButton({
    required this.label,
    required this.loading,
    required this.onTap,
    required this.icon,
    required this.bg,
    required this.border,
  });

  @override
  State<_SocialButton> createState() => _SocialButtonState();
}

class _SocialButtonState extends State<_SocialButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        if (!widget.loading) widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: _pressed ? widget.bg.withOpacity(0.7) : widget.bg,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: widget.border),
          ),
          child: Center(
            child: widget.loading
                ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white54, strokeWidth: 2))
                : Row(mainAxisSize: MainAxisSize.min, children: [
              widget.icon,
              const SizedBox(width: 8),
              Text(widget.label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  GOOGLE ICON
// ═══════════════════════════════════════════════════════════════════════════
class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();
  @override
  Widget build(BuildContext context) => SizedBox(
      width: 20, height: 20,
      child: CustomPaint(painter: _GoogleGPainter()));
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width * 0.46;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.2
      ..strokeCap = StrokeCap.butt;

    final oval = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(oval, math.pi * 1.25, math.pi * 0.70, false, paint);
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(oval, -math.pi * 0.25, math.pi * 0.75, false, paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(oval, math.pi * 0.75, math.pi * 0.5, false, paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(oval, math.pi * 0.5, math.pi * 0.25, false, paint);

    final whitePaint = Paint()..color = const Color(0xFF1C1C24);
    canvas.drawRect(
      Rect.fromLTWH(cx, cy - size.height * 0.21,
          size.width * 0.5, size.height * 0.21),
      whitePaint,
    );

    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = size.width * 0.2
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(Offset(cx, cy), Offset(size.width * 0.88, cy), barPaint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ═══════════════════════════════════════════════════════════════════════════
//  FACEBOOK ICON
// ═══════════════════════════════════════════════════════════════════════════
class _FacebookIcon extends StatelessWidget {
  const _FacebookIcon();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20, height: 20,
      decoration: const BoxDecoration(
          color: Color(0xFF1877F2), shape: BoxShape.circle),
      child: const Center(
        child: Text('f',
            style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                height: 1.2)),
      ),
    );
  }
}