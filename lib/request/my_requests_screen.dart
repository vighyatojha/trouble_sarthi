// lib/screens/request/my_requests_screen.dart
// Bottom-nav "Booking" tab: the customer's bookings and requests, in the same
// purple-gradient style as the rest of the app.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/booking_chat_screen.dart';
import '../../core/job_api.dart';
import '../../core/job_models.dart';
import '../../core/sarthi_ui.dart';
import '../../core/service_catalog.dart';
import 'booking_tracker_screen.dart';
import 'request_pitches_screen.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  late final Stream<List<Booking>> _bookings = JobApi.instance.myBookings(asHelper: false);
  late final Stream<List<JobRequest>> _requests = JobApi.instance.myRequests();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Refresh countdowns ("quotes close in 12 min").
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SarthiColors.page,
      body: Column(children: [
        StreamBuilder<List<Booking>>(
          stream: _bookings,
          builder: (context, snap) {
            final active = (snap.data ?? const <Booking>[]).where((b) => b.isActive).length;
            return SarthiTabHeader(
              title: 'My Bookings',
              subtitle: active > 0
                  ? '$active active booking${active == 1 ? '' : 's'}'
                  : 'Your bookings and service requests',
              tabController: _tab,
              tabs: const ['Bookings', 'Requests'],
            );
          },
        ),
        Expanded(
          child: TabBarView(controller: _tab, children: [
            _BookingsTab(stream: _bookings),
            _RequestsTab(stream: _requests),
          ]),
        ),
      ]),
    );
  }
}

// ─── Bookings ──────────────────────────────────────────────────────────────

class _BookingsTab extends StatelessWidget {
  final Stream<List<Booking>> stream;
  const _BookingsTab({required this.stream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Booking>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return const SarthiEmpty(
            icon: Icons.cloud_off_rounded,
            title: 'Could not load bookings',
            message: 'Check your internet connection and try again.',
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: SarthiColors.purple, strokeWidth: 2));
        }
        final list = snap.data!;
        if (list.isEmpty) {
          return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 130), children: const [
            SizedBox(
              height: 380,
              child: SarthiEmpty(
                icon: Icons.calendar_month_rounded,
                title: 'No bookings yet',
                message: 'Pick a service on Home, describe the problem and choose a quote. Your bookings will appear here.',
              ),
            ),
            _LegacyBookings(),
          ]);
        }
        final active = list.where((b) => b.isActive).toList()..sort((a, b) => a.slot.start.compareTo(b.slot.start));
        final past = list.where((b) => !b.isActive).toList();
        return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 130), children: [
          if (active.isNotEmpty) ...[
            const SarthiSectionLabel('Active'),
            ...active.map((b) => _ActiveBookingCard(b)),
          ],
          if (past.isNotEmpty) ...[
            const SarthiSectionLabel('Past'),
            ...past.map((b) => _PastBookingCard(b)),
          ],
          const _LegacyBookings(),
        ]);
      },
    );
  }
}

(String, Color) _statusStyle(BookingStatus s) => switch (s) {
  BookingStatus.confirmed => ('Confirmed', SarthiColors.purple),
  BookingStatus.onTheWay => ('On the way', const Color(0xFF0891B2)),
  BookingStatus.arrived => ('Arrived', const Color(0xFF0891B2)),
  BookingStatus.inProgress => ('Working', SarthiColors.amber),
  BookingStatus.workDone => ('Pay now', SarthiColors.green),
  BookingStatus.completed => ('Completed', SarthiColors.green),
  BookingStatus.cancelled => ('Cancelled', SarthiColors.red),
  BookingStatus.unknown => ('Updating…', SarthiColors.muted),
};

String _slotLabel(JobSlot s) {
  if (s.isNow) return 'As soon as possible';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(s.start.year, s.start.month, s.start.day);
  final diff = day.difference(today).inDays;
  final d = diff == 0 ? 'Today' : diff == 1 ? 'Tomorrow' : DateFormat('EEE, d MMM').format(s.start);
  return '$d · ${DateFormat('h a').format(s.start)} – ${DateFormat('h a').format(s.end)}';
}

IconData _serviceIcon(String subId) => ServiceCatalog.byId(subId)?.icon ?? Icons.handyman_rounded;

void _openBooking(BuildContext context, Booking b) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => BookingTrackerScreen(bookingId: b.id)));

class _ActiveBookingCard extends StatelessWidget {
  final Booking b;
  const _ActiveBookingCard(this.b);

