// ignore_for_file: use_build_context_synchronously
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:trouble_sarthi/screens/about_screen.dart';
import 'package:trouble_sarthi/service/firebase_storage_service.dart';
import 'package:trouble_sarthi/service/image_picker_service.dart';
import 'ai_agent_constants.dart';
import 'package:local_auth/local_auth.dart';


// ═══════════════════════════════════════════════════════════════════════════
//  PROFILE COMPLETION CONFIG
// ═══════════════════════════════════════════════════════════════════════════
class _CF {
  final String key, label, hint;
  final IconData icon;
  const _CF(this.key, this.label, this.hint, this.icon);
}

const _kCF = <_CF>[
  _CF('name',             'Full Name',         'Add your full name',         Icons.person_rounded),
  _CF('email',            'Email',             'Add your email address',     Icons.email_rounded),
  _CF('phone',            'Phone Number',      'Add your phone number',      Icons.phone_rounded),
  _CF('photoUrl',         'Profile Photo',     'Add a profile photo',        Icons.photo_camera_rounded),
  _CF('dob',              'Date of Birth',     'Add your date of birth',     Icons.cake_rounded),
  _CF('gender',           'Gender',            'Select your gender',         Icons.wc_rounded),
  _CF('emergencyContact', 'Emergency Contact', 'Add an emergency number',    Icons.emergency_rounded),
  _CF('address',          'Home Address',      'Add your home address',      Icons.home_rounded),
];

String _fv(String key, Map<String, dynamic> d, User? u) {
  switch (key) {
    case 'name':     return d['name']     as String? ?? u?.displayName ?? '';
    case 'email':    return d['email']    as String? ?? u?.email        ?? '';
    case 'phone':    return d['phone']    as String? ?? u?.phoneNumber  ?? '';
    case 'photoUrl': return d['photoUrl'] as String? ?? u?.photoURL     ?? '';
    case 'address':
      final a = d['address'] as Map<String, dynamic>?;
      if (a == null) return '';
      return [a['houseNo'], a['building'], a['street'], a['city']]
          .where((v) => v != null && (v as String).isNotEmpty).join(', ');
    default:         return d[key]?.toString() ?? '';
  }
}

int _pct(Map<String, dynamic> d, User? u) {
  int filled = 0;
  for (final f in _kCF) { if (_fv(f.key, d, u).isNotEmpty) filled++; }
  return ((filled / _kCF.length) * 100).round();
}

List<_CF> _pending(Map<String, dynamic> d, User? u) =>
    _kCF.where((f) => _fv(f.key, d, u).isEmpty).toList();

// ═══════════════════════════════════════════════════════════════════════════
//  PROFILE SCREEN
// ═══════════════════════════════════════════════════════════════════════════
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid  = user?.uid ?? '';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FB),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
          builder: (ctx, snap) {
            final data    = snap.data?.data() as Map<String, dynamic>? ?? {};
            final name    = _fv('name',     data, user);
            final email   = _fv('email',    data, user);
            final phone   = _fv('phone',    data, user);
            final photo   = _fv('photoUrl', data, user);
            final pct     = _pct(data, user);
            final pending = _pending(data, user);

            return CustomScrollView(
              physics: const ClampingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _GradientHeader(
                    name: name, email: email, phone: phone,
                    photoUrl: photo.isNotEmpty ? photo : null,
                    pct: pct, pending: pending, data: data, user: user,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _label('MY ACCOUNT'),
                      const SizedBox(height: 12),
                      _GMenu(
                        colors: const [Color(0xFF1E0640), Color(0xFF3B0764), Color(0xFF7C3AED)],
                        items: [
                          _GItem(Icons.person_rounded, 'Edit Profile', 'Name, photo, DOB & more',
                                  () => _sheet(ctx, EditProfileSheet(data: data, user: user))),
                          _GItem(Icons.lock_rounded, 'Change Password', 'Update your credentials',
                                  () => _sheet(ctx, const ChangePasswordSheet())),
                          _GItem(Icons.location_on_rounded, 'Saved Addresses', 'Home & work locations',
                              isLast: true,
                                  () => _sheet(ctx, SavedAddressesSheet(data: data, uid: uid))),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _label('SERVICES'),
                      const SizedBox(height: 12),
                      _GMenu(
                        colors: const [Color(0xFF0C4A6E), Color(0xFF0891B2), Color(0xFF22D3EE)],
                        items: [
                          _GItem(Icons.history_rounded, 'Activity', 'Your bookings & history',
                                  () => _push(ctx, const ActivityScreen())),
                          _GItem(Icons.receipt_long_rounded, 'Payments', 'Cash & UPI payment history',
                              isLast: true,
                                  () => _push(ctx, const PaymentsScreen())),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _label('SAFETY & SUPPORT'),
                      const SizedBox(height: 12),
                      _GMenu(
                        colors: const [Color(0xFF064E3B), Color(0xFF059669), Color(0xFF6EE7B7)],
                        items: [
                          _GItem(Icons.shield_rounded, 'Trust & Safety', 'Your trust score & reports',
                                  () => _push(ctx, const AboutScreen())),
                          _GItem(Icons.help_rounded, 'Support', 'Help center & contact us',
                              isLast: true,
                                  () => _push(ctx, const SupportScreen())),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Center(
                        child: Text('Version 2.4.1 (Indigo)',
                            style: const TextStyle(fontSize: 11, color: Color(0xFFB0B8CC))),
                      ),
                      const SizedBox(height: 100),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(t, style: const TextStyle(fontSize: 10,
        fontWeight: FontWeight.bold, color: Color(0xFF9CA3AF), letterSpacing: 1.4)),
  );

  void _push(BuildContext ctx, Widget page) =>
      Navigator.push(ctx, MaterialPageRoute(builder: (_) => page));

  void _sheet(BuildContext ctx, Widget sheet) =>
      showModalBottomSheet(context: ctx, isScrollControlled: true,
          backgroundColor: Colors.transparent, useSafeArea: true,
          builder: (_) => sheet);
}

// ═══════════════════════════════════════════════════════════════════════════
//  GRADIENT HEADER
// ═══════════════════════════════════════════════════════════════════════════
class _GradientHeader extends StatelessWidget {
  final String name, email, phone;
  final String? photoUrl;
  final int pct;
  final List<_CF> pending;
  final Map<String, dynamic> data;
  final User? user;

  const _GradientHeader({
    required this.name, required this.email, required this.phone,
    required this.photoUrl, required this.pct, required this.pending,
    required this.data, required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF1E0640), Color(0xFF3B0764), Color(0xFF5B21B6)],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Row(children: [
                    const Text('Profile', style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const AppSettingsScreen())),
                      child: Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: const Icon(Icons.settings_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),
                Stack(children: [
                  Container(
                    width: 96, height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle, color: const Color(0xFFEDE9FE),
                      border: Border.all(color: Colors.white.withOpacity(0.6), width: 3),
                      boxShadow: [BoxShadow(
                          color: const Color(0xFF7C3AED).withOpacity(0.4),
                          blurRadius: 20, offset: const Offset(0, 6))],
                      image: photoUrl != null
                          ? DecorationImage(image: NetworkImage(photoUrl!), fit: BoxFit.cover)
                          : null,
                    ),
                    child: photoUrl == null
                        ? Center(child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'U',
                        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold,
                            color: Color(0xFF5B21B6))))
                        : null,
                  ),
                  Positioned(
                    bottom: 2, right: 2,
                    child: GestureDetector(
                      onTap: () => showModalBottomSheet(
                        context: context, isScrollControlled: true,
                        backgroundColor: Colors.transparent, useSafeArea: true,
                        builder: (_) => EditProfileSheet(data: data, user: user),
                      ),
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.edit_rounded, color: Colors.white, size: 13),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Text(name.isNotEmpty ? name : 'Your Name',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 4),
                if (email.isNotEmpty)
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.email_outlined, size: 12, color: Colors.white.withOpacity(0.65)),
                    const SizedBox(width: 4),
                    Text(email, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.75))),
                  ]),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.phone_outlined, size: 12, color: Colors.white.withOpacity(0.65)),
                    const SizedBox(width: 4),
                    Text(phone, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.75))),
                  ]),
                ],
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () {
                    if (pending.isNotEmpty) {
                      showModalBottomSheet(
                        context: context, backgroundColor: Colors.transparent,
                        useSafeArea: true, isScrollControlled: true,
                        builder: (_) => _PendingSheet(pending: pending, data: data, user: user),
                      );
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.18)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.shield_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        const Text('Profile Completion',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                        const Spacer(),
                        Text('$pct%',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                        if (pct < 100) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10)),
                            child: const Text("What's missing?",
                                style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: pct / 100, minHeight: 7,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(
                              pct == 100 ? const Color(0xFF22C55E) : const Color(0xFFA78BFA)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        pct == 100
                            ? '✓ Profile complete — you\'re all set!'
                            : '${pending.length} field${pending.length == 1 ? '' : 's'} pending — tap to see what\'s missing',
                        style: TextStyle(
                            fontSize: 11,
                            color: pct == 100 ? const Color(0xFF86EFAC) : Colors.white.withOpacity(0.75),
                            height: 1.3),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            height: 26,
            decoration: const BoxDecoration(
              color: Color(0xFFF4F6FB),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(28), topRight: Radius.circular(28),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  PENDING FIELDS SHEET
// ═══════════════════════════════════════════════════════════════════════════
class _PendingSheet extends StatelessWidget {
  final List<_CF> pending;
  final Map<String, dynamic> data;
  final User? user;
  const _PendingSheet({required this.pending, required this.data, required this.user});

  void _navigateTo(BuildContext context, _CF field) {
    Navigator.pop(context);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!context.mounted) return;
      if (field.key == 'address') {
        final uid = user?.uid ?? '';
        showModalBottomSheet(
          context: context, isScrollControlled: true,
          backgroundColor: Colors.transparent, useSafeArea: true,
          builder: (_) => SavedAddressesSheet(data: data, uid: uid),
        );
        return;
      }
      showModalBottomSheet(
        context: context, isScrollControlled: true,
        backgroundColor: Colors.transparent, useSafeArea: true,
        builder: (_) => EditProfileSheet(data: data, user: user),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(margin: const EdgeInsets.symmetric(vertical: 12),
            width: 42, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2))),
        Container(
          width: 52, height: 52,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF5B21B6), Color(0xFF7C3AED)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.checklist_rounded, color: Colors.white, size: 26),
        ),
        const SizedBox(height: 14),
        const Text('Complete Your Profile',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
        const SizedBox(height: 6),
        Text('${pending.length} item${pending.length == 1 ? '' : 's'} still missing — tap to fill in',
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        const SizedBox(height: 20),
        ...pending.map((f) => GestureDetector(
          onTap: () => _navigateTo(context, f),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEDE9FE)),
            ),
            child: Row(children: [
              Container(width: 36, height: 36,
                  decoration: BoxDecoration(color: const Color(0xFFEDE9FE),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(f.icon, color: const Color(0xFF7C3AED), size: 18)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(f.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937))),
                Text(f.hint, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Add →', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                    color: Color(0xFF7C3AED))),
              ),
            ]),
          ),
        )),
        const SizedBox(height: 6),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  GRADIENT MENU + ITEM (unchanged - optimised StatelessWidget)
// ═══════════════════════════════════════════════════════════════════════════
class _GMenu extends StatelessWidget {
  final List<Color> colors;
  final List<_GItem> items;
  const _GMenu({required this.colors, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors,
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: colors[1].withOpacity(0.35),
            blurRadius: 16, offset: const Offset(0, 5))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(children: items),
      ),
    );
  }
}

class _GItem extends StatelessWidget {
  final IconData icon;
  final String label, subtitle;
  final VoidCallback onTap;
  final bool isLast;
  const _GItem(this.icon, this.label, this.subtitle, this.onTap, {this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white.withOpacity(0.12),
        highlightColor: Colors.white.withOpacity(0.08),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          decoration: BoxDecoration(
            border: isLast ? null
                : Border(bottom: BorderSide(color: Colors.white.withOpacity(0.15))),
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 14,
                  fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.72))),
            ])),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.60), size: 20),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  EDIT PROFILE SHEET
// ═══════════════════════════════════════════════════════════════════════════
class EditProfileSheet extends StatefulWidget {
  final Map<String, dynamic> data;
  final User? user;
  const EditProfileSheet({super.key, required this.data, required this.user});

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  final _nameCtrl      = TextEditingController();
  final _phoneCtrl     = TextEditingController();
  final _dobCtrl       = TextEditingController();
  final _emergencyCtrl = TextEditingController();

  String? _gender;
  bool _loading  = true;
  bool _saving   = false;
  bool _saved    = false;

  File?   _pickedImage;
  String  _existingPhotoUrl = '';
  bool    _uploadingPhoto   = false;
  double  _uploadProgress   = 0.0;

  String? _nameErr, _phoneErr, _emergencyErr;

