// lib/screens/request/booking_tracker_screen.dart
// Step 3 (customer): follow the booking from "Confirmed" to "Completed".
// Shows the start code, chat/call, payment confirmation and review.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/booking_chat_scree.dart';
import '../../core/job_api.dart';
import '../../core/job_media_widgets.dart';
import '../../core/job_models.dart';
import '../../core/review_sheet.dart';
import 'request_pitches_screen.dart';

const _purple = Color(0xFF7C3AED);
const _ink = Color(0xFF111827);
const _muted = Color(0xFF6B7280);
const _green = Color(0xFF059669);
const _red = Color(0xFFDC2626);
const _amber = Color(0xFFD97706);

class BookingTrackerScreen extends StatefulWidget {
  final String bookingId;
  const BookingTrackerScreen({super.key, required this.bookingId});

  @override
  State<BookingTrackerScreen> createState() => _BookingTrackerScreenState();
}

class _BookingTrackerScreenState extends State<BookingTrackerScreen> {
  bool _busy = false;
  bool _reviewPrompted = false;

  Future<void> _run(Future<void> Function() fn, {String? success}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await fn();
      if (success != null && mounted) _snack(success);
    } on ApiException catch (e) {
      if (mounted) _snack(e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m, {bool error = false}) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(m),
    behavior: SnackBarBehavior.floating,
    backgroundColor: error ? _red : _green,
  ));

  Future<String?> _askReason({required String title, required List<String> presets, int minLen = 3}) {
    final ctrl = TextEditingController();
    String? picked;
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final r in presets)
                ChoiceChip(
                  label: Text(r),
                  selected: picked == r,
                  onSelected: (_) => setLocal(() {
                    picked = r;
                    ctrl.text = r;
                  }),
                ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLength: 300,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Write the reason',
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _red, padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: () {
                  final v = ctrl.text.trim();
                  if (v.length < minLen) return;
                  Navigator.pop(ctx, v);
                },
                child: const Text('Submit'),
              ),
            ),
          ]),
        ),
      ),
    ).whenComplete(() => Future.delayed(const Duration(milliseconds: 500), ctrl.dispose));
  }

  Future<void> _cancel(Booking b) async {
    final reason = await _askReason(
      title: 'Why are you cancelling?',
      presets: const ['Problem solved', 'Booked by mistake', 'Need a different time', 'Helper asked for more money'],
    );
    if (reason == null) return;
    await _run(() => JobApi.instance.bookingAction(b, 'cancel', reason: reason), success: 'Booking cancelled');
  }

  Future<void> _report(Booking b) async {
    final reason = await _askReason(
      title: 'Report a problem',
      presets: const ['Work not done properly', 'Asked for extra money', 'Rude behaviour', 'Safety concern'],
      minLen: 10,
    );
    if (reason == null) return;
    await _run(() => JobApi.instance.bookingAction(b, 'report_issue', reason: reason),
        success: 'Thanks. Our team will contact you.');
  }

  Future<void> _call(Booking b) async {
    final c = await JobApi.instance.contact(b.id);
    final phone = c?.helperPhone ?? '';
    if (phone.isEmpty) {
      if (mounted) _snack('Phone number not available. Please use chat.', error: true);
      return;
    }
    await launchUrl(Uri(scheme: 'tel', path: phone));
  }

  void _chat(Booking b) {
    final me = FirebaseAuth.instance.currentUser?.displayName ?? b.customerName;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BookingChatScreen(
        bookingId: b.id,
        otherName: b.helperName,
        myName: me,
        myRole: 'customer',
        subtitle: b.serviceName,
      ),
    ));
  }

  void _maybePromptReview(Booking b) {
    if (_reviewPrompted || b.status != BookingStatus.completed || b.customerReviewed) return;
    _reviewPrompted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ReviewSheet.show(context, booking: b, asCustomer: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Booking?>(
      stream: JobApi.instance.booking(widget.bookingId),
      builder: (context, snap) {
        final b = snap.data;
        return Scaffold(
          backgroundColor: const Color(0xFFF7F7FB),
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: _ink,
            elevation: 0.5,
            title: Text(b?.serviceName ?? 'Booking', style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          body: snap.hasError
              ? const Center(child: Text('Could not load this booking.'))
              : b == null
              ? const Center(child: CircularProgressIndicator())
              : Stack(children: [
            _content(b),
            if (_busy)
              Container(color: Colors.black12, child: const Center(child: CircularProgressIndicator())),
          ]),
        );
      },
    );
  }

  Widget _content(Booking b) {
    _maybePromptReview(b);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
      _HelperCard(booking: b, onChat: () => _chat(b), onCall: b.isActive ? () => _call(b) : null),
      const SizedBox(height: 12),
      if (b.status == BookingStatus.cancelled) _cancelledCard(b) else _Timeline(booking: b),
      const SizedBox(height: 12),
      if (b.status == BookingStatus.confirmed ||
          b.status == BookingStatus.onTheWay ||
          b.status == BookingStatus.arrived)
        _StartCodeCard(
          bookingId: b.id,
          onRegenerate: () => _run(() => JobApi.instance.bookingAction(b, 'regenerate_code'),
              success: 'New code created'),
        ),
      if (b.status == BookingStatus.workDone) _paymentCard(b),
      if (b.status == BookingStatus.completed) _completedCard(b),
      const SizedBox(height: 12),
      _DetailsCard(booking: b),
      const SizedBox(height: 16),
      if (b.canCancel)
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _cancel(b),
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('Cancel booking'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _red,
            side: const BorderSide(color: Color(0xFFFECACA)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      if (!b.canCancel && b.status != BookingStatus.confirmed)
        TextButton.icon(
          onPressed: _busy ? null : () => _report(b),
          icon: const Icon(Icons.flag_outlined, color: _muted),
          label: const Text('Report a problem', style: TextStyle(color: _muted)),
        ),
    ]);
  }

  Widget _cancelledCard(Booking b) {
    final byHelper = b.cancelledBy == 'helper';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(byHelper ? '${b.helperName} cancelled' : 'You cancelled this booking',
            style: const TextStyle(fontWeight: FontWeight.w800, color: _red, fontSize: 16)),
        if (b.cancelReason.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Reason: ${b.cancelReason}', style: const TextStyle(color: Color(0xFF7F1D1D))),
        ],
        if (byHelper) ...[
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _purple),
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => RequestPitchesScreen(jobId: b.jobId)),
            ),
            child: const Text('See other quotes'),
          ),
        ],
      ]),
    );
  }

  Widget _paymentCard(Booking b) {
    final paid = b.customerPaidAt != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.payments_outlined, color: _green),
          const SizedBox(width: 8),
          Text('Pay ₹${b.agreedAmount} to ${b.helperName.split(' ').first}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _ink)),
        ]),
        const SizedBox(height: 6),
        Text(
          paid
              ? 'You confirmed paying by ${b.paymentMethod == 'upi' ? 'UPI' : 'cash'}. '
              'Waiting for the helper to confirm they received it.'
              : 'The helper marked the work as done. Check the work, pay the agreed price directly '
              '(cash or UPI), then tell us how you paid.',
          style: const TextStyle(color: _muted, height: 1.35),
        ),
        if (b.customerCanClose) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _green,
                side: const BorderSide(color: Color(0xFFA7F3D0)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              onPressed: _busy
                  ? null
                  : () => _run(() => JobApi.instance.bookingAction(b, 'close_job'), success: 'Job closed'),
              icon: const Icon(Icons.task_alt_rounded),
              label: const Text('Helper has not confirmed? Close the job'),
            ),
          ),
        ],
        if (!paid) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _green, padding: const EdgeInsets.symmetric(vertical: 13)),
                onPressed: _busy
                    ? null
                    : () => _run(() => JobApi.instance.bookingAction(b, 'confirm_paid', method: 'cash'),
                    success: 'Thanks! Helper will confirm.'),
                icon: const Icon(Icons.money_rounded),
                label: const Text('Paid cash'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _purple, padding: const EdgeInsets.symmetric(vertical: 13)),
                onPressed: _busy
                    ? null
                    : () => _run(() => JobApi.instance.bookingAction(b, 'confirm_paid', method: 'upi'),
                    success: 'Thanks! Helper will confirm.'),
                icon: const Icon(Icons.qr_code_2_rounded),
                label: const Text('Paid by UPI'),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _completedCard(Booking b) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(18)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Job completed ✅',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF065F46))),
      const SizedBox(height: 4),
      Text(
        '₹${b.agreedAmount} · ${b.completedAt != null ? DateFormat('d MMM, h:mm a').format(b.completedAt!) : ''}'
            '${b.customerPaidAt == null ? '' : ' · paid by ${b.paymentMethod == 'upi' ? 'UPI' : 'cash'}'}',
        style: const TextStyle(color: Color(0xFF047857)),
      ),
      if (!b.customerReviewed) ...[
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: _amber),
          onPressed: () => ReviewSheet.show(context, booking: b, asCustomer: true),
          icon: const Icon(Icons.star_rounded),
          label: Text('Rate ${b.helperName.split(' ').first}'),
        ),
      ],
    ]),
  );
}