  @override
  Widget build(BuildContext context) {
    final (label, color) = _statusStyle(b.status);
    final step = bookingSteps.indexOf(b.status);
    final progress = step < 0 ? 0.0 : (step + 1) / bookingSteps.length;
    final needsAction = b.status == BookingStatus.workDone && b.customerPaidAt == null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openBooking(context, b),
          child: Ink(
            decoration: sarthiCard(radius: 20, border: needsAction ? SarthiColors.green.withValues(alpha: 0.4) : null),
            child: Column(children: [
              // Gradient strip with the service and status.
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: const BoxDecoration(
                  gradient: SarthiColors.header,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                    child: Icon(_serviceIcon(b.subcategoryId), color: Colors.white, size: 19),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(b.serviceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(_slotLabel(b.slot),
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11.5)),
                    ]),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                    child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(children: [
                  Row(children: [
                    SarthiAvatar(name: b.helperName, photoUrl: b.helperPhotoUrl, size: 42),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(b.helperName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: SarthiColors.ink, fontSize: 14)),
                        const Text('Your helper', style: TextStyle(color: SarthiColors.faint, fontSize: 11.5)),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('₹${b.agreedAmount}',
                          style: const TextStyle(fontWeight: FontWeight.w900, color: SarthiColors.ink, fontSize: 17)),
                      const Text('pay after work', style: TextStyle(color: SarthiColors.faint, fontSize: 10.5)),
                    ]),
                  ]),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: SarthiColors.purpleLight,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    Text(bookingStatusLabel(b.status),
                        style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text('Step ${step < 0 ? 0 : step + 1} of ${bookingSteps.length}',
                        style: const TextStyle(fontSize: 11, color: SarthiColors.faint)),
                  ]),
                  if (needsAction) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: SarthiColors.greenLight, borderRadius: BorderRadius.circular(12)),
                      child: Text('Work is done. Pay ₹${b.agreedAmount} and confirm how you paid.',
                          style: const TextStyle(color: Color(0xFF065F46), fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: _SmallButton(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'Chat',
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => BookingChatScreen(
                            bookingId: b.id,
                            otherName: b.helperName,
                            otherPhotoUrl: b.helperPhotoUrl,
                            myName: b.customerName,
                            myRole: 'customer',
                            subtitle: b.serviceName,
                          ),
                        )),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SmallButton(
                        icon: Icons.track_changes_rounded,
                        label: needsAction ? 'Pay & confirm' : 'Track',
                        filled: true,
                        onTap: () => _openBooking(context, b),
                      ),
                    ),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _PastBookingCard extends StatelessWidget {
  final Booking b;
  const _PastBookingCard(this.b);

  @override
  Widget build(BuildContext context) {
    final (label, color) = _statusStyle(b.status);
    final when = b.completedAt ?? b.createdAt;
    final rate = b.status == BookingStatus.completed && !b.customerReviewed;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openBooking(context, b),
          child: Ink(
            decoration: sarthiCard(),
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                child: Icon(_serviceIcon(b.subcategoryId), color: color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(b.serviceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: SarthiColors.ink, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text('${b.helperName}${when != null ? ' · ${DateFormat('d MMM yyyy').format(when)}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: SarthiColors.faint, fontSize: 12)),
                  if (rate) ...[
                    const SizedBox(height: 6),
                    const SarthiChip('Rate your helper', color: SarthiColors.amber, icon: Icons.star_rounded),
                  ],
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('₹${b.agreedAmount}',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: SarthiColors.ink, fontSize: 14)),
                const SizedBox(height: 4),
                SarthiChip(label, color: color),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Bookings made with the old app version: shown read-only so nothing is lost.
class _LegacyBookings extends StatelessWidget {
  const _LegacyBookings();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: JobApi.instance.legacyBookings(),
      builder: (context, snap) {
        final list = [...(snap.data ?? const <Map<String, dynamic>>[])];
        if (list.isEmpty) return const SizedBox.shrink();
        DateTime? when(Map<String, dynamic> d) {
          final v = d['completedAt'] ?? d['scheduledAt'] ?? d['createdAt'];
          return v is Timestamp ? v.toDate() : null;
        }

        list.sort((a, b) => (when(b) ?? DateTime(2000)).compareTo(when(a) ?? DateTime(2000)));
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SarthiSectionLabel('Older bookings (previous app version)'),
          for (final d in list)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: sarthiCard(color: const Color(0xFFFAFAFC)),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.history_rounded, color: SarthiColors.faint, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${d['serviceName'] ?? 'Service'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: SarthiColors.body, fontSize: 13.5)),
                    const SizedBox(height: 2),
                    Text(
                      [
                        '${d['helperName'] ?? ''}',
                        if (when(d) != null) DateFormat('d MMM yyyy').format(when(d)!),
                        if ('${d['bookingCode'] ?? ''}'.isNotEmpty) '#${d['bookingCode']}',
                      ].where((x) => x.isNotEmpty).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: SarthiColors.faint, fontSize: 11.5),
                    ),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  if ((d['totalAmount'] ?? d['baseAmount']) is num)
                    Text('₹${((d['totalAmount'] ?? d['baseAmount']) as num).round()}',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: SarthiColors.body, fontSize: 13)),
                  const SizedBox(height: 4),
                  SarthiChip(_legacyStatus('${d['status'] ?? ''}'), color: SarthiColors.muted),
                ]),
              ]),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text('These were made before the new booking system. They are kept for your records and can\'t be changed.',
                style: TextStyle(fontSize: 11, color: SarthiColors.faint)),
          ),
        ]);
      },
    );
  }

  static String _legacyStatus(String s) => switch (s) {
    'completed' => 'Completed',
    'cancelled' => 'Cancelled',
    '' => 'Old booking',
    _ => 'Closed',
  };
}