  @override
  void initState() {
    super.initState();
    _fetchAndFill();
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose();
    _dobCtrl.dispose(); _emergencyCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAndFill() async {
    final uid = widget.user?.uid ?? '';
    if (uid.isEmpty) { setState(() => _loading = false); return; }
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final d = snap.data() ?? {};
      final u = widget.user;
      _nameCtrl.text      = d['name']            as String? ?? u?.displayName ?? '';
      _phoneCtrl.text     = d['phone']            as String? ?? u?.phoneNumber  ?? '';
      _dobCtrl.text       = d['dob']              as String? ?? '';
      _emergencyCtrl.text = d['emergencyContact'] as String? ?? '';
      _gender             = d['gender']            as String?;
      _existingPhotoUrl   = (d['photoUrl'] as String? ?? '').isNotEmpty
          ? d['photoUrl'] as String : u?.photoURL ?? '';
    } catch (_) {
      final d = widget.data; final u = widget.user;
      _nameCtrl.text      = d['name']            as String? ?? u?.displayName ?? '';
      _phoneCtrl.text     = d['phone']            as String? ?? u?.phoneNumber  ?? '';
      _dobCtrl.text       = d['dob']              as String? ?? '';
      _emergencyCtrl.text = d['emergencyContact'] as String? ?? '';
      _gender             = d['gender']            as String?;
      _existingPhotoUrl   = d['photoUrl']          as String? ?? u?.photoURL ?? '';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickPhoto() async {
    final file = await ImagePickerService.instance.pickWithSourceSheet(context);
    if (file != null && mounted) {
      setState(() { _pickedImage = file; _uploadingPhoto = false; _uploadProgress = 0.0; });
    }
  }

  Future<String?> _uploadPhotoAndGetUrl() async {
    if (_pickedImage == null) return _existingPhotoUrl.isNotEmpty ? _existingPhotoUrl : null;
    final uid = widget.user?.uid ?? '';
    if (uid.isEmpty) return null;
    setState(() { _uploadingPhoto = true; _uploadProgress = 0.0; });
    try {
      final url = await FirebaseStorageService.instance.uploadProfilePhoto(
        uid: uid, file: _pickedImage!,
        onProgress: (p) { if (mounted) setState(() => _uploadProgress = p); },
      );
      if (mounted) setState(() => _uploadingPhoto = false);
      if (url == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Photo upload failed. Profile saved without new photo.'),
          backgroundColor: Color(0xFFD97706),
        ));
        return _existingPhotoUrl.isNotEmpty ? _existingPhotoUrl : null;
      }
      return url;
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Photo upload error: $e'), backgroundColor: const Color(0xFFDC2626)));
      }
      return _existingPhotoUrl.isNotEmpty ? _existingPhotoUrl : null;
    }
  }

  bool _validate() {
    bool ok = true;
    setState(() {
      _nameErr = null; _phoneErr = null; _emergencyErr = null;
      if (_nameCtrl.text.trim().isEmpty) {
        _nameErr = 'Full name is required'; ok = false;
      } else if (_nameCtrl.text.trim().length < 2) {
        _nameErr = 'Name must be at least 2 characters'; ok = false;
      }
      final phoneRaw = _phoneCtrl.text.trim().replaceAll(RegExp(r'[\s\-\+]'), '');
      if (phoneRaw.isNotEmpty && !RegExp(r'^\d{10,13}$').hasMatch(phoneRaw)) {
        _phoneErr = 'Enter a valid 10-digit phone number'; ok = false;
      }
      final emRaw = _emergencyCtrl.text.trim().replaceAll(RegExp(r'[\s\-\+]'), '');
      if (emRaw.isNotEmpty && !RegExp(r'^\d{10,13}$').hasMatch(emRaw)) {
        _emergencyErr = 'Enter a valid 10-digit number'; ok = false;
      }
    });
    return ok;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _saving = true);
    try {
      final uid  = widget.user?.uid ?? '';
      final name = _nameCtrl.text.trim();
      final photoUrl = await _uploadPhotoAndGetUrl();
      final updateData = <String, dynamic>{
        'name':             name,
        'phone':            _phoneCtrl.text.trim(),
        'dob':              _dobCtrl.text.trim(),
        'emergencyContact': _emergencyCtrl.text.trim(),
        'updatedAt':        FieldValue.serverTimestamp(),
      };
      if (_gender != null) updateData['gender'] = _gender;
      if (photoUrl != null && photoUrl.isNotEmpty) updateData['photoUrl'] = photoUrl;
      await FirebaseFirestore.instance.collection('users').doc(uid)
          .set(updateData, SetOptions(merge: true));
      if (widget.user != null) {
        if (name.isNotEmpty) await widget.user!.updateDisplayName(name);
        if (photoUrl != null && photoUrl.isNotEmpty) await widget.user!.updatePhotoURL(photoUrl);
        await widget.user!.reload();
      }
      if (mounted) {
        setState(() { _saving = false; _saved = true; });
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) Navigator.pop(context);
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.message ?? 'Failed to save. Please try again.'),
            backgroundColor: const Color(0xFFDC2626)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Unexpected error: $e'), backgroundColor: const Color(0xFFDC2626)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 28, left: 24, right: 24),
      child: _loading
          ? const Padding(padding: EdgeInsets.symmetric(vertical: 60),
          child: Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED))))
          : SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(margin: const EdgeInsets.symmetric(vertical: 12),
              width: 42, height: 4, decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)))),
          Row(children: [
            Container(width: 46, height: 46,
                decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF5B21B6), Color(0xFF7C3AED)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(13)),
                child: const Icon(Icons.person_rounded, color: Colors.white, size: 24)),
            const SizedBox(width: 14),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Edit Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937))),
              Text('Changes save directly to your account',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            ]),
          ]),
          const SizedBox(height: 20),
          if (_saved)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF059669).withOpacity(0.30))),
              child: const Row(children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 20),
                SizedBox(width: 10),
                Text('Profile updated successfully!',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF065F46))),
              ]),
            ),
          Center(
            child: GestureDetector(
              onTap: (_saving || _saved) ? null : _pickPhoto,
              child: Stack(clipBehavior: Clip.none, children: [
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, color: const Color(0xFFEDE9FE),
                    border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.30), width: 2.5),
                    image: _pickedImage != null
                        ? DecorationImage(image: FileImage(_pickedImage!), fit: BoxFit.cover)
                        : _existingPhotoUrl.isNotEmpty
                        ? DecorationImage(image: NetworkImage(_existingPhotoUrl), fit: BoxFit.cover)
                        : null,
                  ),
                  child: (_pickedImage == null && _existingPhotoUrl.isEmpty)
                      ? const Center(child: Icon(Icons.person_rounded, color: Color(0xFF7C3AED), size: 42))
                      : null,
                ),
                if (_uploadingPhoto)
                  Positioned.fill(child: Container(
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withOpacity(0.45)),
                    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(width: 32, height: 32, child: CircularProgressIndicator(
                          value: _uploadProgress, color: Colors.white, strokeWidth: 3)),
                      const SizedBox(height: 4),
                      Text('${(_uploadProgress * 100).toInt()}%',
                          style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                    ])),
                  )),
                if (!_uploadingPhoto)
                  Positioned(bottom: 2, right: 2, child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF5B21B6), Color(0xFF7C3AED)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight),
                        shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                  )),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          const Center(child: Text('Tap to change photo',
              style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)))),
          const SizedBox(height: 18),
          _infoRow(icon: Icons.email_rounded, label: 'Email Address',
              value: widget.user?.email ?? widget.data['email'] as String? ?? '—',
              note: 'Contact support to change your email'),
          const SizedBox(height: 14),
          _field(label: 'Full Name', controller: _nameCtrl, icon: Icons.person_rounded,
              hint: 'Your full name', kb: TextInputType.name, error: _nameErr,
              onChanged: (_) { if (_nameErr != null) setState(() => _nameErr = null); }),
          _field(label: 'Phone Number', controller: _phoneCtrl, icon: Icons.phone_rounded,
              hint: '+91 XXXXX XXXXX', kb: TextInputType.phone, error: _phoneErr,
              onChanged: (_) { if (_phoneErr != null) setState(() => _phoneErr = null); }),
          _field(label: 'Date of Birth', controller: _dobCtrl, icon: Icons.cake_rounded,
            hint: 'e.g. 15 Aug 1998', kb: TextInputType.datetime, readOnly: true,
            onTap: () async {
              DateTime initial = DateTime(2000);
              try {
                if (_dobCtrl.text.isNotEmpty) {
                  const months = {'Jan':1,'Feb':2,'Mar':3,'Apr':4,'May':5,'Jun':6,
                    'Jul':7,'Aug':8,'Sep':9,'Oct':10,'Nov':11,'Dec':12};
                  final parts = _dobCtrl.text.split(' ');
                  if (parts.length == 3) {
                    initial = DateTime(int.parse(parts[2]), months[parts[1]] ?? 1, int.parse(parts[0]));
                  }
                }
              } catch (_) {}
              final picked = await showDatePicker(
                context: context, initialDate: initial,
                firstDate: DateTime(1920), lastDate: DateTime.now(),
                builder: (ctx, child) => Theme(
                    data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(
                        primary: Color(0xFF7C3AED), onPrimary: Colors.white)), child: child!),
              );
              if (picked != null) {
                const m = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
                setState(() => _dobCtrl.text = '${picked.day} ${m[picked.month]} ${picked.year}');
              }
            },
          ),
          _field(label: 'Emergency Contact', controller: _emergencyCtrl,
              icon: Icons.emergency_rounded, hint: 'Emergency phone number',
              kb: TextInputType.phone, error: _emergencyErr,
              onChanged: (_) { if (_emergencyErr != null) setState(() => _emergencyErr = null); }),
          const Text('Gender', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: Color(0xFF374151))),
          const SizedBox(height: 8),
          Row(children: ['Male', 'Female', 'Other'].map((g) {
            final selected = _gender == g;
            return Expanded(child: GestureDetector(
              onTap: () => setState(() => _gender = g),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                    color: selected ? const Color(0xFF7C3AED) : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: selected ? const Color(0xFF7C3AED) : const Color(0xFFE5E7EB))),
                child: Text(g, textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : const Color(0xFF6B7280))),
              ),
            ));
          }).toList()),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: (_saving || _saved) ? null : _save,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  disabledBackgroundColor: _saved ? const Color(0xFF059669) : const Color(0xFFE5E7EB),
                  elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: _saving
                  ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_saved ? '✓ Saved!' : 'Save Changes',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _infoRow({required IconData icon, required String label, required String value, required String note}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Row(children: [
        Icon(icon, color: const Color(0xFF9CA3AF), size: 18),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF9CA3AF))),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
          const SizedBox(height: 2),
          Text(note, style: const TextStyle(fontSize: 10, color: Color(0xFFB0B8CC))),
        ])),
        const Icon(Icons.lock_outline_rounded, color: Color(0xFFD1D5DB), size: 16),
      ]),
    );
  }

  Widget _field({required String label, required TextEditingController controller,
    required IconData icon, required String hint, required TextInputType kb,
    String? error, bool readOnly = false, VoidCallback? onTap, ValueChanged<String>? onChanged}) {
    final hasError = error != null && error.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
        const SizedBox(height: 6),
        TextField(
          controller: controller, keyboardType: kb, readOnly: readOnly,
          onTap: onTap, onChanged: onChanged,
          textCapitalization: kb == TextInputType.name ? TextCapitalization.words : TextCapitalization.none,
          style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
          decoration: InputDecoration(
            hintText: hint, hintStyle: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 13),
            prefixIcon: Icon(icon, color: hasError ? const Color(0xFFDC2626) : const Color(0xFF7C3AED), size: 18),
            filled: true, fillColor: hasError ? const Color(0xFFFEF2F2) : const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            errorText: error, errorStyle: const TextStyle(fontSize: 11, color: Color(0xFFDC2626)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: hasError ? const Color(0xFFDC2626) : const Color(0xFFE5E7EB))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                    color: hasError ? const Color(0xFFDC2626) : const Color(0xFF7C3AED), width: 1.5)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFDC2626))),
            focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5)),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  CHANGE PASSWORD SHEET
// ═══════════════════════════════════════════════════════════════════════════
class ChangePasswordSheet extends StatefulWidget {
  const ChangePasswordSheet({super.key});
  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  final _curCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _conCtrl = TextEditingController();
  bool _showCur = false, _showNew = false, _showCon = false;
  int _stage = 0;
  bool _verifying = false, _curError = false;
  String _curErrMsg = '';
  bool _submitting = false;

  static const _minLen = 8;
  bool get _hasMinLen  => _newCtrl.text.length >= _minLen;
  bool get _hasUpper   => _newCtrl.text.contains(RegExp(r'[A-Z]'));
  bool get _hasDigit   => _newCtrl.text.contains(RegExp(r'[0-9]'));
  bool get _hasSpecial => _newCtrl.text.contains(RegExp(r'[!@#\$%^&*()_\-+=]'));
  bool get _newValid   => _hasMinLen && _hasUpper && _hasDigit;
  bool get _conMatch   => _conCtrl.text.isNotEmpty && _conCtrl.text == _newCtrl.text;
  bool get _conMismatch => _conCtrl.text.isNotEmpty && _conCtrl.text != _newCtrl.text;

  int get _strength {
    int s = 0;
    if (_hasMinLen) s++; if (_hasUpper) s++;
    if (_hasDigit) s++; if (_hasSpecial) s++;
    return s;
  }

  @override
  void dispose() { _curCtrl.dispose(); _newCtrl.dispose(); _conCtrl.dispose(); super.dispose(); }

  Future<void> _verifyCurrent() async {
    if (_curCtrl.text.isEmpty) return;
    setState(() { _verifying = true; _curError = false; _curErrMsg = ''; });
    try {
      final u    = FirebaseAuth.instance.currentUser!;
      final cred = EmailAuthProvider.credential(email: u.email!, password: _curCtrl.text.trim());
      await u.reauthenticateWithCredential(cred);
      if (mounted) setState(() { _stage = 1; _verifying = false; });
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() {
        _verifying = false; _curError = true;
        _curErrMsg = e.code == 'wrong-password' ? 'Incorrect password. Please try again.'
            : e.code == 'too-many-requests' ? 'Too many attempts. Please wait and try again.'
            : e.message ?? 'Verification failed.';
      });
    }
  }

  void _advanceToConfirm() { if (!_newValid) return; setState(() => _stage = 2); }

  Future<void> _updatePassword() async {
    if (!_conMatch) return;
    setState(() => _submitting = true);
    try {
      await FirebaseAuth.instance.currentUser!.updatePassword(_newCtrl.text.trim());
      if (mounted) setState(() { _stage = 3; _submitting = false; });
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message ?? 'Error updating password')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 28,
          left: 24, right: 24),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(margin: const EdgeInsets.symmetric(vertical: 12),
              width: 42, height: 4, decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)))),
          Row(children: [
            Container(width: 46, height: 46,
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: _stage == 3
                            ? [const Color(0xFF059669), const Color(0xFF0D9488)]
                            : [const Color(0xFF1E40AF), const Color(0xFF3B82F6)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(13)),
                child: Icon(_stage == 3 ? Icons.check_rounded : Icons.lock_rounded,
                    color: Colors.white, size: 24)),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_stage == 3 ? 'Password Updated!' : 'Change Password',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
              Text(_stage == 0 ? 'First, verify it\'s really you'
                  : _stage == 1 ? 'Choose a strong new password'
                  : _stage == 2 ? 'Confirm your new password' : 'Your account is now secured',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            ]),
          ]),
          const SizedBox(height: 20),
          if (_stage < 3) Row(children: List.generate(3, (i) {
            final active = i == _stage; final complete = i < _stage;
            return Expanded(child: Container(margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                height: 4, decoration: BoxDecoration(
                    color: complete ? const Color(0xFF059669)
                        : active ? const Color(0xFF1E40AF) : const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2))));
          })),
          if (_stage < 3) const SizedBox(height: 6),
          if (_stage < 3) Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _stageLabel('Verify', 0), _stageLabel('New', 1), _stageLabel('Confirm', 2),
          ]),
          const SizedBox(height: 24),

          if (_stage == 0) ...[
            _fieldLabel('Current Password'),
            const SizedBox(height: 6),
            TextField(
              controller: _curCtrl, obscureText: !_showCur,
              onChanged: (_) { if (_curError) setState(() => _curError = false); },
              style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
              decoration: InputDecoration(
                hintText: '••••••••', hintStyle: const TextStyle(color: Color(0xFFD1D5DB)),
                prefixIcon: Icon(Icons.lock_outline_rounded,
                    color: _curError ? const Color(0xFFDC2626) : const Color(0xFF1E40AF), size: 18),
                suffixIcon: IconButton(
                    icon: Icon(_showCur ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: const Color(0xFF9CA3AF), size: 18),
                    onPressed: () => setState(() => _showCur = !_showCur)),
                filled: true, fillColor: _curError ? const Color(0xFFFEF2F2) : const Color(0xFFF9FAFB),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: _curError ? const Color(0xFFDC2626) : const Color(0xFFE5E7EB))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: _curError ? const Color(0xFFDC2626) : const Color(0xFF1E40AF), width: 1.5)),
              ),
            ),
            if (_curError) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 14),
                const SizedBox(width: 6),
                Expanded(child: Text(_curErrMsg,
                    style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)))),
              ]),
            ],
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: (_verifying || _curCtrl.text.isEmpty) ? null : _verifyCurrent,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E40AF),
                    disabledBackgroundColor: const Color(0xFFE5E7EB), elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: _verifying
                    ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Verify Password', style: TextStyle(fontSize: 15,
                    fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],

          if (_stage == 1) ...[
            _VerifiedChip(text: 'Current password verified ✓'),
            const SizedBox(height: 16),
            _fieldLabel('New Password'),
            const SizedBox(height: 6),
            TextField(
              controller: _newCtrl, obscureText: !_showNew,
              onChanged: (_) => setState(() {}), autofocus: true,
              style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
              decoration: InputDecoration(
                hintText: '••••••••', hintStyle: const TextStyle(color: Color(0xFFD1D5DB)),
                prefixIcon: const Icon(Icons.lock_rounded, color: Color(0xFF1E40AF), size: 18),
                suffixIcon: IconButton(
                    icon: Icon(_showNew ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: const Color(0xFF9CA3AF), size: 18),
                    onPressed: () => setState(() => _showNew = !_showNew)),
                filled: true, fillColor: const Color(0xFFF9FAFB),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF1E40AF), width: 1.5)),
              ),
            ),
            const SizedBox(height: 14),
            if (_newCtrl.text.isNotEmpty) ...[
              Row(children: List.generate(4, (i) => Expanded(
                child: Container(margin: EdgeInsets.only(right: i < 3 ? 5 : 0), height: 5,
                    decoration: BoxDecoration(
                        color: i < _strength
                            ? [const Color(0xFFDC2626), const Color(0xFFF59E0B),
                          const Color(0xFF3B82F6), const Color(0xFF059669)][i]
                            : const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(3))),
              ))),
              const SizedBox(height: 6),
              Text(['', 'Weak', 'Fair', 'Good', 'Strong password ✓'][_strength],
                  style: TextStyle(fontSize: 11,
                      color: [Colors.grey, const Color(0xFFDC2626), const Color(0xFFF59E0B),
                        const Color(0xFF3B82F6), const Color(0xFF059669)][_strength])),
              const SizedBox(height: 14),
            ],
            _CheckRow(label: 'At least $_minLen characters', done: _hasMinLen),
            const SizedBox(height: 6),
            _CheckRow(label: 'At least one uppercase letter (A–Z)', done: _hasUpper),
            const SizedBox(height: 6),
            _CheckRow(label: 'At least one number (0–9)', done: _hasDigit),
            const SizedBox(height: 6),
            _CheckRow(label: 'Symbol like !@#\$ (optional but recommended)', done: _hasSpecial, optional: true),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: _newValid ? _advanceToConfirm : null,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E40AF),
                    disabledBackgroundColor: const Color(0xFFE5E7EB), elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: Text(_newValid ? 'Continue →' : 'Meet all requirements to continue',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                        color: _newValid ? Colors.white : const Color(0xFF9CA3AF))),
              ),
            ),
          ],

          if (_stage == 2) ...[
            _VerifiedChip(text: 'New password validated ✓'),
            const SizedBox(height: 16),
            _fieldLabel('Confirm New Password'),
            const SizedBox(height: 6),
            TextField(
              controller: _conCtrl, obscureText: !_showCon,
              onChanged: (_) => setState(() {}), autofocus: true,
              style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
              decoration: InputDecoration(
                hintText: '••••••••', hintStyle: const TextStyle(color: Color(0xFFD1D5DB)),
                prefixIcon: Icon(Icons.lock_reset_rounded,
                    color: _conMismatch ? const Color(0xFFDC2626)
                        : _conMatch ? const Color(0xFF059669) : const Color(0xFF1E40AF), size: 18),
                suffixIcon: _conCtrl.text.isEmpty
                    ? IconButton(
                    icon: Icon(_showCon ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: const Color(0xFF9CA3AF), size: 18),
                    onPressed: () => setState(() => _showCon = !_showCon))
                    : Icon(_conMatch ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: _conMatch ? const Color(0xFF059669) : const Color(0xFFDC2626), size: 20),
                filled: true,
                fillColor: _conMismatch ? const Color(0xFFFEF2F2)
                    : _conMatch ? const Color(0xFFF0FDF4) : const Color(0xFFF9FAFB),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: _conMismatch ? const Color(0xFFDC2626)
                        : _conMatch ? const Color(0xFF059669) : const Color(0xFFE5E7EB))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: _conMismatch ? const Color(0xFFDC2626)
                            : _conMatch ? const Color(0xFF059669) : const Color(0xFF1E40AF),
                        width: 1.5)),
              ),
            ),
            const SizedBox(height: 10),
            if (_conCtrl.text.isNotEmpty)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _conMatch
                    ? _inlineMsg(Icons.check_circle_rounded, 'Passwords match!',
                    const Color(0xFF059669), key: const ValueKey('match'))
                    : _inlineMsg(Icons.cancel_rounded, 'Passwords do not match yet',
                    const Color(0xFFDC2626), key: const ValueKey('mismatch')),
              ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => setState(() { _stage = 1; _conCtrl.clear(); }),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFE5E7EB)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('← Back', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
              )),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: ElevatedButton(
                onPressed: (_conMatch && !_submitting) ? _updatePassword : null,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E40AF),
                    disabledBackgroundColor: const Color(0xFFE5E7EB), elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _submitting
                    ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Update Password', style: TextStyle(fontSize: 14,
                    fontWeight: FontWeight.bold, color: Colors.white)),
              )),
            ]),
          ],

          if (_stage == 3) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF059669).withOpacity(0.20))),
              child: Column(children: [
                Container(width: 64, height: 64,
                    decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFF0D9488)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: const Color(0xFF059669).withOpacity(0.30),
                            blurRadius: 16, offset: const Offset(0, 4))]),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 34)),
                const SizedBox(height: 14),
                const Text('Password Changed Successfully!', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF065F46))),
                const SizedBox(height: 8),
                const Text('Your account is now secured with your new password.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Color(0xFF374151), height: 1.5)),
              ]),
            ),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F2937),
                    elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: const Text('Done', style: TextStyle(fontSize: 15,
                    fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _stageLabel(String t, int s) => Text(t, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold,
      color: s < _stage ? const Color(0xFF059669)
          : s == _stage ? const Color(0xFF1E40AF) : const Color(0xFFB0B8CC)));

  Widget _fieldLabel(String t) => Text(t, style: const TextStyle(
      fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)));

  Widget _inlineMsg(IconData icon, String msg, Color c, {Key? key}) =>
      Row(key: key, children: [
        Icon(icon, color: c, size: 14), const SizedBox(width: 6),
        Text(msg, style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w500)),
      ]);
}

class _VerifiedChip extends StatelessWidget {
  final String text;
  const _VerifiedChip({required this.text});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF059669).withOpacity(0.25))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 16),
      const SizedBox(width: 8),
      Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF065F46))),
    ]),
  );
}

