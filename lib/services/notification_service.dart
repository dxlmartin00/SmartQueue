import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  // 1. Initialize (Run this when App Starts)
  static Future<void> init() async {
    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/ic_launcher'); // Uses your App Icon

    const InitializationSettings settings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(settings);
  }

  // 2. The Trigger Function
  static Future<void> showNotification({required String title, required String body}) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'smartqueue_channel', // Channel ID
      'Queue Alerts',       // Channel Name
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      0,      // Notification ID
      title, 
      body, 
      details,
    );
  }
}