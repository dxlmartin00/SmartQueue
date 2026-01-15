import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'services/auth_service.dart';
import 'student_dashboard.dart'; // <--- Imports your new file
import 'admin_dashboard.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // 1. If waiting for connection, show loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // 2. If user is NOT logged in, show Login Screen
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        // 3. If user IS logged in, check their Role in Firestore
        final User user = snapshot.data!;
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            if (roleSnapshot.hasData && roleSnapshot.data!.exists) {
              final userData = roleSnapshot.data!.data() as Map<String, dynamic>;
              final role = userData['role'] ?? 'student';

              if (role == 'admin') {
                return const AdminDashboard(); // Calls the placeholder below
              } else {
                return const StudentDashboard(); // Calls your new file
              }
            }

            // Fallback (Default to Student)
            return const StudentDashboard();
          },
        );
      },
    );
  }
}
