import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/queue_provider.dart';
import '../models/queue.dart';
import '../models/service.dart';

class EnhancedQueueDisplay extends StatefulWidget {
  const EnhancedQueueDisplay({Key? key}) : super(key: key);

  @override
  _EnhancedQueueDisplayState createState() => _EnhancedQueueDisplayState();
}

class _EnhancedQueueDisplayState extends State<EnhancedQueueDisplay>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));
    
    _pulseController.repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EnhancedQueueProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [
            // Connection Status Banner
            _buildConnectionBanner(provider),
            
            // Error Banner
            if (provider.error != null) _buildErrorBanner(provider),
            
            // Queue Status Cards
            _buildQueueStatusCards(provider),
            
            // User's Active Tickets
            if (provider.userTickets.isNotEmpty) 
              _buildActiveTickets(provider),
            
            // Service Selection
            _buildServiceSelection(provider),
          ],
        );
      },
    );
  }

  Widget _buildConnectionBanner(EnhancedQueueProvider provider) {
    if (provider.isOnline) return const SizedBox.shrink();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.orange.shade100,
      child: Row(
        children: [
          Icon(Icons.wifi_off, color: Colors.orange.shade800, size: 20),
          const SizedBox(width: 8),
          Text(
            'Working offline - Changes will sync when reconnected',
            style: TextStyle(
              color: Colors.orange.shade800,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(EnhancedQueueProvider provider) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          border: Border.all(color: Colors.red.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Something went wrong',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade800,
                    ),
                  ),
                  Text(
                    provider.error!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, color: Colors.red.shade600),
              onPressed: () {
                // Call the internal method _clearError through the provider
                // Since clearError() should exist in EnhancedQueueProvider
                try {
                  provider.clearError();
                } catch (e) {
                  debugPrint('Error clearing error: $e');
                }
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueStatusCards(EnhancedQueueProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildWindowStatusCard(provider, 1, Colors.blue),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildWindowStatusCard(provider, 2, Colors.green),
          ),
        ],
      ),
    );
  }

  Widget _buildWindowStatusCard(
    EnhancedQueueProvider provider, 
    int window, 
    Color color,
  ) {
    final status = provider.serviceStatuses.firstWhere(
      (s) => s.serviceWindow == window,
      orElse: () => ServiceStatus(
        serviceWindow: window,
        updatedAt: DateTime.now(),
      ),
    );
    
    final isUserTurn = provider.userTickets.any((ticket) => 
      ticket.ticketNumber == status.currentNumber && 
      ticket.status == 'serving'
    );

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: isUserTurn ? _pulseAnimation.value : 1.0,
          child: Card(
            elevation: isUserTurn ? 8 : 4,
            color: isUserTurn ? color.withOpacity(0.1) : null,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: isUserTurn 
                  ? Border.all(color: color, width: 2)
                  : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.window,
                        color: color,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Window $window',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Now Serving',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status.currentNumber ?? 'None',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  if (isUserTurn) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'YOUR TURN!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveTickets(EnhancedQueueProvider provider) {
    final activeTickets = provider.userTickets
        .where((t) => t.status != 'done' && t.status != 'skipped' && t.status != 'cancelled')
        .toList();

    if (activeTickets.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Active Tickets',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
          ...activeTickets.map((ticket) => _buildTicketCard(ticket, provider)),
        ],
      ),
    );
  }

  Widget _buildTicketCard(QueueTicket ticket, EnhancedQueueProvider provider) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (ticket.status) {
      case 'waiting':
        statusColor = Colors.orange;
        statusText = 'Waiting';
        statusIcon = Icons.schedule;
        break;
      case 'serving':
        statusColor = Colors.green;
        statusText = 'Being Served';
        statusIcon = Icons.person;
        break;
      default:
        statusColor = Colors.grey;
        statusText = ticket.status.toUpperCase();
        statusIcon = Icons.help_outline;
    }

    final queuePosition = _calculateQueuePosition(ticket, provider);
    final estimatedWait = _calculateEstimatedWait(queuePosition);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: ticket.status == 'serving' ? 6 : 2,
      child: Container(
        decoration: ticket.status == 'serving'
            ? BoxDecoration(
                border: Border.all(color: statusColor, width: 2),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: statusColor.withOpacity(0.2),
            child: Icon(statusIcon, color: statusColor),
          ),
          title: Text(
            _getServiceName(ticket.serviceId, provider),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ticket: ${ticket.ticketNumber}'),
              Text(
                '$statusText${ticket.status == 'waiting' ? ' • Position: $queuePosition • Est. wait: ${estimatedWait}m' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
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
              : ticket.status == 'waiting'
                  ? IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () => _showCancelDialog(context, ticket, provider),
                      tooltip: 'Cancel Ticket',
                    )
                  : null,
        ),
      ),
    );
  }

  void _showCancelDialog(BuildContext context, QueueTicket ticket, EnhancedQueueProvider provider) {
    showDialog(
      context: context,
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
              Text('Are you sure you want to cancel this ticket?'),
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
                    Text(_getServiceName(ticket.serviceId, provider)),
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

  Widget _buildServiceSelection(EnhancedQueueProvider provider) {
    final window1Services = provider.services.where((s) => s.window == 1).toList();
    final window2Services = provider.services.where((s) => s.window == 2).toList();

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Get New Ticket',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 16),
          _buildWindowServices('Window 1', window1Services, Colors.blue, provider),
          const SizedBox(height: 16),
          _buildWindowServices('Window 2', window2Services, Colors.green, provider),
        ],
      ),
    );
  }

  Widget _buildWindowServices(
    String windowTitle,
    List<Service> services,
    Color color,
    EnhancedQueueProvider provider,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.window, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  windowTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: services.map((service) => _buildServiceChip(
                service,
                color,
                provider,
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceChip(
    Service service,
    Color color,
    EnhancedQueueProvider provider,
  ) {
    final isLoading = provider.isLoading;
    
    return ActionChip(
      label: Text(
        service.name,
        style: TextStyle(
          color: color.withOpacity(0.8),
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color.withOpacity(0.3)),
      onPressed: isLoading 
          ? null 
          : () => _generateTicket(service, provider),
      avatar: isLoading 
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            )
          : Icon(
              Icons.confirmation_number,
              color: color,
              size: 18,
            ),
    );
  }

  int _calculateQueuePosition(QueueTicket ticket, EnhancedQueueProvider provider) {
    // Get all tickets from the admin queue for the same window
    final serviceWindow = _getServiceWindow(ticket.serviceId, provider);
    final allWaitingTickets = provider.adminTickets
        .where((t) =>
            t.status == 'waiting' &&
            _getServiceWindow(t.serviceId, provider) == serviceWindow)
        .toList();

    // Sort by creation time to get actual queue order
    allWaitingTickets.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Find position (1-indexed)
    final position = allWaitingTickets.indexWhere((t) => t.id == ticket.id) + 1;
    return position > 0 ? position : 1;
  }

  int _calculateEstimatedWait(int position) {
    // More realistic estimate: 3-5 minutes average service time
    // Position accounts for people ahead in queue
    if (position <= 1) return 0; // Next in line
    return (position - 1) * 4; // 4 minutes average per person
  }

  String _getServiceName(String serviceId, EnhancedQueueProvider provider) {
    final service = provider.services.firstWhere(
      (s) => s.id == serviceId,
      orElse: () => Service(id: serviceId, name: 'Unknown Service', window: 1),
    );
    return service.name;
  }

  int _getServiceWindow(String serviceId, EnhancedQueueProvider provider) {
    final service = provider.services.firstWhere(
      (s) => s.id == serviceId,
      orElse: () => Service(id: serviceId, name: 'Unknown Service', window: 1),
    );
    return service.window;
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _generateTicket(Service service, EnhancedQueueProvider provider) async {
    try {
      final ticketNumber = await provider.generateTicket(service.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('Ticket $ticketNumber generated for ${service.name}'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed to generate ticket: $error')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }
}