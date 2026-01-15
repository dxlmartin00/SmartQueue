import 'package:cloud_firestore/cloud_firestore.dart';

class Ticket {
  final String id;
  final int ticketNumber;
  final String userId;
  final String userName;
  final String serviceCategory; // e.g., "TOR", "Diploma"
  final String status; // 'waiting', 'serving', 'completed', 'cancelled'
  final bool isPriority; // PWD, Elderly, Pregnant
  final DateTime timestamp;

  Ticket({
    required this.id,
    required this.ticketNumber,
    required this.userId,
    required this.userName,
    required this.serviceCategory,
    required this.status,
    required this.isPriority,
    required this.timestamp,
  });

  // Convert from Firestore Document to Ticket Object
  factory Ticket.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Ticket(
      id: doc.id,
      ticketNumber: data['ticketNumber'] ?? 0,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Unknown',
      serviceCategory: data['serviceCategory'] ?? '',
      status: data['status'] ?? 'waiting',
      isPriority: data['isPriority'] ?? false,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }
}