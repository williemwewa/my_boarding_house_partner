import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;

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

    // Upload new images
    for (final image in _newImages) {
      final String fileName = '${const Uuid().v4()}${path.extension(image.path)}';
      final Reference ref = FirebaseStorage.instance.ref().child('properties').child(widget.propertyId).child('rooms').child(widget.roomId).child('bedspaces').child(fileName);

      final UploadTask uploadTask = ref.putFile(image);
      final TaskSnapshot snapshot = await uploadTask.whenComplete(() => null);
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      imageUrls.add(downloadUrl);
    }

    return imageUrls;
  }

  Future<void> _saveBedSpace() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Upload images to Firebase Storage
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
      appBar: AppBar(title: Text(widget.bedSpace == null ? 'Add Bed Space' : 'Edit Bed Space', style: const TextStyle(color: Colors.black87)), backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: Colors.black87)),
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
                              Row(children: [const Icon(Icons.apartment, size: 16, color: Colors.grey), const SizedBox(width: 8), Expanded(child: Text('Property: ${widget.propertyName}', style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis))]),
                              const SizedBox(height: 8),
                              Row(children: [const Icon(Icons.meeting_room, size: 16, color: Colors.grey), const SizedBox(width: 8), Expanded(child: Text('Room: ${widget.roomName}', style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis))]),
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
                        decoration: const InputDecoration(labelText: 'Bed Space Name/Number', hintText: 'e.g. Bed 1, Lower Bunk, etc.', border: OutlineInputBorder()),
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
                        decoration: const InputDecoration(labelText: 'Description', hintText: 'Describe this bed space...', border: OutlineInputBorder(), alignLabelWithHint: true),
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
                              decoration: const InputDecoration(labelText: 'Price (ZMW)', hintText: 'e.g. 650.00', border: OutlineInputBorder(), prefixText: 'ZMW '),
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
                              decoration: const InputDecoration(labelText: 'Price Unit', border: OutlineInputBorder()),
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
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Status
                      DropdownButtonFormField<String>(
                        value: _status,
                        decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
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
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
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
