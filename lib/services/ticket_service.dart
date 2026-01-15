import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Add to pubspec.yaml: intl: ^0.19.0

class TicketService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> generateTicket(String serviceName, String? priorityType) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final DocumentReference metaRef = _firestore.collection('meta').doc('dailyCounter');
    
    // Get today's date string (e.g., "2026-01-15")
    String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot metaSnapshot = await transaction.get(metaRef);
        
        int currentCount = 0;
        String storedDate = "";

        if (metaSnapshot.exists) {
          final data = metaSnapshot.data() as Map<String, dynamic>;
          currentCount = data['count'] ?? 0;
          storedDate = data['date'] ?? "";
        }

        // 1. RESET CHECK: If the stored date is different from today, reset count
        if (storedDate != todayStr) {
          currentCount = 0; // Reset!
        }

        // 2. Increment
        int newCount = currentCount + 1;

        // 3. Save new count AND today's date
        transaction.set(metaRef, {
          'count': newCount,
          'date': todayStr, // This locks the counter to today
        }, SetOptions(merge: true));

        // 4. Create Ticket
        final newTicketRef = _firestore.collection('tickets').doc();
        transaction.set(newTicketRef, {
          'ticketNumber': newCount,
          'userId': user.uid,
          'userName': user.displayName ?? "Student",
          'serviceCategory': serviceName,
          'isPriority': priorityType != null,
          'priorityType': priorityType,
          'status': 'waiting',
          'timestamp': FieldValue.serverTimestamp(),
          'dateString': todayStr, // Helper for grouping later
        });
      });
    } catch (e) {
      throw e;
    }
  }
}