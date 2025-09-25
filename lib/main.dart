import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'state/queue_provider.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/user_home_screen.dart';
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
                  Text('Loading your profile...'),
                ],
              ),
            ),
          );
        }
        
        if (snapshot.hasError) {
          if (kDebugMode) {
            print('❌ Error loading user data: ${snapshot.error}');
          }
          
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Failed to load user data'),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: const TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Supabase.instance.client.auth.signOut(),
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            ),
          );
        }
        
        return Consumer<EnhancedQueueProvider>(
          builder: (context, provider, child) {
            final role = provider.currentProfile?.role ?? 'user';
            final userName = provider.currentProfile?.fullName ?? 'User';

            if (kDebugMode) {
              print('🎭 Current user role: $role');
              print('👤 Current user name: $userName');
              print('🔍 Profile object: ${provider.currentProfile}');
            }
            
            // Add debug button in debug mode
            Widget homeScreen;
            if (role == 'admin') {
              if (kDebugMode) {
                print('🔧 Loading AdminDashboardScreen');
              }
              homeScreen = const AdminDashboardScreen();
            } else {
              if (kDebugMode) {
                print('👨‍🎓 Loading UserHomeScreen');
              }
              homeScreen = const UserHomeScreen();
            }
            
            // Wrap with debug button if in debug mode
            if (kDebugMode) {
              return Stack(
                children: [
                  homeScreen,
                  Positioned(
                    top: 50,
                    right: 16,
                    child: FloatingActionButton.small(
                      heroTag: "admin_debug",
                      backgroundColor: Colors.red,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => AdminDebugScreen(),
                          ),
                        );
                      },
                      child: const Icon(Icons.admin_panel_settings),
                    ),
                  ),
                ],
              );
            }
            
            return homeScreen;
          },
        );
      },
    );
  }
  
  Future<void> _initializeUserData(BuildContext context) async {
    final provider = Provider.of<EnhancedQueueProvider>(context, listen: false);
    
    if (kDebugMode) {
      print('📊 Initializing user data...');
    }
    
    // Load user profile first
    await provider.loadProfile();
    
    if (kDebugMode) {
      print('👤 Profile loaded: ${provider.currentProfile?.fullName} (${provider.currentProfile?.role})');
    }
    
    // Load services and other data
    await Future.wait([
      provider.loadServices(),
      provider.loadUserTickets(),
      provider.loadServiceStatuses(),
    ]);
    
    if (kDebugMode) {
      print('📋 Loaded ${provider.services.length} services');
      print('🎫 Loaded ${provider.userTickets.length} user tickets');
      print('📊 Loaded ${provider.serviceStatuses.length} service statuses');
    }
    
    // Subscribe to real-time updates
    provider.subscribeToServiceStatus();
    
    if (kDebugMode) {
      print('✅ User data initialization complete');
    }
  }
}