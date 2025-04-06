import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:my_boarding_house_partner/utils/app_theme.dart';

import 'package:my_boarding_house_partner/utils/app_theme.dart';
import 'package:my_boarding_house_partner/models/property_model.dart';

class AddRoomScreen extends StatefulWidget {
  final String propertyId;
  final Room? room; // If not null, we're editing an existing room

  const AddRoomScreen({Key? key, required this.propertyId, this.room}) : super(key: key);

  @override
  _AddRoomScreenState createState() => _AddRoomScreenState();
}

class _AddRoomScreenState extends State<AddRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSubmitting = false;

  // Room form controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _areaController = TextEditingController();
  final _totalBedSpacesController = TextEditingController();

  // Room type
  String _roomType = 'Single';
  final List<String> _roomTypes = ['Single', 'Double', 'Triple', 'Quad', 'Dormitory'];

  // Images
  List<File> _newImages = [];
  List<String> _existingImages = [];

  // Amenities
  final List<String> _allAmenities = ['Wi-Fi', 'TV', 'Air Conditioning', 'Heating', 'Desk', 'Wardrobe', 'Private Bathroom', 'Shared Bathroom', 'Reading Light'];
  List<String> _selectedAmenities = [];

  @override
  void initState() {
    super.initState();

    // If we're editing an existing room, populate the form
    if (widget.room != null) {
      _loadRoomData();
    }
  }

  void _loadRoomData() {
    final room = widget.room!;

    setState(() {
      _nameController.text = room.name;
      _descriptionController.text = room.description;
      _areaController.text = room.area.toString();
      _totalBedSpacesController.text = room.totalBedSpaces.toString();
      _roomType = room.roomType;
      _existingImages = List<String>.from(room.photos);
      _selectedAmenities = List<String>.from(room.amenities);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _areaController.dispose();
    _totalBedSpacesController.dispose();
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

  Future<List<String>> _uploadImages() async {
    List<String> imageUrls = [];

    // Keep existing images
    imageUrls.addAll(_existingImages);

    // If there are no new images, return just the existing ones
    if (_newImages.isEmpty) {
      return imageUrls;
    }

    try {
      // Get authentication token for API request
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken() ?? '';

      // Upload new images via API
      for (final imageFile in _newImages) {
        // Create unique filename
        final String fileName = '${const Uuid().v4()}${path.extension(imageFile.path)}';

        // Prepare the request
        final url = Uri.parse('http://143.198.165.152/api/upload-image');

        // Create multipart request
        var request = http.MultipartRequest('POST', url);

        // Set headers including authentication
        request.headers.addAll({'Authorization': 'Bearer $idToken', 'Content-Type': 'multipart/form-data'});

        // Add other fields
        request.fields['propertyId'] = widget.propertyId;
        request.fields['type'] = 'room';

        // Add the file
        var fileStream = http.ByteStream(imageFile.openRead());
        var fileLength = await imageFile.length();

        // Determine media type based on file extension
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
          throw Exception('Failed to upload image. Status code: ${response.statusCode}');
        }
      }

      return imageUrls;
    } catch (e) {
      print('Error uploading images to API: $e');
      throw Exception('Failed to upload images: $e');
    }
  }

  Future<void> _saveRoom() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to add a room');
      }

      // Upload images via API
      final List<String> imageUrls = await _uploadImages();

      // Create or update room in Firestore
      final roomData = {
        'propertyId': widget.propertyId,
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'roomType': _roomType,
        'totalBedSpaces': int.parse(_totalBedSpacesController.text.trim()),
        'area': double.parse(_areaController.text.trim()),
        'photos': imageUrls,
        'amenities': _selectedAmenities,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.room == null) {
        // Create new room
        roomData['createdAt'] = FieldValue.serverTimestamp();

        final DocumentReference roomRef = await FirebaseFirestore.instance.collection('Properties').doc(widget.propertyId).collection('Rooms').add(roomData);

        // Update property totalRooms count
        final propertyRef = FirebaseFirestore.instance.collection('Properties').doc(widget.propertyId);

        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final propertyDoc = await transaction.get(propertyRef);
          if (!propertyDoc.exists) {
            throw Exception('Property does not exist');
          }

          final int currentRoomCount = propertyDoc.data()?['totalRooms'] ?? 0;
          final int currentBedSpaces = propertyDoc.data()?['totalBedSpaces'] ?? 0;

          transaction.update(propertyRef, {'totalRooms': currentRoomCount + 1, 'totalBedSpaces': currentBedSpaces + int.parse(_totalBedSpacesController.text.trim()), 'updatedAt': FieldValue.serverTimestamp()});
        });

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room added successfully!'), backgroundColor: Colors.green));
      } else {
        // Update existing room
        // First, get the current bed space count
        final roomRef = FirebaseFirestore.instance.collection('Properties').doc(widget.propertyId).collection('Rooms').doc(widget.room!.id);

        final roomDoc = await roomRef.get();
        final int oldBedSpaceCount = roomDoc.data()?['totalBedSpaces'] ?? 0;
        final int newBedSpaceCount = int.parse(_totalBedSpacesController.text.trim());

        // Update the room
        await roomRef.update(roomData);

        // If bed space count changed, update property totalBedSpaces count
        if (oldBedSpaceCount != newBedSpaceCount) {
          final propertyRef = FirebaseFirestore.instance.collection('Properties').doc(widget.propertyId);

          await FirebaseFirestore.instance.runTransaction((transaction) async {
            final propertyDoc = await transaction.get(propertyRef);
            if (!propertyDoc.exists) {
              throw Exception('Property does not exist');
            }

            final int currentBedSpaces = propertyDoc.data()?['totalBedSpaces'] ?? 0;

            transaction.update(propertyRef, {'totalBedSpaces': currentBedSpaces - oldBedSpaceCount + newBedSpaceCount, 'updatedAt': FieldValue.serverTimestamp()});
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room updated successfully!'), backgroundColor: Colors.green));
      }

      // Return to previous screen
      Navigator.pop(context);
    } catch (e) {
      print('Error saving room: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving room: ${e.toString()}'), backgroundColor: Colors.red));
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
      appBar: AppBar(title: Text(widget.room == null ? 'Add New Room' : 'Edit Room', style: const TextStyle(color: AppTheme.primaryColor)), backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: AppTheme.primaryColor)),
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
                      // Basic room info section
                      _buildSectionHeader('Basic Information'),
                      const SizedBox(height: 16),

                      // Room name
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Room Name', hintText: 'e.g. Room A101, Master Bedroom', border: OutlineInputBorder()),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a room name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Room type dropdown
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Room Type', border: OutlineInputBorder()),
                        value: _roomType,
                        items:
                            _roomTypes.map((type) {
                              return DropdownMenuItem<String>(value: type, child: Text(type));
                            }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _roomType = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Room description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(labelText: 'Description', hintText: 'Describe the room...', border: OutlineInputBorder(), alignLabelWithHint: true),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Room area and bed spaces
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _areaController,
                              decoration: const InputDecoration(labelText: 'Area (m²)', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter area';
                                }
                                if (double.tryParse(value) == null) {
                                  return 'Invalid number';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _totalBedSpacesController,
                              decoration: const InputDecoration(labelText: 'Bed Spaces', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter count';
                                }
                                if (int.tryParse(value) == null) {
                                  return 'Invalid number';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Photos section
                      _buildSectionHeader('Photos'),
                      const SizedBox(height: 8),
                      const Text('Add photos of the room. High-quality photos help students make decisions.', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),

                      // Image picker
                      _buildImagePicker(),
                      const SizedBox(height: 24),

                      // Amenities section
                      _buildSectionHeader('Amenities'),
                      const SizedBox(height: 8),
                      const Text('Select all the amenities that this room offers.', style: TextStyle(color: Colors.grey)),
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
                                labelStyle: TextStyle(color: isSelected ? AppTheme.primaryColor : AppTheme.primaryColor),
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 32),

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _saveRoom,
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          child:
                              _isSubmitting
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : Text(
                                    widget.room == null ? 'Add Room' : 'Update Room',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white, // Set text color to white
                                    ),
                                  ),
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
