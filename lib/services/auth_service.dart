import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // This constructor will now work perfectly with version 6.2.1
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream to listen to auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 1. LOGIN: Student (Google)
  Future<User?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // User canceled

      // Obtain the auth details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      UserCredential userCredential = await _auth.signInWithCredential(credential);
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

  // Helper to save user data
  Future<void> _saveUserToFirestore(User user) async {
    DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) {
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName,
        'role': 'student',
        'createdAt': FieldValue.serverTimestamp(),
      });
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
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}