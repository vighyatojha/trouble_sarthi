// ignore_for_file: use_build_context_synchronously
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/booking_chat_screen.dart';
import '../core/chat_unread.dart';
import '../core/sarthi_ui.dart';
import '../request/booking_tracker_screen.dart';
import '../request/request_pitches_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GLOBAL NOTIFICATION COUNT
// ─────────────────────────────────────────────────────────────────────────────

class NotificationCountNotifier extends ValueNotifier<int> {
  NotificationCountNotifier._() : super(0);
  static final instance = NotificationCountNotifier._();
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVITY SCREEN  (bottom-nav "Messages" tab: chats + notifications)
// ─────────────────────────────────────────────────────────────────────────────

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _searchCtrl = TextEditingController();
  bool _searching = false;
  String _query = '';

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _notifSub;
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() {
      if (!_tab.indexIsChanging && mounted) setState(() {});
    });
    // One place keeps the Messages badge right: unread chats + unread notifications.
    ChatUnread.instance.start();
    ChatUnread.instance.unreadCount.addListener(_syncBadge);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _notifSub = FirebaseFirestore.instance
          .collection('notifications')
          .doc(uid)
          .collection('items')
          .where('read', isEqualTo: false)
          .snapshots()
          .listen((s) {
        _unreadNotifications = s.size;
        _syncBadge();
      }, onError: (_) {});
    }
  }

  void _syncBadge() {
    final total = ChatUnread.instance.unreadCount.value + _unreadNotifications;
    if (NotificationCountNotifier.instance.value != total) NotificationCountNotifier.instance.value = total;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ChatUnread.instance.unreadCount.removeListener(_syncBadge);
    _notifSub?.cancel();
    _searchCtrl.dispose();
    _tab.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _searchCtrl.clear();
        _query = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chats = ChatUnread.instance.unreadCount.value;
    return Scaffold(
      backgroundColor: SarthiColors.page,
      body: Column(
        children: [
          SarthiTabHeader(
            title: 'Activity',
            subtitle: chats > 0
                ? '$chats chat${chats == 1 ? '' : 's'} with new messages'
                : 'Chats with your helpers and booking updates',
            tabController: _tab,
            tabs: [
              chats > 0 ? 'Messages ($chats)' : 'Messages',
              _unreadNotifications > 0 ? 'Notifications ($_unreadNotifications)' : 'Notifications',
            ],
            actions: [
              if (_tab.index == 0)
                SarthiHeaderButton(
                  icon: _searching ? Icons.close_rounded : Icons.search_rounded,
                  active: _searching,
                  onTap: _toggleSearch,
                ),
            ],
            below: _searching && _tab.index == 0
                ? Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white,
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search by name or service',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withValues(alpha: 0.8), size: 20),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.13),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                ),
              ),
            )
                : null,
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _MessagesTab(query: _query),
                const _NotificationsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MESSAGES TAB  — one card per booking chat (chats/{bookingId})
// ─────────────────────────────────────────────────────────────────────────────

class _MessagesTab extends StatefulWidget {
  final String query;
  const _MessagesTab({required this.query});

  @override
  State<_MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<_MessagesTab> {
  Stream<QuerySnapshot<Map<String, dynamic>>>? _stream;
  String _streamUid = '';

  Stream<QuerySnapshot<Map<String, dynamic>>> _chats(String uid) {
    if (_stream == null || _streamUid != uid) {
      _streamUid = uid;
      _stream = FirebaseFirestore.instance.collection('chats').where('participants', arrayContains: uid).snapshots();
    }
    return _stream!;
  }

  static const _active = {'confirmed', 'on_the_way', 'arrived', 'in_progress', 'work_done'};

  void _open(String chatId, Map<String, dynamic> d) {
    final me = FirebaseAuth.instance.currentUser?.displayName;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingChatScreen(
          bookingId: chatId,
          otherName: '${d['helperName'] ?? d['otherName'] ?? 'Helper'}',
          otherPhotoUrl: '${d['helperPhoto'] ?? ''}',
          myName: (me != null && me.isNotEmpty) ? me : '${d['customerName'] ?? 'Customer'}',
          myRole: 'customer',
          subtitle: '${d['serviceName'] ?? ''}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const SarthiEmpty(icon: Icons.chat_bubble_outline_rounded, title: 'Sign in to view messages');
    }

    return ValueListenableBuilder<int>(
      valueListenable: ChatUnread.instance.revision,
      builder: (context, _, __) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _chats(uid),
        builder: (context, snap) {
          if (snap.hasError) {
            return const SarthiEmpty(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load chats',
              message: 'Check your internet connection and try again.',
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: SarthiColors.purple, strokeWidth: 2));
          }

          // Only chats from the new booking flow (they carry a jobId). Chats from
          // the old app version stay in the database but are not listed.
          final docs = snap.data!.docs.where((doc) {
            final d = doc.data();
            return '${d['jobId'] ?? ''}'.isNotEmpty && '${d['helperId'] ?? ''}'.isNotEmpty;
          }).toList();

          final q = widget.query;
          final filtered = q.isEmpty
              ? docs
              : docs.where((doc) {
            final d = doc.data();
            final hay = '${d['helperName'] ?? ''} ${d['otherName'] ?? ''} ${d['serviceName'] ?? ''} ${d['lastMessage'] ?? ''}'
                .toLowerCase();
            return hay.contains(q);
          }).toList();

          // Unread first, then active bookings, then newest message.
          int rank(Map<String, dynamic> d, String id) =>
              (ChatUnread.instance.isUnread(d, id) ? 0 : 2) + (_active.contains(d['bookingStatus']) ? 0 : 1);
          filtered.sort((a, b) {
            final r = rank(a.data(), a.id).compareTo(rank(b.data(), b.id));
            if (r != 0) return r;
            final at = a.data()['lastMessageTime'], bt = b.data()['lastMessageTime'];
            if (at is! Timestamp) return 1;
            if (bt is! Timestamp) return -1;
            return bt.compareTo(at);
          });

          if (docs.isEmpty) {
            return const SarthiEmpty(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'No chats yet',
              message: 'When you book a helper, you can chat with them here.',
            );
          }
          if (filtered.isEmpty) {
            return SarthiEmpty(icon: Icons.search_off_rounded, title: 'No chats match "${widget.query}"');
          }

          final activeList = filtered.where((d) => _active.contains(d.data()['bookingStatus'])).toList();
          final pastList = filtered.where((d) => !_active.contains(d.data()['bookingStatus'])).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 130),
            children: [
              if (activeList.isNotEmpty) ...[
                const SarthiSectionLabel('Active bookings'),
                for (final doc in activeList)
                  _ConversationCard(
                    data: doc.data(),
                    unread: ChatUnread.instance.isUnread(doc.data(), doc.id),
                    onTap: () => _open(doc.id, doc.data()),
                  ),
              ],
              if (pastList.isNotEmpty) ...[
                const SarthiSectionLabel('Past bookings'),
                for (final doc in pastList)
                  _ConversationCard(
                    data: doc.data(),
                    unread: ChatUnread.instance.isUnread(doc.data(), doc.id),
                    onTap: () => _open(doc.id, doc.data()),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONVERSATION CARD
// ─────────────────────────────────────────────────────────────────────────────

class _ConversationCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool unread;
  final VoidCallback onTap;
  const _ConversationCard({required this.data, required this.unread, required this.onTap});

  static (String, Color) _status(String s) => switch (s) {
    'confirmed' => ('Confirmed', SarthiColors.purple),
    'on_the_way' => ('On the way', const Color(0xFF0891B2)),
    'arrived' => ('Arrived', const Color(0xFF0891B2)),
    'in_progress' => ('Working', SarthiColors.amber),
    'work_done' => ('Work done', SarthiColors.green),
    'completed' => ('Completed', SarthiColors.green),
    'cancelled' => ('Cancelled', SarthiColors.red),
    _ => ('Booking', SarthiColors.muted),
  };

  @override
  Widget build(BuildContext context) {
    final name = '${data['helperName'] ?? data['otherName'] ?? 'Helper'}';
    final service = '${data['serviceName'] ?? ''}';
    final photo = '${data['helperPhoto'] ?? ''}';
    final lastMsg = '${data['lastMessage'] ?? ''}';
    final mineLast = data['lastSenderId'] == FirebaseAuth.instance.currentUser?.uid;
    final ts = data['lastMessageTime'];
    final time = ts is Timestamp ? sarthiShortTime(ts.toDate()) : '';
    final statusKey = '${data['bookingStatus'] ?? ''}';
    final (statusText, statusColor) = _status(statusKey);
    final closed = statusKey == 'cancelled';
    final finished = statusKey == 'completed';
    final preview = closed
        ? 'Booking cancelled · chat closed'
        : finished
        ? 'Job completed · chat closed'
        : lastMsg.isEmpty
        ? 'Say hello and share details about the work'
        : '${mineLast ? 'You: ' : ''}$lastMsg';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Ink(
            decoration: sarthiCard(
              color: unread ? const Color(0xFFFAF8FF) : Colors.white,
              border: unread ? SarthiColors.purple.withValues(alpha: 0.25) : null,
            ),
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              SarthiAvatar(name: name, photoUrl: photo, size: 50, dimmed: closed),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                            color: closed ? SarthiColors.faint : SarthiColors.ink,
                          )),
                    ),
                    Text(time,
                        style: TextStyle(
                          fontSize: 11,
                          color: unread ? SarthiColors.purple : SarthiColors.faint,
                          fontWeight: unread ? FontWeight.w700 : FontWeight.normal,
                        )),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    if (service.isNotEmpty) ...[
                      Flexible(
                        child: SarthiChip(service, color: SarthiColors.purple, icon: Icons.build_circle_outlined),
                      ),
                      const SizedBox(width: 6),
                    ],
                    SarthiChip(statusText, color: statusColor),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(
                      child: Text(preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: unread ? SarthiColors.body : SarthiColors.faint,
                            fontWeight: unread ? FontWeight.w600 : FontWeight.normal,
                            fontStyle: (lastMsg.isEmpty || closed || finished) ? FontStyle.italic : FontStyle.normal,
                          )),
                    ),
                    if (unread) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: SarthiColors.purple, borderRadius: BorderRadius.circular(10)),
                        child: const Text('New',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
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

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATIONS TAB
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationsTab extends StatefulWidget {
  const _NotificationsTab();

  @override
  State<_NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<_NotificationsTab> {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const _EmptyState(
          icon: Icons.notifications_none_rounded,
          message: 'Sign in to view notifications');
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .doc(uid)
          .collection('items')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF7C3AED), strokeWidth: 2));
        }

        final docs = snap.data?.docs ?? [];
        final unreadCount =
            docs.where((d) => (d.data() as Map)['read'] != true).length;

        if (docs.isEmpty) {
          return const _EmptyState(
            icon: Icons.notifications_none_rounded,
            message: 'No notifications yet\nBooking updates will appear here',
          );
        }

        final now            = DateTime.now();
        final todayStart     = DateTime(now.year, now.month, now.day);
        final yesterdayStart = todayStart.subtract(const Duration(days: 1));

        final today     = <QueryDocumentSnapshot>[];
        final yesterday = <QueryDocumentSnapshot>[];
        final earlier   = <QueryDocumentSnapshot>[];

        for (final doc in docs) {
          final ts = (doc.data() as Map<String, dynamic>)['createdAt']
          as Timestamp?;
          if (ts == null) continue;
          final dt = ts.toDate();
          if (!dt.isBefore(todayStart)) {
            today.add(doc);
          } else if (!dt.isBefore(yesterdayStart)) {
            yesterday.add(doc);
          } else {
            earlier.add(doc);
          }
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 130),
          children: [
            if (unreadCount > 0)
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => _markAllRead(uid, docs),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'Mark all as read',
                      style: TextStyle(
                          color: Color(0xFF7C3AED),
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: 8),

            if (today.isNotEmpty) ...[
              _SectionLabel('TODAY'),
              ...today.map((d) => _NotificationCard(doc: d, uid: uid)),
            ],
            if (yesterday.isNotEmpty) ...[
              _SectionLabel('YESTERDAY'),
              ...yesterday.map((d) => _NotificationCard(doc: d, uid: uid)),
            ],
            if (earlier.isNotEmpty) ...[
              _SectionLabel('EARLIER'),
              ...earlier.map((d) => _NotificationCard(doc: d, uid: uid)),
            ],
          ],
        );
      },
    );
  }

  Future<void> _markAllRead(
      String uid, List<QueryDocumentSnapshot> docs) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in docs) {
      if ((doc.data() as Map)['read'] != true) {
        batch.update(doc.reference, {'read': true});
      }
    }
    await batch.commit();
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 0, 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Color(0xFF9CA3AF),
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATION CARD
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final String uid;
  const _NotificationCard({required this.doc, required this.uid});

  @override
  Widget build(BuildContext context) {
    final data    = doc.data() as Map<String, dynamic>;
    final type    = data['type']  as String? ?? 'system';
    final title   = data['title'] as String? ?? '';
    final body    = data['body']  as String? ?? '';
    final isRead  = data['read']  as bool?   ?? false;
    final ts      = data['createdAt'] as Timestamp?;
    final timeStr = ts != null ? _relTime(ts.toDate()) : '';

    void markRead() {
      if (!isRead) doc.reference.update({'read': true});
    }

    // Tapping an update opens the booking or the request it is about.
    void open() {
      markRead();
      final bookingId = '${data['bookingId'] ?? ''}';
      final jobId = '${data['jobId'] ?? ''}';
      Widget? page;
      if (bookingId.isNotEmpty && type != 'new_pitch') {
        page = BookingTrackerScreen(bookingId: bookingId);
      } else if (jobId.isNotEmpty) {
        page = RequestPitchesScreen(jobId: jobId);
      }
      if (page != null) Navigator.of(context).push(MaterialPageRoute(builder: (_) => page!));
    }

    if (type == 'offer') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GestureDetector(
          onTap: open,
          child: Container(
            decoration: BoxDecoration(
              color:
              isRead ? const Color(0xFFF0EEFF) : const Color(0xFFEDE9FE),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: const Color(0xFF7C3AED)
                      .withOpacity(isRead ? 0.08 : 0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withOpacity(0.10),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color:
                                const Color(0xFF7C3AED).withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 2))
                          ],
                        ),
                        child: const Icon(Icons.local_offer_rounded,
                            color: Color(0xFF7C3AED), size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('SPECIAL OFFER',
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF7C3AED),
                                      letterSpacing: 0.8)),
                            ),
                            const SizedBox(height: 3),
                            Text(title,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1F2937))),
                          ],
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                              color: Color(0xFF7C3AED),
                              shape: BoxShape.circle),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(body,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF374151),
                              height: 1.5)),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: markRead,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Color(0xFF7C3AED), width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24)),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                        ),
                        child: const Text('CLAIM OFFER NOW',
                            style: TextStyle(
                                color: Color(0xFF7C3AED),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                letterSpacing: 0.8)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (type == 'service_completed') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _RatingCard(
            doc: doc, data: data, timeStr: timeStr, isRead: isRead),
      );
    }

    final cfg = _cfg(type);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: open,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: isRead ? Colors.white : const Color(0xFFFAF8FF),
            borderRadius: BorderRadius.circular(16),
            border: isRead
                ? Border.all(color: const Color(0xFFF0F0F5))
                : Border.all(color: cfg.color.withOpacity(0.18)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cfg.color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(cfg.icon, color: cfg.color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(title,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937))),
                        ),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(timeStr,
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF9CA3AF))),
                            if (!isRead) ...[
                              const SizedBox(height: 4),
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                    color: cfg.color,
                                    shape: BoxShape.circle),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(body,
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                            height: 1.4)),
                    if (cfg.actionLabel != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                cfg.color,
                                cfg.color.withOpacity(0.75)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                  color: cfg.color.withOpacity(0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2))
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(cfg.actionIcon,
                                  color: Colors.white, size: 13),
                              const SizedBox(width: 4),
                              Text(cfg.actionLabel!,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _relTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return '1d ago';
    return '${diff.inDays}d ago';
  }

  _Cfg _cfg(String type) {
    switch (type) {
    // Types written by the notify Worker.
      case 'new_pitch':
        return _Cfg(Icons.local_offer_rounded, const Color(0xFFD97706), 'Compare quotes', Icons.compare_arrows_rounded);
      case 'status_on_the_way':
        return _Cfg(Icons.directions_bike_rounded, const Color(0xFF0891B2), 'Track', Icons.navigation_rounded);
      case 'status_arrived':
        return _Cfg(Icons.location_on_rounded, const Color(0xFF0891B2), 'Show start code', Icons.pin_rounded);
      case 'status_in_progress':
        return _Cfg(Icons.handyman_rounded, const Color(0xFFD97706), 'View booking', Icons.arrow_forward_rounded);
      case 'status_work_done':
        return _Cfg(Icons.task_alt_rounded, const Color(0xFF059669), 'Pay & confirm', Icons.payments_rounded);
      case 'completed_customer':
        return _Cfg(Icons.verified_rounded, const Color(0xFF059669), 'Rate helper', Icons.star_rounded);
      case 'cancelled_by_helper':
        return _Cfg(Icons.cancel_rounded, const Color(0xFFDC2626), 'See other quotes', Icons.arrow_forward_rounded);
      case 'job_no_pitches':
      case 'job_expired':
        return _Cfg(Icons.hourglass_bottom_rounded, const Color(0xFF6B7280));
      case 'review_waiting_customer':
        return _Cfg(Icons.lock_clock_rounded, const Color(0xFFD97706), 'Rate to see review', Icons.star_rounded);
      case 'reviews_revealed_customer':
        return _Cfg(Icons.handshake_rounded, const Color(0xFF7C3AED), 'See review', Icons.visibility_rounded);
      case 'overdue':
        return _Cfg(Icons.schedule_rounded, const Color(0xFFD97706), 'Open booking', Icons.arrow_forward_rounded);
      case 'booking_confirmed':
        return _Cfg(Icons.check_circle_rounded, const Color(0xFF7C3AED),
            'View Booking', Icons.calendar_today_rounded);
      case 'helper_arriving':
        return _Cfg(Icons.near_me_rounded, const Color(0xFF0891B2), 'Track',
            Icons.navigation_rounded);
      case 'helper_assigned':
        return _Cfg(Icons.person_pin_circle_rounded, const Color(0xFF7C3AED),
            'View Helper', Icons.person_rounded);
      case 'payment_received':
        return _Cfg(Icons.check_circle_rounded, const Color(0xFF059669));
      case 'booking_cancelled':
        return _Cfg(Icons.cancel_rounded, const Color(0xFFDC2626));
      default:
        return _Cfg(Icons.notifications_rounded, const Color(0xFF7C3AED));
    }
  }
}