class _CheckRow extends StatelessWidget {
  final String label; final bool done, optional;
  const _CheckRow({required this.label, required this.done, this.optional = false});
  @override
  Widget build(BuildContext context) => Row(children: [
    AnimatedContainer(duration: const Duration(milliseconds: 200), width: 20, height: 20,
        decoration: BoxDecoration(
            color: done ? const Color(0xFF059669) : optional ? const Color(0xFFF9FAFB) : const Color(0xFFF3F4F6),
            shape: BoxShape.circle,
            border: Border.all(color: done ? const Color(0xFF059669) : const Color(0xFFD1D5DB))),
        child: Icon(Icons.check_rounded, size: 12, color: done ? Colors.white : Colors.transparent)),
    const SizedBox(width: 10),
    Text(label, style: TextStyle(fontSize: 12,
        color: done ? const Color(0xFF059669) : optional ? const Color(0xFFB0B8CC) : const Color(0xFF6B7280),
        fontWeight: done ? FontWeight.w600 : FontWeight.normal)),
  ]);
}

// ═══════════════════════════════════════════════════════════════════════════
//  SAVED ADDRESSES SHEET
// ═══════════════════════════════════════════════════════════════════════════
class SavedAddressesSheet extends StatefulWidget {
  final Map<String, dynamic> data;
  final String uid;
  const SavedAddressesSheet({super.key, required this.data, required this.uid});
  @override
  State<SavedAddressesSheet> createState() => _SavedAddressesSheetState();
}

class _SavedAddressesSheetState extends State<SavedAddressesSheet> {
  late final TextEditingController _house, _building, _street, _landmark, _city, _state, _pincode;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final a = widget.data['address'] as Map<String, dynamic>? ?? {};
    _house    = TextEditingController(text: a['houseNo']  as String? ?? '');
    _building = TextEditingController(text: a['building'] as String? ?? '');
    _street   = TextEditingController(text: a['street']   as String? ?? '');
    _landmark = TextEditingController(text: a['landmark'] as String? ?? '');
    _city     = TextEditingController(text: a['city']     as String? ?? '');
    _state    = TextEditingController(text: a['state']    as String? ?? '');
    _pincode  = TextEditingController(text: a['pincode']  as String? ?? '');
  }

  @override
  void dispose() {
    _house.dispose(); _building.dispose(); _street.dispose();
    _landmark.dispose(); _city.dispose(); _state.dispose(); _pincode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.uid).set({
        'address': {
          'houseNo':  _house.text.trim(), 'building': _building.text.trim(),
          'street':   _street.text.trim(), 'landmark': _landmark.text.trim(),
          'city':     _city.text.trim(),   'state':    _state.text.trim(),
          'pincode':  _pincode.text.trim(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24, left: 24, right: 24),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 42, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)))),
          Row(children: [
            Container(width: 46, height: 46,
                decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF064E3B), Color(0xFF059669)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(13)),
                child: const Icon(Icons.home_rounded, color: Colors.white, size: 24)),
            const SizedBox(width: 14),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Home Address', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
              Text('Your delivery & service address', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            ]),
          ]),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: _af('House / Flat No.', _house, Icons.door_front_door_rounded, 'e.g. B-204')),
            const SizedBox(width: 12),
            Expanded(child: _af('Building / Society', _building, Icons.apartment_rounded, 'e.g. Rajvi Heights')),
          ]),
          _af('Street / Area', _street, Icons.map_rounded, 'e.g. MG Road, Adajan'),
          _af('Landmark (Optional)', _landmark, Icons.location_on_rounded, 'e.g. Near Reliance Pump'),
          Row(children: [
            Expanded(child: _af('City', _city, Icons.location_city_rounded, 'e.g. Surat')),
            const SizedBox(width: 12),
            Expanded(child: _af('State', _state, Icons.flag_rounded, 'e.g. Gujarat')),
          ]),
          _af('Pincode', _pincode, Icons.pin_drop_rounded, 'e.g. 395009', kb: TextInputType.number, max: 6),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669),
                  elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Address', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _af(String label, TextEditingController c, IconData icon, String hint,
      {TextInputType kb = TextInputType.streetAddress, int? max}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
        const SizedBox(height: 6),
        TextField(
          controller: c, keyboardType: kb, maxLength: max,
          style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
          decoration: InputDecoration(
            counterText: '', hintText: hint, hintStyle: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 13),
            prefixIcon: Icon(icon, color: const Color(0xFF059669), size: 18),
            filled: true, fillColor: const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5)),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SHARED SUB-PAGE GRADIENT HEADER
// ═══════════════════════════════════════════════════════════════════════════
class _SubHeader extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onBack;

  const _SubHeader({required this.title, required this.subtitle,
    required this.icon, required this.colors, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
      child: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: colors,
            begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 20, 28),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20), onPressed: onBack),
              Container(width: 44, height: 44,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: Colors.white, size: 22)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.70))),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  APP SETTINGS SCREEN
// ═══════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────────────────

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});
  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  // ── Notification prefs ───────────────────────────────────────────────────
  bool _notifRequests = true;
  bool _notifSafety   = true;

  // ── App prefs ────────────────────────────────────────────────────────────
  bool _autoFill = true;

  // ── Emergency prefs ──────────────────────────────────────────────────────
  bool _sosShortcut = true;

  bool _loadingPrefs = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  // ── Load prefs ────────────────────────────────────────────────────────────
  Future<void> _loadPrefs() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) { setState(() => _loadingPrefs = false); return; }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users').doc(uid).get();
      final d     = snap.data() ?? {};
      final prefs = d['prefs']             as Map<String, dynamic>? ?? {};
      final emerg = d['emergencySettings'] as Map<String, dynamic>? ?? {};
      if (mounted) {
        setState(() {
          _notifRequests = prefs['notifRequests'] as bool? ?? true;
          _notifSafety   = prefs['notifSafety']   as bool? ?? true;
          _autoFill      = prefs['autoFill']      as bool? ?? true;
          _sosShortcut   = emerg['sosShortcut']   as bool? ?? true;
          _loadingPrefs  = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPrefs = false);
    }
  }

  // ── Save a pref ───────────────────────────────────────────────────────────
  Future<void> _savePref(String section, String key, dynamic value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('users').doc(uid)
          .set({section: {key: value}}, SetOptions(merge: true));
    } catch (_) {}
  }

  void _toggle(String section, String key, bool current,
      void Function(bool) setter) {
    setState(() => setter(!current));
    _savePref(section, key, !current);
  }

  // ── Log out ───────────────────────────────────────────────────────────────
  Future<void> _logOut() async {
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false), // ✅ dialogCtx
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),  // ✅ dialogCtx
            child: const Text('Log Out',
                style: TextStyle(
                    color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      try {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Logout failed: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ));
        }
      }
    }
  }

  // ── Logout all devices ────────────────────────────────────────────────────
  Future<void> _logOutAllDevices() async {
    final passwordController = TextEditingController();

    // Step 1: Password verification dialog
    final passwordConfirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Verify Password',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter your password to log out from all devices.',
                style: TextStyle(height: 1.4)),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded,
                    color: Color(0xFF7C3AED)),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                  const BorderSide(color: Color(0xFF7C3AED), width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false), // ✅
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),  // ✅
            child: const Text('Verify',
                style: TextStyle(
                    color: Color(0xFF7C3AED), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (passwordConfirmed != true || !mounted) return;

    final password = passwordController.text.trim();
    if (password.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Password cannot be empty.'),
          backgroundColor: Color(0xFFDC2626),
        ));
      }
      return;
    }

    // Step 2: Loading dialog
    if (mounted) {
      showDialog(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(color: Color(0xFF7C3AED)),
                SizedBox(height: 16),
                Text('Verifying...'),
              ]),
            ),
          ),
        ),
      );
    }

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final cred = EmailAuthProvider.credential(
          email: user.email!, password: password);
      await user.reauthenticateWithCredential(cred);

      if (mounted) Navigator.of(context, rootNavigator: true).pop(); // dismiss loading

      // Step 3: Confirmation dialog
      final confirm = await showDialog<bool>(
        context: context,
        useRootNavigator: true,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Logout All Devices?',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text(
              'This will sign you out from all devices including this one. '
                  "You'll need to log in again."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false), // ✅
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF6B7280))),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),  // ✅
              child: const Text('Logout All',
                  style: TextStyle(
                      color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (confirm == true && mounted) {
        await FirebaseFirestore.instance
            .collection('users').doc(user.uid)
            .set({
          'security': {
            'lastLogoutAll':    FieldValue.serverTimestamp(),
            'logoutAllVersion': FieldValue.increment(1),
          }
        }, SetOptions(merge: true));

        await FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.code == 'wrong-password'
              ? 'Incorrect password. Please try again.'
              : e.message ?? 'Authentication failed.'),
          backgroundColor: const Color(0xFFDC2626),
        ));
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ));
      }
    }
  }

  // ── Clear cache ───────────────────────────────────────────────────────────
  Future<void> _clearCache() async {
    if (!mounted) return;

    // Confirmation first
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear Cache?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
            'This will clear locally cached data. The app will re-fetch data from the server.',
            style: TextStyle(height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false), // ✅
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),  // ✅
            child: const Text('Clear',
                style: TextStyle(
                    color: Color(0xFF7C3AED), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    // Loading
    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: Color(0xFF7C3AED)),
              SizedBox(height: 16),
              Text('Clearing cache...'),
            ]),
          ),
        ),
      ),
    );

    try {
      await FirebaseFirestore.instance.terminate();
      await FirebaseFirestore.instance.clearPersistence();
      // Re-enable network after clearPersistence
      await FirebaseFirestore.instanceFor(
          app: FirebaseFirestore.instance.app)
          .enableNetwork();
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Cache cleared successfully!'),
          backgroundColor: Color(0xFF059669),
          duration: Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to clear cache: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ));
      }
    }
  }

  // ── Navigate to Activity tab ──────────────────────────────────────────────
  void _goToActivityPastServices() {
    // Pops back to profile, which should handle tab switching
    // Change '/activity' to your actual route if different
    Navigator.pushNamed(context, '/activity',
        arguments: {'tab': 'pastServices'});
  }

  // ── Safety PIN sheet ──────────────────────────────────────────────────────
  void _setSafetyPin() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => const _SafetyPinSheet(),
    );
  }

  // ── Download my data ──────────────────────────────────────────────────────
  Future<void> _downloadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Row(children: [
          SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2)),
          SizedBox(width: 12),
          Text('Sending request...'),
        ]),
        backgroundColor: Color(0xFF7C3AED),
        duration: Duration(seconds: 2),
      ));
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).get();
      final username     = userDoc.data()?['username']    as String? ?? 'Unknown';
      final displayName  = userDoc.data()?['name']        as String? ?? user.displayName ?? 'Unknown';
      final email        = user.email ?? '';

      await FirebaseFirestore.instance.collection('admin_requests').add({
        'type':        'data_export',
        'uid':         user.uid,
        'email':       email,
        'username':    username,
        'displayName': displayName,
        'requestedAt': FieldValue.serverTimestamp(),
        'status':      'pending',
        'message':     'User @$username ($email) has requested a copy of their data.',
        'read':        false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
          Text("Request sent! You'll be contacted via email within 24 hours."),
          backgroundColor: Color(0xFF059669),
          duration: Duration(seconds: 4),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to send request. Please try again.'),
          backgroundColor: Color(0xFFDC2626),
        ));
      }
    }
  }

  // ── Delete account ────────────────────────────────────────────────────────
  Future<void> _deleteAccount() async {
    final passwordController = TextEditingController();

    // Step 1: Confirm intent
    final wantsToDelete = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Account?',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
        content: const Text(
            'Are you sure? Our admin team will process your deletion request and '
                'contact you within 48 hours.',
            style: TextStyle(height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false), // ✅
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),  // ✅
            child: const Text('Continue',
                style: TextStyle(
                    color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (wantsToDelete != true || !mounted) return;

    // Step 2: Password verification
    final passwordConfirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Identity',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your password to submit the deletion request.',
                style: TextStyle(height: 1.4)),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded,
                    color: Color(0xFFDC2626)),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                  const BorderSide(color: Color(0xFFDC2626), width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false), // ✅
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),  // ✅
            child: const Text('Submit Request',
                style: TextStyle(
                    color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (passwordConfirmed != true || !mounted) return;

    final password = passwordController.text.trim();
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Password cannot be empty.'),
        backgroundColor: Color(0xFFDC2626),
      ));
      return;
    }

    // Loading
    if (mounted) {
      showDialog(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(color: Color(0xFFDC2626)),
                SizedBox(height: 16),
                Text('Submitting request...'),
              ]),
            ),
          ),
        ),
      );
    }

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final cred = EmailAuthProvider.credential(
          email: user.email!, password: password);
      await user.reauthenticateWithCredential(cred);

      final userDoc = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).get();
      final username    = userDoc.data()?['username']   as String? ?? 'Unknown';
      final displayName = userDoc.data()?['name']       as String? ?? user.displayName ?? 'Unknown';
      final email       = user.email ?? '';

      await FirebaseFirestore.instance.collection('admin_requests').add({
        'type':        'account_deletion',
        'uid':         user.uid,
        'email':       email,
        'username':    username,
        'displayName': displayName,
        'requestedAt': FieldValue.serverTimestamp(),
        'status':      'pending',
        'message':     'User @$username (UID: ${user.uid}) requested account deletion.',
        'read':        false,
      });

      await FirebaseFirestore.instance
          .collection('users').doc(user.uid)
          .set({
        'deletionRequested':   true,
        'deletionRequestedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) Navigator.of(context, rootNavigator: true).pop(); // dismiss loading

      if (mounted) {
        await showDialog(
          context: context,
          useRootNavigator: true,
          builder: (dialogCtx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Text('Request Submitted',
                style: TextStyle(fontWeight: FontWeight.bold)),
            content: const Text(
                'Your deletion request has been sent to our admin team. '
                    'They will contact you at your registered email within 48 hours. '
                    'Your account remains active until then.',
                style: TextStyle(height: 1.5)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(), // ✅
                child: const Text('OK',
                    style: TextStyle(
                        color: Color(0xFF7C3AED),
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.code == 'wrong-password'
              ? 'Incorrect password. Please try again.'
              : e.code == 'requires-recent-login'
              ? 'Please log out, log back in, and try again.'
              : e.message ?? 'Authentication failed.'),
          backgroundColor: const Color(0xFFDC2626),
        ));
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to submit: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ));
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: _loadingPrefs
          ? const Center(
          child: CircularProgressIndicator(color: Color(0xFF7C3AED)))
          : CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _SettingsHeader(
              title: 'App Settings',
              subtitle: 'Safety, security & preferences',
              icon: Icons.settings_rounded,
              colors: const [
                Color(0xFF1E0640),
                Color(0xFF3B0764),
                Color(0xFF7C3AED),
              ],
              onBack: () => Navigator.pop(context),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── 1. EMERGENCY & SAFETY ──────────────────────────
                _sectionLabel('EMERGENCY & SAFETY', Icons.emergency_rounded),
                const SizedBox(height: 10),
                _card([
                  _SettingsSwitchTile(
                    icon: Icons.sos_rounded,
                    iconColor: const Color(0xFFDC2626),
                    iconBg: const Color(0xFFFEE2E2),
                    title: 'SOS Shortcut',
                    subtitle: 'Press power 3× to trigger SOS',
                    value: _sosShortcut,
                    onChanged: (_) => _toggle(
                        'emergencySettings', 'sosShortcut',
                        _sosShortcut, (v) => _sosShortcut = v),
                  ),
                  _SettingsTapTile(
                    icon: Icons.pin_rounded,
                    iconColor: const Color(0xFF7C3AED),
                    iconBg: const Color(0xFFEDE9FE),
                    title: 'Safety PIN',
                    subtitle: 'Set or change your safety PIN',
                    isLast: true,
                    onTap: _setSafetyPin,
                  ),
                ]),

                const SizedBox(height: 24),

                // ── 2. NOTIFICATION CONTROLS ───────────────────────
                _sectionLabel('NOTIFICATION CONTROLS', Icons.notifications_rounded),
                const SizedBox(height: 10),
                _card([
                  _SettingsSwitchTile(
                    icon: Icons.build_rounded,
                    iconColor: const Color(0xFF0891B2),
                    iconBg: const Color(0xFFE0F2FE),
                    title: 'Request Updates',
                    subtitle: 'Booking confirmations, status changes',
                    value: _notifRequests,
                    onChanged: (_) => _toggle('prefs', 'notifRequests',
                        _notifRequests, (v) => _notifRequests = v),
                  ),
                  _SettingsSwitchTile(
                    icon: Icons.shield_rounded,
                    iconColor: const Color(0xFFDC2626),
                    iconBg: const Color(0xFFFEE2E2),
                    title: 'Safety Alerts',
                    subtitle: 'Emergency & trust score updates',
                    value: _notifSafety,
                    isLast: true,
                    onChanged: (_) => _toggle('prefs', 'notifSafety',
                        _notifSafety, (v) => _notifSafety = v),
                  ),
                ]),

                const SizedBox(height: 24),

                // ── 3. APP PREFERENCES ─────────────────────────────
                _sectionLabel('APP PREFERENCES', Icons.tune_rounded),
                const SizedBox(height: 10),
                _card([
                  _SettingsSwitchTile(
                    icon: Icons.text_fields_rounded,
                    iconColor: const Color(0xFF0891B2),
                    iconBg: const Color(0xFFE0F2FE),
                    title: 'Auto-fill Request Details',
                    subtitle: 'Pre-fill from your last request',
                    value: _autoFill,
                    onChanged: (_) => _toggle('prefs', 'autoFill',
                        _autoFill, (v) => _autoFill = v),
                  ),
                  _SettingsTapTile(
                    icon: Icons.history_rounded,
                    iconColor: const Color(0xFF7C3AED),
                    iconBg: const Color(0xFFEDE9FE),
                    title: 'Past Services',
                    subtitle: 'View your service history in Activity',
                    isLast: true,
                    onTap: _goToActivityPastServices,
                  ),
                ]),

                const SizedBox(height: 24),

                // ── 4. SECURITY ────────────────────────────────────
                _sectionLabel('SECURITY', Icons.security_rounded),
                const SizedBox(height: 10),
                _card([
                  _SettingsTapTile(
                    icon: Icons.logout_rounded,
                    iconColor: const Color(0xFFDC2626),
                    iconBg: const Color(0xFFFEE2E2),
                    title: 'Logout from All Devices',
                    subtitle: 'Sign out from every device',
                    isLast: true,
                    isDestructive: true,
                    onTap: _logOutAllDevices,
                  ),
                ]),

                const SizedBox(height: 24),

                // ── 5. DATA & STORAGE ──────────────────────────────
                _sectionLabel('DATA & STORAGE', Icons.storage_rounded),
                const SizedBox(height: 10),
                _card([
                  _SettingsTapTile(
                    icon: Icons.download_rounded,
                    iconColor: const Color(0xFF059669),
                    iconBg: const Color(0xFFD1FAE5),
                    title: 'Download My Data',
                    subtitle: 'Request a copy — admin will email you',
                    onTap: _downloadData,
                  ),
                  _SettingsTapTile(
                    icon: Icons.cleaning_services_rounded,
                    iconColor: const Color(0xFF6B7280),
                    iconBg: const Color(0xFFF3F4F6),
                    title: 'Clear Cache',
                    subtitle: 'Free up local storage space',
                    isLast: true,
                    onTap: _clearCache,
                  ),
                ]),

                const SizedBox(height: 24),

                // ── 6. ABOUT & LEGAL ───────────────────────────────
                _sectionLabel('ABOUT & LEGAL', Icons.info_rounded),
                const SizedBox(height: 10),
                _card([
                  _SettingsTapTile(
                    icon: Icons.menu_book_rounded,
                    iconColor: const Color(0xFFD97706),
                    iconBg: const Color(0xFFFEF3C7),
                    title: 'Help Center',
                    subtitle: 'Guides, tutorials & how-tos',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const HelpCenterScreen())),
                  ),
                  _SettingsTapTile(
                    icon: Icons.privacy_tip_rounded,
                    iconColor: const Color(0xFF0891B2),
                    iconBg: const Color(0xFFE0F2FE),
                    title: 'Privacy Policy',
                    subtitle: 'How we handle your data',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const _SettingsTermsScreen())),
                  ),
                  _SettingsTapTile(
                    icon: Icons.description_rounded,
                    iconColor: const Color(0xFF059669),
                    iconBg: const Color(0xFFD1FAE5),
                    title: 'Terms & Conditions',
                    subtitle: 'Our usage terms',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const _SettingsTermsScreen())),
                  ),
                  _SettingsTapTile(
                    icon: Icons.groups_rounded,
                    iconColor: const Color(0xFF7C3AED),
                    iconBg: const Color(0xFFEDE9FE),
                    title: 'Community Guidelines',
                    subtitle: 'How to stay safe & respectful',
                    isLast: true,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) =>
                            const _SettingsCommunityScreen())),
                  ),
                ]),

                const SizedBox(height: 28),

                // ── DELETE ACCOUNT ─────────────────────────────────
                _redButton(
                    icon: Icons.delete_forever_rounded,
                    label: 'Request Account Deletion',
                    onTap: _deleteAccount),

                const SizedBox(height: 12),

                // ── LOG OUT ────────────────────────────────────────
                _redButton(
                    icon: Icons.logout_rounded,
                    label: 'Log Out',
                    onTap: _logOut),

                const SizedBox(height: 20),
                const Center(
                  child: Column(children: [
                    Text('Trouble Sarthi',
                        style: TextStyle(
                            fontSize: 13, color: Color(0xFFB0B8CC))),
                    Text('Version 2.4.1 (Indigo)',
                        style: TextStyle(
                            fontSize: 11, color: Color(0xFFD1D5DB))),
                  ]),
                ),
                const SizedBox(height: 60),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── UI helpers ────────────────────────────────────────────────────────────
  Widget _sectionLabel(String t, IconData icon) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Row(children: [
      Icon(icon, size: 13, color: const Color(0xFF9CA3AF)),
      const SizedBox(width: 6),
      Text(t,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF9CA3AF),
              letterSpacing: 1.3)),
    ]),
  );

  Widget _card(List<Widget> tiles) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3))
      ],
    ),
    child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(children: tiles)),
  );

  Widget _redButton(
      {required IconData icon,
        required String label,
        required VoidCallback onTap}) =>
      Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
                color: const Color(0xFFFFF1F1),
                borderRadius: BorderRadius.circular(16)),
            child:
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: const Color(0xFFDC2626), size: 20),
              const SizedBox(width: 10),
              Text(label,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFDC2626))),
            ]),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// _SafetyPinSheet  –  Set / change 4-digit safety PIN
