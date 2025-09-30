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
        final window1Services = provider.services.where((s) => s.window == 1).toList();
        final window2Services = provider.services.where((s) => s.window == 2).toList();
        
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
                
                // Window 1 Services
                const Text(
                  'Window 1 Services',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ServiceStatusCard(serviceWindow: 1, services: window1Services),
                const SizedBox(height: 16),
                
                // Window 2 Services
                const Text(
                  'Window 2 Services',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ServiceStatusCard(serviceWindow: 2, services: window2Services),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ServiceStatusCard extends StatelessWidget {
  final int serviceWindow;
  final List<Service> services;

  const ServiceStatusCard({super.key, required this.serviceWindow, required this.services});

  @override
  Widget build(BuildContext context) {
    return Consumer<EnhancedQueueProvider>(
      builder: (context, provider, child) {
        final status = provider.serviceStatuses.firstWhere(
          (s) => s.serviceWindow == serviceWindow,
          orElse: () => ServiceStatus(serviceWindow: serviceWindow, updatedAt: DateTime.now()),
        );
        
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Window $serviceWindow',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Now Serving: ${status.currentNumber ?? 'None'}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Quick service buttons (original inline functionality)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: services.map((service) => ElevatedButton(
                    onPressed: () async {
                      try {
                        await provider.generateTicket(service.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Ticket generated for ${service.name}')),
                          );
                        }
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $error')),
                          );
                        }
                      }
                    },
                    child: Text(service.name),
                  )).toList(),
                ),
                
                const SizedBox(height: 12),
                
                // Add navigation button to ServiceSelectionScreen for testing
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ServiceSelectionScreen(serviceWindow: serviceWindow),
                        ),
                      );
                    },
                    icon: const Icon(Icons.arrow_forward),
                    label: Text('Go to Window $serviceWindow Selection Screen'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                    ),
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

class TicketCard extends StatelessWidget {
  final QueueTicket ticket;

  const TicketCard({super.key, required this.ticket});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusText;
    
    switch (ticket.status) {
      case 'waiting':
        statusColor = Colors.orange;
        statusText = 'Waiting';
        break;
      case 'serving':
        statusColor = Colors.green;
        statusText = 'Being Served';
        break;
      case 'done':
        statusColor = Colors.blue;
        statusText = 'Completed';
        break;
      case 'skipped':
        statusColor = Colors.red;
        statusText = 'Skipped';
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Unknown';
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 60,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              ticket.ticketNumber,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        title: Text('Service: ${ticket.serviceId}'),
        subtitle: Text('Created: ${ticket.createdAt.toString().substring(11, 16)}'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            statusText,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ),
    );
  }
}