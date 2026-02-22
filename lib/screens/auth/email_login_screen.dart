import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'signup_screen.dart';
import 'package:trouble_sarthi/screens/home_screen.dart';

class EmailLoginScreen extends StatefulWidget {
  const EmailLoginScreen({super.key});

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final emailErr = email.isEmpty ? 'Email is required' : null;
    final passErr = password.isEmpty ? 'Password is required' : null;

    setState(() {
      _emailError = emailErr;
      _passwordError = passErr;
    });

    if (emailErr != null || passErr != null) return;

    setState(() => _isLoading = true);

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) throw Exception('Login failed');

      // Fetch user doc — but don't block UX on it
      FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (_, animation, __) => const HomeScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
            (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'user-not-found':
        case 'invalid-email':
          msg = 'No account found with this email.';
          break;
        case 'wrong-password':
        case 'invalid-credential':
          msg = 'Incorrect password. Please try again.';
          break;
        case 'too-many-requests':
          msg = 'Too many attempts. Please try later.';
          break;
        default:
          msg = e.message ?? 'Login failed. Please try again.';
      }
      _showSnack(msg, isError: true);
    } catch (_) {
      _showSnack('Something went wrong. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F5),
      body: SafeArea(
        child: Column(
          children: [
            // ── AppBar ─────────────────────────────────────────────────────
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

            // ── Body ───────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Container(
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 6),
                          const _LogoBanner(),
                          const SizedBox(height: 20),

                          const Text(
                            'Welcome Back!',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Login with your email and password',
                            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                          ),
                          const SizedBox(height: 18),

                          // ── Email ─────────────────────────────────────────
                          _InputField(
                            controller: _emailController,
                            label: 'Email',
                            hint: 'Enter your email',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            errorText: _emailError,
                            onChanged: (_) => setState(() => _emailError = null),
                          ),
                          const SizedBox(height: 10),

                          // ── Password ──────────────────────────────────────
                          _PasswordField(
                            controller: _passwordController,
                            obscure: _obscurePassword,
                            errorText: _passwordError,
                            onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
                            onChanged: (_) => setState(() => _passwordError = null),
                          ),

                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                // TODO: forgot password
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  color: Color(0xFF4F46E5),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // ── Login Button ──────────────────────────────────
                          Container(
                            width: double.infinity,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                              ),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: const [
                                BoxShadow(color: Color(0x4D4F46E5), blurRadius: 12, offset: Offset(0, 4)),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _isLoading ? null : _handleLogin,
                                borderRadius: BorderRadius.circular(24),
                                child: Center(
                                  child: _isLoading
                                      ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  )
                                      : const Text(
                                    'Login',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),
                          const _Divider(label: 'Or'),
                          const SizedBox(height: 14),

                          // ── Social Buttons ────────────────────────────────
                          Row(
                            children: [
                              Expanded(
                                child: _InteractiveSocialButton(
                                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Google Sign-In coming soon')),
                                  ),
                                  defaultColor: Colors.white,
                                  pressedColor: const Color(0xFFF1F3F4),
                                  borderColor: const Color(0xFFE5E7EB),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _GoogleGIcon(),
                                      SizedBox(width: 6),
                                      Text('Google', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF3C4043))),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _InteractiveSocialButton(
                                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Facebook Sign-In coming soon')),
                                  ),
                                  defaultColor: const Color(0xFF1877F2),
                                  pressedColor: const Color(0xFF1565C0),
                                  borderColor: Colors.transparent,
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _FacebookFIcon(),
                                      SizedBox(width: 6),
                                      Text('Facebook', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),
                          const _TermsText(action: 'signing in'),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Bottom Signup Link ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? ",
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => const SignUpScreen(),
                        transitionsBuilder: (_, animation, __, child) =>
                            FadeTransition(opacity: animation, child: child),
                        transitionDuration: const Duration(milliseconds: 200),
                      ),
                    ),
                    child: const Text(
                      'Sign up',
                      style: TextStyle(color: Color(0xFF4F46E5), fontSize: 14, fontWeight: FontWeight.bold),
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

// ─── Shared widgets ───────────────────────────────────────────────────────────

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
      child: const Text(
        'Trouble Sarthi',
        style: TextStyle(color: Colors.white, fontFamily: 'Saman', fontSize: 19, fontWeight: FontWeight.bold),
      ),
    );
  }
}

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
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: Color(0xFF4F46E5), shape: BoxShape.circle),
            child: SizedBox(
              width: 80,
              height: 80,
              child: Center(child: Icon(Icons.verified_user, size: 40, color: Colors.white)),
            ),
          ),
          SizedBox(height: 10),
          Text(
            'ASSISTANCE SIMPLIFIED',
            style: TextStyle(color: Color(0xFF4F46E5), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
          ),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = errorText != null ? const Color(0xFFDC2626) : const Color(0xFFE5E7EB);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
            prefixIcon: Icon(icon, color: const Color(0xFF6B7280), size: 20),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: errorText != null ? const Color(0xFFDC2626) : const Color(0xFF4F46E5), width: 2),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(errorText!, style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
          ),
        ],
      ],
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const _PasswordField({
    required this.controller,
    required this.obscure,
    required this.onToggle,
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = errorText != null ? const Color(0xFFDC2626) : const Color(0xFFE5E7EB);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          obscureText: obscure,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            labelText: 'Password',
            hintText: 'Enter your password',
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
            prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF6B7280), size: 20),
            suffixIcon: IconButton(
              icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF6B7280), size: 20),
              onPressed: onToggle,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: errorText != null ? const Color(0xFFDC2626) : const Color(0xFF4F46E5), width: 2),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(errorText!, style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
          ),
        ],
      ],
    );
  }
}

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
          const TextSpan(text: 'Terms of Service', style: TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.w600)),
          const TextSpan(text: ' and '),
          const TextSpan(text: 'Privacy Policy', style: TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.w600)),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }
}

class _InteractiveSocialButton extends StatefulWidget {
  final VoidCallback onTap;
  final Color defaultColor;
  final Color pressedColor;
  final Color borderColor;
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
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 44,
        decoration: BoxDecoration(
          color: _pressed ? widget.pressedColor : widget.defaultColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: widget.borderColor),
          boxShadow: _pressed ? [] : const [BoxShadow(color: Color(0x18000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: widget.child,
      ),
    );
  }
}

class _GoogleGIcon extends StatelessWidget {
  const _GoogleGIcon();
  @override
  Widget build(BuildContext context) => CustomPaint(size: const Size(20, 20), painter: _GoogleGPainter());
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);
    final outer = Rect.fromCircle(center: center, radius: r * 0.85);
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = r * 0.32;

    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(outer, -0.52, 1.57, false, paint);
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(outer, -2.09, 1.57, false, paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(outer, 2.62, 0.70, false, paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(outer, 1.05, 1.57, false, paint);

    canvas.drawCircle(center, r * 0.53, Paint()..color = Colors.white..style = PaintingStyle.fill);

    final bar = Paint()..color = const Color(0xFF4285F4)..strokeWidth = r * 0.32..strokeCap = StrokeCap.butt;
    canvas.drawLine(center, Offset(r + r * 0.85, r), bar);
    canvas.drawRect(
      Rect.fromLTWH(r, r - r * 0.18, r, r * 0.18),
      Paint()..color = Colors.white..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
        child: Text('f', style: TextStyle(color: Color(0xFF1877F2), fontSize: 13, fontWeight: FontWeight.bold, height: 1.1)),
      ),
    );
  }
}