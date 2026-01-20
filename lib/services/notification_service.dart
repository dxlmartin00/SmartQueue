import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart'; // <--- REQUIRED for kIsWeb

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  // 1. Initialize (Safe for Web)
  static Future<void> init() async {
    // STOP: If we are on the Web, do nothing and return.
    if (kIsWeb) return; 

    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const InitializationSettings settings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(settings);
  }

  // 2. The Trigger Function (Safe for Web)
  static Future<void> showNotification({required String title, required String body}) async {
    // STOP: If we are on the Web, do nothing.
    if (kIsWeb) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'smartqueue_channel',
      'Queue Alerts',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      0, 
      title, 
      body, 
      details,
    );
  }
}