// lib/screens/about_screen.dart
//
//  TRUST & SAFETY  (bottom-nav "Trust" tab, also opened from Profile)
//  Everything here is read from the live booking system:
//   • Trust score  — worked out on the phone from verification, completed
//                    bookings, helpers' ratings (user_ratings/{uid}) and
//                    cancellations. The breakdown is shown so it's never a mystery.
//   • Verification — Firebase Auth + users/{uid}
//   • Helper ratings for you — reviews where toUid == me
//   • Reviews you gave       — reviews where fromUid == me
//   • Reports you raised     — reports where reporterId == me
//   • How Sarthi keeps you safe (start code, chat, pay after work, SOS …)

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/job_api.dart';
import '../core/job_models.dart';
import '../core/ranking.dart';
import '../core/review_sheet.dart';
import '../core/sarthi_ui.dart';
import '../request/booking_tracker_screen.dart';

const _navy = Color(0xFF0F2042);
const _teal = Color(0xFF0D6E6E);
const _trustGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF0F2042), Color(0xFF1A3A6B), Color(0xFF0D6E6E)],
);

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  final _db = FirebaseFirestore.instance;
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _profile =
  _db.collection('users').doc(_uid.isEmpty ? '_' : _uid).snapshots();
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _ratings =
  _db.collection('user_ratings').doc(_uid.isEmpty ? '_' : _uid).snapshots();
  late final Stream<List<Booking>> _bookings = JobApi.instance.myBookings(asHelper: false, limit: 100);
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _received = _db
      .collection('reviews')
      .where('toUid', isEqualTo: _uid)
      .where('visible', isEqualTo: true) // mutual reviews stay hidden until both sides review
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _given =
  _db.collection('reviews').where('fromUid', isEqualTo: _uid).limit(30).snapshots();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _reports =
  _db.collection('reports').where('reporterId', isEqualTo: _uid).limit(20).snapshots();

  bool _revealChecked = false;

  /// Completed bookings where the helper rated me but I haven't rated them yet
  /// (still inside the 14-day window). Also reveals overdue hidden reviews once.
  List<Booking> _pendingMutual(List<Booking> all) {
    final now = DateTime.now();
    final completed = all.where((b) => b.status == BookingStatus.completed && b.completedAt != null).toList();
    if (!_revealChecked && completed.isNotEmpty) {
      _revealChecked = true;
      final overdue = completed
          .where((b) => b.customerReviewed != b.helperReviewed && now.isAfter(b.completedAt!.add(reviewWindow)))
          .take(10);
      for (final b in overdue) {
        JobApi.instance.revealDueReviews(b);
      }
    }
    return completed
        .where((b) => b.helperReviewed && !b.customerReviewed && now.isBefore(b.completedAt!.add(reviewWindow)))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_uid.isEmpty) {
      return const Scaffold(
        backgroundColor: SarthiColors.page,
        body: SarthiEmpty(icon: Icons.shield_outlined, title: 'Sign in to see your trust score'),
      );
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: SarthiColors.page,
        body: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: _TrustHero()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 130),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Score + breakdown
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: _profile,
                    builder: (context, p) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: _ratings,
                      builder: (context, r) => StreamBuilder<List<Booking>>(
                        stream: _bookings,
                        builder: (context, b) {
                          final score = _TrustInputs.from(
                            user: FirebaseAuth.instance.currentUser,
                            profile: p.data?.data() ?? const {},
                            ratings: r.data?.data() ?? const {},
                            bookings: b.data ?? const [],
                          );
                          final pending = _pendingMutual(b.data ?? const []);
                          return Column(children: [
                            _TrustScoreCard(t: score, loading: !p.hasData || !b.hasData),
                            if (pending.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _PendingReviewsCard(bookings: pending),
                            ],
                            const SizedBox(height: 12),
                            _StatsRow(t: score),
                            const SarthiSectionLabel('Verification'),
                            _VerificationCard(t: score),
                            const SarthiSectionLabel('How your score is made'),
                            _BreakdownCard(t: score),
                          ]);
                        },
                      ),
                    ),
                  ),

                  // Helper ratings for you
                  const SarthiSectionLabel('What helpers said about you'),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _received,
                    builder: (context, snap) {
                      if (snap.hasError) return const _InfoCard(text: 'Could not load ratings right now.');
                      if (!snap.hasData) return const _LoadingCard();
                      final docs = snap.data!.docs;
                      if (docs.isEmpty) {
                        return const _InfoCard(
                          icon: Icons.star_outline_rounded,
                          text: 'No ratings yet. After a completed job, your helper can rate you. '
                              'Being clear, respectful and paying on time earns good ratings.',
                        );
                      }
                      return Column(children: [for (final d in docs) _ReviewCard(data: d.data(), received: true)]);
                    },
                  ),

                  // Reviews you gave
                  const SarthiSectionLabel('Reviews you gave'),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _given,
                    builder: (context, snap) {
                      if (snap.hasError) return const _InfoCard(text: 'Could not load your reviews right now.');
                      if (!snap.hasData) return const _LoadingCard();
                      final docs = [...snap.data!.docs]..sort((a, b) {
                        final at = a.data()['createdAt'], bt = b.data()['createdAt'];
                        if (at is! Timestamp) return 1;
                        if (bt is! Timestamp) return -1;
                        return bt.compareTo(at);
                      });
                      if (docs.isEmpty) {
                        return const _InfoCard(
                          icon: Icons.rate_review_outlined,
                          text: 'You haven\'t reviewed a helper yet. Your reviews decide which helpers '
                              'appear first for everyone nearby.',
                        );
                      }
                      return SizedBox(
                        height: 150,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (_, i) => _GivenReviewTile(data: docs[i].data()),
                        ),
                      );
                    },
                  ),

                  // Reports
                  const SarthiSectionLabel('Problems you reported'),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _reports,
                    builder: (context, snap) {
                      if (snap.hasError) return const _InfoCard(text: 'Could not load reports right now.');
                      if (!snap.hasData) return const _LoadingCard();
                      final docs = [...snap.data!.docs]..sort((a, b) {
                        final at = a.data()['createdAt'], bt = b.data()['createdAt'];
                        if (at is! Timestamp) return 1;
                        if (bt is! Timestamp) return -1;
                        return bt.compareTo(at);
                      });
                      if (docs.isEmpty) {
                        return const _InfoCard(
                          icon: Icons.verified_user_outlined,
                          text: 'No reports. If anything goes wrong during a booking, open the booking and tap '
                              '"Report a problem". Our team reviews every report.',
                        );
                      }
                      return Column(children: [for (final d in docs) _ReportCard(data: d.data())]);
                    },
                  ),

                  const SarthiSectionLabel('How Sarthi keeps you safe'),
                  const _SafetyFeatures(),

                  const SizedBox(height: 20),
                  const Center(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.lock_rounded, size: 12, color: Color(0xFFB0B8CC)),
                      SizedBox(width: 5),
                      Text('Your phone number and address are shared only with your booked helper.',
                          style: TextStyle(fontSize: 11, color: Color(0xFFB0B8CC))),
                    ]),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TRUST SCORE (worked out on the phone; every part is shown in the breakdown)
