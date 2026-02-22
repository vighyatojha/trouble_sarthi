// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GLOBAL NOTIFICATION COUNT — used by home_screen.dart bottom nav dot badge
// Import this and listen to NotificationCountNotifier.instance in _NavItem
// ─────────────────────────────────────────────────────────────────────────────

class NotificationCountNotifier extends ValueNotifier<int> {
  NotificationCountNotifier._() : super(0);
  static final instance = NotificationCountNotifier._();
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVITY SCREEN — replaces ServicesScreen in HomeScreen._screens[1]
// ─────────────────────────────────────────────────────────────────────────────

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: Column(
        children: [
          _ActivityHeader(tabController: _tab),
          Expanded(
            child: TabBarView(
              controller: _tab,
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                _MessagesTab(),
                _NotificationsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER — gradient + segmented tab bar with improved spacing & inner margin
// ─────────────────────────────────────────────────────────────────────────────

class _ActivityHeader extends StatelessWidget {
  final TabController tabController;
  const _ActivityHeader({required this.tabController});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E0640),
            Color(0xFF3B0764),
            Color(0xFF5B21B6),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Title + Search
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              child: Row(
                children: [
                  const Text(
                    'Activity',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.search_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),

            // Segmented control with visible margin around selected pill
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(28),
                ),
                padding: const EdgeInsets.all(4),           // ← creates margin inside
                child: TabBar(
                  controller: tabController,
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  indicatorPadding: EdgeInsets.zero,
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: const Color(0xFF7C3AED),
                  unselectedLabelColor: Colors.white.withOpacity(0.70),
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13.5,
                  ),
                  tabs: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Tab(text: 'Messages'),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Tab(text: 'Notifications'),
                    ),
                  ],
                ),
              ),
            ),

            // Curved bottom transition into body
            Container(
              height: 26,
              margin: const EdgeInsets.only(top: 12),
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
// MESSAGES TAB
// ─────────────────────────────────────────────────────────────────────────────

class _MessagesTab extends StatelessWidget {
  const _MessagesTab();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const _EmptyState(
          icon: Icons.chat_bubble_outline_rounded,
          message: 'Sign in to view messages');
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: uid)
          .orderBy('lastMessageTime', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF7C3AED), strokeWidth: 2.5));
        }

        final docs = snap.data?.docs ?? [];

        if (docs.isEmpty) {
          return const _EmptyState(
            icon: Icons.chat_bubble_outline_rounded,
            message:
            'No messages yet\nConversations with helpers will appear here',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 130),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(
              height: 1, indent: 72, color: Color(0xFFF0EEF8)),
          itemBuilder: (_, i) => _ConversationTile(
            doc: docs[i],
            currentUid: uid,
          ),
        );
      },
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final String currentUid;
  const _ConversationTile({required this.doc, required this.currentUid});

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final otherName = data['otherName'] as String? ?? 'Helper';
    final lastMsg = data['lastMessage'] as String? ?? '';
    final unread = (data['unreadCount_$currentUid'] as int?) ?? 0;
    final isOnline = data['helperOnline'] as bool? ?? false;
    final photoUrl = data['helperPhoto'] as String? ?? '';
    final ts = data['lastMessageTime'] as Timestamp?;
    final timeStr = ts != null ? _fmtTime(ts.toDate()) : '';
    final initial = otherName.isNotEmpty ? otherName[0].toUpperCase() : 'H';

    return GestureDetector(
      onTap: () {
        // TODO: push ChatScreen(chatId: doc.id)
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFA78BFA), Color(0xFF7C3AED)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    image: photoUrl.isNotEmpty
                        ? DecorationImage(
                        image: NetworkImage(photoUrl), fit: BoxFit.cover)
                        : null,
                  ),
                  child: photoUrl.isEmpty
                      ? Center(
                      child: Text(initial,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20)))
                      : null,
                ),
                if (isOnline)
                  Positioned(
                    right: 1,
                    bottom: 1,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
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
                          otherName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                            unread > 0 ? FontWeight.bold : FontWeight.w600,
                            color: const Color(0xFF1F2937),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 12,
                          color: unread > 0
                              ? const Color(0xFF7C3AED)
                              : const Color(0xFF9CA3AF),
                          fontWeight:
                          unread > 0 ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMsg,
                          style: TextStyle(
                            fontSize: 13,
                            color: unread > 0
                                ? const Color(0xFF374151)
                                : const Color(0xFF9CA3AF),
                            fontWeight:
                            unread > 0 ? FontWeight.w500 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unread > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            unread > 9 ? '9+' : '$unread',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${dt.day}/${dt.month}';
    }
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
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF7C3AED), strokeWidth: 2.5));
        }

        final docs = snap.data?.docs ?? [];

        // Update global unread badge count
        final unreadCount =
            docs.where((d) => (d.data() as Map)['read'] != true).length;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationCountNotifier.instance.value = unreadCount;
        });

        if (docs.isEmpty) {
          return const _EmptyState(
            icon: Icons.notifications_none_rounded,
            message:
            'No notifications yet\nBooking confirmations & updates will appear here',
          );
        }

        // Group: today / yesterday / earlier
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final yesterdayStart = todayStart.subtract(const Duration(days: 1));

        final today = <QueryDocumentSnapshot>[];
        final yesterday = <QueryDocumentSnapshot>[];
        final earlier = <QueryDocumentSnapshot>[];

        for (final doc in docs) {
          final ts =
          (doc.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
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
            // Mark all as read
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
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: 10),

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
      padding: const EdgeInsets.fromLTRB(2, 8, 0, 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
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
    final data = doc.data() as Map<String, dynamic>;
    final type = data['type'] as String? ?? 'system';
    final title = data['title'] as String? ?? '';
    final body = data['body'] as String? ?? '';
    final isRead = data['read'] as bool? ?? false;
    final ts = data['createdAt'] as Timestamp?;
    final timeStr = ts != null ? _relTime(ts.toDate()) : '';

    void markRead() {
      if (!isRead) doc.reference.update({'read': true});
    }

    // Offer type
    if (type == 'offer') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GestureDetector(
          onTap: markRead,
          child: Container(
            decoration: BoxDecoration(
              color: isRead ? const Color(0xFFF0EEFF) : const Color(0xFFEDE9FE),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFF7C3AED)
                      .withOpacity(isRead ? 0.08 : 0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withOpacity(0.10),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: const Color(0xFF7C3AED).withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 2))
                          ],
                        ),
                        child: const Icon(Icons.local_offer_rounded,
                            color: Color(0xFF7C3AED), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
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
                            const SizedBox(height: 4),
                            Text(title,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1F2937))),
                          ],
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: Color(0xFF7C3AED),
                              shape: BoxShape.circle),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(body,
                          style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF374151),
                              height: 1.5)),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: markRead,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Color(0xFF7C3AED), width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text('CLAIM OFFER NOW',
                            style: TextStyle(
                                color: Color(0xFF7C3AED),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
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

    // Service completed / rating
    if (type == 'service_completed') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _RatingCard(
            doc: doc, data: data, timeStr: timeStr, isRead: isRead),
      );
    }

    // Default / standard notification
    final cfg = _cfg(type);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: markRead,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isRead ? Colors.white : const Color(0xFFFAF8FF),
            borderRadius: BorderRadius.circular(18),
            border: isRead
                ? Border.all(color: const Color(0xFFF0F0F5))
                : Border.all(color: cfg.color.withOpacity(0.18)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: cfg.color.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(cfg.icon, color: cfg.color, size: 22),
                  ),
                  const SizedBox(width: 12),
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
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1F2937))),
                            ),
                            const SizedBox(width: 6),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(timeStr,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF9CA3AF))),
                                if (!isRead) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                        color: cfg.color,
                                        shape: BoxShape.circle),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(body,
                            style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6B7280),
                                height: 1.45)),
                      ],
                    ),
                  ),
                ],
              ),
              if (cfg.actionLabel != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [cfg.color, cfg.color.withOpacity(0.75)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: cfg.color.withOpacity(0.28),
                            blurRadius: 8,
                            offset: const Offset(0, 3))
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(cfg.actionIcon, color: Colors.white, size: 14),
                        const SizedBox(width: 5),
                        Text(cfg.actionLabel!,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
              if (type == 'payment_received') ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long_rounded,
                          size: 14, color: Color(0xFF6B7280)),
                      SizedBox(width: 5),
                      Text('Receipt',
                          style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF374151),
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
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
  final Color color;
  final String? actionLabel;
  final IconData actionIcon;
  const _Cfg(this.icon, this.color,
      [this.actionLabel, this.actionIcon = Icons.arrow_forward_rounded]);
}

