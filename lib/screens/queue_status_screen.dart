import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/queue_provider.dart';
import '../models/queue.dart';

class QueueStatusScreen extends StatelessWidget {
  final int window;

  const QueueStatusScreen({super.key, required this.window});

  @override
  Widget build(BuildContext context) {
    return Consumer<EnhancedQueueProvider>(
      builder: (context, provider, child) {
        final waitingTickets = provider.adminTickets
            .where((t) => t.status == 'waiting')
            .toList();
        
        final status = provider.serviceStatuses.firstWhere(
          (s) => s.window == window,
          orElse: () => ServiceStatus(window: window, updatedAt: DateTime.now()),
        );

        return Scaffold(
          appBar: AppBar(
            title: Text('Queue Status - Window $window'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Current Status
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text(
                          'Now Serving',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          status.currentNumber ?? 'None',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Queue List
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Waiting Queue (${waitingTickets.length})',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          itemCount: waitingTickets.length,
                          itemBuilder: (context, index) {
                            final ticket = waitingTickets[index];
                            final position = index + 1;
                            final estimatedWait = position * 5; // 5 minutes per ticket estimate
                            
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  child: Text('$position'),
                                ),
                                title: Text(ticket.ticketNumber),
                                subtitle: Text('Estimated wait: ${estimatedWait}m'),
                                trailing: const Icon(
                                  Icons.schedule,
                                  color: Colors.orange,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
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