import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/queue_provider.dart';
import '../models/service.dart';

class ServiceSelectionScreen extends StatefulWidget {
  const ServiceSelectionScreen({super.key});

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select a Service'),
      ),
      body: Consumer<EnhancedQueueProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.services.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await provider.loadServices();
            },
            child: provider.services.isEmpty
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
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () async {
                            await provider.loadServices();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh Services'),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${provider.services.length} services available',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...provider.services.map((service) {
                          final color = service.window == 1 ? Colors.blue : Colors.green;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.medical_services,
                                  color: color,
                                ),
                              ),
                              title: Text(
                                service.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text('Window ${service.window}'),
                              trailing: ElevatedButton.icon(
                                onPressed: provider.isLoading
                                    ? null
                                    : () => _generateTicket(service, provider),
                                icon: const Icon(Icons.receipt_long),
                                label: const Text('Get Ticket'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: color,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }

  Future<void> _generateTicket(Service service, EnhancedQueueProvider provider) async {
    try {
      final ticketNumber = await provider.generateTicket(service.id);

      // Check if ticket generation failed (returns empty string on error)
      if (ticketNumber.isEmpty) {
        throw Exception(provider.error ?? 'Failed to generate ticket');
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ticket $ticketNumber generated for ${service.name}!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        // Extract clean error message
        String errorMessage = error.toString();
        if (errorMessage.startsWith('Exception:')) {
          errorMessage = errorMessage.replaceAll('Exception:', '').trim();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}
