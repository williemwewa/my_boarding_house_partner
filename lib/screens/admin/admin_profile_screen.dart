import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:my_boarding_house_partner/providers/auth_provider.dart';
import 'package:my_boarding_house_partner/utils/app_theme.dart';
import 'package:my_boarding_house_partner/screens/auth/phone_login_screen.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({Key? key}) : super(key: key);

  @override
  _AdminProfileScreenState createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _isEditing = false;
  bool _isLoading = false;
  bool _isSaving = false;
  File? _newProfileImage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _loadUserData() {
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    if (authProvider.userData != null) {
      _displayNameController.text = authProvider.userData!['displayName'] ?? '';
      _emailController.text = authProvider.userData!['email'] ?? '';
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 75);

    if (image != null && mounted) {
      setState(() {
        _newProfileImage = File(image.path);
      });
    }
  }

  Future<void> _takePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera, maxWidth: 512, maxHeight: 512, imageQuality: 75);

    if (image != null && mounted) {
      setState(() {
        _newProfileImage = File(image.path);
      });
    }
  }

  Future<void> _showImageSourceDialog() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Choose Profile Picture", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildImageSourceOption(
                    icon: Icons.photo_library,
                    title: "Gallery",
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage();
                    },
                  ),
                  _buildImageSourceOption(
                    icon: Icons.camera_alt,
                    title: "Camera",
                    onTap: () {
                      Navigator.pop(context);
                      _takePhoto();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200, foregroundColor: Colors.black87, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 12)),
                  child: const Text("Cancel"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageSourceOption({required IconData icon, required String title, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(width: 60, height: 60, decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: AppTheme.primaryColor, size: 30)),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Future<String?> _uploadProfileImage() async {
    if (_newProfileImage == null) return null;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final fileName = 'profile_${const Uuid().v4()}.jpg';
      final ref = FirebaseStorage.instance.ref().child('profile_images').child(fileName);

      final uploadTask = ref.putFile(_newProfileImage!);
      final snapshot = await uploadTask.whenComplete(() => null);
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      print('Error uploading profile image: $e');
      return null;
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Upload new profile image if selected
      String? profileImageUrl;
      if (_newProfileImage != null) {
        profileImageUrl = await _uploadProfileImage();
        if (profileImageUrl != null) {
          await user.updatePhotoURL(profileImageUrl);
        }
      }

      // Update display name
      if (_displayNameController.text.trim() != user.displayName) {
        await user.updateDisplayName(_displayNameController.text.trim());
      }

      // Update email if changed
      if (_emailController.text.trim() != user.email) {
        await user.updateEmail(_emailController.text.trim());
      }

      // Update Firestore data
      await FirebaseFirestore.instance.collection('Users').doc(user.uid).update({'displayName': _displayNameController.text.trim(), 'email': _emailController.text.trim(), if (profileImageUrl != null) 'profileImageUrl': profileImageUrl, 'updatedAt': FieldValue.serverTimestamp()});

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green));

      // Update AuthProvider to refresh user data
      final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
      // Force a refresh of user data
      await Future.delayed(const Duration(milliseconds: 500));
      // await authProvider.refreshUserData();

      // Exit editing mode
      setState(() {
        _isEditing = false;
        _newProfileImage = null;
        _isSaving = false;
      });
    } catch (e) {
      print('Error saving profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating profile: ${e.toString()}'), backgroundColor: Colors.red));
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();

      // Navigate to login screen
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const PhoneLoginScreen()), (route) => false);
      }
    } catch (e) {
      print('Error signing out: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error signing out: ${e.toString()}'), backgroundColor: Colors.red));
    }
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _signOut();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AppAuthProvider>(context);
    final userData = authProvider.userData;
    final user = authProvider.user;

    if (userData == null || user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile header
                    _buildProfileHeader(userData, user),
                    const SizedBox(height: 24),

                    // Profile details section
                    _buildSectionHeader('Profile Details'),
                    const SizedBox(height: 12),
                    _buildProfileDetailsCard(userData, user),
                    const SizedBox(height: 24),

                    // Account info section
                    _buildSectionHeader('Account Information'),
                    const SizedBox(height: 12),
                    _buildAccountInfoCard(userData, user),
                    const SizedBox(height: 24),

                    // Actions section
                    _buildSectionHeader('Actions'),
                    const SizedBox(height: 12),
                    _buildActionsCard(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> userData, User user) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile image
            Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage:
                      _newProfileImage != null
                          ? FileImage(_newProfileImage!)
                          : userData['profileImageUrl'] != null
                          ? NetworkImage(userData['profileImageUrl'])
                          : null,
                  child: _newProfileImage == null && userData['profileImageUrl'] == null ? const Icon(Icons.person, size: 80, color: Colors.grey) : null,
                ),
                if (_isEditing)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(onTap: _showImageSourceDialog, child: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle), child: const Icon(Icons.camera_alt, color: Colors.white, size: 24))),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // User name and role
            _isEditing
                ? TextFormField(controller: _displayNameController, decoration: const InputDecoration(labelText: 'Display Name', border: OutlineInputBorder()))
                : Column(
                  children: [
                    Text(userData['displayName'] ?? 'Admin User', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.purple.withOpacity(0.5))),
                      child: const Text('ADMINISTRATOR', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
            const SizedBox(height: 16),

            // Edit/Save buttons
            _isEditing
                ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed:
                          _isSaving
                              ? null
                              : () {
                                setState(() {
                                  _isEditing = false;
                                  _newProfileImage = null;
                                  // Reset form values
                                  _loadUserData();
                                });
                              },
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.grey, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                      child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save Changes'),
                    ),
                  ],
                )
                : ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isEditing = true;
                    });
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Profile'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileDetailsCard(Map<String, dynamic> userData, User user) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Email
            _buildProfileDetailItem(
              title: 'Email',
              icon: Icons.email,
              isEditable: _isEditing,
              child: _isEditing ? TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder()), keyboardType: TextInputType.emailAddress) : Text(userData['email'] ?? 'No email provided', style: const TextStyle(fontSize: 16)),
            ),
            const Divider(height: 32),

            // Phone Number
            _buildProfileDetailItem(
              title: 'Phone Number',
              icon: Icons.phone,
              isEditable: false, // Phone number is not editable here, needs OTP verification
              child: Text(userData['phoneNumber'] ?? 'No phone number', style: const TextStyle(fontSize: 16)),
            ),

            // Gender
            if (userData['gender'] != null) ...[const Divider(height: 32), _buildProfileDetailItem(title: 'Gender', icon: Icons.person, isEditable: false, child: Text(userData['gender'], style: const TextStyle(fontSize: 16)))],

            // NRC Number
            if (userData['nrcNumber'] != null) ...[const Divider(height: 32), _buildProfileDetailItem(title: 'NRC Number', icon: Icons.credit_card, isEditable: false, child: Text(userData['nrcNumber'], style: const TextStyle(fontSize: 16)))],
          ],
        ),
      ),
    );
  }

  Widget _buildAccountInfoCard(Map<String, dynamic> userData, User user) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Account creation date
            _buildProfileDetailItem(title: 'Account Created', icon: Icons.calendar_today, isEditable: false, child: Text(userData['createdAt'] != null ? _formatTimestamp(userData['createdAt']) : 'Unknown', style: const TextStyle(fontSize: 16))),
            const Divider(height: 32),

            // Last login
            _buildProfileDetailItem(title: 'Last Login', icon: Icons.access_time, isEditable: false, child: Text(user.metadata.lastSignInTime != null ? _formatDateTime(user.metadata.lastSignInTime!) : 'Unknown', style: const TextStyle(fontSize: 16))),
            const Divider(height: 32),

            // App version
            _buildProfileDetailItem(
              title: 'App Version',
              icon: Icons.info_outline,
              isEditable: false,
              child: const Text(
                '1.0.0', // Hardcoded for demo
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Sign out button
            ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text('Sign Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)), onTap: _showSignOutDialog, contentPadding: EdgeInsets.zero),
            const Divider(),

            // Help & Support
            ListTile(
              leading: const Icon(Icons.help_outline, color: AppTheme.primaryColor),
              title: const Text('Help & Support'),
              onTap: () {
                // Navigate to help & support
              },
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),

            // About
            ListTile(
              leading: const Icon(Icons.info_outline, color: AppTheme.primaryColor),
              title: const Text('About'),
              onTap: () {
                // Show about dialog
              },
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Container(width: 40, height: 3, color: AppTheme.primaryColor)]);
  }

  Widget _buildProfileDetailItem({required String title, required IconData icon, required Widget child, required bool isEditable}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: AppTheme.primaryColor, size: 24)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(title, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                  if (isEditable) ...[const SizedBox(width: 4), Icon(Icons.edit, size: 14, color: Colors.grey.shade600)],
                ],
              ),
              const SizedBox(height: 8),
              child,
            ],
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    return _formatDateTime(date);
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
