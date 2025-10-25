import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import '../models/profile.dart';
import '../models/service.dart';
import '../models/queue.dart';
import '../models/transaction.dart';

class EnhancedQueueProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  // State variables
  Profile? _currentProfile;
  List<Service> _services = [];
  List<QueueTicket> _userTickets = [];
  List<QueueTicket> _adminTickets = [];
  List<ServiceStatus> _serviceStatuses = [];
  List<Transaction> _transactions = [];
  bool _isOnline = true;
  bool _isLoading = false;
  String? _error;
  
  // Subscriptions and timers
  StreamSubscription? _statusSubscription;
  StreamSubscription? _queueSubscription;
  Timer? _reconnectTimer;
  Timer? _offlineQueueTimer;
  Timer? _adminQueuePollingTimer;
  int? _currentAdminWindow;
  
  // Offline support
  final List<Map<String, dynamic>> _offlineActions = [];
  SharedPreferences? _prefs;
  
  // Getters
  Profile? get currentProfile => _currentProfile;
  List<Service> get services => _services;
  List<QueueTicket> get userTickets => _userTickets;
  List<QueueTicket> get adminTickets => _adminTickets;
  List<ServiceStatus> get serviceStatuses => _serviceStatuses;
  List<Transaction> get transactions => _transactions;
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
          case 'cancel_ticket':
            await _executeCancelTicket(action['data']['ticket_id']);
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

    void subscribeToAdminQueue(int window) {
      _queueSubscription?.cancel();
      _adminQueuePollingTimer?.cancel();
      _currentAdminWindow = window;

      if (_isOnline) {
        debugPrint('🔔 Starting admin queue updates for window $window');

        // Try real-time subscription first
        _attemptRealtimeSubscription(window);

        // Start polling as a backup (every 5 seconds)
        _startAdminQueuePolling(window);
      }
    }

    void _attemptRealtimeSubscription(int window) {
      try {
        final servicesForWindow = _services.where((s) => s.window == window).toList();
        if (servicesForWindow.isEmpty) {
          debugPrint('⚠️ No services found for window $window');
          return;
        }

        final serviceIds = servicesForWindow.map((s) => s.id).toList();
        final today = DateTime.now().toIso8601String().split('T')[0];

        debugPrint('📡 Attempting real-time subscription for window $window');

        _queueSubscription = _supabase
            .from('queues')
            .stream(primaryKey: ['id'])
            .listen((data) {
          try {
            debugPrint('📡 Real-time update: ${data.length} total tickets');

            // Filter for this window's services and today's date
            final windowTickets = data.where((json) {
              final serviceId = json['service_id'];
              final queueDate = json['queue_date'];
              return serviceIds.contains(serviceId) && queueDate == today;
            }).toList();

            _adminTickets = windowTickets.map<QueueTicket>((json) {
              return QueueTicket.fromJson(json);
            }).toList();

            debugPrint('✅ Real-time: Updated ${_adminTickets.length} tickets');
            notifyListeners();
          } catch (e) {
            debugPrint('❌ Error processing real-time data: $e');
          }
        }, onError: (error) {
          debugPrint('⚠️ Real-time subscription error: $error');
          debugPrint('   Falling back to polling only');
          _queueSubscription?.cancel();
          _queueSubscription = null;
        });
      } catch (e) {
        debugPrint('❌ Failed to create real-time subscription: $e');
        debugPrint('   Using polling only');
      }
    }

    void _startAdminQueuePolling(int window) {
      debugPrint('🔄 Starting polling for window $window (every 5 seconds)');

      _adminQueuePollingTimer?.cancel();
      _adminQueuePollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
        if (_currentAdminWindow == window && _isOnline) {
          try {
            await loadAdminTickets(window);
          } catch (e) {
            debugPrint('⚠️ Polling error: $e');
          }
        }
      });
    }

    void unsubscribeFromAdminQueue() {
      debugPrint('🔕 Unsubscribing from queue updates');
      _queueSubscription?.cancel();
      _queueSubscription = null;
      _adminQueuePollingTimer?.cancel();
      _adminQueuePollingTimer = null;
      _currentAdminWindow = null;
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
        .filter('status', 'in', '(waiting,serving)');

    debugPrint('📋 Found ${activeTickets.length} active tickets for this user today');

    if (activeTickets.isNotEmpty) {
      final activeTicket = activeTickets.first;
      final ticketNumber = activeTicket['ticket_number'];
      final serviceName = activeTicket['services']?['name'] ?? 'Unknown Service';
      debugPrint('⚠️ User already has active ticket $ticketNumber for $serviceName');
      throw Exception('You already have an active ticket ($ticketNumber) for $serviceName. Please wait for your turn or complete your current ticket before getting a new one.');
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

    // Store timestamp in UTC but adjusted for local time display
    // Supabase stores in UTC, so we add 8 hours to compensate
    final adjustedTime = DateTime.now().toUtc().add(const Duration(hours: 8));

    await _supabase.from('queues').insert({
      'service_id': serviceId,
      'user_id': userId,
      'ticket_number': ticketNumber,
      'status': 'waiting',
      'queue_date': today,
      'created_at': adjustedTime.toIso8601String(),
    });

    debugPrint('✅ Ticket created successfully: $ticketNumber');
    debugPrint('   Service ID: $serviceId');
    debugPrint('   User ID: $userId');
    debugPrint('   Queue Date: $today');

    await loadUserTickets();
    debugPrint('📋 User tickets reloaded. Count: ${_userTickets.length}');

    return ticketNumber;
  }
  
  Future<void> loadUserTickets() async {
    await _executeWithErrorHandling(() async {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final today = DateTime.now().toIso8601String().split('T')[0];
        debugPrint('🔍 Loading user tickets for user ${user.id}, date: $today');

        final response = await _supabase
            .from('queues')
            .select('*, services(*)')
            .eq('user_id', user.id)
            .eq('queue_date', today)
            .order('created_at');

        debugPrint('📦 Found ${response.length} tickets for user');

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
      // Convert service IDs to the format needed for filter: (id1,id2,id3)
      final serviceIdsString = '(${serviceIds.join(',')})';
      final response = await _supabase
          .from('queues')
          .select('*')
          .eq('queue_date', DateTime.now().toIso8601String().split('T')[0])
          .filter('service_id', 'in', serviceIdsString)
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

    // Store timestamp in UTC but adjusted for local time display
    final adjustedTime = DateTime.now().toUtc().add(const Duration(hours: 8));

    try {
      // Use upsert to ensure record exists
      await _supabase
          .from('service_status')
          .upsert({
            'service_window': data['service_window'],
            'current_number': data['current_number'],
            'updated_at': adjustedTime.toIso8601String()
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

    // Store timestamp in UTC but adjusted for local time display
    // Supabase stores in UTC, so we add 8 hours to compensate
    final adjustedTime = DateTime.now().toUtc().add(const Duration(hours: 8));

    final updateData = {'status': status};
    if (status == 'serving') {
      updateData['time_called'] = adjustedTime.toIso8601String();
    } else if (status == 'done') {
      updateData['finished_at'] = adjustedTime.toIso8601String();
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
        errorMessage = 'This record already exists.';
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

  // Cancel a ticket
  Future<void> cancelTicket(String ticketId) async {
    if (_isOnline) {
      await _executeWithErrorHandling(() async {
        await _executeCancelTicket(ticketId);
      });
    } else {
      // Update local ticket status
      final ticketIndex = _userTickets.indexWhere((t) => t.id == ticketId);
      if (ticketIndex != -1) {
        final updatedTicket = QueueTicket(
          id: _userTickets[ticketIndex].id,
          serviceId: _userTickets[ticketIndex].serviceId,
          userId: _userTickets[ticketIndex].userId,
          ticketNumber: _userTickets[ticketIndex].ticketNumber,
          status: 'cancelled',
          queueDate: _userTickets[ticketIndex].queueDate,
          createdAt: _userTickets[ticketIndex].createdAt,
          timeCalled: _userTickets[ticketIndex].timeCalled,
          finishedAt: _userTickets[ticketIndex].finishedAt,
        );

        _userTickets[ticketIndex] = updatedTicket;
      }

      _addOfflineAction('cancel_ticket', {
        'ticket_id': ticketId,
      });

      notifyListeners();
    }
  }

  Future<void> _executeCancelTicket(String ticketId) async {
    debugPrint('🚫 Cancelling ticket $ticketId');

    try {
      await _supabase.from('queues').update({
        'status': 'cancelled',
      }).eq('id', ticketId);

      debugPrint('✅ Ticket cancelled successfully');
      await loadUserTickets();
    } catch (e) {
      debugPrint('❌ Failed to cancel ticket: $e');
      rethrow;
    }
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

  // Load transaction history with filters
  Future<void> loadTransactions({
    required DateTime startDate,
    required DateTime endDate,
    int? serviceWindow,
    String? status,
  }) async {
    await _executeWithErrorHandling(() async {
      final startDateStr = startDate.toIso8601String().split('T')[0];
      final endDateStr = endDate.toIso8601String().split('T')[0];

      debugPrint('🔍 Loading transactions from $startDateStr to $endDateStr');
      debugPrint('   Window: $serviceWindow, Status: $status');

      // Ensure services are loaded
      if (_services.isEmpty) {
        debugPrint('⚠️ Services not loaded, loading now...');
        await loadServices();
      }

      // Start building the query
      // Note: We can't join profiles directly, so we'll fetch user data separately
      var queryBuilder = _supabase
          .from('queues')
          .select('*, services(id, name, service_window)')
          .gte('queue_date', startDateStr)
          .lte('queue_date', endDateStr);

      debugPrint('📊 Base query built for dates: $startDateStr to $endDateStr');

      // Filter by status if specified (do this before filter)
      if (status != null && status.isNotEmpty) {
        queryBuilder = queryBuilder.eq('status', status);
        debugPrint('   Applied status filter: $status');
      }

      // Filter by service window if specified
      if (serviceWindow != null) {
        // Get service IDs for this window
        final servicesForWindow = _services.where((s) => s.window == serviceWindow).toList();

        debugPrint('   Found ${servicesForWindow.length} services for window $serviceWindow');

        if (servicesForWindow.isNotEmpty) {
          final serviceIds = servicesForWindow.map((s) => s.id).toList();
          debugPrint('   Service IDs: $serviceIds');

          // Convert service IDs to the format needed for filter: (id1,id2,id3)
          final serviceIdsString = '(${serviceIds.join(',')})';
          queryBuilder = queryBuilder.filter('service_id', 'in', serviceIdsString);
          debugPrint('   Applied service window filter: $serviceIdsString');
        } else {
          debugPrint('⚠️ No services found for window $serviceWindow');
          _transactions = [];
          return;
        }
      }

      // Apply ordering and execute
      debugPrint('🚀 Executing query...');
      final response = await queryBuilder.order('created_at', ascending: false);

      debugPrint('📦 Raw response length: ${response.length}');
      if (response.isNotEmpty) {
        debugPrint('   Sample record: ${response.first}');
      }

      // Fetch user profiles for all unique user IDs
      final userIds = response.map((r) => r['user_id'] as String).toSet().toList();
      debugPrint('👥 Fetching ${userIds.length} user profiles...');

      Map<String, Map<String, dynamic>> userProfiles = {};
      if (userIds.isNotEmpty) {
        final profilesResponse = await _supabase
            .from('profiles')
            .select('id, full_name, email')
            .filter('id', 'in', '(${userIds.join(',')})');

        for (var profile in profilesResponse) {
          userProfiles[profile['id']] = profile;
        }
        debugPrint('✅ Fetched ${userProfiles.length} profiles');
      }

      // Merge queue data with profile data
      _transactions = response.map<Transaction>((json) {
        try {
          // Add profile data to the json
          final userId = json['user_id'];
          if (userProfiles.containsKey(userId)) {
            json['profiles'] = userProfiles[userId];
          } else {
            // Provide fallback data
            json['profiles'] = {
              'id': userId,
              'full_name': 'Unknown User',
              'email': '',
            };
          }
          return Transaction.fromJson(json);
        } catch (e) {
          debugPrint('❌ Error parsing transaction: $e');
          debugPrint('   JSON: $json');
          rethrow;
        }
      }).toList();

      debugPrint('✅ Loaded ${_transactions.length} transactions');
      if (_transactions.isEmpty) {
        debugPrint('⚠️ No transactions found with current filters');
      }
    });
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _queueSubscription?.cancel();
    _reconnectTimer?.cancel();
    _offlineQueueTimer?.cancel();
    _adminQueuePollingTimer?.cancel();
    super.dispose();
  }

}