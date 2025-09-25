import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'state/queue_provider.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/user_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://uaezsosaqgwvjzsvpahg.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZXpzb3NhcWd3dmp6c3ZwYWhnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgxMTkyMzksImV4cCI6MjA3MzY5NTIzOX0.cbvGox-AxCzwMFFXkw8GfRuqdylDwIqJc8vjbNxKvkM',
  );
  
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
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
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
      future: Provider.of<EnhancedQueueProvider>(context, listen: false).loadProfile(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        final provider = Provider.of<EnhancedQueueProvider>(context);
        final role = provider.currentProfile?.role ?? 'user';

        print('Current user role: $role');
        
        if (role == 'admin') {
          return const AdminDashboardScreen();
        }
        return const UserHomeScreen();
      },
    );
  }
}