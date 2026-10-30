import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/booking_chat_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BACKGROUND HANDLER — must be top-level, outside any class
// ─────────────────────────────────────────────────────────────────────────────

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // OS handles showing the notification automatically in background/terminated.
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATION NAV NOTIFIER
// home_screen.dart listens to this and pushes BookingsScreen when it changes.
// ─────────────────────────────────────────────────────────────────────────────

class NotificationNavNotifier extends ValueNotifier<String?> {
  NotificationNavNotifier._() : super(null);
  static final instance = NotificationNavNotifier._();
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATION SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _fcm = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _androidChannel = AndroidNotificationChannel(
    'trouble_sarthi_channel',
    'Trouble Sarthi Alerts',
    description: 'Booking confirmations, helper updates & more',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    enableLights: true,
  );

  // Chat messages get their own channel so people can mute chats separately.
  // The id must match the Worker ("trouble_sarthi_chat").
  static const _chatChannel = AndroidNotificationChannel(
    'trouble_sarthi_chat',
    'Chat messages',
    description: 'Messages from your helper',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
    ledColor: Color(0xFF7C3AED),
    enableLights: true,
  );

  static const _brand = Color(0xFF7C3AED);
  static const _smallIcon = 'ic_notification';

  Future<void> init() async {
    // 1. Request permission
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 3. Show foreground notifications on iOS
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 4. Initialise flutter_local_notifications
    const androidSettings = AndroidInitializationSettings(_smallIcon);
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // 5. Create Android notification channel — KEY LINE (must be one line, no break inside <>)
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final android = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(_androidChannel);
      await android?.createNotificationChannel(_chatChannel);
    }

    // 6. Foreground FCM → show local banner
    FirebaseMessaging.onMessage.listen(_showForegroundBanner);

    // 7. Background → user taps notification
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // 8. Terminated → user taps notification to launch
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  Future<void> _showForegroundBanner(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    final data = message.data;
    final isChat = data['type'] == 'chat_message';
    final chatId = '${data['bookingId'] ?? ''}';

    // Already looking at this chat: the message is on screen, no banner.
    if (isChat && chatId.isNotEmpty && BookingChatScreen.openChatId == chatId) return;

    final channel = isChat ? _chatChannel : _androidChannel;
    final title = notification.title ?? 'Trouble Sarthi';
    final body = notification.body ?? '';

    await _localNotifications.show(
      // Same id for the same chat / booking → the new banner replaces the old one.
      (isChat ? 'chat_$chatId' : (data['bookingId'] ?? data['jobId'] ?? notification.hashCode)).hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: isChat ? Importance.high : Importance.max,
          priority: Priority.high,
          icon: _smallIcon,
          color: _brand,
          colorized: false,
          category: isChat ? AndroidNotificationCategory.message : AndroidNotificationCategory.status,
          groupKey: isChat ? 'trouble_sarthi_chats' : 'trouble_sarthi_updates',
          styleInformation: isChat
              ? MessagingStyleInformation(
            const Person(name: 'You'),
            conversationTitle: title,
            groupConversation: false,
            messages: [
              Message(body, DateTime.now(), Person(name: '${data['senderName'] ?? title}')),
            ],
          )
              : BigTextStyleInformation(body, contentTitle: title),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: _target(data),
    );
  }

  /// Where a notification should take the user:
  /// "chat:<bookingId>", "booking:<id>" or "job:<id>".
  static String? _target(Map<String, dynamic> data) {
    final bookingId = data['bookingId'];
    if (data['type'] == 'chat_message' && bookingId is String && bookingId.isNotEmpty) return 'chat:$bookingId';
    if (bookingId is String && bookingId.isNotEmpty) return 'booking:$bookingId';
    final jobId = data['jobId'];
    if (jobId is String && jobId.isNotEmpty) return 'job:$jobId';
    return null;
  }

  void _onNotificationTapped(NotificationResponse response) {
    final target = response.payload;
    if (target != null && target.isNotEmpty) {
      NotificationNavNotifier.instance.value = target;
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    final target = _target(message.data);
    if (target != null) NotificationNavNotifier.instance.value = target;
  }

  Future<String?> getDeviceToken() => _fcm.getToken();

  Future<void> saveTokenToFirestore(String uid) async {
    final token = await getDeviceToken();
    if (token == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set({'fcmToken': token}, SetOptions(merge: true));
  }
}