import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trouble_sarthi/screens/location_picker_screen.dart';
import 'package:trouble_sarthi/service/firebase_storage_service.dart';
import 'package:trouble_sarthi/service/image_picker_service.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  File? _pickedImage;
  bool _isSaving = false;
  bool _isLoading = true;

  String? _nameError;
  String? _usernameError;
  String? _phoneError;

  String _uid = '';
  String _existingPhotoUrl = '';
  String _provider = 'email'; // 'email', 'google', 'facebook', 'phone'

  @override
  void initState() {
    super.initState();
    _prefillData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ── Pull existing data from Auth + Firestore ──────────────────────────────
  // Auto-fills name, email, phone from Google/Facebook/Phone auth

  Future<void> _prefillData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _uid = user.uid;
    _existingPhotoUrl = user.photoURL ?? '';

    String name = user.displayName ?? '';
    String email = user.email ?? '';
    String phone = user.phoneNumber ?? '';
    String username = '';

    // Detect provider
    for (final info in user.providerData) {
      if (info.providerId == 'google.com') _provider = 'google';
      if (info.providerId == 'facebook.com') _provider = 'facebook';
      if (info.providerId == 'phone') _provider = 'phone';
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final d = doc.data()!;
        if ((d['fullName'] as String? ?? '').isNotEmpty) name = d['fullName'];
        if ((d['email'] as String? ?? '').isNotEmpty) email = d['email'];
        if ((d['phone'] as String? ?? '').isNotEmpty) phone = d['phone'];
        if ((d['photoUrl'] as String? ?? '').isNotEmpty) {
          _existingPhotoUrl = d['photoUrl'];
        }
        username = d['username'] as String? ?? '';
        if ((d['provider'] as String? ?? '').isNotEmpty) {
          _provider = d['provider'];
        }
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _nameController.text = name;
      _usernameController.text = username;
      _emailController.text = email;
      // Strip leading '+' for display if it's a phone number
      _phoneController.text = phone.startsWith('+91')
          ? phone.replaceFirst('+91', '')
          : phone.replaceFirst('+', '');
      _isLoading = false;
    });
  }

  // ── Image picker ──────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final file = await ImagePickerService.instance.pickWithSourceSheet(context);
    if (file != null && mounted) {
      setState(() => _pickedImage = file);
    }
  }

  // ── Upload photo ──────────────────────────────────────────────────────────

  Future<String?> _uploadPhoto() async {
    if (_pickedImage == null) {
      return _existingPhotoUrl.isNotEmpty ? _existingPhotoUrl : null;
    }
    return await FirebaseStorageService.instance.uploadProfilePhoto(
      uid: _uid,
      file: _pickedImage!,
      onProgress: (p) => print('Upload: ${(p * 100).toStringAsFixed(0)}%'),
    );
  }

  // ── Validate ──────────────────────────────────────────────────────────────

  bool _validate() {
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final phone = _phoneController.text.trim();

    String? nameErr, usernameErr, phoneErr;

    if (name.length < 2) nameErr = 'Please enter your full name';

    if (username.isEmpty) {
      usernameErr = 'Username is required';
    } else if (username.length < 3) {
      usernameErr = 'Username must be at least 3 characters';
    } else if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      usernameErr = 'Only letters, numbers, and underscores';
    }

    if (phone.isEmpty) {
      phoneErr = 'Phone number is required';
    } else if (phone.length < 10) {
      phoneErr = 'Enter a valid 10-digit phone number';
    }

    setState(() {
      _nameError = nameErr;
      _usernameError = usernameErr;
      _phoneError = phoneErr;
    });

    return nameErr == null && usernameErr == null && phoneErr == null;
  }

  // ── Save to Firestore and go to location picker ───────────────────────────

  Future<void> _getStarted() async {
    if (!_validate()) return;

    setState(() => _isSaving = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isSaving = false);
      _snack('Session expired. Please log in again.', isError: true);
      return;
    }

    try {
      final photoUrl = await _uploadPhoto();
      final name = _nameController.text.trim();
      final phone = '+91${_phoneController.text.trim()}';

      await user.updateDisplayName(name);
      if (photoUrl != null) await user.updatePhotoURL(photoUrl);

      final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final doc = await ref.get();
      final ts = FieldValue.serverTimestamp();

      if (doc.exists) {
        await ref.update({
          'fullName': name,
          'username': _usernameController.text.trim().toLowerCase(),
          'email': _emailController.text.trim(),
          'phone': phone,
          if (photoUrl != null) 'photoUrl': photoUrl,
          'locationEnabled': true,
          'profileComplete': true,
          'updatedAt': ts,
        });
      } else {
        await ref.set({
          'uid': user.uid,
          'fullName': name,
          'username': _usernameController.text.trim().toLowerCase(),
          'email': _emailController.text.trim(),
          'phone': phone,
          if (photoUrl != null) 'photoUrl': photoUrl,
          'provider': _provider,
          'locationEnabled': true,
          'profileComplete': true,
          'locationSet': false,
          'createdAt': ts,
          'updatedAt': ts,
        });
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, a, __) => const LocationPickerScreen(),
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 350),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _snack('Failed to save. Please try again.', isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
      isError ? const Color(0xFFDC2626) : const Color(0xFF4F46E5),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
            child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
      );
    }

    final isSocialAuth = _provider == 'google' || _provider == 'facebook';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                          color: Color(0xFFF3F4F6), shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_back,
                          color: Color(0xFF374151), size: 20),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('STEP 3 OF 3',
                          style: TextStyle(
                              color: Color(0xFF4F46E5),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6)),
                      const SizedBox(height: 6),
                      Container(
                        width: 80,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Complete Your Profile',
                        style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            height: 1.2)),
                    const SizedBox(height: 10),
                    const Text(
                      'Help us get to know you better to provide the best assistance when you need it most.',
                      style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                          height: 1.55),
                    ),

                    // ── Social auth banner ────────────────────────────────
                    if (isSocialAuth) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEFBF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: Color(0xFF16A34A), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Name & email auto-filled from ${_provider == 'google' ? 'Google' : 'Facebook'}. Please complete remaining fields.',
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF166534),
                                    height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),

                    // ── Profile photo ─────────────────────────────────────
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 118,
                              height: 118,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: const Color(0xFFD1D5DB), width: 1.5),
                                color: const Color(0xFFF3F4F6),
                                image: _pickedImage != null
                                    ? DecorationImage(
                                    image: FileImage(_pickedImage!),
                                    fit: BoxFit.cover)
                                    : (_existingPhotoUrl.isNotEmpty
                                    ? DecorationImage(
                                    image:
                                    NetworkImage(_existingPhotoUrl),
                                    fit: BoxFit.cover)
                                    : null),
                              ),
                              child: (_pickedImage == null &&
                                  _existingPhotoUrl.isEmpty)
                                  ? Center(
                                  child: Icon(Icons.add_a_photo_outlined,
                                      color: Colors.grey.shade400, size: 36))
                                  : null,
                            ),
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: const BoxDecoration(
                                    color: Color(0xFF4F46E5),
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.edit,
                                    color: Colors.white, size: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Full Name ─────────────────────────────────────────
                    _label('Full Name'),
                    const SizedBox(height: 8),
                    _field(
                      controller: _nameController,
                      hint: 'John Doe',
                      icon: Icons.person_outline,
                      errorText: _nameError,
                      // Editable even for social auth (user may want to change)
                      onChanged: (_) => setState(() => _nameError = null),
                    ),

                    const SizedBox(height: 18),

                    // ── Username ──────────────────────────────────────────
                    _label('Username'),
                    const SizedBox(height: 8),
                    _field(
                      controller: _usernameController,
                      hint: 'john_doe123',
                      icon: Icons.alternate_email,
                      errorText: _usernameError,
                      onChanged: (_) => setState(() => _usernameError = null),
                    ),

                    const SizedBox(height: 18),

                    // ── Email (read-only for social auth, editable for email/phone) ──
                    Row(
                      children: [
                        _label('Email Address'),
                        const SizedBox(width: 8),
                        if (!isSocialAuth)
                          Text('(Optional)',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade500)),
                        if (isSocialAuth)
                          _providerBadge(_provider),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _field(
                      controller: _emailController,
                      hint: 'john@example.com',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      // Read-only if signed in via Google/Facebook (email comes from them)
                      readOnly: isSocialAuth,
                    ),

                    const SizedBox(height: 18),

                    // ── Phone Number ──────────────────────────────────────
                    Row(
                      children: [
                        _label('Phone Number'),
                        if (_provider == 'phone') ...[
                          const SizedBox(width: 8),
                          _providerBadge('phone'),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    _phoneField(),

                    const SizedBox(height: 22),

                    // ── Location info card ────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: const Color(0xFF4F46E5).withOpacity(0.1)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5).withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.location_on_rounded,
                                color: Color(0xFF4F46E5), size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Location Required',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF111827))),
                                SizedBox(height: 5),
                                Text(
                                  "You'll be taken to the location picker next. Trouble Sarthi uses your location to connect you with nearby help instantly.",
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      color: Color(0xFF6B7280),
                                      height: 1.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Get Started button ────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _getStarted,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          disabledBackgroundColor:
                          const Color(0xFF4F46E5).withOpacity(0.6),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                            : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Get Started',
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded,
                                color: Colors.white, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helper widgets ────────────────────────────────────────────────────────

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Color(0xFF111827)),
  );

  Widget _providerBadge(String provider) {
    final isGoogle = provider == 'google';
    final isFacebook = provider == 'facebook';
    final isPhone = provider == 'phone';

    Color bg = isGoogle
        ? const Color(0xFFEFF6FF)
        : isFacebook
        ? const Color(0xFFEFF6FF)
        : const Color(0xFFF0FDF4);
    Color fg = isGoogle
        ? const Color(0xFF1D4ED8)
        : isFacebook
        ? const Color(0xFF1877F2)
        : const Color(0xFF16A34A);
    String label = isGoogle
        ? 'Auto-filled by Google'
        : isFacebook
        ? 'Auto-filled by Facebook'
        : 'Verified';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  Widget _phoneField() {
    final isPhoneAuth = _provider == 'phone';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isPhoneAuth
                ? const Color(0xFFF0FDF4)
                : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: _phoneError != null
                  ? const Color(0xFFDC2626)
                  : isPhoneAuth
                  ? const Color(0xFF16A34A).withOpacity(0.4)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              // Country code prefix
              Container(
                padding: const EdgeInsets.only(left: 16, right: 4),
                child: const Text('+91',
                    style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF374151),
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 4),
              Container(width: 1, height: 24, color: const Color(0xFFD1D5DB)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  readOnly: isPhoneAuth,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  onChanged: (_) => setState(() => _phoneError = null),
                  style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF111827),
                      fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: '9876543210',
                    hintStyle: const TextStyle(
                        color: Color(0xFFADB5BD), fontSize: 15),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 4),
                    suffixIcon: isPhoneAuth
                        ? const Icon(Icons.verified_rounded,
                        color: Color(0xFF16A34A), size: 20)
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
        if (_phoneError != null) ...[
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(_phoneError!,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFFDC2626))),
          ),
        ],
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? errorText,
    ValueChanged<String>? onChanged,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: readOnly
                ? const Color(0xFFEFF6FF)
                : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: errorText != null
                  ? const Color(0xFFDC2626)
                  : readOnly
                  ? const Color(0xFF4F46E5).withOpacity(0.2)
                  : Colors.transparent,
            ),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            onChanged: onChanged,
            readOnly: readOnly,
            style: TextStyle(
                fontSize: 15,
                color: readOnly
                    ? const Color(0xFF4F46E5)
                    : const Color(0xFF111827),
                fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle:
              const TextStyle(color: Color(0xFFADB5BD), fontSize: 15),
              prefixIcon: Icon(icon,
                  color: readOnly
                      ? const Color(0xFF4F46E5)
                      : const Color(0xFFADB5BD),
                  size: 20),
              suffixIcon: readOnly
                  ? const Padding(
                  padding: EdgeInsets.only(right: 14),
                  child: Icon(Icons.lock_outline,
                      color: Color(0xFF4F46E5), size: 16))
                  : null,
              border: InputBorder.none,
              contentPadding:
              const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(errorText,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFFDC2626))),
          ),
        ],
      ],
    );
  }
}