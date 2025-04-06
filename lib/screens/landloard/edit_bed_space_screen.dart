import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_boarding_house_partner/models/property_model.dart';
import 'package:my_boarding_house_partner/services/property_service.dart';
import 'package:my_boarding_house_partner/utils/app_theme.dart';
import 'package:my_boarding_house_partner/widgets/form_input_field.dart';
import 'package:my_boarding_house_partner/widgets/loading_dialog.dart';

class EditBedSpaceScreen extends StatefulWidget {
  final String propertyId;
  final String roomId;
  final BedSpace bedSpace;
  final String propertyName;
  final String roomName;

  const EditBedSpaceScreen({Key? key, required this.propertyId, required this.roomId, required this.bedSpace, required this.propertyName, required this.roomName}) : super(key: key);

  @override
  _EditBedSpaceScreenState createState() => _EditBedSpaceScreenState();
}

class _EditBedSpaceScreenState extends State<EditBedSpaceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  String _priceUnit = 'month'; // Default price unit
  List<String> _selectedFeatures = [];
  List<File> _newImages = [];
  List<String> _existingImages = [];
  bool _isLoading = false;

  final List<String> _priceUnits = ['day', 'week', 'month', 'semester', 'year'];
  final List<String> _availableFeatures = ['Power Outlet', 'Reading Light', 'Privacy Curtain', 'Study Desk', 'Wardrobe', 'Bookshelf', 'Air Conditioning', 'Window View', 'Extra Storage', 'USB Charging Port'];

  final PropertyService _propertyService = PropertyService();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();

    // Initialize controllers with existing data
    _nameController.text = widget.bedSpace.name;
    _descriptionController.text = widget.bedSpace.description;
    _priceController.text = widget.bedSpace.price.toString();
    _priceUnit = widget.bedSpace.priceUnit;
    _selectedFeatures = List<String>.from(widget.bedSpace.features);
    _existingImages = List<String>.from(widget.bedSpace.photos);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
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

      showDialog(context: context, barrierDismissible: false, builder: (context) => const LoadingDialog(message: 'Updating bed space...'));

      try {
        Map<String, dynamic> bedSpaceData = {'name': _nameController.text.trim(), 'description': _descriptionController.text.trim(), 'price': double.parse(_priceController.text), 'priceUnit': _priceUnit, 'features': _selectedFeatures};

        await _propertyService.updateBedSpace(widget.propertyId, widget.roomId, widget.bedSpace.id, bedSpaceData, newImages: _newImages.isNotEmpty ? _newImages : null);

        Navigator.pop(context); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bed space updated successfully!'), backgroundColor: Colors.green));

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
    // Can't delete booked bed spaces
    if (widget.bedSpace.status == 'booked') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot delete a booked bed space. The booking must be cancelled first.'), backgroundColor: Colors.orange));
      return;
    }

    final bool confirmDelete =
        await showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Confirm Delete'),
              content: const Text('Are you sure you want to delete this bed space? This action cannot be undone.'),
              actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red)))],
            );
          },
        ) ??
        false;

    if (confirmDelete) {
      showDialog(context: context, barrierDismissible: false, builder: (context) => const LoadingDialog(message: 'Deleting bed space...'));

      try {
        await _propertyService.deleteBedSpace(widget.propertyId, widget.roomId, widget.bedSpace.id);

        Navigator.pop(context); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bed space deleted successfully!'), backgroundColor: Colors.green));

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
        title: const Text('Edit Bed Space', style: TextStyle(color: AppTheme.primaryColor)),
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
              Text('${widget.propertyName} > ${widget.roomName}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              // Bed space status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color:
                      widget.bedSpace.status == 'available'
                          ? Colors.green
                          : widget.bedSpace.status == 'maintenance'
                          ? Colors.orange
                          : Colors.blue,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(widget.bedSpace.status.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const SizedBox(height: 24),

              // Bed space name field
              FormInputField(
                controller: _nameController,
                labelText: 'Bed Space Name',
                hintText: 'e.g., Bed A, Lower Bunk',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Bed space name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Price field
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: FormInputField(
                      controller: _priceController,
                      labelText: 'Price',
                      hintText: 'e.g., 500',
                      prefixText: 'ZMW ',
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Price is required';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      value: _priceUnit,
                      decoration: const InputDecoration(labelText: 'Per', border: OutlineInputBorder()),
                      items:
                          _priceUnits.map((unit) {
                            return DropdownMenuItem(value: unit, child: Text(unit.substring(0, 1).toUpperCase() + unit.substring(1)));
                          }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _priceUnit = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Bed space description field
              FormInputField(
                controller: _descriptionController,
                labelText: 'Description',
                hintText: 'Describe the bed space...',
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Description is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Bed space features
              const Text('Features', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    _availableFeatures.map((feature) {
                      final isSelected = _selectedFeatures.contains(feature);
                      return FilterChip(
                        label: Text(feature),
                        selected: isSelected,
                        selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                        checkmarkColor: AppTheme.primaryColor,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedFeatures.add(feature);
                            } else {
                              _selectedFeatures.remove(feature);
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
                child: ElevatedButton(onPressed: _isLoading ? null : _submitForm, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, padding: const EdgeInsets.symmetric(vertical: 16)), child: const Text('Update Bed Space', style: TextStyle(fontSize: 16))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
