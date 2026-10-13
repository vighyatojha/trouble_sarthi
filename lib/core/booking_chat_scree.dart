// lib/core/booking_chat_screen.dart
// One chat per booking: chats/{bookingId}/messages in Firestore.
// Only the customer and helper on the booking can read or write; the chat is
// open while the booking is active and for 7 days after completion
// (firestore.rules enforces this). IDENTICAL in both apps.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'job_api.dart';
import 'job_models.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime? createdAt;
  const ChatMessage(this.id, this.senderId, this.text, this.createdAt);
}

class BookingChatService {
  BookingChatService._();
  static final BookingChatService instance = BookingChatService._();
  final _db = FirebaseFirestore.instance;

  Stream<List<ChatMessage>> messages(String bookingId) => _db
      .collection('chats')
      .doc(bookingId)
      .collection('messages')
      .orderBy('createdAt')
      .limitToLast(300)
      .snapshots()
      .map((s) => s.docs
      .map((d) => ChatMessage(
    d.id,
    '${d.data()['senderId'] ?? ''}',
    '${d.data()['text'] ?? ''}',
    (d.data()['createdAt'] as Timestamp?)?.toDate(),
  ))
      .toList());

  Future<void> send({
    required String bookingId,
    required String text,
    required String senderName,
    required String role, // 'customer' | 'helper'
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final chat = _db.collection('chats').doc(bookingId);
    await chat.collection('messages').add({
      'senderId': uid,
      'senderName': senderName.length > 80 ? senderName.substring(0, 80) : senderName,
      'senderRole': role,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
    try {
      await chat.update({
        'lastMessage': text.length > 120 ? '${text.substring(0, 120)}…' : text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderId': uid,
      });
    } catch (_) {}
  }
}

class BookingChatScreen extends StatefulWidget {
  final String bookingId;
  final String otherName;
  final String myName;
  final String myRole; // 'customer' | 'helper'
  final String subtitle;
  final Color accent;

  const BookingChatScreen({
    super.key,
    required this.bookingId,
    required this.otherName,
    required this.myName,
    required this.myRole,
    this.subtitle = '',
    this.accent = const Color(0xFF7C3AED),
  });

  @override
  State<BookingChatScreen> createState() => _BookingChatScreenState();
}

class _BookingChatScreenState extends State<BookingChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  int _lastCount = 0;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await BookingChatService.instance.send(
        bookingId: widget.bookingId,
        text: text.length > 2000 ? text.substring(0, 2000) : text,
        senderName: widget.myName,
        role: widget.myRole,
      );
      _ctrl.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Message not sent. The chat may be closed, or you are offline.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _autoScroll(int count) {
    if (count == _lastCount) return;
    _lastCount = count;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0.5,
        titleSpacing: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.otherName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          if (widget.subtitle.isNotEmpty)
            Text(widget.subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: BookingChatService.instance.messages(widget.bookingId),
            builder: (context, snap) {
              if (snap.hasError) {
                return const _ChatNotice(icon: Icons.lock_outline, text: 'This chat is not available.');
              }
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final msgs = snap.data!;
              _autoScroll(msgs.length);
              if (msgs.isEmpty) {
                return const _ChatNotice(
                  icon: Icons.chat_bubble_outline,
                  text: 'Say hello and share any details about the work.\n'
                      'For your safety, keep plans and payment details in this chat.',
                );
              }
              return ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                itemCount: msgs.length,
                itemBuilder: (_, i) {
                  final m = msgs[i];
                  final showDay = i == 0 || !_sameDay(msgs[i - 1].createdAt, m.createdAt);
                  return Column(children: [
                    if (showDay) _DayChip(at: m.createdAt),
                    _Bubble(message: m, mine: m.senderId == _uid, accent: widget.accent),
                  ]);
                },
              );
            },
          ),
        ),
        StreamBuilder<Booking?>(
          stream: JobApi.instance.booking(widget.bookingId),
          builder: (context, snap) {
            final open = snap.data?.chatOpen ?? true;
            if (!open) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                color: Colors.white,
                child: const Text('This chat is closed.',
                    textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF6B7280))),
              );
            }
            return SafeArea(
              top: false,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 2000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: 'Type a message',
                        filled: true,
                        fillColor: const Color(0xFFF3F4F6),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: widget.accent),
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded, color: Colors.white),
                  ),
                ]),
              ),
            );
          },
        ),
      ]),
    );
  }

  static bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return true;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  final Color accent;
  const _Bubble({required this.message, required this.mine, required this.accent});

  @override
  Widget build(BuildContext context) {
    final time = message.createdAt == null ? 'sending…' : DateFormat('h:mm a').format(message.createdAt!);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: mine ? accent : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
          boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 1))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(message.text,
                style: TextStyle(color: mine ? Colors.white : const Color(0xFF111827), fontSize: 15)),
          ),
          const SizedBox(height: 2),
          Text(time, style: TextStyle(fontSize: 10.5, color: mine ? Colors.white70 : const Color(0xFF9CA3AF))),
        ]),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final DateTime? at;
  const _DayChip({required this.at});
  @override
  Widget build(BuildContext context) {
    if (at == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final label = (at!.year == now.year && at!.month == now.month && at!.day == now.day)
        ? 'Today'
        : DateFormat('d MMM yyyy').format(at!);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(10)),
        child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563))),
      ),
    );
  }
}

class _ChatNotice extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ChatNotice({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 40, color: const Color(0xFF9CA3AF)),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B7280))),
      ]),
    ),
  );
}