// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../service/realtime_db_service.dart';
import '../screens/chat_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GLOBAL NOTIFICATION COUNT
// ─────────────────────────────────────────────────────────────────────────────

class NotificationCountNotifier extends ValueNotifier<int> {
  NotificationCountNotifier._() : super(0);
  static final instance = NotificationCountNotifier._();
}

// ─────────────────────────────────────────────────────────────────────────────
// MERGED CHAT  — deduplicates two Firestore docs for the same booking
// ─────────────────────────────────────────────────────────────────────────────

class _MergedChat {
  /// The chatId that actually has messages in Realtime DB (use for navigation)
  final String chatId;

  /// All Firestore doc IDs that belong to this chat (needed for bulk-delete)
  final Set<String> allDocIds;

  /// Merged display fields (otherName/photo from whichever doc has them,
  /// lastMessage/lastMessageTime from the active doc)
  final Map<String, dynamic> data;

  const _MergedChat({
    required this.chatId,
    required this.allDocIds,
    required this.data,
  });

  factory _MergedChat.fromDoc(QueryDocumentSnapshot doc) => _MergedChat(
    chatId: doc.id,
    allDocIds: {doc.id},
    data: Map<String, dynamic>.from(doc.data() as Map),
  );

  _MergedChat mergeWith(QueryDocumentSnapshot other) {
    final otherData = other.data() as Map<String, dynamic>;
    final myMsg    = data['lastMessage']    as String?    ?? '';
    final otherMsg = otherData['lastMessage'] as String?  ?? '';
    final myTs     = data['lastMessageTime']    as Timestamp?;
    final otherTs  = otherData['lastMessageTime'] as Timestamp?;

    // "Active" chatId = whichever doc has messages (or is more recent)
    String activeChatId = chatId;
    if (myMsg.isEmpty && otherMsg.isNotEmpty) {
      activeChatId = other.id;
    } else if (myMsg.isNotEmpty && otherMsg.isNotEmpty) {
      if (otherTs != null &&
          (myTs == null || otherTs.compareTo(myTs) > 0)) {
        activeChatId = other.id;
      }
    }

    // Merge display fields — prefer non-empty values
    final merged = Map<String, dynamic>.from(data);
    for (final entry in otherData.entries) {
      final existing = merged[entry.key];
      if (existing == null ||
          (existing is String && existing.isEmpty) ||
          existing == false) {
        merged[entry.key] = entry.value;
      }
    }

    // Always show the active doc's lastMessage / timestamp
    if (activeChatId == other.id) {
      if (otherMsg.isNotEmpty) merged['lastMessage'] = otherMsg;
      if (otherTs != null)     merged['lastMessageTime'] = otherTs;
    } else {
      if (myMsg.isNotEmpty) merged['lastMessage'] = myMsg;
      if (myTs != null)     merged['lastMessageTime'] = myTs;
    }

    return _MergedChat(
      chatId: activeChatId,
      allDocIds: {...allDocIds, other.id},
      data: merged,
    );
  }
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
          colors: [Color(0xFF1E0640), Color(0xFF3B0764), Color(0xFF5B21B6)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 20, 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 18),
                    splashRadius: 22,
                  ),
                  const Text(
                    'Activity',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.search_rounded,
                        color: Colors.white, size: 18),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(26),
                ),
                padding: const EdgeInsets.all(3),
                child: TabBar(
                  controller: tabController,
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
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
                      fontWeight: FontWeight.bold, fontSize: 12.5),
                  unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 12.5),
                  tabs: const [
                    Tab(text: 'Messages'),
                    Tab(text: 'Notifications'),
                  ],
                ),
              ),
            ),
            Container(
              height: 24,
              margin: const EdgeInsets.only(top: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFF4F6FB),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(26),
                  topRight: Radius.circular(26),
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

class _MessagesTab extends StatefulWidget {
  const _MessagesTab();

  @override
  State<_MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<_MessagesTab> {
  // Selection tracks by merged chatId (the active one)
  final Set<String> _selected = {};
  bool get _isSelecting => _selected.isNotEmpty;

  void _toggleSelect(String chatId) {
    setState(() {
      if (_selected.contains(chatId)) {
        _selected.remove(chatId);
      } else {
        _selected.add(chatId);
      }
    });
  }

  void _clearSelection() => setState(() => _selected.clear());

  Future<void> _deleteSelected(List<_MergedChat> mergedChats) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Chats',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Text(
          'Delete ${_selected.length} conversation${_selected.length > 1 ? 's' : ''}? This cannot be undone.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete',
                style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Collect ALL Firestore doc IDs for each selected merged chat
    final allIdsToDelete = <String>{};
    for (final mc in mergedChats) {
      if (_selected.contains(mc.chatId)) {
        allIdsToDelete.addAll(mc.allDocIds);
      }
    }

    final batch = FirebaseFirestore.instance.batch();
    for (final id in allIdsToDelete) {
      batch.delete(FirebaseFirestore.instance.collection('chats').doc(id));
    }
    await batch.commit();
    _clearSelection();
  }

  // ── Deduplicate raw Firestore docs into merged chats ──────────────────────
  List<_MergedChat> _mergeChats(
      List<QueryDocumentSnapshot> sorted, String uid) {
    final Map<String, _MergedChat> byKey = {};

    for (final doc in sorted) {
      final data      = doc.data() as Map<String, dynamic>;
      final bookingId = data['bookingId'] as String? ?? '';
      final helperId  = data['helperId']  as String? ?? '';

      // Group key: bookingId > helperId > doc.id
      final key = bookingId.isNotEmpty
          ? bookingId
          : helperId.isNotEmpty
          ? helperId
          : doc.id;

      if (!byKey.containsKey(key)) {
        byKey[key] = _MergedChat.fromDoc(doc);
      } else {
        byKey[key] = byKey[key]!.mergeWith(doc);
      }
    }

    // Re-sort merged results by lastMessageTime descending
    final result = byKey.values.toList();
    result.sort((a, b) {
      final aTs = a.data['lastMessageTime'] as Timestamp?;
      final bTs = b.data['lastMessageTime'] as Timestamp?;
      if (aTs == null && bTs == null) return 0;
      if (aTs == null) return 1;
      if (bTs == null) return -1;
      return bTs.compareTo(aTs);
    });
    return result;
  }

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
                  color: Color(0xFF7C3AED), strokeWidth: 2));
        }

        if (snap.hasError) {
          return const _EmptyState(
            icon: Icons.chat_bubble_outline_rounded,
            message:
            'No messages yet\nConversations with helpers will appear here',
          );
        }

        final docs = snap.data?.docs ?? [];

        // Sort raw docs first
        final sorted = [...docs]..sort((a, b) {
          final aTs = (a.data() as Map)['lastMessageTime'] as Timestamp?;
          final bTs = (b.data() as Map)['lastMessageTime'] as Timestamp?;
          if (aTs == null && bTs == null) return 0;
          if (aTs == null) return 1;
          if (bTs == null) return -1;
          return bTs.compareTo(aTs);
        });

        // ── KEY FIX: merge duplicate docs for the same booking ────────────
        final mergedChats = _mergeChats(sorted, uid);

        if (mergedChats.isEmpty) {
          return const _EmptyState(
            icon: Icons.chat_bubble_outline_rounded,
            message:
            'No messages yet\nConversations with helpers will appear here',
          );
        }

        return Column(
          children: [
            // ── Selection action bar ──────────────────────────────────
            if (_isSelecting)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E0640),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _clearSelection,
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${_selected.length} selected',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _deleteSelected(mergedChats),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete_outline_rounded,
                                color: Colors.white, size: 14),
                            SizedBox(width: 5),
                            Text('Delete',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Conversation list ──────────────────────────────────────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 130),
                itemCount: mergedChats.length,
                itemBuilder: (_, i) {
                  final mc         = mergedChats[i];
                  final isSelected = _selected.contains(mc.chatId);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ConversationCard(
                      mergedChat:  mc,
                      currentUid:  uid,
                      isSelected:  isSelected,
                      isSelecting: _isSelecting,
                      onTap: () {
                        if (_isSelecting) {
                          _toggleSelect(mc.chatId);
                        } else {
                          final data          = mc.data;
                          final bookingStatus =
                              data['bookingStatus'] as String? ?? 'active';
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                // ✅ Always use the active chatId
                                chatId:       mc.chatId,
                                helperName:
                                data['otherName'] as String? ?? 'Helper',
                                helperId:
                                data['helperId'] as String? ?? '',
                                helperPhoto:
                                data['helperPhoto'] as String?,
                                bookingId:
                                data['bookingId'] as String?,
                                serviceName:
                                data['serviceName'] as String?,
                                bookingStatus: bookingStatus,
                              ),
                            ),
                          );
                        }
                      },
                      onLongPress: () => _toggleSelect(mc.chatId),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONVERSATION CARD  — now uses _MergedChat