// ─────────────────────────────────────────────────────────────────────────────

class _TrustInputs {
  final bool emailVerified, phoneAdded, photoAdded, profileComplete;
  final int completed, cancelledByMe, active;
  final double rating; // raw average from helpers
  final int ratingCount;

  const _TrustInputs({
    required this.emailVerified,
    required this.phoneAdded,
    required this.photoAdded,
    required this.profileComplete,
    required this.completed,
    required this.cancelledByMe,
    required this.active,
    required this.rating,
    required this.ratingCount,
  });

  factory _TrustInputs.from({
    required User? user,
    required Map<String, dynamic> profile,
    required Map<String, dynamic> ratings,
    required List<Booking> bookings,
  }) {
    String str(String k) => '${profile[k] ?? ''}'.trim();
    final phone = str('phone').isNotEmpty || (user?.phoneNumber ?? '').isNotEmpty;
    final photo = str('photoUrl').isNotEmpty || (user?.photoURL ?? '').isNotEmpty;
    final name = str('name').isNotEmpty || (user?.displayName ?? '').isNotEmpty;
    return _TrustInputs(
      emailVerified: user?.emailVerified ?? false,
      phoneAdded: phone,
      photoAdded: photo,
      profileComplete: profile['profileComplete'] == true || (name && phone),
      completed: bookings.where((b) => b.status == BookingStatus.completed).length,
      cancelledByMe:
      bookings.where((b) => b.status == BookingStatus.cancelled && b.cancelledBy == 'customer').length,
      active: bookings.where((b) => b.isActive).length,
      rating: (ratings['rating'] as num?)?.toDouble() ?? 0,
      ratingCount: (ratings['ratingCount'] as num?)?.toInt() ?? 0,
    );
  }

