// lib/screens/chat_screen.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../service/realtime_db_service.dart';
import 'about_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CHAT SCREEN
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

  // ── Reactive completed flag ───────────────────────────────────────────────
  bool _isCompleted = false;
  StreamSubscription? _statusSub;

  bool _isSending       = false;
  bool _showHelperIntro = false;

  late final AnimationController _introAnim;
  late final Animation<double>   _introSlide;
  late final Animation<double>   _introFade;

  String get _uid      => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _userName => FirebaseAuth.instance.currentUser?.displayName ?? 'User';

  @override
  void initState() {
    super.initState();

    // ── Seed from the param passed in (instant, no flicker) ──────────────
    _isCompleted =
        widget.bookingStatus == 'completed' ||
            widget.bookingStatus == 'cancelled';

    // ── React to Firestore changes so the banner appears the moment the
    //    booking is marked completed, even while the chat is open ──────────
    _statusSub = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .snapshots()
        .listen((snap) {
      final status = snap.data()?['bookingStatus'] as String? ?? 'active';
      if (mounted) {
        setState(() {
          _isCompleted =
              status == 'completed' || status == 'cancelled';
        });
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
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

  // ── Two-step seva completion ──────────────────────────────────────────────
  Future<void> _onSevaCompleted() async {
    // Step 1 — confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Service completed?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Please confirm that "${widget.serviceName ?? "the service"}" '
              'has been fully completed before rating.',
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
            child: const Text('Yes, it is done',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Step 2 — update /bookings doc
    final snap = await FirebaseFirestore.instance
        .collection('bookings')
        .where('bookingCode', isEqualTo: widget.bookingId ?? '')
        .where('userId', isEqualTo: _uid)
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty) {
      await snap.docs.first.reference.update({
        'status':      'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });
    }

    // Step 3 — update /chats/{chatId} so the stream above fires instantly
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .update({'bookingStatus': 'completed'});

    // Step 4 — show the review sheet
    if (!mounted) return;
    MutualReviewSheet.showForUser(
      context,
      bookingId:   widget.bookingId ?? '',
      helperId:    widget.helperId,
      helperName:  widget.helperName,
      serviceName: widget.serviceName ?? '',
    );
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChatOptionsSheet(
        helperName: widget.helperName,
        helperId:   widget.helperId,
        bookingId:  widget.bookingId ?? '',
        chatId:     widget.chatId,
        uid:        _uid,
      ),
    );
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
            // ── Header ──────────────────────────────────────────────────
            _ChatHeader(
              helperName:   widget.helperName,
              helperPhoto:  widget.helperPhoto,
              onBackTap:    () => Navigator.pop(context),
              onProfileTap: _toggleHelperIntro,
              onOptionsTap: _showOptionsMenu,
              onSevaTap:    _onSevaCompleted,
              serviceName:  widget.serviceName,
            ),

            // ── Helper Intro Slide-down ──────────────────────────────────
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

            // ── Messages ─────────────────────────────────────────────────
            Expanded(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: RealtimeDbService.instance.messagesStream(widget.chatId),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF7C3AED), strokeWidth: 2),
                      );
                    }

                    final messages = snap.data ?? [];

                    if (messages.isEmpty) {
                      return _EmptyChatState(helperName: widget.helperName);
                    }

                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => _scrollToBottom());

                    return ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      itemCount: messages.length,
                      itemBuilder: (_, i) {
                        final msg  = messages[i];
                        final isMe = msg['senderId'] == _uid;
                        final type = msg['type'] as String? ?? 'text';

                        if (type == 'booking_confirmed' || type == 'system') {
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

            // ── Input Bar / Closed Banner ─────────────────────────────────
            _isCompleted
                ? Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 16),
              color: const Color(0xFFF0FDF4),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF059669), size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Service completed — chat is now closed.',
                      style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF065F46),
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            )
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