// ─────────────────────────────────────────────────────────────────────────────

class _SafetyPinSheet extends StatefulWidget {
  const _SafetyPinSheet();
  @override
  State<_SafetyPinSheet> createState() => _SafetyPinSheetState();
}

class _SafetyPinSheetState extends State<_SafetyPinSheet> {
  final List<TextEditingController> _ctrl =
  List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _foci = List.generate(4, (_) => FocusNode());

  bool _isConfirm  = false;
  String _firstPin = '';
  bool _saving     = false;
  bool _hasPin     = false;
  bool _loading    = true;

  @override
  void initState() {
    super.initState();
    _checkExistingPin();
  }

  @override
  void dispose() {
    for (final c in _ctrl) c.dispose();
    for (final f in _foci) f.dispose();
    super.dispose();
  }

  Future<void> _checkExistingPin() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) { setState(() => _loading = false); return; }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users').doc(uid).get();
      final pin = snap.data()?['safetyPin'] as String?;
      if (mounted) setState(() { _hasPin = pin != null && pin.isNotEmpty; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _currentPin => _ctrl.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < 3) {
      FocusScope.of(context).requestFocus(_foci[index + 1]);
    } else if (value.isEmpty && index > 0) {
      FocusScope.of(context).requestFocus(_foci[index - 1]);
    }
    setState(() {});
  }

  Future<void> _onSubmit() async {
    final pin = _currentPin;
    if (pin.length < 4) return;

    if (!_isConfirm) {
      // Move to confirmation step
      setState(() {
        _isConfirm = true;
        _firstPin  = pin;
        for (final c in _ctrl) c.clear();
      });
      FocusScope.of(context).requestFocus(_foci[0]);
      return;
    }

    // Confirm step
    if (pin != _firstPin) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('PINs do not match. Please try again.'),
        backgroundColor: Color(0xFFDC2626),
      ));
      setState(() {
        _isConfirm = false;
        _firstPin  = '';
        for (final c in _ctrl) c.clear();
      });
      FocusScope.of(context).requestFocus(_foci[0]);
      return;
    }

    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      await FirebaseFirestore.instance
          .collection('users').doc(uid)
          .set({'safetyPin': pin}, SetOptions(merge: true));
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Safety PIN saved successfully!'),
          backgroundColor: Color(0xFF059669),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save PIN: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ));
      }
    }
  }

  Widget _pinBox(int index) => SizedBox(
    width: 56,
    height: 64,
    child: TextField(
      controller: _ctrl[index],
      focusNode: _foci[index],
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 1,
      obscureText: true,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        counterText: '',
        filled: true,
        fillColor: const Color(0xFFF5F3FF),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
          const BorderSide(color: Color(0xFF7C3AED), width: 2),
        ),
      ),
      onChanged: (v) => _onDigitChanged(index, v),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: _loading
          ? const Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
          ))
          : Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 24),

        // Icon
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
              color: const Color(0xFFEDE9FE),
              borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.pin_rounded,
              color: Color(0xFF7C3AED), size: 28),
        ),
        const SizedBox(height: 16),

        Text(
          _isConfirm
              ? 'Confirm Your PIN'
              : _hasPin
              ? 'Change Safety PIN'
              : 'Set Safety PIN',
          style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          _isConfirm
              ? 'Re-enter the PIN to confirm'
              : 'Enter a 4-digit PIN for emergency verification',
          style: const TextStyle(
              fontSize: 13, color: Color(0xFF6B7280)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // PIN boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _pinBox(0),
            const SizedBox(width: 12),
            _pinBox(1),
            const SizedBox(width: 12),
            _pinBox(2),
            const SizedBox(width: 12),
            _pinBox(3),
          ],
        ),
        const SizedBox(height: 32),

        // Submit button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _currentPin.length == 4 && !_saving
                ? _onSubmit
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              disabledBackgroundColor: const Color(0xFFDDD6FE),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _saving
                ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
                : Text(
              _isConfirm ? 'Confirm & Save' : 'Next',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ),
        ),

        if (_isConfirm) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              setState(() {
                _isConfirm = false;
                _firstPin  = '';
                for (final c in _ctrl) c.clear();
              });
              FocusScope.of(context).requestFocus(_foci[0]);
            },
            child: const Text('Go Back',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared sub-widgets (keep as-is or adapt to your existing versions)
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsHeader extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onBack;

  const _SettingsHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Row(children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8),
            Icon(icon, color: Colors.white.withOpacity(0.9), size: 28),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              Text(subtitle,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.7), fontSize: 12)),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ── Switch tile ───────────────────────────────────────────────────────────────
class _SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor, iconBg;
  final String title, subtitle;
  final bool value;
  final bool isLast;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration:
            BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF9CA3AF))),
            ]),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF7C3AED),
          ),
        ]),
      ),
      if (!isLast)
        const Divider(height: 1, indent: 68, endIndent: 16,
            color: Color(0xFFF3F4F6)),
    ]);
  }
}

// ── Tap tile ──────────────────────────────────────────────────────────────────
class _SettingsTapTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor, iconBg;
  final String title, subtitle;
  final bool isLast;
  final bool isDestructive;
  final VoidCallback onTap;

  const _SettingsTapTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isLast = false,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration:
              BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDestructive
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF111827))),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF9CA3AF))),
              ]),
            ),
            Icon(Icons.chevron_right_rounded,
                color: const Color(0xFFD1D5DB), size: 20),
          ]),
        ),
      ),
      if (!isLast)
        const Divider(height: 1, indent: 68, endIndent: 16,
            color: Color(0xFFF3F4F6)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Placeholder screens (replace with your actual implementations)
// ─────────────────────────────────────────────────────────────────────────────

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});
  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}




// ═══════════════════════════════════════════════════════════════════════════
//  _SettingsHeader — private gradient header, no conflict with _SubHeader
// ═══════════════════════════════════════════════════════════════════════════



// ═══════════════════════════════════════════════════════════════════════════
//  _ActiveSessionsScreen — private to this file, no conflict
// ═══════════════════════════════════════════════════════════════════════════
class _ActiveSessionsScreen extends StatefulWidget {
  const _ActiveSessionsScreen();
  @override
  State<_ActiveSessionsScreen> createState() => _ActiveSessionsScreenState();
}

class _ActiveSessionsScreenState extends State<_ActiveSessionsScreen> {
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) { setState(() => _loading = false); return; }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('sessions')
          .orderBy('lastActive', descending: true)
          .get();
      setState(() {
        _sessions = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        _loading  = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _revoke(String sessionId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('sessions')
          .doc(sessionId)
          .delete();
      setState(() => _sessions.removeWhere((s) => s['id'] == sessionId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Session revoked.'),
          backgroundColor: Color(0xFF059669),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to revoke session.'),
          backgroundColor: Color(0xFFDC2626),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const Text('Active Sessions',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E0640),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF3F4F6)),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)))
          : _sessions.isEmpty
          ? Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.devices_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No active sessions found',
              style: TextStyle(color: Colors.grey[500], fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Sessions are recorded when you\nlog in from a new device.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFFB0B8CC))),
        ]),
      )
          : ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _sessions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final s          = _sessions[i];
          final isCurrent  = s['isCurrentDevice'] as bool? ?? false;
          final deviceName = s['deviceName'] as String? ?? 'Unknown Device';
          final location   = s['location']   as String? ?? 'Unknown location';
          final deviceType = s['deviceType'] as String? ?? 'phone';
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: isCurrent
                  ? Border.all(color: const Color(0xFF7C3AED), width: 2)
                  : null,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? const Color(0xFFEDE9FE)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  deviceType == 'tablet'
                      ? Icons.tablet_rounded
                      : Icons.smartphone_rounded,
                  color: isCurrent
                      ? const Color(0xFF7C3AED)
                      : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(deviceName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                                color: const Color(0xFFEDE9FE),
                                borderRadius: BorderRadius.circular(20)),
                            child: const Text('This device',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF7C3AED),
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 4),
                      Text(location,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF6B7280))),
                    ]),
              ),
              if (!isCurrent)
                TextButton(
                  onPressed: () => _revoke(s['id'] as String),
                  child: const Text('Revoke',
                      style: TextStyle(
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.bold)),
                ),
            ]),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  _SettingsTermsScreen — private, no conflict with _TermsScreen
// ═══════════════════════════════════════════════════════════════════════════
class _SettingsTermsScreen extends StatelessWidget {
  const _SettingsTermsScreen();

  static const _sections = [
    {
      'title': '1. Acceptance of Terms',
      'body':
      'By downloading or using Trouble Sarthi, you agree to be bound by these '
          'Terms of Service. If you do not agree, please do not use the app.',
    },
    {
      'title': '2. Services Provided',
      'body':
      'Trouble Sarthi connects users with independent service providers '
          '("Sarthi Helpers") for home services. We act as an intermediary platform.',
    },
    {
      'title': '3. Payments & Escrow',
      'body':
      'UPI payments are held in escrow and released to helpers only after you '
          'confirm service completion. Refunds for disputed transactions are '
          'processed within 5–7 business days.',
    },
    {
      'title': '4. User Responsibilities',
      'body':
      'You agree to provide accurate information, treat helpers respectfully, '
          'and not misuse the platform.',
    },
    {
      'title': '5. Privacy Policy',
      'body':
      'We collect name, phone, email, and location data solely to provide our '
          'services. We do not sell your personal data to third parties.',
    },
    {
      'title': '6. Cancellation Policy',
      'body':
      'Free cancellations are allowed up to 30 minutes before the scheduled '
          'service time. Late cancellations may attract a convenience fee of ₹20–₹50.',
    },
    {
      'title': '7. Contact Us',
      'body':
      'For any questions: support@troublesarthi.com · '
          'Trouble Sarthi, Surat, Gujarat, India.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const Text('Terms & Privacy',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E0640),
        elevation: 0,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _sections.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final s = _sections[i];
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s['title']!,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF059669))),
              const SizedBox(height: 8),
              Text(s['body']!,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF4B5563), height: 1.6)),
            ]),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  _SettingsCommunityScreen — private, no conflict with _CommunityGuidelinesScreen
// ═══════════════════════════════════════════════════════════════════════════
class _SettingsCommunityScreen extends StatelessWidget {
  const _SettingsCommunityScreen();

  static const _guidelines = <Map<String, Object>>[
    {
      'icon':  Icons.handshake_rounded,
      'title': 'Respect Everyone',
      'body':
      'Treat every helper and user with courtesy and dignity. Harassment, '
          'discrimination, or abusive behaviour will result in immediate account suspension.',
    },
    {
      'icon':  Icons.verified_rounded,
      'title': 'Be Honest',
      'body':
      'Provide accurate service requests and honest reviews. False reports or '
          'fake feedback harm our community and the helpers who depend on it.',
    },
    {
      'icon':  Icons.lock_rounded,
      'title': 'Protect Privacy',
      'body':
      'Do not share personal information of helpers or other users outside the app. '
          'All communication should remain within the Trouble Sarthi platform.',
    },
    {
      'icon':  Icons.payments_rounded,
      'title': 'Pay Fairly',
      'body':
      'Do not attempt to bypass the escrow system or negotiate payments '
          'outside the app. This protects both you and the helper.',
    },
    {
      'icon':  Icons.block_rounded,
      'title': 'Zero Tolerance for Abuse',
      'body':
      'Physical, verbal, or sexual abuse of any kind will result in permanent '
          'banning and may be reported to law enforcement.',
    },
    {
      'icon':  Icons.health_and_safety_rounded,
      'title': 'Safety First',
      'body':
      'Always verify the helper\'s identity before letting them into your home. '
          'Use the SOS feature if you ever feel unsafe.',
    },
    {
      'icon':  Icons.star_rounded,
      'title': 'Leave Honest Reviews',
      'body':
      'Your reviews help the community. Be fair, specific, and constructive. '
          'Avoid leaving reviews based on personal bias.',
    },
    {
      'icon':  Icons.build_circle_rounded,
      'title': 'Use the Platform Correctly',
      'body':
      'Only request services for legitimate needs. Misuse of emergency features '
          'or the support system may result in account restrictions.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const Text('Community Guidelines',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E0640),
        elevation: 0,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _guidelines.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final g = _guidelines[i];
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(g['icon'] as IconData,
                    color: const Color(0xFF7C3AED), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(g['title'] as String,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937))),
                  const SizedBox(height: 4),
                  Text(g['body'] as String,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF4B5563), height: 1.5)),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  REUSABLE TILE WIDGETS
// ═══════════════════════════════════════════════════════════════════════════
class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor, iconBg;
  final String title, subtitle;
  final bool value;
  final bool isLast;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon, required this.iconColor, required this.iconBg,
    required this.title, required this.subtitle,
    required this.value, required this.onChanged, this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(border: isLast ? null
          : const Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))),
      child: Row(children: [
        Container(width: 40, height: 40,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: iconColor, size: 20)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
        ])),
        Switch(value: value, onChanged: onChanged, activeColor: const Color(0xFF5B21B6),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
      ]),
    );
  }
}

class _TapTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor, iconBg;
  final String title, subtitle;
  final bool isLast, isDestructive;
  final VoidCallback onTap;

  const _TapTile({
    required this.icon, required this.iconColor, required this.iconBg,
    required this.title, required this.subtitle, required this.onTap,
    this.isLast = false, this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(border: isLast ? null
              : const Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))),
          child: Row(children: [
            Container(width: 40, height: 40,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(11)),
                child: Icon(icon, color: iconColor, size: 20)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                  color: isDestructive ? const Color(0xFFDC2626) : const Color(0xFF1F2937))),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
            ])),
            Icon(Icons.chevron_right_rounded,
                color: isDestructive ? const Color(0xFFDC2626).withOpacity(0.4) : const Color(0xFFD1D5DB), size: 20),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TRUSTED CONTACTS SHEET
// ═══════════════════════════════════════════════════════════════════════════
class _TrustedContactsListSheet extends StatelessWidget {
  final List<Map<String, dynamic>> contacts;
  final VoidCallback onAdd;
  final Future<void> Function(Map<String, dynamic>) onRemove;

