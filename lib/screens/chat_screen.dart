// lib/screens/chat_screen.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../service/realtime_db_service.dart';
import 'about_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CHAT SCREEN  (User side)
// ─────────────────────────────────────────────────────────────────────────────

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String helperName;
  final String helperId;
  final String? helperPhoto;
  final String? bookingId;
  final String? serviceName;
  final String? helperIntro;
  final String? helperRating;
  final String? helperJobCount;
  final String? bookingStatus;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.helperName,
    required this.helperId,
    this.helperPhoto,
    this.bookingId,
    this.serviceName,
    this.helperIntro,
    this.helperRating,
    this.helperJobCount,
    this.bookingStatus,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final _msgCtrl    = TextEditingController();
  final _scrollCtrl = ScrollController();

  bool _isCompleted             = false;
  bool _helperConfirmed         = false;
  bool _userConfirmed           = false;
  bool _mutualCompletionHandled = false;

  StreamSubscription? _statusSub;

  bool _isSending       = false;
  bool _showHelperIntro = false;

  // Track message count to only scroll on NEW messages, not rebuilds
  int _prevMessageCount = 0;

  late final AnimationController _introAnim;
  late final Animation<double>   _introSlide;
  late final Animation<double>   _introFade;

  String get _uid      => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _userName => FirebaseAuth.instance.currentUser?.displayName ?? 'User';

  @override
  void initState() {
    super.initState();

    _isCompleted =
        widget.bookingStatus == 'completed' ||
            widget.bookingStatus == 'cancelled';

    _statusSub = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .snapshots()
        .listen((snap) {
      final data   = snap.data() ?? {};
      final status = data['bookingStatus'] as String? ?? 'active';
      final helperDone = data['helperConfirmedComplete'] as bool? ?? false;
      final userDone   = data['userConfirmedComplete']   as bool? ?? false;

      if (!mounted) return;
      setState(() {
        _helperConfirmed = helperDone;
        _userConfirmed   = userDone;
        _isCompleted     = status == 'completed' || status == 'cancelled';
      });

      if (helperDone && userDone && !_mutualCompletionHandled) {
        _mutualCompletionHandled = true;
        _onMutuallyConfirmed();
      }
    });

    _introAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _introSlide = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(parent: _introAnim, curve: Curves.easeOutCubic),
    );
    _introFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _introAnim, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _introAnim.dispose();
    super.dispose();
  }

  void _toggleHelperIntro() {
    setState(() => _showHelperIntro = !_showHelperIntro);
    if (_showHelperIntro) {
      _introAnim.forward();
    } else {
      _introAnim.reverse();
    }
  }

  // Only scroll when a genuinely new message arrives
  void _scrollToBottomIfNeeded(int currentCount) {
    if (currentCount > _prevMessageCount) {
      _prevMessageCount = currentCount;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  // Immediate scroll after sending
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    _msgCtrl.clear();

    await RealtimeDbService.instance.sendMessage(
      chatId:     widget.chatId,
      senderId:   _uid,
      senderName: _userName,
      text:       text,
    );

    await RealtimeDbService.instance.notifyHelperMessage(
      userId:         widget.helperId,
      helperName:     _userName,
      messagePreview: text,
      bookingId:      widget.bookingId,
    );

    setState(() => _isSending = false);
    _scrollToBottom();
  }

  Future<void> _onSevaCompleted() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Confirm Payment & Completion',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Please confirm that "${widget.serviceName ?? "the service"}" '
              'has been completed and payment has been made.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not yet',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Yes, confirm',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .update({'userConfirmedComplete': true});
  }

  Future<void> _onMutuallyConfirmed() async {
    if (!mounted) return;

    final bookingSnap = await FirebaseFirestore.instance
        .collection('bookings')
        .where('bookingCode', isEqualTo: widget.bookingId ?? '')
        .where('userId', isEqualTo: _uid)
        .limit(1)
        .get();

    if (bookingSnap.docs.isNotEmpty) {
      await bookingSnap.docs.first.reference.update({
        'status':      'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });
    }

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .update({'bookingStatus': 'completed'}).catchError((_) {});

    if (!mounted) return;
      MutualReviewSheet.showForUser(
      context,
      bookingId:   widget.bookingId ?? '',
      helperId:    widget.helperId,
      helperName:  widget.helperName,
      serviceName: widget.serviceName ?? '',
    );
  }

  // ── Cancel booking ───────────────────────────────────────────────────────
  Future<void> _cancelBooking() async {
    Navigator.pop(context); // close bottom sheet first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Booking?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to cancel "${widget.serviceName ?? "this booking"}"? '
              'This cannot be undone.',
          style: const TextStyle(color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, keep it'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Yes, cancel',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      // Update chat doc
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update({'bookingStatus': 'cancelled'});

      // Update booking doc if bookingId provided
      if ((widget.bookingId ?? '').isNotEmpty) {
        final snap = await FirebaseFirestore.instance
            .collection('bookings')
            .where('bookingCode', isEqualTo: widget.bookingId)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          await snap.docs.first.reference.update({
            'status':      'cancelled',
            'cancelledAt': FieldValue.serverTimestamp(),
            'cancelledBy': 'user',
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Booking cancelled successfully.'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to cancel. Try again.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ── Clear chat ───────────────────────────────────────────────────────────
  Future<void> _clearChat() async {
    Navigator.pop(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear Chat?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'This will delete all messages. Only visible to you.',
          style: TextStyle(color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0891B2),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await RealtimeDbService.instance.deleteChat(widget.chatId);
      // Clear lastMessage in Firestore so chat list updates too
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update({'lastMessage': '', 'lastMessageTime': null})
          .catchError((_) {});
    } catch (_) {}
  }

  // ── Report helper — opens contact URL with pre-filled info ───────────────
  Future<void> _reportHelper() async {
    Navigator.pop(context);
    final name    = Uri.encodeComponent(widget.helperName);
    final id      = Uri.encodeComponent(widget.helperId);
    final service = Uri.encodeComponent(widget.serviceName ?? '');
    final url = Uri.parse(
      'https://vighyatojha.github.io/TroubleSarthi_web/contact.html'
          '?name=${Uri.encodeComponent(_userName)}'
          '&message=${Uri.encodeComponent('Report: Helper ${widget.helperName} (ID: ${widget.helperId}) — Service: ${widget.serviceName ?? 'N/A'}. Booking ID: ${widget.bookingId ?? 'N/A'}.')}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      // Fallback: open base URL
      final fallback = Uri.parse(
          'https://vighyatojha.github.io/TroubleSarthi_web/contact.html');
      if (await canLaunchUrl(fallback)) {
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
      }
    }
  }

  // ── View booking details — navigates to bookings screen ──────────────────
  void _viewBookingDetails() {
    Navigator.pop(context); // close bottom sheet
    // Navigate back to parent and let parent handle booking detail routing.
    // If you have a BookingDetailScreen, replace this with:
    // Navigator.push(context, MaterialPageRoute(builder: (_) => BookingDetailScreen(bookingId: widget.bookingId)));
    Navigator.pop(context);
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChatOptionsSheet(
        helperName:         widget.helperName,
        helperId:           widget.helperId,
        bookingId:          widget.bookingId ?? '',
        chatId:             widget.chatId,
        uid:                _uid,
        isCompleted:        _isCompleted,
        onClearChat:        _clearChat,
        onReport:           _reportHelper,
        onViewBooking:      _viewBookingDetails,
        onCancelBooking:    _cancelBooking,
      ),
    );
  }

  _SevaButtonState get _sevaButtonState {
    if (_isCompleted) return _SevaButtonState.hidden;
    if (_userConfirmed) return _SevaButtonState.hidden;
    if (_helperConfirmed) return _SevaButtonState.confirmPayment;
    return _SevaButtonState.hidden;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FB),
        resizeToAvoidBottomInset: true,
        body: Column(
          children: [
            _ChatHeader(
              helperName:      widget.helperName,
              helperPhoto:     widget.helperPhoto,
              onBackTap:       () => Navigator.pop(context),
              onProfileTap:    _toggleHelperIntro,
              onOptionsTap:    _showOptionsMenu,
              onSevaTap:       _onSevaCompleted,
              serviceName:     widget.serviceName,
              isCompleted:     _isCompleted,
              sevaButtonState: _sevaButtonState,
            ),

            if (_helperConfirmed && !_userConfirmed && !_isCompleted)
              _HelperConfirmedBanner(onConfirm: _onSevaCompleted),

            AnimatedBuilder(
              animation: _introAnim,
              builder: (_, child) => ClipRect(
                child: Align(
                  heightFactor: _introAnim.value,
                  child: FadeTransition(opacity: _introFade, child: child),
                ),
              ),
              child: _HelperIntroCard(
                helperName:  widget.helperName,
                helperPhoto: widget.helperPhoto,
                intro: widget.helperIntro ??
                    'Verified Sarthi • ${widget.helperJobCount ?? '50'}+ jobs completed',
                rating:   widget.helperRating   ?? '4.8',
                jobCount: widget.helperJobCount ?? '50',
              ),
            ),

            Expanded(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: RealtimeDbService.instance.messagesStream(widget.chatId),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting &&
                        !snap.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF7C3AED), strokeWidth: 2),
                      );
                    }

                    final messages = snap.data ?? [];

                    if (messages.isEmpty) {
                      return _EmptyChatState(helperName: widget.helperName);
                    }

                    // Only auto-scroll when message count increases
                    _scrollToBottomIfNeeded(messages.length);

                    return ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      itemCount: messages.length,
                      // KEY: keeps list stable across rebuilds
                      key: PageStorageKey(widget.chatId),
                      itemBuilder: (_, i) {
                        final msg  = messages[i];
                        final isMe = msg['senderId'] == _uid;
                        final type = msg['type'] as String? ?? 'text';

                        if (type == 'booking_confirmed' ||
                            type == 'system' ||
                            type == 'system_warning') {
                          return _SystemMessage(text: msg['text'] ?? '');
                        }

                        final showDate = i == 0 ||
                            _isDifferentDay(
                              (messages[i - 1]['timestamp'] as int?) ?? 0,
                              (msg['timestamp']             as int?) ?? 0,
                            );

                        return Column(
                          children: [
                            if (showDate)
                              _DateSeparator(
                                  timestamp: (msg['timestamp'] as int?) ?? 0),
                            _MessageBubble(
                              text:       msg['text']       ?? '',
                              isMe:       isMe,
                              senderName: msg['senderName'] ?? '',
                              timestamp:  (msg['timestamp'] as int?) ?? 0,
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),

            _isCompleted
                ? const _CompletedBanner()
                : _userConfirmed && !_isCompleted
                ? const _WaitingForReviewBanner()
                : _ChatInputBar(
              controller: _msgCtrl,
              isSending:  _isSending,
              onSend:     _sendMessage,
            ),
          ],
        ),
      ),
    );
  }

  bool _isDifferentDay(int ts1, int ts2) {
    final d1 = DateTime.fromMillisecondsSinceEpoch(ts1);
    final d2 = DateTime.fromMillisecondsSinceEpoch(ts2);
    return d1.day != d2.day || d1.month != d2.month || d1.year != d2.year;
  }
}

// ── Seva button states ────────────────────────────────────────────────────────
enum _SevaButtonState { hidden, confirmPayment }

// ─────────────────────────────────────────────────────────────────────────────
// CHAT OPTIONS SHEET (User side)
// ─────────────────────────────────────────────────────────────────────────────

class _ChatOptionsSheet extends StatelessWidget {
  final String helperName, helperId, bookingId, chatId, uid;
  final bool isCompleted;
  final VoidCallback onClearChat;
  final VoidCallback onReport;
  final VoidCallback onViewBooking;
  final VoidCallback onCancelBooking;

  const _ChatOptionsSheet({
    required this.helperName,
    required this.helperId,
    required this.bookingId,
    required this.chatId,
    required this.uid,
    required this.isCompleted,
    required this.onClearChat,
    required this.onReport,
    required this.onViewBooking,
    required this.onCancelBooking,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Chat Options',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937))),
          ),
          const SizedBox(height: 16),

          _OptionTile(
            icon:      Icons.receipt_long_rounded,
            iconColor: const Color(0xFF7C3AED),
            iconBg:    const Color(0xFFEDE9FE),
            title:     'View Booking Details',
            subtitle:  'See your booking info',
            onTap:     onViewBooking,
          ),

          _OptionTile(
            icon:      Icons.cleaning_services_rounded,
            iconColor: const Color(0xFF0891B2),
            iconBg:    const Color(0xFFE0F2FE),
            title:     'Clear Chat',
            subtitle:  'Remove all messages',
            onTap:     onClearChat,
          ),

          if (!isCompleted)
            _OptionTile(
              icon:      Icons.cancel_rounded,
              iconColor: const Color(0xFFDC2626),
              iconBg:    const Color(0xFFFEE2E2),
              title:     'Cancel Booking',
              subtitle:  'Cancel this service booking',
              onTap:     onCancelBooking,
            ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: Color(0xFFF3F4F6)),
          ),

          _OptionTile(
            icon:      Icons.flag_rounded,
            iconColor: const Color(0xFFDC2626),
            iconBg:    const Color(0xFFFEE2E2),
            title:     'Report Helper',
            subtitle:  'Report inappropriate behavior',
            onTap:     onReport,
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor, iconBg;
  final String title, subtitle;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
                color: iconBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937))),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: Color(0xFFD1D5DB), size: 20),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BANNERS
