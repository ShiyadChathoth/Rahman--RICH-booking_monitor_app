// lib/services/notification_service.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Initializes the notification plugin
  Future<void> initNotification() async {
    // Settings for Android
    // Use the icon name (without extension) from the drawable folder
    AndroidInitializationSettings initializationSettingsAndroid =
        const AndroidInitializationSettings(
          'notification_icon', // MUST match your icon file name
        );

    // Settings for iOS (can be kept or removed if only targeting Android)
    var initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      onDidReceiveLocalNotification:
          (int id, String? title, String? body, String? payload) async {},
    );

    var initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS:
          initializationSettingsIOS, // Keep or remove based on target platforms
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
          'Main Channel', // Channel name visible in Android settings
          channelDescription:
              "Main channel for booking notifications", // Channel description
          importance: Importance.max, // Ensures the notification pops up
          priority: Priority.high, // High priority
          // Ensure this icon name matches the file in android/app/src/main/res/drawable
          icon: 'notification_icon', // Use the same icon name here
        ),
        // Notification details for iOS (can be kept or removed)
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