  const _TrustedContactsListSheet({
    required this.contacts, required this.onAdd, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 42, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
        Row(children: [
          Container(width: 46, height: 46,
              decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF78350F), Color(0xFFD97706)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(13)),
              child: const Icon(Icons.people_rounded, color: Colors.white, size: 24)),
          const SizedBox(width: 14),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Trusted Contacts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
            Text('Notified in emergencies', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ]),
          const Spacer(),
          GestureDetector(
            onTap: () { Navigator.pop(context); onAdd(); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFFD97706), borderRadius: BorderRadius.circular(10)),
              child: const Text('+ Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        if (contacts.isEmpty)
          Container(padding: const EdgeInsets.all(24),
              child: const Column(children: [
                Icon(Icons.people_outline_rounded, color: Color(0xFFD1D5DB), size: 48),
                SizedBox(height: 12),
                Text('No trusted contacts yet', style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF))),
                Text('Add someone who will be notified during emergencies',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFFB0B8CC))),
              ]))
        else
          ...contacts.map((c) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFCD34D).withOpacity(0.5))),
            child: Row(children: [
              Container(width: 40, height: 40,
                  decoration: const BoxDecoration(color: Color(0xFFFEF9C3), shape: BoxShape.circle),
                  child: Center(child: Text(
                      (c['name'] as String? ?? '?')[0].toUpperCase(),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFD97706))))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c['name'] as String? ?? 'Unknown',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
                Text(c['phone'] as String? ?? '',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ])),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 20),
                onPressed: () => onRemove(c),
              ),
            ]),
          )),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  ADD TRUSTED CONTACT SHEET
// ═══════════════════════════════════════════════════════════════════════════
class _TrustedContactSheet extends StatefulWidget {
  final Future<void> Function(String name, String phone) onSave;
  const _TrustedContactSheet({required this.onSave});
  @override
  State<_TrustedContactSheet> createState() => _TrustedContactSheetState();
}

class _TrustedContactSheetState extends State<_TrustedContactSheet> {
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() { _nameCtrl.dispose(); _phoneCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 28, left: 24, right: 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 42, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)))),
        const Text('Add Trusted Contact', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
        const SizedBox(height: 4),
        const Text('This person will be notified when SOS is triggered',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        const SizedBox(height: 20),
        _inputField('Full Name', _nameCtrl, Icons.person_rounded, TextInputType.name),
        const SizedBox(height: 12),
        _inputField('Phone Number', _phoneCtrl, Icons.phone_rounded, TextInputType.phone),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: _saving ? null : () async {
              if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) return;
              setState(() => _saving = true);
              await widget.onSave(_nameCtrl.text.trim(), _phoneCtrl.text.trim());
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706),
                elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save Contact', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      ]),
    );
  }

  Widget _inputField(String label, TextEditingController ctrl, IconData icon, TextInputType kb) {
    return TextField(
      controller: ctrl, keyboardType: kb,
      style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
      decoration: InputDecoration(
        hintText: label, hintStyle: const TextStyle(color: Color(0xFFD1D5DB)),
        prefixIcon: Icon(icon, color: const Color(0xFFD97706), size: 18),
        filled: true, fillColor: const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.5)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SAFETY PIN SHEET
// ═══════════════════════════════════════════════════════════════════════════


// ═══════════════════════════════════════════════════════════════════════════
//  ACTIVE SESSIONS SCREEN
// ═══════════════════════════════════════════════════════════════════════════
class ActiveSessionsScreen extends StatefulWidget {
  const ActiveSessionsScreen({super.key});

  @override
  State<ActiveSessionsScreen> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<ActiveSessionsScreen>
    with TickerProviderStateMixin {
  late final AnimationController _headerCtrl;
  late final AnimationController _listCtrl;

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..forward();
    _listCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _listCtrl.dispose();
    super.dispose();
  }

  Future<void> _revokeSession(String docId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => const _SessionsRevokeDialog(),
    );
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('sessions')
          .doc(docId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            backgroundColor: const Color(0xFF0D1117),
            content: Row(children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF39D353).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.check_rounded,
                    color: Color(0xFF39D353), size: 16),
              ),
              const SizedBox(width: 12),
              const Text('Session revoked',
                  style: TextStyle(
                      color: Colors.white, fontFamily: 'monospace')),
            ]),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            backgroundColor: const Color(0xFF2D1117),
            content: const Text('Failed to revoke session',
                style: TextStyle(color: Color(0xFFFF6B6B))),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('sessions')
            .orderBy('loginAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          final docs = snap.data?.docs ?? [];
          final sessions = docs
              .map((d) => {
            'id': d.id,
            ...Map<String, dynamic>.from(d.data() as Map),
          })
              .toList();

          final currentSession =
          sessions.where((s) => s['isCurrent'] == true).toList();
          final otherSessions =
          sessions.where((s) => s['isCurrent'] != true).toList();

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── HEADER ─────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _SessionsHeader(
                  ctrl: _headerCtrl,
                  sessionCount: sessions.length,
                ),
              ),

              // ── LOADING ────────────────────────────────────────────────
              if (snap.connectionState == ConnectionState.waiting)
                const SliverToBoxAdapter(child: _SessionsLoadingGrid()),

              // ── EMPTY ──────────────────────────────────────────────────
              if (snap.connectionState != ConnectionState.waiting &&
                  sessions.isEmpty)
                const SliverToBoxAdapter(child: _SessionsEmptyState()),

              // ── CURRENT DEVICE ─────────────────────────────────────────
              if (currentSession.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                    child: _SessionsSectionLabel(label: 'CURRENT DEVICE'),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (_, i) => _SessionsCard(
                        key: ValueKey(currentSession[i]['id']),
                        data: currentSession[i],
                        index: i,
                        listCtrl: _listCtrl,
                        onRevoke: null,
                      ),
                      childCount: currentSession.length,
                    ),
                  ),
                ),
              ],

              // ── OTHER SESSIONS ─────────────────────────────────────────
              if (otherSessions.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _SessionsSectionLabel(label: 'OTHER SESSIONS'),
                        _SessionsRevokeAllButton(
                          onTap: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (_) => const _SessionsRevokeAllDialog(),
                            );
                            if (confirm == true) {
                              for (final s in otherSessions) {
                                await _revokeSession(s['id'] as String);
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (_, i) => _SessionsCard(
                        key: ValueKey(otherSessions[i]['id']),
                        data: otherSessions[i],
                        index: i + currentSession.length,
                        listCtrl: _listCtrl,
                        onRevoke: () =>
                            _revokeSession(otherSessions[i]['id'] as String),
                      ),
                      childCount: otherSessions.length,
                    ),
                  ),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 60)),
            ],
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  _SessionsHeader
// ═══════════════════════════════════════════════════════════════════════════
class _SessionsHeader extends StatelessWidget {
  final AnimationController ctrl;
  final int sessionCount;

  const _SessionsHeader({required this.ctrl, required this.sessionCount});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, child) {
        final fade = CurvedAnimation(parent: ctrl, curve: Curves.easeOut);
        final slide =
        Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
            .animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOutCubic));
        return FadeTransition(
            opacity: fade,
            child: SlideTransition(position: slide, child: child));
      },
      child: Stack(
        children: [
          Container(
            height: 240,
            decoration: const BoxDecoration(color: Color(0xFF0D1117)),
            child: CustomPaint(painter: _SessionsGridPainter()),
          ),
          Container(
            height: 240,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0D1117).withValues(alpha: 0.3),
                  const Color(0xFF0D1117),
                ],
              ),
            ),
          ),
          Positioned(
            top: -30,
            right: -20,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF39D353).withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF39D353).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color:
                            const Color(0xFF39D353).withValues(alpha: 0.3)),
                      ),
                      child: Row(children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                              color: Color(0xFF39D353), shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$sessionCount ${sessionCount == 1 ? 'session' : 'sessions'} active',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: Color(0xFF39D353),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  const Text(
                    'Active\nSessions',
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.0,
                      letterSpacing: -1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage where you\'re logged in',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.4),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  _SessionsCard
// ═══════════════════════════════════════════════════════════════════════════
class _SessionsCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final int index;
  final AnimationController listCtrl;
  final VoidCallback? onRevoke;

  const _SessionsCard({
    super.key,
    required this.data,
    required this.index,
    required this.listCtrl,
    required this.onRevoke,
  });

  @override
  State<_SessionsCard> createState() => _SessionsCardState();
}

class _SessionsCardState extends State<_SessionsCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final s          = widget.data;
    final isCurrent  = s['isCurrent'] as bool? ?? false;
    final deviceName = s['device']    as String? ?? 'Unknown Device';
    final platform   = s['platform']  as String? ?? 'Unknown';
    final loginAt    = s['loginAt']   as Timestamp?;

    final delay       = (widget.index * 0.12).clamp(0.0, 0.6);
    final intervalEnd = (delay + 0.4).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: widget.listCtrl,
      builder: (_, child) {
        final t = CurvedAnimation(
          parent: widget.listCtrl,
          curve: Interval(delay, intervalEnd, curve: Curves.easeOutCubic),
        );
        return FadeTransition(
          opacity: t,
          child: SlideTransition(
            position:
            Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
                .animate(t),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isCurrent
                  ? const Color(0xFF0F2117)
                  : const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isCurrent
                    ? const Color(0xFF39D353).withValues(alpha: 0.35)
                    : Colors.white.withValues(alpha: 0.06),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                _SessionsDeviceIcon(platform: platform, isCurrent: isCurrent),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(
                            deviceName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCurrent)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF39D353)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: const Color(0xFF39D353)
                                      .withValues(alpha: 0.4)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                    color: Color(0xFF39D353),
                                    shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 5),
                              const Text('NOW',
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF39D353),
                                      letterSpacing: 1)),
                            ]),
                          ),
                      ]),
                      const SizedBox(height: 5),
                      Row(children: [
                        _SessionsPlatformChip(platform: platform),
                        const SizedBox(width: 8),
                        if (loginAt != null)
                          Text(
                            _fmtDate(loginAt.toDate()),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.35),
                              fontFamily: 'monospace',
                            ),
                          ),
                      ]),
                    ],
                  ),
                ),
                if (widget.onRevoke != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: widget.onRevoke,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B6B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFFFF6B6B)
                                .withValues(alpha: 0.2)),
                      ),
                      child: const Icon(Icons.link_off_rounded,
                          color: Color(0xFFFF6B6B), size: 18),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'Today ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '${d.day} ${months[d.month]} ${d.year}';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  _SessionsDeviceIcon
// ═══════════════════════════════════════════════════════════════════════════
class _SessionsDeviceIcon extends StatelessWidget {
  final String platform;
  final bool isCurrent;

  const _SessionsDeviceIcon(
      {required this.platform, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    final p = platform.toLowerCase();
    final IconData icon;
    if (p.contains('ios') || p.contains('iphone') || p.contains('ipad')) {
      icon = Icons.phone_iphone_rounded;
    } else if (p.contains('web') ||
        p.contains('chrome') ||
        p.contains('browser')) {
      icon = Icons.laptop_rounded;
    } else if (p.contains('android')) {
      icon = Icons.android_rounded;
    } else if (p.contains('tablet')) {
      icon = Icons.tablet_rounded;
    } else {
      icon = Icons.devices_rounded;
    }

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: isCurrent
            ? const Color(0xFF39D353).withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent
              ? const Color(0xFF39D353).withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: Icon(
        icon,
        color: isCurrent
            ? const Color(0xFF39D353)
            : Colors.white.withValues(alpha: 0.4),
        size: 26,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  _SessionsPlatformChip
// ═══════════════════════════════════════════════════════════════════════════
class _SessionsPlatformChip extends StatelessWidget {
  final String platform;
  const _SessionsPlatformChip({required this.platform});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        platform,
        style: TextStyle(
          fontSize: 10,
          fontFamily: 'monospace',
          color: Colors.white.withValues(alpha: 0.4),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  _SessionsSectionLabel
// ═══════════════════════════════════════════════════════════════════════════
class _SessionsSectionLabel extends StatelessWidget {
  final String label;
  const _SessionsSectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 3,
        height: 14,
        decoration: BoxDecoration(
          color: const Color(0xFF39D353),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Colors.white.withValues(alpha: 0.35),
          letterSpacing: 2.0,
          fontFamily: 'monospace',
        ),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  _SessionsRevokeAllButton
// ═══════════════════════════════════════════════════════════════════════════
class _SessionsRevokeAllButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SessionsRevokeAllButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B6B).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: const Color(0xFFFF6B6B).withValues(alpha: 0.2)),
        ),
        child: const Text(
          'Revoke all',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFFFF6B6B),
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  _SessionsRevokeDialog
// ═══════════════════════════════════════════════════════════════════════════
class _SessionsRevokeDialog extends StatelessWidget {
  const _SessionsRevokeDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B6B).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFFFF6B6B).withValues(alpha: 0.25)),
            ),
            child: const Icon(Icons.link_off_rounded,
                color: Color(0xFFFF6B6B), size: 28),
          ),
          const SizedBox(height: 16),
          const Text('Revoke Session?',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5)),
          const SizedBox(height: 8),
          Text('This device will be signed out immediately.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.4),
                  height: 1.5)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(context, false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                      child: Text('Cancel',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14))),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(context, true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B6B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color:
                        const Color(0xFFFF6B6B).withValues(alpha: 0.3)),
                  ),
                  child: const Center(
                      child: Text('Revoke',
                          style: TextStyle(
                              color: Color(0xFFFF6B6B),
                              fontWeight: FontWeight.w700,
                              fontSize: 14))),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  _SessionsRevokeAllDialog
// ═══════════════════════════════════════════════════════════════════════════
class _SessionsRevokeAllDialog extends StatelessWidget {
  const _SessionsRevokeAllDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B6B).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFFFF6B6B).withValues(alpha: 0.25)),
            ),
            child: const Icon(Icons.devices_other_rounded,
                color: Color(0xFFFF6B6B), size: 28),
          ),
          const SizedBox(height: 16),
          const Text('Revoke All?',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5)),
          const SizedBox(height: 8),
          Text(
              'All other devices will be signed out.\nYour current session stays active.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.4),
                  height: 1.5)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(context, false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                      child: Text('Cancel',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14))),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(context, true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B6B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color:
                        const Color(0xFFFF6B6B).withValues(alpha: 0.3)),
                  ),
                  child: const Center(
                      child: Text('Revoke All',
                          style: TextStyle(
                              color: Color(0xFFFF6B6B),
                              fontWeight: FontWeight.w700,
                              fontSize: 14))),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  _SessionsLoadingGrid
// ═══════════════════════════════════════════════════════════════════════════
class _SessionsLoadingGrid extends StatefulWidget {
  const _SessionsLoadingGrid();
  @override
  State<_SessionsLoadingGrid> createState() => _SessionsLoadingGridState();
}

class _SessionsLoadingGridState extends State<_SessionsLoadingGrid>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              final t =
              math.sin((_ctrl.value * 2 * math.pi) + i * 1.0);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                height: 80,
                decoration: BoxDecoration(
                  color: Color.lerp(const Color(0xFF161B22),
                      const Color(0xFF1C2128), (t + 1) / 2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05)),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  _SessionsEmptyState
// ═══════════════════════════════════════════════════════════════════════════
class _SessionsEmptyState extends StatelessWidget {
  const _SessionsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      child: Column(children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(24),
            border:
            Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Icon(Icons.devices_rounded,
              size: 36, color: Colors.white.withValues(alpha: 0.2)),
        ),
        const SizedBox(height: 20),
        Text('No sessions found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.6),
              letterSpacing: -0.5,
            )),
        const SizedBox(height: 8),
        Text('Sessions appear here when\nyou log in from a device.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.25),
              height: 1.6,
            )),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  _SessionsGridPainter
// ═══════════════════════════════════════════════════════════════════════════
class _SessionsGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ═══════════════════════════════════════════════════════════════════════════
//  COMMUNITY GUIDELINES SCREEN
// ═══════════════════════════════════════════════════════════════════════════
class _CommunityGuidelinesScreen extends StatelessWidget {
  const _CommunityGuidelinesScreen();

  static const _guidelines = [
    {'emoji': '🤝', 'title': 'Respect Everyone',
      'body': 'Treat every helper and user with courtesy and dignity. Harassment, discrimination, or abusive behaviour will result in immediate account suspension.'},
    {'emoji': '✅', 'title': 'Be Honest',
      'body': 'Provide accurate service requests and honest reviews. False reports or fake feedback harm our community and the helpers who depend on it.'},
    {'emoji': '🔒', 'title': 'Protect Privacy',
      'body': 'Do not share personal information of helpers or other users outside the app. All communication should remain within the Trouble Sarthi platform.'},
    {'emoji': '💳', 'title': 'Pay Fairly',
      'body': 'Do not attempt to bypass the escrow system or negotiate payments outside the app. This protects both you and the helper.'},
    {'emoji': '🚫', 'title': 'Zero Tolerance for Abuse',
      'body': 'Physical, verbal, or sexual abuse of any kind will result in permanent banning and may be reported to law enforcement.'},
    {'emoji': '📍', 'title': 'Safety First',
      'body': 'Always verify the helper\'s identity before letting them into your home. Use the SOS feature if you ever feel unsafe.'},
    {'emoji': '⭐', 'title': 'Leave Honest Reviews',
      'body': 'Your reviews help the community. Be fair, specific, and constructive. Avoid leaving reviews based on personal bias.'},
    {'emoji': '🛠️', 'title': 'Use the Platform Correctly',
      'body': 'Only request services for legitimate needs. Misuse of emergency features or the support system may result in account restrictions.'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: CustomScrollView(physics: const ClampingScrollPhysics(), slivers: [
        SliverToBoxAdapter(child: _SubHeader(
          title: 'Community Guidelines', subtitle: 'Stay safe & respectful',
          icon: Icons.groups_rounded,
          colors: const [Color(0xFF3B1F8C), Color(0xFF5B21B6), Color(0xFF7C3AED)],
          onBack: () => Navigator.pop(context),
        )),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(delegate: SliverChildBuilderDelegate((_, i) {
            if (i >= _guidelines.length) return const SizedBox(height: 80);
            final g = _guidelines[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 44, height: 44,
                    decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(12)),
                    child: Center(child: Text(g['emoji']!, style: const TextStyle(fontSize: 20)))),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(g['title']!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                  const SizedBox(height: 4),
                  Text(g['body']!, style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563), height: 1.5)),
                ])),
              ]),
            );
          }, childCount: _guidelines.length + 1)),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  ACTIVITY SCREEN
