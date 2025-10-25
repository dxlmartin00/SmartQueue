// lib/screens/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../state/queue_provider.dart';
import 'queue_control_screen.dart';
import 'analytics_screen.dart';
import 'transaction_history_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    final provider = Provider.of<EnhancedQueueProvider>(context, listen: false);
    provider.loadServices();
    provider.loadServiceStatuses();
    provider.subscribeToServiceStatus();
  }

  void _showSignOutDialog(BuildContext context) {
    // Store a reference to the widget's context
    final widgetContext = context;

    showDialog(
      context: widgetContext,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.logout, color: Colors.orange),
              SizedBox(width: 8),
              Text('Sign Out'),
            ],
          ),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                try {
                  debugPrint('🚪 Admin signing out...');
                  await Supabase.instance.client.auth.signOut();
                  debugPrint('✅ Sign out successful');

                  // Force navigation to login screen
                  if (widgetContext.mounted) {
                    Navigator.of(widgetContext).pushNamedAndRemoveUntil(
                      '/login',
                      (route) => false,
                    );
                  }
                } catch (e) {
                  debugPrint('❌ Sign out error: $e');
                  if (widgetContext.mounted) {
                    ScaffoldMessenger.of(widgetContext).showSnackBar(
                      SnackBar(
                        content: Text('Error signing out: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EnhancedQueueProvider>(
      builder: (context, provider, child) {
        final profile = provider.currentProfile;
        
        // Safety check
        if (profile == null || profile.role != 'admin' || profile.assignedWindow == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Unauthorized Access'),
                  const SizedBox(height: 8),
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

        final assignedWindow = profile.assignedWindow!;
        final windowColor = assignedWindow == 1 ? Colors.blue : Colors.green;

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: windowColor,
            title: Row(
              children: [
                Icon(Icons.window, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Window $assignedWindow Admin Dashboard',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            actions: [
              // Admin Info Badge
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      profile.fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white, size: 28),
                onPressed: () => _showSignOutDialog(context),
                tooltip: 'Sign Out',
              ),
            ],
          ),
          body: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                Container(
                  color: windowColor,
                  child: TabBar(
                    indicatorColor: Colors.white,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.queue),
                        text: 'Queue Control',
                      ),
                      Tab(
                        icon: Icon(Icons.history),
                        text: 'History',
                      ),
                      Tab(
                        icon: Icon(Icons.analytics),
                        text: 'Analytics',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Queue control for assigned window
                      QueueControlScreen(serviceWindow: assignedWindow),
                      // Transaction history for assigned window
                      TransactionHistoryScreen(serviceWindow: assignedWindow),
                      // Analytics for assigned window
                      AnalyticsScreen(specificWindow: assignedWindow),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}