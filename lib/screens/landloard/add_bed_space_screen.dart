import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'package:my_boarding_house_partner/utils/app_theme.dart';
import 'package:my_boarding_house_partner/models/property_model.dart';

class AddBedSpaceScreen extends StatefulWidget {
  final String propertyId;
  final String roomId;
  final String propertyName;
  final String roomName;
  final BedSpace? bedSpace; // If editing an existing bed space

  const AddBedSpaceScreen({Key? key, required this.propertyId, required this.roomId, required this.propertyName, required this.roomName, this.bedSpace}) : super(key: key);

  @override
  _AddBedSpaceScreenState createState() => _AddBedSpaceScreenState();
}

class _AddBedSpaceScreenState extends State<AddBedSpaceScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSubmitting = false;

  // Form controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  // Bed space details
  String _priceUnit = 'per month';
  final List<String> _priceUnits = ['per month', 'per semester', 'per year'];

  String _status = 'available';
  final List<String> _statusOptions = ['available', 'maintenance'];

  // Features
  final List<String> _allFeatures = ['Study Desk', 'Wardrobe', 'Bookshelf', 'Window View', 'Reading Lamp', 'Privacy Curtain', 'Extra Storage', 'Power Outlet', 'Lockable Cabinet', 'Premium Mattress'];
  List<String> _selectedFeatures = [];

  // Images
  List<File> _newImages = [];
  List<String> _existingImages = [];

  @override
  void initState() {
    super.initState();

    // If we're editing an existing bed space, populate the form
    if (widget.bedSpace != null) {
      _loadBedSpaceData();
    }
  }

  void _loadBedSpaceData() {
    final bedSpace = widget.bedSpace!;

    setState(() {
      _nameController.text = bedSpace.name;
      _descriptionController.text = bedSpace.description;
      _priceController.text = bedSpace.price.toString();
      _priceUnit = bedSpace.priceUnit;
      _status = bedSpace.status;
      _selectedFeatures = List<String>.from(bedSpace.features);
      _existingImages = List<String>.from(bedSpace.photos);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
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

  void _toggleFeature(String feature) {
    setState(() {
      if (_selectedFeatures.contains(feature)) {
        _selectedFeatures.remove(feature);
      } else {
        _selectedFeatures.add(feature);
      }
    });
  }

  Future<List<String>> _uploadImages() async {
    List<String> imageUrls = [];

    // Keep existing images
    imageUrls.addAll(_existingImages);

    // If there are no new images, return just existing ones
    if (_newImages.isEmpty) {
      return imageUrls;
    }

    try {
      // Get authentication token for API request
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken() ?? '';

      // Upload each image via API
      for (final imageFile in _newImages) {
        // Create unique filename
        final String fileName = '${const Uuid().v4()}${path.extension(imageFile.path)}';

        // Prepare the API request
        final url = Uri.parse('http://143.198.165.152/api/upload-image');

        // Create multipart request
        var request = http.MultipartRequest('POST', url);

        // Set headers including authentication
        request.headers.addAll({'Authorization': 'Bearer $idToken', 'Content-Type': 'multipart/form-data'});

        // Add metadata fields
        request.fields['propertyId'] = widget.propertyId;
        request.fields['roomId'] = widget.roomId;
        request.fields['type'] = 'bedspace';

        // Add the file
        var fileStream = http.ByteStream(imageFile.openRead());
        var fileLength = await imageFile.length();

        // Determine content type based on file extension
        final fileExt = path.extension(imageFile.path).toLowerCase();
        String contentType = 'image/jpeg'; // default
        if (fileExt == '.png') {
          contentType = 'image/png';
        } else if (fileExt == '.gif') {
          contentType = 'image/gif';
        } else if (fileExt == '.webp') {
          contentType = 'image/webp';
        }

        var multipartFile = http.MultipartFile('image', fileStream, fileLength, filename: fileName, contentType: MediaType.parse(contentType));

        request.files.add(multipartFile);

        // Send the request
        var response = await request.send();

        // Process the response
        if (response.statusCode == 200) {
          // Get response data
          final responseData = await response.stream.bytesToString();
          final jsonData = json.decode(responseData);

          // Add the image URL from the API response
          if (jsonData['url'] != null) {
            imageUrls.add(jsonData['url']);
          } else {
            throw Exception('API returned success but no image URL');
          }
        } else {
          final responseData = await response.stream.bytesToString();
          throw Exception('Failed to upload image. Status: ${response.statusCode}, Response: $responseData');
        }
      }

      return imageUrls;
    } catch (e) {
      print('Error uploading images to API: $e');
      throw Exception('Failed to upload images: $e');
    }
  }

  Future<void> _saveBedSpace() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Upload images via API
      final List<String> imageUrls = await _uploadImages();

      // Parse form data
      final String name = _nameController.text.trim();
      final String description = _descriptionController.text.trim();
      final double price = double.parse(_priceController.text.trim());

      // Create bed space data
      final bedSpaceData = {'roomId': widget.roomId, 'propertyId': widget.propertyId, 'name': name, 'description': description, 'price': price, 'priceUnit': _priceUnit, 'status': _status, 'features': _selectedFeatures, 'photos': imageUrls, 'updatedAt': FieldValue.serverTimestamp()};

      if (widget.bedSpace == null) {
        // Create new bed space
        bedSpaceData['createdAt'] = FieldValue.serverTimestamp();

        await FirebaseFirestore.instance.collection('Properties').doc(widget.propertyId).collection('Rooms').doc(widget.roomId).collection('BedSpaces').add(bedSpaceData);

        // Update total bed spaces count in the room
        await FirebaseFirestore.instance.collection('Properties').doc(widget.propertyId).collection('Rooms').doc(widget.roomId).update({'totalBedSpaces': FieldValue.increment(1)});

        // Update total bed spaces count in the property
        await FirebaseFirestore.instance.collection('Properties').doc(widget.propertyId).update({'totalBedSpaces': FieldValue.increment(1), 'minPrice': await _updatePropertyMinPrice()});

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bed space added successfully!'), backgroundColor: Colors.green));
      } else {
        // Update existing bed space
        await FirebaseFirestore.instance.collection('Properties').doc(widget.propertyId).collection('Rooms').doc(widget.roomId).collection('BedSpaces').doc(widget.bedSpace!.id).update(bedSpaceData);

        // Update property min price if needed
        await FirebaseFirestore.instance.collection('Properties').doc(widget.propertyId).update({'minPrice': await _updatePropertyMinPrice()});

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bed space updated successfully!'), backgroundColor: Colors.green));
      }

      // Return to previous screen
      Navigator.pop(context);
    } catch (e) {
      print('Error saving bed space: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving bed space: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<double> _updatePropertyMinPrice() async {
    // Get all bed spaces for this property to calculate minimum price
    final QuerySnapshot roomsSnapshot = await FirebaseFirestore.instance.collection('Properties').doc(widget.propertyId).collection('Rooms').get();

    double minPrice = double.infinity;

    for (final roomDoc in roomsSnapshot.docs) {
      final bedSpacesSnapshot = await FirebaseFirestore.instance.collection('Properties').doc(widget.propertyId).collection('Rooms').doc(roomDoc.id).collection('BedSpaces').get();

      for (final bedSpaceDoc in bedSpacesSnapshot.docs) {
        final double price = (bedSpaceDoc.data()['price'] as num).toDouble();
        if (price < minPrice) {
          minPrice = price;
        }
      }
    }

    // If no bed spaces found, set minPrice to 0
    if (minPrice == double.infinity) {
      minPrice = 0;
    }

    return minPrice;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.bedSpace == null ? 'Add Bed Space' : 'Edit Bed Space', style: const TextStyle(color: AppTheme.primaryColor)), backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: AppTheme.primaryColor)),
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
                      // Property and room info
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        color: Colors.grey.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [const Icon(Icons.apartment, size: 16, color: AppTheme.primaryColor), const SizedBox(width: 8), Expanded(child: Text('Property: ${widget.propertyName}', style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis))]),
                              const SizedBox(height: 8),
                              Row(children: [const Icon(Icons.meeting_room, size: 16, color: AppTheme.primaryColor), const SizedBox(width: 8), Expanded(child: Text('Room: ${widget.roomName}', style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis))]),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Basic info section
                      _buildSectionHeader('Basic Information'),
                      const SizedBox(height: 16),

                      // Bed space name
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Bed Space Name/Number', hintText: 'e.g. Bed 1, Lower Bunk, etc.', border: OutlineInputBorder(), focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryColor))),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a name or number for this bed space';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Bed space description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(labelText: 'Description', hintText: 'Describe this bed space...', border: OutlineInputBorder(), focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryColor)), alignLabelWithHint: true),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Price section
                      _buildSectionHeader('Pricing'),
                      const SizedBox(height: 16),

                      // Price and unit
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _priceController,
                              decoration: const InputDecoration(labelText: 'Price (ZMW)', hintText: 'e.g. 650.00', border: OutlineInputBorder(), focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryColor)), prefixText: 'ZMW '),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter a price';
                                }
                                try {
                                  double.parse(value);
                                } catch (e) {
                                  return 'Please enter a valid number';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              value: _priceUnit,
                              decoration: const InputDecoration(labelText: 'Price Unit', border: OutlineInputBorder(), focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryColor))),
                              items:
                                  _priceUnits.map((String unit) {
                                    return DropdownMenuItem<String>(value: unit, child: Text(unit));
                                  }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _priceUnit = newValue;
                                  });
                                }
                              },
                              dropdownColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Status
                      DropdownButtonFormField<String>(
                        value: _status,
                        decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder(), focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryColor))),
                        items:
                            _statusOptions.map((String status) {
                              return DropdownMenuItem<String>(value: status, child: Text(status == 'available' ? 'Available' : 'Maintenance Required', style: TextStyle(color: status == 'available' ? Colors.green : Colors.orange)));
                            }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _status = newValue;
                            });
                          }
                        },
                        dropdownColor: Colors.white,
                      ),
                      const SizedBox(height: 24),

                      // Features section
                      _buildSectionHeader('Features'),
                      const SizedBox(height: 8),
                      const Text('Select all features available with this bed space.', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),

                      // Features chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            _allFeatures.map((feature) {
                              final isSelected = _selectedFeatures.contains(feature);
                              return FilterChip(
                                label: Text(feature),
                                selected: isSelected,
                                onSelected: (_) => _toggleFeature(feature),
                                backgroundColor: Colors.grey.shade200,
                                selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                                checkmarkColor: AppTheme.primaryColor,
                                labelStyle: TextStyle(color: isSelected ? AppTheme.primaryColor : Colors.black87),
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // Photos section
                      _buildSectionHeader('Photos'),
                      const SizedBox(height: 8),
                      const Text('Add photos of this bed space to help students make decisions.', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),

                      // Image picker
                      _buildImagePicker(),
                      const SizedBox(height: 32),

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _saveBedSpace,
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), disabledBackgroundColor: AppTheme.primaryColor.withOpacity(0.5)),
                          child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : Text(widget.bedSpace == null ? 'Add Bed Space' : 'Update Bed Space', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.photo_library, color: AppTheme.primaryColor),
                label: const Text('Pick from Gallery', style: TextStyle(color: AppTheme.primaryColor)),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), side: const BorderSide(color: AppTheme.primaryColor)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _takePhoto,
                icon: const Icon(Icons.camera_alt, color: AppTheme.primaryColor),
                label: const Text('Take Photo', style: TextStyle(color: AppTheme.primaryColor)),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), side: const BorderSide(color: AppTheme.primaryColor)),
              ),
            ),
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
