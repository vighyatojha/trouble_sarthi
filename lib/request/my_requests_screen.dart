// lib/screens/request/my_requests_screen.dart
// Bottom-nav tab: the customer's bookings and requests (replaces the old BookingsScreen).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/job_api.dart';
import '../../core/job_models.dart';
import 'booking_tracker_screen.dart';
import 'request_pitches_screen.dart';

const _purple = Color(0xFF7C3AED);
const _ink = Color(0xFF111827);
const _muted = Color(0xFF6B7280);

class MyRequestsScreen extends StatelessWidget {
  const MyRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7FB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: _ink,
          elevation: 0.5,
          automaticallyImplyLeading: false,
          title: const Text('My bookings', style: TextStyle(fontWeight: FontWeight.w800)),
          bottom: const TabBar(
            labelColor: _purple,
            indicatorColor: _purple,
            unselectedLabelColor: _muted,
            tabs: [Tab(text: 'Bookings'), Tab(text: 'Requests')],
          ),
        ),
        body: const TabBarView(children: [_BookingsTab(), _RequestsTab()]),
      ),
    );
  }
}

class _BookingsTab extends StatelessWidget {
  const _BookingsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Booking>>(
      stream: JobApi.instance.myBookings(asHelper: false),
      builder: (context, snap) {
        if (snap.hasError) return const _Empty(text: 'Could not load bookings. Pull down to retry.');
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final list = snap.data!;
        if (list.isEmpty) {
          return const _Empty(
              text: 'No bookings yet.\nPick a service on Home, describe the problem and choose a quote.');
        }
        final active = list.where((b) => b.isActive).toList();
        final past = list.where((b) => !b.isActive).toList();
        return ListView(padding: const EdgeInsets.all(16), children: [
          if (active.isNotEmpty) ...[
            const _Section('Active'),
            ...active.map((b) => _BookingTile(b)),
          ],
          if (past.isNotEmpty) ...[
            const _Section('Past'),
            ...past.map((b) => _BookingTile(b)),
          ],
        ]);
      },
    );
  }
}

class _RequestsTab extends StatelessWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<JobRequest>>(
      stream: JobApi.instance.myRequests(),
      builder: (context, snap) {
        if (snap.hasError) return const _Empty(text: 'Could not load requests.');
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final list = snap.data!;
        if (list.isEmpty) return const _Empty(text: 'Your requests will appear here.');
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (_, i) => _RequestTile(list[i]),
        );
      },
    );
  }
}

class _BookingTile extends StatelessWidget {
  final Booking b;
  const _BookingTile(this.b);

  @override
  Widget build(BuildContext context) {
    final color = switch (b.status) {
      BookingStatus.completed => const Color(0xFF059669),
      BookingStatus.cancelled => const Color(0xFFDC2626),
      _ => _purple,
    };
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => BookingTrackerScreen(bookingId: b.id))),
        title: Text(b.serviceName, style: const TextStyle(fontWeight: FontWeight.w800, color: _ink)),
        subtitle: Text(
          '${b.helperName} · ${slotText(b.slot)}',
          style: const TextStyle(color: _muted),
        ),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('₹${b.agreedAmount}', style: const TextStyle(fontWeight: FontWeight.w800, color: _ink)),
          const SizedBox(height: 4),
          Text(bookingStatusLabel(b.status),
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  final JobRequest j;
  const _RequestTile(this.j);

  @override
  Widget build(BuildContext context) {
    final (String label, Color color) = switch (j.status) {
      JobStatus.open => (j.acceptingPitches ? 'Collecting quotes' : 'Choose a quote', _purple),
      JobStatus.booked => ('Booked', const Color(0xFF059669)),
      JobStatus.completed => ('Completed', const Color(0xFF059669)),
      JobStatus.expired => ('Expired', _muted),
      JobStatus.cancelled => ('Cancelled', const Color(0xFFDC2626)),
      JobStatus.unknown => ('Updating…', _muted),
    };
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        onTap: () {
          if (j.bookingId != null && (j.status == JobStatus.booked || j.status == JobStatus.completed)) {
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => BookingTrackerScreen(bookingId: j.bookingId!)));
          } else {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => RequestPitchesScreen(jobId: j.id)));
          }
        },
        title: Text(j.serviceName, style: const TextStyle(fontWeight: FontWeight.w800, color: _ink)),
        subtitle: Text(
          j.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _muted),
        ),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(j.createdAt != null ? DateFormat('d MMM').format(j.createdAt!) : '',
              style: const TextStyle(fontSize: 12, color: _muted)),
        ]),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String text;
  const _Section(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
    child: Text(text.toUpperCase(),
        style: const TextStyle(fontSize: 12, letterSpacing: 1, color: _muted, fontWeight: FontWeight.w800)),
  );
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty({required this.text});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.receipt_long_outlined, size: 44, color: Color(0xFF9CA3AF)),
        const SizedBox(height: 10),
        Text(text, textAlign: TextAlign.center, style: const TextStyle(color: _muted, height: 1.4)),
      ]),
    ),
  );
}