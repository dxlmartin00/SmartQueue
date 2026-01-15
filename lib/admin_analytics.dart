import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class AdminAnalytics extends StatefulWidget {
  const AdminAnalytics({super.key});

  @override
  State<AdminAnalytics> createState() => _AdminAnalyticsState();
}

class _AdminAnalyticsState extends State<AdminAnalytics> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _filterDays = 1; // Default to "Today" (1 day)

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Analytics & Reports"),
        backgroundColor: const Color(0xFF1A237E), // Navy Blue
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.pie_chart), text: "Overview"),
            Tab(icon: Icon(Icons.history), text: "History Log"),
          ],
        ),
        actions: [
          // TIME FILTER DROPDOWN
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: DropdownButton<int>(
              dropdownColor: const Color(0xFF1A237E),
              value: _filterDays,
              icon: const Icon(Icons.calendar_today, color: Colors.white, size: 16),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 1, child: Text("Today")),
                DropdownMenuItem(value: 3, child: Text("Last 3 Days")),
                DropdownMenuItem(value: 7, child: Text("Last 7 Days")),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _filterDays = val);
              },
            ),
          )
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OverviewTab(days: _filterDays),
          _HistoryTab(days: _filterDays),
        ],
      ),
    );
  }
}

// --- TAB 1: CHARTS (Filtered by Date) ---
class _OverviewTab extends StatelessWidget {
  final int days;
  const _OverviewTab({required this.days});

  @override
  Widget build(BuildContext context) {
    // Calculate start date based on filter
    DateTime startDate = DateTime.now().subtract(Duration(days: days == 1 ? 0 : days - 1));
    // Reset to start of that day (00:00:00)
    startDate = DateTime(startDate.year, startDate.month, startDate.day);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tickets')
          .where('status', isEqualTo: 'completed')
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text("No records for this period."));

        // Count logic
        Map<String, int> serviceCounts = {};
        for (var doc in docs) {
          String service = doc['serviceCategory'];
          serviceCounts[service] = (serviceCounts[service] ?? 0) + 1;
        }

        List<PieChartSectionData> sections = [];
        List<Color> colors = [Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple];
        int colorIndex = 0;

        serviceCounts.forEach((service, count) {
          final isLarge = count > docs.length / 3; // Highlight big chunks
          sections.add(PieChartSectionData(
            color: colors[colorIndex % colors.length],
            value: count.toDouble(),
            title: '${((count/docs.length)*100).toStringAsFixed(0)}%',
            radius: isLarge ? 60 : 50,
            titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ));
          colorIndex++;
        });

        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
               Text("Total Served: ${docs.length}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
               const SizedBox(height: 30),
               SizedBox(
                height: 250,
                child: PieChart(
                  PieChartData(sections: sections, centerSpaceRadius: 40, sectionsSpace: 2),
                ),
               ),
               const SizedBox(height: 20),
               Expanded(
                 child: ListView(
                   children: serviceCounts.entries.map((entry) {
                     int index = serviceCounts.keys.toList().indexOf(entry.key);
                     return ListTile(
                       leading: CircleAvatar(backgroundColor: colors[index % colors.length], radius: 8),
                       title: Text(entry.key),
                       trailing: Text("${entry.value}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                     );
                   }).toList(),
                 ),
               )
            ],
          ),
        );
      },
    );
  }
}

// --- TAB 2: HISTORY (Grouped by Date) ---
class _HistoryTab extends StatelessWidget {
  final int days;
  const _HistoryTab({required this.days});

  @override
  Widget build(BuildContext context) {
    DateTime startDate = DateTime.now().subtract(Duration(days: days == 1 ? 0 : days - 1));
    startDate = DateTime(startDate.year, startDate.month, startDate.day);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tickets')
          .where('status', whereIn: ['completed', 'cancelled']) // Show completed and cancelled
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No history found."));

        final docs = snapshot.data!.docs;

        // Grouping Logic
        Map<String, List<DocumentSnapshot>> groupedDocs = {};
        for (var doc in docs) {
          Timestamp t = doc['timestamp'];
          // Create Key: "Jan 15, 2026"
          String dateKey = DateFormat('MMM dd, yyyy').format(t.toDate());
          if (groupedDocs[dateKey] == null) groupedDocs[dateKey] = [];
          groupedDocs[dateKey]!.add(doc);
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: groupedDocs.entries.map((entry) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // DATE HEADER
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  margin: const EdgeInsets.only(bottom: 10, top: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8)
                  ),
                  child: Text(
                    entry.key, // "Jan 15, 2026"
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
                  ),
                ),
                // LIST OF TICKETS FOR THAT DAY
                ...entry.value.map((doc) {
                   var data = doc.data() as Map<String, dynamic>;
                   bool isCancelled = data['status'] == 'cancelled';
                   Timestamp t = data['timestamp'];
                   String timeStr = DateFormat('h:mm a').format(t.toDate());

                   return Card(
                     elevation: 0,
                     color: isCancelled ? Colors.red.shade50 : Colors.white,
                     margin: const EdgeInsets.only(bottom: 8),
                     shape: RoundedRectangleBorder(
                       side: BorderSide(color: Colors.grey.shade200),
                       borderRadius: BorderRadius.circular(12)
                     ),
                     child: ListTile(
                       leading: Text(
                         "#${data['ticketNumber']}",
                         style: TextStyle(
                           fontSize: 20, 
                           fontWeight: FontWeight.w900, 
                           color: isCancelled ? Colors.red : const Color(0xFF1A237E)
                         ),
                       ),
                       title: Text(data['userName']),
                       subtitle: Text("${data['serviceCategory']} • $timeStr"),
                       trailing: isCancelled 
                         ? const Icon(Icons.cancel, color: Colors.red)
                         : const Icon(Icons.check_circle, color: Colors.green),
                     ),
                   );
                })
              ],
            );
          }).toList(),
        );
      },
    );
  }
}