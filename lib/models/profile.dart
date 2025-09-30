// lib/models/profile.dart
class Profile {
  final String id;
  final String fullName;
  final String role;
  final int? assignedWindow; // New field for window assignment

  Profile({
    required this.id, 
    required this.fullName, 
    required this.role,
    this.assignedWindow,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'],
      fullName: json['full_name'] ?? '',
      role: json['role'] ?? 'user',
      assignedWindow: json['assigned_window'], // Parse assigned window
    );
  }

  // Helper method to check if user is admin for specific window
  bool isAdminForWindow(int window) {
    return role == 'admin' && assignedWindow == window;
  }

  // Helper method to check if user is any type of admin
  bool get isAdmin => role == 'admin';
}