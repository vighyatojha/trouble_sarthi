// lib/screens/request/request_pitches_screen.dart
// Step 2 (customer): watch price quotes arrive, ranked by the server, and pick one.

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/job_api.dart';
import '../../core/job_media_widgets.dart';
import '../../core/job_models.dart';
import 'booking_tracker_screen.dart';

const _purple = Color(0xFF7C3AED);
const _ink = Color(0xFF111827);
const _muted = Color(0xFF6B7280);
const _green = Color(0xFF059669);
const _red = Color(0xFFDC2626);

class RequestPitchesScreen extends StatefulWidget {
  final String jobId;
  const RequestPitchesScreen({super.key, required this.jobId});

  @override
  State<RequestPitchesScreen> createState() => _RequestPitchesScreenState();
}

class _RequestPitchesScreenState extends State<RequestPitchesScreen> {
  Timer? _ticker;
  bool _accepting = false;
  bool _navigatedToBooking = false;
  Stream<List<RankedPitch>>? _pitchStream; // created once, not on every rebuild

  @override
  void initState() {
    super.initState();
    // Re-draw every second for the countdowns.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _openBooking(String bookingId) {
    if (_navigatedToBooking) return;
    _navigatedToBooking = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => BookingTrackerScreen(bookingId: bookingId)),
      );
    });
  }

  Future<void> _accept(JobRequest job, RankedPitch r, List<RankedPitch> shown) async {
    final p = r.pitch;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Book ${r.helper.name}?'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Fixed price: ₹${p.amount}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink)),
          const SizedBox(height: 8),
          const Text(
            'You pay this amount directly to the helper (cash or UPI) after the work is done. '
                'Nothing is charged in the app.',
            style: TextStyle(color: _muted, height: 1.35),
          ),
          const SizedBox(height: 8),
          const Text('Other quotes will be closed.', style: TextStyle(color: _muted)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _purple),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Book'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _accepting = true);
    try {
      final bookingId = await JobApi.instance.acceptPitch(job, r, shown);
      _openBooking(bookingId);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating, backgroundColor: _red));
      }
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  Future<void> _cancelRequest(JobRequest job) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this request?'),
        content: const Text('Helpers will stop sending prices for it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep it')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel request', style: TextStyle(color: _red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await JobApi.instance.cancelJobRequest(job.id);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<JobRequest?>(
      stream: JobApi.instance.job(widget.jobId),
      builder: (context, jobSnap) {
        final job = jobSnap.data;
        if (jobSnap.hasError) {
          return _scaffold(null, const _Message(icon: Icons.error_outline, text: 'Could not load this request.'));
        }
        if (job == null) {
          return _scaffold(null, const Center(child: CircularProgressIndicator()));
        }
        if (job.status == JobStatus.booked && job.bookingId != null) {
          _openBooking(job.bookingId!);
        }
        return _scaffold(job, _body(job));
      },
    );
  }

  Widget _scaffold(JobRequest? job, Widget body) => Scaffold(
    backgroundColor: const Color(0xFFF7F7FB),
    appBar: AppBar(
      backgroundColor: Colors.white,
      foregroundColor: _ink,
      elevation: 0.5,
      title: Text(job?.serviceName ?? 'Your request', style: const TextStyle(fontWeight: FontWeight.w700)),
      actions: [
        if (job != null && job.status == JobStatus.open && !_accepting)
          IconButton(
            tooltip: 'Cancel request',
            onPressed: _accepting ? null : () => _cancelRequest(job),
            icon: const Icon(Icons.close_rounded),
          ),
      ],
    ),
    body: Stack(children: [
      body,
      if (_accepting)
        Container(
          color: Colors.black26,
          child: const Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
    ]),
  );

  Widget _body(JobRequest job) {
    return StreamBuilder<List<RankedPitch>>(
      stream: _pitchStream ??= JobApi.instance.rankedPitches(job),
      builder: (context, snap) {
        final pitches = snap.data ?? const <RankedPitch>[];
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _StatusHeader(job: job, pitchCount: pitches.length),
            const SizedBox(height: 12),
            _RequestSummary(job: job),
            const SizedBox(height: 16),
            if (job.status == JobStatus.open) ...[
              Row(children: [
                Text(pitches.isEmpty ? 'Price quotes' : '${pitches.length} price quote${pitches.length == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _ink)),
                const Spacer(),
                if (pitches.length > 1)
                  IconButton(
                    tooltip: 'How ranking works',
                    icon: const Icon(Icons.info_outline_rounded, color: _muted, size: 20),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('How quotes are ranked'),
                        content: const Text(
                          'Best first, based on star rating and number of reviews, '
                              'feedback from past customers, how reliably the helper turns up, '
                              'their price compared with the other quotes, and distance.\n\n'
                              'You can choose any quote you like.',
                        ),
                        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 8),
              if (pitches.isEmpty)
                _WaitingCard(job: job)
              else
                ...pitches.map((r) => _PitchCard(
                  ranked: r,
                  isNow: job.slot.isNow,
                  onBook: _accepting ? null : () => _accept(job, r, pitches),
                )),
            ] else
              _ClosedCard(job: job),
          ],
        );
      },
    );
  }
}

String _countdown(DateTime? until) {
  if (until == null) return '';
  final d = until.difference(DateTime.now());
  if (d.isNegative) return '0:00';
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(h > 0 ? 2 : 1, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

String slotText(JobSlot s) {
  if (s.isNow) return 'As soon as possible';
  final day = DateFormat('EEE, d MMM').format(s.start);
  return '$day, ${DateFormat('h a').format(s.start)} – ${DateFormat('h a').format(s.end)}';
}

class _StatusHeader extends StatelessWidget {
  final JobRequest job;
  final int pitchCount;
  const _StatusHeader({required this.job, required this.pitchCount});

  @override
  Widget build(BuildContext context) {
    final open = job.status == JobStatus.open;
    final pitching = job.acceptingPitches;
    final String title;
    final String sub;
    if (!open) {
      title = switch (job.status) {
        JobStatus.expired => 'Request expired',
        JobStatus.cancelled => 'Request cancelled',
        JobStatus.booked || JobStatus.completed => 'Booked',
        _ => 'Updating…',
      };
      sub = '';
    } else if (job.notifiedCount == 0 && pitchCount == 0) {
      title = 'No helpers online nearby yet';
      sub = 'Helpers who come online within 5 km in the next ${_countdown(job.pitchDeadline)} will see your request.';
    } else if (pitching) {
      title = 'Sent to ${job.notifiedCount} helper${job.notifiedCount == 1 ? '' : 's'} within 5 km';
      sub = 'Quotes can arrive for ${_countdown(job.pitchDeadline)} more.';
    } else {
      title = 'Quoting has closed';
      sub = 'Choose a quote before ${DateFormat('h:mm a').format(job.expiresAt ?? DateTime.now())}.';
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: open ? const [Color(0xFF6D28D9), Color(0xFF8B5CF6)] : const [Color(0xFF4B5563), Color(0xFF6B7280)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        if (open && pitching)
          const SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
          )
        else
          Icon(open ? Icons.hourglass_bottom_rounded : Icons.info_outline_rounded, color: Colors.white, size: 32),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            if (sub.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(sub, style: const TextStyle(color: Colors.white70, height: 1.3)),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _RequestSummary extends StatelessWidget {
  final JobRequest job;
  const _RequestSummary({required this.job});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.schedule_rounded, size: 18, color: _purple),
          const SizedBox(width: 6),
          Text(slotText(job.slot), style: const TextStyle(fontWeight: FontWeight.w700, color: _ink)),
          const Spacer(),
          if (job.areaName.isNotEmpty)
            Flexible(
              child: Text(job.areaName,
                  overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 13)),
            ),
        ]),
        const SizedBox(height: 10),
        Text(job.description, style: const TextStyle(color: Color(0xFF374151), height: 1.4)),
        if (job.photoUrls.isNotEmpty) ...[
          const SizedBox(height: 10),
          PhotoStrip(urls: job.photoUrls, size: 70),
        ],
        if (job.audioUrl != null) ...[
          const SizedBox(height: 10),
          VoiceNotePlayer(url: job.audioUrl),
        ],
      ]),
    );
  }
}

