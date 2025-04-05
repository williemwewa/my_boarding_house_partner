import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import 'package:my_boarding_house_partner/models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Get user profile from Firestore
  Future<AppUser?> getUserProfile(String userId) async {
    try {
      final userDoc = await _firestore.collection('Users').doc(userId).get();

      if (userDoc.exists) {
        return AppUser.fromFirestore(userDoc);
      }

      return null;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  // Get current user profile
  Future<AppUser?> getCurrentUserProfile() async {
    final user = getCurrentUser();
    if (user == null) return null;

    return getUserProfile(user.uid);
  }

  // Create or update user profile
  Future<void> updateUserProfile(Map<String, dynamic> userData, {File? profileImage}) async {
    try {
      final user = getCurrentUser();
      if (user == null) throw Exception('User not authenticated');

      // Upload profile image if provided
      if (profileImage != null) {
        final imageUrl = await _uploadProfileImage(user.uid, profileImage);
        if (imageUrl != null) {
          userData['profileImageUrl'] = imageUrl;

          // Also update Firebase Auth user profile
          await user.updatePhotoURL(imageUrl);
        }
      }

      // Update display name in Firebase Auth
      if (userData.containsKey('displayName')) {
        await user.updateDisplayName(userData['displayName']);
      }

      // Update email in Firebase Auth if provided
      if (userData.containsKey('email') && userData['email'] != user.email) {
        await user.updateEmail(userData['email']);
      }

      // Add timestamps
      userData['updatedAt'] = FieldValue.serverTimestamp();
      if (!(await _userExists(user.uid))) {
        userData['createdAt'] = FieldValue.serverTimestamp();
      }

      // Update user document in Firestore
      await _firestore.collection('Users').doc(user.uid).set(userData, SetOptions(merge: true));
    } catch (e) {
      print('Error updating user profile: $e');
      throw e;
    }
  }

  // Check if user exists in Firestore
  Future<bool> _userExists(String userId) async {
    final userDoc = await _firestore.collection('Users').doc(userId).get();
    return userDoc.exists;
  }

  // Upload profile image to Firebase Storage
  Future<String?> _uploadProfileImage(String userId, File imageFile) async {
    try {
      final fileName = '${const Uuid().v4()}_profile.jpg';
      final ref = _storage.ref().child('profile_images').child(userId).child(fileName);

      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask.whenComplete(() {});

      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading profile image: $e');
      return null;
    }
  }

  // Get all users with optional filtering
  Future<List<AppUser>> getUsers({String? role, bool? isVerified, String? searchQuery}) async {
    try {
      Query query = _firestore.collection('Users');

      // Apply role filter
      if (role != null) {
        query = query.where('role', isEqualTo: role);
      }

      // Apply verification filter
      if (isVerified != null) {
        query = query.where('isVerified', isEqualTo: isVerified);
      }

      final usersSnapshot = await query.get();

      List<AppUser> users = usersSnapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList();

      // Apply search filter if provided
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final searchLower = searchQuery.toLowerCase();
        users =
            users.where((user) {
              return user.displayName.toLowerCase().contains(searchLower) || user.email.toLowerCase().contains(searchLower) || (user.phoneNumber?.toLowerCase().contains(searchLower) ?? false);
            }).toList();
      }

      return users;
    } catch (e) {
      print('Error getting users: $e');
      return [];
    }
  }

  // Verify or unverify a user (for admins)
  Future<void> updateUserVerification(String userId, bool isVerified) async {
    try {
      await _firestore.collection('Users').doc(userId).update({'isVerified': isVerified, 'updatedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      print('Error updating user verification: $e');
      throw e;
    }
  }

  // Block or unblock a user (for admins)
  Future<void> updateUserBlockStatus(String userId, bool isBlocked) async {
    try {
      await _firestore.collection('Users').doc(userId).update({'isBlocked': isBlocked, 'updatedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      print('Error updating user block status: $e');
      throw e;
    }
  }

  // Get landlord details for a property
  Future<AppUser?> getLandlordForProperty(String landlordId) async {
    return getUserProfile(landlordId);
  }

  // Get user statistics (for admin dashboard)
  Future<Map<String, dynamic>> getUserStatistics() async {
    try {
      final QuerySnapshot usersSnapshot = await _firestore.collection('Users').get();

      int totalUsers = usersSnapshot.docs.length;
      int studentsCount = 0;
      int landlordsCount = 0;
      int adminsCount = 0;
      int verifiedLandlords = 0;
      int unverifiedLandlords = 0;

      for (var doc in usersSnapshot.docs) {
        final role = doc.get('role') as String?;

        if (role == 'student') {
          studentsCount++;
        } else if (role == 'landlord') {
          landlordsCount++;

          final isVerified = doc.get('isVerified') as bool?;
          if (isVerified == true) {
            verifiedLandlords++;
          } else {
            unverifiedLandlords++;
          }
        } else if (role == 'admin') {
          adminsCount++;
        }
      }

      return {'totalUsers': totalUsers, 'studentsCount': studentsCount, 'landlordsCount': landlordsCount, 'adminsCount': adminsCount, 'verifiedLandlords': verifiedLandlords, 'unverifiedLandlords': unverifiedLandlords};
    } catch (e) {
      print('Error getting user statistics: $e');
      return {};
    }
  }
}
