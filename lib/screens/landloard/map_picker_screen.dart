import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:my_boarding_house_partner/utils/app_theme.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MapPickerScreen extends StatefulWidget {
  final LatLng initialLocation;
  final Set<Marker> initialMarkers;

  const MapPickerScreen({Key? key, required this.initialLocation, required this.initialMarkers}) : super(key: key);

  @override
  _MapPickerScreenState createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  late GoogleMapController _mapController;
  late Set<Marker> _markers;
  late LatLng _selectedLocation;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  String _searchError = '';

  // Zambia bounds (approximate)
  final LatLngBounds _zambiaBounds = LatLngBounds(
    southwest: const LatLng(-18.0, 22.0), // Southwest corner of Zambia
    northeast: const LatLng(-8.2, 34.0), // Northeast corner of Zambia
  );

  // Zambia center point (approximate)
  final LatLng _zambiaCenter = const LatLng(-13.133897, 27.849332);

  // Zambia major cities with coordinates - for fallback search
  final List<Map<String, dynamic>> _zambianCities = [
    {'name': 'Lusaka', 'lat': -15.3875, 'lng': 28.3228},
    {'name': 'Kitwe', 'lat': -12.8231, 'lng': 28.2118},
    {'name': 'Ndola', 'lat': -12.9587, 'lng': 28.6366},
    {'name': 'Kabwe', 'lat': -14.4469, 'lng': 28.4464},
    {'name': 'Chingola', 'lat': -12.5294, 'lng': 27.8543},
    {'name': 'Mufulira', 'lat': -12.5498, 'lng': 28.2407},
    {'name': 'Livingstone', 'lat': -17.8419, 'lng': 25.8544},
    {'name': 'Luanshya', 'lat': -13.1367, 'lng': 28.4166},
    {'name': 'Chipata', 'lat': -13.6333, 'lng': 32.6500},
    {'name': 'Choma', 'lat': -16.8092, 'lng': 26.9539},
  ];

  @override
  void initState() {
    super.initState();
    _markers = Set.from(widget.initialMarkers);

    // If the initial location is outside Zambia, use Zambia's center
    if (_isLocationInZambia(widget.initialLocation)) {
      _selectedLocation = widget.initialLocation;
    } else {
      _selectedLocation = _zambiaCenter;
      _markers.clear();
      _markers.add(Marker(markerId: const MarkerId('selectedLocation'), position: _zambiaCenter, draggable: false, infoWindow: const InfoWindow(title: 'Selected Location')));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isLocationInZambia(LatLng location) {
    return _zambiaBounds.contains(location);
  }

  // Try with direct Geocoding first
  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _searchError = '';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = '';
    });

    try {
      // First, try looking up Zambian cities directly
      final cityResults = _findZambianCities(query);

      if (cityResults.isNotEmpty) {
        setState(() {
          _searchResults = cityResults;
          _isSearching = false;
        });
        return;
      }

      // Try geocoding with Zambia in the query
      List<Location> locations = [];

      try {
        // First try with Zambia explicit
        locations = await locationFromAddress("$query, Zambia");
      } catch (e) {
        print('First geocoding attempt failed: $e');

        // If that fails, try without Zambia explicit
        try {
          locations = await locationFromAddress(query);
        } catch (e) {
          print('Second geocoding attempt failed: $e');
          // All geocoding attempts failed
        }
      }

      if (locations.isEmpty) {
        // Try OSM Nominatim as a fallback (doesn't require API key)
        await _searchWithNominatim(query);
        return;
      }

      // Convert locations to a format we can use for the UI
      List<Map<String, dynamic>> results = [];

      for (var i = 0; i < locations.length; i++) {
        Location location = locations[i];

        // Create position
        LatLng position = LatLng(location.latitude, location.longitude);

        // Filter for Zambia (but more lenient - don't filter here if we don't have many results)
        if (locations.length > 3 && !_isLocationInZambia(position)) {
          continue;
        }

        // Get placemark information for each location
        List<Placemark> placemarks = [];
        try {
          placemarks = await placemarkFromCoordinates(location.latitude, location.longitude);
        } catch (e) {
          print('Error getting placemark: $e');
          // Create a basic result if we can't get the placemark
          results.add({'displayName': 'Location in Zambia', 'position': position});
          continue;
        }

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;

          // Create a display name from the placemark data
          String displayName = '';

          if (place.name != null && place.name!.isNotEmpty && place.name != 'Unnamed Road') {
            displayName += place.name!;
          }

          if (place.street != null && place.street!.isNotEmpty && place.street != 'Unnamed Road') {
            if (displayName.isNotEmpty) displayName += ', ';
            displayName += place.street!;
          }

          if (place.subLocality != null && place.subLocality!.isNotEmpty) {
            if (displayName.isNotEmpty) displayName += ', ';
            displayName += place.subLocality!;
          }

          if (place.locality != null && place.locality!.isNotEmpty) {
            // Only add locality if it's not already part of the name
            if (displayName.isEmpty || !displayName.contains(place.locality!)) {
              if (displayName.isNotEmpty) displayName += ', ';
              displayName += place.locality!;
            }
          }

          if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
            if (displayName.isNotEmpty && !displayName.contains(place.administrativeArea!)) {
              displayName += ', ';
              displayName += place.administrativeArea!;
            }
          }

          // If the display name is still empty, use a default
          if (displayName.isEmpty) {
            displayName = 'Location in Zambia (${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)})';
          }

          results.add({'displayName': displayName, 'position': position});
        }
      }

      if (results.isEmpty) {
        // If we didn't get any results, try our fallback
        await _searchWithNominatim(query);
        return;
      }

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      print('Error searching for places: $e');
      setState(() {
        _isSearching = false;
        _searchError = 'Error searching for locations. Try a different search term.';
        _searchResults = [];
      });
    }
  }

  // Search Zambian cities from our predefined list
  List<Map<String, dynamic>> _findZambianCities(String query) {
    query = query.toLowerCase();
    List<Map<String, dynamic>> results = [];

    for (var city in _zambianCities) {
      if (city['name'].toString().toLowerCase().contains(query)) {
        results.add({'displayName': '${city['name']}, Zambia', 'position': LatLng(city['lat'], city['lng'])});
      }
    }

    return results;
  }

  // Use OpenStreetMap Nominatim as a fallback search provider
  Future<void> _searchWithNominatim(String query) async {
    try {
      final encodedQuery = Uri.encodeComponent('$query, Zambia');
      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&countrycodes=zm&limit=5'),
        headers: {
          'User-Agent': 'BoardingHousePartnerApp', // Nominatim requires a User-Agent
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final List<Map<String, dynamic>> results = [];

        for (var item in data) {
          final lat = double.tryParse(item['lat'].toString());
          final lon = double.tryParse(item['lon'].toString());

          if (lat != null && lon != null) {
            final position = LatLng(lat, lon);

            // Skip if not in Zambia
            if (!_isLocationInZambia(position)) {
              continue;
            }

            results.add({'displayName': item['display_name'], 'position': position});
          }
        }

        setState(() {
          _searchResults = results;
          _isSearching = false;
          if (results.isEmpty) {
            _searchError = 'No locations found in Zambia. Try a different search term.';
          }
        });
      } else {
        setState(() {
          _isSearching = false;
          _searchError = 'Search failed. Please try again.';
        });
      }
    } catch (e) {
      print('Nominatim search error: $e');
      setState(() {
        _isSearching = false;
        _searchError = 'Search service unavailable. Please try again later.';
      });
    }
  }

  void _selectSearchResult(Map<String, dynamic> result) {
    LatLng position = result['position'] as LatLng;

    // Update marker
    setState(() {
      _markers.clear();
      _markers.add(Marker(markerId: const MarkerId('selectedLocation'), position: position, draggable: false, infoWindow: const InfoWindow(title: 'Selected Location')));
      _selectedLocation = position;
    });

    // Move camera to the location
    _mapController.animateCamera(CameraUpdate.newLatLngZoom(position, 15));

    // Clear search results
    setState(() {
      _searchResults = [];
      _searchController.clear();
      _searchError = '';
    });

    // Hide keyboard
    FocusScope.of(context).unfocus();
  }

  void _onMapTap(LatLng latLng) {
    // Ensure the tapped location is within Zambia
    if (_isLocationInZambia(latLng)) {
      setState(() {
        _markers.clear();
        _markers.add(Marker(markerId: const MarkerId('selectedLocation'), position: latLng, draggable: false, infoWindow: const InfoWindow(title: 'Selected Location')));
        _selectedLocation = latLng;
      });

      // Get address for the selected location
      _getAddressForPoint(latLng);
    } else {
      // Show error message if location is outside Zambia
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a location within Zambia'), backgroundColor: Colors.red));
    }
  }

  Future<void> _getAddressForPoint(LatLng point) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(point.latitude, point.longitude);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String address = '';

        if (place.name != null && place.name!.isNotEmpty && place.name != 'Unnamed Road') {
          address += place.name!;
        }

        if (place.street != null && place.street!.isNotEmpty && place.street != 'Unnamed Road') {
          if (address.isNotEmpty) address += ', ';
          address += place.street!;
        }

        if (place.locality != null && place.locality!.isNotEmpty) {
          if (address.isNotEmpty) address += ', ';
          address += place.locality!;
        }

        if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
          if (address.isNotEmpty) address += ', ';
          address += place.administrativeArea!;
        }

        if (address.isNotEmpty) {
          // Update marker info window
          setState(() {
            _markers.clear();
            _markers.add(Marker(markerId: const MarkerId('selectedLocation'), position: point, draggable: false, infoWindow: InfoWindow(title: address)));
          });
        }
      }
    } catch (e) {
      print('Error getting address for point: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick a Location in Zambia', style: TextStyle(color: AppTheme.primaryColor)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.primaryColor),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, _selectedLocation);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
            child: const Text('Select'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search for a location in Zambia',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon:
                        _searchController.text.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchResults = [];
                                  _searchError = '';
                                });
                              },
                            )
                            : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                  ),
                  onChanged: (value) {
                    // Perform search after a short delay to avoid excessive API calls
                    Future.delayed(const Duration(milliseconds: 500), () {
                      if (value == _searchController.text) {
                        _searchPlaces(value);
                      }
                    });
                  },
                ),

                // Error message
                if (_searchError.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(_searchError, style: const TextStyle(color: Colors.red, fontSize: 12))),

                // Search results
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), spreadRadius: 1, blurRadius: 3, offset: const Offset(0, 2))]),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: _searchResults.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return ListTile(title: Text(result['displayName']), leading: const Icon(Icons.location_on), dense: true, onTap: () => _selectSearchResult(result));
                      },
                    ),
                  ),

                // Loading indicator
                if (_isSearching) Container(margin: const EdgeInsets.only(top: 8), child: const Center(child: CircularProgressIndicator())),
              ],
            ),
          ),

          // Zambia restriction notice
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(8)),
            child: const Row(children: [Icon(Icons.info_outline, color: Colors.amber), SizedBox(width: 8), Expanded(child: Text('Location selection is restricted to Zambia only', style: TextStyle(fontSize: 12)))]),
          ),

          // Search tips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Icon(Icons.tips_and_updates, color: Colors.blue, size: 16), SizedBox(width: 8), Text('Search Tips:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))]),
                SizedBox(height: 4),
                Text('• Try searching for city names like "Lusaka" or "Kitwe"', style: TextStyle(fontSize: 12)),
                Text('• Include area or district names for better results', style: TextStyle(fontSize: 12)),
                Text('• You can also tap directly on the map', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),

          // Map
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _selectedLocation,
                    zoom: 6, // Zoom out to show more of Zambia
                  ),
                  markers: _markers,
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller;

                    // Add bounds to restrict to Zambia
                    controller.animateCamera(CameraUpdate.newLatLngBounds(_zambiaBounds, 50));
                  },
                  onTap: _onMapTap,
                  cameraTargetBounds: CameraTargetBounds(_zambiaBounds),
                  minMaxZoomPreference: const MinMaxZoomPreference(5, 20),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                  compassEnabled: true,
                ),

                // Information overlay
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, _selectedLocation);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(vertical: 12)),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check), SizedBox(width: 8), Text('Confirm Location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