// ─────────────────────────────────────────────────────────────────────────────
// CHAT HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _ChatHeader extends StatelessWidget {
  final String helperName;
  final String? helperPhoto;
  final String? serviceName;
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
    this.serviceName,
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
              // ── Back arrow ───────────────────────────────────────────
              IconButton(
                onPressed: onBackTap,
                icon: const Icon(Icons.arrow_back_ios_rounded,
                    color: Colors.white, size: 20),
                padding: const EdgeInsets.all(8),
              ),

              // ── Avatar (tappable) ─────────────────────────────────────
              GestureDetector(
                onTap: onProfileTap,
                child: Stack(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFA78BFA), Color(0xFF7C3AED)],
                        ),
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
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E),
                          shape: BoxShape.circle,
                          border:
                          Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // ── Name + service (tappable) ─────────────────────────────
              Expanded(
                child: GestureDetector(
                  onTap: onProfileTap,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(helperName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            color: Color(0xFFC4B5FD), size: 16),
                      ]),
                      if (serviceName != null)
                        Text(serviceName!,
                            style: const TextStyle(
                                color: Color(0xFFC4B5FD), fontSize: 11)),
                    ],
                  ),
                ),
              ),

              // ── Seva Completed button ─────────────────────────────────
              GestureDetector(
                onTap: onSevaTap,
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF059669).withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded,
                          color: Colors.white, size: 13),
                      SizedBox(width: 4),
                      Text('Seva Done',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 4),

              // ── 3 dots menu ───────────────────────────────────────────
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
// HELPER INTRO SLIDE-DOWN CARD
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
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFA78BFA), Color(0xFF7C3AED)],
              ),
              border: Border.all(
                  color: Colors.white.withOpacity(0.25), width: 2),
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
          Column(
            children: [
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
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHAT OPTIONS SHEET (3 dots menu)
// ─────────────────────────────────────────────────────────────────────────────

class _ChatOptionsSheet extends StatelessWidget {
  final String helperName;
  final String helperId;
  final String bookingId;
  final String chatId;
  final String uid;

  const _ChatOptionsSheet({
    required this.helperName,
    required this.helperId,
    required this.bookingId,
    required this.chatId,
    required this.uid,
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
              width: 40,
              height: 4,
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
            onTap: () {
              Navigator.pop(context);
            },
          ),

          _OptionTile(
            icon:      Icons.cleaning_services_rounded,
            iconColor: const Color(0xFF0891B2),
            iconBg:    const Color(0xFFE0F2FE),
            title:     'Clear Chat',
            subtitle:  'Remove all messages locally',
            onTap: () {
              Navigator.pop(context);
              _showClearChatConfirm(context);
            },
          ),

          _OptionTile(
            icon:      Icons.block_rounded,
            iconColor: const Color(0xFFD97706),
            iconBg:    const Color(0xFFFEF3C7),
            title:     'Block Helper',
            subtitle:  'Stop receiving messages',
            onTap: () {
              Navigator.pop(context);
              _blockHelper(context);
            },
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: Color(0xFFF3F4F6)),
          ),

          _OptionTile(
            icon:      Icons.flag_rounded,
            iconColor: const Color(0xFFDC2626),
            iconBg:    const Color(0xFFFEE2E2),
            title:     'Report',
            subtitle:  'Report inappropriate behavior',
            onTap: () {
              Navigator.pop(context);
              _showReportSheet(context);
            },
          ),
        ],
      ),
    );
  }

  void _showClearChatConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear Chat?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('This will delete all messages for you only.',
            style: TextStyle(color: Color(0xFF6B7280))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await RealtimeDbService.instance.deleteChat(chatId);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0891B2), elevation: 0),
            child:
            const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _blockHelper(BuildContext context) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('blocked')
        .doc(helperId)
        .set({
      'blockedAt':  FieldValue.serverTimestamp(),
      'helperId':   helperId,
      'helperName': helperName,
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Helper blocked successfully'),
        backgroundColor: Color(0xFFD97706),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _showReportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReportSheet(
        helperName:     helperName,
        helperId:       helperId,
        bookingId:      bookingId,
        chatId:         chatId,
        reporterUserId: uid,
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData  icon;
  final Color     iconColor;
  final Color     iconBg;
  final String    title;
  final String    subtitle;
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
            width: 44,
            height: 44,
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
// REPORT SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _ReportSheet extends StatefulWidget {
  final String helperName;
  final String helperId;
  final String bookingId;
  final String chatId;
  final String reporterUserId;

  const _ReportSheet({
    required this.helperName,
    required this.helperId,
    required this.bookingId,
    required this.chatId,
    required this.reporterUserId,
  });

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  int?   _selectedReason;
  final  _detailCtrl   = TextEditingController();
  bool   _isSubmitting = false;
  String? _errorMsg;

  static const List<Map<String, dynamic>> _reasons = [
    {
      'icon':  Icons.warning_amber_rounded,
      'color': Color(0xFFDC2626),
      'label': 'Harassment or Abusive Language',
      'sub':   'Rude, threatening, or abusive messages',
    },
    {
      'icon':  Icons.block_rounded,
      'color': Color(0xFFD97706),
      'label': 'Inappropriate Content',
      'sub':   'Offensive or uncomfortable messages',
    },
    {
      'icon':  Icons.campaign_rounded,
      'color': Color(0xFF0891B2),
      'label': 'Spam or Promotion',
      'sub':   'Repeated promotions or unwanted messages',
    },
    {
      'icon':  Icons.money_off_rounded,
      'color': Color(0xFFDC2626),
      'label': 'Fraud or Scam Attempt',
      'sub':   'Trying to cheat or defraud',
    },
    {
      'icon':  Icons.engineering_rounded,
      'color': Color(0xFF7C3AED),
      'label': 'Unprofessional Behavior',
      'sub':   'Inappropriate service behavior',
    },
    {
      'icon':  Icons.shield_rounded,
      'color': Color(0xFFDC2626),
      'label': 'Safety Concern',
      'sub':   'Feeling unsafe with this helper',
    },
    {
      'icon':  Icons.credit_card_rounded,
      'color': Color(0xFFD97706),
      'label': 'Asking for Personal Information',
      'sub':   'Requesting OTP, bank details, etc.',
    },
    {
      'icon':  Icons.chat_bubble_outline_rounded,
      'color': Color(0xFF6B7280),
      'label': 'Irrelevant Messages',
      'sub':   'Unrelated chat content',
    },
    {
      'icon':  Icons.person_off_rounded,
      'color': Color(0xFFDC2626),
      'label': 'Fake Helper Identity',
      'sub':   'Pretending to be a different helper',
    },
    {
      'icon':  Icons.help_outline_rounded,
      'color': Color(0xFF374151),
      'label': 'Other',
      'sub':   'Describe the issue below',
    },
  ];

  @override
  void dispose() {
    _detailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) {
      setState(() => _errorMsg = 'Please select a reason to continue.');
      return;
    }
    if (_selectedReason == 9 && _detailCtrl.text.trim().isEmpty) {
      setState(() => _errorMsg = 'Please describe the issue.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMsg     = null;
    });

    try {
      final reason = _reasons[_selectedReason!]['label'] as String;
      final detail = _detailCtrl.text.trim();

      await FirebaseFirestore.instance.collection('chat_reports').add({
        'reporterUserId': widget.reporterUserId,
        'helperId':       widget.helperId,
        'bookingId':      widget.bookingId,
        'chatId':         widget.chatId,
        'reason':         reason,
        'detail':         detail.isNotEmpty ? detail : null,
        'status':         'pending',
        'timestamp':      FieldValue.serverTimestamp(),
      });

      final reportsSnap = await FirebaseFirestore.instance
          .collection('chat_reports')
          .where('helperId', isEqualTo: widget.helperId)
          .where('status',   isEqualTo: 'pending')
          .get();

      if (reportsSnap.docs.length >= 3) {
        await FirebaseFirestore.instance
            .collection('helpers')
            .doc(widget.helperId)
            .set({
          'flagged':        true,
          'flagReason':     'Auto-flagged: 3+ chat reports',
          'flaggedAt':      FieldValue.serverTimestamp(),
          'pendingReports': reportsSnap.docs.length,
        }, SetOptions(merge: true));
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Expanded(
                child: Text('Report submitted. Our team will review it.',
                    style: TextStyle(fontWeight: FontWeight.w600))),
          ]),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          margin:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ));
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMsg     = 'Failed to submit report. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize:     0.5,
      maxChildSize:     0.95,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.flag_rounded,
                      color: Color(0xFFDC2626), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Report Helper',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937))),
                      Text('Reporting: ${widget.helperName}',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF9CA3AF))),
                    ],
                  ),
                ),
              ]),
            ),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                children: [
                  const Text('Select a reason',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF374151))),
                  const SizedBox(height: 12),

                  ...List.generate(_reasons.length, (i) {
                    final r          = _reasons[i];
                    final isSelected = _selectedReason == i;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedReason = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (r['color'] as Color).withOpacity(0.06)
                              : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? (r['color'] as Color)
                                : const Color(0xFFE5E7EB),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: (r['color'] as Color).withOpacity(0.10),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(r['icon'] as IconData,
                                color: r['color'] as Color, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r['label'] as String,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? r['color'] as Color
                                            : const Color(0xFF1F2937))),
                                const SizedBox(height: 2),
                                Text(r['sub'] as String,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF9CA3AF))),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check_circle_rounded,
                                color: r['color'] as Color, size: 20),
                        ]),
                      ),
                    );
                  }),

                  const SizedBox(height: 4),
                  const Text('Additional details (optional)',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF374151))),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _detailCtrl,
                    maxLines:   3,
                    maxLength:  300,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Describe what happened in your own words...',
                      hintStyle: const TextStyle(
                          color: Color(0xFFADB5BD), fontSize: 13),
                      filled:    true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                        const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                        const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: Color(0xFFDC2626), width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),

                  if (_errorMsg != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Color(0xFFDC2626), size: 15),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(_errorMsg!,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFDC2626)))),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        disabledBackgroundColor:
                        const Color(0xFFDC2626).withOpacity(0.4),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                          : const Text('Submit Report',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MESSAGE BUBBLE
// ─────────────────────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool   isMe;
  final String senderName;
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
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 6, bottom: 2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFA78BFA), Color(0xFF7C3AED)],
                ),
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
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  decoration: BoxDecoration(
                    gradient: isMe
                        ? const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
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
                        color:      Colors.black.withOpacity(0.06),
                        blurRadius: 6,
                        offset:     const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      color:    isMe ? Colors.white : const Color(0xFF1F2937),
                      fontSize: 14,
                      height:   1.4,
                    ),
                  ),
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
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
              width: 72,
              height: 72,
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
            color:      Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset:     const Offset(0, -3),
          ),
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
                controller:           controller,
                maxLines:             null,
                keyboardType:         TextInputType.multiline,
                textCapitalization:   TextCapitalization.sentences,
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
              width:  46,
              height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                  begin: Alignment.topLeft,
                  end:   Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color:      const Color(0xFF7C3AED).withOpacity(0.4),
                    blurRadius: 8,
                    offset:     const Offset(0, 3),
                  ),
                ],
              ),
              child: isSending
                  ? const Center(
                child: SizedBox(
                  width:  18,
                  height: 18,
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