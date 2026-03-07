// ignore_for_file: use_build_context_synchronously, deprecated_member_use
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'complete_profile_screen.dart';
import 'package:trouble_sarthi/service/auth_service.dart';

class EmailSignUpScreen extends StatefulWidget {
  const EmailSignUpScreen({super.key});

  @override
  State<EmailSignUpScreen> createState() => _EmailSignUpScreenState();
}

class _EmailSignUpScreenState extends State<EmailSignUpScreen>
    with TickerProviderStateMixin {
  final _nameController            = TextEditingController();
  final _usernameController        = TextEditingController();
  final _emailController           = TextEditingController();
  final _phoneController           = TextEditingController();
  final _passwordController        = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm  = true;
  bool _isLoading       = false;
  bool _googleLoading   = false;
  bool _facebookLoading = false;

  String? _nameError;
  String? _usernameError;
  String? _emailError;
  String? _phoneError;
  String? _passwordError;
  String? _confirmPasswordError;

  // ── Page entrance animation ───────────────────────────────────────────────
  late final AnimationController _pageCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _pageCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _fadeAnim  = CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(
        CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  // ── Password strength ─────────────────────────────────────────────────────
  bool get _hasMinLength => _passwordController.text.length >= 8;
  bool get _hasUppercase =>
      _passwordController.text.contains(RegExp(r'[A-Z]'));
  bool get _hasNumber =>
      _passwordController.text.contains(RegExp(r'[0-9]'));
  bool get _hasSpecial =>
      _passwordController.text.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

  // ── Validation ────────────────────────────────────────────────────────────
  bool _validateAll() {
    final name     = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final email    = _emailController.text.trim();
    final phone    = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirm  = _confirmPasswordController.text;

    String? nameErr, usernameErr, emailErr, phoneErr, passwordErr, confirmErr;

    if (name.isEmpty) {
      nameErr = 'Full name is required';
    } else if (name.length < 2) {
      nameErr = 'Name must be at least 2 characters';
    }

    if (username.isEmpty) {
      usernameErr = 'Username is required';
    } else if (username.length < 3) {
      usernameErr = 'Username must be at least 3 characters';
    } else if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      usernameErr = 'Only letters, numbers, and underscores allowed';
    }

    if (email.isEmpty) {
      emailErr = 'Email is required';
    } else if (!RegExp(r'^[\w.+-]+@[\w-]+\.\w{2,}$').hasMatch(email)) {
      emailErr = 'Enter a valid email address';
    }

    if (phone.isEmpty) {
      phoneErr = 'Phone number is required';
    } else if (!RegExp(r'^\+?[0-9]{10,13}$').hasMatch(phone)) {
      phoneErr = 'Enter a valid phone number (10–13 digits)';
    }

    if (password.isEmpty) {
      passwordErr = 'Password is required';
    } else if (password.length < 8) {
      passwordErr = 'Password must be at least 8 characters';
    } else if (!_hasUppercase) {
      passwordErr = 'Must contain at least one uppercase letter';
    } else if (!_hasNumber) {
      passwordErr = 'Must contain at least one number';
    } else if (!_hasSpecial) {
      passwordErr = 'Must contain at least one special character';
    }

    if (confirm.isEmpty) {
      confirmErr = 'Please confirm your password';
    } else if (confirm != password) {
      confirmErr = 'Passwords do not match';
    }

    setState(() {
      _nameError            = nameErr;
      _usernameError        = usernameErr;
      _emailError           = emailErr;
      _phoneError           = phoneErr;
      _passwordError        = passwordErr;
      _confirmPasswordError = confirmErr;
    });

    return nameErr == null &&
        usernameErr == null &&
        emailErr == null &&
        phoneErr == null &&
        passwordErr == null &&
        confirmErr == null;
  }

  // ── Email Sign Up ─────────────────────────────────────────────────────────
  Future<void> _handleSignUp() async {
    if (!_validateAll()) return;
    setState(() => _isLoading = true);

    try {
      final credential =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email:    _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = credential.user;
      if (user == null) throw Exception('User creation failed');

      await user.updateDisplayName(_nameController.text.trim());

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'uid':             user.uid,
        'fullName':        _nameController.text.trim(),
        'username':        _usernameController.text.trim().toLowerCase(),
        'email':           _emailController.text.trim(),
        'phone':           _phoneController.text.trim(),
        'provider':        'email',
        'createdAt':       FieldValue.serverTimestamp(),
        'profileComplete': false,
        'locationSet':     false,
      });

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (_, animation, __) => const CompleteProfileScreen(),
          transitionsBuilder: (_, animation, __, child) {
            final curved = CurvedAnimation(
                parent: animation, curve: Curves.easeOutCubic);
            return FadeTransition(opacity: curved, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
            (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      final message = switch (e.code) {
        'email-already-in-use' => 'An account with this email already exists.',
        'invalid-email'        => 'The email address is not valid.',
        'weak-password'        => 'Password is too weak. Use at least 8 characters.',
        _                      => e.message ?? 'Sign-up failed. Please try again.',
      };
      _showSnackBar(message, isError: true);
    } catch (e) {
      _showSnackBar('Something went wrong. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Google Sign Up ────────────────────────────────────────────────────────
  Future<void> _handleGoogleSignUp() async {
    setState(() => _googleLoading = true);
    final result = await AuthService.instance.signInWithGoogle();
    if (mounted) setState(() => _googleLoading = false);
    _handleSocialAuthResult(result);
  }

  // ── Facebook Sign Up ──────────────────────────────────────────────────────
  Future<void> _handleFacebookSignUp() async {
    setState(() => _facebookLoading = true);
    final result = await AuthService.instance.signInWithFacebook();
    if (mounted) setState(() => _facebookLoading = false);
    _handleSocialAuthResult(result);
  }

  // ── Handle Social Auth Result ─────────────────────────────────────────────
  void _handleSocialAuthResult(AuthResult result) {
    if (!mounted) return;
    if (result.cancelled) return;
    if (result.error != null) {
      _showSnackBar(result.error!, isError: true);
      return;
    }
    if (result.isSuccess) {
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (_, a, __) => const CompleteProfileScreen(),
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
            (route) => false,
      );
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor:
      isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
      behavior: SnackBarBehavior.floating,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      body: Stack(
        children: [
          // ── Dark dot-grid background ──────────────────────────────────────
          const _SignUpBackground(),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  children: [
                    // ── Top bar ─────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                      child: Row(children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.white54, size: 18),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        _SignUpLogo(),
                        const Spacer(),
                        const SizedBox(width: 40),
                      ]),
                    ),

                    // ── Scrollable content ──────────────────────────────────
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding:
                        const EdgeInsets.fromLTRB(20, 12, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 4),

                            // ── Hero ──────────────────────────────────────
                            _SignUpHero(),

                            const SizedBox(height: 24),

                            // ── Glass card ────────────────────────────────
                            _SignUpGlassCard(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.stretch,
                                children: [
                                  // Name
                                  _DarkField(
                                    controller: _nameController,
                                    hint: 'Full Name',
                                    icon: Icons.person_outline_rounded,
                                    error: _nameError,
                                    onChanged: (_) => setState(
                                            () => _nameError = null),
                                  ),
                                  const SizedBox(height: 10),

                                  // Username
                                  _DarkField(
                                    controller: _usernameController,
                                    hint: 'Username',
                                    icon: Icons.alternate_email_rounded,
                                    error: _usernameError,
                                    onChanged: (_) => setState(
                                            () => _usernameError = null),
                                  ),
                                  const SizedBox(height: 10),

                                  // Email
                                  _DarkField(
                                    controller: _emailController,
                                    hint: 'Email address',
                                    icon: Icons.mail_outline_rounded,
                                    keyboardType:
                                    TextInputType.emailAddress,
                                    error: _emailError,
                                    onChanged: (_) => setState(
                                            () => _emailError = null),
                                  ),
                                  const SizedBox(height: 10),

                                  // Phone
                                  _DarkField(
                                    controller: _phoneController,
                                    hint: 'Phone number',
                                    icon: Icons.phone_outlined,
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [
                                      FilteringTextInputFormatter
                                          .digitsOnly
                                    ],
                                    error: _phoneError,
                                    onChanged: (_) => setState(
                                            () => _phoneError = null),
                                  ),
                                  const SizedBox(height: 10),

                                  // Password
                                  _DarkField(
                                    controller: _passwordController,
                                    hint: 'Password',
                                    icon: Icons.lock_outline_rounded,
                                    obscure: _obscurePassword,
                                    error: _passwordError,
                                    onChanged: (_) => setState(
                                            () => _passwordError = null),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: Colors.white38,
                                        size: 18,
                                      ),
                                      onPressed: () => setState(() =>
                                      _obscurePassword =
                                      !_obscurePassword),
                                    ),
                                  ),

                                  // Password strength chips
                                  if (_passwordController
                                      .text.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    _DarkStrengthRow(
                                      hasMinLength: _hasMinLength,
                                      hasUppercase: _hasUppercase,
                                      hasNumber:    _hasNumber,
                                      hasSpecial:   _hasSpecial,
                                    ),
                                  ],
                                  const SizedBox(height: 10),

                                  // Confirm password
                                  _DarkField(
                                    controller: _confirmPasswordController,
                                    hint: 'Confirm Password',
                                    icon: Icons.lock_outline_rounded,
                                    obscure: _obscureConfirm,
                                    error: _confirmPasswordError,
                                    onChanged: (_) => setState(() =>
                                    _confirmPasswordError = null),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureConfirm
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: Colors.white38,
                                        size: 18,
                                      ),
                                      onPressed: () => setState(() =>
                                      _obscureConfirm =
                                      !_obscureConfirm),
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // ── Create Account button ─────────────
                                  _SignUpPrimaryButton(
                                    loading: _isLoading,
                                    onTap:   _handleSignUp,
                                  ),

                                  const SizedBox(height: 20),

                                  // ── Divider ───────────────────────────
                                  Row(children: [
                                    Expanded(
                                        child: Divider(
                                            color: Colors.white
                                                .withOpacity(0.08),
                                            thickness: 1)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14),
                                      child: Text('or sign up with',
                                          style: TextStyle(
                                              color: Colors.white
                                                  .withOpacity(0.3),
                                              fontSize: 11)),
                                    ),
                                    Expanded(
                                        child: Divider(
                                            color: Colors.white
                                                .withOpacity(0.08),
                                            thickness: 1)),
                                  ]),

                                  const SizedBox(height: 14),

                                  // ── Social buttons ────────────────────
                                  Row(children: [
                                    Expanded(
                                      child: _DarkSocialButton(
                                        label:   'Google',
                                        loading: _googleLoading,
                                        onTap:   _handleGoogleSignUp,
                                        icon:    const _GoogleIcon(),
                                        bg:      const Color(0xFF1C1C24),
                                        border:  const Color(0xFF2A2A38),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _DarkSocialButton(
                                        label:   'Facebook',
                                        loading: _facebookLoading,
                                        onTap:   _handleFacebookSignUp,
                                        icon:    const _FacebookIcon(),
                                        bg:      const Color(0xFF0D1E3D),
                                        border:  const Color(0xFF1A3260),
                                      ),
                                    ),
                                  ]),

                                  const SizedBox(height: 16),

                                  Text(
                                    'By signing up, you agree to our Terms of Service and Privacy Policy.',
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

                            // ── Login link ────────────────────────────────
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Already have an account? ',
                                    style: TextStyle(
                                        color:
                                        Colors.white.withOpacity(0.4),
                                        fontSize: 13)),
                                GestureDetector(
                                  onTap: () => Navigator.pushReplacement(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder: (_, __, ___) =>
                                      const LoginScreen(),
                                      transitionsBuilder:
                                          (_, a, __, child) =>
                                          FadeTransition(
                                              opacity: a, child: child),
                                      transitionDuration: const Duration(
                                          milliseconds: 200),
                                    ),
                                  ),
                                  child: const Text('Log in',
                                      style: TextStyle(
                                          color:      Color(0xFF818CF8),
                                          fontSize:   13,
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
//  BACKGROUND  (same dot-grid + radial glows as login)
// ═══════════════════════════════════════════════════════════════════════════
class _SignUpBackground extends StatelessWidget {
  const _SignUpBackground();

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
class _SignUpLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFF818CF8), Color(0xFF6366F1), Color(0xFFA5B4FC)],
      ).createShader(bounds),
      child: const Text('Trouble Sarthi',
          style: TextStyle(
              color:       Colors.white,
              fontFamily:  'Saman',
              fontSize:    18,
              fontWeight:  FontWeight.bold,
              letterSpacing: 0.3)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  HERO
// ═══════════════════════════════════════════════════════════════════════════
class _SignUpHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors:    [Color(0xFF4F46E5), Color(0xFF6366F1)],
            begin:     Alignment.topLeft,
            end:       Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color:      const Color(0xFF4F46E5).withOpacity(0.4),
              blurRadius: 16,
              offset:     const Offset(0, 6),
            )
          ],
        ),
        child: const Icon(Icons.person_add_rounded,
            color: Colors.white, size: 26),
      ),
      const SizedBox(height: 14),
      const Text('Create your\naccount.',
          style: TextStyle(
              fontSize:      36,
              fontWeight:    FontWeight.w900,
              color:         Colors.white,
              height:        1.05,
              letterSpacing: -1.2)),
      const SizedBox(height: 6),
      Text(
        'Sign up to get started with Trouble Sarthi',
        style: TextStyle(
            fontSize: 13, color: Colors.white.withOpacity(0.4)),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  GLASS CARD
// ═══════════════════════════════════════════════════════════════════════════
class _SignUpGlassCard extends StatelessWidget {
  final Widget child;
  const _SignUpGlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:         const Color(0xFF16161F),
        borderRadius:  BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(0.4),
              blurRadius: 30,
              offset:     const Offset(0, 12)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child:   child,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  DARK TEXT FIELD  (mirrors _LoginField exactly)
// ═══════════════════════════════════════════════════════════════════════════
class _DarkField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final String?  error;
  final bool     obscure;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final Widget? suffixIcon;

  const _DarkField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.error,
    this.obscure        = false,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve:    Curves.easeInOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: hasError
              ? [
            BoxShadow(
              color:      const Color(0xFFDC2626).withOpacity(0.18),
              blurRadius: 10,
              spreadRadius: 1,
            )
          ]
              : [],
        ),
        child: TextField(
          controller:       controller,
          obscureText:      obscure,
          keyboardType:     keyboardType,
          inputFormatters:  inputFormatters,
          onChanged:        onChanged,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText:  hint,
            hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.25), fontSize: 14),
            prefixIcon:
            Icon(icon, color: const Color(0xFF6366F1), size: 18),
            suffixIcon: suffixIcon,
            filled:     true,
            fillColor:  const Color(0xFF0F0F14),
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

      // Animated error slide-in
      AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve:    Curves.easeOutCubic,
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
//  DARK PASSWORD STRENGTH CHIPS
// ═══════════════════════════════════════════════════════════════════════════
class _DarkStrengthRow extends StatelessWidget {
  final bool hasMinLength, hasUppercase, hasNumber, hasSpecial;

  const _DarkStrengthRow({
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasNumber,
    required this.hasSpecial,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _DarkChip(label: '8+ chars', met: hasMinLength),
        _DarkChip(label: 'A-Z',      met: hasUppercase),
        _DarkChip(label: '0-9',      met: hasNumber),
        _DarkChip(label: '@#\$!',   met: hasSpecial),
      ],
    );
  }
}

class _DarkChip extends StatelessWidget {
  final String label;
  final bool   met;
  const _DarkChip({required this.label, required this.met});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: met
            ? const Color(0xFF052E16).withOpacity(0.8)
            : const Color(0xFF1A1A24),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: met
                ? const Color(0xFF16A34A).withOpacity(0.6)
                : Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.circle_outlined,
            size:  12,
            color: met
                ? const Color(0xFF4ADE80)
                : Colors.white.withOpacity(0.3),
          ),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize:   11,
                  fontWeight: FontWeight.w600,
                  color: met
                      ? const Color(0xFF4ADE80)
                      : Colors.white.withOpacity(0.3))),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  PRIMARY BUTTON
