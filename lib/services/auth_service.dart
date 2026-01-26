import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // <--- REQUIRED for kIsWeb

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream to listen to auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 1. LOGIN: Student (Google) - SMART HYBRID METHOD
  Future<User?> signInWithGoogle() async {
    try {
      UserCredential userCredential;

      if (kIsWeb) {
        // --- WEB STRATEGY: Use Popup (Much safer & easier) ---
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        
        // This triggers the browser popup directly without using the google_sign_in package
        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        // --- MOBILE STRATEGY: Use Native Google Sign In ---
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null; // User canceled

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCredential = await _auth.signInWithCredential(credential);
      }

      // --- SAVE USER DATA ---
      User? user = userCredential.user;
      if (user != null) {
        await _saveUserToFirestore(user);
      }
      return user;

    } catch (e) {
      print("Error signing in with Google: $e");
      return null;
    }
  }

  // Helper to save user data (With Null Safety Fixes)
  Future<void> _saveUserToFirestore(User user) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
      
      // We use 'set' with 'merge: true' to ensure we don't accidentally wipe data
      // We also use '??' to provide default values if Google returns null
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email ?? '', // Fallback to empty string
        'displayName': user.displayName ?? 'Student', // Fallback to 'Student'
        'photoUrl': user.photoURL ?? '', // Save photo URL if available
        'role': 'student',
        'lastLogin': FieldValue.serverTimestamp(),
        // Only set 'createdAt' if it doesn't exist yet
        if (!userDoc.exists) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
    } catch (e) {
      print("Error saving user to Firestore: $e");
    }
  }

  // 2. LOGIN: Admin (Email/Password)
  Future<User?> signInAdmin(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password
      );
      return result.user;
    } catch (e) {
      print("Error Admin Login: $e");
      rethrow;
    }
  }

  // 3. LOGOUT
  Future<void> signOut() async {
    // Only try to sign out of Google Plugin if NOT on web
    if (!kIsWeb) {
      await _googleSignIn.signOut();
    }
    await _auth.signOut();
  }
}