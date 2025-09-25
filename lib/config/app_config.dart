class AppConfig {
  static const String appName = 'SmartQueue';
  static const String version = '2.0.0';
  
  // Supabase Configuration
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'YOUR_SUPABASE_URL',
  );
  
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY', 
    defaultValue: 'YOUR_SUPABASE_ANON_KEY',
  );
  
  // App Configuration
  static const int maxRetryAttempts = 3;
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration offlineSyncInterval = Duration(minutes: 5);
  static const int estimatedServiceTimeMinutes = 5;
  static const int maxTicketsPerUser = 3;
  
  // Notification Configuration
  static const String notificationChannelId = 'smartqueue_notifications';
  static const String notificationChannelName = 'SmartQueue Notifications';
  static const String notificationChannelDescription = 'Queue status notifications';
  
  // Debug Configuration
  static const bool enableDetailedLogging = bool.fromEnvironment('DEBUG_LOGGING', defaultValue: false);
  static const bool enablePerformanceMonitoring = bool.fromEnvironment('PERFORMANCE_MONITORING', defaultValue: true);
}