class _WaitingCard extends StatelessWidget {
  final JobRequest job;
  const _WaitingCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final closed = !job.acceptingPitches;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(children: [
        Icon(closed ? Icons.search_off_rounded : Icons.notifications_active_outlined, size: 44, color: _purple),
        const SizedBox(height: 12),
        Text(closed ? 'No quotes arrived' : 'Waiting for quotes…',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
        const SizedBox(height: 6),
        Text(
          closed
              ? 'Try again with a different time, or add photos so helpers understand the job.'
              : 'Nearby helpers are reading your request. We\'ll notify you as soon as a price comes in.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, height: 1.35),
        ),
      ]),
    );
  }
}

class _ClosedCard extends StatelessWidget {
  final JobRequest job;
  const _ClosedCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final text = switch (job.status) {
      JobStatus.expired => 'This request expired without a booking. Post a new one from Home anytime.',
      JobStatus.cancelled => 'You cancelled this request.',
      JobStatus.booked || JobStatus.completed => 'Opening your booking…',
      _ => 'Updating…',
    };
    return _Message(icon: Icons.inbox_outlined, text: text);
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Message({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 40, color: const Color(0xFF9CA3AF)),
      const SizedBox(height: 10),
      Text(text, textAlign: TextAlign.center, style: const TextStyle(color: _muted)),
    ]),
  );
}