class _SmallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;
  const _SmallButton({required this.icon, required this.label, required this.onTap, this.filled = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 40,
      decoration: BoxDecoration(
        gradient: filled ? const LinearGradient(colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)]) : null,
        color: filled ? null : SarthiColors.purpleLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 16, color: filled ? Colors.white : SarthiColors.purple),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 12.5, color: filled ? Colors.white : SarthiColors.purple)),
      ]),
    ),
  );
}

// ─── Requests ──────────────────────────────────────────────────────────────

class _RequestsTab extends StatelessWidget {
  final Stream<List<JobRequest>> stream;
  const _RequestsTab({required this.stream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<JobRequest>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return const SarthiEmpty(icon: Icons.cloud_off_rounded, title: 'Could not load requests');
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: SarthiColors.purple, strokeWidth: 2));
        }
        final list = snap.data!;
        if (list.isEmpty) {
          return const SarthiEmpty(
            icon: Icons.assignment_outlined,
            title: 'No requests yet',
            message: 'When you describe a problem, nearby helpers send you prices. Your requests appear here.',
          );
        }
        final open = list.where((j) => j.status == JobStatus.open).toList();
        final rest = list.where((j) => j.status != JobStatus.open).toList();
        return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 130), children: [
          if (open.isNotEmpty) ...[
            const SarthiSectionLabel('Waiting for you'),
            ...open.map((j) => _RequestCard(j)),
          ],
          if (rest.isNotEmpty) ...[
            const SarthiSectionLabel('Earlier'),
            ...rest.map((j) => _RequestCard(j)),
          ],
        ]);
      },
    );
  }
}

class _RequestCard extends StatelessWidget {
  final JobRequest j;
  const _RequestCard(this.j);

  @override
  Widget build(BuildContext context) {
    final left = j.pitchDeadline?.difference(DateTime.now());
    final (String label, Color color) = switch (j.status) {
      JobStatus.open => j.acceptingPitches
          ? ('Collecting quotes', SarthiColors.purple)
          : ('Choose a quote', SarthiColors.amber),
      JobStatus.booked => ('Booked', SarthiColors.green),
      JobStatus.completed => ('Completed', SarthiColors.green),
      JobStatus.expired => ('Expired', SarthiColors.muted),
      JobStatus.cancelled => ('Cancelled', SarthiColors.red),
      JobStatus.unknown => ('Updating…', SarthiColors.muted),
    };
    final isOpen = j.status == JobStatus.open;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            if (j.bookingId != null && (j.status == JobStatus.booked || j.status == JobStatus.completed)) {
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => BookingTrackerScreen(bookingId: j.bookingId!)));
            } else {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => RequestPitchesScreen(jobId: j.id)));
            }
          },
          child: Ink(
            decoration: sarthiCard(border: isOpen ? SarthiColors.purple.withValues(alpha: 0.2) : null),
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: SarthiColors.purpleLight, borderRadius: BorderRadius.circular(12)),
                  child: Icon(_serviceIcon(j.subcategoryId), color: SarthiColors.purple, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(j.serviceName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: SarthiColors.ink, fontSize: 14)),
                    Text(j.createdAt != null ? DateFormat('d MMM, h:mm a').format(j.createdAt!) : '',
                        style: const TextStyle(color: SarthiColors.faint, fontSize: 11.5)),
                  ]),
                ),
                SarthiChip(label, color: color),
              ]),
              const SizedBox(height: 10),
              Text(j.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: SarthiColors.body, fontSize: 12.5, height: 1.4)),
              if (isOpen) ...[
                const SizedBox(height: 10),
                Row(children: [
                  Icon(Icons.timer_outlined,
                      size: 15, color: j.acceptingPitches ? SarthiColors.amber : SarthiColors.faint),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      j.acceptingPitches && left != null
                          ? 'Quotes close in ${left.inHours > 0 ? '${left.inHours}h ' : ''}${left.inMinutes.remainder(60)}m'
                          : 'Quotes are in. Pick a helper before the request expires.',
                      style: TextStyle(
                          fontSize: 11.5,
                          color: j.acceptingPitches ? SarthiColors.amber : SarthiColors.muted,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Text('View quotes',
                      style: TextStyle(color: SarthiColors.purple, fontWeight: FontWeight.bold, fontSize: 12)),
                  const Icon(Icons.chevron_right_rounded, color: SarthiColors.purple, size: 18),
                ]),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}