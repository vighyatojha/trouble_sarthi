// ignore_for_file: use_build_context_synchronously
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trouble_sarthi/screens/about_screen.dart';
import 'package:trouble_sarthi/service/firebase_storage_service.dart';
import 'package:trouble_sarthi/service/image_picker_service.dart';

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
                          // Settings icon at top-right already navigates here — text label removed
                          _GItem(Icons.help_rounded, 'Support', 'Help center & contact us',
                              isLast: true,
                                  () => _push(ctx, const SupportScreen())),
                        ],
                      ),

                      const SizedBox(height: 28),
                      _LogOut(),
                      const SizedBox(height: 14),
                      const Center(
                        child: Text('Version 2.4.1 (Indigo)',
                            style: TextStyle(fontSize: 11, color: Color(0xFFB0B8CC))),
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
//  GRADIENT HEADER  — same dark-purple palette as Home/Trust
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
                // ── Top bar ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Row(children: [
                    const Text('Profile', style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                    const Spacer(),
                    // Settings icon only — no duplicate "App Settings" in menu list
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
                        child: const Icon(Icons.settings_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 24),

                // ── Avatar ───────────────────────────────────────────────
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

                // ── Completion bar (tappable) ─────────────────────────────
                GestureDetector(
                  onTap: () {
                    if (pending.isNotEmpty) {
                      showModalBottomSheet(
                        context: context, backgroundColor: Colors.transparent,
                        useSafeArea: true, isScrollControlled: true,
                        builder: (_) => _PendingSheet(pending: pending),
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
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        const Spacer(),
                        Text('$pct%',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        if (pct < 100) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10)),
                            child: const Text("What's missing?",
                                style: TextStyle(fontSize: 9, color: Colors.white,
                                    fontWeight: FontWeight.w600)),
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
                            color: pct == 100
                                ? const Color(0xFF86EFAC)
                                : Colors.white.withOpacity(0.75),
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
        // White rounded bottom
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
  const _PendingSheet({required this.pending});

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
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF5B21B6), Color(0xFF7C3AED)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.checklist_rounded, color: Colors.white, size: 26),
        ),
        const SizedBox(height: 14),
        const Text('Complete Your Profile',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
        const SizedBox(height: 6),
        Text('${pending.length} item${pending.length == 1 ? '' : 's'} still missing',
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        const SizedBox(height: 20),
        ...pending.map((f) => Container(
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
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF7C3AED), size: 20),
          ]),
        )),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity, height: 50,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED), elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Complete Now', style: TextStyle(fontSize: 14,
                fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  GRADIENT MENU
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

class _GItem extends StatefulWidget {
  final IconData icon;
  final String label, subtitle;
  final VoidCallback onTap;
  final bool isLast;
  const _GItem(this.icon, this.label, this.subtitle, this.onTap, {this.isLast = false});

  @override
  State<_GItem> createState() => _GItemState();
}

class _GItemState extends State<_GItem> {
  bool _p = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _p = true),
      onTapUp:   (_) { setState(() => _p = false); widget.onTap(); },
      onTapCancel: () => setState(() => _p = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: _p ? Colors.white.withOpacity(0.12) : Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          decoration: BoxDecoration(
            border: widget.isLast ? null
                : Border(bottom: BorderSide(color: Colors.white.withOpacity(0.15))),
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(widget.icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.label, style: const TextStyle(fontSize: 14,
                  fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 2),
              Text(widget.subtitle, style: TextStyle(
                  fontSize: 11, color: Colors.white.withOpacity(0.72))),
            ])),
            Icon(Icons.chevron_right_rounded,
                color: Colors.white.withOpacity(0.60), size: 20),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  LOG OUT
