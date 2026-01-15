import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/auth_service.dart';
import 'admin_analytics.dart'; // Ensure this file exists

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String adminId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    // Run the cleanup task silently when dashboard opens
    _performWeeklyCleanup();
  }

  // --- 1. AUTO-MAINTENANCE: DELETE OLD TICKETS ---
  Future<void> _performWeeklyCleanup() async {
    // Calculate date 7 days ago
    DateTime sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    
    try {
      // Find tickets older than 7 days
      QuerySnapshot oldTickets = await _firestore.collection('tickets')
          .where('timestamp', isLessThan: sevenDaysAgo)
          .get();

      if (oldTickets.docs.isNotEmpty) {
        WriteBatch batch = _firestore.batch();
        for (var doc in oldTickets.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        print("Maintenance: Cleaned up ${oldTickets.docs.length} old records.");
      }
    } catch (e) {
      // Silently fail or log error (don't disturb the user)
      print("Maintenance Error: $e");
    }
  }

  // --- 2. ACTION: CALL NEXT TICKET (Concurrency Safe) ---
  Future<void> _callTicket(String ticketId) async {
    final DocumentReference ticketRef = _firestore.collection('tickets').doc(ticketId);
    final DocumentReference adminRef = _firestore.collection('users').doc(adminId);

    try {
      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot ticketSnapshot = await transaction.get(ticketRef);
        DocumentSnapshot adminSnapshot = await transaction.get(adminRef);

        if (!ticketSnapshot.exists) throw Exception("Ticket missing!");
        
        // Critical Check: Is it still waiting?
        if (ticketSnapshot.get('status') != 'waiting') {
          throw Exception("Ticket already taken!");
        }

        // Get this Admin's assigned Counter # (Default to 1 if not set)
        int myCounter = 1;
        if (adminSnapshot.exists && adminSnapshot.data() != null) {
          final data = adminSnapshot.data() as Map<String, dynamic>;
          if (data.containsKey('counter')) {
            myCounter = (data['counter'] as num).toInt();
          }
        }

        // Lock the ticket
        transaction.update(ticketRef, {
          'status': 'serving',
          'servedBy': adminId,
          'counter': myCounter,
          'servedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- 3. ACTION: MARK COMPLETE ---
  Future<void> _completeTicket(String ticketId) async {
    await _firestore.collection('tickets').doc(ticketId).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  // --- 4. ACTION: MARK NO-SHOW ---
  Future<void> _markNoShow(String ticketId) async {
    await _firestore.collection('tickets').doc(ticketId).update({
      'status': 'cancelled',
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7), // Light Grey Background
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E), // Navy Blue
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text("Staff Control Panel", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: "View Reports",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAnalytics())),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => AuthService().signOut(),
          )
        ],
      ),
      body: Column(
        children: [
          // --- SECTION A: WORKSPACE (Idle or Serving?) ---
          StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('tickets')
                .where('servedBy', isEqualTo: adminId)
                .where('status', isEqualTo: 'serving')
                .snapshots(),
            builder: (context, snapshot) {
              // STATE 1: IDLE (Not serving anyone)
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(30),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A237E),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))]
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.coffee_rounded, size: 40, color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      const Text("Counter Idle", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const Text("Select a ticket below to call next student", style: TextStyle(color: Colors.white54)),
                    ],
                  ),
                );
              }
              
              // STATE 2: ACTIVE (Serving a student)
              var ticket = snapshot.data!.docs.first;
              var data = ticket.data() as Map<String, dynamic>;
              bool isPriority = data['isPriority'] ?? false;
              String? priorityType = data['priorityType'];

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Color(0xFF1A237E),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))]
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("NOW SERVING", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                        if(isPriority) ...[
                           const SizedBox(width: 10),
                           Container(
                             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                             decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                             child: Text("PRIORITY: $priorityType", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
                           )
                        ]
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text("#${data['ticketNumber']}", style: const TextStyle(fontSize: 60, fontWeight: FontWeight.w900, color: Colors.white, height: 1.0)),
                    Text("${data['userName']} • ${data['serviceCategory']}", style: const TextStyle(color: Colors.white, fontSize: 16)),
                    const SizedBox(height: 24),
                    
                    // CONTROL BUTTONS
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.close),
                            label: const Text("NO SHOW"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white30),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: () => _markNoShow(ticket.id),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle),
                            label: const Text("COMPLETE"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.greenAccent.shade700,
                              foregroundColor: Colors.white, // Text color
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 4,
                            ),
                            onPressed: () => _completeTicket(ticket.id),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              );
            },
          ),

          // --- SECTION B: QUEUE LIST ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('tickets')
                  .where('status', isEqualTo: 'waiting')
                  // SORT: Priority first, then Time
                  .orderBy('isPriority', descending: true) 
                  .orderBy('timestamp', descending: false) 
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final tickets = snapshot.data!.docs;

                if (tickets.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Text("All caught up! No pending tickets.", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: tickets.length,
                  itemBuilder: (context, index) {
                    var data = tickets[index].data() as Map<String, dynamic>;
                    bool isPriority = data['isPriority'] ?? false;
                    String? priorityType = data['priorityType'];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        // Golden border for priority tickets
                        border: isPriority ? Border.all(color: Colors.amber.shade400, width: 2) : null,
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: isPriority ? Colors.amber.shade100 : Colors.blue.shade50,
                          child: Icon(
                            isPriority ? Icons.priority_high_rounded : Icons.person,
                            color: isPriority ? Colors.amber.shade900 : Colors.blue.shade900,
                          ),
                        ),
                        title: Row(
                          children: [
                            Text("#${data['ticketNumber']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            const SizedBox(width: 10),
                            // RED BADGE FOR PRIORITY
                            if (isPriority)
                               Container(
                                 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                 decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4)),
                                 child: const Text("VERIFY ID", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
                               )
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['serviceCategory'], style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87)),
                            Text(data['userName'], style: const TextStyle(fontSize: 12)),
                            if(priorityType != null)
                              Text("Category: $priorityType", style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade50,
                            foregroundColor: Colors.blue.shade900,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _callTicket(tickets[index].id),
                          child: const Text("CALL"),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}