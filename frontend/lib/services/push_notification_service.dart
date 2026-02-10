import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you are using data-only messages, you can handle them here.
  // For standard notifications, the OS handles display while terminated.
  debugPrint("📱 Handling a background message: ${message.messageId}");
}

class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // 1. Request Permissions (iOS/Android 13+)
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('🔔 Notification Permission Granted');
    }

    // 2. Setup Local Notifications (for Foreground alerts)
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification click here
      },
    );

    // 3. Listen for Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });

    // 4. Initial Token Sync
    await syncToken();

    // 5. Listen for Token Refresh
    _messaging.onTokenRefresh.listen((newToken) {
      syncToken(token: newToken);
    });
  }

  static Future<void> syncToken({String? token}) async {
    try {
      final fcmToken = token ?? await _messaging.getToken();
      final user = Supabase.instance.client.auth.currentUser;

      if (fcmToken != null && user != null) {
        debugPrint('📡 Syncing FCM Token: $fcmToken');
        await Supabase.instance.client
            .from('profiles')
            .update({
              'fcm_token': fcmToken,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', user.id);
      }
    } catch (e) {
      debugPrint('⚠️ FCM Token Sync Failed: $e');
    }
  }

  static void _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;

    if (notification != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription: 'This channel is used for transaction alerts.',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    }
  }
}
