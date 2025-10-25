import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/queue_provider.dart';
import '../models/queue.dart';

class QueueControlScreen extends StatefulWidget {
  final int serviceWindow;

  const QueueControlScreen({super.key, required this.serviceWindow});

  @override
  _QueueControlScreenState createState() => _QueueControlScreenState();
}

class _QueueControlScreenState extends State<QueueControlScreen> {
  @override
  void initState() {
    super.initState();
    final provider = Provider.of<EnhancedQueueProvider>(context, listen: false);
    provider.loadServiceStatuses(); // Load service statuses first
    provider.loadAdminTickets(widget.serviceWindow);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EnhancedQueueProvider>(
      builder: (context, provider, child) {
        final status = provider.serviceStatuses.firstWhere(
          (s) => s.serviceWindow == widget.serviceWindow,
          orElse: () => ServiceStatus(serviceWindow: widget.serviceWindow, updatedAt: DateTime.now()),
        );
        
        final waitingTickets = provider.adminTickets
            .where((t) => t.status == 'waiting')
            .toList();

        final servingTickets = provider.adminTickets
            .where((t) => t.status == 'serving')
            .toList();

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Current Serving - Enhanced with elevation and color
              Card(
                elevation: 8,
                color: status.currentNumber != null && status.currentNumber!.isNotEmpty
                    ? Colors.green.shade50
                    : Colors.grey.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            status.currentNumber != null && status.currentNumber!.isNotEmpty
                                ? Icons.person
                                : Icons.hourglass_empty,
                            size: 28,
                            color: status.currentNumber != null && status.currentNumber!.isNotEmpty
                                ? Colors.green
                                : Colors.grey,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Currently Serving',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        status.currentNumber ?? 'None',
                        style: TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.bold,
                          color: status.currentNumber != null && status.currentNumber!.isNotEmpty
                              ? Colors.green.shade700
                              : Colors.grey.shade400,
                        ),
                      ),
                      if (servingTickets.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            provider.getServiceName(servingTickets.first.serviceId),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Primary Action Buttons - Large and prominent
              Row(
                children: [
                  // Next Button - Large (most used)
                  Expanded(
                    flex: 5,
                    child: ElevatedButton.icon(
                      onPressed: waitingTickets.isNotEmpty &&
                                 (status.currentNumber == null || status.currentNumber!.isEmpty)
                          ? () => _callNext(provider, waitingTickets.first)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      icon: const Icon(Icons.skip_next, size: 28),
                      label: const Text(
                        'NEXT',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Done Button - Large (most used)
                  Expanded(
                    flex: 5,
                    child: ElevatedButton.icon(
                      onPressed: status.currentNumber != null && status.currentNumber!.isNotEmpty
                          ? () => _markDone(provider)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      icon: const Icon(Icons.check_circle, size: 28),
                      label: const Text(
                        'DONE',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Skip Button - Small (rarely used)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: status.currentNumber != null && status.currentNumber!.isNotEmpty
                      ? () => _skipCurrent(provider)
                      : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.refresh, size: 20),
                  label: const Text(
                    'Return to Queue',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Queue Header with count badge
              Row(
                children: [
                  const Icon(Icons.queue, size: 24, color: Colors.blueGrey),
                  const SizedBox(width: 8),
                  const Text(
                    'Waiting Queue',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: waitingTickets.isEmpty ? Colors.grey.shade300 : Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${waitingTickets.length}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: waitingTickets.isEmpty ? Colors.grey.shade600 : Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Waiting Queue List - Improved cards
              Expanded(
                child: waitingTickets.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              'No tickets waiting',
                              style: TextStyle(fontSize: 18, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: waitingTickets.length,
                        itemBuilder: (context, index) {
                          final ticket = waitingTickets[index];
                          final isNext = index == 0;
                          return Card(
                            elevation: isNext ? 4 : 1,
                            margin: const EdgeInsets.only(bottom: 12),
                            color: isNext ? Colors.blue.shade50 : null,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  // Position indicator
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: isNext ? Colors.blue : Colors.grey.shade400,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Ticket number
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade700,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      ticket.ticketNumber,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          provider.getServiceName(ticket.serviceId),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                                            const SizedBox(width: 4),
                                            Text(
                                              _calculateWaitTime(ticket.createdAt),
                                              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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
    try {
      await provider.updateTicketStatus(ticket.id, 'serving');
      await provider.updateServiceStatus(widget.serviceWindow, ticket.ticketNumber);
      await provider.loadServiceStatuses(); // Reload service statuses after update
      await provider.loadAdminTickets(widget.serviceWindow);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Now serving: ${ticket.ticketNumber}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error calling ticket: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markDone(EnhancedQueueProvider provider) async {
    try {
      final status = provider.serviceStatuses.firstWhere(
        (s) => s.serviceWindow == widget.serviceWindow,
        orElse: () => throw Exception('No service status found for window ${widget.serviceWindow}'),
      );

      if (status.currentNumber == null || status.currentNumber!.isEmpty) {
        throw Exception('No ticket is currently being served');
      }

      final currentTicket = provider.adminTickets.firstWhere(
        (t) => t.ticketNumber == status.currentNumber && t.status == 'serving',
        orElse: () => throw Exception('Current serving ticket not found'),
      );

      await provider.updateTicketStatus(currentTicket.id, 'done');
      await provider.updateServiceStatus(widget.serviceWindow, '');
      await provider.loadServiceStatuses(); // Reload service statuses after update
      await provider.loadAdminTickets(widget.serviceWindow);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ticket ${status.currentNumber} marked as done'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _skipCurrent(EnhancedQueueProvider provider) async {
    try {
      final status = provider.serviceStatuses.firstWhere(
        (s) => s.serviceWindow == widget.serviceWindow,
        orElse: () => throw Exception('No service status found for window ${widget.serviceWindow}'),
      );

      if (status.currentNumber == null || status.currentNumber!.isEmpty) {
        throw Exception('No ticket is currently being served');
      }

      final currentTicket = provider.adminTickets.firstWhere(
        (t) => t.ticketNumber == status.currentNumber && t.status == 'serving',
        orElse: () => throw Exception('Current serving ticket not found'),
      );

      // Put the ticket back in waiting queue instead of marking as skipped
      await provider.updateTicketStatus(currentTicket.id, 'waiting');
      await provider.updateServiceStatus(widget.serviceWindow, '');
      await provider.loadServiceStatuses(); // Reload service statuses after update
      await provider.loadAdminTickets(widget.serviceWindow);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ticket ${status.currentNumber} returned to waiting queue'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}