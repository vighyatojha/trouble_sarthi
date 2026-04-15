// lib/screens/services_screen.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../service/realtime_db_service.dart';
import '../screens/chat_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GLOBAL NOTIFICATION COUNT — used by home_screen.dart bottom nav dot badge
// ─────────────────────────────────────────────────────────────────────────────

class NotificationCountNotifier extends ValueNotifier<int> {
  NotificationCountNotifier._() : super(0);
  static final instance = NotificationCountNotifier._();
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVITY SCREEN
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
// HEADER
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(28),
                ),
                padding: const EdgeInsets.all(4),
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
// MESSAGES TAB  (Firestore — unchanged, already works)
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
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF7C3AED), strokeWidth: 2.5));
        }
        if (snap.hasError) {
          return const _EmptyState(
            icon: Icons.chat_bubble_outline_rounded,
            message:
            'No messages yet\nConversations with helpers will appear here',
          );
        }

        final docs = snap.data?.docs ?? [];
        final sorted = [...docs]..sort((a, b) {
          final aTs =
          (a.data() as Map<String, dynamic>)['lastMessageTime']
          as Timestamp?;
          final bTs =
          (b.data() as Map<String, dynamic>)['lastMessageTime']
          as Timestamp?;
          if (aTs == null && bTs == null) return 0;
          if (aTs == null) return 1;
          if (bTs == null) return -1;
          return bTs.compareTo(aTs);
        });

        if (sorted.isEmpty) {
          return const _EmptyState(
            icon: Icons.chat_bubble_outline_rounded,
            message:
            'No messages yet\nConversations with helpers will appear here',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 130),
          itemCount: sorted.length,
          separatorBuilder: (_, __) => const Divider(
              height: 1, indent: 72, color: Color(0xFFF0EEF8)),
          itemBuilder: (_, i) => _ConversationTile(
            doc: sorted[i],
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

    final bookingStatus = data['bookingStatus'] as String? ?? 'active';
    final isCompleted = bookingStatus == 'completed';
    final isCancelled = bookingStatus == 'cancelled';
    final isInactive = isCompleted || isCancelled;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: doc.id,
              helperName: data['otherName'] as String? ?? 'Helper',
              helperId: data['helperId'] as String? ?? '',
              helperPhoto: data['helperPhoto'] as String?,
              bookingId: data['bookingId'] as String?,
              serviceName: data['serviceName'] as String?,
              bookingStatus: bookingStatus,
            ),
          ),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Stack(
              children: [
                Opacity(
                  opacity: isInactive ? 0.55 : 1.0,
                  child: Container(
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
                          image: NetworkImage(photoUrl),
                          fit: BoxFit.cover)
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
                ),
                if (isOnline && !isInactive)
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
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                otherName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: unread > 0
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  color: isInactive
                                      ? const Color(0xFF9CA3AF)
                                      : const Color(0xFF1F2937),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (isCompleted)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD1FAE5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('Completed',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF065F46))),
                              )
                            else if (isCancelled)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('Cancelled',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF991B1B))),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 12,
                          color: unread > 0
                              ? const Color(0xFF7C3AED)
                              : const Color(0xFF9CA3AF),
                          fontWeight: unread > 0
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isCompleted
                              ? 'Service completed — chat closed'
                              : isCancelled
                              ? 'Booking cancelled — chat closed'
                              : lastMsg,
                          style: TextStyle(
                            fontSize: 13,
                            color: isInactive
                                ? const Color(0xFFB0B8CC)
                                : unread > 0
                                ? const Color(0xFF374151)
                                : const Color(0xFF9CA3AF),
                            fontWeight:
                            unread > 0 && !isInactive
                                ? FontWeight.w500
                                : FontWeight.normal,
                            fontStyle: isInactive
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unread > 0 && !isInactive) ...[
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
// NOTIFICATIONS TAB — ✅ FIXED: reads from Realtime Database (not Firestore)
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationsTab extends StatefulWidget {
  const _NotificationsTab();

  @override
  State<_NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<_NotificationsTab> {
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DatabaseReference? get _ref => _uid == null
      ? null
      : FirebaseDatabase.instance.ref('notifications/$_uid');

  Future<void> _markAllRead(List<Map<String, dynamic>> items) async {
    if (_uid == null || _ref == null) return;
    final updates = <String, dynamic>{};
    for (final item in items) {
      if (item['read'] != true) {
        updates['${item['_key']}/read'] = true;
      }
    }
    if (updates.isNotEmpty) await _ref!.update(updates);
  }

  Future<void> _deleteNotification(String key) async {
    try {
      await _ref?.child(key).remove();
    } catch (_) {}
  }

  Future<void> _clearAll(List<Map<String, dynamic>> items) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear all?'),
        content: const Text('All notifications will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Clear All',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _ref?.remove();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    if (uid == null) {
      return const _EmptyState(
          icon: Icons.notifications_none_rounded,
          message: 'Sign in to view notifications');
    }

    // ✅ Use RealtimeDbService stream — matches where notifications are written
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: RealtimeDbService.instance.notificationsStream(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF7C3AED), strokeWidth: 2.5));
        }

        final items = snap.data ?? [];

        // Update global unread count badge
        final unreadCount = items.where((i) => i['read'] != true).length;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationCountNotifier.instance.value = unreadCount;
        });

        if (items.isEmpty) {
          return const _EmptyState(
            icon: Icons.notifications_none_rounded,
            message:
            'No notifications yet\nBooking confirmations & updates will appear here',
          );
        }

        // Group into Today / Yesterday / Earlier
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final yesterdayStart =
        todayStart.subtract(const Duration(days: 1));

        final today = <Map<String, dynamic>>[];
        final yesterday = <Map<String, dynamic>>[];
        final earlier = <Map<String, dynamic>>[];

        for (final item in items) {
          final ts = item['timestamp'] as int?;
          if (ts == null) continue;
          final dt = DateTime.fromMillisecondsSinceEpoch(ts);
          if (!dt.isBefore(todayStart)) {
            today.add(item);
          } else if (!dt.isBefore(yesterdayStart)) {
            yesterday.add(item);
          } else {
            earlier.add(item);
          }
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 130),
          children: [
            // ── Header row with clear button ────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (unreadCount > 0)
                  GestureDetector(
                    onTap: () => _markAllRead(items),
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
                  )
                else
                  const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => _clearAll(items),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'Clear all',
                      style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),

            if (today.isNotEmpty) ...[
              _SectionLabel('TODAY'),
              ...today.map((item) => _RtdbNotifCard(
                item: item,
                onDelete: () =>
                    _deleteNotification(item['_key'] as String),
                onMarkRead: () async {
                  if (item['read'] != true) {
                    await _ref
                        ?.child(item['_key'] as String)
                        .update({'read': true});
                  }
                },
              )),
            ],
            if (yesterday.isNotEmpty) ...[
              _SectionLabel('YESTERDAY'),
              ...yesterday.map((item) => _RtdbNotifCard(
                item: item,
                onDelete: () =>
                    _deleteNotification(item['_key'] as String),
                onMarkRead: () async {
                  if (item['read'] != true) {
                    await _ref
                        ?.child(item['_key'] as String)
                        .update({'read': true});
                  }
                },
              )),
            ],
            if (earlier.isNotEmpty) ...[
              _SectionLabel('EARLIER'),
              ...earlier.map((item) => _RtdbNotifCard(
                item: item,
                onDelete: () =>
                    _deleteNotification(item['_key'] as String),
                onMarkRead: () async {
                  if (item['read'] != true) {
                    await _ref
                        ?.child(item['_key'] as String)
                        .update({'read': true});
                  }
                },
              )),
            ],
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RTDB NOTIFICATION CARD
// ─────────────────────────────────────────────────────────────────────────────