// ═══════════════════════════════════════════════════════════════════════════
class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: CustomScrollView(physics: const ClampingScrollPhysics(), slivers: [
        SliverToBoxAdapter(child: _SubHeader(
            title: 'Activity', subtitle: 'Your bookings & service history',
            icon: Icons.history_rounded,
            colors: const [Color(0xFF0C4A6E), Color(0xFF0891B2), Color(0xFF22D3EE)],
            onBack: () => Navigator.pop(context))),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('bookings')
              .where('userId', isEqualTo: uid).limit(30).snapshots(),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const SliverToBoxAdapter(child: Center(child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: Color(0xFF0891B2)))));
            }
            final docs = (snap.data?.docs ?? [])
              ..sort((a, b) {
                final aTs = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                final bTs = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                if (aTs == null && bTs == null) return 0;
                if (aTs == null) return 1;
                if (bTs == null) return -1;
                return bTs.compareTo(aTs);
              });
            if (docs.isEmpty) {
              return const SliverToBoxAdapter(child: _EmptyState(
                  icon: Icons.calendar_today_rounded, color: Color(0xFF0891B2),
                  bg: Color(0xFFE0F2FE), title: 'No activity yet',
                  sub: 'Your bookings and service history\nwill appear here.'));
            }
            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              sliver: SliverList(delegate: SliverChildBuilderDelegate((_, i) {
                final d = docs[i].data() as Map<String, dynamic>;
                final service = d['serviceName'] as String? ?? 'Service';
                final helper  = d['helperName']  as String? ?? 'Helper';
                final status  = (d['status'] as String? ?? 'pending').toLowerCase();
                final ts      = d['createdAt'] as Timestamp?;
                Color sc; String sl;
                switch (status) {
                  case 'completed': sc = const Color(0xFF059669); sl = 'Completed'; break;
                  case 'cancelled': sc = const Color(0xFFDC2626); sl = 'Cancelled'; break;
                  case 'ongoing':   sc = const Color(0xFF0891B2); sl = 'Ongoing';   break;
                  default:          sc = const Color(0xFFD97706); sl = 'Pending';
                }
                return Container(
                  margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))]),
                  child: Row(children: [
                    Container(width: 44, height: 44,
                        decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.build_rounded, color: Color(0xFF0891B2), size: 22)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(service, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                      Text('by $helper', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                      if (ts != null) Text(_fd(ts.toDate()), style: const TextStyle(fontSize: 11, color: Color(0xFFB0B8CC))),
                    ])),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: sc.withOpacity(0.10), borderRadius: BorderRadius.circular(20)),
                        child: Text(sl, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: sc))),
                  ]),
                );
              }, childCount: docs.length)),
            );
          },
        ),
      ]),
    );
  }

  String _fd(DateTime d) {
    const m = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${m[d.month]}, ${d.year}';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  PAYMENTS SCREEN (unchanged from original)
// ═══════════════════════════════════════════════════════════════════════════
class _PayStatusMeta {
  final String label;
  final Color color, bg;
  final IconData icon;
  const _PayStatusMeta(this.label, this.color, this.bg, this.icon);
}

_PayStatusMeta _payMeta(String status, String mode) {
  switch (status) {
    case 'in_escrow': return const _PayStatusMeta('In Escrow', Color(0xFF0891B2), Color(0xFFE0F2FE), Icons.lock_clock_rounded);
    case 'released':  return const _PayStatusMeta('Released',  Color(0xFF059669), Color(0xFFD1FAE5), Icons.check_circle_rounded);
    case 'refunded':  return const _PayStatusMeta('Refunded',  Color(0xFF7C3AED), Color(0xFFEDE9FE), Icons.keyboard_return_rounded);
    case 'cash_paid': return const _PayStatusMeta('Cash Paid', Color(0xFF059669), Color(0xFFD1FAE5), Icons.payments_rounded);
    case 'pending':   return const _PayStatusMeta('Pending',   Color(0xFFD97706), Color(0xFFFEF3C7), Icons.hourglass_empty_rounded);
    case 'failed':    return const _PayStatusMeta('Failed',    Color(0xFFDC2626), Color(0xFFFEE2E2), Icons.cancel_rounded);
    default:          return const _PayStatusMeta('Processing',Color(0xFF6B7280), Color(0xFFF3F4F6), Icons.sync_rounded);
  }
}

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});
  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  @override
  void initState() { super.initState(); _tab = TabController(length: 2, vsync: this); _tab.addListener(() => setState(() {})); }
  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverToBoxAdapter(child: _SubHeader(title: 'Payments', subtitle: 'Your spending & escrow status',
              icon: Icons.receipt_long_rounded,
              colors: const [Color(0xFF1E0640), Color(0xFF5B21B6), Color(0xFF7C3AED)],
              onBack: () => Navigator.pop(context))),
          SliverToBoxAdapter(child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('transactions').where('userId', isEqualTo: uid).snapshots(),
            builder: (_, snap) {
              final docs = snap.data?.docs ?? [];
              double total = 0, escrow = 0, cash = 0;
              for (final d in docs) {
                final tx = d.data() as Map<String, dynamic>;
                final amt = (tx['amount'] as num?)?.toDouble() ?? 0;
                final mode = tx['paymentMode'] as String? ?? '';
                final status = tx['paymentStatus'] as String? ?? '';
                total += amt;
                if (mode == 'cash') cash += amt;
                if (status == 'in_escrow') escrow += amt;
              }
              return _SpendingSummaryCard(total: total, escrow: escrow, cash: cash);
            },
          )),
          const SliverToBoxAdapter(child: _EscrowInfoBanner()),
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Container(height: 44,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0,2))]),
              child: TabBar(controller: _tab, labelColor: Colors.white,
                  unselectedLabelColor: const Color(0xFF6B7280),
                  labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  indicator: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF5B21B6), Color(0xFF7C3AED)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(12)),
                  indicatorSize: TabBarIndicatorSize.tab, dividerColor: Colors.transparent,
                  tabs: const [Tab(text: 'All Payments'), Tab(text: 'In Escrow')]),
            ),
          )),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
        body: TabBarView(controller: _tab, children: [
          _TransactionsList(uid: uid, escrowOnly: false),
          _TransactionsList(uid: uid, escrowOnly: true),
        ]),
      ),
    );
  }
}

class _SpendingSummaryCard extends StatelessWidget {
  final double total, escrow, cash;
  const _SpendingSummaryCard({required this.total, required this.escrow, required this.cash});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF3B1F8C), Color(0xFF5B21B6), Color(0xFF7C3AED)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: const Color(0xFF5B21B6).withOpacity(0.30), blurRadius: 18, offset: const Offset(0, 6))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 36, height: 36,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), shape: BoxShape.circle),
              child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 18)),
          const SizedBox(width: 10),
          const Text('Total Spent on Trouble Sarthi', style: TextStyle(fontSize: 12, color: Colors.white70)),
        ]),
        const SizedBox(height: 14),
        Text('₹${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 16),
        Row(children: [
          _StatPill(icon: Icons.lock_clock_rounded, label: 'In Escrow', value: '₹${escrow.toStringAsFixed(0)}', color: const Color(0xFF22D3EE)),
          const SizedBox(width: 10),
          _StatPill(icon: Icons.payments_rounded, label: 'Paid Cash', value: '₹${cash.toStringAsFixed(0)}', color: const Color(0xFF86EFAC)),
          const SizedBox(width: 10),
          _StatPill(icon: Icons.check_circle_rounded, label: 'Released',
              value: '₹${(total - escrow - cash).clamp(0, double.infinity).toStringAsFixed(0)}',
              color: const Color(0xFFA78BFA)),
        ]),
      ]),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon; final String label, value; final Color color;
  const _StatPill({required this.icon, required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(14)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 16), const SizedBox(height: 6),
      Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.70))),
    ]),
  ));
}

class _EscrowInfoBanner extends StatelessWidget {
  const _EscrowInfoBanner();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 0), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF0891B2).withOpacity(0.20))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 34, height: 34,
            decoration: BoxDecoration(color: const Color(0xFF0891B2).withOpacity(0.15), shape: BoxShape.circle),
            child: const Icon(Icons.security_rounded, color: Color(0xFF0891B2), size: 18)),
        const SizedBox(width: 12),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('🔐  How UPI Payments Work',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0C4A6E))),
          SizedBox(height: 4),
          Text('When you pay via UPI, the money is held securely in escrow — '
              'not released to the helper until you confirm the service is done.',
              style: TextStyle(fontSize: 11, color: Color(0xFF0C4A6E), height: 1.5)),
        ])),
      ]),
    );
  }
}

class _TransactionsList extends StatelessWidget {
  final String uid; final bool escrowOnly;
  const _TransactionsList({required this.uid, required this.escrowOnly});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('transactions')
          .where('userId', isEqualTo: uid).limit(escrowOnly ? 30 : 40).snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: Color(0xFF7C3AED))));
        }
        final rawDocs = snap.data?.docs ?? [];
        final docs = rawDocs.where((d) {
          if (!escrowOnly) return true;
          return (d.data() as Map<String, dynamic>)['paymentStatus'] == 'in_escrow';
        }).toList()
          ..sort((a, b) {
            final aTs = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            final bTs = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            if (aTs == null && bTs == null) return 0;
            if (aTs == null) return 1;
            if (bTs == null) return -1;
            return bTs.compareTo(aTs);
          });
        if (docs.isEmpty) {
          return _EmptyState(
            icon: escrowOnly ? Icons.lock_clock_rounded : Icons.receipt_long_rounded,
            color: const Color(0xFF7C3AED), bg: const Color(0xFFEDE9FE),
            title: escrowOnly ? 'No funds in escrow' : 'No payments yet',
            sub: escrowOnly ? 'UPI payments held in escrow\nwill appear here.'
                : 'Your cash & UPI payment history\nwill appear here.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          itemCount: docs.length,
          itemBuilder: (_, i) => _TransactionCard(data: docs[i].data() as Map<String, dynamic>),
        );
      },
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _TransactionCard({required this.data});
  @override
  Widget build(BuildContext context) {
    final amount    = (data['amount']       as num?)?.toDouble() ?? 0.0;
    final mode      = data['paymentMode']   as String? ?? 'upi';
    final status    = data['paymentStatus'] as String? ?? 'pending';
    final service   = data['serviceName']   as String? ?? 'Service';
    final helper    = data['helperName']    as String? ?? 'Helper';
    final bookingId = data['bookingId']     as String? ?? '';
    final ts        = data['createdAt']     as Timestamp?;
    final meta      = _payMeta(status, mode);
    final isCash    = mode == 'cash';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))]),
      child: Column(children: [
        Padding(padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 46, height: 46,
                decoration: BoxDecoration(
                    color: isCash ? const Color(0xFFD1FAE5) : const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(13)),
                child: Icon(isCash ? Icons.payments_rounded : Icons.phone_android_rounded,
                    color: isCash ? const Color(0xFF059669) : const Color(0xFF7C3AED), size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(service, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
              const SizedBox(height: 3),
              Text('Helper: $helper', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              const SizedBox(height: 3),
              Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: isCash ? const Color(0xFFD1FAE5) : const Color(0xFFEDE9FE),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(isCash ? '💵 Cash' : '📱 UPI',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                            color: isCash ? const Color(0xFF059669) : const Color(0xFF7C3AED)))),
                if (ts != null) ...[const SizedBox(width: 8),
                  Text(_ft(ts.toDate()), style: const TextStyle(fontSize: 10, color: Color(0xFFB0B8CC)))],
              ]),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('₹${amount.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
              const SizedBox(height: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: meta.bg, borderRadius: BorderRadius.circular(10)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(meta.icon, size: 11, color: meta.color), const SizedBox(width: 4),
                    Text(meta.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: meta.color)),
                  ])),
            ]),
          ]),
        ),
        if (!isCash && status == 'in_escrow') ...[
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          _EscrowProgressRow(bookingId: bookingId),
        ],
      ]),
    );
  }
  String _ft(DateTime d) {
    const m = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${m[d.month]} · ${d.hour}:${d.minute.toString().padLeft(2,'0')}';
  }
}

class _EscrowProgressRow extends StatelessWidget {
  final String bookingId;
  const _EscrowProgressRow({required this.bookingId});
  @override
  Widget build(BuildContext context) {
    if (bookingId.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('bookings').doc(bookingId).snapshots(),
      builder: (_, snap) {
        final d = snap.data?.data() as Map<String, dynamic>? ?? {};
        final svcStatus     = d['serviceStatus']  as String? ?? 'pending';
        final proofUploaded = (d['proofUploaded'] as bool?) ?? false;
        final userConfirmed = (d['userConfirmed'] as bool?) ?? false;
        final step1 = svcStatus == 'completed' || svcStatus == 'confirmed';
        final step2 = proofUploaded; final step3 = userConfirmed;
        return Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ESCROW RELEASE PROGRESS', style: TextStyle(fontSize: 9,
                fontWeight: FontWeight.bold, color: Color(0xFF9CA3AF), letterSpacing: 1.2)),
            const SizedBox(height: 10),
            Row(children: [
              _EStep(done: step1, label: 'Service\nCompleted', icon: Icons.handyman_rounded),
              _ELine(done: step1 && step2),
              _EStep(done: step2, label: 'Proof\nUploaded', icon: Icons.upload_file_rounded),
              _ELine(done: step2 && step3),
              _EStep(done: step3, label: 'Funds\nReleased', icon: Icons.check_circle_rounded),
            ]),
          ]),
        );
      },
    );
  }
}

class _EStep extends StatelessWidget {
  final bool done; final String label; final IconData icon;
  const _EStep({required this.done, required this.label, required this.icon});
  @override
  Widget build(BuildContext context) => Column(children: [
    Container(width: 32, height: 32,
        decoration: BoxDecoration(color: done ? const Color(0xFF059669) : const Color(0xFFF3F4F6), shape: BoxShape.circle),
        child: Icon(icon, size: 16, color: done ? Colors.white : const Color(0xFFD1D5DB))),
    const SizedBox(height: 5),
    Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 9, height: 1.3,
        color: done ? const Color(0xFF059669) : const Color(0xFFB0B8CC),
        fontWeight: done ? FontWeight.bold : FontWeight.normal)),
  ]);
}

class _ELine extends StatelessWidget {
  final bool done;
  const _ELine({required this.done});
  @override
  Widget build(BuildContext context) => Expanded(child: Container(height: 2,
      margin: const EdgeInsets.only(bottom: 20),
      color: done ? const Color(0xFF059669) : const Color(0xFFE5E7EB)));
}

class _EmptyState extends StatelessWidget {
  final IconData icon; final Color color, bg; final String title, sub;
  const _EmptyState({required this.icon, required this.color, required this.bg,
    required this.title, required this.sub});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(40),
    child: Column(children: [
      Container(width: 80, height: 80, decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Icon(icon, size: 36, color: color)),
      const SizedBox(height: 16),
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
      const SizedBox(height: 8),
      Text(sub, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5)),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
//  SUPPORT SCREEN
// ═══════════════════════════════════════════════════════════════════════════
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: CustomScrollView(physics: const ClampingScrollPhysics(), slivers: [
        SliverToBoxAdapter(child: _SubHeader(
            title: 'Support & Help', subtitle: "We're here to help anytime",
            icon: Icons.headset_mic_rounded,
            colors: const [Color(0xFF78350F), Color(0xFFD97706), Color(0xFFFBBF24)],
            onBack: () => Navigator.pop(context))),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(delegate: SliverChildListDelegate([
            const Text('How can we help?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
            const SizedBox(height: 4),
            const Text('Browse guides, contact our team, or use the AI assistant',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _SQC(icon: Icons.menu_book_rounded, title: 'Help Center', subtitle: 'App guides & tutorials',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpCenterScreen())))),
              const SizedBox(width: 12),
              Expanded(child: _SQC(icon: Icons.help_outline_rounded, title: 'FAQs', subtitle: 'Common questions',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FaqScreen())))),
            ]),
            const SizedBox(height: 24),
            const Text('DIRECT ASSISTANCE', style: TextStyle(fontSize: 10,
                fontWeight: FontWeight.bold, color: Color(0xFF9CA3AF), letterSpacing: 1.4)),
            const SizedBox(height: 10),
            _SC(items: [
              _SR(icon: Icons.chat_bubble_rounded, title: 'Live Chat',
                  subtitle: 'Chat with our support team in real-time',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveChatScreen()))),
              _SR(icon: Icons.email_rounded, title: 'Email Support',
                  subtitle: 'Send us an email — response in 2 hours',
                  onTap: () => _launchUrl('mailto:vighyatojha@gmail.com?subject=Trouble%20Sarthi%20Support')),
              _SR(icon: Icons.emergency_rounded, title: 'Emergency Helplines',
                  subtitle: 'Ambulance, Police, Women safety & more',
                  isLast: true,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyScreen()))),
            ]),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiAgentScreen())),
              child: Container(
                width: double.infinity, padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF3B1F8C), Color(0xFF5B21B6)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(22)),
                child: Column(children: [
                  Container(width: 60, height: 60,
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                      child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 30)),
                  const SizedBox(height: 14),
                  const Text('Need Personal Help?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 6),
                  Text('Chat with our AI Sarthi Agent — always available, powered by Gemini.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.75), height: 1.4)),
                  const SizedBox(height: 18),
                  Container(width: double.infinity, height: 50,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.auto_awesome_rounded, color: Color(0xFF5B21B6), size: 20),
                      SizedBox(width: 10),
                      Text('Talk to AI Sarthi Agent', style: TextStyle(fontSize: 14,
                          fontWeight: FontWeight.bold, color: Color(0xFF5B21B6))),
                    ]),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 60),
          ])),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  HELP CENTER, FAQ, LIVE CHAT, EMERGENCY, AI AGENT SCREENS
//  (All kept intact from original — only referencing them for completeness)
// ═══════════════════════════════════════════════════════════════════════════
// These screens remain exactly as in your original file:
// HelpCenterScreen, FaqScreen, LiveChatScreen, EmergencyScreen,
// AiAgentScreen, _AiMessageBlock, _MenuCard, _NavButton,
// _TypingIndicator, _ChatBubble, _AccordionSection, _AccordionItem