class _HelperCard extends StatelessWidget {
  final Booking booking;
  final VoidCallback onChat;
  final VoidCallback? onCall;
  const _HelperCard({required this.booking, required this.onChat, required this.onCall});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: const Color(0xFFEDE9FE),
          backgroundImage: b.helperPhotoUrl.isNotEmpty ? CachedNetworkImageProvider(b.helperPhotoUrl) : null,
          child: b.helperPhotoUrl.isEmpty
              ? Text(b.helperName.isNotEmpty ? b.helperName[0].toUpperCase() : 'H',
              style: const TextStyle(color: _purple, fontWeight: FontWeight.w800, fontSize: 22))
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(b.helperName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _ink)),
            const SizedBox(height: 2),
            Text('₹${b.agreedAmount} fixed · pay after work',
                style: const TextStyle(color: _muted, fontSize: 13)),
          ]),
        ),
        IconButton.filledTonal(onPressed: onChat, icon: const Icon(Icons.chat_bubble_outline_rounded)),
        if (onCall != null) ...[
          const SizedBox(width: 4),
          IconButton.filledTonal(onPressed: onCall, icon: const Icon(Icons.call_outlined)),
        ],
      ]),
    );
  }
}

class _Timeline extends StatelessWidget {
  final Booking booking;
  const _Timeline({required this.booking});

