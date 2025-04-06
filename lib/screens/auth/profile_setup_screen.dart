import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:my_boarding_house_partner/screens/landloard/landlord_dashboard.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';

import 'package:my_boarding_house_partner/providers/auth_provider.dart';
import 'package:my_boarding_house_partner/screens/admin/admin_dashboard.dart';
import 'package:my_boarding_house_partner/utils/app_theme.dart';

class UserProfileSetupScreen extends StatefulWidget {
  const UserProfileSetupScreen({Key? key}) : super(key: key);

  @override
  _UserProfileSetupScreenState createState() => _UserProfileSetupScreenState();
}

class _UserProfileSetupScreenState extends State<UserProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _nrcNumberController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _businessNameController = TextEditingController();

  File? _profileImage;
  bool _isLoading = false;
  String _selectedRole = 'landlord'; // Always set to landlord
  String _selectedGender = 'Male';

  // API endpoint for image uploads
  final String _imageUploadApiUrl = 'http://143.198.165.152/api/upload-image';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _nrcNumberController.dispose();
    _emailController.dispose();
    _businessNameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          // Check if the user already has data in Firestore
          DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('Users').doc(user.uid).get();

          if (userDoc.exists && userDoc.data() != null && mounted) {
            Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

            // Populate the form fields with existing data
            setState(() {
              if (userData['displayName'] != null) {
                _displayNameController.text = userData['displayName'];
              } else if (user.displayName != null) {
                _displayNameController.text = user.displayName!;
              }

              if (userData['nrcNumber'] != null) {
                _nrcNumberController.text = userData['nrcNumber'];
              }

              if (userData['email'] != null) {
                _emailController.text = userData['email'];
              } else if (user.email != null) {
                _emailController.text = user.email!;
              }

              if (userData['businessName'] != null) {
                _businessNameController.text = userData['businessName'];
              }

              if (userData['gender'] != null) {
                _selectedGender = userData['gender'];
              }
            });
          } else if (user.displayName != null && mounted) {
            // If no Firestore data but user has display name
            _displayNameController.text = user.displayName!;
          }

          if (user.email != null && mounted) {
            _emailController.text = user.email!;
          }
        } catch (e) {
          print('Error loading user data: $e');
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 75);

    if (image != null && mounted) {
      setState(() {
        _profileImage = File(image.path);
      });
    }
  }

  Future<void> _takePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera, maxWidth: 512, maxHeight: 512, imageQuality: 75);

    if (image != null && mounted) {
      setState(() {
        _profileImage = File(image.path);
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
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200, foregroundColor: AppTheme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 12)),
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
    if (_profileImage == null) return null;

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      // Create a unique filename for the image
      String fileName = 'profile_${user.uid}_${DateTime.now().millisecondsSinceEpoch}${path.extension(_profileImage!.path)}';

      // Create multipart request
      var request = http.MultipartRequest('POST', Uri.parse(_imageUploadApiUrl));

      // Add authorization headers if required by your API
      request.headers.addAll({
        'Authorization': 'Bearer YOUR_API_TOKEN', // Replace with your API token or authentication method
        'Content-Type': 'multipart/form-data',
      });

      // Add the file as a multipart file
      request.files.add(
        await http.MultipartFile.fromPath(
          'image', // Field name expected by your API
          _profileImage!.path,
          filename: fileName,
        ),
      );

      // Add additional parameters if needed by your API
      request.fields['user_id'] = user.uid;
      request.fields['file_type'] = 'profile_image';

      // Send the request
      var response = await request.send();

      // Get response
      var responseData = await response.stream.toBytes();
      var responseString = String.fromCharCodes(responseData);
      var jsonResponse = jsonDecode(responseString);

      // Check if the request was successful
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Extract the URL from the response based on the provided format
        String downloadUrl = jsonResponse['url'];
        print('Image uploaded successfully: $downloadUrl');
        return downloadUrl;
      } else {
        print('Failed to upload image. Status code: ${response.statusCode}');
        print('Response: $responseString');
        return null;
      }
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _saveUserProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          _showErrorSnackBar('User not found. Please sign in again.');
        }
        return;
      }

      // Upload profile image if selected
      String? profileImageUrl = await _uploadProfileImage();

      // Update user display name
      await user.updateDisplayName(_displayNameController.text.trim());

      // Update user profile photo URL if available
      if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
        await user.updatePhotoURL(profileImageUrl);
      }

      // Get the user's email from Firebase Auth
      String userEmail = user.email ?? "";

      // Save additional user data to Firestore
      await FirebaseFirestore.instance.collection('Users').doc(user.uid).set({
        'displayName': _displayNameController.text.trim(),
        'nrcNumber': _nrcNumberController.text.trim(),
        'email': userEmail,
        'businessName': _businessNameController.text.trim(),
        'gender': _selectedGender,
        'phoneNumber': user.phoneNumber,
        'profileImageUrl': profileImageUrl ?? user.photoURL,
        'role': _selectedRole, // Always 'landlord'
        'userId': user.uid,
        'isVerified': false, // Admin needs to verify landlord accounts
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        _showSuccessSnackBar('Profile created successfully!');

        // Update the AuthProvider to fetch the latest user data
        //final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await Future.delayed(const Duration(milliseconds: 500)); // Give Firestore time to update

        // Navigate to landlord dashboard
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LandlordDashboard()), (route) => false);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error saving profile: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red.shade800, behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))));
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green.shade700, behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(elevation: 0, backgroundColor: Colors.white, iconTheme: const IconThemeData(color: AppTheme.primaryColor), title: const Text("Complete Your Profile", style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)), centerTitle: true),
        body: SafeArea(
          child:
              _isLoading && (_displayNameController.text.isEmpty && _nrcNumberController.text.isEmpty)
                  ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1F2B7E))))
                  : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Progress indicator
                          LinearProgressIndicator(value: 0.9, backgroundColor: Colors.grey.shade200, valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor)),
                          const SizedBox(height: 24),

                          // Header
                          Center(
                            child: Column(
                              children: [
                                const Text("Almost there!", style: TextStyle(fontSize: 28.0, color: AppTheme.primaryColor, fontWeight: FontWeight.bold, height: 1.2)),
                                const SizedBox(height: 12),
                                Text("Please complete your partner profile to continue", style: TextStyle(fontSize: 16.0, color: Colors.grey.shade700)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Profile image picker
                          Center(
                            child: GestureDetector(
                              onTap: _showImageSourceDialog,
                              child: Stack(
                                children: [
                                  CircleAvatar(radius: 60, backgroundColor: Colors.grey.shade200, backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null, child: _profileImage == null ? const Icon(Icons.person, size: 60, color: Colors.grey) : null),
                                  Positioned(bottom: 0, right: 0, child: Container(decoration: const BoxDecoration(color: Color(0xFF1F2B7E), shape: BoxShape.circle), padding: const EdgeInsets.all(8), child: const Icon(Icons.camera_alt, color: Colors.white, size: 20))),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Form fields
                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Display Name
                                const Text("Full Name", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _displayNameController,
                                  decoration: InputDecoration(
                                    hintText: "Enter your full name",
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1F2B7E), width: 2)),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter your name';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),

                                // NRC Number
                                const Text("NRC Number", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _nrcNumberController,
                                  decoration: InputDecoration(
                                    hintText: "Enter your NRC number",
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1F2B7E), width: 2)),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter your NRC number';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),

                                // Business Name (for landlords)
                                const Text("Business Name (Optional)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _businessNameController,
                                  decoration: InputDecoration(
                                    hintText: "Enter your business name if applicable",
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1F2B7E), width: 2)),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Gender
                                const Text("Gender", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
                                const SizedBox(height: 8),
                                Container(
                                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _selectedGender,
                                        isExpanded: true,
                                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF1F2B7E)),
                                        items:
                                            ['Male', 'Female', 'Other'].map((String value) {
                                              return DropdownMenuItem<String>(value: value, child: Text(value));
                                            }).toList(),
                                        onChanged: (String? newValue) {
                                          if (newValue != null && mounted) {
                                            setState(() {
                                              _selectedGender = newValue;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Information box about verification
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [Icon(Icons.info_outline, size: 20, color: Colors.orange.shade800), const SizedBox(width: 8), Text("Important Information", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange.shade800))]),
                                const SizedBox(height: 8),
                                Text("After submitting your profile, your account will need to be verified by an administrator before you can list properties. This helps ensure the security and quality of our platform.", style: TextStyle(fontSize: 14, color: Colors.orange.shade900)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Save button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _saveUserProfile,
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                              child:
                                  _isLoading
                                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white), strokeWidth: 2.5))
                                      : const Text("Complete Profile", style: TextStyle(fontSize: 18.0, color: Colors.white, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
        ),
      ),
    );
  }
}