// ═══════════════════════════════════════════════════════════════════════════
//  TERMS SCREEN (unchanged)
// ═══════════════════════════════════════════════════════════════════════════
class _TermsScreen extends StatelessWidget {
  const _TermsScreen();
  static const _sections = [
    {'title': '1. Acceptance of Terms',
      'body': 'By downloading or using Trouble Sarthi, you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use the app.'},
    {'title': '2. Services Provided',
      'body': 'Trouble Sarthi connects users with independent service providers ("Sarthi Helpers") for home services. We act as an intermediary platform.'},
    {'title': '3. Payments & Escrow',
      'body': 'UPI payments are held in escrow and released to helpers only after you confirm service completion. Refunds for disputed transactions are processed within 5–7 business days.'},
    {'title': '4. User Responsibilities',
      'body': 'You agree to provide accurate information, treat helpers respectfully, and not misuse the platform.'},
    {'title': '5. Privacy Policy',
      'body': 'We collect name, phone, email, and location data solely to provide our services. We do not sell your personal data to third parties.'},
    {'title': '6. Cancellation Policy',
      'body': 'Free cancellations are allowed up to 30 minutes before the scheduled service time. Late cancellations may attract a convenience fee of ₹20–₹50.'},
    {'title': '7. Contact Us',
      'body': 'For any questions: vighyatojha@gmail.com · Trouble Sarthi, Surat, Gujarat, India.'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: CustomScrollView(physics: const ClampingScrollPhysics(), slivers: [
        SliverToBoxAdapter(child: _SubHeader(title: 'Terms of Service', subtitle: 'Last updated: March 2025',
            icon: Icons.description_rounded,
            colors: const [Color(0xFF064E3B), Color(0xFF059669), Color(0xFF6EE7B7)],
            onBack: () => Navigator.pop(context))),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(delegate: SliverChildBuilderDelegate((_, i) {
            if (i == 0) {
              return Container(margin: const EdgeInsets.only(bottom: 20), padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF059669).withOpacity(0.25))),
                  child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.info_outline_rounded, color: Color(0xFF059669), size: 20),
                    SizedBox(width: 12),
                    Expanded(child: Text('Please read these terms carefully before using Trouble Sarthi.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF065F46), height: 1.5))),
                  ]));
            }
            if (i > _sections.length) return const SizedBox(height: 80);
            final s = _sections[i - 1];
            return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s['title']!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                  const SizedBox(height: 8),
                  Text(s['body']!, style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563), height: 1.6)),
                ]));
          }, childCount: _sections.length + 2)),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SHARED WIDGET ALIASES
// ═══════════════════════════════════════════════════════════════════════════
class _SQC extends StatelessWidget {
  final IconData icon; final String title, subtitle; final VoidCallback onTap;
  const _SQC({required this.icon, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0,3))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 42, height: 42,
            decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: const Color(0xFFD97706), size: 22)),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), height: 1.4)),
      ]),
    ),
  );
}

class _SC extends StatelessWidget {
  final List<_SR> items;
  const _SC({required this.items});
  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0,3))]),
      child: Column(children: items));
}

class _SR extends StatelessWidget {
  final IconData icon; final String title, subtitle;
  final bool isDestructive, isLast;
  final VoidCallback onTap;
  const _SR({required this.icon, required this.title, required this.subtitle,
    required this.onTap, this.isDestructive = false, this.isLast = false});
  @override
  Widget build(BuildContext context) {
    final c  = isDestructive ? const Color(0xFFDC2626) : const Color(0xFF5B21B6);
    final bg = isDestructive ? const Color(0xFFFEE2E2) : const Color(0xFFEDE9FE);
    return Material(color: Colors.transparent,
      child: InkWell(onTap: onTap,
        borderRadius: isLast ? const BorderRadius.vertical(bottom: Radius.circular(18)) : BorderRadius.zero,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          decoration: BoxDecoration(border: isLast ? null
              : const Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))),
          child: Row(children: [
            Container(width: 38, height: 38,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)),
                child: Icon(icon, color: c, size: 19)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                  color: isDestructive ? const Color(0xFFDC2626) : const Color(0xFF1F2937))),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
              ],
            ])),
            Icon(Icons.chevron_right_rounded,
                color: isDestructive ? const Color(0xFFDC2626).withOpacity(0.4) : const Color(0xFFD1D5DB), size: 20),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  FIRESTORE SECURITY RULES (reference — add to firestore.rules)
// ═══════════════════════════════════════════════════════════════════════════
/*
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Users — own data only
    match /users/{uid} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }

    // Bookings — users can read their own
    match /bookings/{bookingId} {
      allow read: if request.auth != null &&
          resource.data.userId == request.auth.uid;
      allow write: if false; // server-side only
    }

    // Transactions — users can read their own
    match /transactions/{txId} {
      allow read: if request.auth != null &&
          resource.data.userId == request.auth.uid;
      allow write: if false;
    }

    // Support chats — user owns their chat thread
    match /support_chats/{chatId} {
      allow read, write: if request.auth != null &&
          chatId == ('chat_' + request.auth.uid);

      match /messages/{msgId} {
        allow read, write: if request.auth != null &&
            chatId == ('chat_' + request.auth.uid);
      }
    }

    // Data export requests
    match /data_requests/{reqId} {
      allow create: if request.auth != null &&
          request.resource.data.uid == request.auth.uid;
      allow read: if false;
    }
  }
}
*/

// ═══════════════════════════════════════════════════════════════════════════
//  HELP CENTER SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  int? _openSection;

  static const _sections = [
    {
      'title': 'How to Contact Support Team',
      'icon': Icons.headset_mic_rounded,
      'color': Color(0xFF5B21B6),
      'bg': Color(0xFFEDE9FE),
      'content': [
        {
          'q': 'Live Chat',
          'a': 'Go to Support → Live Chat. Our team is available Mon–Sat, 9 AM to 9 PM IST. '
              'You\'ll be connected to a human agent within 2 minutes on average.',
        },
        {
          'q': 'Email Support',
          'a': 'Tap "Email Support" in the Support screen. This opens Gmail with our support address '
              '(vighyatojha@gmail.com) pre-filled. Typical response time is 2 hours during business days.',
        },
        {
          'q': 'AI Agent (24/7)',
          'a': 'The AI Sarthi Agent is powered by Gemini and available around the clock. '
              'It can answer questions about bookings, payments, helper status, app features, and more.',
        },
      ],
    },
    {
      'title': 'How to Book a Sarthi Helper',
      'icon': Icons.handyman_rounded,
      'color': Color(0xFF0891B2),
      'bg': Color(0xFFE0F2FE),
      'content': [
        {
          'q': 'Finding a Sarthi',
          'a': 'Open the Home screen and select your service category (Plumber, Electrician, etc.). '
              'Browse available helpers nearby and check their rating, reviews, and trust score.',
        },
        {
          'q': 'Scheduling',
          'a': 'Select your preferred date and time slot. You can book for immediate help '
              '(within the hour) or schedule up to 7 days in advance.',
        },
        {
          'q': 'Confirming a Booking',
          'a': 'Once you tap "Book Now", the helper gets notified instantly. You\'ll receive a '
              'confirmation with the helper\'s details, ETA, and booking ID.',
        },
        {
          'q': 'Cancellation Policy',
          'a': 'You can cancel for free up to 30 minutes before the scheduled time. '
              'Cancellations after that may attract a small convenience fee.',
        },
      ],
    },
    {
      'title': 'Payments & UPI Escrow',
      'icon': Icons.account_balance_wallet_rounded,
      'color': Color(0xFF059669),
      'bg': Color(0xFFD1FAE5),
      'content': [
        {
          'q': 'How does payment work?',
          'a': 'You can pay via UPI or cash. UPI payments go into a secure escrow hold — '
              'the helper is paid only after you confirm the service was completed satisfactorily.',
        },
        {
          'q': 'What is Escrow?',
          'a': 'Escrow means your money is safely held by us — not given to the helper until the '
              'job is done and you approve. This protects you from bad service.',
        },
        {
          'q': 'Refund Policy',
          'a': 'If the service wasn\'t completed or you\'re unsatisfied, raise a dispute within '
              '24 hours. Our team reviews it within 48 hours and initiates a refund if valid.',
        },
      ],
    },
    {
      'title': 'Trust & Safety Features',
      'icon': Icons.verified_user_rounded,
      'color': Color(0xFFD97706),
      'bg': Color(0xFFFEF3C7),
      'content': [
        {
          'q': 'Trust Score',
          'a': 'Every helper has a Trust Score based on past jobs, reviews, on-time rate, and '
              'background check status. Higher score = more reliable helper.',
        },
        {
          'q': 'Safety Reporting',
          'a': 'If you feel unsafe, use the SOS button on the booking screen. You can also '
              'report a helper via the booking detail page.',
        },
        {
          'q': 'Female Safety Option',
          'a': 'Female users can request female helpers or police-verified contacts via the '
              'Emergency Helplines screen in Support.',
        },
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _SubHeader(
              title: 'Help Center',
              subtitle: 'Guides & how-to articles',
              icon: Icons.menu_book_rounded,
              colors: const [Color(0xFF78350F), Color(0xFFD97706), Color(0xFFFBBF24)],
              onBack: () => Navigator.pop(context),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (_, i) {
                  if (i < _sections.length) {
                    final s = _sections[i];
                    final isOpen = _openSection == i;
                    final items = s['content'] as List<Map<String, String>>;
                    return _AccordionSection(
                      title: s['title'] as String,
                      icon: s['icon'] as IconData,
                      color: s['color'] as Color,
                      bg: s['bg'] as Color,
                      items: items,
                      isOpen: isOpen,
                      onTap: () => setState(() => _openSection = isOpen ? null : i),
                    );
                  }
                  return const SizedBox(height: 80);
                },
                childCount: _sections.length + 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccordionSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color, bg;
  final List<Map<String, String>> items;
  final bool isOpen;
  final VoidCallback onTap;

  const _AccordionSection({
    required this.title, required this.icon, required this.color,
    required this.bg, required this.items, required this.isOpen, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Container(width: 42, height: 42,
                      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                      child: Icon(icon, color: color, size: 22)),
                  const SizedBox(width: 14),
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 14,
                      fontWeight: FontWeight.bold, color: Color(0xFF1F2937)))),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down_rounded, color: color, size: 24),
                  ),
                ]),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: isOpen
                  ? Column(
                children: items.asMap().entries.map((e) {
                  return _AccordionItem(
                    question: e.value['q']!,
                    answer: e.value['a']!,
                    isLast: e.key == items.length - 1,
                    accentColor: color,
                  );
                }).toList(),
              )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccordionItem extends StatefulWidget {
  final String question, answer;
  final bool isLast;
  final Color accentColor;
  const _AccordionItem({required this.question, required this.answer,
    required this.isLast, required this.accentColor});
  @override
  State<_AccordionItem> createState() => _AccordionItemState();
}

class _AccordionItemState extends State<_AccordionItem> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFB),
        border: Border(top: BorderSide(color: widget.accentColor.withOpacity(0.12))),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _open = !_open),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              child: Row(children: [
                Icon(Icons.circle, size: 6,
                    color: _open ? widget.accentColor : const Color(0xFFD1D5DB)),
                const SizedBox(width: 10),
                Expanded(child: Text(widget.question, style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _open ? widget.accentColor : const Color(0xFF374151)))),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(Icons.keyboard_arrow_down_rounded,
                      color: widget.accentColor, size: 20),
                ),
              ]),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _open
                ? Container(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
              child: Text(widget.answer,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563), height: 1.6)),
            )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  FAQ SCREEN
// ═══════════════════════════════════════════════════════════════════════════
class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});
  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  int? _openIdx;

  static const _faqs = [
    {'q': 'What is Trouble Sarthi?',
      'a': 'Trouble Sarthi is your on-demand home services platform. You can book verified plumbers, electricians, carpenters, cleaners, and more with just a few taps.'},
    {'q': 'How are helpers verified?',
      'a': 'All helpers undergo background checks, ID verification, skill tests, and are rated by previous customers. You can see their Trust Score before booking.'},
    {'q': 'Is it safe to pay via UPI?',
      'a': 'Yes! UPI payments are held in escrow and only released to the helper after you confirm the job is done. Your money is protected at all times.'},
    {'q': 'Can I cancel a booking?',
      'a': 'Yes. Free cancellation up to 30 minutes before the scheduled time. Late cancellations may attract a small convenience fee of ₹20-50.'},
    {'q': 'What if I\'m not satisfied with the service?',
      'a': 'Raise a dispute within 24 hours of service completion. Our team will review it within 48 hours and issue a full or partial refund if valid.'},
    {'q': 'Is there a female safety feature?',
      'a': 'Yes! Female users can request female helpers, and the Emergency screen has a dedicated Trouble Sarthi safety line that dispatches verified female helpers or police to your location.'},
    {'q': 'How do I update my profile?',
      'a': 'Go to Profile → Edit Profile. You can update your name, photo, phone, date of birth, emergency contact, and more. 100% profile completion improves your Trust Score.'},
    {'q': 'Is the AI Support Agent accurate?',
      'a': 'The AI Sarthi Agent uses Gemini and is trained on our app knowledge. It handles most questions instantly. Complex issues are escalated to our human team.'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _SubHeader(
              title: 'FAQs',
              subtitle: 'Frequently asked questions',
              icon: Icons.help_outline_rounded,
              colors: const [Color(0xFF78350F), Color(0xFFD97706), Color(0xFFFBBF24)],
              onBack: () => Navigator.pop(context),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (_, i) {
                  if (i >= _faqs.length) return const SizedBox(height: 80);
                  final faq = _faqs[i];
                  final isOpen = _openIdx == i;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: isOpen
                              ? const Color(0xFFD97706).withOpacity(0.4)
                              : Colors.transparent),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Column(children: [
                        GestureDetector(
                          onTap: () => setState(() => _openIdx = isOpen ? null : i),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            child: Row(children: [
                              Expanded(child: Text(faq['q']!, style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600,
                                  color: isOpen
                                      ? const Color(0xFFD97706)
                                      : const Color(0xFF1F2937)))),
                              AnimatedRotation(
                                turns: isOpen ? 0.5 : 0,
                                duration: const Duration(milliseconds: 180),
                                child: const Icon(Icons.keyboard_arrow_down_rounded,
                                    color: Color(0xFFD97706), size: 22),
                              ),
                            ]),
                          ),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          child: isOpen
                              ? Container(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Text(faq['a']!,
                                style: const TextStyle(
                                    fontSize: 13, color: Color(0xFF4B5563), height: 1.6)),
                          )
                              : const SizedBox.shrink(),
                        ),
                      ]),
                    ),
                  );
                },
                childCount: _faqs.length + 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  LIVE CHAT SCREEN
// ═══════════════════════════════════════════════════════════════════════════
class LiveChatScreen extends StatefulWidget {
  const LiveChatScreen({super.key});
  @override
  State<LiveChatScreen> createState() => _LiveChatScreenState();
}