  @override
  Widget build(BuildContext context) {
    final current = bookingSteps.indexOf(booking.status);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(children: [
        for (var i = 0; i < bookingSteps.length; i++)
          _step(
            bookingStatusLabel(bookingSteps[i]),
            booking.timeOf(bookingSteps[i]),
            done: current >= 0 && i <= current,
            active: i == current,
            last: i == bookingSteps.length - 1,
          ),
      ]),
    );
  }

  Widget _step(String label, DateTime? at, {required bool done, required bool active, required bool last}) {
    final color = done ? _green : const Color(0xFFD1D5DB);
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Column(children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: done ? color : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
            child: done ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
          ),
          if (!last) Expanded(child: Container(width: 2, color: color)),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(children: [
              Text(label,
                  style: TextStyle(
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    color: done ? _ink : _muted,
                  )),
              const Spacer(),
              if (at != null) Text(DateFormat('h:mm a').format(at), style: const TextStyle(color: _muted, fontSize: 12)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _StartCodeCard extends StatelessWidget {
  final String bookingId;
  final VoidCallback onRegenerate;
  const _StartCodeCard({required this.bookingId, required this.onRegenerate});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: JobApi.instance.startCode(bookingId),
      builder: (context, snap) {
        final code = snap.data ?? '····';
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF312E81), Color(0xFF6D28D9)]),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Start code', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(code.split('').join('  '),
                style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 2)),
            const SizedBox(height: 6),
            const Text(
              'Tell this code to the helper only when they are at your place and ready to start. '
                  'Never share it on a phone call.',
              style: TextStyle(color: Colors.white70, height: 1.35),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onRegenerate,
                child: const Text('Get a new code', style: TextStyle(color: Colors.white)),
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final Booking booking;
  const _DetailsCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _row(Icons.schedule_rounded, slotText(b.slot)),
        _row(Icons.location_on_outlined, b.address.full),
        const Divider(height: 20),
        Text(b.description, style: const TextStyle(color: Color(0xFF374151), height: 1.4)),
        if (b.photoUrls.isNotEmpty) ...[
          const SizedBox(height: 10),
          PhotoStrip(urls: b.photoUrls, size: 64),
        ],
        if (b.audioUrl != null && b.audioUrl!.isNotEmpty) ...[
          const SizedBox(height: 10),
          VoiceNotePlayer(url: b.audioUrl),
        ],
      ]),
    );
  }

  Widget _row(IconData i, String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(i, size: 18, color: _purple),
      const SizedBox(width: 8),
      Expanded(child: Text(t, style: const TextStyle(color: _ink))),
    ]),
  );
}