import 'package:flutter/material.dart';
import 'services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isStaffMode = false; // Toggles the Admin view

  @override
  Widget build(BuildContext context) {
    // University Color Palette
    final primaryColor = const Color(0xFF1A237E); // Deep Blue
    final accentColor = const Color(0xFFFFA000);  // Amber/Gold

    return Scaffold(
      backgroundColor: Colors.grey.shade100, // Light background
      body: Stack(
        children: [
          // --- 1. DECORATIVE BACKGROUND HEADER ---
          Container(
            height: MediaQuery.of(context).size.height * 0.45,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, const Color(0xFF283593)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(50),
                bottomRight: Radius.circular(50),
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white30, width: 2)
                    ),
                    child: const Icon(Icons.school_rounded, size: 60, color: Colors.white),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    "UNIVERSITY REGISTRAR",
                    style: TextStyle(
                      color: Colors.white70, 
                      letterSpacing: 2.0, 
                      fontSize: 12, 
                      fontWeight: FontWeight.w600
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    "SmartQueue",
                    style: TextStyle(
                      color: Colors.white, 
                      fontSize: 36, 
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5
                    ),
                  ),
                  const SizedBox(height: 60), // Space for the card overlap
                ],
              ),
            ),
          ),

          // --- 2. FLOATING LOGIN CARD ---
          Align(
            alignment: Alignment.bottomCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                children: [
                  const SizedBox(height: 180), // Push down to overlap header
                  
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.15), 
                          blurRadius: 20, 
                          offset: const Offset(0, 10)
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // HEADER TEXT
                        Text(
                          _isStaffMode ? "Staff Portal" : "Student Access",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22, 
                            fontWeight: FontWeight.bold, 
                            color: primaryColor
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isStaffMode ? "Enter credentials to manage queue" : "Sign in with your university account",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                        ),
                        const SizedBox(height: 32),

                        // --- STUDENT MODE (Google Login) ---
                        if (!_isStaffMode) ...[
                          ElevatedButton.icon(
                            icon: Image.network(
                              'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png', 
                              height: 24,
                            ), 
                            label: const Text("Continue with Google"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(color: Colors.grey.shade200),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _isLoading ? null : () async {
                               setState(() => _isLoading = true);
                               await AuthService().signInWithGoogle();
                               if (mounted) setState(() => _isLoading = false);
                            },
                          ),
                          const SizedBox(height: 20),
                        ],

                        // --- STAFF MODE (Email/Password) ---
                        if (_isStaffMode) ...[
                          TextField(
                            controller: _emailCtrl,
                            decoration: InputDecoration(
                              labelText: "University ID / Email",
                              prefixIcon: Icon(Icons.person_outline, color: primaryColor),
                              filled: true,
                              fillColor: Colors.grey.shade500.withOpacity(0.08),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _passCtrl,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: "Password",
                              prefixIcon: Icon(Icons.lock_outline, color: primaryColor),
                              filled: true,
                              fillColor: Colors.grey.shade500.withOpacity(0.08),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 5,
                              shadowColor: primaryColor.withOpacity(0.4),
                            ),
                            onPressed: _isLoading ? null : () async {
                               setState(() => _isLoading = true);
                               try {
                                 await AuthService().signInAdmin(_emailCtrl.text, _passCtrl.text);
                               } catch (e) {
                                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login Failed: $e")));
                               }
                               if (mounted) setState(() => _isLoading = false);
                            },
                            child: _isLoading 
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text("Secure Login", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // --- TOGGLE BUTTON (Student <-> Staff) ---
                        TextButton(
                          onPressed: () {
                            setState(() => _isStaffMode = !_isStaffMode);
                          },
                          child: Text(
                            _isStaffMode ? "← Back to Student Access" : "Admin / Staff Login",
                            style: TextStyle(color: accentColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // FOOTER
                  const SizedBox(height: 30),
                  const Text("© 2026 Assassin Academy", style: TextStyle(color: Colors.grey, fontSize: 10)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}