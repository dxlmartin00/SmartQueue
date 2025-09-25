import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  _AnalyticsScreenState createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String, dynamic> _analytics = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    
    try {
      final supabase = Supabase.instance.client;
      final today = DateTime.now().toIso8601String().split('T')[0];

      // Students per window
      final windowStats = await supabase
          .from('queues')
          .select('services!inner(window)')
          .eq('queue_date', today);

      // Total students served
      final totalServed = await supabase
          .from('queues')
          .select()
          .eq('queue_date', today)
          .eq('status', 'done');

      // Average wait time (simplified calculation)
      final completedTickets = await supabase
          .from('queues')
          .select('created_at, time_called')
          .eq('queue_date', today)
          .not('time_called', 'is', null);

      double avgWaitTime = 0;
      if (completedTickets.isNotEmpty) {
        double totalWaitMinutes = 0;
        for (var ticket in completedTickets) {
          final created = DateTime.parse(ticket['created_at']);
          final called = DateTime.parse(ticket['time_called']);
          totalWaitMinutes += called.difference(created).inMinutes;
        }
        avgWaitTime = totalWaitMinutes / completedTickets.length;
      }

      setState(() {
        _analytics = {
          'window1Count': windowStats.where((q) => q['services']['window'] == 1).length,
          'window2Count': windowStats.where((q) => q['services']['window'] == 2).length,
          'avgWaitTime': avgWaitTime,
          'totalServed': totalServed.length,
          'totalQueued': windowStats.length,
        };
      });
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading analytics: $error')),
      );
    }
    
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Today\'s Analytics',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: _isLoading ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ) : const Icon(Icons.refresh),
                onPressed: _isLoading ? null : _loadAnalytics,
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Stats Cards
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildStatCard(
                  'Total Queued',
                  _analytics['totalQueued']?.toString() ?? '0',
                  Icons.people_outline,
                  Colors.blue,
                ),
                _buildStatCard(
                  'Total Served',
                  _analytics['totalServed']?.toString() ?? '0',
                  Icons.people,
                  Colors.green,
                ),
                _buildStatCard(
                  'Avg Wait Time',
                  '${_analytics['avgWaitTime']?.toStringAsFixed(1) ?? '0'}m',
                  Icons.timer,
                  Colors.orange,
                ),
                _buildStatCard(
                  'Success Rate',
                  _analytics['totalQueued'] != null && _analytics['totalQueued'] > 0
                      ? '${((_analytics['totalServed'] / _analytics['totalQueued']) * 100).toStringAsFixed(1)}%'
                      : '0%',
                  Icons.check_circle,
                  Colors.purple,
                ),
                _buildStatCard(
                  'Window 1',
                  _analytics['window1Count']?.toString() ?? '0',
                  Icons.looks_one,
                  Colors.indigo,
                ),
                _buildStatCard(
                  'Window 2',
                  _analytics['window2Count']?.toString() ?? '0',
                  Icons.looks_two,
                  Colors.teal,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}