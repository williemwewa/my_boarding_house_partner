import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;

import 'package:my_boarding_house_partner/utils/app_theme.dart';
import 'package:my_boarding_house_partner/widgets/custom_dropdown.dart';
import 'package:my_boarding_house_partner/models/property_model.dart';

class AddPropertyScreen extends StatefulWidget {
  final Property? property; // If not null, we're editing an existing property

  const AddPropertyScreen({Key? key, this.property}) : super(key: key);

  @override
  _AddPropertyScreenState createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSubmitting = false;

  // Property form controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _zipCodeController = TextEditingController();

  // Property type and details
  String _propertyType = 'Apartment';
  final List<String> _propertyTypes = ['Apartment', 'House', 'Dormitory', 'Student Residence'];

  // Images
  List<File> _newImages = [];
  List<String> _existingImages = [];

  // Amenities
  final List<String> _allAmenities = ['Wi-Fi', 'Parking', 'Laundry', 'Security', 'Kitchen', 'TV', 'Air Conditioning', 'Heating', 'Study Area', 'Gym'];
  List<String> _selectedAmenities = [];

  // Rules
  final List<String> _allRules = ['No Smoking', 'No Pets', 'No Parties', 'Quiet Hours', 'No Guests Overnight', 'No Alcohol'];
  List<String> _selectedRules = [];

  // Location
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();

