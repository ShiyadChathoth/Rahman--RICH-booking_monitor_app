// lib/services/notification_service.dart - CORRECTED ICON

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Initializes the notification plugin
  Future<void> initNotification() async {
    // Settings for Android
    AndroidInitializationSettings initializationSettingsAndroid =
        const AndroidInitializationSettings(
          'notification_icon', // Use the icon from drawable folder
        );

    // Settings for iOS
    var initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      onDidReceiveLocalNotification:
          (int id, String? title, String? body, String? payload) async {
            // Handle notification received while app is in foreground for older iOS versions
          },
    );

    var initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
      // Add settings for macOS, Linux, etc. if needed
    );

    await notificationsPlugin.initialize(
      initializationSettings,
      // Handles notification tapped action
      onDidReceiveNotificationResponse:
          (NotificationResponse notificationResponse) async {
            // Handle payload or navigation when notification is tapped
            // Example: if (notificationResponse.payload != null) { ... }
          },
      // Handles background notification tapped action (Android specific?)
      // onDidReceiveBackgroundNotificationResponse: notificationTapBackground, // Needs a static/top-level function
    );

    // Request permissions specifically for Android 13+
    // You might need to call this separately depending on your app flow
    // or handle the result of requestPermission from firebase_messaging
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    await androidImplementation
        ?.requestNotificationsPermission(); // Request permission
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
          icon:
              'notification_icon', // <<< CORRECTED: Use the actual drawable icon name
          // You can add sound, vibration patterns etc. here
        ),
        // Notification details for iOS
        iOS: DarwinNotificationDetails(
          sound: 'default.wav', // Default sound
          presentAlert: true, // Show alert banner
          presentBadge: true, // Update app icon badge
          presentSound: true, // Play sound
        ),
      ),
      // payload: 'Optional payload data for when notification is tapped'
    );
  }
}

// Example top-level function if needed for onDidReceiveBackgroundNotificationResponse
// @pragma('vm:entry-point')
// void notificationTapBackground(NotificationResponse notificationResponse) {
//   // handle action
//   print("Notification tapped in background/terminated state: ${notificationResponse.payload}");
// }
