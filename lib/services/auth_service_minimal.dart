import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A minimal authentication service interface for the app
/// This is a simplified version since you asked to skip the full auth_service
class AuthenticationService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();

      // Clear any stored credentials
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      throw Exception('Error signing out: $e');
    }
  }

  // Check if user is verified
  Future<bool> isUserVerified(String uid) async {
    try {
      final doc = await _firestore.collection('Users').doc(uid).get();
      if (doc.exists) {
        return doc.get('isVerified') ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Get user role
  Future<String?> getUserRole(String uid) async {
    try {
      final doc = await _firestore.collection('Users').doc(uid).get();
      if (doc.exists) {
        return doc.get('role') as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Update FCM token for push notifications
  Future<void> updateFCMToken(String uid, String token) async {
    try {
      await _firestore.collection('Users').doc(uid).update({'fcmToken': token, 'updatedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      throw Exception('Error updating FCM token: $e');
    }
  }
}
