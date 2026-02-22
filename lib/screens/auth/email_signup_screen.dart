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

class _EmailSignUpScreenState extends State<EmailSignUpScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _googleLoading = false;
  bool _facebookLoading = false;

  String? _nameError;
  String? _usernameError;
  String? _emailError;
  String? _phoneError;
  String? _passwordError;
  String? _confirmPasswordError;

  // ── Password strength ─────────────────────────────────────────────────────
  bool get _hasMinLength => _passwordController.text.length >= 8;
  bool get _hasUppercase => _passwordController.text.contains(RegExp(r'[A-Z]'));
  bool get _hasNumber => _passwordController.text.contains(RegExp(r'[0-9]'));
  bool get _hasSpecial =>
      _passwordController.text.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _validateAll() {
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

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

    // Strong password validation
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
      _nameError = nameErr;
      _usernameError = usernameErr;
      _emailError = emailErr;
      _phoneError = phoneErr;
      _passwordError = passwordErr;
      _confirmPasswordError = confirmErr;
    });

    return nameErr == null &&
        usernameErr == null &&
        emailErr == null &&
        phoneErr == null &&
        passwordErr == null &&
        confirmErr == null;
  }

  Future<void> _handleSignUp() async {
    if (!_validateAll()) return;
    setState(() => _isLoading = true);

    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = credential.user;
      if (user == null) throw Exception('User creation failed');

      await user.updateDisplayName(_nameController.text.trim());

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'fullName': _nameController.text.trim(),
        'username': _usernameController.text.trim().toLowerCase(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'provider': 'email',
        'createdAt': FieldValue.serverTimestamp(),
        'profileComplete': false,
        'locationSet': false,
      });

      if (!mounted) return;

      // After email signup → always go to CompleteProfileScreen
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (_, animation, __) => const CompleteProfileScreen(),
          transitionsBuilder: (_, animation, __, child) {
            final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
            return FadeTransition(opacity: curved, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
            (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'An account with this email already exists.';
          break;
        case 'invalid-email':
          message = 'The email address is not valid.';
          break;
        case 'weak-password':
          message = 'Password is too weak. Use at least 8 characters.';
          break;
        default:
          message = e.message ?? 'Sign-up failed. Please try again.';
      }
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
        isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
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

            // ── Form ───────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.white, Color(0xFFF8F7FF), Color(0xFFF3F1FF)],
                      ),
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x144F46E5),
                            blurRadius: 24,
                            offset: Offset(0, 8)),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          const _LogoBanner(),
                          const SizedBox(height: 16),

                          const Text('Create Account',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937))),
                          const SizedBox(height: 4),
                          const Text('Sign up with your email and password',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF6B7280))),

                          const SizedBox(height: 16),

                          _InputField(
                            controller: _nameController,
                            label: 'Full Name',
                            hint: 'Enter your full name',
                            icon: Icons.person_outline,
                            errorText: _nameError,
                            onChanged: (_) {
                              if (_nameError != null)
                                setState(() => _nameError = null);
                            },
                          ),
                          const SizedBox(height: 10),
                          _InputField(
                            controller: _usernameController,
                            label: 'Username',
                            hint: 'Choose a username',
                            icon: Icons.alternate_email,
                            errorText: _usernameError,
                            onChanged: (_) {
                              if (_usernameError != null)
                                setState(() => _usernameError = null);
                            },
                          ),
                          const SizedBox(height: 10),
                          _InputField(
                            controller: _emailController,
                            label: 'Email',
                            hint: 'Enter your email',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            errorText: _emailError,
                            onChanged: (_) {
                              if (_emailError != null)
                                setState(() => _emailError = null);
                            },
                          ),
                          const SizedBox(height: 10),
                          _InputField(
                            controller: _phoneController,
                            label: 'Phone Number',
                            hint: 'Enter your phone number',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            errorText: _phoneError,
                            onChanged: (_) {
                              if (_phoneError != null)
                                setState(() => _phoneError = null);
                            },
                          ),
                          const SizedBox(height: 10),
                          _PasswordField(
                            controller: _passwordController,
                            label: 'Password',
                            hint: 'Min 8 chars, A-Z, 0-9, @#\$...',
                            obscure: _obscurePassword,
                            errorText: _passwordError,
                            onToggle: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                            onChanged: (_) {
                              setState(() => _passwordError = null);
                            },
                          ),

                          // ── Password strength indicators ──────────────────
                          if (_passwordController.text.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _PasswordStrengthRow(
                              hasMinLength: _hasMinLength,
                              hasUppercase: _hasUppercase,
                              hasNumber: _hasNumber,
                              hasSpecial: _hasSpecial,
                            ),
                          ],

                          const SizedBox(height: 10),
                          _PasswordField(
                            controller: _confirmPasswordController,
                            label: 'Confirm Password',
                            hint: 'Re-enter your password',
                            obscure: _obscureConfirm,
                            errorText: _confirmPasswordError,
                            onToggle: () => setState(
                                    () => _obscureConfirm = !_obscureConfirm),
                            onChanged: (_) {
                              if (_confirmPasswordError != null) {
                                setState(() => _confirmPasswordError = null);
                              }
                            },
                          ),
                          const SizedBox(height: 18),

                          // ── Create Account button ─────────────────────────
                          Container(
                            width: double.infinity,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [Color(0xFF4F46E5), Color(0xFF6366F1)]),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: const [
                                BoxShadow(
                                    color: Color(0x4D4F46E5),
                                    blurRadius: 12,
                                    offset: Offset(0, 4)),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _isLoading ? null : _handleSignUp,
                                borderRadius: BorderRadius.circular(24),
                                child: Center(
                                  child: _isLoading
                                      ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5))
                                      : const Text('Create Account',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white)),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),
                          const _Divider(label: 'Or sign up with'),
                          const SizedBox(height: 12),

                          // ── Google + Facebook ─────────────────────────────
                          Row(
                            children: [
                              Expanded(
                                child: _GoogleSignupButton(
                                  loading: _googleLoading,
                                  onTap: _handleGoogleSignUp,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _FacebookSignupButton(
                                  loading: _facebookLoading,
                                  onTap: _handleFacebookSignUp,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),
                          const _TermsText(action: 'signing up'),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Bottom Login Link ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account? ',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
                  GestureDetector(
                    onTap: () => Navigator.pushReplacement(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => const LoginScreen(),
                        transitionsBuilder: (_, animation, __, child) =>
                            FadeTransition(opacity: animation, child: child),
                        transitionDuration: const Duration(milliseconds: 200),
                      ),
                    ),
                    child: const Text('Log in',
                        style: TextStyle(
                            color: Color(0xFF4F46E5),
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
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

// ─── Password Strength Row ────────────────────────────────────────────────────
class _PasswordStrengthRow extends StatelessWidget {
  final bool hasMinLength, hasUppercase, hasNumber, hasSpecial;

  const _PasswordStrengthRow({
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
        _Criteria(label: '8+ chars', met: hasMinLength),
        _Criteria(label: 'A-Z', met: hasUppercase),
        _Criteria(label: '0-9', met: hasNumber),
        _Criteria(label: '@#\$!', met: hasSpecial),
      ],
    );
  }
}

class _Criteria extends StatelessWidget {
  final String label;
  final bool met;
  const _Criteria({required this.label, required this.met});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: met ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: met ? const Color(0xFF16A34A) : const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 12,
            color: met ? const Color(0xFF16A34A) : const Color(0xFF9CA3AF),
          ),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: met ? const Color(0xFF16A34A) : const Color(0xFF6B7280))),
        ],
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
      child: const Text('Trouble Sarthi',
          style: TextStyle(
              color: Colors.white,
              fontFamily: 'Saman',
              fontSize: 19,
              fontWeight: FontWeight.bold)),
    );
  }
}

