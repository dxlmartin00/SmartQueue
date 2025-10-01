import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../state/queue_provider.dart';
import '../models/service.dart';
import '../models/queue.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  _UserHomeScreenState createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  @override
  void initState() {
    super.initState();
    final provider = Provider.of<EnhancedQueueProvider>(context, listen: false);
    provider.loadServices();
    provider.loadUserTickets();
    provider.loadServiceStatuses();
    provider.subscribeToServiceStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EnhancedQueueProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('SmartQueue'),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => Supabase.instance.client.auth.signOut(),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${provider.currentProfile?.fullName ?? 'User'}!',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                
                // Current Tickets
                if (provider.userTickets.isNotEmpty) ...[
                  const Text(
                    'Your Tickets Today',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...provider.userTickets.map((ticket) => TicketCard(ticket: ticket)),
                  const SizedBox(height: 24),
                ],
                
                // Window Status Cards
                const Text(
                  'Current Queue Status',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: WindowStatusCard(serviceWindow: 1),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: WindowStatusCard(serviceWindow: 2),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // All Services Section
                const Text(
                  'Select a Service',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                AllServicesCard(services: provider.services),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Window Status Card - Shows current queue status
class WindowStatusCard extends StatelessWidget {
  final int serviceWindow;

  const WindowStatusCard({super.key, required this.serviceWindow});

  @override
  Widget build(BuildContext context) {
    return Consumer<EnhancedQueueProvider>(
      builder: (context, provider, child) {
        final status = provider.serviceStatuses.firstWhere(
          (s) => s.serviceWindow == serviceWindow,
          orElse: () => ServiceStatus(serviceWindow: serviceWindow, updatedAt: DateTime.now()),
        );
        
        // Count waiting tickets for this window
        final windowServices = provider.services
            .where((s) => s.window == serviceWindow)
            .map((s) => s.id)
            .toSet();
        
        final waitingCount = provider.userTickets
            .where((t) => windowServices.contains(t.serviceId) && t.status == 'waiting')
            .length;
        
        return Card(
          color: serviceWindow == 1 ? Colors.blue.shade50 : Colors.green.shade50,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.window,
                      color: serviceWindow == 1 ? Colors.blue : Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Window $serviceWindow',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: serviceWindow == 1 ? Colors.blue.shade900 : Colors.green.shade900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Now Serving:',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                  ),
                ),
                Text(
                  status.currentNumber ?? 'None',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: serviceWindow == 1 ? Colors.blue.shade700 : Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'In Queue: $waitingCount',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
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

// All Services Card - Shows all services without window grouping
class AllServicesCard extends StatelessWidget {
  final List<Service> services;

  const AllServicesCard({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    return Consumer<EnhancedQueueProvider>(
      builder: (context, provider, child) {
        if (services.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text('No services available'),
              ),
            ),
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: services.map((service) {
                final isLoading = provider.isLoading;
                
                // Determine color based on which window the service belongs to
                final color = service.window == 1 ? Colors.blue : Colors.green;
                
                return ActionChip(
                  label: Text(
                    service.name,
                    style: TextStyle(
                      color: color.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  backgroundColor: color.withOpacity(0.1),
                  side: BorderSide(color: color.withOpacity(0.3)),
                  onPressed: isLoading
                      ? null
                      : () => _handleServiceSelection(context, provider, service),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleServiceSelection(
    BuildContext context,
    EnhancedQueueProvider provider,
    Service service,
  ) async {
    try {
      final ticketNumber = await provider.generateTicket(service.id);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ticket generated: $ticketNumber\nAssigned to Window ${service.window}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        
        // Refresh tickets
        await provider.loadUserTickets();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Ticket Card - Shows user's current tickets
class TicketCard extends StatelessWidget {
  final QueueTicket ticket;

  const TicketCard({super.key, required this.ticket});

  String _getStatusText(String status) {
    switch (status) {
      case 'waiting':
        return 'Waiting in Queue';
      case 'serving':
        return 'Being Served';
      case 'done':
        return 'Completed';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'waiting':
        return Colors.orange;
      case 'serving':
        return Colors.green;
      case 'done':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(ticket.status).withOpacity(0.2),
          child: Text(
            ticket.ticketNumber,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: _getStatusColor(ticket.status),
            ),
          ),
        ),
        title: Text(
          ticket.ticketNumber,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_getStatusText(ticket.status)),
            Text(
              'Created: ${_formatTime(ticket.createdAt)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
        trailing: ticket.status == 'serving'
            ? const Icon(Icons.notifications_active, color: Colors.green)
            : null,
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}