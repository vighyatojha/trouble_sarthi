// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../service/realtime_db_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  TRUST & SAFETY SCREEN  —  "Your Safety is Our Priority"
//  - No auto-popup of review sheet on load
//  - Smooth animations (no jank)
//  - Shows: Trust Score, Helper Ratings to User, Verification, Report History
//  - MutualReviewSheet kept here, called only on booking completion
// ═══════════════════════════════════════════════════════════════════════════════

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen>
    with SingleTickerProviderStateMixin {
  // Single animation controller for staggered card entrance
  // SingleTicker = much lighter than multiple controllers
  late final AnimationController _stagger;
  late final List<Animation<double>> _fades;

  @override
  void initState() {
    super.initState();

    // ─── NO auto-popup here. MutualReviewSheet.showForUser / showForHelper
    // should be called from your booking-completion flow, NOT from initState.

    _stagger = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    // Lightweight opacity-only stagger — avoids SlideTransition jank on scroll
    _fades = List.generate(7, (i) {
      final start = (i * 0.12).clamp(0.0, 0.8);
      final end = (start + 0.35).clamp(0.0, 1.0);
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _stagger,
          curve: Interval(start, end, curve: Curves.easeOut),
        ),
      );
    });
  }

  @override
  void dispose() {
    _stagger.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FB),
        body: CustomScrollView(
          // RepaintBoundary-friendly physics
          physics: const ClampingScrollPhysics(),
          slivers: [
            // ── Hero header ──────────────────────────────────────────
            SliverToBoxAdapter(child: _TrustHero(stagger: _stagger)),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 24),

                  // ── Trust Score Card ─────────────────────────────
                  _FadeIn(
                    animation: _fades[0],
                    child: const _TrustScoreCard(),
                  ),

                  const SizedBox(height: 28),
                  _sectionLabel('VERIFICATION STATUS'),
                  const SizedBox(height: 12),

                  // ── Verification chips ───────────────────────────
                  _FadeIn(
                    animation: _fades[1],
                    child: const _VerificationRow(),
                  ),

                  const SizedBox(height: 28),
                  _sectionLabel('HELPER RATINGS FOR YOU'),
                  const SizedBox(height: 4),
                  _FadeIn(
                    animation: _fades[2],
                    child: const _SectionSubtitle(
                      'Ratings helpers have given you across bookings.',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Helper-to-User ratings feed ──────────────────
                  _FadeIn(
                    animation: _fades[3],
                    child: const _HelperRatingsFeed(),
                  ),

                  const SizedBox(height: 28),
                  _sectionLabel('REPORT HISTORY'),
                  const SizedBox(height: 12),

                  // ── Report history ───────────────────────────────
                  _FadeIn(
                    animation: _fades[4],
                    child: const _ReportHistorySection(),
                  ),

                  const SizedBox(height: 28),

                  // ── Learn More CTA ───────────────────────────────
                  _FadeIn(
                    animation: _fades[5],
                    child: const _LearnMoreButton(),
                  ),

                  // ── Demo Banner ──────────────────────────────────
                  _FadeIn(
                    animation: _fades[6],
                    child: _DemoBanner(
                      onDemoAsUser: () => MutualReviewSheet.showForUser(
                        context,
                        bookingId: 'DEMO-001',
                        helperId: 'helper_demo',
                        helperName: 'Rajesh Kumar',
                        serviceName: 'Emergency Plumbing',
                        demoMode: true,
                      ),
                      onDemoAsHelper: () => MutualReviewSheet.showForHelper(
                        context,
                        bookingId: 'DEMO-001',
                        userId: 'user_demo',
                        userName: 'Arjun Mehta',
                        serviceName: 'Emergency Plumbing',
                        demoMode: true,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  const SizedBox(height: 32),
                  // Privacy note
                  const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_rounded, size: 12, color: Color(0xFFB0B8CC)),
                        SizedBox(width: 5),
                        Text(
                          'Your data is end-to-end encrypted',
                          style: TextStyle(fontSize: 11, color: Color(0xFFB0B8CC)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.bold,
      color: Color(0xFF9CA3AF),
      letterSpacing: 1.4,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Lightweight fade-only wrapper (no translate = no jank)
// ─────────────────────────────────────────────────────────────────────────────
class _FadeIn extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  const _FadeIn({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: animation, child: child);
}

class _SectionSubtitle extends StatelessWidget {
  final String text;
  const _SectionSubtitle(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), height: 1.4),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO SECTION  (simplified — pulsing animation removed to cut repaints)
// ─────────────────────────────────────────────────────────────────────────────
class _TrustHero extends StatelessWidget {
  final AnimationController stagger;
  const _TrustHero({required this.stagger});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F2042), Color(0xFF1A3A6B), Color(0xFF0D6E6E)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Nav row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'Trust & Safety',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  // Shield icon button
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shield_rounded,
                        color: Colors.white, size: 18),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Static shield (no pulsing = no repaint every frame)
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0D9488).withOpacity(0.18),
                  ),
                ),
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.22),
                        Colors.white.withOpacity(0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.28), width: 1.5),
                  ),
                  child: const Icon(Icons.shield_rounded,
                      size: 38, color: Colors.white),
                ),
              ],
            ),

            const SizedBox(height: 18),

            const Text(
              'Your Safety is\nOur Priority',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Verified helpers · Secure chats · Mutual reviews',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.65),
                  height: 1.5,
                ),
              ),
            ),

            const SizedBox(height: 26),

            // Curved bottom edge
            Container(
              height: 26,
              decoration: const BoxDecoration(
                color: Color(0xFFF4F6FB),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TRUST SCORE CARD  (like reference image — big star + score + badge)
// ─────────────────────────────────────────────────────────────────────────────
class _TrustScoreCard extends StatelessWidget {
  const _TrustScoreCard();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: uid != null
          ? FirebaseFirestore.instance.collection('users').doc(uid).snapshots()
          : null,
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>?;
        final avgRating =
            (data?['avgRating'] as num?)?.toDouble() ?? 0.0;
        final reviewCount = (data?['reviewCount'] as int?) ?? 0;

        // Determine badge label
        String badge = 'New Member';
        if (avgRating >= 4.8) badge = 'Top 5% of Users';
        else if (avgRating >= 4.5) badge = 'Top 15% of Users';
        else if (avgRating >= 4.0) badge = 'Trusted User';
        else if (avgRating >= 3.0) badge = 'Good Standing';

        final displayScore = reviewCount == 0
            ? '—'
            : avgRating.toStringAsFixed(1);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3B1F8C), Color(0xFF1A3A6B), Color(0xFF0D6E6E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D6E6E).withOpacity(0.28),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              const Text(
                'YOUR TRUST SCORE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFB2E8E8),
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Icon(Icons.star_rounded,
                      color: Color(0xFFFBBF24), size: 42),
                  const SizedBox(width: 8),
                  Text(
                    displayScore,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      '/5',
                      style: TextStyle(
                        fontSize: 18,
                        color: Color(0xFFB2E8E8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.20)),
                ),
                child: Text(
                  reviewCount == 0 ? 'No ratings yet' : badge,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              if (reviewCount > 0) ...[
                const SizedBox(height: 10),
                Text(
                  'Based on $reviewCount helper rating${reviewCount == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.55),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VERIFICATION ROW  (Mobile Verified, Email Verified, KYC Done)
// ─────────────────────────────────────────────────────────────────────────────
class _VerificationRow extends StatelessWidget {
  const _VerificationRow();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final user = FirebaseAuth.instance.currentUser;

    // Use Firebase Auth for email/phone verification state
    final emailVerified = user?.emailVerified ?? false;
    final phoneVerified = user?.phoneNumber != null;

    return StreamBuilder<DocumentSnapshot>(
      stream: uid != null
          ? FirebaseFirestore.instance.collection('users').doc(uid).snapshots()
          : null,
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>?;
        final kycDone = (data?['kycDone'] as bool?) ?? false;

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              _VerifChip(
                icon: Icons.phone_android_rounded,
                label: 'Mobile\nVerified',
                done: phoneVerified,
              ),
              _VerifChip(
                icon: Icons.email_rounded,
                label: 'Email\nVerified',
                done: emailVerified,
              ),
              _VerifChip(
                icon: Icons.fingerprint_rounded,
                label: 'KYC\nDone',
                done: kycDone,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VerifChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool done;
  const _VerifChip(
      {required this.icon, required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF5B21B6);
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: done
                  ? const Color(0xFFEDE9FE)
                  : const Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                color: done ? accent : const Color(0xFFD1D5DB), size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 5),
          Icon(
            done ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 16,
            color: done ? const Color(0xFF22C55E) : const Color(0xFFD1D5DB),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER RATINGS FEED  (ratings helpers gave to THIS user)
// ─────────────────────────────────────────────────────────────────────────────
class _HelperRatingsFeed extends StatelessWidget {
  const _HelperRatingsFeed();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const _EmptyRatings();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collectionGroup('helper_to_user')
          .where('revieweeId', isEqualTo: uid)
          .orderBy('createdAt', descending: true) // FIXED (Problem C/D): index-backed sort
          .limit(10)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _SimpleShimmer(height: 90, count: 2);
        }

        // FIXED: removed manual ..sort() — Firestore orderBy handles this now
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const _EmptyRatings();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${docs.length} rating${docs.length == 1 ? '' : 's'} received',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
                if (docs.length >= 5)
                  GestureDetector(
                    onTap: () {},
                    child: const Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5B21B6),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ...docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _HelperRatingCard(data: data),
              );
            }),
          ],
        );
      },
    );
  }
}

class _HelperRatingCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _HelperRatingCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final helperName = data['reviewerName'] as String? ??
        data['revieweeName'] as String? ??
        'Helper';
    final stars = (data['starRating'] as int?) ?? 0;
    final service = data['serviceName'] as String? ?? '';
    final answers = data['answers'] as Map<String, dynamic>? ?? {};
    final ts = data['createdAt'] as Timestamp?;

    // Pick first answer as the "comment" to display
    final comment = answers.values.isNotEmpty
        ? answers.values.first.toString()
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEDE9FE),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                helperName.isNotEmpty ? helperName[0].toUpperCase() : 'H',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5B21B6),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        helperName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),
                    // Star rating
                    Row(
                      children: [
                        Text(
                          '$stars.0',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(Icons.star_rounded,
                            color: Color(0xFFF59E0B), size: 16),
                      ],
                    ),
                  ],
                ),
                if (service.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    service,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF9CA3AF)),
                  ),
                ],
                if (comment != null) ...[
                  const SizedBox(height: 7),
                  Text(
                    '"$comment"',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF374151),
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ],
                if (ts != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _relTime(ts.toDate()),
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFFB0B8CC)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _relTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday, ${_time(dt)}';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _time(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }
}