class _PitchCard extends StatelessWidget {
  final RankedPitch ranked;
  final bool isNow;
  final VoidCallback? onBook;
  const _PitchCard({required this.ranked, required this.isNow, required this.onBook});

  @override
  Widget build(BuildContext context) {
    final p = ranked.pitch;
    final h = ranked.helper;
    final top = ranked.badges.contains('best_match');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: top ? _purple : const Color(0xFFEDE9FE), width: top ? 1.6 : 1),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFFEDE9FE),
            backgroundImage: h.photoUrl.isNotEmpty ? CachedNetworkImageProvider(h.photoUrl) : null,
            child: h.photoUrl.isEmpty
                ? Text(h.name.isNotEmpty ? h.name[0].toUpperCase() : 'H',
                style: const TextStyle(color: _purple, fontWeight: FontWeight.w800, fontSize: 20))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(h.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.verified_rounded, size: 16, color: _green),
              ]),
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
                const SizedBox(width: 2),
                Text(
                  h.ratingCount == 0
                      ? 'No reviews yet'
                      : '${h.rating.toStringAsFixed(1)} (${h.ratingCount})',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF374151), fontWeight: FontWeight.w600),
                ),
                const Text('  ·  ', style: TextStyle(color: _muted)),
                Text('${h.completedJobs} jobs', style: const TextStyle(fontSize: 13, color: _muted)),
              ]),
              const SizedBox(height: 3),
              Text(
                '${p.distanceKm.toStringAsFixed(1)} km away'
                    '${isNow && p.etaMinutes != null ? ' · can reach in ~${p.etaMinutes} min' : ''}',
                style: const TextStyle(fontSize: 12.5, color: _muted),
              ),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₹${NumberFormat.decimalPattern('en_IN').format(p.amount)}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _ink)),
            const Text('fixed price', style: TextStyle(fontSize: 11, color: _muted)),
          ]),
        ]),
        if (ranked.badges.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: ranked.badges.map((b) => _Badge(b)).toList()),
        ],
        if (p.note.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12)),
            child: Text('“${p.note}”', style: const TextStyle(color: Color(0xFF374151), height: 1.35)),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: top ? _purple : const Color(0xFF111827),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: onBook,
            child: Text('Book for ₹${p.amount}', style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

class _Badge extends StatelessWidget {
  final String id;
  const _Badge(this.id);
  @override
  Widget build(BuildContext context) {
    final (Color c, IconData icon) = switch (id) {
      'best_match' => (_purple, Icons.workspace_premium_rounded),
      'lowest_price' => (_green, Icons.savings_outlined),
      'top_rated' => (const Color(0xFFD97706), Icons.star_rounded),
      'nearest' => (const Color(0xFF0284C7), Icons.near_me_rounded),
      _ => (_muted, Icons.fiber_new_rounded),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 4),
        Text(badgeLabel(id), style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}