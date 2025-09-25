// First, let's create a debug widget to check what's happening
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../state/queue_provider.dart';

class AdminDebugScreen extends StatefulWidget {
  const AdminDebugScreen({super.key});

  @override
  State<AdminDebugScreen> createState() => _AdminDebugScreenState();
}

class _AdminDebugScreenState extends State<AdminDebugScreen> {
  String _debugInfo = 'Loading...';

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final buffer = StringBuffer();
    
    try {
      final user = Supabase.instance.client.auth.currentUser;
      buffer.writeln('=== USER INFO ===');
      buffer.writeln('User ID: ${user?.id}');
      buffer.writeln('Email: ${user?.email}');
      buffer.writeln('Authenticated: ${user != null}');
      buffer.writeln('');

      if (user != null) {
        buffer.writeln('=== PROFILE CHECK ===');
        
        try {
          // Direct database query to check profile
          final profileResponse = await Supabase.instance.client
              .from('profiles')
              .select()
              .eq('id', user.id)
              .single();
          
          buffer.writeln('Profile found: YES');
          buffer.writeln('Full name: ${profileResponse['full_name']}');
          buffer.writeln('Role: ${profileResponse['role']}');
          buffer.writeln('Raw profile data: $profileResponse');
          
        } catch (profileError) {
          buffer.writeln('Profile found: NO');
          buffer.writeln('Profile error: $profileError');
          
          // Try to create profile
          buffer.writeln('');
          buffer.writeln('=== CREATING PROFILE ===');
          try {
            await Supabase.instance.client.from('profiles').insert({
              'id': user.id,
              'full_name': user.userMetadata?['full_name'] ?? 'Admin User',
              'role': 'admin', // Set as admin by default for testing
            });
            buffer.writeln('Profile created successfully as admin');
          } catch (createError) {
            buffer.writeln('Failed to create profile: $createError');
          }
        }

        buffer.writeln('');
        buffer.writeln('=== PROVIDER CHECK ===');
        
        final provider = Provider.of<EnhancedQueueProvider>(context, listen: false);
        await provider.loadProfile();
        
        buffer.writeln('Provider profile loaded: ${provider.currentProfile != null}');
        buffer.writeln('Provider role: ${provider.currentProfile?.role}');
        buffer.writeln('Provider name: ${provider.currentProfile?.fullName}');
      }

    } catch (e) {
      buffer.writeln('ERROR: $e');
    }

    setState(() {
      _debugInfo = buffer.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Debug'),
        actions: [
          IconButton(
            onPressed: _checkAdminStatus,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: () => _makeCurrentUserAdmin(),
            icon: const Icon(Icons.admin_panel_settings),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: _makeCurrentUserAdmin,
              child: const Text('Force Make Me Admin'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _testRoleBasedNavigation(),
              child: const Text('Test Role-Based Navigation'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _debugInfo,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _makeCurrentUserAdmin() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() {
          _debugInfo = 'No user logged in';
        });
        return;
      }

      // First ensure profile exists
      try {
        await Supabase.instance.client.from('profiles').upsert({
          'id': user.id,
          'full_name': user.userMetadata?['full_name'] ?? 'Admin User',
          'role': 'admin',
        });
      } catch (e) {
        // If upsert fails, try insert
        await Supabase.instance.client.from('profiles').insert({
          'id': user.id,
          'full_name': user.userMetadata?['full_name'] ?? 'Admin User',
          'role': 'admin',
        });
      }

      // Reload provider
      final provider = Provider.of<EnhancedQueueProvider>(context, listen: false);
      await provider.loadProfile();

      setState(() {
        _debugInfo = 'SUCCESS: User set as admin. Role: ${provider.currentProfile?.role}';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User set as admin successfully!')),
      );

    } catch (e) {
      setState(() {
        _debugInfo = 'FAILED to set as admin: $e';
      });
    }
  }

  void _testRoleBasedNavigation() {
    final provider = Provider.of<EnhancedQueueProvider>(context, listen: false);
    final role = provider.currentProfile?.role ?? 'user';
    
    setState(() {
      _debugInfo = '''
=== NAVIGATION TEST ===
Current role: $role
Should show: ${role == 'admin' ? 'AdminDashboardScreen' : 'UserHomeScreen'}
Provider has profile: ${provider.currentProfile != null}
Profile role field: ${provider.currentProfile?.role}
''';
    });

    if (role == 'admin') {
      Navigator.of(context).pushReplacementNamed('/admin');
    } else {
      Navigator.of(context).pushReplacementNamed('/user');
    }
  }
}