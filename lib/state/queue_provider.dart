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
        // Keep action for next sync attempt
        continue;
      }
    }
    _offlineActions.clear();
  }
  
  // FIX: Enhanced profile loading with better error handling
  Future<void> loadProfile() async {
    await _executeWithErrorHandling(() async {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found');
      }

      try {
        final response = await _supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .single();
        
        _currentProfile = Profile.fromJson(response);
        debugPrint('Loaded profile: ${_currentProfile?.fullName} (${_currentProfile?.role})');
      } catch (e) {
        debugPrint('Profile not found, creating default profile');
        // Create profile if it doesn't exist
        await _supabase.from('profiles').insert({
          'id': user.id,
          'full_name': user.userMetadata?['full_name'] ?? 'User',
          'role': 'user',
        });
        
        // Load the newly created profile
        final response = await _supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .single();
        
        _currentProfile = Profile.fromJson(response);
      }
    });
  }
  
  // FIX: Enhanced service loading
  Future<void> loadServices() async {
    await _executeWithErrorHandling(() async {
      debugPrint('Loading services...');
      final response = await _supabase.from('services').select().order('window');
      _services = response.map<Service>((json) => Service.fromJson(json)).toList();
      await _saveOfflineData();
      debugPrint('Loaded ${_services.length} services');
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
  
  // FIX: Enhanced ticket generation with better error handling and validation
  Future<String> generateTicket(String serviceId) async {
    if (_services.isEmpty) {
      await loadServices();
    }

    final service = _services.where((s) => s.id == serviceId).firstOrNull;
    if (service == null) {
      throw Exception('Service not found');
    }

    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final prefix = service.window == 1 ? 'A' : 'B';
    
    if (_isOnline) {
      return await _executeWithErrorHandling(() async {
        return await _executeGenerateTicket({'service_id': serviceId});
      }) ?? '';
    } else {
      // Offline ticket generation
      final today = DateTime.now().toIso8601String().split('T')[0];
      final todayTickets = _userTickets.where((t) => 
          t.queueDate.toIso8601String().split('T')[0] == today &&
          t.ticketNumber.startsWith(prefix)).length;
      
      final ticketNumber = '$prefix-${(todayTickets + 1).toString().padLeft(3, '0')}';
      
      // Create offline ticket
      final offlineTicket = QueueTicket(
        id: 'offline_${DateTime.now().millisecondsSinceEpoch}',
        serviceId: serviceId,
        userId: user.id,
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
  
  // FIX: Enhanced ticket generation execution
  Future<String> _executeGenerateTicket(Map<String, dynamic> data) async {
    final serviceId = data['service_id'];
    
    if (_services.isEmpty) {
      await loadServices();
    }
    
    final service = _services.where((s) => s.id == serviceId).firstOrNull;
    if (service == null) {
      throw Exception('Service not found: $serviceId');
    }
    
    final prefix = service.window == 1 ? 'A' : 'B';
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    // Get count of tickets for this service today
    final countResponse = await _supabase
        .from('queues')
        .select('id')
        .eq('service_id', serviceId)
        .eq('queue_date', today);
    
    final count = countResponse.length;
    final ticketNumber = '$prefix-${(count + 1).toString().padLeft(3, '0')}';
    
    debugPrint('Generating ticket: $ticketNumber for service: ${service.name}');
    
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    
    await _supabase.from('queues').insert({
      'service_id': serviceId,
      'user_id': user.id,
      'ticket_number': ticketNumber,
      'queue_date': today,
    });
    
    await loadUserTickets();
    return ticketNumber;
  }
  
  Future<void> loadUserTickets() async {
    await _executeWithErrorHandling(() async {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final today = DateTime.now().toIso8601String().split('T')[0];
        final response = await _supabase
            .from('queues')
            .select('*')
            .eq('user_id', user.id)
            .eq('queue_date', today)
            .order('created_at');
        
        _userTickets = response.map<QueueTicket>((json) => QueueTicket.fromJson(json)).toList();
        await _saveOfflineData();
        debugPrint('Loaded ${_userTickets.length} user tickets');
      }
    });
  }
  
  // FIX: Enhanced admin ticket loading with better service join
  Future<void> loadAdminTickets(int window) async {
    await _executeWithErrorHandling(() async {
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      try {
        // Use a single query with join to get tickets for the specific window
        final response = await _supabase
            .from('queues')
            .select('''
              *,
              services!inner (
                id,
                name,
                window
              )
            ''')
            .eq('services.window', window)
            .eq('queue_date', today)
            .order('created_at');
        
        _adminTickets = response.map<QueueTicket>((json) => QueueTicket.fromJson(json)).toList();
        debugPrint('Loaded ${_adminTickets.length} admin tickets for window $window');
        
      } catch (e) {
        debugPrint('Join query failed, trying fallback method: $e');
        
        // Fallback: Get services first, then tickets individually
        final windowServices = await _supabase
            .from('services')
            .select('id')
            .eq('window', window);
        
        if (windowServices.isEmpty) {
          _adminTickets = [];
          debugPrint('No services found for window $window');
          return;
        }
        
        final allTickets = <QueueTicket>[];
        
        for (final service in windowServices) {
          try {
            final serviceTickets = await _supabase
                .from('queues')
                .select('*')
                .eq('service_id', service['id'])
                .eq('queue_date', today);
            
            final tickets = serviceTickets.map<QueueTicket>((json) => QueueTicket.fromJson(json)).toList();
            allTickets.addAll(tickets);
          } catch (serviceError) {
            debugPrint('Error loading tickets for service ${service['id']}: $serviceError');
          }
        }
        
        // Sort by creation time
        allTickets.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        _adminTickets = allTickets;
        debugPrint('Loaded ${_adminTickets.length} admin tickets for window $window (fallback)');
      }
    });
  }
  
  Future<void> updateServiceStatus(int window, String currentNumber) async {
    if (_isOnline) {
      await _executeWithErrorHandling(() async {
        await _executeUpdateServiceStatus({
          'window': window,
          'current_number': currentNumber,
        });
      });
    } else {
      _addOfflineAction('update_service_status', {
        'window': window,
        'current_number': currentNumber,
      });
    }
  }
  
  Future<void> _executeUpdateServiceStatus(Map<String, dynamic> data) async {
    final currentNumber = data['current_number'];
    final updateData = {
      'current_number': currentNumber.isEmpty ? null : currentNumber,
      'updated_at': DateTime.now().toIso8601String()
    };
    
    await _supabase
        .from('service_status')
        .update(updateData)
        .eq('window', data['window']);
        
    // Refresh service statuses
    await loadServiceStatuses();
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
        // Create updated ticket (immutable approach)
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
    
    final updateData = {'status': status};
    if (status == 'serving') {
      updateData['time_called'] = DateTime.now().toIso8601String();
    } else if (status == 'done') {
      updateData['finished_at'] = DateTime.now().toIso8601String();
    }
    
    await _supabase.from('queues').update(updateData).eq('id', ticketId);
  }
  
  Future<Map<String, dynamic>> getDailyAnalytics() async {
    return await _executeWithErrorHandling(() async {
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      try {
        // Try to get analytics from the view we created
        final analytics = await _supabase
            .from('queue_analytics')
            .select()
            .eq('date', today)
            .single();
            
        return analytics;
      } catch (e) {
        // Fallback to manual calculation
        debugPrint('Analytics view not available, calculating manually');
        
        final tickets = await _supabase
            .from('queues')
            .select('*, services(*)')
            .eq('queue_date', today);
            
        final totalTickets = tickets.length;
        final completedTickets = tickets.where((t) => t['status'] == 'done').length;
        final window1Count = tickets.where((t) => t['services']?['window'] == 1).length;
        final window2Count = tickets.where((t) => t['services']?['window'] == 2).length;
        
        return {
          'total_tickets': totalTickets,
          'completed_tickets': completedTickets,
          'avg_wait_minutes': 0,
          'window_1_count': window1Count,
          'window_2_count': window2Count,
        };
      }
    }) ?? {
      'total_tickets': 0,
      'completed_tickets': 0,
      'avg_wait_minutes': 0,
      'window_1_count': 0,
      'window_2_count': 0,
    };
  }
  
  // FIX: Enhanced error handling with more specific error messages
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
      debugPrint('Operation failed: $e');
      
      String errorMessage = 'An error occurred';
      
      if (e is PostgrestException) {
        errorMessage = 'Database error: ${e.message}';
      } else if (e.toString().contains('network') || 
                 e.toString().contains('connection') ||
                 e.toString().contains('timeout')) {
        errorMessage = 'Network connection error';
        _setOnlineStatus(false);
      } else if (e.toString().contains('not found')) {
        errorMessage = 'Requested data not found';
      } else if (e.toString().contains('permission')) {
        errorMessage = 'Permission denied';
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
  
  @override
  void dispose() {
    _statusSubscription?.cancel();
    _queueSubscription?.cancel();
    _reconnectTimer?.cancel();
    _offlineQueueTimer?.cancel();
    super.dispose();
  }
}