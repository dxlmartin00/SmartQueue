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
    await _executeWithErrorHandling(() async {
      // Changed from .order('window') to .order('service_window')
      final response = await _supabase.from('services').select().order('service_window');
      _services = response.map<Service>((json) => Service.fromJson(json)).toList();
      await _saveOfflineData();
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
        userId: _supabase.auth.currentUser!.id,
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
    final service = _services.firstWhere((s) => s.id == serviceId);
    final prefix = service.window == 1 ? 'A' : 'B';
    
    final countResponse = await _supabase
        .from('queues')
        .select()
        .eq('service_id', serviceId)
        .eq('queue_date', DateTime.now().toIso8601String().split('T')[0]);
    
    final ticketNumber = '$prefix-${(countResponse.length + 1).toString().padLeft(3, '0')}';
    
    await _supabase.from('queues').insert({
      'service_id': serviceId,
      'user_id': _supabase.auth.currentUser!.id,
      'ticket_number': ticketNumber,
    });
    
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
      final response = await _supabase
          .from('queues')
          .select('*, services(*)')
          // Changed from .eq('services.window', window) to .eq('services.service_window', window)
          .eq('services.service_window', window)
          .eq('queue_date', DateTime.now().toIso8601String().split('T')[0])
          .order('created_at');
      
      _adminTickets = response.map<QueueTicket>((json) => QueueTicket.fromJson(json)).toList();
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
    await _supabase
        .from('service_status')
        .update({
          'current_number': data['current_number'],
          'updated_at': DateTime.now().toIso8601String()
        })
        .eq('service_window', data['service_window']);  // Changed from 'window' to 'service_window'
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
      debugPrint('Operation failed: $e');
      
      if (e.toString().contains('network') || 
          e.toString().contains('connection') ||
          e.toString().contains('timeout')) {
        _setOnlineStatus(false);
      }
      
      _setError(e.toString());
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