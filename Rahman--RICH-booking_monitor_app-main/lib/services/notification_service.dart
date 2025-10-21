// lib/services/notification_service.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Initializes the notification plugin
  Future<void> initNotification() async {
    // Settings for Android
    AndroidInitializationSettings initializationSettingsAndroid =
        const AndroidInitializationSettings(
          'app_icon',
        ); // MUST match your icon file name

    // Settings for iOS
    var initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      onDidReceiveLocalNotification:
          (int id, String? title, String? body, String? payload) async {},
    );

    var initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse:
          (NotificationResponse notificationResponse) async {},
    );
  }

  // Shows a notification
  Future<void> showNotification(int id, String title, String body) async {
    await notificationsPlugin.show(
      id,
      title,
      body,
      NotificationDetails(
        // Notification details for Android
        android: AndroidNotificationDetails(
          'main_channel', // A unique ID for the channel
          'Main Channel',
          channelDescription: "Main channel for booking notifications",
          importance: Importance.max, // Ensures the notification pops up
          priority: Priority.high,
          icon: 'app_icon', // MUST match your icon file name
        ),
        // Notification details for iOS
        iOS: DarwinNotificationDetails(
          sound: 'default.wav',
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}
