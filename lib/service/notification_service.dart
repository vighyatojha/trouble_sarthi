import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
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
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);
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

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF7C3AED),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data['bookingId'] as String?,
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    final bookingId = response.payload;
    if (bookingId != null && bookingId.isNotEmpty) {
      NotificationNavNotifier.instance.value = bookingId;
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    final bookingId = message.data['bookingId'] as String?;
    if (bookingId != null && bookingId.isNotEmpty) {
      NotificationNavNotifier.instance.value = bookingId;
    }
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