class _EmptyRatings extends StatelessWidget {
  const _EmptyRatings();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0F0F5)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFFEDE9FE),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.star_outline_rounded,
                size: 26, color: Color(0xFF5B21B6)),
          ),
          const SizedBox(height: 12),
          const Text(
            'No helper ratings yet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Ratings from helpers will appear here\nafter completed bookings.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF9CA3AF),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REPORT HISTORY SECTION
// ─────────────────────────────────────────────────────────────────────────────
class _ReportHistorySection extends StatelessWidget {
  const _ReportHistorySection();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .where('reporterId', isEqualTo: uid)
          .limit(5)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _SimpleShimmer(height: 70, count: 2);
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
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFF0F0F5)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: Color(0xFF22C55E), size: 22),
                SizedBox(width: 12),
                Text(
                  'No reports raised — clean record!',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: docs.asMap().entries.map((e) {
              final data = e.value.data() as Map<String, dynamic>;
              final title = data['title'] as String? ?? 'Report';
              final ts = data['createdAt'] as Timestamp?;
              final status =
              (data['status'] as String? ?? 'pending').toLowerCase();
              final isLast = e.key == docs.length - 1;

              return Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : const Border(
                      bottom: BorderSide(color: Color(0xFFF3F4F6))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          if (ts != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                'Raised on ${_fmtDate(ts.toDate())}',
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF9CA3AF)),
                              ),
                            ),
                        ],
                      ),
                    ),
                    _StatusBadge(status: status),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  String _fmtDate(DateTime dt) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    String label;
    switch (status) {
      case 'resolved':
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF065F46);
        label = 'RESOLVED';
        break;
      case 'under_review':
      case 'under review':
        bg = const Color(0xFFE0E7FF);
        fg = const Color(0xFF3730A3);
        label = 'UNDER\nREVIEW';
        break;
      default:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        label = 'PENDING';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: fg,
          letterSpacing: 0.4,
          height: 1.3,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DEMO BANNER  — shows two buttons to trigger MutualReviewSheet in demo mode
