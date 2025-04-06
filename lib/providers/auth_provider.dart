import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Rename the enum if needed
enum UserRole { student, landlord, admin }

// Rename the class from AuthProvider to AppAuthProvider
class AppAuthProvider with ChangeNotifier {
  User? _user;
  UserRole? _userRole;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _userData;

  User? get user => _user;
  UserRole? get userRole => _userRole;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get userData => _userData;

  AppAuthProvider() {
    _initializeAuthListener();
  }

  void _initializeAuthListener() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      _user = user;

      if (user != null) {
        try {
          await _fetchUserData();
        } catch (e) {
          _errorMessage = "Failed to fetch user data: ${e.toString()}";
        }
      } else {
        _userRole = null;
        _userData = null;
      }

      notifyListeners();
    });
  }

  Future<void> _fetchUserData() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Check if user exists in Firestore
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('Users').doc(_user!.uid).get();

      if (userDoc.exists) {
        _userData = userDoc.data() as Map<String, dynamic>;

        // Determine user role
        String? role = _userData!['role'];
        if (role == 'landlord') {
          _userRole = UserRole.landlord;
        } else if (role == 'admin') {
          _userRole = UserRole.admin;
        } else {
          _userRole = UserRole.student;
        }
      } else {
        _userRole = null;
        _userData = null;
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      _user = null;
      _userRole = null;
      _userData = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateUserData(Map<String, dynamic> data) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Update Firestore document
      await FirebaseFirestore.instance.collection('Users').doc(_user!.uid).update(data);

      // Refresh user data
      await _fetchUserData();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> checkIfNewUser() async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance.collection('Users').where('userId', isEqualTo: _user!.uid).limit(1).get();

      return querySnapshot.docs.isEmpty;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return true;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
