import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_boarding_house_partner/models/property_model.dart';
import 'package:my_boarding_house_partner/services/property_service.dart';
import 'package:my_boarding_house_partner/utils/app_theme.dart';
import 'package:my_boarding_house_partner/widgets/form_input_field.dart';
import 'package:my_boarding_house_partner/widgets/loading_dialog.dart';

class EditRoomScreen extends StatefulWidget {
  final Property property;
  final Room room;

  const EditRoomScreen({Key? key, required this.property, required this.room}) : super(key: key);

  @override
  _EditRoomScreenState createState() => _EditRoomScreenState();
}

class _EditRoomScreenState extends State<EditRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _areaController = TextEditingController();

  late String _roomType; // Will be initialized in initState
  List<String> _selectedAmenities = [];
  List<File> _newImages = [];
  List<String> _existingImages = [];
  bool _isLoading = false;

  // Define all possible room types - make sure lowercase for consistency
  final List<String> _roomTypes = ['single', 'double', 'triple', 'quad', 'dormitory', 'suite'];

  final List<String> _availableAmenities = ['Air Conditioning', 'Attached Bathroom', 'Balcony', 'Ceiling Fan', 'Desk', 'Private Entrance', 'Storage Cabinets', 'TV', 'WiFi', 'Window'];

  final PropertyService _propertyService = PropertyService();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();

    // Initialize controllers with existing data
    _nameController.text = widget.room.name;
    _descriptionController.text = widget.room.description;
    _areaController.text = widget.room.area.toString();

    // Normalize room type to lowercase for consistency
    String normalizedRoomType = widget.room.roomType.toLowerCase();

    // Check if the normalized room type exists in our list
    if (!_roomTypes.contains(normalizedRoomType)) {
      // If not, add it to our list of room types
      _roomTypes.add(normalizedRoomType);
    }

    // Set the room type to the normalized version
    _roomType = normalizedRoomType;

    _selectedAmenities = List<String>.from(widget.room.amenities);
    _existingImages = List<String>.from(widget.room.photos);

    // Debug printing
    print('Room type from database: ${widget.room.roomType}');
    print('Normalized room type: $_roomType');
    print('Available room types: $_roomTypes');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final List<XFile>? pickedFiles = await _picker.pickMultiImage();

    if (pickedFiles != null && pickedFiles.isNotEmpty) {
      setState(() {
        _newImages.addAll(pickedFiles.map((file) => File(file.path)).toList());
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      showDialog(context: context, barrierDismissible: false, builder: (context) => const LoadingDialog(message: 'Updating room...'));

      try {
        Map<String, dynamic> roomData = {'name': _nameController.text.trim(), 'description': _descriptionController.text.trim(), 'area': double.parse(_areaController.text), 'roomType': _roomType, 'amenities': _selectedAmenities};

        await _propertyService.updateRoom(widget.property.id, widget.room.id, roomData, newImages: _newImages.isNotEmpty ? _newImages : null);

        Navigator.pop(context); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room updated successfully!'), backgroundColor: Colors.green));

        Navigator.pop(context, true); // Return to previous screen with success indicator
      } catch (e) {
        Navigator.pop(context); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red));
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _confirmDelete() async {
    final bool confirmDelete =
        await showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Confirm Delete'),
              content: const Text('Are you sure you want to delete this room? This action cannot be undone, and all bed spaces in this room will also be deleted.'),
              actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red)))],
            );
          },
        ) ??
        false;

    if (confirmDelete) {
      showDialog(context: context, barrierDismissible: false, builder: (context) => const LoadingDialog(message: 'Deleting room...'));

      try {
        await _propertyService.deleteRoom(widget.property.id, widget.room.id);

        Navigator.pop(context); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room deleted successfully!'), backgroundColor: Colors.green));

        Navigator.pop(context, 'deleted'); // Return to previous screen with deleted indicator
      } catch (e) {
        Navigator.pop(context); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Room', style: TextStyle(color: AppTheme.primaryColor)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.primaryColor),
        actions: [TextButton.icon(onPressed: _confirmDelete, icon: const Icon(Icons.delete, color: Colors.red), label: const Text('Delete', style: TextStyle(color: Colors.red)))],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Property and room info
              Text(widget.property.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 24),

              // Room name field
              FormInputField(
                controller: _nameController,
                labelText: 'Room Name',
                hintText: 'e.g., Room 101, Master Bedroom',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Room name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Room type dropdown
              DropdownButtonFormField<String>(
                value: _roomType,
                decoration: const InputDecoration(labelText: 'Room Type', border: OutlineInputBorder()),
                items:
                    _roomTypes.map((type) {
                      return DropdownMenuItem(value: type, child: Text(type.substring(0, 1).toUpperCase() + type.substring(1)));
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

              // Room area field
              FormInputField(
                controller: _areaController,
                labelText: 'Room Area (m²)',
                hintText: 'e.g., 15',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Room area is required';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Room description field
              FormInputField(
                controller: _descriptionController,
                labelText: 'Room Description',
                hintText: 'Describe the room...',
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Room description is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Room amenities
              const Text('Room Amenities', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    _availableAmenities.map((amenity) {
                      final isSelected = _selectedAmenities.contains(amenity);
                      return FilterChip(
                        label: Text(amenity),
                        selected: isSelected,
                        selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                        checkmarkColor: AppTheme.primaryColor,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedAmenities.add(amenity);
                            } else {
                              _selectedAmenities.remove(amenity);
                            }
                          });
                        },
                      );
                    }).toList(),
              ),
              const SizedBox(height: 24),

              // Existing images
              if (_existingImages.isNotEmpty) ...[
                const Text('Existing Images', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _existingImages.length,
                    itemBuilder: (context, index) {
                      return Padding(padding: const EdgeInsets.only(right: 8), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(_existingImages[index], width: 100, height: 100, fit: BoxFit.cover)));
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // New images
              const Text('Add New Images', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton.icon(onPressed: _pickImages, icon: const Icon(Icons.add_a_photo), label: const Text('Add Images'), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor)),
                  const SizedBox(width: 16),
                  Text('${_newImages.length} new images selected', style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
                ],
              ),
              if (_newImages.isNotEmpty) ...[
                const SizedBox(height: 16),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _newImages.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(_newImages[index], width: 100, height: 100, fit: BoxFit.cover)),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _newImages.removeAt(index);
                                  });
                                },
                                child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.close, size: 16, color: Colors.red)),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 32),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: _isLoading ? null : _submitForm, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, padding: const EdgeInsets.symmetric(vertical: 16)), child: const Text('Update Room', style: TextStyle(fontSize: 16))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