  // Parts of the score (max 100).
  int get verificationPts =>
      (emailVerified ? 8 : 0) + (phoneAdded ? 8 : 0) + (photoAdded ? 4 : 0) + (profileComplete ? 5 : 0); // 25
  int get bookingPts => (math.min(completed, 10) * 1.5).round(); // 15
  int get ratingPts => ratingCount == 0
      ? 10 // neutral until helpers rate you
      : math.max(0, math.min(20, (((bayesRating(rating, ratingCount) - 1) / 4) * 20).round())); // 20
  int get cancelPts => -math.min(cancelledByMe * 4, 20);
  static const basePts = 40;

  int get score => math.max(0, math.min(100, basePts + verificationPts + bookingPts + ratingPts + cancelPts));

  String get label => score >= 85
      ? 'Excellent'
      : score >= 70
      ? 'Trusted customer'
      : score >= 50
      ? 'Good standing'
      : 'Needs attention';

  Color get color => score >= 85
      ? const Color(0xFF34D399)
      : score >= 70
      ? const Color(0xFF5EEAD4)
      : score >= 50
      ? const Color(0xFFFBBF24)
      : const Color(0xFFF87171);
}

class _TrustHero extends StatelessWidget {
  const _TrustHero();

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Container(
      decoration: const BoxDecoration(gradient: _trustGradient),
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: EdgeInsets.fromLTRB(canPop ? 8 : 20, 10, 20, 0),
            child: Row(children: [
              if (canPop)
                IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                ),
              const Text('Trust & Safety',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white)),
              const Spacer(),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: const Icon(Icons.shield_rounded, color: Colors.white, size: 18),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          Text('Verified helpers · Start code · Pay after work',
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
          Container(
            height: 24,
            margin: const EdgeInsets.only(top: 16),
            decoration: const BoxDecoration(
              color: SarthiColors.page,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(26), topRight: Radius.circular(26)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _TrustScoreCard extends StatelessWidget {
  final _TrustInputs t;
  final bool loading;
  const _TrustScoreCard({required this.t, required this.loading});

  @override
  Widget build(BuildContext context) {
    final score = t.score;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B1F8C), Color(0xFF1A3A6B), _teal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: _teal.withValues(alpha: 0.28), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(children: [
        SizedBox(
          width: 104,
          height: 104,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 104,
              height: 104,
              child: CircularProgressIndicator(
                value: loading ? null : score / 100,
                strokeWidth: 9,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(t.color),
                strokeCap: StrokeCap.round,
              ),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text(loading ? '…' : '$score',
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white, height: 1)),
              Text('/100', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.6))),
            ]),
          ]),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('YOUR TRUST SCORE',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB2E8E8), letterSpacing: 1.5)),
            const SizedBox(height: 6),
            Text(loading ? 'Calculating…' : t.label,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 18),
              const SizedBox(width: 4),
              Text(
                t.ratingCount == 0
                    ? 'No helper ratings yet'
                    : '${t.rating.toStringAsFixed(1)} from ${t.ratingCount} helper${t.ratingCount == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
              ),
            ]),
            const SizedBox(height: 6),
            Text('Helpers see how reliable you are when they price your requests.',
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.55), height: 1.35)),
          ]),
        ),
      ]),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final _TrustInputs t;
  const _StatsRow({required this.t});

  @override
  Widget build(BuildContext context) {
    Widget stat(String value, String label, IconData icon, Color color) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: sarthiCard(radius: 16),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: SarthiColors.ink)),
          Text(label, style: const TextStyle(fontSize: 10.5, color: SarthiColors.faint)),
        ]),
      ),
    );
    return Row(children: [
      stat('${t.completed}', 'Completed', Icons.task_alt_rounded, SarthiColors.green),
      const SizedBox(width: 10),
      stat('${t.active}', 'Active', Icons.schedule_rounded, SarthiColors.purple),
      const SizedBox(width: 10),
      stat('${t.cancelledByMe}', 'Cancelled', Icons.cancel_outlined, SarthiColors.red),
    ]);
  }
}

