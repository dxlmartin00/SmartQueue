import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/queue_provider.dart';

class ServiceSelectionScreen extends StatefulWidget {
  final int serviceWindow;

  const ServiceSelectionScreen({super.key, required this.serviceWindow});

  @override
  State<ServiceSelectionScreen> createState() => _ServiceSelectionScreenState();
}

class _ServiceSelectionScreenState extends State<ServiceSelectionScreen> {
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load services only once
    if (!_isInitialized) {
      _isInitialized = true;
      final provider = Provider.of<EnhancedQueueProvider>(context, listen: false);
      if (provider.services.isEmpty) {
        provider.loadServices();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EnhancedQueueProvider>(
      builder: (context, provider, child) {
        final services = provider.services
            .where((s) => s.window == widget.serviceWindow)
            .toList();
        
        return Scaffold(
          appBar: AppBar(
            title: Text('Select Service - Window ${widget.serviceWindow}'),
          ),
          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : services.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No services available',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Window ${widget.serviceWindow}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: services.length,
                      itemBuilder: (context, index) {
                        final service = services[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: widget.serviceWindow == 1
                                    ? Colors.blue.shade100
                                    : Colors.green.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.medical_services,
                                color: widget.serviceWindow == 1
                                    ? Colors.blue.shade700
                                    : Colors.green.shade700,
                              ),
                            ),
                            title: Text(
                              service.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text('Window ${widget.serviceWindow}'),
                            trailing: ElevatedButton.icon(
                              onPressed: provider.isLoading
                                  ? null
                                  : () async {
                                      try {
                                        final ticketNumber = await provider
                                            .generateTicket(service.id);
                                        if (mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Ticket $ticketNumber generated!',
                                              ),
                                              backgroundColor: Colors.green,
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      } catch (error) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text('Error: $error'),
                                              backgroundColor: Colors.red,
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      }
                                    },
                              icon: const Icon(Icons.receipt_long),
                              label: const Text('Get Ticket'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.serviceWindow == 1
                                    ? Colors.blue
                                    : Colors.green,
                                foregroundColor: Colors.white,
                              ),
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