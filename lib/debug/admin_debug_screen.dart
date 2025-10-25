// First, let's create a debug widget to check what's happening
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../state/queue_provider.dart';
import '../screens/signup_screen.dart';
import '../screens/login_screen.dart';
import '../screens/window_admin_login_screen.dart';
import '../screens/admin_dashboard_screen.dart';
import '../screens/queue_control_screen.dart';
import '../screens/queue_status_screen.dart';
import '../screens/service_selection_screen.dart';
import '../screens/analytics_screen.dart';
import '../screens/user_home_screen.dart';
import '../screens/ticket_screen.dart';
import '../models/queue.dart';

class AdminDebugScreen extends StatefulWidget {
  const AdminDebugScreen({super.key});

  @override
  State<AdminDebugScreen> createState() => _AdminDebugScreenState();
}

class _AdminDebugScreenState extends State<AdminDebugScreen> {
  String _debugInfo = 'Loading...';
  int _selectedTab = 0; // 0: Navigation, 1: Debug Info

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
        title: const Text('Debug & Navigation'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _checkAdminStatus,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab Selector
          Container(
            color: Colors.purple.shade100,
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton(
                    'Screen Navigator',
                    Icons.navigation,
                    0,
                  ),
                ),
                Expanded(
                  child: _buildTabButton(
                    'Debug Info',
                    Icons.bug_report,
                    1,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _selectedTab == 0
                ? _buildNavigationTab()
                : _buildDebugTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, IconData icon, int index) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.purple : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Colors.purple : Colors.grey.shade300,
              width: 3,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.purple.shade700,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.purple.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Test All Screens',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Navigate to any screen to test its functionality',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // Authentication Screens
          _buildScreenCategory(
            'Authentication Screens',
            Icons.login,
            Colors.blue,
            [
              _ScreenButton('Login Screen', Icons.login, Colors.blue, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
              }),
              _ScreenButton('Signup Screen', Icons.person_add, Colors.blue, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => SignupScreen()));
              }),
              _ScreenButton('Window 1 Admin Login', Icons.admin_panel_settings, Colors.blue, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const WindowAdminLoginScreen(window: 1)));
              }),
              _ScreenButton('Window 2 Admin Login', Icons.admin_panel_settings, Colors.green, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const WindowAdminLoginScreen(window: 2)));
              }),
            ],
          ),

          const SizedBox(height: 24),

          // User Screens
          _buildScreenCategory(
            'User Screens',
            Icons.person,
            Colors.orange,
            [
              _ScreenButton('User Home Screen', Icons.home, Colors.orange, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const UserHomeScreen()));
              }),
              _ScreenButton('Service Selection', Icons.business, Colors.orange, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ServiceSelectionScreen()));
              }),
              _ScreenButton('Ticket Screen (Sample)', Icons.receipt_long, Colors.orange, () {
                // Create a sample ticket for testing
                final sampleTicket = QueueTicket(
                  id: 'sample-123',
                  userId: 'test-user',
                  serviceId: 'A-001',
                  ticketNumber: 'A-001',
                  status: 'waiting',
                  queueDate: DateTime.now(),
                  createdAt: DateTime.now(),
                );
                Navigator.push(context, MaterialPageRoute(builder: (context) => TicketScreen(ticket: sampleTicket)));
              }),
            ],
          ),

          const SizedBox(height: 24),

          // Admin Screens
          _buildScreenCategory(
            'Admin Screens',
            Icons.admin_panel_settings,
            Colors.red,
            [
              _ScreenButton('Admin Dashboard', Icons.dashboard, Colors.red, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminDashboardScreen()));
              }),
              _ScreenButton('Queue Control (Window 1)', Icons.control_camera, Colors.blue, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const QueueControlScreen(serviceWindow: 1)));
              }),
              _ScreenButton('Queue Control (Window 2)', Icons.control_camera, Colors.green, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const QueueControlScreen(serviceWindow: 2)));
              }),
              _ScreenButton('Queue Status (Window 1)', Icons.queue, Colors.blue, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const QueueStatusScreen(serviceWindow: 1)));
              }),
              _ScreenButton('Queue Status (Window 2)', Icons.queue, Colors.green, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const QueueStatusScreen(serviceWindow: 2)));
              }),
              _ScreenButton('Analytics (Window 1)', Icons.analytics, Colors.blue, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AnalyticsScreen(specificWindow: 1)));
              }),
              _ScreenButton('Analytics (Window 2)', Icons.analytics, Colors.green, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AnalyticsScreen(specificWindow: 2)));
              }),
              _ScreenButton('Analytics (All Windows)', Icons.analytics_outlined, Colors.purple, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AnalyticsScreen()));
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScreenCategory(String title, IconData icon, Color color, List<_ScreenButton> buttons) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...buttons.map((btn) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: btn.onPressed,
              icon: Icon(btn.icon, size: 20),
              label: Text(btn.label),
              style: ElevatedButton.styleFrom(
                backgroundColor: btn.color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                alignment: Alignment.centerLeft,
              ),
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildDebugTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ElevatedButton.icon(
            onPressed: _makeCurrentUserAdmin,
            icon: const Icon(Icons.admin_panel_settings),
            label: const Text('Force Make Me Admin'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _testRoleBasedNavigation(),
            icon: const Icon(Icons.navigation),
            label: const Text('Test Role-Based Navigation'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Debug Information:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
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

// Helper class for screen navigation buttons
class _ScreenButton {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  _ScreenButton(this.label, this.icon, this.color, this.onPressed);
}