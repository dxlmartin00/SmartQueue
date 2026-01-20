import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_analytics.dart'; 

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Safely get the current user ID
  final String adminId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    if (adminId.isNotEmpty) {
      _performWeeklyCleanup();
    }
  }

  // --- LOGIC: CLEANUP ---
  Future<void> _performWeeklyCleanup() async {
    DateTime sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    try {
      QuerySnapshot oldTickets = await _firestore.collection('tickets')
          .where('timestamp', isLessThan: sevenDaysAgo).get();
      if (oldTickets.docs.isNotEmpty) {
        WriteBatch batch = _firestore.batch();
        for (var doc in oldTickets.docs) batch.delete(doc.reference);
        await batch.commit();
      }
    } catch (e) { print("Cleanup Error: $e"); }
  }

  // --- LOGIC: ACTIONS ---
  Future<void> _callTicket(String ticketId) async {
    if (adminId.isEmpty) return;

    final DocumentReference ticketRef = _firestore.collection('tickets').doc(ticketId);
    final DocumentReference adminRef = _firestore.collection('users').doc(adminId);

    try {
      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot ticketSnapshot = await transaction.get(ticketRef);
        DocumentSnapshot adminSnapshot = await transaction.get(adminRef);

        if (!ticketSnapshot.exists) throw Exception("Ticket missing!");
        if (ticketSnapshot.get('status') != 'waiting') throw Exception("Ticket taken!");

        int myCounter = 1;
        if (adminSnapshot.exists && adminSnapshot.data() != null) {
          final data = adminSnapshot.data() as Map<String, dynamic>;
          if (data.containsKey('counter')) myCounter = (data['counter'] as num).toInt();
        }

        transaction.update(ticketRef, {
          'status': 'serving',
          'servedBy': adminId,
          'counter': myCounter,
          'servedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _completeTicket(String ticketId) async {
    await _firestore.collection('tickets').doc(ticketId).update({
      'status': 'completed', 'completedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _markNoShow(String ticketId) async {
    await _firestore.collection('tickets').doc(ticketId).update({
      'status': 'cancelled', 'completedAt': FieldValue.serverTimestamp(),
    });
  }

  // --- UI BUILDER (THE RESPONSIVE ENGINE) ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text("Staff Control Panel", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: "View Reports",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAnalytics())),
          ),
          
          // --- FIXED LOGOUT BUTTON ---
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: "Logout",
            onPressed: () async {
              // 1. Sign out from Firebase
              await FirebaseAuth.instance.signOut();
              
              // 2. Force navigation back to the Login Screen (Root)
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
          )
        ],
      ),
      // LAYOUT BUILDER: Checks screen width to protect mobile view
      body: LayoutBuilder(
        builder: (context, constraints) {
          // If screen width > 900px, it's a Desktop/Tablet
          bool isDesktop = constraints.maxWidth > 900;

          if (isDesktop) {
            // --- DESKTOP LAYOUT (Side-by-Side) ---
            return Row(
              children: [
                SizedBox(width: 400, child: _buildServingSection(isDesktop: true)),
                Expanded(child: _buildQueueSection(isGrid: true)),
              ],
            );
          } else {
            // --- MOBILE LAYOUT (Original Top-to-Bottom) ---
            // This ensures phones look EXACTLY as they did before
            return Column(
              children: [
                _buildServingSection(isDesktop: false),
                Expanded(child: _buildQueueSection(isGrid: false)),
              ],
            );
          }
        },
      ),
    );
  }

  // --- WIDGET 1: NOW SERVING PANEL ---
  Widget _buildServingSection({required bool isDesktop}) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('tickets')
          .where('servedBy', isEqualTo: adminId)
          .where('status', isEqualTo: 'serving')
          .snapshots(),
      builder: (context, snapshot) {
        // MOBILE PROTECTION: If NOT desktop, use original Rounded Bottom
        final decoration = BoxDecoration(
          color: const Color(0xFF1A237E),
          borderRadius: isDesktop 
              ? const BorderRadius.horizontal(right: Radius.circular(0)) // Flat for Desktop
              : const BorderRadius.vertical(bottom: Radius.circular(30)), // Rounded for Mobile
          boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))],
        );

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            width: double.infinity,
            height: isDesktop ? double.infinity : null, // Mobile uses auto-height
            padding: const EdgeInsets.all(30),
            decoration: decoration,
            child: Column(
              mainAxisAlignment: isDesktop ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.coffee_rounded, size: 40, color: Colors.white70),
                ),
                const SizedBox(height: 16),
                const Text("Counter Idle", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text("Select a ticket to call next student", style: TextStyle(color: Colors.white54), textAlign: TextAlign.center),
              ],
            ),
          );
        }

        var ticket = snapshot.data!.docs.first;
        var data = ticket.data() as Map<String, dynamic>;
        bool isPriority = data['isPriority'] ?? false;
        String? priorityType = data['priorityType'];

        return Container(
          width: double.infinity,
          height: isDesktop ? double.infinity : null, // Mobile uses auto-height
          padding: const EdgeInsets.all(24),
          decoration: decoration,
          child: Column(
            mainAxisAlignment: isDesktop ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              const Text("NOW SERVING", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              if(isPriority) ...[
                 const SizedBox(height: 10),
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                   decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                   child: Text("PRIORITY: $priorityType", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
                 )
              ],
              const SizedBox(height: 10),
              FittedBox(
                child: Text("#${data['ticketNumber']}", style: const TextStyle(fontSize: 60, fontWeight: FontWeight.w900, color: Colors.white, height: 1.0)),
              ),
              const SizedBox(height: 5),
              Text(data['userName'], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              Text(data['serviceCategory'], style: const TextStyle(color: Colors.amber, fontSize: 14)),
              
              SizedBox(height: isDesktop ? 40 : 24),
              
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.close),
                    label: const Text("NO SHOW"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white30),
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    ),
                    onPressed: () => _markNoShow(ticket.id),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle),
                    label: const Text("COMPLETE"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                      elevation: 4,
                    ),
                    onPressed: () => _completeTicket(ticket.id),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  // --- WIDGET 2: WAITING LIST ---
  Widget _buildQueueSection({required bool isGrid}) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('tickets')
          .where('status', isEqualTo: 'waiting')
          .orderBy('isPriority', descending: true) 
          .orderBy('timestamp', descending: false) 
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final tickets = snapshot.data!.docs;

        if (tickets.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text("All caught up!", style: TextStyle(color: Colors.grey, fontSize: 18)),
              ],
            ),
          );
        }

        // DESKTOP: Uses Grid (Better for wide screens)
        if (isGrid) {
          return GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 400,
              childAspectRatio: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: tickets.length,
            itemBuilder: (context, index) => _buildTicketCard(tickets[index]),
          );
        }

        // MOBILE PROTECTION: Uses original List View (Vertical stack)
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: tickets.length,
          itemBuilder: (context, index) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: _buildTicketCard(tickets[index]),
          ),
        );
      },
    );
  }

  // --- REUSABLE TICKET CARD (Shared by Mobile & Desktop) ---
  Widget _buildTicketCard(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    bool isPriority = data['isPriority'] ?? false;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isPriority ? Border.all(color: Colors.amber.shade400, width: 2) : null,
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _callTicket(doc.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: isPriority ? Colors.amber.shade100 : Colors.blue.shade50,
                  child: Icon(
                    isPriority ? Icons.priority_high_rounded : Icons.person,
                    color: isPriority ? Colors.amber.shade900 : Colors.blue.shade900,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Text("#${data['ticketNumber']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          if (isPriority) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4)),
                              child: const Text("PRIORITY", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
                            )
                          ]
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(data['serviceCategory'], style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87), overflow: TextOverflow.ellipsis),
                      Text(data['userName'], style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A237E),
                    foregroundColor: Colors.white,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(12),
                  ),
                  onPressed: () => _callTicket(doc.id),
                  child: const Icon(Icons.mic, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}