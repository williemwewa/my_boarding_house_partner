import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String id;
  final String displayName;
  final String email;
  final String? phoneNumber;
  final String? profileImageUrl;
  final String role; // 'student', 'landlord', 'admin'
  final bool isVerified;
  final String? nrcNumber;
  final String? gender;
  final String? businessName;
  final DateTime createdAt;
  final DateTime? updatedAt;

  AppUser({required this.id, required this.displayName, required this.email, this.phoneNumber, this.profileImageUrl, required this.role, required this.isVerified, this.nrcNumber, this.gender, this.businessName, required this.createdAt, this.updatedAt});

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Handle Timestamps
    Timestamp createdTimestamp = data['createdAt'] as Timestamp? ?? Timestamp.now();
    Timestamp? updatedTimestamp = data['updatedAt'] as Timestamp?;

    return AppUser(
      id: doc.id,
      displayName: data['displayName'] ?? 'Unknown User',
      email: data['email'] ?? '',
      phoneNumber: data['phoneNumber'],
      profileImageUrl: data['profileImageUrl'],
      role: data['role'] ?? 'student',
      isVerified: data['isVerified'] ?? false,
      nrcNumber: data['nrcNumber'],
      gender: data['gender'],
      businessName: data['businessName'],
      createdAt: createdTimestamp.toDate(),
      updatedAt: updatedTimestamp?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'displayName': displayName, 'email': email, 'phoneNumber': phoneNumber, 'profileImageUrl': profileImageUrl, 'role': role, 'isVerified': isVerified, 'nrcNumber': nrcNumber, 'gender': gender, 'businessName': businessName, 'updatedAt': FieldValue.serverTimestamp()};
  }

  // Create a copy with updated fields
  AppUser copyWith({String? displayName, String? email, String? phoneNumber, String? profileImageUrl, String? role, bool? isVerified, String? nrcNumber, String? gender, String? businessName}) {
    return AppUser(
      id: this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      role: role ?? this.role,
      isVerified: isVerified ?? this.isVerified,
      nrcNumber: nrcNumber ?? this.nrcNumber,
      gender: gender ?? this.gender,
      businessName: businessName ?? this.businessName,
      createdAt: this.createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
