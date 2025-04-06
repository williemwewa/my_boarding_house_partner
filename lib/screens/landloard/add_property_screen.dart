import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:my_boarding_house_partner/screens/landloard/map_picker_screen.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'package:my_boarding_house_partner/utils/app_theme.dart';
import 'package:my_boarding_house_partner/widgets/custom_dropdown.dart';
import 'package:my_boarding_house_partner/models/property_model.dart';
// Import the map picker screen - update the path based on your project structure

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
  final List<String> _allAmenities = ['Wi-Fi', 'Parking', 'Laundry', 'Security', 'Kitchen', 'TV', 'Air Conditioning', 'Solar', 'Study Area', 'Gym', 'Washing Machine'];
  List<String> _selectedAmenities = [];

  // Rules
  final List<String> _allRules = ['No Smoking', 'No Pets', 'No Parties', 'Quiet Hours', 'No Guests Overnight', 'No Alcohol'];
  List<String> _selectedRules = [];

  // Location
  double? _latitude;
  double? _longitude;
  LatLng? _selectedLocation;
  CameraPosition _initialCameraPosition = CameraPosition(target: LatLng(0, 0), zoom: 15);
  bool _locationSelected = false;

  // Markers for the map
  final Set<Marker> _markers = {};

  // API endpoint for image uploads
  final String _imageUploadApiUrl = 'http://143.198.165.152/api/upload-image';

  @override
  void initState() {
    super.initState();

    // If we're editing an existing property, populate the form
    if (widget.property != null) {
      _loadPropertyData();
    } else {
      // Get current location for new properties
      _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // Permissions are denied, handle accordingly
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are denied'), backgroundColor: Colors.red));
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Permissions are permanently denied, handle accordingly
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are permanently denied, please enable them in settings'), backgroundColor: Colors.red));
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _initialCameraPosition = CameraPosition(target: LatLng(position.latitude, position.longitude), zoom: 15);

        // Add marker for the current location
        _markers.clear();
        _markers.add(Marker(markerId: const MarkerId('selectedLocation'), position: LatLng(position.latitude, position.longitude), draggable: false, infoWindow: const InfoWindow(title: 'Selected Location')));

        _isLoading = false;
      });

      // Get address from location
      _getAddressFromLatLng(position.latitude, position.longitude);
    } catch (e) {
      print('Error getting location: $e');
      setState(() {
        _isLoading = false;
        // Default to a generic location if unable to get current location
        _initialCameraPosition = const CameraPosition(
          target: LatLng(52.4064, 16.9252), // Default to Poznan, Poland
          zoom: 15,
        );
      });
    }
  }

  Future<void> _getAddressFromLatLng(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);

      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks.first;
        String street = placemark.street ?? '';
        String locality = placemark.locality ?? '';
        String postalCode = placemark.postalCode ?? '';
        String country = placemark.country ?? '';

        setState(() {
          _addressController.text = '$street, $locality, $postalCode, $country'.replaceAll(RegExp(r', ,'), ',').replaceAll(RegExp(r',,'), ',').replaceAll(RegExp(r', $'), '');
          _cityController.text = locality;
          _zipCodeController.text = postalCode;
          _locationSelected = true;
        });
      }
    } catch (e) {
      print('Error getting address from coordinates: $e');
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

      if (_latitude != null && _longitude != null) {
        _selectedLocation = LatLng(_latitude!, _longitude!);
        _initialCameraPosition = CameraPosition(target: _selectedLocation!, zoom: 15);

        // Add marker for the existing location
        _markers.clear();
        _markers.add(Marker(markerId: const MarkerId('selectedLocation'), position: _selectedLocation!, draggable: false, infoWindow: const InfoWindow(title: 'Property Location')));

        _locationSelected = true;
      }

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

  Future<void> _openMapPicker() async {
    final result = await Navigator.push<LatLng>(context, MaterialPageRoute(builder: (context) => MapPickerScreen(initialLocation: _selectedLocation ?? _initialCameraPosition.target, initialMarkers: _markers)));

    if (result != null) {
      setState(() {
        _selectedLocation = result;
        _latitude = result.latitude;
        _longitude = result.longitude;

        // Update markers
        _markers.clear();
        _markers.add(Marker(markerId: const MarkerId('selectedLocation'), position: result, draggable: false, infoWindow: const InfoWindow(title: 'Selected Location')));

        _locationSelected = true;
      });

      // Get address from the selected location
      _getAddressFromLatLng(result.latitude, result.longitude);
    }
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

  // Modified method to upload images to API instead of Firebase Storage
  Future<List<String>> _uploadImages() async {
    List<String> imageUrls = [];

    // Keep existing images
    imageUrls.addAll(_existingImages);

    // Upload new images using API endpoint
    for (final image in _newImages) {
      try {
        User? user = FirebaseAuth.instance.currentUser;
        if (user == null) continue;

        // Create a unique filename for the image
        String fileName = 'property_${user.uid}_${DateTime.now().millisecondsSinceEpoch}${path.extension(image.path)}';

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
            image.path,
            filename: fileName,
          ),
        );

        // Add additional parameters if needed by your API
        request.fields['user_id'] = user.uid;
        request.fields['file_type'] = 'property_image';
        request.fields['property_name'] = _nameController.text.trim();

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
          imageUrls.add(downloadUrl);
        } else {
          print('Failed to upload image. Status code: ${response.statusCode}');
          print('Response: $responseString');
        }
      } catch (e) {
        print('Error uploading image: $e');
      }
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

    if (!_locationSelected || _latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a location on the map'), backgroundColor: Colors.red));
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

      // Upload images to API
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

      // Add location
      propertyData['latitude'] = _latitude as Object;
      propertyData['longitude'] = _longitude as Object;
      propertyData['location'] = GeoPoint(_latitude!, _longitude!);

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
      appBar: AppBar(title: Text(widget.property == null ? 'Add New Property' : 'Edit Property', style: const TextStyle(color: AppTheme.primaryColor)), backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: AppTheme.primaryColor)),
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

                      // Map location picker
                      Container(
                        height: 200,
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                        child:
                            _selectedLocation != null
                                ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Stack(
                                    children: [
                                      // Static map image instead of GoogleMap
                                      Image.network(
                                        'https://maps.googleapis.com/maps/api/staticmap?center=${_selectedLocation!.latitude},${_selectedLocation!.longitude}&zoom=15&size=800x400&maptype=roadmap&markers=color:red%7C${_selectedLocation!.latitude},${_selectedLocation!.longitude}&key=YOUR_API_KEY', // Replace with your Google Maps API key
                                        width: double.infinity,
                                        height: 200,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.location_on, size: 48, color: AppTheme.primaryColor), Text('Location selected', style: TextStyle(color: Colors.grey[700]))]));
                                        },
                                      ),
                                      // Overlay to indicate the image is clickable
                                      Positioned.fill(child: Material(color: Colors.transparent, child: InkWell(onTap: _openMapPicker, borderRadius: BorderRadius.circular(8)))),
                                    ],
                                  ),
                                )
                                : Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.map, size: 48, color: Colors.grey[400]), const SizedBox(height: 8), Text('No location selected', style: TextStyle(color: Colors.grey[600]))])),
                      ),
                      const SizedBox(height: 16),

                      // Map picker button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _openMapPicker,
                          icon: const Icon(Icons.map),
                          label: const Text('Pick Location on Map'),
                          style: ElevatedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: AppTheme.primaryColor, minimumSize: const Size(double.infinity, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Address display (read-only)
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder(), filled: true, fillColor: Color(0xFFF5F5F5)),
                        readOnly: true,
                        enabled: false,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please select a location on the map';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // City and Zip code (read-only)
                      Row(
                        children: [
                          Expanded(flex: 2, child: TextFormField(controller: _cityController, decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder(), filled: true, fillColor: Color(0xFFF5F5F5)), readOnly: true, enabled: false)),
                          const SizedBox(width: 16),
                          Expanded(flex: 1, child: TextFormField(controller: _zipCodeController, decoration: const InputDecoration(labelText: 'Zip Code', border: OutlineInputBorder(), filled: true, fillColor: Color(0xFFF5F5F5)), readOnly: true, enabled: false)),
                        ],
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
                                labelStyle: TextStyle(color: isSelected ? AppTheme.primaryColor : AppTheme.primaryColor),
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
                          onPressed: _isSubmitting ? null : _saveProperty,
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          child:
                              _isSubmitting
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : Text(
                                    widget.property == null ? 'Add Property' : 'Update Property',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white, // Make text white
                                    ),
                                  ),
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
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [Icon(Icons.info_outline, size: 16, color: Colors.orange.shade800), const SizedBox(width: 8), const Expanded(child: Text("Verification Required", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor)))],
                            ),
                            const SizedBox(height: 8),
                            const Text("All properties must be verified by an administrator before they become visible to students. This usually takes 1-2 business days.", style: TextStyle(fontSize: 12)),
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