// ═══════════════════════════════════════════════════════════════════════════
class _LogOut extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Log Out?',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              content: const Text('Are you sure you want to log out?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280)))),
                TextButton(onPressed: () => Navigator.pop(context, true),
                    child: const Text('Log Out', style: TextStyle(
                        color: Color(0xFFDC2626), fontWeight: FontWeight.bold))),
              ],
            ),
          );
          if (ok == true) {
            await FirebaseAuth.instance.signOut();
            Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(color: const Color(0xFFFFF1F1),
              borderRadius: BorderRadius.circular(16)),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 20),
            SizedBox(width: 10),
            Text('Log Out', style: TextStyle(fontSize: 15,
                fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  EDIT PROFILE SHEET
// ═══════════════════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════════════════
//  EDIT PROFILE SHEET
//
//  - Fetches LIVE from Firestore on open (never stale)
//  - Validates name (required), phone (digits only), emergency (digits only)
//  - Email shown as read-only info (Firebase requires re-auth to change email)
//  - Writes every field with merge:true so unrelated fields are never wiped
//  - Updates Firebase Auth displayName in parallel
//  - Shows green success banner before closing
// ═══════════════════════════════════════════════════════════════════════════
class EditProfileSheet extends StatefulWidget {
  // data + user still accepted so callers don't need to change,
  // but we always re-fetch fresh from Firestore inside initState.
  final Map<String, dynamic> data;
  final User? user;
  const EditProfileSheet({super.key, required this.data, required this.user});

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  // Controllers
  final _nameCtrl      = TextEditingController();
  final _phoneCtrl     = TextEditingController();
  final _dobCtrl       = TextEditingController();
  final _emergencyCtrl = TextEditingController();

  String? _gender;
  bool _loading  = true; // true while fetching fresh data from Firestore
  bool _saving   = false;
  bool _saved    = false; // shows success banner

  // ── Photo state ────────────────────────────────────────────────────────────
  File?   _pickedImage;           // local file chosen by user
  String  _existingPhotoUrl = ''; // current URL from Firestore/Auth
  bool    _uploadingPhoto   = false;
  double  _uploadProgress   = 0.0;

  // Validation error strings (null = no error)
  String? _nameErr, _phoneErr, _emergencyErr;

  @override
  void initState() {
    super.initState();
    _fetchAndFill();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _dobCtrl.dispose();
    _emergencyCtrl.dispose();
    super.dispose();
  }

  // ── Always fetch fresh Firestore data on open ────────────────────────────
  Future<void> _fetchAndFill() async {
    final uid = widget.user?.uid ?? '';
    if (uid.isEmpty) { setState(() => _loading = false); return; }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users').doc(uid).get();
      final d = snap.data() ?? {};
      final u = widget.user;

      // Pre-fill from Firestore, fall back to Firebase Auth fields
      _nameCtrl.text      = d['name']             as String? ?? u?.displayName ?? '';
      _phoneCtrl.text     = d['phone']             as String? ?? u?.phoneNumber  ?? '';
      _dobCtrl.text       = d['dob']               as String? ?? '';
      _emergencyCtrl.text = d['emergencyContact']  as String? ?? '';
      _gender             = d['gender']             as String?;

      // Load existing photo — prefer Firestore URL, fallback to Auth photoURL
      _existingPhotoUrl   = (d['photoUrl']         as String? ?? '').isNotEmpty
          ? d['photoUrl'] as String
          : u?.photoURL ?? '';
    } catch (_) {
      // If fetch fails, fall back to the passed-in data map
      final d = widget.data;
      final u = widget.user;
      _nameCtrl.text      = d['name']             as String? ?? u?.displayName ?? '';
      _phoneCtrl.text     = d['phone']             as String? ?? u?.phoneNumber  ?? '';
      _dobCtrl.text       = d['dob']               as String? ?? '';
      _emergencyCtrl.text = d['emergencyContact']  as String? ?? '';
      _gender             = d['gender']             as String?;
      _existingPhotoUrl   = d['photoUrl']           as String? ?? u?.photoURL ?? '';
    }

    if (mounted) setState(() => _loading = false);
  }

  // ── Pick photo from camera or gallery ─────────────────────────────────────
  Future<void> _pickPhoto() async {
    final file = await ImagePickerService.instance.pickWithSourceSheet(context);
    if (file != null && mounted) {
      setState(() { _pickedImage = file; _uploadingPhoto = false; _uploadProgress = 0.0; });
    }
  }

  // ── Upload photo to Firebase Storage, return download URL ─────────────────
  Future<String?> _uploadPhoto() async {
    // No new image picked — keep existing
    if (_pickedImage == null) {
      return _existingPhotoUrl.isNotEmpty ? _existingPhotoUrl : null;
    }

    final uid = widget.user?.uid ?? '';
    if (uid.isEmpty) return null;

    setState(() { _uploadingPhoto = true; _uploadProgress = 0.0; });

    final url = await FirebaseStorageService.instance.uploadProfilePhoto(
      uid: uid,
      file: _pickedImage!,
      onProgress: (p) {
        if (mounted) setState(() => _uploadProgress = p);
      },
    );

    if (mounted) setState(() => _uploadingPhoto = false);

    if (url == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo upload failed. Profile saved without new photo.'),
          backgroundColor: Color(0xFFD97706),
        ),
      );
    }
    return url;
  }

  // ── Validation ────────────────────────────────────────────────────────────
  bool _validate() {
    bool ok = true;
    setState(() {
      _nameErr      = null;
      _phoneErr     = null;
      _emergencyErr = null;

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

  // ── Save to Firestore ─────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _saving = true);

    try {
      final uid  = widget.user?.uid ?? '';
      final name = _nameCtrl.text.trim();

      // 1. Upload photo first (if a new one was picked)
      final photoUrl = await _uploadPhoto();

      // 2. Write to Firestore with merge — never overwrites unrelated fields
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name':             name,
        'phone':            _phoneCtrl.text.trim(),
        'dob':              _dobCtrl.text.trim(),
        'emergencyContact': _emergencyCtrl.text.trim(),
        if (_gender != null) 'gender': _gender,
        if (photoUrl != null) 'photoUrl': photoUrl,
        'updatedAt':        FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3. Sync display name + photo URL to Firebase Auth
      if (widget.user != null) {
        if (name.isNotEmpty) await widget.user!.updateDisplayName(name);
        if (photoUrl != null) await widget.user!.updatePhotoURL(photoUrl);
        // Reload so currentUser reflects immediately
        await widget.user!.reload();
      }

      // 4. Show success banner then close
      if (mounted) {
        setState(() { _saving = false; _saved = true; });
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) Navigator.pop(context);
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Failed to save. Please try again.'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
        left: 24, right: 24,
      ),
      child: _loading
          ? const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
        ),
      )
          : SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 42, height: 4,
                  decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2))),
            ),

            // Header
            Row(children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF5B21B6), Color(0xFF7C3AED)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.person_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Edit Profile',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937))),
                Text('Changes save directly to your account',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ]),
            ]),

            const SizedBox(height: 20),

            // ── Success banner (shown after save) ───────────────────
            if (_saved)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFF059669).withOpacity(0.30)),
                ),
                child: const Row(children: [
                  Icon(Icons.check_circle_rounded,
                      color: Color(0xFF059669), size: 20),
                  SizedBox(width: 10),
                  Text('Profile updated successfully!',
                      style: TextStyle(fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF065F46))),
                ]),
              ),

            // ── Profile photo picker ─────────────────────────────────
            Center(
              child: GestureDetector(
                onTap: (_saving || _saved) ? null : _pickPhoto,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Avatar circle
                    Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFEDE9FE),
                        border: Border.all(
                            color: const Color(0xFF7C3AED).withOpacity(0.30),
                            width: 2.5),
                        image: _pickedImage != null
                            ? DecorationImage(
                            image: FileImage(_pickedImage!),
                            fit: BoxFit.cover)
                            : _existingPhotoUrl.isNotEmpty
                            ? DecorationImage(
                            image: NetworkImage(_existingPhotoUrl),
                            fit: BoxFit.cover)
                            : null,
                      ),
                      child: (_pickedImage == null && _existingPhotoUrl.isEmpty)
                          ? const Center(
                          child: Icon(Icons.person_rounded,
                              color: Color(0xFF7C3AED), size: 42))
                          : null,
                    ),

                    // Upload progress ring overlay
                    if (_uploadingPhoto)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withOpacity(0.45),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 32, height: 32,
                                  child: CircularProgressIndicator(
                                    value: _uploadProgress,
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${(_uploadProgress * 100).toInt()}%',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Edit badge
                    if (!_uploadingPhoto)
                      Positioned(
                        bottom: 2, right: 2,
                        child: Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF5B21B6), Color(0xFF7C3AED)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt_rounded,
                              color: Colors.white, size: 14),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Hint text under avatar
            const Center(
              child: Text(
                'Tap to change photo',
                style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
            ),

            const SizedBox(height: 18),

            // ── Email — read-only info row ───────────────────────────
            _infoRow(
              icon: Icons.email_rounded,
              label: 'Email Address',
              value: widget.user?.email ?? widget.data['email'] as String? ?? '—',
              note: 'Contact support to change your email',
            ),

            const SizedBox(height: 14),

            // ── Editable fields ──────────────────────────────────────
            _field(
              label: 'Full Name',
              controller: _nameCtrl,
              icon: Icons.person_rounded,
              hint: 'Your full name',
              kb: TextInputType.name,
              error: _nameErr,
              onChanged: (_) { if (_nameErr != null) setState(() => _nameErr = null); },
            ),

            _field(
              label: 'Phone Number',
              controller: _phoneCtrl,
              icon: Icons.phone_rounded,
              hint: '+91 XXXXX XXXXX',
              kb: TextInputType.phone,
              error: _phoneErr,
              onChanged: (_) { if (_phoneErr != null) setState(() => _phoneErr = null); },
            ),

            // Date of birth — tap to open picker
            _field(
              label: 'Date of Birth',
              controller: _dobCtrl,
              icon: Icons.cake_rounded,
              hint: 'e.g. 15 Aug 1998',
              kb: TextInputType.datetime,
              readOnly: true,
              onTap: () async {
                // Parse existing value if present
                DateTime initial = DateTime(2000);
                try {
                  if (_dobCtrl.text.isNotEmpty) {
                    const months = {
                      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4,
                      'May': 5, 'Jun': 6, 'Jul': 7, 'Aug': 8,
                      'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
                    };
                    final parts = _dobCtrl.text.split(' ');
                    if (parts.length == 3) {
                      initial = DateTime(
                        int.parse(parts[2]),
                        months[parts[1]] ?? 1,
                        int.parse(parts[0]),
                      );
                    }
                  }
                } catch (_) {}
                final picked = await showDatePicker(
                  context: context,
                  initialDate: initial,
                  firstDate: DateTime(1920),
                  lastDate: DateTime.now(),
                  builder: (ctx, child) => Theme(
                    data: Theme.of(ctx).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: Color(0xFF7C3AED),
                        onPrimary: Colors.white,
                      ),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) {
                  const m = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                  setState(() =>
                  _dobCtrl.text = '${picked.day} ${m[picked.month]} ${picked.year}');
                }
              },
            ),

            _field(
              label: 'Emergency Contact',
              controller: _emergencyCtrl,
              icon: Icons.emergency_rounded,
              hint: 'Emergency phone number',
              kb: TextInputType.phone,
              error: _emergencyErr,
              onChanged: (_) { if (_emergencyErr != null) setState(() => _emergencyErr = null); },
            ),

            // Gender chips
            const Text('Gender',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: Color(0xFF374151))),
            const SizedBox(height: 8),
            Row(
              children: ['Male', 'Female', 'Other'].map((g) {
                final selected = _gender == g;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _gender = g),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF7C3AED)
                            : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF7C3AED)
                              : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Text(g,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF6B7280))),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: (_saving || _saved) ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  disabledBackgroundColor: _saved
                      ? const Color(0xFF059669)
                      : const Color(0xFFE5E7EB),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: _saving
                    ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                    : Text(
                  _saved ? '✓ Saved!' : 'Save Changes',
                  style: const TextStyle(fontSize: 15,
                      fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Email read-only info row ──────────────────────────────────────────────
  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    required String note,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(children: [
        Icon(icon, color: const Color(0xFF9CA3AF), size: 18),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: Color(0xFF9CA3AF))),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
          const SizedBox(height: 2),
          Text(note,
              style: const TextStyle(fontSize: 10, color: Color(0xFFB0B8CC))),
        ])),
        const Icon(Icons.lock_outline_rounded, color: Color(0xFFD1D5DB), size: 16),
      ]),
    );
  }

  // ── Editable field ────────────────────────────────────────────────────────
  Widget _field({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    required TextInputType kb,
    String? error,
    bool readOnly = false,
    VoidCallback? onTap,
    ValueChanged<String>? onChanged,
  }) {
    final hasError = error != null && error.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: Color(0xFF374151))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: kb,
          readOnly: readOnly,
          onTap: onTap,
          onChanged: onChanged,
          textCapitalization: kb == TextInputType.name
              ? TextCapitalization.words : TextCapitalization.none,
          style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 13),
            prefixIcon: Icon(icon,
                color: hasError ? const Color(0xFFDC2626) : const Color(0xFF7C3AED),
                size: 18),
            filled: true,
            fillColor: hasError ? const Color(0xFFFEF2F2) : const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            errorText: error,
            errorStyle: const TextStyle(fontSize: 11, color: Color(0xFFDC2626)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                    color: hasError ? const Color(0xFFDC2626) : const Color(0xFFE5E7EB))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                    color: hasError ? const Color(0xFFDC2626) : const Color(0xFF7C3AED),
                    width: 1.5)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFDC2626))),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5)),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  CHANGE PASSWORD SHEET
//
//  3 locked stages — each must pass before the next unlocks:
//  Stage 1 → Enter current password → "Verify" hits Firebase re-auth
//  Stage 2 → Enter new password     → validated live (length, strength rules)
//  Stage 3 → Confirm new password   → character-by-character match check
//  Final   → "Update Password" calls Firebase updatePassword()
// ═══════════════════════════════════════════════════════════════════════════
class ChangePasswordSheet extends StatefulWidget {
  const ChangePasswordSheet({super.key});

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  // Controllers
  final _curCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _conCtrl = TextEditingController();

  // Visibility toggles
  bool _showCur = false, _showNew = false, _showCon = false;

  // Stage: 0 = verify current | 1 = new password | 2 = confirm | 3 = done
  int _stage = 0;

  // Stage-specific state
  bool _verifying  = false; // spinner while re-authing
  bool _curError   = false; // current password wrong flag
  String _curErrMsg = '';

  bool _submitting = false; // final update spinner

  // New password validation
  static const _minLen = 8;
  bool get _hasMinLen   => _newCtrl.text.length >= _minLen;
  bool get _hasUpper    => _newCtrl.text.contains(RegExp(r'[A-Z]'));
  bool get _hasDigit    => _newCtrl.text.contains(RegExp(r'[0-9]'));
  bool get _hasSpecial  => _newCtrl.text.contains(RegExp(r'[!@#\$%^&*()_\-+=]'));
  bool get _newValid    => _hasMinLen && _hasUpper && _hasDigit;

  // Confirm match
  bool get _conMatch =>
      _conCtrl.text.isNotEmpty && _conCtrl.text == _newCtrl.text;
  bool get _conMismatch =>
      _conCtrl.text.isNotEmpty && _conCtrl.text != _newCtrl.text;

  // Strength 0-4
  int get _strength {
    int s = 0;
    if (_hasMinLen)  s++;
    if (_hasUpper)   s++;
    if (_hasDigit)   s++;
    if (_hasSpecial) s++;
    return s;
  }

  @override
  void dispose() {
    _curCtrl.dispose(); _newCtrl.dispose(); _conCtrl.dispose();
    super.dispose();
  }

  // ── Stage 1: verify current password against Firebase ───────────────────
  Future<void> _verifyCurrent() async {
    if (_curCtrl.text.isEmpty) return;
    setState(() { _verifying = true; _curError = false; _curErrMsg = ''; });
    try {
      final u    = FirebaseAuth.instance.currentUser!;
      final cred = EmailAuthProvider.credential(
          email: u.email!, password: _curCtrl.text.trim());
      await u.reauthenticateWithCredential(cred);
      // ✅ Correct — advance to stage 1
      if (mounted) setState(() { _stage = 1; _verifying = false; });
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() {
        _verifying = false;
        _curError  = true;
        _curErrMsg = e.code == 'wrong-password'
            ? 'Incorrect password. Please try again.'
            : e.code == 'too-many-requests'
            ? 'Too many attempts. Please wait and try again.'
            : e.message ?? 'Verification failed.';
      });
    }
  }

  // ── Stage 2: new password validated — advance to confirm ────────────────
  void _advanceToConfirm() {
    if (!_newValid) return;
    setState(() => _stage = 2);
  }

  // ── Stage 3: final update ────────────────────────────────────────────────
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
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 28,
          left: 24, right: 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 42, height: 4,
                  decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2))),
            ),

            // Header
            Row(children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _stage == 3
                        ? [const Color(0xFF059669), const Color(0xFF0D9488)]
                        : [const Color(0xFF1E40AF), const Color(0xFF3B82F6)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  _stage == 3 ? Icons.check_rounded : Icons.lock_rounded,
                  color: Colors.white, size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  _stage == 3 ? 'Password Updated!' : 'Change Password',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937)),
                ),
                Text(
                  _stage == 0 ? 'First, verify it\'s really you'
                      : _stage == 1 ? 'Choose a strong new password'
                      : _stage == 2 ? 'Confirm your new password'
                      : 'Your account is now secured',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ]),
            ]),

            const SizedBox(height: 20),

            // ── Stage progress pills ────────────────────────────────────
            if (_stage < 3)
              Row(children: List.generate(3, (i) {
                final active   = i == _stage;
                final complete = i < _stage;
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                    height: 4,
                    decoration: BoxDecoration(
                      color: complete
                          ? const Color(0xFF059669)
                          : active
                          ? const Color(0xFF1E40AF)
                          : const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              })),

            if (_stage < 3) const SizedBox(height: 6),
            if (_stage < 3)
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _stageLabel('Verify', 0),
                _stageLabel('New', 1),
                _stageLabel('Confirm', 2),
              ]),

            const SizedBox(height: 24),

            // ── STAGE 0: Verify current password ───────────────────────
            if (_stage == 0) ...[
              _fieldLabel('Current Password'),
              const SizedBox(height: 6),
              TextField(
                controller: _curCtrl,
                obscureText: !_showCur,
                onChanged: (_) { if (_curError) setState(() => _curError = false); },
                style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
                decoration: InputDecoration(
                  hintText: '••••••••',
                  hintStyle: const TextStyle(color: Color(0xFFD1D5DB)),
                  prefixIcon: Icon(Icons.lock_outline_rounded,
                      color: _curError ? const Color(0xFFDC2626) : const Color(0xFF1E40AF),
                      size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _showCur ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: const Color(0xFF9CA3AF), size: 18),
                    onPressed: () => setState(() => _showCur = !_showCur),
                  ),
                  filled: true,
                  fillColor: _curError
                      ? const Color(0xFFFEF2F2) : const Color(0xFFF9FAFB),
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: _curError
                              ? const Color(0xFFDC2626) : const Color(0xFFE5E7EB))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: _curError
                              ? const Color(0xFFDC2626) : const Color(0xFF1E40AF),
                          width: 1.5)),
                ),
              ),

              // Error message
              if (_curError) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.error_outline_rounded,
                      color: Color(0xFFDC2626), size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(_curErrMsg,
                        style: const TextStyle(fontSize: 12,
                            color: Color(0xFFDC2626))),
                  ),
                ]),
              ],

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: (_verifying || _curCtrl.text.isEmpty) ? null : _verifyCurrent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E40AF),
                    disabledBackgroundColor: const Color(0xFFE5E7EB),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _verifying
                      ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                      : const Text('Verify Password',
                      style: TextStyle(fontSize: 15,
                          fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],

            // ── STAGE 1: New password + live validation ─────────────────
            if (_stage == 1) ...[
              // Green "current verified" chip
              _VerifiedChip(text: 'Current password verified ✓'),
              const SizedBox(height: 16),

              _fieldLabel('New Password'),
              const SizedBox(height: 6),
              TextField(
                controller: _newCtrl,
                obscureText: !_showNew,
                onChanged: (_) => setState(() {}),
                autofocus: true,
                style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
                decoration: InputDecoration(
                  hintText: '••••••••',
                  hintStyle: const TextStyle(color: Color(0xFFD1D5DB)),
                  prefixIcon: const Icon(Icons.lock_rounded,
                      color: Color(0xFF1E40AF), size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _showNew ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: const Color(0xFF9CA3AF), size: 18),
                    onPressed: () => setState(() => _showNew = !_showNew),
                  ),
                  filled: true, fillColor: const Color(0xFFF9FAFB),
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: Color(0xFF1E40AF), width: 1.5)),
                ),
              ),

              const SizedBox(height: 14),

              // Strength bar
              if (_newCtrl.text.isNotEmpty) ...[
                Row(children: List.generate(4, (i) => Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: i < 3 ? 5 : 0),
                    height: 5,
                    decoration: BoxDecoration(
                      color: i < _strength
                          ? [const Color(0xFFDC2626), const Color(0xFFF59E0B),
                        const Color(0xFF3B82F6), const Color(0xFF059669)][i]
                          : const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ))),
                const SizedBox(height: 6),
                Text(
                  ['', 'Weak — add uppercase & numbers',
                    'Fair — add numbers or symbols',
                    'Good — add a symbol for stronger',
                    'Strong password ✓'][_strength],
                  style: TextStyle(fontSize: 11,
                      color: [Colors.grey, const Color(0xFFDC2626),
                        const Color(0xFFF59E0B), const Color(0xFF3B82F6),
                        const Color(0xFF059669)][_strength]),
                ),
                const SizedBox(height: 14),
              ],

              // Validation checklist
              _CheckRow(label: 'At least $_minLen characters', done: _hasMinLen),
              const SizedBox(height: 6),
              _CheckRow(label: 'At least one uppercase letter (A–Z)', done: _hasUpper),
              const SizedBox(height: 6),
              _CheckRow(label: 'At least one number (0–9)', done: _hasDigit),
              const SizedBox(height: 6),
              _CheckRow(label: 'Symbol like !@#\$ (optional but recommended)',
                  done: _hasSpecial, optional: true),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: _newValid ? _advanceToConfirm : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E40AF),
                    disabledBackgroundColor: const Color(0xFFE5E7EB),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    _newValid ? 'Continue →' : 'Meet all requirements to continue',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                        color: _newValid ? Colors.white : const Color(0xFF9CA3AF)),
                  ),
                ),
              ),
            ],

            // ── STAGE 2: Confirm password ───────────────────────────────
            if (_stage == 2) ...[
              _VerifiedChip(text: 'New password validated ✓'),
              const SizedBox(height: 16),

              _fieldLabel('Confirm New Password'),
              const SizedBox(height: 6),
              TextField(
                controller: _conCtrl,
                obscureText: !_showCon,
                onChanged: (_) => setState(() {}),
                autofocus: true,
                style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
                decoration: InputDecoration(
                  hintText: '••••••••',
                  hintStyle: const TextStyle(color: Color(0xFFD1D5DB)),
                  prefixIcon: Icon(Icons.lock_reset_rounded,
                      color: _conMismatch
                          ? const Color(0xFFDC2626)
                          : _conMatch
                          ? const Color(0xFF059669)
                          : const Color(0xFF1E40AF),
                      size: 18),
                  suffixIcon: _conCtrl.text.isEmpty
                      ? IconButton(
                    icon: Icon(
                        _showCon
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: const Color(0xFF9CA3AF), size: 18),
                    onPressed: () => setState(() => _showCon = !_showCon),
                  )
                      : Icon(
                    _conMatch ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: _conMatch
                        ? const Color(0xFF059669) : const Color(0xFFDC2626),
                    size: 20,
                  ),
                  filled: true,
                  fillColor: _conMismatch
                      ? const Color(0xFFFEF2F2)
                      : _conMatch
                      ? const Color(0xFFF0FDF4)
                      : const Color(0xFFF9FAFB),
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: _conMismatch
                              ? const Color(0xFFDC2626)
                              : _conMatch
                              ? const Color(0xFF059669)
                              : const Color(0xFFE5E7EB))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: _conMismatch
                              ? const Color(0xFFDC2626)
                              : _conMatch
                              ? const Color(0xFF059669)
                              : const Color(0xFF1E40AF),
                          width: 1.5)),
                ),
              ),

              const SizedBox(height: 10),

              // Live match feedback
              if (_conCtrl.text.isNotEmpty)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _conMatch
                      ? _inlineMsg(Icons.check_circle_rounded,
                      'Passwords match!', const Color(0xFF059669),
                      key: const ValueKey('match'))
                      : _inlineMsg(Icons.cancel_rounded,
                      'Passwords do not match yet',
                      const Color(0xFFDC2626),
                      key: const ValueKey('mismatch')),
                ),

              const SizedBox(height: 20),

              Row(children: [
                // Back to stage 1
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      _stage = 1;
                      _conCtrl.clear();
                    }),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('← Back',
                        style: TextStyle(color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: (_conMatch && !_submitting) ? _updatePassword : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E40AF),
                      disabledBackgroundColor: const Color(0xFFE5E7EB),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _submitting
                        ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                        : const Text('Update Password',
                        style: TextStyle(fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ),
                ),
              ]),
            ],

            // ── STAGE 3: Success ────────────────────────────────────────
            if (_stage == 3) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: const Color(0xFF059669).withOpacity(0.20)),
                ),
                child: Column(children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF059669), Color(0xFF0D9488)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight),
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(
                          color: const Color(0xFF059669).withOpacity(0.30),
                          blurRadius: 16, offset: const Offset(0, 4))],
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: Colors.white, size: 34),
                  ),
                  const SizedBox(height: 14),
                  const Text('Password Changed Successfully!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                          color: Color(0xFF065F46))),
                  const SizedBox(height: 8),
                  const Text(
                    'Your account is now secured with your new password. '
                        'You may be asked to sign in again on other devices.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Color(0xFF374151),
                        height: 1.5),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F2937),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Done',
                      style: TextStyle(fontSize: 15,
                          fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _stageLabel(String t, int s) => Text(
    t,
    style: TextStyle(
      fontSize: 9, fontWeight: FontWeight.bold,
      color: s < _stage
          ? const Color(0xFF059669)
          : s == _stage
          ? const Color(0xFF1E40AF)
          : const Color(0xFFB0B8CC),
    ),
  );

  Widget _fieldLabel(String t) => Text(t,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
          color: Color(0xFF374151)));

  Widget _inlineMsg(IconData icon, String msg, Color c, {Key? key}) =>
      Row(key: key, children: [
        Icon(icon, color: c, size: 14),
        const SizedBox(width: 6),
        Text(msg, style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w500)),
      ]);
}

// ─── Verified chip (green pill shown when a stage passes) ────────────────────
class _VerifiedChip extends StatelessWidget {
  final String text;
  const _VerifiedChip({required this.text});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFF0FDF4),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF059669).withOpacity(0.25)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 16),
      const SizedBox(width: 8),
      Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
          color: Color(0xFF065F46))),
    ]),
  );
}

// ─── Validation check row ────────────────────────────────────────────────────
class _CheckRow extends StatelessWidget {
  final String label;
  final bool done;
  final bool optional;
  const _CheckRow({required this.label, required this.done, this.optional = false});

  @override
  Widget build(BuildContext context) => Row(children: [
    AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 20, height: 20,
      decoration: BoxDecoration(
        color: done
            ? const Color(0xFF059669)
            : optional
            ? const Color(0xFFF9FAFB)
            : const Color(0xFFF3F4F6),
        shape: BoxShape.circle,
        border: Border.all(
            color: done
                ? const Color(0xFF059669)
                : optional
                ? const Color(0xFFD1D5DB)
                : const Color(0xFFD1D5DB)),
      ),
      child: Icon(Icons.check_rounded,
          size: 12,
          color: done ? Colors.white : Colors.transparent),
    ),
    const SizedBox(width: 10),
    Text(label,
        style: TextStyle(
            fontSize: 12,
            color: done
                ? const Color(0xFF059669)
                : optional
                ? const Color(0xFFB0B8CC)
                : const Color(0xFF6B7280),
            fontWeight: done ? FontWeight.w600 : FontWeight.normal)),
  ]);
}

// ═══════════════════════════════════════════════════════════════════════════
//  SAVED ADDRESSES SHEET  — full Indian address form
// ═══════════════════════════════════════════════════════════════════════════
class SavedAddressesSheet extends StatefulWidget {
  final Map<String, dynamic> data;
  final String uid;
  const SavedAddressesSheet({super.key, required this.data, required this.uid});

  @override
  State<SavedAddressesSheet> createState() => _SavedAddressesSheetState();
}

class _SavedAddressesSheetState extends State<SavedAddressesSheet> {
  late final TextEditingController _house, _building, _street, _landmark,
      _city, _state, _pincode;
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
          'houseNo':  _house.text.trim(),
          'building': _building.text.trim(),
          'street':   _street.text.trim(),
          'landmark': _landmark.text.trim(),
          'city':     _city.text.trim(),
          'state':    _state.text.trim(),
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
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 24, right: 24),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(margin: const EdgeInsets.symmetric(vertical: 12),
              width: 42, height: 4, decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)))),
          Row(children: [
            Container(width: 46, height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF064E3B), Color(0xFF059669)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.home_rounded, color: Colors.white, size: 24)),
            const SizedBox(width: 14),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Home Address', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937))),
              Text('Your delivery & service address',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            ]),
          ]),
          const SizedBox(height: 24),

          Row(children: [
            Expanded(child: _af('House / Flat No.', _house,
                Icons.door_front_door_rounded, 'e.g. B-204')),
            const SizedBox(width: 12),
            Expanded(child: _af('Building / Society', _building,
                Icons.apartment_rounded, 'e.g. Rajvi Heights')),
          ]),
          _af('Street / Area', _street,
              Icons.map_rounded, 'e.g. MG Road, Adajan'),
          _af('Landmark (Optional)', _landmark,
              Icons.location_on_rounded, 'e.g. Near Reliance Pump'),
          Row(children: [
            Expanded(child: _af('City', _city, Icons.location_city_rounded, 'e.g. Surat')),
            const SizedBox(width: 12),
            Expanded(child: _af('State', _state, Icons.flag_rounded, 'e.g. Gujarat')),
          ]),
          _af('Pincode', _pincode, Icons.pin_drop_rounded, 'e.g. 395009',
              kb: TextInputType.number, max: 6),

          const SizedBox(height: 8),
          SizedBox(width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669),
                  elevation: 0, shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16))),
              child: _saving
                  ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Address', style: TextStyle(fontSize: 15,
                  fontWeight: FontWeight.bold, color: Colors.white)),
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
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: Color(0xFF374151))),
        const SizedBox(height: 6),
        TextField(
          controller: c, keyboardType: kb, maxLength: max,
          style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
          decoration: InputDecoration(
            counterText: '',
            hintText: hint, hintStyle: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 13),
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
    return Stack(children: [
      Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors,
              begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 20, 28),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
                onPressed: onBack,
              ),
              Container(width: 44, height: 44,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: Colors.white, size: 22)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 20,
                    fontWeight: FontWeight.bold, color: Colors.white)),
                Text(subtitle, style: TextStyle(fontSize: 11,
                    color: Colors.white.withOpacity(0.70))),
              ]),
            ]),
          ),
        ),
      ),
      Positioned(bottom: 0, left: 0, right: 0,
        child: Container(height: 24,
          decoration: const BoxDecoration(color: Color(0xFFF4F6FB),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24), topRight: Radius.circular(24),
            ),
          ),
        ),
      ),
    ]);
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
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _SubHeader(
              title: 'Activity', subtitle: 'Your bookings & service history',
              icon: Icons.history_rounded,
              colors: const [Color(0xFF0C4A6E), Color(0xFF0891B2), Color(0xFF22D3EE)],
              onBack: () => Navigator.pop(context),
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('bookings')
                .where('userId', isEqualTo: uid)
                .limit(30).snapshots(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                    child: Center(child: Padding(padding: EdgeInsets.all(40),
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
                    bg: Color(0xFFE0F2FE),
                    title: 'No activity yet',
                    sub: 'Your bookings and service history\nwill appear here.'));
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (_, i) {
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
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
                                blurRadius: 10, offset: const Offset(0, 3))]),
                        child: Row(children: [
                          Container(width: 44, height: 44,
                              decoration: BoxDecoration(color: const Color(0xFFE0F2FE),
                                  borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.build_rounded,
                                  color: Color(0xFF0891B2), size: 22)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(service, style: const TextStyle(fontSize: 14,
                                fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                            Text('by $helper', style: const TextStyle(
                                fontSize: 12, color: Color(0xFF6B7280))),
                            if (ts != null) Text(_fd(ts.toDate()),
                                style: const TextStyle(fontSize: 11, color: Color(0xFFB0B8CC))),
                          ])),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: sc.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(20)),
                            child: Text(sl, style: TextStyle(fontSize: 11,
                                fontWeight: FontWeight.bold, color: sc)),
                          ),
                        ]),
                      );
                    },
                    childCount: docs.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _fd(DateTime d) {
    const m = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${m[d.month]}, ${d.year}';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  PAYMENTS SCREEN
// ═══════════════════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════════════════
//  PAYMENTS SCREEN  — Escrow-aware: shows spending summary + transaction list
//  No wallet top-up. Cash & UPI payments tracked. UPI goes via escrow.
// ═══════════════════════════════════════════════════════════════════════════

/// Maps raw Firestore paymentStatus / paymentMode to UI display values.
class _PayStatusMeta {
  final String label;
  final Color color, bg;
  final IconData icon;
  const _PayStatusMeta(this.label, this.color, this.bg, this.icon);
}

_PayStatusMeta _payMeta(String status, String mode) {
  switch (status) {
    case 'in_escrow':
      return const _PayStatusMeta('In Escrow', Color(0xFF0891B2), Color(0xFFE0F2FE),
          Icons.lock_clock_rounded);
    case 'released':
      return const _PayStatusMeta('Released', Color(0xFF059669), Color(0xFFD1FAE5),
          Icons.check_circle_rounded);
    case 'refunded':
      return const _PayStatusMeta('Refunded', Color(0xFF7C3AED), Color(0xFFEDE9FE),
          Icons.keyboard_return_rounded);
    case 'cash_paid':
      return const _PayStatusMeta('Cash Paid', Color(0xFF059669), Color(0xFFD1FAE5),
          Icons.payments_rounded);
    case 'pending':
      return const _PayStatusMeta('Pending', Color(0xFFD97706), Color(0xFFFEF3C7),
          Icons.hourglass_empty_rounded);
    case 'failed':
      return const _PayStatusMeta('Failed', Color(0xFFDC2626), Color(0xFFFEE2E2),
          Icons.cancel_rounded);
    default:
      return const _PayStatusMeta('Processing', Color(0xFF6B7280), Color(0xFFF3F4F6),
          Icons.sync_rounded);
  }
}

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          // ── Gradient header ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: _SubHeader(
              title: 'Payments',
              subtitle: 'Your spending & escrow status',
              icon: Icons.receipt_long_rounded,
              colors: const [Color(0xFF1E0640), Color(0xFF5B21B6), Color(0xFF7C3AED)],
              onBack: () => Navigator.pop(context),
            ),
          ),

          // ── Spending summary card ───────────────────────────────────
          SliverToBoxAdapter(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('transactions')
                  .where('userId', isEqualTo: uid)
                  .snapshots(),
              builder: (_, snap) {
                final docs  = snap.data?.docs ?? [];
                double total = 0, escrow = 0, cash = 0;
                for (final d in docs) {
                  final tx     = d.data() as Map<String, dynamic>;
                  final amt    = (tx['amount'] as num?)?.toDouble() ?? 0;
                  final mode   = tx['paymentMode']   as String? ?? '';
                  final status = tx['paymentStatus'] as String? ?? '';
                  total += amt;
                  if (mode == 'cash') cash += amt;
                  if (status == 'in_escrow') escrow += amt;
                }
                return _SpendingSummaryCard(total: total, escrow: escrow, cash: cash);
              },
            ),
          ),

          // ── Escrow explainer banner ─────────────────────────────────
          const SliverToBoxAdapter(child: _EscrowInfoBanner()),

          // ── Tab bar ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
                        blurRadius: 8, offset: const Offset(0, 2))]),
                child: TabBar(
                  controller: _tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: const Color(0xFF6B7280),
                  labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  indicator: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF5B21B6), Color(0xFF7C3AED)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  tabs: const [Tab(text: 'All Payments'), Tab(text: 'In Escrow')],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],

        body: TabBarView(
          controller: _tab,
          children: [
            // ── Tab 0: All transactions ─────────────────────────────
            _TransactionsList(uid: uid, escrowOnly: false),
            // ── Tab 1: Escrow-only ──────────────────────────────────
            _TransactionsList(uid: uid, escrowOnly: true),
          ],
        ),
      ),
    );
  }
}

// ─── Spending summary card ────────────────────────────────────────────────────
class _SpendingSummaryCard extends StatelessWidget {
  final double total, escrow, cash;
  const _SpendingSummaryCard({required this.total, required this.escrow, required this.cash});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF3B1F8C), Color(0xFF5B21B6), Color(0xFF7C3AED)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: const Color(0xFF5B21B6).withOpacity(0.30),
            blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row
        Row(children: [
          Container(width: 36, height: 36,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.18),
                  shape: BoxShape.circle),
              child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 18)),
          const SizedBox(width: 10),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Total Spent on Trouble Sarthi',
                style: TextStyle(fontSize: 12, color: Colors.white70)),
          ]),
        ]),

        const SizedBox(height: 14),

        Text('₹${total.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white)),

        const SizedBox(height: 16),

        // 2 stat pills
        Row(children: [
          _StatPill(
            icon: Icons.lock_clock_rounded,
            label: 'In Escrow',
            value: '₹${escrow.toStringAsFixed(0)}',
            color: const Color(0xFF22D3EE),
          ),
          const SizedBox(width: 10),
          _StatPill(
            icon: Icons.payments_rounded,
            label: 'Paid Cash',
            value: '₹${cash.toStringAsFixed(0)}',
            color: const Color(0xFF86EFAC),
          ),
          const SizedBox(width: 10),
          _StatPill(
            icon: Icons.check_circle_rounded,
            label: 'Released',
            value: '₹${(total - escrow - cash).clamp(0, double.infinity).toStringAsFixed(0)}',
            color: const Color(0xFFA78BFA),
          ),
        ]),
      ]),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _StatPill({required this.icon, required this.label,
    required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.70))),
      ]),
    ),
  );
}

