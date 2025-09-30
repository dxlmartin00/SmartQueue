import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';
import '../models/service.dart';

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;

  // Authentication
  static Future<void> signIn(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // Profile Management
  static Future<Profile?> getCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final response = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .single();
    
    return Profile.fromJson(response);
  }

  // Services
  static Future<List<Service>> getServices() async {
    final response = await _client.from('services').select();
    return response.map<Service>((json) => Service.fromJson(json)).toList();
  }

  // Queue Management
  static Future<String> generateTicket(String serviceId, int window) async {
    final prefix = window == 1 ? 'A' : 'B';
    
    final countResponse = await _client
        .from('queues')
        .select()
        .eq('service_id', serviceId)
        .eq('queue_date', DateTime.now().toIso8601String().split('T')[0]);
    
    final ticketNumber = '$prefix-${(countResponse.length + 1).toString().padLeft(3, '0')}';
    
    await _client.from('queues').insert({
      'service_id': serviceId,
      'user_id': _client.auth.currentUser!.id,
      'ticket_number': ticketNumber,
    });
    
    return ticketNumber;
  }

  // Analytics
  static Future<Map<String, dynamic>> getDailyAnalytics() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    // Students per window
    final windowStats = await _client
        .from('queues')
        // Changed from 'services!inner(window)' to 'services!inner(service_window)'
        .select('services!inner(service_window)')
        .eq('queue_date', today);

    // Total served
    final totalServed = await _client
        .from('queues')
        .select()
        .eq('queue_date', today)
        .eq('status', 'done');

    return {
      // Changed from q['services']['window'] to q['services']['service_window']
      'window1Count': windowStats.where((q) => q['services']['service_window'] == 1).length,
      'window2Count': windowStats.where((q) => q['services']['service_window'] == 2).length,
      'totalServed': totalServed.length,
    };
  }
}