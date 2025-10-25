import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../state/queue_provider.dart';
import '../models/service.dart';
import '../models/queue.dart';
import 'service_selection_screen.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  _UserHomeScreenState createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final provider = Provider.of<EnhancedQueueProvider>(context, listen: false);
    debugPrint('🚀 UserHomeScreen: Starting data load...');

    // Clear any previous errors when refreshing
    provider.clearError();

    await provider.loadServices();
    await provider.loadUserTickets();
    await provider.loadServiceStatuses();
    provider.subscribeToServiceStatus();

    debugPrint('✅ UserHomeScreen: Data load complete');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartQueue'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                debugPrint('🚪 User signing out...');
                await Supabase.instance.client.auth.signOut();
                debugPrint('✅ Sign out successful');

                // Force navigation to login screen
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/login',
                    (route) => false,
                  );
                }
              } catch (e) {
                debugPrint('❌ Sign out error: $e');
              }
            },
          ),
        ],
      ),
      body: Consumer<EnhancedQueueProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.services.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, ${provider.currentProfile?.fullName ?? 'User'}!',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  
                  // Error display
                  if (provider.error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error, color: Colors.red.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              provider.error!,
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: provider.clearError,
                          ),
                        ],
                      ),
                    ),
                  
                  // Current Active Ticket
                  _buildActiveTicketSection(provider),
                  
                  // Window Status Cards
                  const Text(
                    'Current Queue Status',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildWindowStatusCard(provider, 1),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildWindowStatusCard(provider, 2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Service Selection Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ServiceSelectionScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.medical_services),
                      label: const Text('Select a Service'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActiveTicketSection(EnhancedQueueProvider provider) {
    // Find active ticket (waiting or serving, excluding cancelled)
    final activeTicket = provider.userTickets.firstWhere(
      (t) => (t.status == 'waiting' || t.status == 'serving') && t.status != 'cancelled',
      orElse: () => QueueTicket(
        id: '',
        serviceId: '',
        userId: '',
        ticketNumber: '',
        status: '',
        queueDate: DateTime.now(),
        createdAt: DateTime.now(),
      ),
    );

    if (activeTicket.id.isEmpty) {
      // No active ticket - show message
      return Column(
        children: [
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'You don\'t have an active ticket. Select a service below to get started!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      );
    }

    // Has active ticket - show it prominently
    final service = provider.services.firstWhere(
      (s) => s.id == activeTicket.serviceId,
      orElse: () => Service(id: activeTicket.serviceId, name: 'Unknown', window: 1),
    );

    final isServing = activeTicket.status == 'serving';
    final color = isServing ? Colors.green : Colors.orange;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Current Ticket',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 4,
          color: color.shade50,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: color.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          activeTicket.ticketNumber,
                          style: TextStyle(
                            color: color.shade900,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            service.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: color.shade900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Window ${service.window}',
                            style: TextStyle(
                              fontSize: 14,
                              color: color.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isServing ? Icons.notifications_active : Icons.schedule,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isServing ? 'NOW SERVING' : 'WAITING',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (isServing) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade300, width: 2),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade700, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Please proceed to Window ${service.window} now!',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Cancel button for waiting tickets
                if (!isServing) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showCancelDialog(context, activeTicket, provider),
                      icon: const Icon(Icons.cancel),
                      label: const Text('Cancel Ticket'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildWindowStatusCard(EnhancedQueueProvider provider, int window) {
    final status = provider.serviceStatuses.firstWhere(
      (s) => s.serviceWindow == window,
      orElse: () => ServiceStatus(serviceWindow: window, updatedAt: DateTime.now()),
    );

    return Card(
      color: window == 1 ? Colors.blue.shade50 : Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.window,
                  color: window == 1 ? Colors.blue : Colors.green,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  'Window $window',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: window == 1 ? Colors.blue.shade900 : Colors.green.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Now Serving:',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
            Text(
              status.currentNumber ?? 'None',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: window == 1 ? Colors.blue.shade700 : Colors.green.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelDialog(BuildContext context, QueueTicket ticket, EnhancedQueueProvider provider) {
    final service = provider.services.firstWhere(
      (s) => s.id == ticket.serviceId,
      orElse: () => Service(id: ticket.serviceId, name: 'Unknown', window: 1),
    );

    // Store a reference to the widget's context
    final widgetContext = context;

    showDialog(
      context: widgetContext,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('Cancel Ticket?'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Are you sure you want to cancel this ticket?'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ticket: ${ticket.ticketNumber}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(service.name),
                    const SizedBox(height: 4),
                    Text(
                      'Window ${service.window}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This action cannot be undone.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Keep Ticket'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _cancelTicket(ticket, provider);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Cancel Ticket'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _cancelTicket(QueueTicket ticket, EnhancedQueueProvider provider) async {
    try {
      debugPrint('🔴 User attempting to cancel ticket: ${ticket.id} (${ticket.ticketNumber})');
      await provider.cancelTicket(ticket.id);
      debugPrint('✅ Ticket cancelled successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('Ticket ${ticket.ticketNumber} cancelled'),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (error) {
      debugPrint('❌ Failed to cancel ticket: $error');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed to cancel ticket: $error')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

}