//import 'package:flutter_local_notifications/flutter_local_notifications.dart';
//import 'package:permission_handler/permission_handler.dart';
//import '../config/app_config.dart';

// TODO: Re-enable when flutter_local_notifications is compatible with SDK 35
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();
  
  Future<void> initialize() async {
    // Placeholder - notifications disabled
  }
  
  Future<void> showTicketCalledNotification({
    required String ticketNumber,
    required int window,
  }) async {
    // Placeholder - notifications disabled
  }
}
/*
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();
  
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = 
      FlutterLocalNotificationsPlugin();
  
  Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestSoundPermission: true,
          requestBadgePermission: true,
          requestAlertPermission: true,
        );
    
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );
    
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
    await _requestPermissions();
  }
  
  Future<void> _requestPermissions() async {
    await Permission.notification.request();
  }
  
  Future<void> showTicketCalledNotification({
    required String ticketNumber,
    required int window,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          AppConfig.notificationChannelId,
          AppConfig.notificationChannelName,
          channelDescription: AppConfig.notificationChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          showWhen: false,
          enableVibration: true,
          playSound: true,
        );
    
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );
    
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );
    
    await _flutterLocalNotificationsPlugin.show(
      0,
      'Your Turn!',
      'Ticket $ticketNumber is being called at Window $window',
      platformChannelSpecifics,
    );
  }
}

*/