  import 'package:flutter/material.dart';
  import 'package:flutter/services.dart';
  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'complete_profile_screen.dart';
  import 'package:trouble_sarthi/screens/home_screen.dart';

  class OtpVerificationScreen extends StatefulWidget {
    final String phoneNumber;
    final bool isSignUp;

    const OtpVerificationScreen({
      super.key,
      required this.phoneNumber,
      required this.isSignUp,
    });

    @override
    State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
  }

  class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
    final List<TextEditingController> _otpControllers =
    List.generate(6, (_) => TextEditingController());
    final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

    String? _verificationId;
    bool _isLoading = true;
    bool _isSendingOtp = false;
    int _resendSeconds = 60;
    bool _canResend = false;

    @override
    void initState() {
      super.initState();
      _sendOTP();
      _startResendTimer();
    }

    @override
    void dispose() {
      for (final c in _otpControllers) c.dispose();
      for (final f in _focusNodes) f.dispose();
      super.dispose();
    }

    // ── Timer ─────────────────────────────────────────────────────────────────

    void _startResendTimer() {
      setState(() {
        _resendSeconds = 60;
        _canResend = false;
      });
      Future.doWhile(() async {
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return false;
        setState(() {
          _resendSeconds--;
          if (_resendSeconds <= 0) _canResend = true;
        });
        return _resendSeconds > 0;
      });
    }

    // ── Send OTP ──────────────────────────────────────────────────────────────

    Future<void> _sendOTP() async {
      setState(() {
        _isLoading = true;
        _isSendingOtp = true;
      });

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,

        verificationCompleted: (PhoneAuthCredential credential) async {
          await _signInWithCredential(credential);
        },

        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _isSendingOtp = false;
          });
          String msg;
          switch (e.code) {
            case 'invalid-phone-number':
              msg = 'Invalid phone number. Go back and check.';
              break;
            case 'too-many-requests':
              msg = 'Too many attempts. Please try later.';
              break;
            default:
              msg = e.message ?? 'Failed to send OTP. Try again.';
          }
          _showSnackBar(msg, isError: true);
        },

        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _isLoading = false;
            _isSendingOtp = false;
          });
          _showSnackBar('OTP sent to ${widget.phoneNumber}');
        },

        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },

        timeout: const Duration(seconds: 60),
      );
    }

    Future<void> _resendOTP() async {
      for (final c in _otpControllers) c.clear();
      _focusNodes[0].requestFocus();
      _startResendTimer();
      await _sendOTP();
    }

    // ── Verify OTP ────────────────────────────────────────────────────────────

    Future<void> _verifyOTP() async {
      final otp = _otpControllers.map((c) => c.text).join();
      if (otp.length < 6) {
        _showSnackBar('Please enter the complete 6-digit OTP', isError: true);
        return;
      }
      if (_verificationId == null) {
        _showSnackBar('Verification session expired. Resend OTP.', isError: true);
        return;
      }

      setState(() => _isLoading = true);

      try {
        final credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: otp,
        );
        await _signInWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        switch (e.code) {
          case 'invalid-verification-code':
            _showSnackBar('Wrong OTP. Please try again.', isError: true);
            break;
          case 'session-expired':
            _showSnackBar('OTP expired. Please resend.', isError: true);
            setState(() => _canResend = true);
            break;
          default:
            _showSnackBar(e.message ?? 'Verification failed.', isError: true);
        }
      }
    }

    // ── Sign In with Credential ───────────────────────────────────────────────

    Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
      try {
        final result =
        await FirebaseAuth.instance.signInWithCredential(credential);
        final user = result.user;
        if (user == null) throw Exception('Auth failed');

        if (!mounted) return;
        setState(() => _isLoading = false);

        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!mounted) return;

        if (doc.exists && (doc.data()?['profileComplete'] == true)) {
          // ── Existing user with complete profile → Home ────────────────────
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'lastLogin': FieldValue.serverTimestamp()});

          if (!mounted) return;
          _goToHome();
        } else {
          // ── New user OR incomplete profile → CompleteProfileScreen ────────
          // Save basic record so CompleteProfileScreen can prefill phone
          if (!doc.exists) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .set({
              'uid': user.uid,
              'phone': widget.phoneNumber,
              'profileComplete': false,
              'locationSet': false,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }

          if (!mounted) return;
          _goToCompleteProfile();
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showSnackBar('Sign in failed. Please try again.', isError: true);
        }
      }
    }

    // ── Navigation ────────────────────────────────────────────────────────────

    void _goToCompleteProfile() {
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (_, animation, __) => const CompleteProfileScreen(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 350),
        ),
            (route) => false,
      );
    }

    void _goToHome() {
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (_, animation, __) => const HomeScreen(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 350),
        ),
            (route) => false,
      );
    }

    void _showSnackBar(String message, {bool isError = false}) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
          isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      );
    }

    // ── Build ─────────────────────────────────────────────────────────────────

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: const Color(0xFFF0F0F5),
        body: SafeArea(
          child: Column(
            children: [
              // AppBar
              SizedBox(
                height: 44,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: Color(0xFF4F46E5)),
                        onPressed: () => Navigator.pop(context),
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                      ),
                      Expanded(
                        child: Center(
                          child: ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [
                                Color(0xFF7C3FED),
                                Color(0xFF9D6FFF),
                                Color(0xFF6B28EA)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds),
                            child: const Text(
                              'Trouble Sarthi',
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'Saman',
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              ),

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
                          colors: [
                            Colors.white,
                            Color(0xFFF8F7FF),
                            Color(0xFFF3F1FF)
                          ],
                        ),
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4F46E5).withOpacity(0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 6),

                            // Banner
                            Container(
                              width: double.infinity,
                              padding:
                              const EdgeInsets.symmetric(vertical: 28),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFE8E4FF),
                                    Color(0xFFD4CEFF)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    width: 90,
                                    height: 90,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4F46E5),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF4F46E5)
                                              .withOpacity(0.3),
                                          blurRadius: 16,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(Icons.sms_outlined,
                                        size: 44, color: Colors.white),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'OTP VERIFICATION',
                                    style: TextStyle(
                                      color: Color(0xFF4F46E5),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 28),

                            const Text(
                              'Enter OTP',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'We sent a 6-digit code to\n${widget.phoneNumber}',
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF6B7280)),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 32),

                            // 6 OTP Boxes
                            Row(
                              mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                              children: List.generate(6, (i) {
                                return SizedBox(
                                  width: 46,
                                  height: 54,
                                  child: TextField(
                                    controller: _otpControllers[i],
                                    focusNode: _focusNodes[i],
                                    textAlign: TextAlign.center,
                                    keyboardType: TextInputType.number,
                                    maxLength: 1,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1F2937),
                                    ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                    decoration: InputDecoration(
                                      counterText: '',
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding: EdgeInsets.zero,
                                      border: OutlineInputBorder(
                                        borderRadius:
                                        BorderRadius.circular(14),
                                        borderSide: const BorderSide(
                                            color: Color(0xFFE5E7EB)),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                        BorderRadius.circular(14),
                                        borderSide: const BorderSide(
                                            color: Color(0xFFE5E7EB)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                        BorderRadius.circular(14),
                                        borderSide: const BorderSide(
                                            color: Color(0xFF4F46E5),
                                            width: 2),
                                      ),
                                    ),
                                    onChanged: (val) {
                                      if (val.isNotEmpty && i < 5) {
                                        _focusNodes[i + 1].requestFocus();
                                      }
                                      if (val.isEmpty && i > 0) {
                                        _focusNodes[i - 1].requestFocus();
                                      }
                                      final otp = _otpControllers
                                          .map((c) => c.text)
                                          .join();
                                      if (otp.length == 6) _verifyOTP();
                                    },
                                  ),
                                );
                              }),
                            ),

                            const SizedBox(height: 32),

                            // Verify Button
                            Container(
                              width: double.infinity,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF4F46E5),
                                    Color(0xFF6366F1)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF4F46E5)
                                        .withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _isLoading ? null : _verifyOTP,
                                  borderRadius: BorderRadius.circular(24),
                                  child: Center(
                                    child: _isLoading
                                        ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                        : const Text(
                                      'Verify OTP',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Resend
                            _canResend
                                ? GestureDetector(
                              onTap: _resendOTP,
                              child: const Text(
                                'Resend OTP',
                                style: TextStyle(
                                  color: Color(0xFF4F46E5),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                                : Text(
                              'Resend OTP in ${_resendSeconds}s',
                              style: const TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 13,
                              ),
                            ),

                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }