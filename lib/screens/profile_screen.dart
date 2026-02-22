// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trouble_sarthi/screens/about_screen.dart';

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
                          _GItem(Icons.account_balance_wallet_rounded, 'Payments', 'Wallet & transactions',
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
class EditProfileSheet extends StatefulWidget {
  final Map<String, dynamic> data;
  final User? user;
  const EditProfileSheet({super.key, required this.data, required this.user});

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late final TextEditingController _name, _email, _phone, _dob, _emergency;
  String? _gender;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.data; final u = widget.user;
    _name      = TextEditingController(text: d['name']             as String? ?? u?.displayName ?? '');
    _email     = TextEditingController(text: d['email']            as String? ?? u?.email        ?? '');
    _phone     = TextEditingController(text: d['phone']            as String? ?? u?.phoneNumber  ?? '');
    _dob       = TextEditingController(text: d['dob']              as String? ?? '');
    _emergency = TextEditingController(text: d['emergencyContact'] as String? ?? '');
    _gender    = d['gender'] as String?;
  }

  @override
  void dispose() {
    _name.dispose(); _email.dispose(); _phone.dispose();
    _dob.dispose(); _emergency.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final uid = widget.user?.uid ?? '';
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': _name.text.trim(), 'email': _email.text.trim(),
        'phone': _phone.text.trim(), 'dob': _dob.text.trim(),
        'emergencyContact': _emergency.text.trim(),
        if (_gender != null) 'gender': _gender,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (widget.user != null && _name.text.trim().isNotEmpty) {
        await widget.user!.updateDisplayName(_name.text.trim());
      }
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
                  gradient: const LinearGradient(colors: [Color(0xFF5B21B6), Color(0xFF7C3AED)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.person_rounded, color: Colors.white, size: 24)),
            const SizedBox(width: 14),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Edit Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937))),
              Text('Update your personal details',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            ]),
          ]),

          const SizedBox(height: 24),

          _f('Full Name',          _name,      Icons.person_rounded,    'Your full name',       TextInputType.name),
          _f('Email',              _email,     Icons.email_rounded,     'you@email.com',         TextInputType.emailAddress),
          _f('Phone Number',       _phone,     Icons.phone_rounded,     '+91 XXXXX XXXXX',       TextInputType.phone),
          _f('Date of Birth',      _dob,       Icons.cake_rounded,      'e.g. 15 Aug 1998',      TextInputType.datetime,
              readOnly: true, onTap: () async {
                final d = await showDatePicker(context: context,
                    initialDate: DateTime(2000),
                    firstDate: DateTime(1920), lastDate: DateTime.now());
                if (d != null) {
                  const m = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
                  _dob.text = '${d.day} ${m[d.month]} ${d.year}';
                }
              }),
          _f('Emergency Contact',  _emergency, Icons.emergency_rounded, 'Emergency phone number', TextInputType.phone),

          const Text('Gender', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: Color(0xFF374151))),
          const SizedBox(height: 8),
          Row(children: ['Male', 'Female', 'Other'].map((g) => Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _gender = g),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: _gender == g ? const Color(0xFF7C3AED) : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _gender == g
                      ? const Color(0xFF7C3AED) : const Color(0xFFE5E7EB)),
                ),
                child: Text(g, textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: _gender == g ? Colors.white : const Color(0xFF6B7280))),
              ),
            ),
          )).toList()),

          const SizedBox(height: 24),

          SizedBox(width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED),
                  elevation: 0, shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16))),
              child: _saving
                  ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Changes', style: TextStyle(fontSize: 15,
                  fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _f(String label, TextEditingController c, IconData icon, String hint,
      TextInputType kb, {bool readOnly = false, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: Color(0xFF374151))),
        const SizedBox(height: 6),
        TextField(
          controller: c, keyboardType: kb, readOnly: readOnly, onTap: onTap,
          style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
          decoration: InputDecoration(
            hintText: hint, hintStyle: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 13),
            prefixIcon: Icon(icon, color: const Color(0xFF7C3AED), size: 18),
            filled: true, fillColor: const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5)),
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
  final _cur = TextEditingController();
  final _new = TextEditingController();
  final _con = TextEditingController();
  bool _sCur = false, _sNew = false, _sCon = false, _saving = false;

  @override
  void dispose() { _cur.dispose(); _new.dispose(); _con.dispose(); super.dispose(); }

  int get _strength {
    final p = _new.text;
    int s = 0;
    if (p.length >= 6) s++;
    if (p.length >= 10) s++;
    if (p.contains(RegExp(r'[A-Z]'))) s++;
    if (p.contains(RegExp(r'[0-9]'))) s++;
    if (p.contains(RegExp(r'[!@#\$%^&*]'))) s++;
    return s;
  }

  Future<void> _submit() async {
    if (_new.text != _con.text) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords do not match'))); return;
    }
    if (_new.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Minimum 6 characters required'))); return;
    }
    setState(() => _saving = true);
    try {
      final u = FirebaseAuth.instance.currentUser!;
      await u.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: u.email!, password: _cur.text));
      await u.updatePassword(_new.text);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password updated!')));
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Error')));
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
                  gradient: const LinearGradient(colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.lock_rounded, color: Colors.white, size: 24)),
            const SizedBox(width: 14),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Change Password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937))),
              Text('Keep your account secure',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            ]),
          ]),
          const SizedBox(height: 24),
          _pf('Current Password',      _cur, _sCur, () => setState(() => _sCur = !_sCur)),
          _pf('New Password',          _new, _sNew, () => setState(() => _sNew = !_sNew), onChange: true),
          _pf('Confirm New Password',  _con, _sCon, () => setState(() => _sCon = !_sCon)),

          if (_new.text.isNotEmpty) ...[
            Row(children: List.generate(5, (i) => Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 4), height: 4,
                decoration: BoxDecoration(
                  color: i < _strength
                      ? [Colors.red, Colors.orange, Colors.yellow,
                    Colors.lightGreen, Colors.green][i]
                      : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ))),
            const SizedBox(height: 6),
            Text(
              ['', 'Weak', 'Fair', 'Good', 'Strong', 'Very Strong'][_strength],
              style: TextStyle(fontSize: 11, color: [
                Colors.grey, Colors.red, Colors.orange,
                Colors.yellow.shade700, Colors.lightGreen, Colors.green
              ][_strength]),
            ),
          ],

          const SizedBox(height: 16),
          SizedBox(width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E40AF),
                  elevation: 0, shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16))),
              child: _saving
                  ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Update Password', style: TextStyle(fontSize: 15,
                  fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _pf(String label, TextEditingController c, bool vis, VoidCallback toggle,
      {bool onChange = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: Color(0xFF374151))),
        const SizedBox(height: 6),
        TextField(
          controller: c, obscureText: !vis,
          onChanged: onChange ? (_) => setState(() {}) : null,
          style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
          decoration: InputDecoration(
            hintText: '••••••••', hintStyle: const TextStyle(color: Color(0xFFD1D5DB)),
            prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF1E40AF), size: 18),
            suffixIcon: IconButton(
              icon: Icon(vis ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: const Color(0xFF9CA3AF), size: 18),
              onPressed: toggle,
            ),
            filled: true, fillColor: const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF1E40AF), width: 1.5)),
          ),
        ),
      ]),
    );
  }
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
                .orderBy('createdAt', descending: true)
                .limit(30).snapshots(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                    child: Center(child: Padding(padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(color: Color(0xFF0891B2)))));
              }
              final docs = snap.data?.docs ?? [];
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
class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

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
              title: 'Payments', subtitle: 'Wallet & transaction history',
              icon: Icons.account_balance_wallet_rounded,
              colors: const [Color(0xFF1E0640), Color(0xFF5B21B6), Color(0xFF7C3AED)],
              onBack: () => Navigator.pop(context),
            ),
          ),

          // Wallet card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
                builder: (_, snap) {
                  final d = snap.data?.data() as Map<String, dynamic>? ?? {};
                  final bal = (d['walletBalance'] as num?)?.toDouble() ?? 0.0;
                  return Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF3B1F8C), Color(0xFF5B21B6), Color(0xFF7C3AED)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [BoxShadow(color: const Color(0xFF5B21B6).withOpacity(0.35),
                          blurRadius: 18, offset: const Offset(0, 6))],
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(width: 38, height: 38,
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.18),
                                shape: BoxShape.circle),
                            child: const Icon(Icons.account_balance_wallet_rounded,
                                color: Colors.white, size: 20)),
                        const SizedBox(width: 10),
                        const Text('Sarthi Wallet', style: TextStyle(fontSize: 14,
                            color: Colors.white70)),
                      ]),
                      const SizedBox(height: 16),
                      Text('₹${bal.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 32,
                              fontWeight: FontWeight.bold, color: Colors.white)),
                      Text('Available Balance',
                          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.65))),
                      const SizedBox(height: 16),
                      Row(children: [
                        _WA(Icons.add_rounded, 'Add Money', () {}),
                        const SizedBox(width: 10),
                        _WA(Icons.history_rounded, 'History', () {}),
                        const SizedBox(width: 10),
                        _WA(Icons.send_rounded, 'Transfer', () {}),
                      ]),
                    ]),
                  );
                },
              ),
            ),
          ),

          // Transactions
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('transactions')
                .where('userId', isEqualTo: uid)
                .orderBy('createdAt', descending: true)
                .limit(20).snapshots(),
            builder: (_, snap) {
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const SliverToBoxAdapter(child: _EmptyState(
                    icon: Icons.receipt_long_rounded, color: Color(0xFF7C3AED),
                    bg: Color(0xFFEDE9FE),
                    title: 'No transactions yet',
                    sub: 'Your payment history will\nappear here.'));
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (_, i) {
                      final d = docs[i].data() as Map<String, dynamic>;
                      final type   = d['type']        as String? ?? 'debit';
                      final amount = (d['amount']     as num?)?.toDouble() ?? 0.0;
                      final desc   = d['description'] as String? ?? 'Transaction';
                      final ts     = d['createdAt']   as Timestamp?;
                      final isC    = type == 'credit' || type == 'refund';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
                                blurRadius: 8, offset: const Offset(0, 2))]),
                        child: Row(children: [
                          Container(width: 42, height: 42,
                              decoration: BoxDecoration(
                                  color: isC ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(12)),
                              child: Icon(
                                isC ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                color: isC ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                size: 20,
                              )),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(desc, style: const TextStyle(fontSize: 13,
                                fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
                            if (ts != null) Text(_ft(ts.toDate()),
                                style: const TextStyle(fontSize: 11, color: Color(0xFFB0B8CC))),
                          ])),
                          Text('${isC ? '+' : '-'}₹${amount.toStringAsFixed(2)}',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                                  color: isC ? const Color(0xFF059669) : const Color(0xFFDC2626))),
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

  String _ft(DateTime d) {
    const m = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${m[d.month]} · ${d.hour}:${d.minute.toString().padLeft(2,'0')}';
  }
}

class _WA extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _WA(this.icon, this.label, this.onTap);

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white)),
        ]),
      ),
    ),
  );
}

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
          ])));
}