class _LogoBanner extends StatelessWidget {
  const _LogoBanner();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
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
            decoration:
            BoxDecoration(color: Color(0xFF4F46E5), shape: BoxShape.circle),
            child: SizedBox(
              width: 80,
              height: 80,
              child: Center(
                  child: Icon(Icons.verified_user, size: 40, color: Colors.white)),
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

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.inputFormatters,
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
    errorText != null ? const Color(0xFFDC2626) : const Color(0xFFE5E7EB);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
            prefixIcon: Icon(icon, color: const Color(0xFF6B7280), size: 20),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
            const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: errorText != null
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF4F46E5),
                  width: 2),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(errorText!,
                style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
          ),
        ],
      ],
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final bool obscure;
  final VoidCallback onToggle;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.obscure,
    required this.onToggle,
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
    errorText != null ? const Color(0xFFDC2626) : const Color(0xFFE5E7EB);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          obscureText: obscure,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
            prefixIcon: const Icon(Icons.lock_outline,
                color: Color(0xFF6B7280), size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                  obscure ? Icons.visibility_off : Icons.visibility,
                  color: const Color(0xFF6B7280),
                  size: 20),
              onPressed: onToggle,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
            const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: errorText != null
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF4F46E5),
                  width: 2),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(errorText!,
                style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
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
          child: Text(label,
              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
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
          const TextSpan(
              text: 'Terms of Service',
              style: TextStyle(
                  color: Color(0xFF4F46E5), fontWeight: FontWeight.w600)),
          const TextSpan(text: ' and '),
          const TextSpan(
              text: 'Privacy Policy',
              style: TextStyle(
                  color: Color(0xFF4F46E5), fontWeight: FontWeight.w600)),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }
}