class _VerificationCard extends StatelessWidget {
  final _TrustInputs t;
  const _VerificationCard({required this.t});

  @override
  Widget build(BuildContext context) {
    Widget chip(IconData icon, String label, bool done) => Expanded(
      child: Column(children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: done ? SarthiColors.purpleLight : const Color(0xFFF3F4F6),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: done ? SarthiColors.purpleDark : const Color(0xFFD1D5DB), size: 23),
        ),
        const SizedBox(height: 7),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: SarthiColors.body, height: 1.3)),
        const SizedBox(height: 4),
        Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 15, color: done ? const Color(0xFF22C55E) : const Color(0xFFD1D5DB)),
      ]),
    );
    final missing = [
      if (!t.emailVerified) 'verify your email',
      if (!t.phoneAdded) 'add your phone number',
      if (!t.photoAdded) 'add a profile photo',
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 14),
      decoration: sarthiCard(),
      child: Column(children: [
        Row(children: [
          chip(Icons.email_rounded, 'Email\nverified', t.emailVerified),
          chip(Icons.phone_android_rounded, 'Phone\nadded', t.phoneAdded),
          chip(Icons.photo_camera_rounded, 'Profile\nphoto', t.photoAdded),
          chip(Icons.badge_rounded, 'Profile\ncomplete', t.profileComplete),
        ]),
        if (missing.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: SarthiColors.amberLight, borderRadius: BorderRadius.circular(12)),
            child: Text(
              'Raise your score: ${missing.join(', ')} (Profile tab).',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ]),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  final _TrustInputs t;
  const _BreakdownCard({required this.t});

  @override
  Widget build(BuildContext context) {
    Widget row(String label, String detail, int pts, int max) {
      final neg = pts < 0;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: SarthiColors.ink, fontSize: 13)),
              Text(detail, style: const TextStyle(fontSize: 11, color: SarthiColors.faint)),
            ]),
          ),
          Text(
            neg ? '$pts' : (max == 0 ? '+$pts' : '+$pts / $max'),
            style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 13, color: neg ? SarthiColors.red : SarthiColors.green),
          ),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: sarthiCard(),
      child: Column(children: [
        row('Starting score', 'Everyone starts here', _TrustInputs.basePts, 0),
        const Divider(height: 1),
        row('Verification', 'Email, phone, photo, complete profile', t.verificationPts, 25),
        const Divider(height: 1),
        row('Completed bookings', '${t.completed} completed (1.5 points each, up to 10)', t.bookingPts, 15),
        const Divider(height: 1),
        row(
          'Helper ratings',
          t.ratingCount == 0 ? 'Neutral until helpers rate you' : 'Average ${t.rating.toStringAsFixed(1)} from ${t.ratingCount}',
          t.ratingPts,
          20,
        ),
        if (t.cancelPts < 0) ...[
          const Divider(height: 1),
          row('Cancellations', '${t.cancelledByMe} booking(s) you cancelled', t.cancelPts, 0),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REVIEWS
// ─────────────────────────────────────────────────────────────────────────────

/// "Ramesh rated you — rate him to see what he said."
class _PendingReviewsCard extends StatelessWidget {
  final List<Booking> bookings;
  const _PendingReviewsCard({required this.bookings});

  @override
  Widget build(BuildContext context) {
    final first = bookings.first;
    final name = first.helperName.split(' ').first;
    final more = bookings.length - 1;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(color: Color(0xFFFEF3C7), shape: BoxShape.circle),
          child: const Icon(Icons.lock_clock_rounded, color: Color(0xFFD97706), size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(more > 0 ? '$name and $more other helper${more == 1 ? '' : 's'} rated you' : '$name rated you',
                style: const TextStyle(fontWeight: FontWeight.bold, color: SarthiColors.ink, fontSize: 13.5)),
            const SizedBox(height: 2),
            const Text('Rate them back to see what they said.',
                style: TextStyle(fontSize: 12, color: Color(0xFF92400E))),
          ]),
        ),
        TextButton(
          onPressed: () => ReviewSheet.show(context, booking: first, asCustomer: true),
          child: const Text('Rate', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
        ),
      ]),
    );
  }
}

