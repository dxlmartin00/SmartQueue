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
      child: const SmartQueueApp(),
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
      routes: {
        '/login': (context) => LoginScreen(),
        '/user': (context) => const UserHomeScreen(),
        '/admin': (context) => const AdminDashboardScreen(),
        '/debug': (context) => const AdminDebugScreen(),
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
        
        // Check if user is authenticated
        if (snapshot.hasData && snapshot.data!.session != null) {
          return const RoleBasedHome();
        }
        
        // Not authenticated - show login screen
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
        // Loading state
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

        // Error state
        if (snapshot.hasError) {
          if (kDebugMode) {
            print('❌ Error loading profile: ${snapshot.error}');
          }
          
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Error loading profile'),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      await Supabase.instance.client.auth.signOut();
                      if (context.mounted) {
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          '/login',
                          (route) => false,
                        );
                      }
                    },
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            ),
          );
        }

        // Success - route based on role
        return Consumer<EnhancedQueueProvider>(
          builder: (context, provider, child) {
            final role = provider.currentProfile?.role ?? 'user';
            
            if (kDebugMode) {
              print('📍 Routing user to: $role screen');
              print('👤 Profile: ${provider.currentProfile?.fullName}');
              print('🎭 Role: $role');
              if (role == 'admin') {
                print('🪟 Assigned Window: ${provider.currentProfile?.assignedWindow}');
              }
            }

            // Route based on role
            if (role == 'admin') {
              return const AdminDashboardScreen();
            } else {
              return const UserHomeScreen();
            }
          },
        );
      },
    );
  }

  Future<void> _initializeUserData(BuildContext context) async {
    final provider = Provider.of<EnhancedQueueProvider>(context, listen: false);
    
    try {
      if (kDebugMode) {
        print('🔄 Initializing user data...');
      }

      // Load user profile
      await provider.loadProfile();
      
      if (provider.currentProfile == null) {
        if (kDebugMode) {
          print('⚠️ No profile found, creating default profile...');
        }
        
        // Create a default user profile if none exists
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          await _createDefaultProfile(user.id, user.email ?? 'User');
          await provider.loadProfile();
        }
      }

      if (kDebugMode) {
        print('✅ User data initialized');
        print('Profile: ${provider.currentProfile?.fullName}');
        print('Role: ${provider.currentProfile?.role}');
      }

      // Load additional data based on role
      if (provider.currentProfile?.role == 'admin') {
        final window = provider.currentProfile?.assignedWindow;
        if (window != null) {
          await provider.loadAdminTickets(window);
          await provider.loadServiceStatuses();
        }
      } else {
        await provider.loadServices();
        await provider.loadUserTickets();
        await provider.loadServiceStatuses();
        provider.subscribeToServiceStatus();
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing user data: $e');
      }
      rethrow;
    }
  }

  Future<void> _createDefaultProfile(String userId, String email) async {
    try {
      await Supabase.instance.client.from('profiles').insert({
        'id': userId,
        'full_name': email.split('@')[0], // Use email username as name
        'role': 'user', // Default to user role
      });
      
      if (kDebugMode) {
        print('✅ Created default user profile');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Could not create default profile: $e');
      }
    }
  }
}