// ─────────────────────────────────────────────────────────────────────────────

class _HelperConfirmedBanner extends StatelessWidget {
  final VoidCallback onConfirm;
  const _HelperConfirmedBanner({required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onConfirm,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: const Color(0xFFFFF7ED),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.payment_rounded,
                color: Color(0xFFD97706), size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Helper has confirmed the job is done!',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF92400E))),
                SizedBox(height: 2),
                Text('Tap here to confirm payment & complete.',
                    style: TextStyle(fontSize: 11, color: Color(0xFFB45309))),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: Color(0xFFD97706), size: 20),
        ]),
      ),
    );
  }
}

class _WaitingForReviewBanner extends StatelessWidget {
  const _WaitingForReviewBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: const Color(0xFFF0FDF4),
      child: const Row(children: [
        SizedBox(
          width: 18, height: 18,
          child: CircularProgressIndicator(
              color: Color(0xFF059669), strokeWidth: 2),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'Payment confirmed! Waiting for mutual completion…',
            style: TextStyle(
                fontSize: 13,
                color: Color(0xFF065F46),
                fontWeight: FontWeight.w500),
          ),
        ),
      ]),
    );
  }
}

class _CompletedBanner extends StatelessWidget {
  const _CompletedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: const Color(0xFFF0FDF4),
      child: const Row(children: [
        Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 20),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Service completed — chat is now closed.',
            style: TextStyle(
                fontSize: 13,
                color: Color(0xFF065F46),
                fontWeight: FontWeight.w500),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHAT HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _ChatHeader extends StatelessWidget {
  final String helperName;
  final String? helperPhoto;
  final String? serviceName;
  final bool isCompleted;
  final _SevaButtonState sevaButtonState;
  final VoidCallback onBackTap;
  final VoidCallback onProfileTap;
  final VoidCallback onOptionsTap;
  final VoidCallback onSevaTap;

  const _ChatHeader({
    required this.helperName,
    required this.helperPhoto,
    required this.onBackTap,
    required this.onProfileTap,
    required this.onOptionsTap,
    required this.onSevaTap,
    required this.sevaButtonState,
    this.serviceName,
    this.isCompleted = false,
  });

  @override
  Widget build(BuildContext context) {
    final initial = helperName.isNotEmpty ? helperName[0].toUpperCase() : 'H';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E0640), Color(0xFF3B0764), Color(0xFF5B21B6)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 8, 14),
          child: Row(
            children: [
              IconButton(
                onPressed: onBackTap,
                icon: const Icon(Icons.arrow_back_ios_rounded,
                    color: Colors.white, size: 20),
                padding: const EdgeInsets.all(8),
              ),

              GestureDetector(
                onTap: onProfileTap,
                child: Stack(children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                          colors: [Color(0xFFA78BFA), Color(0xFF7C3AED)]),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.3), width: 2),
                      image: (helperPhoto != null && helperPhoto!.isNotEmpty)
                          ? DecorationImage(
                          image: NetworkImage(helperPhoto!),
                          fit: BoxFit.cover)
                          : null,
                    ),
                    child: (helperPhoto == null || helperPhoto!.isEmpty)
                        ? Center(
                        child: Text(initial,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 17)))
                        : null,
                  ),
                  Positioned(
                    right: 0, bottom: 0,
                    child: Container(
                      width: 11, height: 11,
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
                ]),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: GestureDetector(
                  onTap: onProfileTap,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(helperName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            color: Color(0xFFC4B5FD), size: 16),
                      ]),
                      if (serviceName != null)
                        Text(serviceName!,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Color(0xFFC4B5FD), fontSize: 11)),
                    ],
                  ),
                ),
              ),

              if (sevaButtonState == _SevaButtonState.confirmPayment)
                GestureDetector(
                  onTap: onSevaTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD97706).withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.payment_rounded,
                            color: Colors.white, size: 13),
                        SizedBox(width: 4),
                        Text('Confirm Payment',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),

              const SizedBox(width: 4),

              // 3-dot menu
              IconButton(
                onPressed: onOptionsTap,
                icon: const Icon(Icons.more_vert_rounded,
                    color: Colors.white, size: 22),
                padding: const EdgeInsets.all(8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER INTRO CARD
// ─────────────────────────────────────────────────────────────────────────────

class _HelperIntroCard extends StatelessWidget {
  final String helperName;
  final String? helperPhoto;
  final String intro;
  final String rating;
  final String jobCount;

  const _HelperIntroCard({
    required this.helperName,
    required this.helperPhoto,
    required this.intro,
    required this.rating,
    required this.jobCount,
  });

  @override
  Widget build(BuildContext context) {
    final initial = helperName.isNotEmpty ? helperName[0].toUpperCase() : 'H';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2D0F5E),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(children: [
        Container(
          width: 54, height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
                colors: [Color(0xFFA78BFA), Color(0xFF7C3AED)]),
            border:
            Border.all(color: Colors.white.withOpacity(0.25), width: 2),
            image: (helperPhoto != null && helperPhoto!.isNotEmpty)
                ? DecorationImage(
                image: NetworkImage(helperPhoto!), fit: BoxFit.cover)
                : null,
          ),
          child: (helperPhoto == null || helperPhoto!.isEmpty)
              ? Center(
              child: Text(initial,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22)))
              : null,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(helperName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              const SizedBox(height: 3),
              Text(intro,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 11,
                      height: 1.4)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(children: [
          Row(children: [
            const Icon(Icons.star_rounded,
                color: Color(0xFFFBBF24), size: 14),
            const SizedBox(width: 3),
            Text(rating,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ]),
          const SizedBox(height: 4),
          Text('$jobCount+ jobs',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.6), fontSize: 10)),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MESSAGE BUBBLE
// ─────────────────────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final String text, senderName;
  final bool   isMe;
  final int    timestamp;

  const _MessageBubble({
    required this.text,
    required this.isMe,
    required this.senderName,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final time = timestamp > 0
        ? _fmtTime(DateTime.fromMillisecondsSinceEpoch(timestamp))
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment:
        isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 28, height: 28,
              margin: const EdgeInsets.only(right: 6, bottom: 2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    colors: [Color(0xFFA78BFA), Color(0xFF7C3AED)]),
              ),
              child: Center(
                child: Text(
                  senderName.isNotEmpty ? senderName[0].toUpperCase() : 'H',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.72),
                  decoration: BoxDecoration(
                    gradient: isMe
                        ? const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight)
                        : null,
                    color: isMe ? null : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft:     const Radius.circular(18),
                      topRight:    const Radius.circular(18),
                      bottomLeft:  Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Text(text,
                      style: TextStyle(
                          color:
                          isMe ? Colors.white : const Color(0xFF1F2937),
                          fontSize: 14,
                          height: 1.4)),
                ),
                const SizedBox(height: 3),
                Text(time,
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  String _fmtTime(DateTime dt) {
    final h      = dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
    final m      = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SYSTEM MESSAGE
// ─────────────────────────────────────────────────────────────────────────────

class _SystemMessage extends StatelessWidget {
  final String text;
  const _SystemMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEDE9FE),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: const Color(0xFF7C3AED).withOpacity(0.2)),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded,
              color: Color(0xFF7C3AED), size: 15),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF5B21B6),
                    height: 1.5)),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATE SEPARATOR
// ─────────────────────────────────────────────────────────────────────────────

class _DateSeparator extends StatelessWidget {
  final int timestamp;
  const _DateSeparator({required this.timestamp});

  @override
  Widget build(BuildContext context) {
    final dt  = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    String label;
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      label = 'Today';
    } else if (dt.day == now.day - 1 &&
        dt.month == now.month &&
        dt.year == now.year) {
      label = 'Yesterday';
    } else {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      label = '${dt.day} ${months[dt.month - 1]}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500)),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY CHAT STATE
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyChatState extends StatelessWidget {
  final String helperName;
  const _EmptyChatState({required this.helperName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: const BoxDecoration(
                  color: Color(0xFFEDE9FE), shape: BoxShape.circle),
              child: const Icon(Icons.chat_bubble_outline_rounded,
                  size: 32, color: Color(0xFF7C3AED)),
            ),
            const SizedBox(height: 16),
            Text('Say hello to $helperName!',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937))),
            const SizedBox(height: 6),
            const Text('Your conversation will appear here.',
                style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHAT INPUT BAR
// ─────────────────────────────────────────────────────────────────────────────

class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool         isSending;
  final VoidCallback onSend;

  const _ChatInputBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 10, 12, MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -3)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color:        const Color(0xFFF4F6FB),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller:         controller,
                maxLines:           null,
                keyboardType:       TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  hintText:  'Type a message...',
                  hintStyle: TextStyle(color: Color(0xFFADB5BD), fontSize: 14),
                  border:    InputBorder.none,
                  contentPadding:
                  EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isSending ? null : onSend,
            child: Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                  begin: Alignment.topLeft,
                  end:   Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF7C3AED).withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3)),
                ],
              ),
              child: isSending
                  ? const Center(
                child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                ),
              )
                  : const Icon(Icons.send_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}