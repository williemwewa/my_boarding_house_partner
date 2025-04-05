import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthenticationService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Returns the current user
  User? get currentUser => _auth.currentUser;

  // Stream to get auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with phone number
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
    int? forceResendingToken,
  }) async {
    await _auth.verifyPhoneNumber(phoneNumber: phoneNumber, verificationCompleted: verificationCompleted, verificationFailed: verificationFailed, codeSent: codeSent, codeAutoRetrievalTimeout: codeAutoRetrievalTimeout, forceResendingToken: forceResendingToken);
  }

  // Sign in with credential
  Future<UserCredential> signInWithCredential(PhoneAuthCredential credential) async {
    return await _auth.signInWithCredential(credential);
  }

  // Sign out
  Future<void> signOut() async {
    // Clear any stored session data in shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // Sign out from Firebase
    return await _auth.signOut();
  }

  // Check if user is new or existing
  Future<bool> isNewUser() async {
    User? user = _auth.currentUser;
    if (user == null) {
      return true;
    }

    DocumentSnapshot userDoc = await _firestore.collection('Users').doc(user.uid).get();
    return !userDoc.exists;
  }

  // Create or update user data in Firestore
  Future<void> createOrUpdateUserData(Map<String, dynamic> userData) async {
    User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found');
    }

    await _firestore.collection('Users').doc(user.uid).set({...userData, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  // Get user role
  Future<String?> getUserRole() async {
    User? user = _auth.currentUser;
    if (user == null) {
      return null;
    }

    DocumentSnapshot userDoc = await _firestore.collection('Users').doc(user.uid).get();
    if (!userDoc.exists) {
      return null;
    }

    return (userDoc.data() as Map<String, dynamic>)['role'] as String?;
  }

  // Check if user is verified
  Future<bool> isUserVerified() async {
    User? user = _auth.currentUser;
    if (user == null) {
      return false;
    }

    DocumentSnapshot userDoc = await _firestore.collection('Users').doc(user.uid).get();
    if (!userDoc.exists) {
      return false;
    }

    return (userDoc.data() as Map<String, dynamic>)['isVerified'] as bool? ?? false;
  }

  // Update display name
  Future<void> updateDisplayName(String displayName) async {
    User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found');
    }

    await user.updateDisplayName(displayName);
  }

  // Update profile photo URL
  Future<void> updateProfilePhoto(String photoURL) async {
    User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found');
    }

    await user.updatePhotoURL(photoURL);
  }

  // Update email
  Future<void> updateEmail(String email) async {
    User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found');
    }

    await user.updateEmail(email);
  }

  // Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData() async {
    User? user = _auth.currentUser;
    if (user == null) {
      return null;
    }

    DocumentSnapshot userDoc = await _firestore.collection('Users').doc(user.uid).get();
    if (!userDoc.exists) {
      return null;
    }

    return userDoc.data() as Map<String, dynamic>;
  }
}