class _Cfg {
  final IconData icon;
  final Color    color;
  final String?  actionLabel;
  final IconData actionIcon;
  const _Cfg(this.icon, this.color,
      [this.actionLabel, this.actionIcon = Icons.arrow_forward_rounded]);
}

// ─────────────────────────────────────────────────────────────────────────────
// RATING CARD
// ─────────────────────────────────────────────────────────────────────────────

class _RatingCard extends StatefulWidget {
  final QueryDocumentSnapshot  doc;
  final Map<String, dynamic>   data;
  final String                 timeStr;
  final bool                   isRead;
  const _RatingCard(
      {required this.doc,
        required this.data,
        required this.timeStr,
        required this.isRead});

  @override
  State<_RatingCard> createState() => _RatingCardState();
}

class _RatingCardState extends State<_RatingCard> {
  late int _rating;

  @override
  void initState() {
    super.initState();
    _rating = (widget.data['rating'] as int?) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.data['title'] as String? ?? 'Service Completed';
    final body  = widget.data['body']  as String? ?? '';
    final rated = _rating > 0;

    return GestureDetector(
      onTap: () {
        if (!widget.isRead) widget.doc.reference.update({'read': true});
      },
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: widget.isRead ? Colors.white : const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: widget.isRead
                  ? const Color(0xFFF0F0F5)
                  : const Color(0xFFD97706).withOpacity(0.20)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEF3C7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.star_rounded,
                      color: Color(0xFFD97706), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(title,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1F2937))),
                          ),
                          Text(widget.timeStr,
                              style: const TextStyle(
                                  fontSize: 10, color: Color(0xFF9CA3AF))),
                          if (!widget.isRead) ...[
                            const SizedBox(width: 5),
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                  color: Color(0xFFD97706),
                                  shape: BoxShape.circle),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(body,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                              height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final filled = i < _rating;
                return GestureDetector(
                  onTap: rated
                      ? null
                      : () async {
                    setState(() => _rating = i + 1);
                    await widget.doc.reference
                        .update({'rating': i + 1, 'read': true});
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      Icons.star_rounded,
                      size: 30,
                      color: filled
                          ? const Color(0xFFD97706)
                          : const Color(0xFFD1D5DB),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 5),
            Center(
              child: Text(
                rated ? 'Thanks for rating!' : 'Tap to rate',
                style: TextStyle(
                  fontSize: 11,
                  color: rated
                      ? const Color(0xFF059669)
                      : const Color(0xFF9CA3AF),
                  fontWeight: rated ? FontWeight.w600 : FontWeight.normal,
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
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String   message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                  color: Color(0xFFEDE9FE), shape: BoxShape.circle),
              child: Icon(icon, size: 32, color: const Color(0xFF7C3AED)),
            ),
            const SizedBox(height: 18),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF9CA3AF), height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FIRESTORE NOTIFICATION HELPERS
// ─────────────────────────────────────────────────────────────────────────────

Future<void> sendBookingConfirmedNotification({
  required String userId,
  required String helperName,
  required String serviceName,
  required String bookingId,
}) async {
  await FirebaseFirestore.instance
      .collection('notifications')
      .doc(userId)
      .collection('items')
      .add({
    'type': 'booking_confirmed',
    'title': 'Booking Confirmed',
    'body':
    'Your request for "$serviceName" has been confirmed. Helper: $helperName.',
    'bookingId': bookingId,
    'read': false,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

Future<void> sendBookingCancelledNotification({
  required String userId,
  required String serviceName,
  required String bookingId,
}) async {
  await FirebaseFirestore.instance
      .collection('notifications')
      .doc(userId)
      .collection('items')
      .add({
    'type': 'booking_cancelled',
    'title': 'Booking Cancelled',
    'body':
    'Your booking for "$serviceName" (#$bookingId) has been cancelled.',
    'bookingId': bookingId,
    'read': false,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

Future<void> sendHelperArrivingNotification({
  required String userId,
  required String helperName,
  required int minutesAway,
}) async {
  await FirebaseFirestore.instance
      .collection('notifications')
      .doc(userId)
      .collection('items')
      .add({
    'type': 'helper_arriving',
    'title': 'Helper Arriving Soon',
    'body': '$helperName is just $minutesAway mins away. Please be ready.',
    'read': false,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

Future<void> sendPaymentReceivedNotification({
  required String userId,
  required String amount,
  required String bookingId,
}) async {
  await FirebaseFirestore.instance
      .collection('notifications')
      .doc(userId)
      .collection('items')
      .add({
    'type': 'payment_received',
    'title': 'Payment Successful',
    'body':
    'Payment of Rs.$amount for Booking #$bookingId confirmed. Your invoice is ready.',
    'bookingId': bookingId,
    'read': false,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

Future<void> sendServiceCompletedNotification({
  required String userId,
  required String serviceName,
  required String bookingId,
}) async {
  await FirebaseFirestore.instance
      .collection('notifications')
      .doc(userId)
      .collection('items')
      .add({
    'type': 'service_completed',
    'title': 'Service Completed',
    'body': 'How was your experience with $serviceName?',
    'bookingId': bookingId,
    'rating': 0,
    'read': false,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

Future<void> sendOfferNotification({
  required String userId,
  required String title,
  required String body,
}) async {
  await FirebaseFirestore.instance
      .collection('notifications')
      .doc(userId)
      .collection('items')
      .add({
    'type': 'offer',
    'title': title,
    'body': body,
    'read': false,
    'createdAt': FieldValue.serverTimestamp(),
  });
}