String _tagLabel(String id) {
  for (final t in [...helperToCustomerTags, ...customerToHelperTags]) {
    if (t.id == id) return t.label;
  }
  return id.replaceAll('_', ' ');
}

bool _tagPositive(String id) {
  for (final t in [...helperToCustomerTags, ...customerToHelperTags]) {
    if (t.id == id) return t.positive;
  }
  return true;
}

class _Stars extends StatelessWidget {
  final int value;
  final double size;
  const _Stars(this.value, {this.size = 15});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    for (var i = 0; i < 5; i++)
      Icon(i < value ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size, color: i < value ? const Color(0xFFF59E0B) : const Color(0xFFD1D5DB)),
  ]);
}

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool received;
  const _ReviewCard({required this.data, required this.received});

  @override
  Widget build(BuildContext context) {
    final name = '${data['fromFirstName'] ?? 'Helper'}';
    final rating = (data['rating'] as num?)?.toInt() ?? 0;
    final tags = (data['tags'] as List?)?.whereType<String>().toList() ?? const <String>[];
    final comment = '${data['comment'] ?? ''}'.trim();
    final service = '${data['serviceName'] ?? ''}';
    final ts = data['createdAt'];
    final when = ts is Timestamp ? DateFormat('d MMM yyyy').format(ts.toDate()) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: sarthiCard(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SarthiAvatar(name: name, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: SarthiColors.ink, fontSize: 13.5)),
              Text([if (service.isNotEmpty) service, if (when.isNotEmpty) when].join(' · '),
                  style: const TextStyle(fontSize: 11, color: SarthiColors.faint)),
            ]),
          ),
          _Stars(rating),
        ]),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final t in tags)
              SarthiChip(_tagLabel(t), color: _tagPositive(t) ? SarthiColors.green : SarthiColors.red),
          ]),
        ],
        if (comment.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('“$comment”', style: const TextStyle(fontSize: 12.5, color: SarthiColors.body, height: 1.4)),
        ],
      ]),
    );
  }
}

