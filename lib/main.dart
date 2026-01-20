import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'; // <--- 1. NEW IMPORT (For Web Check)
import 'firebase_options.dart';
import 'auth_wrapper.dart';
import 'services/notification_service.dart';
import 'monitor_dashboard.dart'; // <--- 2. NEW IMPORT (For Monitor)

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 3. SAFETY CHECK: Only init notifications if NOT on web
  // This prevents the "Uncaught Error" crash on the browser
  if (!kIsWeb) {
    await NotificationService.init(); 
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartQueue', // Official Name
      debugShowCheckedModeBanner: false,
      
      // --- PROFESSIONAL THEME START ---
      theme: ThemeData(
        useMaterial3: true,
        
        // 1. Color Palette (Deep Blue & Gold is a classic academic combo)
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A237E), // Deep Indigo/Blue (Primary)
          secondary: const Color(0xFFFFA000), // Amber/Gold (Accent)
          background: const Color(0xFFF5F5F7), // Light Grey (Not harsh white)
        ),
        
        // 2. Card Styling (Soft shadows, rounded corners)
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.white,
          surfaceTintColor: Colors.white, // Removes the slight tint on M3 cards
        ),

        // 3. Input Fields (Clean outlines)
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1A237E), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),

        // 4. Buttons (Big, bold, readable)
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A237E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            elevation: 3,
          ),
        ),
        
        // 5. Typography (Headings)
        textTheme: const TextTheme(
          headlineMedium: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF2D3436)),
          titleLarge: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2D3436)),
        ),
      ),
      // --- PROFESSIONAL THEME END ---

      home: const AuthWrapper(),

      // 4. ADD ROUTES HERE (This enables the Monitor URL)
      routes: {
        // 1. Dual View (Side-by-Side)
        '/monitor': (context) => const MonitorDual(),
        
        // 2. Counter 1 Only
        '/monitor1': (context) => const MonitorCounter1(),
        
        // 3. Counter 2 Only
        '/monitor2': (context) => const MonitorCounter2(),
      },
    );
  }
}