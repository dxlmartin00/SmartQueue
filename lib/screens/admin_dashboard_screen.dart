// lib/screens/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../state/queue_provider.dart';
import 'queue_control_screen.dart';
import 'analytics_screen.dart';

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
                    onPressed: () => Supabase.instance.client.auth.signOut(),
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
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: () => Supabase.instance.client.auth.signOut(),
                tooltip: 'Sign Out',
              ),
            ],
          ),
          body: DefaultTabController(
            length: 2,
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
                        icon: Icon(Icons.analytics),
                        text: 'Analytics',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Only show queue control for assigned window
                      QueueControlScreen(serviceWindow: assignedWindow),
                      // Analytics for assigned window only
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