// Remove this widget (and its _FadeIn above) before production release.
// ─────────────────────────────────────────────────────────────────────────────
class _DemoBanner extends StatelessWidget {
  final VoidCallback onDemoAsUser;
  final VoidCallback onDemoAsHelper;
  const _DemoBanner({required this.onDemoAsUser, required this.onDemoAsHelper});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE9D8FD), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3B1F8C), Color(0xFF5B21B6), Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.play_circle_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('🎯  Try the Mutual Review Feature',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  SizedBox(height: 2),
                  Text('Pre-filled demo — tap to experience the full flow',
                      style: TextStyle(fontSize: 11, color: Colors.white70)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('DEMO',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold,
                        color: Colors.white, letterSpacing: 1)),
              ),
            ]),
          ),

          // ── Description ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('After every booking, both parties review each other.',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937))),
              const SizedBox(height: 6),
              const Text(
                'This builds a trust ecosystem — helpers rate users, users rate helpers. '
                    'Bad actors get flagged automatically. Tap a role below to see the full sheet.',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.5),
              ),
              const SizedBox(height: 14),

              // ── Flow steps ─────────────────────────────────────
              _FlowStep(
                number: '1',
                color: const Color(0xFF7C3AED),
                title: 'Questionnaire',
                sub: '6 quick questions about the experience',
              ),
              _FlowStep(
                number: '2',
                color: const Color(0xFF0891B2),
                title: 'Star Rating',
                sub: 'Overall 1–5 star rating for the person',
              ),
              _FlowStep(
                number: '3',
                color: const Color(0xFF059669),
                title: 'Submit & Update',
                sub: 'Score saved, avg rating recalculated live',
                isLast: true,
              ),
            ]),
          ),

          // ── Divider ───────────────────────────────────────────────
          const Divider(height: 1, color: Color(0xFFF0EBF9), indent: 18, endIndent: 18),

          // ── Two buttons ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(children: [
              const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.info_outline_rounded, size: 12, color: Color(0xFF9CA3AF)),
                SizedBox(width: 5),
                Text('All answers are pre-filled — just tap through',
                    style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                // User → rates Helper
                Expanded(
                  child: _DemoButton(
                    icon: Icons.person_rounded,
                    label: 'As User',
                    sub: 'Rating a Helper',
                    color: const Color(0xFF7C3AED),
                    bgColor: const Color(0xFFEDE9FE),
                    onTap: onDemoAsUser,
                  ),
                ),
                const SizedBox(width: 10),
                // Helper → rates User
                Expanded(
                  child: _DemoButton(
                    icon: Icons.engineering_rounded,
                    label: 'As Helper',
                    sub: 'Rating a Customer',
                    color: const Color(0xFF0D9488),
                    bgColor: const Color(0xFFCCFBF1),
                    onTap: onDemoAsHelper,
                  ),
                ),
              ]),
            ]),
          ),
        ],
      ),
    );
  }
}