// ═══════════════════════════════════════════════════════════════════════════
class _SignUpPrimaryButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _SignUpPrimaryButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors:    [Color(0xFF4F46E5), Color(0xFF6366F1)],
              begin:     Alignment.centerLeft,
              end:       Alignment.centerRight),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color:      const Color(0xFF4F46E5).withOpacity(0.35),
                blurRadius: 14,
                offset:     const Offset(0, 5))
          ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
              width:  20, height: 20,
              child:  CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
              : const Text('Create Account',
              style: TextStyle(
                  color:       Colors.white,
                  fontSize:    15,
                  fontWeight:  FontWeight.w700,
                  letterSpacing: 0.3)),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SOCIAL BUTTON  (same as login)
// ═══════════════════════════════════════════════════════════════════════════
class _DarkSocialButton extends StatefulWidget {
  final String   label;
  final bool     loading;
  final VoidCallback onTap;
  final Widget   icon;
  final Color    bg, border;

  const _DarkSocialButton({
    required this.label,
    required this.loading,
    required this.onTap,
    required this.icon,
    required this.bg,
    required this.border,
  });

  @override
  State<_DarkSocialButton> createState() => _DarkSocialButtonState();
}

class _DarkSocialButtonState extends State<_DarkSocialButton> {
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
        scale:    _pressed ? 0.96 : 1.0,
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
                width:  18, height: 18,
                child:  CircularProgressIndicator(
                    color: Colors.white54, strokeWidth: 2))
                : Row(mainAxisSize: MainAxisSize.min, children: [
              widget.icon,
              const SizedBox(width: 8),
              Text(widget.label,
                  style: const TextStyle(
                      color:      Colors.white,
                      fontSize:   13,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  GOOGLE ICON  (same painter as login)
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
    final cx   = size.width / 2;
    final cy   = size.height / 2;
    final r    = size.width * 0.46;
    final paint = Paint()
      ..style      = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.2
      ..strokeCap  = StrokeCap.butt;
    final oval = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(oval, math.pi * 1.25, math.pi * 0.75, false, paint);
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(oval, -math.pi * 0.25, math.pi * 0.75, false, paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(oval, math.pi * 0.75, math.pi * 0.5, false, paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(oval, math.pi * 0.5, math.pi * 0.25, false, paint);

    canvas.drawRect(
      Rect.fromLTWH(cx, cy - size.height * 0.21,
          size.width * 0.5, size.height * 0.21),
      Paint()..color = const Color(0xFF1C1C24),
    );

    canvas.drawLine(
      Offset(cx, cy),
      Offset(size.width * 0.88, cy),
      Paint()
        ..color      = const Color(0xFF4285F4)
        ..strokeWidth = size.width * 0.2
        ..strokeCap  = StrokeCap.square,
    );
  }
  @override
  bool shouldRepaint(_) => false;
}

// ═══════════════════════════════════════════════════════════════════════════
//  FACEBOOK ICON  (same as login)
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
                color:      Colors.white,
                fontSize:   13,
                fontWeight: FontWeight.w900,
                height:     1.2)),
      ),
    );
  }
}