class _GivenReviewTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _GivenReviewTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final rating = (data['rating'] as num?)?.toInt() ?? 0;
    final service = '${data['serviceName'] ?? 'Service'}';
    final comment = '${data['comment'] ?? ''}'.trim();
    final tags = (data['tags'] as List?)?.whereType<String>().toList() ?? const <String>[];
    final ts = data['createdAt'];
    final when = ts is Timestamp ? DateFormat('d MMM').format(ts.toDate()) : '';
    final bookingId = '${data['bookingId'] ?? ''}';

    return GestureDetector(
      onTap: bookingId.isEmpty
          ? null
          : () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => BookingTrackerScreen(bookingId: bookingId))),
      child: Container(
        width: 210,
        padding: const EdgeInsets.all(14),
        decoration: sarthiCard(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(service,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: SarthiColors.ink, fontSize: 13)),
            ),
            Text(when, style: const TextStyle(fontSize: 10.5, color: SarthiColors.faint)),
          ]),
          const SizedBox(height: 6),
          _Stars(rating, size: 16),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              comment.isNotEmpty ? '“$comment”' : (tags.isEmpty ? 'No comment' : tags.map(_tagLabel).join(' · ')),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12,
                  color: comment.isEmpty && tags.isEmpty ? SarthiColors.faint : SarthiColors.body,
                  height: 1.35),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REPORTS
// ─────────────────────────────────────────────────────────────────────────────

class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ReportCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final status = '${data['status'] ?? 'open'}';
    final (label, color) = switch (status) {
      'resolved' || 'closed' => ('Resolved', SarthiColors.green),
      'in_review' || 'reviewing' => ('In review', SarthiColors.amber),
      _ => ('Open', SarthiColors.purple),
    };
    final ts = data['createdAt'];
    final when = ts is Timestamp ? DateFormat('d MMM yyyy, h:mm a').format(ts.toDate()) : '';
    final bookingId = '${data['bookingId'] ?? ''}';
    return GestureDetector(
      onTap: bookingId.isEmpty
          ? null
          : () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => BookingTrackerScreen(bookingId: bookingId))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: sarthiCard(),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(Icons.flag_rounded, color: color, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${data['reason'] ?? ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: SarthiColors.ink, fontSize: 13)),
              const SizedBox(height: 3),
              Text(when, style: const TextStyle(fontSize: 11, color: SarthiColors.faint)),
            ]),
          ),
          SarthiChip(label, color: color),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SAFETY FEATURES
// ─────────────────────────────────────────────────────────────────────────────

class _SafetyFeatures extends StatelessWidget {
  const _SafetyFeatures();

  static const _items = [
    (Icons.verified_user_rounded, 'Verified helpers',
    'Every helper submits Aadhaar and PAN, checked by our team before they can send prices.'),
    (Icons.pin_rounded, '4-digit start code',
    'Work starts only when you tell the helper the code shown in your booking. Never share it on a call.'),
    (Icons.payments_rounded, 'Pay after the work',
    'No money goes through the app. Pay the agreed price by cash or UPI only after the job is done.'),
    (Icons.chat_rounded, 'Chat inside the app',
    'Keep plans and price talk in the booking chat, so there is a record if something goes wrong.'),
    (Icons.star_half_rounded, 'Two-way reviews',
    'You rate helpers and helpers rate you. Ratings decide who appears first for everyone.'),
    (Icons.sos_rounded, 'Emergency help',
    'Use the emergency button on Home to reach police, ambulance or fire services quickly.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      decoration: sarthiCard(),
      child: Column(children: [
        for (var i = 0; i < _items.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_navy, _teal]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_items[i].$1, color: Colors.white, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_items[i].$2,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: SarthiColors.ink, fontSize: 13.5)),
                  const SizedBox(height: 2),
                  Text(_items[i].$3, style: const TextStyle(fontSize: 12, color: SarthiColors.muted, height: 1.4)),
                ]),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SMALL PIECES
// ─────────────────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final String text;
  final IconData icon;
  const _InfoCard({required this.text, this.icon = Icons.info_outline_rounded});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: sarthiCard(),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: SarthiColors.purple, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5, color: SarthiColors.muted, height: 1.4))),
    ]),
  );
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) => Container(
    height: 70,
    decoration: sarthiCard(),
    child: const Center(
        child: SizedBox(
            width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: SarthiColors.purple))),
  );
}