class _FlowStep extends StatelessWidget {
  final String number, title, sub;
  final Color color;
  final bool isLast;
  const _FlowStep({
    required this.number, required this.title,
    required this.sub, required this.color, this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(color: color.withOpacity(0.12),
                shape: BoxShape.circle),
            child: Center(child: Text(number,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color))),
          ),
          if (!isLast)
            Container(width: 1.5, height: 16,
                color: color.withOpacity(0.20),
                margin: const EdgeInsets.symmetric(vertical: 2)),
        ]),
        const SizedBox(width: 10),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 12,
                fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
            Text(sub, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
          ]),
        ),
      ]),
    );
  }
}

class _DemoButton extends StatefulWidget {
  final IconData icon;
  final String label, sub;
  final Color color, bgColor;
  final VoidCallback onTap;
  const _DemoButton({required this.icon, required this.label, required this.sub,
    required this.color, required this.bgColor, required this.onTap});

  @override
  State<_DemoButton> createState() => _DemoButtonState();
}

class _DemoButtonState extends State<_DemoButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        transform: Matrix4.identity()..scale(_pressed ? 0.96 : 1.0),
        transformAlignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: widget.bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: widget.color.withOpacity(0.25)),
          boxShadow: _pressed ? null : [
            BoxShadow(color: widget.color.withOpacity(0.12),
                blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
            child: Icon(widget.icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 8),
          Text(widget.label, style: TextStyle(fontSize: 13,
              fontWeight: FontWeight.bold, color: widget.color)),
          const SizedBox(height: 2),
          Text(widget.sub, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Launch Demo →',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LEARN MORE BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _LearnMoreButton extends StatelessWidget {
  const _LearnMoreButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B1F8C), Color(0xFF5B21B6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5B21B6).withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {},
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.help_outline_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text(
                'Learn More About Safety',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SIMPLE SHIMMER  (lightweight — no shimmer package needed)
// ─────────────────────────────────────────────────────────────────────────────
class _SimpleShimmer extends StatefulWidget {
  final double height;
  final int count;
  const _SimpleShimmer({required this.height, required this.count});

  @override
  State<_SimpleShimmer> createState() => _SimpleShimmerState();
}

class _SimpleShimmerState extends State<_SimpleShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Column(
        children: List.generate(
          widget.count,
              (_) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            height: widget.height,
            decoration: BoxDecoration(
              color: Color.lerp(
                  const Color(0xFFF3F4F6), const Color(0xFFE5E7EB), _c.value),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  MUTUAL REVIEW SHEET — Call this from booking completion, NOT from initState
//
//  Usage (from your booking completion screen):
//    MutualReviewSheet.showForUser(context, bookingId: ..., helperId: ..., ...)
//    MutualReviewSheet.showForHelper(context, bookingId: ..., userId: ..., ...)
// ═══════════════════════════════════════════════════════════════════════════════

enum _ReviewerRole { user, helper }

class MutualReviewSheet extends StatefulWidget {
  final String bookingId;
  final String revieweeId;
  final String revieweeName;
  final String serviceName;
  final _ReviewerRole role;
  // ── Set to true to pre-fill with demo data for team presentations.
  // ── Remove or set false before production release.
  final bool demoMode;

  const MutualReviewSheet._({
    required this.bookingId,
    required this.revieweeId,
    required this.revieweeName,
    required this.serviceName,
    required this.role,
    this.demoMode = false,
  });

  static Future<void> showForUser(
      BuildContext context, {
        required String bookingId,
        required String helperId,
        required String helperName,
        required String serviceName,
        bool demoMode = false, // ← pass true when demoing to team
      }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => MutualReviewSheet._(
        bookingId: bookingId,
        revieweeId: helperId,
        revieweeName: helperName,
        serviceName: serviceName,
        role: _ReviewerRole.user,
        demoMode: demoMode,
      ),
    );
  }

  static Future<void> showForHelper(
      BuildContext context, {
        required String bookingId,
        required String userId,
        required String userName,
        required String serviceName,
        bool demoMode = false, // ← pass true when demoing to team
      }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => MutualReviewSheet._(
        bookingId: bookingId,
        revieweeId: userId,
        revieweeName: userName,
        serviceName: serviceName,
        role: _ReviewerRole.helper,
        demoMode: demoMode,
      ),
    );
  }

  @override
  State<MutualReviewSheet> createState() => _MutualReviewSheetState();
}

class _MutualReviewSheetState extends State<MutualReviewSheet>
    with SingleTickerProviderStateMixin {
  int _step = 0;
  int _starRating = 0;
  bool _submitting = false;
  final Map<int, int> _answers = {};

  final TextEditingController _noteController = TextEditingController();

  late final AnimationController _doneAnim;
  late final Animation<double> _doneScale;

  @override
  void initState() {
    super.initState();
    _doneAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _doneScale = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _doneAnim, curve: Curves.elasticOut));

    if (widget.demoMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final qs = widget.role == _ReviewerRole.user
            ? _userQuestions(widget.serviceName)
            : _helperQuestions(widget.serviceName);
        setState(() {
          for (var i = 0; i < qs.length; i++) {
            _answers[i] = 0;
          }
          _starRating = 5;
          _noteController.text = widget.role == _ReviewerRole.user
              ? 'Rajesh was extremely professional and fixed the issue faster than expected. Highly recommend!'
              : 'Arjun was very respectful and had all the necessary tools ready. Great customer!';
        });
      });
    }
  }

  @override
  void dispose() {
    _doneAnim.dispose();
    _noteController.dispose();
    super.dispose();
  }

  List<_ReviewQuestion> get _questions => widget.role == _ReviewerRole.user
      ? _userQuestions(widget.serviceName)
      : _helperQuestions(widget.serviceName);

  bool get _allAnswered => _answers.length == _questions.length;

  Future<void> _submit() async {
    if (_starRating == 0) return;
    setState(() => _submitting = true);

    try {
      final reviewerId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final isUserRole = widget.role == _ReviewerRole.user;
      final note = _noteController.text.trim();

      final reviewData = {
        'bookingId': widget.bookingId,
        'reviewerId': reviewerId,
        'revieweeId': widget.revieweeId,
        'revieweeName': widget.revieweeName,
        'role': isUserRole ? 'user' : 'helper',
        'starRating': _starRating,
        'answers': _answers.map(
                (k, v) => MapEntry(_questions[k].question, _questions[k].options[v])),
        if (note.isNotEmpty) 'additionalNote': note,
        'serviceName': widget.serviceName,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('reviews')
          .doc(widget.bookingId)
          .collection(isUserRole ? 'user_to_helper' : 'helper_to_user')
          .add(reviewData);

      await FirebaseFirestore.instance.collection('reviewHistory').add({
        'userId':      isUserRole
            ? FirebaseAuth.instance.currentUser?.uid ?? ''
            : widget.revieweeId,
        'helperId':    isUserRole
            ? widget.revieweeId
            : FirebaseAuth.instance.currentUser?.uid ?? '',
        'helperName':  isUserRole ? widget.revieweeName : '',
        'bookingId':   widget.bookingId,
        'serviceName': widget.serviceName,
        'rating':      _starRating,
        'answers':     _answers.map(
                (k, v) => MapEntry(_questions[k].question, _questions[k].options[v])),
        'role':        isUserRole ? 'user' : 'helper',
        'createdAt':   FieldValue.serverTimestamp(),
      });

      // ── FIXED (Problem B): Booking lookup with docId fallback ────────────
      if (isUserRole) {
        final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
        // Try by bookingCode field first
        var bookingSnap = await FirebaseFirestore.instance
            .collection('bookings')
            .where('bookingCode', isEqualTo: widget.bookingId)
            .where('userId', isEqualTo: currentUid)
            .limit(1).get();
        // Fallback: treat bookingId as the Firestore document ID
        if (bookingSnap.docs.isEmpty) {
          final directDoc = await FirebaseFirestore.instance
              .collection('bookings').doc(widget.bookingId).get();
          if (directDoc.exists) {
            await directDoc.reference.update({
              'status': 'completed',
              'completedAt': FieldValue.serverTimestamp(),
            });
          }
        } else {
          await bookingSnap.docs.first.reference.update({
            'status': 'completed',
            'completedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // ── FIXED (Problem A): Safe avg rating update with null/missing-doc guard
      final targetCollection = isUserRole ? 'helpers' : 'users';
      final targetDocRef = FirebaseFirestore.instance
          .collection(targetCollection).doc(widget.revieweeId);

      await FirebaseFirestore.instance.runTransaction((txn) async {
        final snap = await txn.get(targetDocRef);
        final prev = (snap.exists ? (snap.data()?['totalRatingSum'] as num?)?.toDouble() : null) ?? 0.0;
        final count = (snap.exists ? (snap.data()?['reviewCount'] as int?) : null) ?? 0;
        final newSum = prev + _starRating;
        final newCount = count + 1;
        txn.set(
          targetDocRef,
          {
            'totalRatingSum': newSum,
            'reviewCount': newCount,
            'avgRating': double.parse((newSum / newCount).toStringAsFixed(1)),
            'lastReviewedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });

      // ── Auto-flag low-rated users ─────────────────────────────────────────
      if (!isUserRole && _starRating <= 2) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.revieweeId)
            .set({
          'flagCount':     FieldValue.increment(1),
          'lastFlaggedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // ── Firestore notification ────────────────────────────────────────────
      if (isUserRole) {
        final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
        await FirebaseFirestore.instance
            .collection('notifications')
            .doc(currentUid)
            .collection('items')
            .add({
          'type':      'service_completed',
          'title':     'Service Completed',
          'body':      'How was your experience with ${widget.serviceName}? Tap to rate.',
          'bookingId': widget.bookingId,
          'rating':    0,
          'read':      false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      setState(() {
        _step = 2;
        _submitting = false;
      });
      _doneAnim.forward();

    } catch (e) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting review: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: child,
        ),
        child: _step == 2
            ? _DoneView(
          key: const ValueKey('done'),
          role: widget.role,
          revieweeName: widget.revieweeName,
          anim: _doneScale,
          onClose: () async {
            if (widget.role == _ReviewerRole.user) {
              final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
              final chatId = '${uid}_${widget.revieweeId}';
              await RealtimeDbService.instance.deleteChat(chatId);
            }
            if (context.mounted) Navigator.pop(context);
          },
        )
            : _step == 1
            ? _RatingView(
          key: const ValueKey('rating'),
          role: widget.role,
          revieweeName: widget.revieweeName,
          starRating: _starRating,
          submitting: _submitting,
          onStar: (s) => setState(() => _starRating = s),
          onBack: () => setState(() => _step = 0),
          onSubmit: _submit,
        )
            : _QuestionsView(
          key: const ValueKey('questions'),
          role: widget.role,
          questions: _questions,
          answers: _answers,
          revieweeName: widget.revieweeName,
          serviceName: widget.serviceName,
          allAnswered: _allAnswered,
          noteController: _noteController,
          onAnswer: (q, a) => setState(() => _answers[q] = a),
          onNext: () => setState(() => _step = 1),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 0 — QUESTIONS VIEW
// ─────────────────────────────────────────────────────────────────────────────
class _QuestionsView extends StatelessWidget {
  final _ReviewerRole role;
  final List<_ReviewQuestion> questions;
  final Map<int, int> answers;
  final String revieweeName;
  final String serviceName;
  final bool allAnswered;
  final TextEditingController noteController;
  final Function(int q, int a) onAnswer;
  final VoidCallback onNext;

  const _QuestionsView({
    super.key,
    required this.role,
    required this.questions,
    required this.answers,
    required this.revieweeName,
    required this.serviceName,
    required this.allAnswered,
    required this.noteController,
    required this.onAnswer,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = role == _ReviewerRole.user;
    final accentColor =
    isUser ? const Color(0xFF7C3AED) : const Color(0xFF0D9488);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.70,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 42,
            height: 4,
            decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    isUser
                        ? Icons.rate_review_rounded
                        : Icons.engineering_rounded,
                    color: accentColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isUser ? 'Review $revieweeName' : 'Review this Customer',
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937)),
                      ),
                      Text(
                        isUser
                            ? 'How was your $serviceName experience?'
                            : 'How did the customer treat you?',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: _ProgressBar(
              answered: answers.length,
              total: questions.length,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
              // questions + 1 extra item for the optional note box
              itemCount: questions.length + 1,
              itemBuilder: (_, i) {
                // Last item → optional additional note text field
                if (i == questions.length) {
                  return _AdditionalNoteBox(
                    controller: noteController,
                    accentColor: accentColor,
                  );
                }
                return _QuestionCard(
                  index: i,
                  question: questions[i],
                  selectedOption: answers[i],
                  accentColor: accentColor,
                  onSelect: (a) => onAnswer(i, a),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: allAnswered ? onNext : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  disabledBackgroundColor: const Color(0xFFE5E7EB),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                ),
                child: Text(
                  allAnswered
                      ? 'Next — Give Your Rating →'
                      : 'Answer all questions to continue',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: allAnswered ? Colors.white : const Color(0xFF9CA3AF),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OPTIONAL ADDITIONAL NOTE BOX  (appears after all questions in the list)
// ─────────────────────────────────────────────────────────────────────────────
class _AdditionalNoteBox extends StatelessWidget {
  final TextEditingController controller;
  final Color accentColor;

  const _AdditionalNoteBox({
    required this.controller,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0F0F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.edit_note_rounded,
                    color: accentColor, size: 14),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Anything else you\'d like to add? (Optional)',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                    height: 1.4,
                  ),
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'OPTIONAL',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 34),
            child: Text(
              'Share anything not covered in the questions above.',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF9CA3AF),
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Text field
          TextField(
            controller: controller,
            maxLines: 4,
            maxLength: 300,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF1F2937),
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText: 'e.g. "He brought extra tools without being asked…"',
              hintStyle: const TextStyle(
                fontSize: 13,
                color: Color(0xFFD1D5DB),
                height: 1.5,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(14),
              counterStyle: const TextStyle(
                fontSize: 10,
                color: Color(0xFFB0B8CC),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: accentColor, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final int answered;
  final int total;
  final Color color;
  const _ProgressBar(
      {required this.answered, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$answered / $total answered',
                style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600)),
            Text('${total == 0 ? 0 : ((answered / total) * 100).round()}%',
                style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : answered / total,
            minHeight: 6,
            backgroundColor: color.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final int index;
  final _ReviewQuestion question;
  final int? selectedOption;
  final Color accentColor;
  final ValueChanged<int> onSelect;

  const _QuestionCard({
    required this.index,
    required this.question,
    required this.selectedOption,
    required this.accentColor,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: selectedOption != null
            ? accentColor.withOpacity(0.04)
            : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selectedOption != null
              ? accentColor.withOpacity(0.22)
              : const Color(0xFFF0F0F5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  question.question,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                    height: 1.4,
                  ),
                ),
              ),
              if (selectedOption != null)
                Icon(Icons.check_circle_rounded, color: accentColor, size: 18),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: question.options.asMap().entries.map((e) {
              final isSelected = selectedOption == e.key;
              return GestureDetector(
                onTap: () => onSelect(e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: isSelected ? accentColor : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected
                          ? accentColor
                          : const Color(0xFFE5E7EB),
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                      BoxShadow(
                        color: accentColor.withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                        : null,
                  ),
                  child: Text(
                    e.value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF374151),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 1 — STAR RATING VIEW
// ─────────────────────────────────────────────────────────────────────────────
class _RatingView extends StatelessWidget {
  final _ReviewerRole role;
  final String revieweeName;
  final int starRating;
  final bool submitting;
  final ValueChanged<int> onStar;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  const _RatingView({
    super.key,
    required this.role,
    required this.revieweeName,
    required this.starRating,
    required this.submitting,
    required this.onStar,
    required this.onBack,
    required this.onSubmit,
  });

  String get _ratingLabel {
    switch (starRating) {
      case 1: return 'Very Poor 😞';
      case 2: return 'Below Average 😕';
      case 3: return 'Average 🙂';
      case 4: return 'Good 😊';
      case 5: return 'Excellent! 🌟';
      default: return 'Tap a star to rate';
    }
  }

  Color get _accentColor => role == _ReviewerRole.user
      ? const Color(0xFF7C3AED)
      : const Color(0xFF0D9488);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 24),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_accentColor.withOpacity(0.8), _accentColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              role == _ReviewerRole.user
                  ? Icons.engineering_rounded
                  : Icons.person_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            revieweeName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            role == _ReviewerRole.user
                ? 'How would you rate this helper overall?'
                : 'How would you rate this customer overall?',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF6B7280), height: 1.4),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < starRating;
              return GestureDetector(
                onTap: () => onStar(i + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: filled ? 48 : 44,
                    color: filled
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFD1D5DB),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Text(
              _ratingLabel,
              key: ValueKey(_ratingLabel),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: starRating > 0
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF9CA3AF),
              ),
            ),
          ),
          const SizedBox(height: 36),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onBack,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('← Back',
                      style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed:
                  starRating > 0 && !submitting ? onSubmit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentColor,
                    disabledBackgroundColor: const Color(0xFFE5E7EB),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: submitting
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                      : const Text('Submit Review',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 2 — DONE VIEW
// ─────────────────────────────────────────────────────────────────────────────
class _DoneView extends StatelessWidget {
  final _ReviewerRole role;
  final String revieweeName;
  final Animation<double> anim;
  final VoidCallback onClose;

  const _DoneView({
    super.key,
    required this.role,
    required this.revieweeName,
    required this.anim,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: anim,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF059669), Color(0xFF0D9488)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF059669).withOpacity(0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.check_rounded,
                  color: Colors.white, size: 46),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Review Submitted!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            role == _ReviewerRole.user
                ? 'Thank you for reviewing $revieweeName.\nYour feedback helps others make safe choices.'
                : 'Thank you for your honest feedback.\nIt helps keep our community genuine & safe.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF6B7280), height: 1.6),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFF059669).withOpacity(0.20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.swap_horiz_rounded,
                    color: Color(0xFF059669), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    role == _ReviewerRole.user
                        ? '$revieweeName will also rate this booking — keeping things fair for everyone.'
                        : 'The customer has also been asked to rate this booking.',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF374151),
                        height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onClose,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F2937),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Close',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  REVIEW QUESTION DATA
// ═══════════════════════════════════════════════════════════════════════════════

class _ReviewQuestion {
  final String question;
  final List<String> options;
  const _ReviewQuestion(this.question, this.options);
}

List<_ReviewQuestion> _userQuestions(String serviceName) => [
  _ReviewQuestion(
    'Did the helper arrive on time?',
    ['Yes, right on time', 'Slightly late', 'Very late', 'Did not arrive'],
  ),
  _ReviewQuestion(
    'How was the quality of work done?',
    ['Excellent', 'Good', 'Average', 'Poor'],
  ),
  _ReviewQuestion(
    'Was the helper professional and polite?',
    ['Very professional', 'Mostly yes', 'Somewhat', 'Not at all'],
  ),
  _ReviewQuestion(
    'Did the helper explain the work clearly?',
    ['Yes, clearly', 'Partially', 'No explanation given'],
  ),
  _ReviewQuestion(
    'Was the price fair for the service?',
    ['Very fair', 'Somewhat fair', 'Overcharged', 'Price not discussed'],
  ),
  _ReviewQuestion(
    'Would you book this helper again?',
    ['Definitely yes', 'Maybe', 'Probably not', 'No'],
  ),
];

List<_ReviewQuestion> _helperQuestions(String serviceName) => [
  _ReviewQuestion(
    'Did the customer treat you respectfully?',
    ['Very respectfully', 'Mostly yes', 'Somewhat rude', 'Disrespectful'],
  ),
  _ReviewQuestion(
    'Was the service request genuine?',
    [
      'Yes, completely genuine',
      'Seemed genuine',
      'Slightly suspicious',
      'Not genuine'
    ],
  ),
  _ReviewQuestion(
    'Did the customer provide correct address & access?',
    ['Yes, everything was clear', 'Minor issues', 'Address was wrong', 'No access given'],
  ),
  _ReviewQuestion(
    'Was payment handled smoothly?',
    ['Yes, no issues', 'Minor delay', 'Refused to pay full', 'Payment issues'],
  ),
  _ReviewQuestion(
    'Did the customer make unreasonable demands?',
    ['No, totally fair', 'Minor extra requests', 'Several extras', 'Very unreasonable'],
  ),
  _ReviewQuestion(
    'Would you accept a booking from this customer again?',
    ['Definitely yes', 'Maybe', 'Hesitant', 'No'],
  ),
];