// ─── Escrow explainer banner ──────────────────────────────────────────────────
class _EscrowInfoBanner extends StatelessWidget {
  const _EscrowInfoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2FE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0891B2).withOpacity(0.20)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
              color: const Color(0xFF0891B2).withOpacity(0.15),
              shape: BoxShape.circle),
          child: const Icon(Icons.security_rounded, color: Color(0xFF0891B2), size: 18),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('🔐  How UPI Payments Work',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                    color: Color(0xFF0C4A6E))),
            SizedBox(height: 4),
            Text(
              'When you pay via UPI, the money is held securely in escrow — '
                  'not released to the helper until you confirm the service is done. '
                  'Cash payments are recorded directly.',
              style: TextStyle(fontSize: 11, color: Color(0xFF0C4A6E), height: 1.5),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─── Transaction list (used in both tabs) ────────────────────────────────────
class _TransactionsList extends StatelessWidget {
  final String uid;
  final bool escrowOnly;
  const _TransactionsList({required this.uid, required this.escrowOnly});

  @override
  Widget build(BuildContext context) {
    // Fetch all user transactions, filter + sort client-side to avoid composite index requirement
    final Stream<QuerySnapshot> stream = FirebaseFirestore.instance
        .collection('transactions')
        .where('userId', isEqualTo: uid)
        .limit(escrowOnly ? 30 : 40)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: Color(0xFF7C3AED))));
        }

        // Client-side filter (escrow) + sort by createdAt desc — avoids composite index
        final rawDocs = snap.data?.docs ?? [];
        final docs = rawDocs
            .where((d) {
          if (!escrowOnly) return true;
          final tx = d.data() as Map<String, dynamic>;
          return tx['paymentStatus'] == 'in_escrow';
        })
            .toList()
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
            color: const Color(0xFF7C3AED),
            bg: const Color(0xFFEDE9FE),
            title: escrowOnly ? 'No funds in escrow' : 'No payments yet',
            sub: escrowOnly
                ? 'UPI payments held in escrow\nwill appear here.'
                : 'Your cash & UPI payment history\nwill appear here.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final tx = docs[i].data() as Map<String, dynamic>;
            return _TransactionCard(data: tx);
          },
        );
      },
    );
  }
}

// ─── Single transaction card ──────────────────────────────────────────────────
class _TransactionCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _TransactionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final amount      = (data['amount']        as num?)?.toDouble() ?? 0.0;
    final mode        = data['paymentMode']    as String? ?? 'upi';
    final status      = data['paymentStatus']  as String? ?? 'pending';
    final service     = data['serviceName']    as String? ?? 'Service';
    final helper      = data['helperName']     as String? ?? 'Helper';
    final bookingId   = data['bookingId']      as String? ?? '';
    final ts          = data['createdAt']      as Timestamp?;
    final meta        = _payMeta(status, mode);
    final isCash      = mode == 'cash';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          // ── Main row ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Mode icon
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                    color: isCash ? const Color(0xFFD1FAE5) : const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(13)),
                child: Icon(
                  isCash ? Icons.payments_rounded : Icons.phone_android_rounded,
                  color: isCash ? const Color(0xFF059669) : const Color(0xFF7C3AED),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),

              // Details
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(service, style: const TextStyle(fontSize: 14,
                    fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                const SizedBox(height: 3),
                Text('Helper: $helper',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                const SizedBox(height: 3),
                Row(children: [
                  // Payment mode chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isCash
                          ? const Color(0xFFD1FAE5) : const Color(0xFFEDE9FE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isCash ? '💵 Cash' : '📱 UPI',
                      style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.bold,
                          color: isCash ? const Color(0xFF059669) : const Color(0xFF7C3AED)),
                    ),
                  ),
                  if (ts != null) ...[
                    const SizedBox(width: 8),
                    Text(_ft(ts.toDate()),
                        style: const TextStyle(fontSize: 10, color: Color(0xFFB0B8CC))),
                  ],
                ]),
              ])),

              // Amount + status
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('₹${amount.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937))),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                      color: meta.bg,
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(meta.icon, size: 11, color: meta.color),
                    const SizedBox(width: 4),
                    Text(meta.label,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                            color: meta.color)),
                  ]),
                ),
              ]),
            ]),
          ),

          // ── Escrow progress bar (UPI only, not released/refunded) ──
          if (!isCash && status == 'in_escrow') ...[
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            _EscrowProgressRow(bookingId: bookingId),
          ],
        ],
      ),
    );
  }

  String _ft(DateTime d) {
    const m = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${m[d.month]} · ${d.hour}:${d.minute.toString().padLeft(2,'0')}';
  }
}

// ─── Escrow progress row (reads booking doc for live status) ─────────────────
class _EscrowProgressRow extends StatelessWidget {
  final String bookingId;
  const _EscrowProgressRow({required this.bookingId});

  @override
  Widget build(BuildContext context) {
    if (bookingId.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings').doc(bookingId).snapshots(),
      builder: (_, snap) {
        final d = snap.data?.data() as Map<String, dynamic>? ?? {};
        final svcStatus    = d['serviceStatus']   as String? ?? 'pending';
        final proofUploaded = (d['proofUploaded'] as bool?) ?? false;
        final userConfirmed = (d['userConfirmed'] as bool?) ?? false;

        // 3 steps: service done → proof uploaded → funds released
        final step1 = svcStatus == 'completed' || svcStatus == 'confirmed';
        final step2 = proofUploaded;
        final step3 = userConfirmed;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ESCROW RELEASE PROGRESS',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold,
                    color: Color(0xFF9CA3AF), letterSpacing: 1.2)),
            const SizedBox(height: 10),
            Row(children: [
              _EStep(done: step1, label: 'Service\nCompleted',  icon: Icons.handyman_rounded),
              _ELine(done: step1 && step2),
              _EStep(done: step2, label: 'Proof\nUploaded',    icon: Icons.upload_file_rounded),
              _ELine(done: step2 && step3),
              _EStep(done: step3, label: 'Funds\nReleased',    icon: Icons.check_circle_rounded),
            ]),
          ]),
        );
      },
    );
  }
}

class _EStep extends StatelessWidget {
  final bool done;
  final String label;
  final IconData icon;
  const _EStep({required this.done, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: done ? const Color(0xFF059669) : const Color(0xFFF3F4F6),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 16,
          color: done ? Colors.white : const Color(0xFFD1D5DB)),
    ),
    const SizedBox(height: 5),
    Text(label, textAlign: TextAlign.center,
        style: TextStyle(fontSize: 9, height: 1.3,
            color: done ? const Color(0xFF059669) : const Color(0xFFB0B8CC),
            fontWeight: done ? FontWeight.bold : FontWeight.normal)),
  ]);
}

class _ELine extends StatelessWidget {
  final bool done;
  const _ELine({required this.done});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      height: 2, margin: const EdgeInsets.only(bottom: 20),
      color: done ? const Color(0xFF059669) : const Color(0xFFE5E7EB),
    ),
  );
}

// ─── Shared empty state ───────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon; final Color color, bg;
  final String title, sub;
  const _EmptyState({required this.icon, required this.color, required this.bg,
    required this.title, required this.sub});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(40),
    child: Column(children: [
      Container(width: 80, height: 80,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Icon(icon, size: 36, color: color)),
      const SizedBox(height: 16),
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
          color: Color(0xFF1F2937))),
      const SizedBox(height: 8),
      Text(sub, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5)),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
