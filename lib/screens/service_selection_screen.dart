import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/queue_provider.dart';

class ServiceSelectionScreen extends StatelessWidget {
  final int serviceWindow;

  const ServiceSelectionScreen({super.key, required this.serviceWindow});

  @override
  Widget build(BuildContext context) {
    return Consumer<EnhancedQueueProvider>(
      builder: (context, provider, child) {
        final services = provider.services.where((s) => s.window == serviceWindow).toList();
        
        return Scaffold(
          appBar: AppBar(
            title: Text('Select Service - Window $serviceWindow'),
          ),
          body: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: services.length,
            itemBuilder: (context, index) {
              final service = services[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(service.name),
                  subtitle: Text('Window $serviceWindow'),
                  trailing: ElevatedButton(
                    onPressed: () async {
                      try {
                        final ticketNumber = await provider.generateTicket(service.id);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Ticket $ticketNumber generated!')),
                        );
                      } catch (error) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $error')),
                        );
                      }
                    },
                    child: const Text('Get Ticket'),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}