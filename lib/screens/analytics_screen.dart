// lib/screens/analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/queue_provider.dart';

class AnalyticsScreen extends StatefulWidget {
  final int? specificWindow; // If provided, show only this window's analytics

  const AnalyticsScreen({super.key, this.specificWindow});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    final provider = Provider.of<EnhancedQueueProvider>(context, listen: false);
    await provider.loadAdminTickets(widget.specificWindow ?? 1);
    
    // If no specific window, load both
    if (widget.specificWindow == null) {
      await provider.loadAdminTickets(2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EnhancedQueueProvider>(
      builder: (context, provider, child) {
        // Filter tickets based on window
        final allTickets = provider.adminTickets;
        final todayTickets = allTickets.where((t) {
          final isToday = t.queueDate.day == DateTime.now().day &&
              t.queueDate.month == DateTime.now().month &&
              t.queueDate.year == DateTime.now().year;
          
          if (widget.specificWindow == null) return isToday;
          
          // Get service for this ticket
          final service = provider.services.firstWhere(
            (s) => s.id == t.serviceId,
            orElse: () => provider.services.first,
          );
          
          return isToday && service.window == widget.specificWindow;
        }).toList();

        final waitingCount = todayTickets.where((t) => t.status == 'waiting').length;
        final servingCount = todayTickets.where((t) => t.status == 'serving').length;
        final doneCount = todayTickets.where((t) => t.status == 'done').length;
        final totalCount = todayTickets.length;

        // Calculate average wait time for completed tickets
        final completedTickets = todayTickets.where((t) => 
          t.status == 'done' && t.timeCalled != null && t.finishedAt != null
        ).toList();
        
        final avgWaitMinutes = completedTickets.isEmpty
            ? 0
            : completedTickets.map((t) {
                final waitTime = t.timeCalled!.difference(t.createdAt).inMinutes;
                return waitTime;
              }).reduce((a, b) => a + b) / completedTickets.length;

        final avgServiceMinutes = completedTickets.isEmpty
            ? 0
            : completedTickets.map((t) {
                final serviceTime = t.finishedAt!.difference(t.timeCalled!).inMinutes;
                return serviceTime;
              }).reduce((a, b) => a + b) / completedTickets.length;

        return Scaffold(
          body: RefreshIndicator(
            onRefresh: _loadAnalytics,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(
                        Icons.analytics,
                        size: 32,
                        color: widget.specificWindow == 1 
                            ? Colors.blue.shade600 
                            : widget.specificWindow == 2
                                ? Colors.green.shade600
                                : Colors.purple.shade600,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.specificWindow != null
                                  ? 'Window ${widget.specificWindow} Analytics'
                                  : 'Analytics Dashboard',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Today\'s Performance',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Summary Cards
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.5,
                    children: [
                      _buildStatCard(
                        'Total Tickets',
                        totalCount.toString(),
                        Icons.confirmation_number,
                        Colors.blue,
                      ),
                      _buildStatCard(
                        'Completed',
                        doneCount.toString(),
                        Icons.check_circle,
                        Colors.green,
                      ),
                      _buildStatCard(
                        'In Progress',
                        servingCount.toString(),
                        Icons.sync,
                        Colors.orange,
                      ),
                      _buildStatCard(
                        'Waiting',
                        waitingCount.toString(),
                        Icons.schedule,
                        Colors.purple,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Time Metrics
                  Row(
                    children: [
                      Expanded(
                        child: _buildTimeCard(
                          'Avg. Wait Time',
                          '${avgWaitMinutes.toStringAsFixed(1)} min',
                          Icons.hourglass_empty,
                          Colors.amber,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTimeCard(
                          'Avg. Service Time',
                          '${avgServiceMinutes.toStringAsFixed(1)} min',
                          Icons.timer,
                          Colors.teal,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Services Breakdown
                  const Text(
                    'Services Breakdown',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  _buildServicesBreakdown(provider, todayTickets),
                  
                  const SizedBox(height: 24),
                  
                  // Completion Rate
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.trending_up, color: Colors.green.shade600),
                              const SizedBox(width: 8),
                              const Text(
                                'Completion Rate',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          LinearProgressIndicator(
                            value: totalCount > 0 ? doneCount / totalCount : 0,
                            minHeight: 10,
                            backgroundColor: Colors.grey.shade300,
                            valueColor: AlwaysStoppedAnimation(Colors.green.shade600),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${totalCount > 0 ? ((doneCount / totalCount) * 100).toStringAsFixed(1) : 0}% Complete',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServicesBreakdown(EnhancedQueueProvider provider, List tickets) {
    // Group tickets by service
    final serviceGroups = <String, List>{};
    
    for (var ticket in tickets) {
      if (!serviceGroups.containsKey(ticket.serviceId)) {
        serviceGroups[ticket.serviceId] = [];
      }
      serviceGroups[ticket.serviceId]!.add(ticket);
    }

    if (serviceGroups.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.info_outline, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Text(
                  'No tickets today',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: serviceGroups.entries.map((entry) {
            final service = provider.services.firstWhere(
              (s) => s.id == entry.key,
              orElse: () => provider.services.first,
            );
            final tickets = entry.value;
            final completed = tickets.where((t) => t.status == 'done').length;
            
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${tickets.length} tickets',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: LinearProgressIndicator(
                      value: tickets.isNotEmpty ? completed / tickets.length : 0,
                      backgroundColor: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$completed/${tickets.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}