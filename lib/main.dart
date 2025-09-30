import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'state/queue_provider.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/user_home_screen.dart';
import 'screens/service_selection_screen.dart';
import 'debug/admin_debug_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (kDebugMode) {
    print('🚀 Initializing SmartQueue...');
  }
  
  try {
    await Supabase.initialize(
      url: 'https://uaezsosaqgwvjzsvpahg.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZXpzb3NhcWd3dmp6c3ZwYWhnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgxMTkyMzksImV4cCI6MjA3MzY5NTIzOX0.cbvGox-AxCzwMFFXkw8GfRuqdylDwIqJc8vjbNxKvkM',
    );
    
    if (kDebugMode) {
      print('✅ Supabase initialized successfully');
    }
  } catch (e) {
    if (kDebugMode) {
      print('❌ Failed to initialize Supabase: $e');
    }
  }
  
  runApp(
    ChangeNotifierProvider(
      create: (context) => EnhancedQueueProvider(),
      child: SmartQueueApp(),
    ),
  );
}

class SmartQueueApp extends StatelessWidget {
  const SmartQueueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartQueue',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: const AuthWrapper(),
      // Add named routes for testing
      routes: {
        '/service-selection-1': (context) => const ServiceSelectionScreen(serviceWindow: 1),
        '/service-selection-2': (context) => const ServiceSelectionScreen(serviceWindow: 2),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (kDebugMode) {
          print('🔐 Auth state changed: ${snapshot.data?.event}');
          if (snapshot.data?.session?.user != null) {
            print('👤 User: ${snapshot.data?.session?.user?.email}');
          }
        }
        
        if (snapshot.hasData && snapshot.data!.session != null) {
          return const RoleBasedHome();
        }
        return LoginScreen();
      },
    );
  }
}

class RoleBasedHome extends StatelessWidget {
  const RoleBasedHome({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initializeUserData(context),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading profile...'),
                ],
              ),
            ),
          );
        }
        
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Supabase.instance.client.auth.signOut();
                    },
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            ),
          );
        }
        
        final provider = Provider.of<EnhancedQueueProvider>(context, listen: false);
        
        if (kDebugMode) {
          print('👤 User role: ${provider.currentProfile?.role}');
        }
        
        // Route based on role
        if (provider.currentProfile?.role == 'admin') {
          return const AdminDashboardScreen();
        } else {
          return const UserHomeScreen();
        }
      },
    );
  }
  
  Future<void> _initializeUserData(BuildContext context) async {
    final provider = Provider.of<EnhancedQueueProvider>(context, listen: false);
    await provider.loadProfile();
  }
}