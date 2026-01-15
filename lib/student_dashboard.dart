import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/auth_service.dart';
import 'services/ticket_service.dart';
import 'services/notification_service.dart'; 

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final TicketService _ticketService = TicketService();
  bool _isLoading = false;
  String? _lastStatus; 

  final Map<String, IconData> categoryIcons = {
    'Transcript of Records': Icons.history_edu_rounded,
    'Certification': Icons.verified_user_rounded,
    'Certified True Copy': Icons.copy_all_rounded,
    'Others': Icons.widgets_rounded,
  };

  // --- 1. BLOCKING ALERT ---
  void _showActiveTicketError() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 10),
            Text("Action Blocked"),
          ],
        ),
        content: const Text("You already have an active ticket. Please finish your current transaction before getting a new one."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- 2. SERVICE SELECTION MENU ---
  void _showServiceOptions(String category, List<String> options) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(category, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: const Color(0xFF1A237E), fontSize: 24)),
              const SizedBox(height: 8),
              const Text("Select specific document:", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              
              Expanded(
                child: ListView.separated(
                  itemCount: options.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF1A237E)),
                      ),
                      title: Text(options[index], style: const TextStyle(fontWeight: FontWeight.w600)),
                      onTap: () {
                        Navigator.pop(context); 
                        _confirmPriority(options[index]); 
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- 3. PRIORITY FLOW ---
  void _confirmPriority(String serviceName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Priority Check"),
        content: const Text("Are you a Priority Applicant (PWD, Senior Citizen, or Pregnant)?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _getTicket(serviceName, null);
            },
            child: const Text("No, Regular Student"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.amber.shade800),
            onPressed: () {
              Navigator.pop(context);
              _showPrioritySelection(serviceName);
            },
            child: const Text("Yes, I have an ID"),
          ),
        ],
      ),
    );
  }

  void _showPrioritySelection(String serviceName) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Select Priority Category", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: const [
                  Icon(Icons.warning_amber_rounded, color: Colors.red),
                  SizedBox(width: 10),
                  Expanded(child: Text("You MUST present a valid ID at the counter. Failure to do so will void your ticket.", style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold))),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _priorityButton(serviceName, "Senior Citizen", Icons.elderly),
            _priorityButton(serviceName, "PWD", Icons.accessible),
            _priorityButton(serviceName, "Pregnant", Icons.pregnant_woman),
          ],
        ),
      ),
    );
  }

  Widget _priorityButton(String service, String type, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: OutlinedButton.icon(
        icon: Icon(icon, color: Colors.amber.shade900),
        label: Text(type, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.all(16),
          side: BorderSide(color: Colors.amber.shade900),
          alignment: Alignment.centerLeft,
        ),
        onPressed: () {
          Navigator.pop(context);
          _getTicket(service, type);
        },
      ),
    );
  }

  void _getTicket(String serviceName, String? priorityType) async {
    setState(() => _isLoading = true);
    try {
      await _ticketService.generateTicket(serviceName, priorityType);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ticket Generated for $serviceName"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final Map<String, List<String>> services = {
      'Transcript of Records': ['For Board Exam / PRC Purposes', 'For Employment Purposes', 'For Evaluation Purposes'],
      'Certification': ['Graduation', 'Enrollment', 'Free Tuition', 'Units Earned', 'Transfer Credentials', 'Field Study', 'Passed Comprehensive Exam', 'CAV', 'Good Moral', 'GWA'],
      'Certified True Copy': ['Diploma', 'Transcript of Records', 'Certification'],
      'Others': ['Completion Form', 'Grades (2nd Copy)', 'Form 137', 'Documentary Stamp'],
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("SmartQueue", style: TextStyle(fontSize: 14, color: Colors.white70)),
            Text("Hi, ${user?.displayName?.split(' ')[0] ?? 'Student'}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [IconButton(onPressed: () => AuthService().signOut(), icon: const Icon(Icons.logout_rounded))],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : Column(
        children: [
          // --- TOP SECTION: LIVE TICKER ---
          Container(
            width: double.infinity,
            height: 70, 
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondary, boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('tickets').where('status', isEqualTo: 'serving').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("Waiting for counters...", style: TextStyle(fontWeight: FontWeight.bold)));
                }
                List<Widget> ticketWidgets = snapshot.data!.docs.map((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
                    child: Row(children: [Text("#${data['ticketNumber']}", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Theme.of(context).primaryColor)), const SizedBox(width: 8), Text("CNTR ${data['counter']}", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade900))]),
                  );
                }).toList();
                return Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 16), color: Theme.of(context).colorScheme.secondary, alignment: Alignment.center, child: const Text("📢 CALLING:", style: TextStyle(fontWeight: FontWeight.w900))), Expanded(child: _MarqueeWidget(children: ticketWidgets))]);
              },
            ),
          ),

          // --- MAIN SECTION: ACTIVE TICKET CHECK ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // Listen for ANY active ticket for this user
              stream: FirebaseFirestore.instance
                  .collection('tickets')
                  .where('userId', isEqualTo: user?.uid)
                  .where('status', whereIn: ['waiting', 'serving'])
                  .snapshots(),
              builder: (context, snapshot) {
                
                // 1. Determine State
                bool hasActiveTicket = false;
                QueryDocumentSnapshot? activeTicketDoc;

                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  hasActiveTicket = true;
                  activeTicketDoc = snapshot.data!.docs.first;
                  
                  // Run Notification Logic
                  var data = activeTicketDoc.data() as Map<String, dynamic>;
                  if (data['status'] != _lastStatus) {
                    if (data['status'] == 'serving') {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                         NotificationService.showNotification(title: "It's Your Turn!", body: "Proceed to Counter ${data['counter']} now.");
                      });
                    }
                    _lastStatus = data['status'];
                  }
                } else {
                  _lastStatus = null; // Reset if no active ticket
                }

                // 2. Build UI based on State
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    
                    // A. SHOW ACTIVE TICKET CARD (If exists)
                    if (hasActiveTicket && activeTicketDoc != null) ...[
                      _buildTicketCard(context, activeTicketDoc),
                      const SizedBox(height: 25),
                    ],

                    const Text("Select a Service", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),

                    // B. GRID MENU (Tap blocked if hasActiveTicket is true)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 1.1),
                      itemCount: services.length,
                      itemBuilder: (context, index) {
                        String category = services.keys.elementAt(index);
                        return Material(
                          color: hasActiveTicket ? Colors.grey.shade200 : Colors.white, // Visual feedback
                          elevation: hasActiveTicket ? 0 : 2,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              if (hasActiveTicket) {
                                _showActiveTicketError(); // <--- BLOCKING LOGIC
                              } else {
                                _showServiceOptions(category, services.values.elementAt(index));
                              }
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: hasActiveTicket ? Colors.grey.shade300 : Theme.of(context).primaryColor.withOpacity(0.08), 
                                    shape: BoxShape.circle
                                  ),
                                  child: Icon(
                                    categoryIcons[category] ?? Icons.grid_view, 
                                    size: 32, 
                                    color: hasActiveTicket ? Colors.grey : Theme.of(context).primaryColor
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(category, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: hasActiveTicket ? Colors.grey : Colors.black)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 40),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget for the ticket card
  Widget _buildTicketCard(BuildContext context, QueryDocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    bool isMyTurn = data['status'] == 'serving';
    bool isPriority = data['isPriority'] ?? false;
    int counter = data['counter'] ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: isMyTurn 
          ? LinearGradient(colors: [Colors.green.shade600, Colors.green.shade400])
          : LinearGradient(colors: [Theme.of(context).primaryColor, const Color(0xFF283593)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 5))]
      ),
      child: Column(
        children: [
          if (isPriority)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
              child: Text("PRIORITY: ${data['priorityType']}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          Text(isMyTurn ? "IT'S YOUR TURN!" : "YOUR TICKET NUMBER", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70)),
          const SizedBox(height: 10),
          Text("#${data['ticketNumber']}", style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: Colors.white, height: 1.0)),
          const SizedBox(height: 10),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
              child: Text(isMyTurn ? "PROCEED TO COUNTER $counter" : "WAITING IN QUEUE", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          )
        ],
      ),
    );
  }
}

// Keep the MarqueeWidget class as is
class _MarqueeWidget extends StatefulWidget {
  final List<Widget> children;
  const _MarqueeWidget({required this.children});
  @override
  State<_MarqueeWidget> createState() => _MarqueeWidgetState();
}

class _MarqueeWidgetState extends State<_MarqueeWidget> {
  late ScrollController _scrollController;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  void _startScrolling() {
    _timer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!_scrollController.hasClients) return;
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent) {
        _scrollController.jumpTo(0);
      } else {
        _scrollController.animateTo(_scrollController.offset + 1.5, duration: const Duration(milliseconds: 30), curve: Curves.linear);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(controller: _scrollController, scrollDirection: Axis.horizontal, itemCount: widget.children.isEmpty ? 0 : 1000, itemBuilder: (context, index) => widget.children[index % widget.children.length]);
  }
}