//  APP SETTINGS
// ═══════════════════════════════════════════════════════════════════════════
class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});
  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  bool _dark = false, _push = true, _email = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _SubHeader(
              title: 'App Settings', subtitle: 'Theme, language & notifications',
              icon: Icons.settings_rounded,
              colors: const [Color(0xFF064E3B), Color(0xFF059669), Color(0xFF6EE7B7)],
              onBack: () => Navigator.pop(context),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(delegate: SliverChildListDelegate([
              _sl('APPEARANCE'), const SizedBox(height: 10),
              _TC(icon: Icons.dark_mode_rounded, title: 'Dark Mode',
                  value: _dark, onChanged: (v) => setState(() => _dark = v)),
              const SizedBox(height: 24),
              _sl('LOCALIZATION'), const SizedBox(height: 10),
              _TapCard(icon: Icons.language_rounded, title: 'Language',
                  trailing: 'English', onTap: () {}),
              const SizedBox(height: 24),
              _sl('NOTIFICATIONS'), const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
                        blurRadius: 10, offset: const Offset(0,3))]),
                child: Column(children: [
                  _TR(icon: Icons.notifications_rounded, title: 'Push Notifications',
                      value: _push, onChanged: (v) => setState(() => _push = v)),
                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  _TR(icon: Icons.email_rounded, title: 'Email Alerts',
                      value: _email, isLast: true, onChanged: (v) => setState(() => _email = v)),
                ]),
              ),
              const SizedBox(height: 24),
              _sl('ABOUT'), const SizedBox(height: 10),
              _SC(items: [
                _SR(icon: Icons.help_rounded,        title: 'Help Center',      subtitle: '', onTap: () {}),
                _SR(icon: Icons.description_rounded, title: 'Terms of Service', subtitle: '',
                    isLast: true, onTap: () {}),
              ]),
              const SizedBox(height: 40),
              const Center(child: Column(children: [
                Text('Trouble Sarthi', style: TextStyle(fontSize: 13, color: Color(0xFFB0B8CC))),
                Text('Version 1.0.4 (Build 224)', style: TextStyle(fontSize: 11, color: Color(0xFFD1D5DB))),
              ])),
              const SizedBox(height: 60),
            ])),
          ),
        ],
      ),
    );
  }

  Widget _sl(String t) => Text(t, style: const TextStyle(fontSize: 10,
      fontWeight: FontWeight.bold, color: Color(0xFF9CA3AF), letterSpacing: 1.4));
}

// ═══════════════════════════════════════════════════════════════════════════
//  SUPPORT SCREEN
// ═══════════════════════════════════════════════════════════════════════════
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _SubHeader(
              title: 'Support & Help', subtitle: "We're here to help anytime",
              icon: Icons.headset_mic_rounded,
              colors: const [Color(0xFF78350F), Color(0xFFD97706), Color(0xFFFBBF24)],
              onBack: () => Navigator.pop(context),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(delegate: SliverChildListDelegate([
              const Text('How can we help?', style: TextStyle(fontSize: 22,
                  fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
              const SizedBox(height: 4),
              const Text('Search articles or talk to our team',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
                        blurRadius: 10, offset: const Offset(0,3))]),
                child: Row(children: [
                  const Icon(Icons.search_rounded, color: Color(0xFFD97706), size: 20),
                  const SizedBox(width: 10),
                  Text('Search troubleshooting guides...',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                ]),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: _SQC(icon: Icons.menu_book_rounded, title: 'Help Center',
                    subtitle: 'Detailed guides', onTap: () {})),
                const SizedBox(width: 12),
                Expanded(child: _SQC(icon: Icons.help_outline_rounded, title: 'FAQs',
                    subtitle: 'Common questions', onTap: () {})),
              ]),
              const SizedBox(height: 24),
              const Text('DIRECT ASSISTANCE', style: TextStyle(fontSize: 10,
                  fontWeight: FontWeight.bold, color: Color(0xFF9CA3AF), letterSpacing: 1.4)),
              const SizedBox(height: 10),
              _SC(items: [
                _SR(icon: Icons.chat_bubble_rounded,  title: 'Live Chat',
                    subtitle: 'Typical response: 2 mins', onTap: () {}),
                _SR(icon: Icons.email_rounded,         title: 'Email Support',
                    subtitle: 'Typical response: 2 hours', onTap: () {}),
                _SR(icon: Icons.emergency_rounded,     title: 'Emergency Hotline',
                    subtitle: 'Critical issues only (24/7)',
                    isDestructive: true, isLast: true, onTap: () {}),
              ]),
              const SizedBox(height: 24),
              Container(
                width: double.infinity, padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF3B1F8C), Color(0xFF5B21B6)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(children: [
                  Container(width: 60, height: 60,
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 30)),
                  const SizedBox(height: 14),
                  const Text('Need Personal Help?', style: TextStyle(fontSize: 18,
                      fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 6),
                  Text('Our expert Sarthi agents are ready to assist you.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.75),
                          height: 1.4)),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity, height: 50,
                    decoration: BoxDecoration(color: Colors.white,
                        borderRadius: BorderRadius.circular(14)),
                    child: Material(color: Colors.transparent,
                      child: InkWell(borderRadius: BorderRadius.circular(14),
                        onTap: () {},
                        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.headset_mic_rounded, color: Color(0xFF5B21B6), size: 20),
                          SizedBox(width: 10),
                          Text('Talk to an Agent', style: TextStyle(fontSize: 14,
                              fontWeight: FontWeight.bold, color: Color(0xFF5B21B6))),
                        ]),
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 60),
            ])),
          ),
        ],
      ),
    );
  }
}

class _SQC extends StatelessWidget {
  final IconData icon; final String title, subtitle; final VoidCallback onTap;
  const _SQC({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 10, offset: const Offset(0,3))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 42, height: 42,
            decoration: BoxDecoration(color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: const Color(0xFFD97706), size: 22)),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937))),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), height: 1.4)),
      ]),
    ),
  );
}

// ─── Compact shared widget aliases ───────────────────────────────────────────
class _SC extends StatelessWidget {
  final List<_SR> items;
  const _SC({required this.items});
  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 10, offset: const Offset(0,3))]),
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
                color: isDestructive ? const Color(0xFFDC2626).withOpacity(0.4)
                    : const Color(0xFFD1D5DB), size: 20),
          ]),
        ),
      ),
    );
  }
}

class _TC extends StatelessWidget {
  final IconData icon; final String title; final bool value;
  final ValueChanged<bool> onChanged;
  const _TC({required this.icon, required this.title, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 10, offset: const Offset(0,3))]),
      child: _TR(icon: icon, title: title, value: value, onChanged: onChanged));
}

class _TR extends StatelessWidget {
  final IconData icon; final String title; final bool value, isLast;
  final ValueChanged<bool> onChanged;
  const _TR({required this.icon, required this.title, required this.value,
    required this.onChanged, this.isLast = false});

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(children: [
        Container(width: 38, height: 38,
            decoration: BoxDecoration(color: const Color(0xFFEDE9FE),
                borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: const Color(0xFF5B21B6), size: 19)),
        const SizedBox(width: 14),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 14,
            fontWeight: FontWeight.w600, color: Color(0xFF1F2937)))),
        Switch(value: value, onChanged: onChanged, activeColor: const Color(0xFF5B21B6)),
      ]));
}

class _TapCard extends StatelessWidget {
  final IconData icon; final String title, trailing; final VoidCallback onTap;
  const _TapCard({required this.icon, required this.title, required this.trailing, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
                  blurRadius: 10, offset: const Offset(0,3))]),
          child: Row(children: [
            Container(width: 38, height: 38,
                decoration: BoxDecoration(color: const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(11)),
                child: Icon(icon, color: const Color(0xFF5B21B6), size: 19)),
            const SizedBox(width: 14),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 14,
                fontWeight: FontWeight.w600, color: Color(0xFF1F2937)))),
            Text(trailing, style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFD1D5DB), size: 20),
          ]
          )
      )
  );
}