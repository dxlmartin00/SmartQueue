import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- SCREEN 1: DUAL MONITOR (Side-by-Side) ---
// Route: /monitor
class MonitorDual extends StatelessWidget {
  const MonitorDual({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A237E), // Navy Blue
      body: Row(
        children: [
          // Left Side: Counter 1
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: Colors.white24, width: 2)),
              ),
              child: const MonitorWidget(targetCounter: 1),
            ),
          ),
          // Right Side: Counter 2
          Expanded(
            child: const MonitorWidget(targetCounter: 2),
          ),
        ],
      ),
    );
  }
}

// --- SCREEN 2: COUNTER 1 ONLY ---
// Route: /monitor1
class MonitorCounter1 extends StatelessWidget {
  const MonitorCounter1({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1A237E),
      body: MonitorWidget(targetCounter: 1),
    );
  }
}

// --- SCREEN 3: COUNTER 2 ONLY ---
// Route: /monitor2
class MonitorCounter2 extends StatelessWidget {
  const MonitorCounter2({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1A237E),
      body: MonitorWidget(targetCounter: 2),
    );
  }
}

// --- CORE WIDGET: HANDLES LOGIC & UI ---
class MonitorWidget extends StatelessWidget {
  final int targetCounter;

  const MonitorWidget({super.key, required this.targetCounter});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // Listen to ALL serving tickets (Client-side filtering prevents flickering)
      stream: FirebaseFirestore.instance
          .collection('tickets')
          .where('status', isEqualTo: 'serving')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _buildIdleState();

        // 1. Filter for THIS specific counter
        var allDocs = snapshot.data!.docs;
        var counterDocs = allDocs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          return (data['counter'] ?? 1) == targetCounter;
        }).toList();

        if (counterDocs.isEmpty) return _buildIdleState();

        // 2. Sort to find the newest one (Robust Client-Side Sort)
        counterDocs.sort((a, b) {
          var dataA = a.data() as Map<String, dynamic>;
          var dataB = b.data() as Map<String, dynamic>;
          Timestamp? timeA = dataA['servedAt'];
          Timestamp? timeB = dataB['servedAt'];
          if (timeA == null) return -1;
          if (timeB == null) return 1;
          return timeB.compareTo(timeA);
        });

        // 3. Display the latest ticket
        var data = counterDocs.first.data() as Map<String, dynamic>;
        bool isPriority = data['isPriority'] ?? false;

        return Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 700),
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: isPriority ? Border.all(color: Colors.amber, width: 15) : null,
              boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 30, offset: Offset(0, 10))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("COUNTER $targetCounter",
                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.grey)),
                const Divider(height: 40, thickness: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text("#${data['ticketNumber']}",
                      style: const TextStyle(fontSize: 180, fontWeight: FontWeight.w900, color: Color(0xFF1A237E), height: 1.0)),
                ),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  decoration: BoxDecoration(
                      color: isPriority ? Colors.amber : const Color(0xFFE8EAF6),
                      borderRadius: BorderRadius.circular(100)),
                  child: Text(
                    data['serviceCategory'] ?? 'Service',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 30, color: isPriority ? Colors.black : const Color(0xFF1A237E), fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIdleState() {
    return Center(
      child: Opacity(
        opacity: 0.5,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("COUNTER $targetCounter", style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            const Icon(Icons.monitor, size: 80, color: Colors.white),
            const SizedBox(height: 20),
            const Text("Waiting...", style: TextStyle(color: Colors.white, fontSize: 24)),
          ],
        ),
      ),
    );
  }
}