// ─────────────────────────────────────────────────────────────────────────────
// RATING CARD
// ─────────────────────────────────────────────────────────────────────────────

class _RatingCard extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  final Map<String, dynamic> data;
  final String timeStr;
  final bool isRead;
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
    final body = widget.data['body'] as String? ?? '';
    final rated = _rating > 0;

    return GestureDetector(
      onTap: () {
        if (!widget.isRead) widget.doc.reference.update({'read': true});
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: widget.isRead ? Colors.white : const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: widget.isRead
                  ? const Color(0xFFF0F0F5)
                  : const Color(0xFFD97706).withOpacity(0.20)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.star_rounded,
                      color: Color(0xFFD97706), size: 24),
                ),
                const SizedBox(width: 12),
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
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1F2937))),
                          ),
                          Text(widget.timeStr,
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF9CA3AF))),
                          if (!widget.isRead) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                  color: Color(0xFFD97706),
                                  shape: BoxShape.circle),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(body,
                          style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                              height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
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
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Icon(
                      Icons.star_rounded,
                      size: 32,
                      color:
                      filled ? const Color(0xFFD97706) : const Color(0xFFD1D5DB),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                rated ? 'Thanks for rating!' : 'Tap to rate',
                style: TextStyle(
                  fontSize: 12,
                  color: rated ? const Color(0xFF059669) : const Color(0xFF9CA3AF),
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
  final String message;
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
              width: 80,
              height: 80,
              decoration:
              const BoxDecoration(color: Color(0xFFEDE9FE), shape: BoxShape.circle),
              child: Icon(icon, size: 36, color: const Color(0xFF7C3AED)),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF9CA3AF), height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FIRESTORE HELPER FUNCTIONS (Notification creators)
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
    'body': 'Your request for "$serviceName" has been accepted by $helperName.',
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
    'Payment of ₹$amount for Booking #$bookingId confirmed. Your invoice is ready.',
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