    // If we're editing an existing property, populate the form
    if (widget.property != null) {
      _loadPropertyData();
    }
  }

  void _loadPropertyData() {
    final property = widget.property!;

    setState(() {
      _nameController.text = property.name;
      _descriptionController.text = property.description;
      _addressController.text = property.address;
      _propertyType = property.propertyType;
      _existingImages = List<String>.from(property.photos);
      _selectedAmenities = List<String>.from(property.amenities);
      _selectedRules = List<String>.from(property.rules);
      _latitude = property.latitude;
      _longitude = property.longitude;

      // Parse city and zip code from address if available
      final addressParts = property.address.split(',');
      if (addressParts.length > 1) {
        _cityController.text = addressParts[addressParts.length - 2].trim();
      }
      if (addressParts.length > 0) {
        final lastPart = addressParts[addressParts.length - 1].trim();
        final zipMatch = RegExp(r'\d{5}').firstMatch(lastPart);
        if (zipMatch != null) {
          _zipCodeController.text = zipMatch.group(0)!;
        }
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _zipCodeController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();

    if (images.isNotEmpty) {
      setState(() {
        _newImages.addAll(images.map((image) => File(image.path)).toList());
      });
    }
  }

  Future<void> _takePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera);

    if (photo != null) {
      setState(() {
        _newImages.add(File(photo.path));
      });
    }
  }

  void _removeImage(int index, bool isExisting) {
    setState(() {
      if (isExisting) {
        _existingImages.removeAt(index);
      } else {
        _newImages.removeAt(index);
      }
    });
  }

  void _toggleAmenity(String amenity) {
    setState(() {
      if (_selectedAmenities.contains(amenity)) {
        _selectedAmenities.remove(amenity);
      } else {
        _selectedAmenities.add(amenity);
      }
    });
  }

  void _toggleRule(String rule) {
    setState(() {
      if (_selectedRules.contains(rule)) {
        _selectedRules.remove(rule);
      } else {
        _selectedRules.add(rule);
      }
    });
  }

  Future<List<String>> _uploadImages() async {
    List<String> imageUrls = [];

    // Keep existing images
    imageUrls.addAll(_existingImages);

    // Upload new images
    for (final image in _newImages) {
      final String fileName = '${const Uuid().v4()}${path.extension(image.path)}';
      final Reference ref = FirebaseStorage.instance.ref().child('properties').child(fileName);

      final UploadTask uploadTask = ref.putFile(image);
      final TaskSnapshot snapshot = await uploadTask.whenComplete(() => null);
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      imageUrls.add(downloadUrl);
    }

    return imageUrls;
  }

  Future<void> _saveProperty() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_existingImages.isEmpty && _newImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one image of the property'), backgroundColor: Colors.red));
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to add a property');
      }

      // Upload images to Firebase Storage
      final List<String> imageUrls = await _uploadImages();

      // Create or update property in Firestore
      final propertyData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'address': _addressController.text.trim(),
        'propertyType': _propertyType,
        'photos': imageUrls,
        'amenities': _selectedAmenities,
        'rules': _selectedRules,
        'landlordId': user.uid,
        'isActive': true,
        'isVerified': false, // Admin will need to verify
        'totalRooms': 0, // Will be updated as rooms are added
        'totalBedSpaces': 0, // Will be updated as bed spaces are added
        'occupiedBedSpaces': 0, // Will be updated as bookings are made
        'minPrice': 0, // Will be updated as bed spaces are added
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add location if available
      if (_latitude != null && _longitude != null) {
        propertyData['location'] = GeoPoint(_latitude!, _longitude!);
      }

      if (widget.property == null) {
        // Create new property
        propertyData['createdAt'] = FieldValue.serverTimestamp();

        await FirebaseFirestore.instance.collection('Properties').add(propertyData);

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Property added successfully! It will be reviewed by an administrator soon.'), backgroundColor: Colors.green));
      } else {
        // Update existing property
        await FirebaseFirestore.instance.collection('Properties').doc(widget.property!.id).update(propertyData);

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Property updated successfully!'), backgroundColor: Colors.green));
      }

      // Return to previous screen
      Navigator.pop(context);
    } catch (e) {
      print('Error saving property: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving property: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.property == null ? 'Add New Property' : 'Edit Property', style: const TextStyle(color: Colors.black87)), backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: Colors.black87)),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Progress indicator
                      LinearProgressIndicator(
                        value: 0.3, // Just an indicator for multi-step form
                        backgroundColor: Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                      ),
                      const SizedBox(height: 24),

                      // Basic property info section
                      _buildSectionHeader('Basic Information'),
                      const SizedBox(height: 16),

                      // Property name
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Property Name', hintText: 'e.g. Cozy Studio Near ZUT College', border: OutlineInputBorder()),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a property name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Property type
                      CustomDropdown(
                        label: 'Property Type',
                        value: _propertyType,
                        items: _propertyTypes,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _propertyType = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Property description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(labelText: 'Description', hintText: 'Describe your property...', border: OutlineInputBorder(), alignLabelWithHint: true),
                        maxLines: 5,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Location section
                      _buildSectionHeader('Location'),
                      const SizedBox(height: 16),

                      // Address
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(labelText: 'Address', hintText: 'Full street address', border: OutlineInputBorder()),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter an address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // City and Zip code
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _cityController,
                              decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder()),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter a city';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(flex: 1, child: TextFormField(controller: _zipCodeController, decoration: const InputDecoration(labelText: 'Zip Code', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Map button (will be implemented later)
                      OutlinedButton.icon(
                        onPressed: () {
                          // TODO: Implement map location picker
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Map location picker will be available soon')));
                        },
                        icon: const Icon(Icons.map),
                        label: const Text('Pick Location on Map'),
                        style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryColor, minimumSize: const Size(double.infinity, 48)),
                      ),
                      const SizedBox(height: 24),

                      // Photos section
                      _buildSectionHeader('Photos'),
                      const SizedBox(height: 8),
                      const Text('Add at least one photo of your property. High-quality photos help students make decisions.', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),

                      // Image picker
                      _buildImagePicker(),
                      const SizedBox(height: 24),

                      // Amenities section
                      _buildSectionHeader('Amenities'),
                      const SizedBox(height: 8),
                      const Text('Select all the amenities that your property offers.', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),

                      // Amenities chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            _allAmenities.map((amenity) {
                              final isSelected = _selectedAmenities.contains(amenity);
                              return FilterChip(
                                label: Text(amenity),
                                selected: isSelected,
                                onSelected: (_) => _toggleAmenity(amenity),
                                backgroundColor: Colors.grey.shade200,
                                selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                                checkmarkColor: AppTheme.primaryColor,
                                labelStyle: TextStyle(color: isSelected ? AppTheme.primaryColor : Colors.black87),
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // Rules section
                      _buildSectionHeader('House Rules'),
                      const SizedBox(height: 8),
                      const Text('Select all rules that apply to your property.', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),

                      // Rules chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            _allRules.map((rule) {
                              final isSelected = _selectedRules.contains(rule);
                              return FilterChip(
                                label: Text(rule),
                                selected: isSelected,
                                onSelected: (_) => _toggleRule(rule),
                                backgroundColor: Colors.grey.shade200,
                                selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                                checkmarkColor: AppTheme.primaryColor,
                                labelStyle: TextStyle(color: isSelected ? AppTheme.primaryColor : Colors.black87),
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 32),

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _saveProperty,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : Text(widget.property == null ? 'Add Property' : 'Update Property', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Note about verification
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.shade200)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [Icon(Icons.info_outline, color: Colors.orange.shade800, size: 20), const SizedBox(width: 8), const Text('Verification Required', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))]),
                            const SizedBox(height: 8),
                            const Text('All properties must be verified by an administrator before they become visible to students. This usually takes 1-2 business days.', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 8), Container(width: 40, height: 3, color: AppTheme.primaryColor)]);
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image selector buttons
        Row(
          children: [
            Expanded(child: OutlinedButton.icon(onPressed: _pickImages, icon: const Icon(Icons.photo_library), label: const Text('Pick from Gallery'), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)))),
            const SizedBox(width: 16),
            Expanded(child: OutlinedButton.icon(onPressed: _takePhoto, icon: const Icon(Icons.camera_alt), label: const Text('Take Photo'), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)))),
          ],
        ),
        const SizedBox(height: 16),

        // Image preview grid
        if (_existingImages.isNotEmpty || _newImages.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1),
            itemCount: _existingImages.length + _newImages.length,
            itemBuilder: (context, index) {
              if (index < _existingImages.length) {
                // Existing image
                return _buildImagePreview(NetworkImage(_existingImages[index]), () => _removeImage(index, true));
              } else {
                // New image
                final newIndex = index - _existingImages.length;
                return _buildImagePreview(FileImage(_newImages[newIndex]), () => _removeImage(newIndex, false));
              }
            },
          ),
      ],
    );
  }

  Widget _buildImagePreview(ImageProvider imageProvider, VoidCallback onRemove) {
    return Stack(
      children: [
        Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), image: DecorationImage(image: imageProvider, fit: BoxFit.cover))),
        Positioned(top: 4, right: 4, child: GestureDetector(onTap: onRemove, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 16)))),
      ],
    );
  }
}
