import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/queue_provider.dart';
import '../models/queue.dart';
import '../models/service.dart';

class EnhancedAdminControlPanel extends StatefulWidget {
  final int window;
  
  const EnhancedAdminControlPanel({
    Key? key,
    required this.window,
  }) : super(key: key);

  @override
  _EnhancedAdminControlPanelState createState() => _EnhancedAdminControlPanelState();
}

class _EnhancedAdminControlPanelState extends State<EnhancedAdminControlPanel>
    with TickerProviderStateMixin {
  late AnimationController _numberController;
  late AnimationController _buttonController;
  late Animation<double> _numberAnimation;
  late Animation<double> _buttonAnimation;
  
  String? _lastCalledNumber;
  
  @override
  void initState() {
    super.initState();
    _setupAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EnhancedQueueProvider>().loadAdminTickets(widget.window);
    });
  }

  void _setupAnimations() {
    _numberController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _numberAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _numberController,
      curve: Curves.elasticOut,
    ));
    
    _buttonAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _buttonController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EnhancedQueueProvider>(
      builder: (context, provider, child) {
        final status = provider.serviceStatuses.firstWhere(
          (s) => s.window == widget.window,
          orElse: () => ServiceStatus(
            window: widget.window,
            updatedAt: DateTime.now(),
          ),
        );
        
        final waitingTickets = provider.adminTickets
            .where((t) => t.status == 'waiting')
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        
        final servingTicket = provider.adminTickets
            .where((t) => t.status == 'serving')
            .firstWhere(
              (t) => t.ticketNumber == status.currentNumber,
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

        // Trigger animation when number changes
        if (status.currentNumber != _lastCalledNumber && status.currentNumber != null) {
          _lastCalledNumber = status.currentNumber;
          _numberController.forward().then((_) {
            _numberController.reverse();
          });
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current Status Card
              _buildCurrentStatusCard(status, servingTicket, provider),
              
              const SizedBox(height: 20),
              
              // Control Buttons
              _buildControlButtons(status, waitingTickets, provider),
              
              const SizedBox(height: 20),
              
              // Queue Statistics
              _buildQueueStats(waitingTickets, provider),
              
              const SizedBox(height: 20),
              
              // Waiting Queue List
              _buildWaitingQueue(waitingTickets, provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCurrentStatusCard(
    ServiceStatus status,
    QueueTicket? servingTicket,
    EnhancedQueueProvider provider,
  ) {
    final isServing = status.currentNumber != null;
    final cardColor = isServing ? Colors.green.shade50 : Colors.grey.shade50;
    final borderColor = isServing ? Colors.green : Colors.grey.shade300;

    return AnimatedBuilder(
      animation: _numberAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _numberAnimation.value,
          child: Card(
            elevation: isServing ? 8 : 4,
            color: cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: borderColor, width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Window ${widget.window}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      if (!provider.isOnline)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'OFFLINE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Currently Serving',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isServing ? Colors.green : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Text(
                      status.currentNumber ?? 'None',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: isServing ? Colors.white : Colors.grey.shade600,
                      ),
                    ),
                  ),
                  if (isServing && servingTicket?.id.isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Service: ${_getServiceName(servingTicket!.serviceId, provider)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Wait time: ${_calculateWaitTime(servingTicket.createdAt, servingTicket.timeCalled)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
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

  Widget _buildControlButtons(
    ServiceStatus status,
    List<QueueTicket> waitingTickets,
    EnhancedQueueProvider provider,
  ) {
    final canCallNext = waitingTickets.isNotEmpty;
    final canComplete = status.currentNumber != null;
    final isLoading = provider.isLoading;

    return Row(
      children: [
        Expanded(
          child: AnimatedBuilder(
            animation: _buttonAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _buttonAnimation.value,
                child: ElevatedButton.icon(
                  onPressed: canCallNext && !isLoading 
                      ? () => _callNext(waitingTickets.first, provider)
                      : null,
                  icon: isLoading 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(Icons.play_arrow),
                  label: const Text('Call Next'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: canComplete && !isLoading 
                ? () => _markComplete(provider)
                : null,
            icon: const Icon(Icons.check),
            label: const Text('Complete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: canComplete && !isLoading 
                ? () => _skipCurrent(provider)
                : null,
            icon: const Icon(Icons.skip_next),
            label: const Text('Skip'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQueueStats(
    List<QueueTicket> waitingTickets,
    EnhancedQueueProvider provider,
  ) {
    final totalToday = provider.adminTickets.length;
    final completed = provider.adminTickets.where((t) => t.status == 'done').length;
    final skipped = provider.adminTickets.where((t) => t.status == 'skipped').length;
    final avgWaitTime = _calculateAverageWaitTime(provider.adminTickets);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today\'s Statistics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Waiting',
                    waitingTickets.length.toString(),
                    Colors.orange,
                    Icons.schedule,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Completed',
                    completed.toString(),
                    Colors.green,
                    Icons.check_circle,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Total Today',
                    totalToday.toString(),
                    Colors.blue,
                    Icons.people,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Avg Wait',
                    '${avgWaitTime.toStringAsFixed(1)}m',
                    Colors.purple,
                    Icons.timer,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildWaitingQueue(
    List<QueueTicket> waitingTickets,
    EnhancedQueueProvider provider,
  ) {
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
                  'Waiting Queue (${waitingTickets.length})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => provider.loadAdminTickets(widget.window),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (waitingTickets.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No tickets waiting',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: waitingTickets.length,
                itemBuilder: (context, index) {
                  final ticket = waitingTickets[index];
                  final position = index + 1;
                  final estimatedWait = position * 5;
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: position == 1 ? 4 : 1,
                    color: position == 1 ? Colors.green.shade50 : null,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: position == 1 ? Colors.green : Colors.blue,
                        foregroundColor: Colors.white,
                        child: Text(
                          position.toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              ticket.ticketNumber,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _getServiceName(ticket.serviceId, provider),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Wait time: ${_calculateWaitTime(ticket.createdAt, null)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            'Est. service in: ${estimatedWait}m',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      trailing: position == 1
                          ? ElevatedButton(
                              onPressed: () => _callNext(ticket, provider),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Call'),
                            )
                          : OutlinedButton(
                              onPressed: () => _callSpecific(ticket, provider),
                              child: const Text('Call'),
                            ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  String _getServiceName(String serviceId, EnhancedQueueProvider provider) {
    final service = provider.services.firstWhere(
      (s) => s.id == serviceId,
      orElse: () => Service(id: serviceId, name: 'Unknown Service', window: 1),
    );
    return service.name;
  }

  String _calculateWaitTime(DateTime createdAt, DateTime? calledAt) {
    final endTime = calledAt ?? DateTime.now();
    final difference = endTime.difference(createdAt);
    final minutes = difference.inMinutes;
    return '${minutes}m';
  }

  double _calculateAverageWaitTime(List<QueueTicket> tickets) {
    final completedTickets = tickets.where((t) => 
        t.status == 'done' && t.timeCalled != null).toList();
    
    if (completedTickets.isEmpty) return 0.0;
    
    final totalMinutes = completedTickets.fold<int>(0, (sum, ticket) {
      return sum + ticket.timeCalled!.difference(ticket.createdAt).inMinutes;
    });
    
    return totalMinutes / completedTickets.length;
  }

  void _callNext(QueueTicket ticket, EnhancedQueueProvider provider) {
    _animateButtonPress(() async {
      await provider.updateTicketStatus(ticket.id, 'serving');
      await provider.updateServiceStatus(widget.window, ticket.ticketNumber);
      await provider.loadAdminTickets(widget.window);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Called ticket ${ticket.ticketNumber}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  void _callSpecific(QueueTicket ticket, EnhancedQueueProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Call Ticket'),
        content: Text(
          'Call ${ticket.ticketNumber} out of order?\n\n'
          'This will skip ahead in the queue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _callNext(ticket, provider);
            },
            child: const Text('Call Now'),
          ),
        ],
      ),
    );
  }

  void _markComplete(EnhancedQueueProvider provider) {
    _animateButtonPress(() async {
      final status = provider.serviceStatuses.firstWhere(
        (s) => s.window == widget.window,
      );
      
      final currentTicket = provider.adminTickets.firstWhere(
        (t) => t.ticketNumber == status.currentNumber && t.status == 'serving',
      );
      
      await provider.updateTicketStatus(currentTicket.id, 'done');
      await provider.updateServiceStatus(widget.window, '');
      await provider.loadAdminTickets(widget.window);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Completed service for ${currentTicket.ticketNumber}'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    });
  }

  void _skipCurrent(EnhancedQueueProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip Current Ticket'),
        content: const Text(
          'Skip the current ticket? The student will need to get a new ticket.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _performSkip(provider);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Skip'),
          ),
        ],
      ),
    );
  }

  void _performSkip(EnhancedQueueProvider provider) {
    _animateButtonPress(() async {
      final status = provider.serviceStatuses.firstWhere(
        (s) => s.window == widget.window,
      );
      
      final currentTicket = provider.adminTickets.firstWhere(
        (t) => t.ticketNumber == status.currentNumber && t.status == 'serving',
      );
      
      await provider.updateTicketStatus(currentTicket.id, 'skipped');
      await provider.updateServiceStatus(widget.window, '');
      await provider.loadAdminTickets(widget.window);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Skipped ticket ${currentTicket.ticketNumber}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });
  }

  void _animateButtonPress(VoidCallback onPressed) {
    _buttonController.forward().then((_) {
      _buttonController.reverse();
      onPressed();
    });
  }

  @override
  void dispose() {
    _numberController.dispose();
    _buttonController.dispose();
    super.dispose();
  }
}