class _LiveChatScreenState extends State<LiveChatScreen> {
  final _msgCtrl   = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;
  late final String _chatId;
  late final String _uid;
  late final String _userName;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _uid      = user?.uid ?? 'guest';
    _userName = user?.displayName ?? user?.email ?? 'User';
    _chatId   = 'chat_$_uid';
    _ensureChatDoc();
  }

  Future<void> _ensureChatDoc() async {
    final ref  = FirebaseFirestore.instance.collection('support_chats').doc(_chatId);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'userId':        _uid,
        'userName':      _userName,
        'status':        'open',
        'lastMessage':   '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'createdAt':     FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    _msgCtrl.clear();
    try {
      final batch  = FirebaseFirestore.instance.batch();
      final msgRef = FirebaseFirestore.instance
          .collection('support_chats').doc(_chatId)
          .collection('messages').doc();
      batch.set(msgRef, {
        'text':       text,
        'senderId':   _uid,
        'senderName': _userName,
        'senderRole': 'user',
        'createdAt':  FieldValue.serverTimestamp(),
        'read':       false,
      });
      batch.update(
        FirebaseFirestore.instance.collection('support_chats').doc(_chatId),
        {'lastMessage': text, 'lastMessageAt': FieldValue.serverTimestamp(), 'userName': _userName},
      );
      await batch.commit();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to send: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ));
      }
    }
    if (mounted) setState(() => _sending = false);
    await Future.delayed(const Duration(milliseconds: 100));
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() { _msgCtrl.dispose(); _scrollCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: Column(children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [Color(0xFF1E0640), Color(0xFF5B21B6), Color(0xFF7C3AED)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 20, 28),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                Container(width: 40, height: 40,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18), shape: BoxShape.circle),
                    child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 22)),
                const SizedBox(width: 10),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Live Support Chat', style: TextStyle(fontSize: 16,
                      fontWeight: FontWeight.bold, color: Colors.white)),
                  Text('Our team typically replies in 2 minutes',
                      style: TextStyle(fontSize: 11, color: Colors.white70)),
                ])),
                Container(width: 10, height: 10,
                    decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle)),
                const SizedBox(width: 4),
                const Text('Online', style: TextStyle(fontSize: 11, color: Colors.white70)),
              ]),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('support_chats').doc(_chatId)
                .collection('messages')
                .orderBy('createdAt', descending: false)
                .snapshots(),
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)));
              }
              final docs = snap.data?.docs ?? [];
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollCtrl.hasClients) {
                  _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
                }
              });
              if (docs.isEmpty) {
                return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 72, height: 72,
                      decoration: const BoxDecoration(
                          color: Color(0xFFEDE9FE), shape: BoxShape.circle),
                      child: const Icon(Icons.chat_bubble_outline_rounded,
                          color: Color(0xFF7C3AED), size: 32)),
                  const SizedBox(height: 12),
                  const Text('Start a conversation', style: TextStyle(fontSize: 15,
                      fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                  const SizedBox(height: 6),
                  const Text('Our support team is ready to help!',
                      style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                ]));
              }
              return ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final d     = docs[i].data() as Map<String, dynamic>;
                  final isUser = d['senderId'] == _uid;
                  final text  = d['text'] as String? ?? '';
                  final ts    = d['createdAt'] as Timestamp?;
                  return _ChatBubble(text: text, isUser: isUser, timestamp: ts);
                },
              );
            },
          ),
        ),
        Container(
          padding: EdgeInsets.only(
              left: 16, right: 16, top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16),
          decoration: BoxDecoration(color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
                  blurRadius: 10, offset: const Offset(0, -3))]),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _msgCtrl,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Type your message...',
                  hintStyle: const TextStyle(color: Color(0xFFD1D5DB)),
                  filled: true, fillColor: const Color(0xFFF4F6FB),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _sending ? null : _sendMessage,
              child: Container(
                width: 48, height: 48,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Color(0xFF5B21B6), Color(0xFF7C3AED)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  shape: BoxShape.circle,
                ),
                child: _sending
                    ? const Center(child: SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final Timestamp? timestamp;
  const _ChatBubble({required this.text, required this.isUser, required this.timestamp});

  @override
  Widget build(BuildContext context) {
    final time = timestamp != null
        ? '${timestamp!.toDate().hour}:${timestamp!.toDate().minute.toString().padLeft(2, '0')}'
        : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(width: 32, height: 32, margin: const EdgeInsets.only(right: 8),
                decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Color(0xFF5B21B6), Color(0xFF7C3AED)]),
                    shape: BoxShape.circle),
                child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 16)),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isUser
                        ? const LinearGradient(
                        colors: [Color(0xFF5B21B6), Color(0xFF7C3AED)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight)
                        : null,
                    color: isUser ? null : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft:     const Radius.circular(18),
                      topRight:    const Radius.circular(18),
                      bottomLeft:  Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
                        blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Text(text, style: TextStyle(fontSize: 14,
                      color: isUser ? Colors.white : const Color(0xFF1F2937), height: 1.4)),
                ),
                if (time.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                    child: Text(time,
                        style: const TextStyle(fontSize: 10, color: Color(0xFFB0B8CC))),
                  ),
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  EMERGENCY SCREEN
// ═══════════════════════════════════════════════════════════════════════════
class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  Future<void> _call(String number) async {
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _SubHeader(
              title: 'Emergency Helplines',
              subtitle: 'Tap any number to call instantly',
              icon: Icons.emergency_rounded,
              colors: const [Color(0xFF7F1D1D), Color(0xFFDC2626), Color(0xFFF87171)],
              onBack: () => Navigator.pop(context),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF7F1D1D), Color(0xFFDC2626)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(
                        color: const Color(0xFFDC2626).withOpacity(0.30),
                        blurRadius: 14, offset: const Offset(0, 5))],
                  ),
                  child: const Row(children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('In immediate danger?', style: TextStyle(fontSize: 15,
                          fontWeight: FontWeight.bold, color: Colors.white)),
                      SizedBox(height: 3),
                      Text('Call 112 — India\'s all-in-one Emergency Number',
                          style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.4)),
                    ])),
                  ]),
                ),
                const SizedBox(height: 20),
                _emergencyLabel('🚨  GOVERNMENT EMERGENCY NUMBERS'),
                const SizedBox(height: 10),
                _emergencyCard('Police Control Room',        '100',          Icons.local_police_rounded,          const Color(0xFF1E40AF), const Color(0xFFEFF6FF), _call),
                _emergencyCard('Ambulance / Medical',        '108',          Icons.emergency_rounded,              const Color(0xFFDC2626), const Color(0xFFFFF1F2), _call),
                _emergencyCard('Fire Brigade',               '101',          Icons.local_fire_department_rounded,  const Color(0xFFEA580C), const Color(0xFFFFF7ED), _call),
                _emergencyCard('National Emergency Number',  '112',          Icons.sos_rounded,                    const Color(0xFF7C3AED), const Color(0xFFF5F3FF), _call),
                _emergencyCard('Women Helpline (National)',  '1091',         Icons.female_rounded,                 const Color(0xFFDB2777), const Color(0xFFFDF2F8), _call),
                _emergencyCard('Women SOS (Himmat App)',     '100',          Icons.shield_rounded,                 const Color(0xFF9333EA), const Color(0xFFF5F3FF), _call),
                _emergencyCard('Child Helpline',             '1098',         Icons.child_friendly_rounded,         const Color(0xFF059669), const Color(0xFFF0FDF4), _call),
                _emergencyCard('Senior Citizen Helpline',    '14567',        Icons.elderly_rounded,                const Color(0xFF0891B2), const Color(0xFFECFEFF), _call),
                _emergencyCard('Disaster Management (NDMA)', '1078',         Icons.flood_rounded,                  const Color(0xFF0369A1), const Color(0xFFE0F2FE), _call),
                _emergencyCard('Anti-Poison Helpline',       '1800-11-6117', Icons.medical_services_rounded,       const Color(0xFF15803D), const Color(0xFFF0FDF4), _call),
                const SizedBox(height: 20),
                _emergencyLabel('💜  TROUBLE SARTHI SAFETY LINE'),
                const SizedBox(height: 8),
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF3B1F8C), Color(0xFF5B21B6), Color(0xFF7C3AED)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(
                        color: const Color(0xFF5B21B6).withOpacity(0.30),
                        blurRadius: 14, offset: const Offset(0, 5))],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(width: 48, height: 48,
                            decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18), shape: BoxShape.circle),
                            child: const Icon(Icons.security_rounded, color: Colors.white, size: 26)),
                        const SizedBox(width: 14),
                        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Trouble Sarthi Safety Helpline', style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                          Text('+91 94270 00000 (Placeholder)',
                              style: TextStyle(fontSize: 12, color: Colors.white70)),
                        ])),
                      ]),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12)),
                        child: const Text(
                          '🛡️  Especially for women & lone users — Calling this number dispatches '
                              'the nearest verified Trouble Sarthi helper AND alerts the local police station. '
                              'Female police officers and female Sarthi helpers will be sent to your location ASAP.',
                          style: TextStyle(fontSize: 12, color: Colors.white, height: 1.5),
                        ),
                      ),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: () => _call('+919427000000'),
                        child: Container(
                          width: double.infinity, height: 48,
                          decoration: BoxDecoration(
                              color: Colors.white, borderRadius: BorderRadius.circular(12)),
                          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.call_rounded, color: Color(0xFF5B21B6), size: 20),
                            SizedBox(width: 10),
                            Text('Call Trouble Sarthi Safety Line', style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF5B21B6))),
                          ]),
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emergencyLabel(String t) => Text(t, style: const TextStyle(
      fontSize: 10, fontWeight: FontWeight.bold,
      color: Color(0xFF9CA3AF), letterSpacing: 1.2));

  Widget _emergencyCard(String name, String number, IconData icon,
      Color color, Color bg, Future<void> Function(String) onCall) {
    return GestureDetector(
      onTap: () => onCall(number),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
                blurRadius: 8, offset: const Offset(0, 2))]),
        child: Row(children: [
          Container(width: 44, height: 44,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937))),
            Text(number, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          ])),
          Container(width: 40, height: 40,
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.call_rounded, color: color, size: 20)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  AI AGENT — Navigation state + message model
// ═══════════════════════════════════════════════════════════════════════════
enum _AiNavState { welcome, mainMenu, subMenu, answer }

class _AiMsg {
  final String text;
  final bool isUser;
  final _AiNavState? menuState;
  final String? subMenuParentId;
  const _AiMsg({
    required this.text, required this.isUser,
    this.menuState, this.subMenuParentId,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
//  AI AGENT SCREEN
// ═══════════════════════════════════════════════════════════════════════════
class AiAgentScreen extends StatefulWidget {
  const AiAgentScreen({super.key});
  @override
  State<AiAgentScreen> createState() => _AiAgentScreenState();
}

class _AiAgentScreenState extends State<AiAgentScreen> {
  static const _geminiApiKey = 'YOUR_GEMINI_API_KEY';

  final _scrollCtrl = ScrollController();
  final List<_AiMsg> _messages = [];
  bool _loading = false;

  late final String _uid;
  late final String _userName;

  List<Map<String, dynamic>> _userBookings = [];
  bool _bookingsLoaded = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _uid      = user?.uid ?? 'guest';
    _userName = user?.displayName ?? user?.email?.split('@').first ?? 'User';
    _loadBookings();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pushWelcome());
  }

  @override
  void dispose() { _scrollCtrl.dispose(); super.dispose(); }

  Future<void> _loadBookings() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('bookings').where('userId', isEqualTo: _uid).limit(5).get();
      _userBookings = snap.docs.map((d) => d.data()).toList();
      _bookingsLoaded = true;
    } catch (_) { _bookingsLoaded = true; }
  }

  String _buildBookingContext() {
    if (_userBookings.isEmpty) return '';
    final lines = _userBookings.map((b) {
      final service = b['serviceName'] as String? ?? 'Service';
      final status  = b['status']      as String? ?? 'unknown';
      final helper  = b['helperName']  as String? ?? 'Unknown helper';
      return '• $service with $helper — status: $status';
    }).join('\n');
    return '\n\nUser\'s recent bookings:\n$lines';
  }

  void _pushWelcome() {
    setState(() {
      _messages.add(_AiMsg(
        text: 'Hi ${_userName.split(' ').first}! 👋\n\n'
            'I\'m Sarthi, your AI assistant.\n'
            'What can I help you with today?',
        isUser: false,
        menuState: _AiNavState.mainMenu,
      ));
    });
  }

  void _onMainMenuTap(Map<String, String> item) {
    final id    = item['id']!;
    final label = item['label']!;
    setState(() { _messages.add(_AiMsg(text: label, isUser: true)); _loading = true; });
    _scrollToBottom();
    if (id == 'human') { _loading = false; _redirectToLiveChat(); return; }
    final subItems = kSubMenuItems[id];
    if (subItems == null || subItems.isEmpty) { setState(() => _loading = false); return; }
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _messages.add(_AiMsg(text: 'Sure! What specifically can I help you with?',
            isUser: false, menuState: _AiNavState.subMenu, subMenuParentId: id));
      });
      _scrollToBottom();
    });
  }

  void _onSubMenuTap(Map<String, String> item, String parentId) {
    final id    = item['id']!;
    final label = item['label']!;
    setState(() { _messages.add(_AiMsg(text: label, isUser: true)); _loading = true; });
    _scrollToBottom();
    String enriched = kAnswers[id] ?? '';
    if (parentId == 'bookings' && _bookingsLoaded && _userBookings.isNotEmpty) {
      if (id == 'book_status' || id == 'book_cancel' || id == 'book_noshow') {
        final latest  = _userBookings.first;
        final service = latest['serviceName'] as String? ?? 'your last service';
        final status  = latest['status']      as String? ?? 'unknown';
        enriched = 'Based on your latest booking ($service — $status):\n\n$enriched';
      }
    }
    if (enriched.isNotEmpty) {
      final ms = (enriched.length * 1.8).clamp(1000.0, 1800.0).toInt();
      Future.delayed(Duration(milliseconds: ms), () {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _messages.add(_AiMsg(text: enriched, isUser: false,
              menuState: _AiNavState.answer, subMenuParentId: parentId));
        });
        _scrollToBottom();
      });
    } else {
      _callGeminiForAnswer(label, parentId);
    }
  }

  Future<void> _callGeminiForAnswer(String question, String parentId) async {
    setState(() => _loading = true);
    _scrollToBottom();
    try {
      final bookingCtx = _buildBookingContext();
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/'
              'gemini-1.5-flash:generateContent?key=$_geminiApiKey');
      final body = jsonEncode({
        'contents': [
          {'role': 'user',  'parts': [{'text': kAiSystemPrompt + bookingCtx}]},
          {'role': 'model', 'parts': [{'text': 'Understood! I am Sarthi. How can I help?'}]},
          {'role': 'user',  'parts': [{'text': question}]},
        ],
        'generationConfig': {'maxOutputTokens': 512, 'temperature': 0.7},
      });
      final res = await http.post(url,
          headers: {'Content-Type': 'application/json'}, body: body);
      String reply = "I couldn't get an answer right now. 🙏\n\nPlease try Live Chat for immediate help.";
      if (res.statusCode == 200) {
        final decoded    = jsonDecode(res.body) as Map<String, dynamic>;
        final candidates = decoded['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final parts = candidates[0]['content']?['parts'] as List<dynamic>?;
          if (parts != null && parts.isNotEmpty) {
            reply = parts[0]['text'] as String? ?? reply;
          }
        }
      }
      if (mounted) {
        setState(() {
          _loading = false;
          _messages.add(_AiMsg(text: reply.trim(), isUser: false,
              menuState: _AiNavState.answer, subMenuParentId: parentId));
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _messages.add(_AiMsg(
              text: "I couldn't connect right now. 🙏\n\nPlease use Live Chat for immediate help.",
              isUser: false, menuState: _AiNavState.answer, subMenuParentId: parentId));
        });
        _scrollToBottom();
      }
    }
  }

  void _goToPreviousMenu(String parentId) {
    setState(() => _loading = true);
    _scrollToBottom();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _messages.add(_AiMsg(text: 'Sure, here are more options:',
            isUser: false, menuState: _AiNavState.subMenu, subMenuParentId: parentId));
      });
      _scrollToBottom();
    });
  }

  void _goToMainMenu() {
    setState(() => _loading = true);
    _scrollToBottom();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _messages.add(_AiMsg(text: 'What else can I help you with?',
            isUser: false, menuState: _AiNavState.mainMenu));
      });
      _scrollToBottom();
    });
  }

  void _redirectToLiveChat() {
    setState(() {
      _messages.add(const _AiMsg(
          text: 'Connecting you to our support team...', isUser: false));
    });
    _scrollToBottom();
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        Navigator.push(context, PageRouteBuilder(
          pageBuilder: (_, animation, __) => const LiveChatScreen(),
          transitionsBuilder: (_, animation, __, child) => SlideTransition(
            position: Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 400),
        ));
      }
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: Column(children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E0640), Color(0xFF5B21B6), Color(0xFF7C3AED)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 20, 28),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                Container(width: 44, height: 44,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18), shape: BoxShape.circle),
                    child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22)),
                const SizedBox(width: 10),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Sarthi AI Agent', style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text('Powered by Gemini · Available 24/7',
                      style: TextStyle(fontSize: 11, color: Colors.white70)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.circle, color: Color(0xFF22C55E), size: 8),
                    SizedBox(width: 5),
                    Text('Active', style: TextStyle(fontSize: 11, color: Colors.white,
                        fontWeight: FontWeight.w600)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: _messages.length + (_loading ? 1 : 0),
            itemBuilder: (_, i) {
              if (i == _messages.length) return const _TypingIndicator();
              final msg = _messages[i];
              return _AiMessageBlock(
                msg: msg,
                onMainMenuTap: _onMainMenuTap,
                onSubMenuTap:  _onSubMenuTap,
                onGoBack:      _goToPreviousMenu,
                onGoMain:      _goToMainMenu,
                onLiveChat:    _redirectToLiveChat,
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  AI MESSAGE BLOCK
// ═══════════════════════════════════════════════════════════════════════════
class _AiMessageBlock extends StatelessWidget {
  final _AiMsg msg;
  final void Function(Map<String, String>) onMainMenuTap;
  final void Function(Map<String, String>, String) onSubMenuTap;
  final void Function(String) onGoBack;
  final VoidCallback onGoMain;
  final VoidCallback onLiveChat;

  const _AiMessageBlock({
    required this.msg, required this.onMainMenuTap, required this.onSubMenuTap,
    required this.onGoBack, required this.onGoMain, required this.onLiveChat,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!msg.isUser)
              Container(width: 32, height: 32,
                  margin: const EdgeInsets.only(right: 8, bottom: 4),
                  decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFF5B21B6), Color(0xFF7C3AED)]),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 15)),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  gradient: msg.isUser
                      ? const LinearGradient(colors: [Color(0xFF5B21B6), Color(0xFF7C3AED)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight)
                      : null,
                  color: msg.isUser ? null : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft:     const Radius.circular(18),
                    topRight:    const Radius.circular(18),
                    bottomLeft:  Radius.circular(msg.isUser ? 18 : 4),
                    bottomRight: Radius.circular(msg.isUser ? 4 : 18),
                  ),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
                      blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Text(msg.text, style: TextStyle(fontSize: 14, height: 1.5,
                    color: msg.isUser ? Colors.white : const Color(0xFF1F2937))),
              ),
            ),
          ],
        ),
        if (!msg.isUser && msg.menuState != null) ...[
          const SizedBox(height: 8),
          _buildMenu(msg.menuState!, msg.subMenuParentId),
          const SizedBox(height: 16),
        ] else
          const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildMenu(_AiNavState state, String? parentId) {
    switch (state) {
      case _AiNavState.mainMenu:
        return _MenuCard(items: kMainMenuItems, onTap: (item) => onMainMenuTap(item));

      case _AiNavState.subMenu:
        final items = kSubMenuItems[parentId ?? ''] ?? [];
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _MenuCard(items: items, onTap: (item) => onSubMenuTap(item, parentId ?? '')),
          const SizedBox(height: 8),
          _NavButton(icon: Icons.home_rounded, label: '← Go to Main Menu',
              onTap: onGoMain, color: const Color(0xFF5B21B6)),
        ]);

      case _AiNavState.answer:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _NavButton(icon: Icons.arrow_back_rounded, label: '← Go to Previous Menu',
              onTap: () => onGoBack(parentId ?? ''), color: const Color(0xFF5B21B6)),
          const SizedBox(height: 8),
          _NavButton(icon: Icons.home_rounded, label: '⌂  Go to Main Menu',
              onTap: onGoMain, color: const Color(0xFF374151)),
          const SizedBox(height: 8),
          _NavButton(icon: Icons.support_agent_rounded, label: '💬  Talk to Support Team',
              onTap: onLiveChat, color: const Color(0xFF059669), filled: true),
        ]);

      default:
        return const SizedBox.shrink();
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  MENU CARD
// ═══════════════════════════════════════════════════════════════════════════
class _MenuCard extends StatelessWidget {
  final List<Map<String, String>> items;
  final void Function(Map<String, String>) onTap;
  const _MenuCard({required this.items, required this.onTap});

  static const _shadow = [BoxShadow(
      color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 3))];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(16), boxShadow: _shadow),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: items.asMap().entries.map((e) {
            final isLast = e.key == items.length - 1;
            final item   = e.value;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onTap(item),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(border: isLast ? null
                      : const Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))),
                  child: Row(children: [
                    const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF7C3AED), size: 12),
                    const SizedBox(width: 12),
                    Expanded(child: Text(item['label']!, style: const TextStyle(
                        fontSize: 13, color: Color(0xFF1F2937), fontWeight: FontWeight.w500))),
                  ]),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  NAV BUTTON
// ═══════════════════════════════════════════════════════════════════════════
class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool filled;

  const _NavButton({
    required this.icon, required this.label, required this.onTap,
    required this.color, this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: filled ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: filled ? null : Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: filled ? Colors.white : color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: filled ? Colors.white : color)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TYPING INDICATOR
// ═══════════════════════════════════════════════════════════════════════════
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(width: 32, height: 32, margin: const EdgeInsets.only(right: 8),
            decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF5B21B6), Color(0xFF7C3AED)]),
                shape: BoxShape.circle),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 15)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: Colors.white,
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18), topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4), bottomRight: Radius.circular(18)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
                  blurRadius: 6, offset: const Offset(0, 2))]),
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: [
              _buildDot(0.0), _buildDot(0.33), _buildDot(0.66),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildDot(double offset) {
    final phase  = ((_ctrl.value - offset) % 1.0 + 1.0) % 1.0;
    final t      = phase < 0.5 ? (phase * 2) : (1.0 - (phase - 0.5) * 2);
    final eased  = Curves.easeInOut.transform(t);
    return Container(
      width: 8, height: 8,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: Color.lerp(const Color(0xFFD1D5DB), const Color(0xFF7C3AED), eased),
        shape: BoxShape.circle,
      ),
    );
  }
}