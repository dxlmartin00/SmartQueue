import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/queue_provider.dart';
import '../models/queue.dart';

class QueueControlScreen extends StatefulWidget {
  final int window;

  const QueueControlScreen({super.key, required this.window});

  @override
  _QueueControlScreenState createState() => _QueueControlScreenState();
}

class _QueueControlScreenState extends State<QueueControlScreen> {
  @override
  void initState() {
    super.initState();
    Provider.of<EnhancedQueueProvider>(context, listen: false).loadAdminTickets(widget.window);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EnhancedQueueProvider>(
      builder: (context, provider, child) {
        final status = provider.serviceStatuses.firstWhere(
          (s) => s.window == widget.window,
          orElse: () => ServiceStatus(window: widget.window, updatedAt: DateTime.now()),
        );
        
        final waitingTickets = provider.adminTickets
            .where((t) => t.status == 'waiting')
            .toList();

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current Serving
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'Currently Serving',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        status.currentNumber ?? 'None',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Control Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: waitingTickets.isNotEmpty 
                        ? () => _callNext(provider, waitingTickets.first) 
                        : null,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('Next'),
                  ),
                  ElevatedButton(
                    onPressed: status.currentNumber != null 
                        ? () => _markDone(provider) 
                        : null,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                    child: const Text('Done'),
                  ),
                  ElevatedButton(
                    onPressed: status.currentNumber != null 
                        ? () => _skipCurrent(provider) 
                        : null,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    child: const Text('Skip'),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Waiting Queue
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
                    return Card(
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
                        subtitle: Text('Waiting time: ${_calculateWaitTime(ticket.createdAt)}'),
                        trailing: ElevatedButton(
                          onPressed: () => _callNext(provider, ticket),
                          child: const Text('Call'),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _calculateWaitTime(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    final minutes = diff.inMinutes;
    return '${minutes}m';
  }

  Future<void> _callNext(EnhancedQueueProvider provider, QueueTicket ticket) async {
    await provider.updateTicketStatus(ticket.id, 'serving');
    await provider.updateServiceStatus(widget.window, ticket.ticketNumber);
    provider.loadAdminTickets(widget.window);
  }

  Future<void> _markDone(EnhancedQueueProvider provider) async {
    final status = provider.serviceStatuses.firstWhere((s) => s.window == widget.window);
    final currentTicket = provider.adminTickets
        .firstWhere((t) => t.ticketNumber == status.currentNumber && t.status == 'serving');
    
    await provider.updateTicketStatus(currentTicket.id, 'done');
    await provider.updateServiceStatus(widget.window, '');
    provider.loadAdminTickets(widget.window);
  }

  Future<void> _skipCurrent(EnhancedQueueProvider provider) async {
    final status = provider.serviceStatuses.firstWhere((s) => s.window == widget.window);
    final currentTicket = provider.adminTickets
        .firstWhere((t) => t.ticketNumber == status.currentNumber && t.status == 'serving');
    
    await provider.updateTicketStatus(currentTicket.id, 'skipped');
    await provider.updateServiceStatus(widget.window, '');
    provider.loadAdminTickets(widget.window);
  }
}