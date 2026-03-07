// lib/service/realtime_db_service.dart
// ignore_for_file: avoid_print

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  REALTIME DATABASE SERVICE
//
//  RTDB tree:
//    messages/{chatId}/messages/{pushId}  — individual chat messages
//    chatMeta/{chatId}                    — last-message metadata
//    notifications/{userId}/{pushId}      — per-user notifications
//
//  Notification types:
//    booking_confirmed | helper_message | cancellation |
//    service_completed | review_request
// ═══════════════════════════════════════════════════════════════════════════════

class RealtimeDbService {
  RealtimeDbService._();
  static final RealtimeDbService instance = RealtimeDbService._();

  final FirebaseDatabase _db = FirebaseDatabase.instance;

  // ════════════════════════════════════════════════════════════════════════════
  //  CHAT MESSAGES
  // ════════════════════════════════════════════════════════════════════════════

  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String text,
    String type = 'text', // 'text' | 'booking_confirmed' | 'system'
  }) async {
    try {
      final msgRef = _db.ref('messages/$chatId/messages').push();
      await msgRef.set({
        'messageId': msgRef.key,
        'senderId': senderId,
        'senderName': senderName,
        'text': text,
        'type': type,
        'timestamp': ServerValue.timestamp,
      });
      // Mirror last-message to chatMeta so the messages-list screen can use it
      await _db.ref('chatMeta/$chatId').update({
        'lastMessage': text,
        'lastMessageTime': ServerValue.timestamp,
        'lastSenderId': senderId,
      });
    } catch (e) {
      debugPrint('RealtimeDbService.sendMessage error: $e');
    }
  }

  // ── Auto-sent when booking is created ────────────────────────────────────
  // "Hi [userName], I am your Sarthi for the service you booked on [date]
  //  at [time]. I will be there to assist you. Looking forward to helping you."

  Future<void> sendHelperAcknowledgement({
    required String chatId,
    required String helperId,
    required String helperName,
    required String userName,
    required String serviceDate,
    required String serviceTime,
  }) async {
    final text =
        'Hi $userName, I am your Sarthi for the service you booked on '
        '$serviceDate at $serviceTime. I will be there to assist you. '
        'Looking forward to helping you.';

    await sendMessage(
      chatId: chatId,
      senderId: helperId,
      senderName: helperName,
      text: text,
      type: 'booking_confirmed',
    );
  }

  // ── Real-time stream of messages ordered by timestamp ────────────────────

  Stream<List<Map<String, dynamic>>> messagesStream(String chatId) {
    return _db
        .ref('messages/$chatId/messages')
        .orderByChild('timestamp')
        .onValue
        .map((event) {
      final raw = event.snapshot.value;
      if (raw == null) return <Map<String, dynamic>>[];
      final map = Map<dynamic, dynamic>.from(raw as Map);
      final list = map.entries
          .map((e) => <String, dynamic>{
        '_key': e.key as String,
        ...Map<String, dynamic>.from(e.value as Map),
      })
          .toList()
        ..sort((a, b) {
          final ta = (a['timestamp'] as int?) ?? 0;
          final tb = (b['timestamp'] as int?) ?? 0;
          return ta.compareTo(tb);
        });
      return list;
    });
  }

  // ── Delete entire chat (called after user submits review) ─────────────────

  Future<void> deleteChat(String chatId) async {
    try {
      await _db.ref('messages/$chatId').remove();
      await _db.ref('chatMeta/$chatId').remove();
      debugPrint('RealtimeDbService: chat $chatId deleted ✓');
    } catch (e) {
      debugPrint('RealtimeDbService.deleteChat error: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  NOTIFICATIONS
  // ════════════════════════════════════════════════════════════════════════════

  Future<void> sendNotification({
    required String userId,
    required String type,
    required String title,
    required String body,
    String? bookingId,
  }) async {
    try {
      final ref = _db.ref('notifications/$userId').push();
      await ref.set({
        'notifId': ref.key,
        'type': type,
        'title': title,
        'body': body,
        if (bookingId != null) 'bookingId': bookingId,
        'read': false,
        'timestamp': ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint('RealtimeDbService.sendNotification error: $e');
    }
  }

  // ── Real-time notifications stream (newest first) ─────────────────────────

  Stream<List<Map<String, dynamic>>> notificationsStream(String userId) {
    return _db
        .ref('notifications/$userId')
        .orderByChild('timestamp')
        .onValue
        .map((event) {
      final raw = event.snapshot.value;
      if (raw == null) return <Map<String, dynamic>>[];
      final map = Map<dynamic, dynamic>.from(raw as Map);
      final list = map.entries
          .map((e) => <String, dynamic>{
        '_key': e.key as String,
        ...Map<String, dynamic>.from(e.value as Map),
      })
          .toList()
        ..sort((a, b) {
          final ta = (a['timestamp'] as int?) ?? 0;
          final tb = (b['timestamp'] as int?) ?? 0;
          return tb.compareTo(ta); // newest first
        });
      return list;
    });
  }

  Future<void> markNotificationRead(String userId, String notifKey) async {
    try {
      await _db
          .ref('notifications/$userId/$notifKey')
          .update({'read': true});
    } catch (e) {
      debugPrint('RealtimeDbService.markNotificationRead error: $e');
    }
  }

  Future<void> markAllNotificationsRead(String userId) async {
    try {
      final snap = await _db.ref('notifications/$userId').get();
      if (!snap.exists || snap.value == null) return;
      final data = Map<dynamic, dynamic>.from(snap.value as Map);
      final updates = <String, dynamic>{};
      for (final key in data.keys) {
        updates['notifications/$userId/$key/read'] = true;
      }
      if (updates.isNotEmpty) await _db.ref().update(updates);
    } catch (e) {
      debugPrint('RealtimeDbService.markAllNotificationsRead error: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  TYPED NOTIFICATION HELPERS  (5 event types)
  // ════════════════════════════════════════════════════════════════════════════

  // 1. Booking confirmed
  Future<void> notifyBookingConfirmed({
    required String userId,
    required String helperName,
    required String serviceName,
    required String bookingId,
  }) =>
      sendNotification(
        userId: userId,
        type: 'booking_confirmed',
        title: 'Booking Confirmed',
        body:
        'Your request for "$serviceName" has been accepted by $helperName.',
        bookingId: bookingId,
      );

  // 2. Helper sent a message
  Future<void> notifyHelperMessage({
    required String userId,
    required String helperName,
    required String messagePreview,
    String? bookingId,
  }) =>
      sendNotification(
        userId: userId,
        type: 'helper_message',
        title: 'Message from $helperName',
        body: messagePreview,
        bookingId: bookingId,
      );

  // 3. Booking was cancelled
  Future<void> notifyCancellation({
    required String userId,
    required String serviceName,
    required String bookingId,
  }) =>
      sendNotification(
        userId: userId,
        type: 'cancellation',
        title: 'Booking Cancelled',
        body: 'Your booking for "$serviceName" has been cancelled.',
        bookingId: bookingId,
      );

  // 4. Service completed — prompt to review
  Future<void> notifyServiceCompleted({
    required String userId,
    required String serviceName,
    required String bookingId,
  }) =>
      sendNotification(
        userId: userId,
        type: 'service_completed',
        title: 'Service Completed! 🎉',
        body:
        'Your "$serviceName" service is done. Please leave a review.',
        bookingId: bookingId,
      );

  // 5. Review request (sent to helper after user finishes review)
  Future<void> notifyReviewRequest({
    required String userId,
    required String helperName,
    required String bookingId,
  }) =>
      sendNotification(
        userId: userId,
        type: 'review_request',
        title: 'Rate Your Experience',
        body:
        'How was your experience with $helperName? Share your feedback.',
        bookingId: bookingId,
      );
}