// ─────────────────────────────────────────────────────────────────────────────

class _ConversationCard extends StatelessWidget {
  final _MergedChat  mergedChat;
  final String       currentUid;
  final bool         isSelected;
  final bool         isSelecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ConversationCard({
    required this.mergedChat,
    required this.currentUid,
    required this.isSelected,
    required this.isSelecting,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final data          = mergedChat.data;
    final helperName    = data['otherName']    as String? ?? 'Helper';
    final serviceName   = data['serviceName']  as String? ?? '';
    final lastMsg       = data['lastMessage']  as String? ?? '';
    final unread        = (data['unreadCount_$currentUid'] as int?) ?? 0;
    final isOnline      = data['helperOnline'] as bool?   ?? false;
    final photoUrl      = data['helperPhoto']  as String? ?? '';
    final ts            = data['lastMessageTime'] as Timestamp?;
    final timeStr       = ts != null ? _fmtTime(ts.toDate()) : '';
    final initial       = helperName.isNotEmpty ? helperName[0].toUpperCase() : 'H';
    final bookingStatus = data['bookingStatus'] as String? ?? 'active';
    final isCompleted   = bookingStatus == 'completed';
    final isCancelled   = bookingStatus == 'cancelled';
    final isInactive    = isCompleted || isCancelled;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEDE9FE) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? const Color(0xFF7C3AED) : Colors.transparent,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? []
              : [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Select checkbox ─────────────────────────────────────
              if (isSelecting)
                Padding(
                  padding: const EdgeInsets.only(right: 10, top: 4),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF7C3AED)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF7C3AED)
                            : const Color(0xFFD1D5DB),
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 13)
                        : null,
                  ),
                ),

              // ── Avatar ──────────────────────────────────────────────
              Stack(
                children: [
                  Opacity(
                    opacity: isInactive ? 0.5 : 1.0,
                    child: Container(
                      width: 48,
                      height: 48,
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
                                  fontSize: 18)))
                          : null,
                    ),
                  ),
                  if (isOnline && !isInactive)
                    Positioned(
                      right: 1,
                      bottom: 1,
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
              const SizedBox(width: 12),

              // ── Content ─────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            helperName,
                            style: TextStyle(
                              fontSize: 13.5,
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
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 11,
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

                    if (serviceName.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: isInactive
                                  ? const Color(0xFFF3F4F6)
                                  : const Color(0xFFEDE9FE),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.build_circle_outlined,
                                  size: 10,
                                  color: isInactive
                                      ? const Color(0xFF9CA3AF)
                                      : const Color(0xFF7C3AED),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  serviceName,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isInactive
                                        ? const Color(0xFF9CA3AF)
                                        : const Color(0xFF7C3AED),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (isCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD1FAE5),
                                borderRadius: BorderRadius.circular(6),
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
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('Cancelled',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF991B1B))),
                            ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 5),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isCompleted
                                ? 'Service completed — chat closed'
                                : isCancelled
                                ? 'Booking cancelled — chat closed'
                                : lastMsg.isEmpty
                                ? 'No messages yet'
                                : lastMsg,
                            style: TextStyle(
                              fontSize: 12,
                              color: isInactive
                                  ? const Color(0xFFB0B8CC)
                                  : unread > 0
                                  ? const Color(0xFF374151)
                                  : const Color(0xFF9CA3AF),
                              fontWeight: unread > 0 && !isInactive
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
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              unread > 9 ? '9+' : '$unread',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
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
      ),
    );
  }

  String _fmtTime(DateTime dt) {
    final now  = DateTime.now();
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
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF7C3AED), strokeWidth: 2));
        }

        final docs = snap.data?.docs ?? [];
        final unreadCount =
            docs.where((d) => (d.data() as Map)['read'] != true).length;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationCountNotifier.instance.value = unreadCount;
        });

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

    if (type == 'offer') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GestureDetector(
          onTap: markRead,
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
        onTap: markRead,
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