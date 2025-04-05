import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:my_boarding_house_partner/providers/auth_provider.dart';
import 'package:my_boarding_house_partner/screens/auth/phone_login_screen.dart';
import 'package:my_boarding_house_partner/utils/app_theme.dart';
import 'package:my_boarding_house_partner/providers/auth_provider.dart';

class LandlordProfileScreen extends StatefulWidget {
  const LandlordProfileScreen({Key? key}) : super(key: key);

  @override
  _LandlordProfileScreenState createState() => _LandlordProfileScreenState();
}

class _LandlordProfileScreenState extends State<LandlordProfileScreen> {
  bool _isLoading = false;
  bool _isUpdating = false;
  File? _newProfileImage;
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _businessNameController = TextEditingController();

  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _businessNameController.dispose();
    super.dispose();
  }

  void _loadUserData() {
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final userData = authProvider.userData;

    if (userData != null) {
      _displayNameController.text = userData['displayName'] ?? '';
      _emailController.text = userData['email'] ?? '';
      _businessNameController.text = userData['businessName'] ?? '';
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
              const Text("Change Profile Picture", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
          Container(width: 60, height: 60, decoration: BoxDecoration(color: const Color(0xFF1F2B7E).withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: const Color(0xFF1F2B7E), size: 30)),
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

      final fileName = 'profile_${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child('profile_images').child(fileName);

      final uploadTask = ref.putFile(_newProfileImage!);
      final snapshot = await uploadTask.whenComplete(() => null);

      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading profile image: $e');
      return null;
    }
  }

  Future<void> _updateProfile() async {
    if (!_isEditing) {
      setState(() {
        _isEditing = true;
      });
      return;
    }

    // Validate form
    if (_displayNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your display name'), backgroundColor: Colors.red));
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Upload new profile image if selected
      String? profileImageUrl;
      if (_newProfileImage != null) {
        profileImageUrl = await _uploadProfileImage();
      }

      // Update display name in Firebase Auth
      await user.updateDisplayName(_displayNameController.text.trim());

      // Update email if changed
      if (_emailController.text.trim() != user.email && _emailController.text.trim().isNotEmpty) {
        await user.updateEmail(_emailController.text.trim());
      }

      // Update profile photo if available
      if (profileImageUrl != null) {
        await user.updatePhotoURL(profileImageUrl);
      }

      // Update Firestore document
      await FirebaseFirestore.instance.collection('Users').doc(user.uid).update({
        'displayName': _displayNameController.text.trim(),
        'email': _emailController.text.trim(),
        'businessName': _businessNameController.text.trim(),
        if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update AuthProvider
      final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
      // await authProvider._fetchUserData();

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green));

      setState(() {
        _isEditing = false;
        _newProfileImage = null;
      });
    } catch (e) {
      print('Error updating profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating profile: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  Future<void> _signOut() async {
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
              onPressed: () async {
                Navigator.of(context).pop();

                setState(() {
                  _isLoading = true;
                });

                try {
                  final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
                  await authProvider.signOut();

                  // Navigate to login screen
                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const PhoneLoginScreen()), (route) => false);
                  }
                } catch (e) {
                  print('Error signing out: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error signing out: ${e.toString()}'), backgroundColor: Colors.red));
                  }
                } finally {
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                    });
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }

  void _openPrivacyPolicy() async {
    const url = 'https://dododoba.com/privacy-policy';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open privacy policy'), backgroundColor: Colors.red));
    }
  }

  void _openHelpCenter() async {
    const url = 'https://dododoba.com/help-center';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open help center'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AppAuthProvider>(context);
    final userData = authProvider.userData;
    final user = authProvider.user;

    return Scaffold(
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: () async {
                  // await authProvider._fetchUserData();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile header
                      _buildProfileHeader(userData, user),
                      const SizedBox(height: 24),

                      // Edit profile section
                      _buildEditProfileSection(),
                      const SizedBox(height: 24),

                      // Other sections
                      _buildProfileMenuSection('Account', [
                        _buildMenuTile('Payment Methods', Icons.credit_card, () {
                          // Navigate to payment methods
                        }),
                        _buildMenuTile('Verification Status', Icons.verified_user, () {
                          // Navigate to verification status
                        }),
                        _buildMenuTile('Booking History', Icons.history, () {
                          // Navigate to booking history
                        }),
                      ]),
                      const SizedBox(height: 16),

                      _buildProfileMenuSection('Support', [_buildMenuTile('Help Center', Icons.help_outline, _openHelpCenter), _buildMenuTile('Privacy Policy', Icons.policy, _openPrivacyPolicy)]),
                      const SizedBox(height: 16),

                      // App version
                      Center(child: Text('App Version 1.0.0', style: TextStyle(color: Colors.grey.shade600, fontSize: 12))),
                      const SizedBox(height: 24),

                      // Sign out button
                      SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _signOut, icon: const Icon(Icons.logout), label: const Text('Sign Out'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 16)))),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic>? userData, User? user) {
    final bool isVerified = userData?['isVerified'] ?? false;

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
                          : userData?['profileImageUrl'] != null
                          ? NetworkImage(userData!['profileImageUrl'])
                          : null,
                  child: _newProfileImage == null && userData?['profileImageUrl'] == null ? const Icon(Icons.person, size: 60, color: Colors.grey) : null,
                ),
                if (_isEditing)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(onTap: _showImageSourceDialog, child: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Color(0xFF1F2B7E), shape: BoxShape.circle), child: const Icon(Icons.camera_alt, color: Colors.white, size: 20))),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // User name
            if (!_isEditing) Text(userData?['displayName'] ?? 'Landlord', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),

            // Verification badge
            if (!_isEditing) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: isVerified ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: isVerified ? Colors.green : Colors.orange)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isVerified ? Icons.verified_user : Icons.pending, size: 16, color: isVerified ? Colors.green : Colors.orange),
                    const SizedBox(width: 4),
                    Text(isVerified ? 'Verified Landlord' : 'Verification Pending', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isVerified ? Colors.green : Colors.orange)),
                  ],
                ),
              ),
            ],

            // User info
            if (!_isEditing) ...[
              const SizedBox(height: 16),
              if (userData?['email'] != null) _buildInfoItem(Icons.email, userData!['email']),
              if (userData?['phoneNumber'] != null) _buildInfoItem(Icons.phone, userData!['phoneNumber']),
              if (userData?['businessName'] != null && userData!['businessName'].isNotEmpty) _buildInfoItem(Icons.business, userData['businessName']),
            ],

            // Edit fields when editing
            if (_isEditing) ...[
              const SizedBox(height: 16),
              TextFormField(controller: _displayNameController, decoration: InputDecoration(labelText: 'Display Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 16),
              TextFormField(controller: _emailController, decoration: InputDecoration(labelText: 'Email', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),
              TextFormField(controller: _businessNameController, decoration: InputDecoration(labelText: 'Business Name (Optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
            ],

            // Edit profile button
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isUpdating ? null : _updateProfile,
                icon: Icon(_isEditing ? Icons.save : Icons.edit),
                label: _isUpdating ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(_isEditing ? 'Save Profile' : 'Edit Profile'),
                style: ElevatedButton.styleFrom(backgroundColor: _isEditing ? Colors.green : AppTheme.primaryColor, padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isEditing = false;
                    _newProfileImage = null;
                    _loadUserData(); // Reset form data
                  });
                },
                child: const Text('Cancel'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 16, color: Colors.grey.shade600), const SizedBox(width: 8), Text(text, style: TextStyle(fontSize: 14, color: Colors.grey.shade700))]));
  }

  Widget _buildEditProfileSection() {
    final authProvider = Provider.of<AppAuthProvider>(context);
    final userData = authProvider.userData;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.home_work, color: AppTheme.primaryColor)),
                const SizedBox(width: 12),
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Property Statistics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text('Overview of your listings', style: TextStyle(fontSize: 14, color: Colors.grey))]),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatTile('Total Properties', userData?['propertyCount']?.toString() ?? '0', Icons.apartment, Colors.blue),
                _buildStatTile('Total Rooms', userData?['roomCount']?.toString() ?? '0', Icons.meeting_room, Colors.orange),
                _buildStatTile('Bed Spaces', userData?['bedSpaceCount']?.toString() ?? '0', Icons.bed, Colors.purple),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: OutlinedButton.icon(
                onPressed: () {
                  // Navigate to property management
                },
                icon: const Icon(Icons.dashboard),
                label: const Text('View All Properties'),
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryColor, side: BorderSide(color: AppTheme.primaryColor), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildProfileMenuSection(String title, List<Widget> menuItems) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87))),
        Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Column(children: menuItems)),
      ],
    );
  }

  Widget _buildMenuTile(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle), child: Icon(icon, color: AppTheme.primaryColor, size: 20)),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 16))),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