class _RtdbNotifCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onDelete;
  final VoidCallback onMarkRead;

  const _RtdbNotifCard({
    required this.item,
    required this.onDelete,
    required this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    final type = (item['type'] as String?) ?? 'general';
    final title = (item['title'] as String?) ?? _defaultTitle(type);
    final body = (item['body'] as String?) ?? '';
    final read = (item['read'] as bool?) ?? false;
    final ts = item['timestamp'] as int?;
    final dt = ts != null
        ? DateTime.fromMillisecondsSinceEpoch(ts)
        : null;
    final timeStr = dt != null ? _relTime(dt) : '';
    final (icon, color) = _typeInfo(type);

    return Dismissible(
      key: ValueKey(item['_key']),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFDC2626),
          borderRadius: BorderRadius.circular(18),
        ),
        child:
        const Icon(Icons.delete_rounded, color: Colors.white, size: 22),
      ),
      child: GestureDetector(
        onTap: onMarkRead,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: read ? Colors.white : const Color(0xFFFAF8FF),
            borderRadius: BorderRadius.circular(18),
            border: read
                ? Border.all(color: const Color(0xFFF0F0F5))
                : Border.all(color: color.withOpacity(0.18)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
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
                            if (!read) ...[
                              const SizedBox(height: 4),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(body,
                          style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                              height: 1.45)),
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

  String _defaultTitle(String type) {
    switch (type) {
      case 'booking_confirmed':  return 'Booking Confirmed';
      case 'helper_message':     return 'New Message';
      case 'service_completed':  return 'Service Completed 🎉';
      case 'cancellation':       return 'Booking Cancelled';
      case 'review_request':     return 'Rate Your Experience';
      case 'payment':            return 'Payment Received';
      default:                   return 'Notification';
    }
  }

  (IconData, Color) _typeInfo(String type) {
    switch (type) {
      case 'booking_confirmed':  return (Icons.check_circle_rounded,    const Color(0xFF7C3AED));
      case 'helper_message':     return (Icons.chat_bubble_rounded,     const Color(0xFF0891B2));
      case 'service_completed':  return (Icons.verified_rounded,        const Color(0xFF059669));
      case 'cancellation':       return (Icons.cancel_rounded,          const Color(0xFFDC2626));
      case 'review_request':     return (Icons.star_rounded,            const Color(0xFFD97706));
      case 'payment':            return (Icons.wallet_rounded,          const Color(0xFFD97706));
      default:                   return (Icons.notifications_rounded,   const Color(0xFF7C3AED));
    }
  }

  String _relTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    if (diff.inDays == 1)    return '1d ago';
    return '${diff.inDays}d ago';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION LABEL
// ─────────────────────────────────────────────────────────────────────────────

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
              decoration: const BoxDecoration(
                  color: Color(0xFFEDE9FE), shape: BoxShape.circle),
              child: Icon(icon, size: 36, color: const Color(0xFF7C3AED)),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF9CA3AF),
                  height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}