// ─── Interactive button base ──────────────────────────────────────────────────
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
  State<_InteractiveSocialButton> createState() =>
      _InteractiveSocialButtonState();
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
              : const [
            BoxShadow(
                color: Color(0x18000000),
                blurRadius: 6,
                offset: Offset(0, 2))
          ],
        ),
        child: widget.child,
      ),
    );
  }
}

// ─── Google button ────────────────────────────────────────────────────────────
class _GoogleSignupButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _GoogleSignupButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _InteractiveSocialButton(
      onTap: loading ? () {} : onTap,
      defaultColor: Colors.white,
      pressedColor: const Color(0xFFF1F3F4),
      borderColor: const Color(0xFFE5E7EB),
      child: loading
          ? const Center(
          child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF4285F4))))
          : const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _GoogleGIcon(),
          SizedBox(width: 6),
          Text('Google',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3C4043))),
        ],
      ),
    );
  }
}

// ─── Facebook button ──────────────────────────────────────────────────────────
class _FacebookSignupButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _FacebookSignupButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _InteractiveSocialButton(
      onTap: loading ? () {} : onTap,
      defaultColor: const Color(0xFF1877F2),
      pressedColor: const Color(0xFF1565C0),
      borderColor: Colors.transparent,
      child: loading
          ? const Center(
          child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white)))
          : const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _FacebookFIcon(),
          SizedBox(width: 6),
          Text('Facebook',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
        ],
      ),
    );
  }
}

// ─── Google G icon ────────────────────────────────────────────────────────────
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

    canvas.drawCircle(center, r * 0.53,
        Paint()..color = Colors.white..style = PaintingStyle.fill);

    final bar = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = r * 0.32
      ..strokeCap = StrokeCap.butt;
    canvas.drawLine(center, Offset(r + r * 0.85, r), bar);
    canvas.drawRect(
      Rect.fromLTWH(r, r - r * 0.18, r, r * 0.18),
      Paint()..color = Colors.white..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Facebook f icon ──────────────────────────────────────────────────────────
class _FacebookFIcon extends StatelessWidget {
  const _FacebookFIcon();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration:
      const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: const Center(
        child: Text('f',
            style: TextStyle(
                color: Color(0xFF1877F2),
                fontSize: 13,
                fontWeight: FontWeight.bold,
                height: 1.1)),
      ),
    );
  }
}