import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import '../models/profile.dart';
import '../models/service.dart';
import '../models/queue.dart';

class EnhancedQueueProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  // State variables
  Profile? _currentProfile;
  List<Service> _services = [];
  List<QueueTicket> _userTickets = [];
  List<QueueTicket> _adminTickets = [];
  List<ServiceStatus> _serviceStatuses = [];
  bool _isOnline = true;
  bool _isLoading = false;
  String? _error;
  
  // Subscriptions and timers
  StreamSubscription? _statusSubscription;
  StreamSubscription? _queueSubscription;
  Timer? _reconnectTimer;
  Timer? _offlineQueueTimer;
  
  // Offline support
  final List<Map<String, dynamic>> _offlineActions = [];
  SharedPreferences? _prefs;
  
  // Getters
  Profile? get currentProfile => _currentProfile;
  List<Service> get services => _services;
  List<QueueTicket> get userTickets => _userTickets;
  List<QueueTicket> get adminTickets => _adminTickets;
  List<ServiceStatus> get serviceStatuses => _serviceStatuses;
  bool get isOnline => _isOnline;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  EnhancedQueueProvider() {
    _initializeOfflineSupport();
    _startConnectionMonitoring();
  }
  
  Future<void> _initializeOfflineSupport() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadOfflineData();
  }
  
  void _startConnectionMonitoring() {
    _reconnectTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkConnection();
    });
  }
  
  Future<void> _checkConnection() async {
    try {
      final response = await _supabase.from('services').select('id').limit(1);
      if (!_isOnline) {
        _setOnlineStatus(true);
        await _syncOfflineActions();
      }
    } catch (e) {
      if (_isOnline) {
        _setOnlineStatus(false);
      }
    }
  }
  
  void _setOnlineStatus(bool status) {
    if (_isOnline != status) {
      _isOnline = status;
      notifyListeners();
      
      if (status) {
        debugPrint('Connection restored - syncing offline data');
      } else {
        debugPrint('Connection lost - switching to offline mode');
      }
    }
  }
  
  Future<void> _saveOfflineData() async {
    if (_prefs != null) {
      await _prefs!.setString('cached_services', jsonEncode(_services.map((s) => {
        'id': s.id,
        'name': s.name,
        'window': s.window,
      }).toList()));
      
      await _prefs!.setString('cached_tickets', jsonEncode(_userTickets.map((t) => {
        'id': t.id,
        'service_id': t.serviceId,
        'user_id': t.userId,
        'ticket_number': t.ticketNumber,
        'status': t.status,
        'queue_date': t.queueDate.toIso8601String(),
        'created_at': t.createdAt.toIso8601String(),
      }).toList()));
    }
  }
  
  Future<void> _loadOfflineData() async {
    if (_prefs != null) {
      final servicesJson = _prefs!.getString('cached_services');
      if (servicesJson != null) {
        final servicesList = jsonDecode(servicesJson) as List;
        _services = servicesList.map((s) => Service(
          id: s['id'],
          name: s['name'],
          window: s['window'],
        )).toList();
      }
      
      final ticketsJson = _prefs!.getString('cached_tickets');
      if (ticketsJson != null) {
        final ticketsList = jsonDecode(ticketsJson) as List;
        _userTickets = ticketsList.map((t) => QueueTicket(
          id: t['id'],
          serviceId: t['service_id'],
          userId: t['user_id'],
          ticketNumber: t['ticket_number'],
          status: t['status'],
          queueDate: DateTime.parse(t['queue_date']),
          createdAt: DateTime.parse(t['created_at']),
        )).toList();
      }
    }
  }
  
  void _addOfflineAction(String action, Map<String, dynamic> data) {
    _offlineActions.add({
      'action': action,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  Future<void> _syncOfflineActions() async {
    for (final action in _offlineActions) {
      try {
        switch (action['action']) {
          case 'generate_ticket':
            await _executeGenerateTicket(action['data']);
            break;
          case 'update_ticket_status':
            await _executeUpdateTicketStatus(action['data']);
            break;
          case 'update_service_status':
            await _executeUpdateServiceStatus(action['data']);
            break;
        }
      } catch (e) {
        debugPrint('Failed to sync offline action: $e');
        continue;
      }
    }
    _offlineActions.clear();
  }
  
  Future<void> loadProfile() async {
    await _executeWithErrorHandling(() async {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final response = await _supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .single();
        _currentProfile = Profile.fromJson(response);
      }
    });
  }
  
  Future<void> loadServices() async {
    debugPrint('🔄 Loading services...');
    
    await _executeWithErrorHandling(() async {
      final response = await _supabase
          .from('services')
          .select()
          .order('service_window');
      
      debugPrint('📦 Received ${response.length} services from database');
      
      _services = response.map<Service>((json) {
        return Service.fromJson(json);
      }).toList();
      
      debugPrint('✅ Parsed ${_services.length} services');
      for (var service in _services) {
        debugPrint('  - ${service.name} (Window ${service.window})');
      }
      
      await _saveOfflineData();
      notifyListeners(); // CRITICAL: Must notify listeners
    });
  }


    
    Future<void> loadServiceStatuses() async {
      await _executeWithErrorHandling(() async {
        final response = await _supabase.from('service_status').select();
        _serviceStatuses = response.map<ServiceStatus>((json) => ServiceStatus.fromJson(json)).toList();
      });
    }
    
    void subscribeToServiceStatus() {
      _statusSubscription?.cancel();
      
      if (_isOnline) {
        _statusSubscription = _supabase
            .from('service_status')
            .stream(primaryKey: ['id'])
            .listen((data) {
          _serviceStatuses = data.map<ServiceStatus>((json) => ServiceStatus.fromJson(json)).toList();
          notifyListeners();
        }, onError: (error) {
          debugPrint('Real-time subscription error: $error');
          _setOnlineStatus(false);
        });
      }
    }
  
  Future<String> generateTicket(String serviceId) async {
    final service = _services.firstWhere((s) => s.id == serviceId);
    final prefix = service.window == 1 ? 'A' : 'B';
    final userId = _supabase.auth.currentUser!.id;
    final today = DateTime.now().toIso8601String().split('T')[0];

    if (_isOnline) {
      return await _executeWithErrorHandling(() async {
        return await _executeGenerateTicket({'service_id': serviceId});
      }) ?? '';
    } else {
      // Offline mode checks

      // First check: User can only have ONE active ticket across ALL services today
      final activeTicket = _userTickets.firstWhere(
        (t) => t.queueDate.toIso8601String().split('T')[0] == today &&
               (t.status == 'waiting' || t.status == 'serving'),
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

      if (activeTicket.id.isNotEmpty) {
        final service = _services.firstWhere((s) => s.id == activeTicket.serviceId);
        throw Exception('You already have an active ticket (${activeTicket.ticketNumber}) for ${service.name}. Please wait for your turn or complete your current ticket before getting a new one.');
      }

      // Second check: User cannot get another ticket for the SAME service today (even if previous was completed)
      final existingTicketForService = _userTickets.firstWhere(
        (t) => t.serviceId == serviceId &&
               t.queueDate.toIso8601String().split('T')[0] == today,
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

      if (existingTicketForService.id.isNotEmpty) {
        final service = _services.firstWhere((s) => s.id == serviceId);
        throw Exception('You already received a ticket for ${service.name} today. Please try a different service or come back tomorrow.');
      }

      // Offline ticket generation
      // Count all tickets for this window today (across all services in that window)
      final window = service.window;
      final windowServices = _services.where((s) => s.window == window).map((s) => s.id).toList();

      final windowTicketsCount = _userTickets.where((t) =>
          t.queueDate.toIso8601String().split('T')[0] == today &&
          windowServices.contains(t.serviceId)).length;

      final nextNumber = windowTicketsCount + 1;
      final ticketNumber = '$prefix-${nextNumber.toString().padLeft(3, '0')}';

      // Create offline ticket
      final offlineTicket = QueueTicket(
        id: 'offline_${DateTime.now().millisecondsSinceEpoch}',
        serviceId: serviceId,
        userId: userId,
        ticketNumber: ticketNumber,
        status: 'waiting',
        queueDate: DateTime.now(),
        createdAt: DateTime.now(),
      );

      _userTickets.add(offlineTicket);
      _addOfflineAction('generate_ticket', {'service_id': serviceId});
      await _saveOfflineData();
      notifyListeners();

      return ticketNumber;
    }
  }
  
  Future<String> _executeGenerateTicket(Map<String, dynamic> data) async {
    final serviceId = data['service_id'];
    final userId = _supabase.auth.currentUser!.id;
    final today = DateTime.now().toIso8601String().split('T')[0];

    debugPrint('🎫 Generating ticket for service $serviceId, user $userId, date $today');

    // First check: User can only have ONE active ticket across ALL services today
    final activeTickets = await _supabase
        .from('queues')
        .select('*, services(name)')
        .eq('user_id', userId)
        .eq('queue_date', today)
        .inFilter('status', ['waiting', 'serving']);

    debugPrint('📋 Found ${activeTickets.length} active tickets for this user today');

    if (activeTickets.isNotEmpty) {
      final activeTicket = activeTickets.first;
      final ticketNumber = activeTicket['ticket_number'];
      final serviceName = activeTicket['services']?['name'] ?? 'Unknown Service';
      debugPrint('⚠️ User already has active ticket $ticketNumber for $serviceName');
      throw Exception('You already have an active ticket ($ticketNumber) for $serviceName. Please wait for your turn or complete your current ticket before getting a new one.');
    }

    // Second check: User cannot get another ticket for the SAME service today (even if previous was completed)
    // This matches the database constraint unique_ticket_per_day
    final existingTicketForService = await _supabase
        .from('queues')
        .select('*, services(name)')
        .eq('user_id', userId)
        .eq('service_id', serviceId)
        .eq('queue_date', today);

    debugPrint('📋 Found ${existingTicketForService.length} tickets for this specific service today');

    if (existingTicketForService.isNotEmpty) {
      final existingTicket = existingTicketForService.first;
      final ticketNumber = existingTicket['ticket_number'];
      final serviceName = existingTicket['services']?['name'] ?? 'Unknown Service';
      final status = existingTicket['status'];
      debugPrint('⚠️ User already got ticket $ticketNumber for $serviceName today (status: $status)');
      throw Exception('You already received a ticket for $serviceName today. Please try a different service or come back tomorrow.');
    }

    final service = _services.firstWhere((s) => s.id == serviceId);
    final window = service.window;

    debugPrint('🔢 Generating sequential ticket number for window $window using database function');

    // Use PostgreSQL function to generate sequential ticket number atomically
    // This prevents race conditions when multiple users request tickets simultaneously
    final ticketNumberResult = await _supabase
        .rpc('generate_ticket_number', params: {
          'p_queue_date': today,
          'p_window': window,
        });

    final ticketNumber = ticketNumberResult as String;

    debugPrint('✨ Generated ticket number: $ticketNumber for window $window');

    await _supabase.from('queues').insert({
      'service_id': serviceId,
      'user_id': userId,
      'ticket_number': ticketNumber,
    });

    debugPrint('✅ Ticket created successfully');
    await loadUserTickets();
    return ticketNumber;
  }
  
  Future<void> loadUserTickets() async {
    await _executeWithErrorHandling(() async {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final response = await _supabase
            .from('queues')
            .select('*, services(*)')
            .eq('user_id', user.id)
            .eq('queue_date', DateTime.now().toIso8601String().split('T')[0])
            .order('created_at');
        
        _userTickets = response.map<QueueTicket>((json) => QueueTicket.fromJson(json)).toList();
        await _saveOfflineData();
      }
    });
  }
  
  Future<void> loadAdminTickets(int window) async {
    await _executeWithErrorHandling(() async {
      debugPrint('🔍 Loading admin tickets for window $window');

      // First, get all service IDs for this window
      final servicesForWindow = _services.where((s) => s.window == window).toList();

      if (servicesForWindow.isEmpty) {
        debugPrint('⚠️ No services found for window $window, loading services first');
        await loadServices();
        servicesForWindow.addAll(_services.where((s) => s.window == window));
      }

      final serviceIds = servicesForWindow.map((s) => s.id).toList();
      debugPrint('📋 Service IDs for window $window: $serviceIds');

      if (serviceIds.isEmpty) {
        debugPrint('❌ No services available for window $window');
        _adminTickets = [];
        return;
      }

      // Now fetch tickets for these service IDs
      final response = await _supabase
          .from('queues')
          .select('*')
          .inFilter('service_id', serviceIds)
          .eq('queue_date', DateTime.now().toIso8601String().split('T')[0])
          .order('created_at');

      _adminTickets = response.map<QueueTicket>((json) => QueueTicket.fromJson(json)).toList();
      debugPrint('✅ Loaded ${_adminTickets.length} tickets for window $window');
    });
  }
  
  Future<void> updateServiceStatus(int window, String currentNumber) async {
    if (_isOnline) {
      await _executeWithErrorHandling(() async {
        await _executeUpdateServiceStatus({
          'service_window': window,  // Changed from 'window' to 'service_window'
          'current_number': currentNumber,
        });
      });
    } else {
      _addOfflineAction('update_service_status', {
        'service_window': window,  // Changed from 'window' to 'service_window'
        'current_number': currentNumber,
      });
    }
  }
  
  Future<void> _executeUpdateServiceStatus(Map<String, dynamic> data) async {
    debugPrint('📝 Updating service status for window ${data['service_window']} to ${data['current_number']}');

    try {
      // Use upsert to ensure record exists
      await _supabase
          .from('service_status')
          .upsert({
            'service_window': data['service_window'],
            'current_number': data['current_number'],
            'updated_at': DateTime.now().toIso8601String()
          }, onConflict: 'service_window');

      debugPrint('✅ Service status updated successfully');
    } catch (e) {
      debugPrint('❌ Failed to update service status: $e');
      rethrow;
    }
  }
  
  Future<void> updateTicketStatus(String ticketId, String status) async {
    if (_isOnline) {
      await _executeWithErrorHandling(() async {
        await _executeUpdateTicketStatus({
          'ticket_id': ticketId,
          'status': status,
        });
      });
    } else {
      // Update local ticket status
      final ticketIndex = _adminTickets.indexWhere((t) => t.id == ticketId);
      if (ticketIndex != -1) {
        final updatedTicket = QueueTicket(
          id: _adminTickets[ticketIndex].id,
          serviceId: _adminTickets[ticketIndex].serviceId,
          userId: _adminTickets[ticketIndex].userId,
          ticketNumber: _adminTickets[ticketIndex].ticketNumber,
          status: status,
          queueDate: _adminTickets[ticketIndex].queueDate,
          createdAt: _adminTickets[ticketIndex].createdAt,
          timeCalled: status == 'serving' ? DateTime.now() : _adminTickets[ticketIndex].timeCalled,
          finishedAt: status == 'done' ? DateTime.now() : _adminTickets[ticketIndex].finishedAt,
        );
        
        _adminTickets[ticketIndex] = updatedTicket;
      }
      
      _addOfflineAction('update_ticket_status', {
        'ticket_id': ticketId,
        'status': status,
      });
      
      notifyListeners();
    }
  }
  
  Future<void> _executeUpdateTicketStatus(Map<String, dynamic> data) async {
    final ticketId = data['ticket_id'];
    final status = data['status'];

    debugPrint('📝 Updating ticket $ticketId to status: $status');

    final updateData = {'status': status};
    if (status == 'serving') {
      updateData['time_called'] = DateTime.now().toIso8601String();
    } else if (status == 'done') {
      updateData['finished_at'] = DateTime.now().toIso8601String();
    }

    try {
      await _supabase.from('queues').update(updateData).eq('id', ticketId);
      debugPrint('✅ Ticket status updated successfully');
    } catch (e) {
      debugPrint('❌ Failed to update ticket status: $e');
      rethrow;
    }
  }
  
  Future<Map<String, dynamic>> getDailyAnalytics() async {
    return await _executeWithErrorHandling(() async {
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      final analytics = await _supabase
          .from('queue_analytics')
          .select()
          .eq('date', today)
          .single();
          
      return analytics;
    }) ?? {
      'total_tickets': 0,
      'completed_tickets': 0,
      'avg_wait_minutes': 0,
      'window_1_count': 0,
      'window_2_count': 0,
    };
  }
  
  Future<T?> _executeWithErrorHandling<T>(Future<T> Function() operation) async {
    try {
      _setLoading(true);
      _clearError();

      final result = await operation();

      if (!_isOnline) {
        _setOnlineStatus(true);
      }

      return result;
    } catch (e) {
      debugPrint('❌ Operation failed: $e');

      String errorMessage;

      // Parse PostgreSQL errors for user-friendly messages
      if (e.toString().contains('duplicate key value violates unique constraint')) {
        if (e.toString().contains('unique_ticket_per_day')) {
          errorMessage = 'You already have a ticket for this service today. Please check your active tickets.';
        } else {
          errorMessage = 'This record already exists.';
        }
      } else if (e.toString().contains('network') ||
          e.toString().contains('connection') ||
          e.toString().contains('timeout')) {
        _setOnlineStatus(false);
        errorMessage = 'Network connection issue. Please check your internet connection.';
      } else if (e.toString().contains('Exception:')) {
        // Extract custom exception messages
        errorMessage = e.toString().replaceAll('Exception:', '').trim();
      } else {
        errorMessage = e.toString();
      }

      _setError(errorMessage);
      return null;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void _setError(String? error) {
    if (_error != error) {
      _error = error;
      notifyListeners();
    }
  }

  void _clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  void clearError() {
    _clearError();
  }

  // Helper method to get service name by ID
  String getServiceName(String serviceId) {
    try {
      final service = _services.firstWhere((s) => s.id == serviceId);
      return service.name;
    } catch (e) {
      return 'Unknown Service';
    }
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _queueSubscription?.cancel();
    _reconnectTimer?.cancel();
    _offlineQueueTimer?.cancel();
    super.dispose();
  }

}