import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:my_boarding_house_partner/screens/landloard/add_property_screen.dart';
import 'package:my_boarding_house_partner/screens/landloard/add_room_screen.dart';
import 'package:my_boarding_house_partner/screens/landloard/room_details_screen.dart';
import 'package:provider/provider.dart';

import 'package:my_boarding_house_partner/models/property_model.dart';
import 'package:my_boarding_house_partner/providers/auth_provider.dart';
import 'package:my_boarding_house_partner/utils/app_theme.dart';
import 'package:my_boarding_house_partner/widgets/empty_state_widget.dart';

class PropertyDetailsScreen extends StatefulWidget {
  final Property property;

  const PropertyDetailsScreen({Key? key, required this.property}) : super(key: key);

  @override
  _PropertyDetailsScreenState createState() => _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends State<PropertyDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  List<Room> _rooms = [];
  StreamSubscription<QuerySnapshot>? _roomsSubscription;

  // Google Maps controller
  Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRooms();

    // Initialize the marker if latitude and longitude are available
    if (widget.property.latitude != null && widget.property.longitude != null) {
      _markers.add(Marker(markerId: MarkerId(widget.property.id), position: LatLng(widget.property.latitude!, widget.property.longitude!), infoWindow: InfoWindow(title: widget.property.name, snippet: widget.property.address)));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _roomsSubscription?.cancel();
    super.dispose();
  }

  void _loadRooms() {
    setState(() {
      _isLoading = true;
    });

    // Subscribe to real-time updates for rooms in this property
    _roomsSubscription = FirebaseFirestore.instance
        .collection('Properties')
        .doc(widget.property.id)
        .collection('Rooms')
        .snapshots()
        .listen(
          (snapshot) {
            if (mounted) {
              setState(() {
                _rooms = snapshot.docs.map((doc) => Room.fromFirestore(doc)).toList();

                // Sort rooms: by name (alphabetically)
                _rooms.sort((a, b) => a.name.compareTo(b.name));

                _isLoading = false;
              });
            }
          },
          onError: (error) {
            print('Error loading rooms: $error');
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
        );
  }

  Future<void> _togglePropertyStatus() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final newStatus = !widget.property.isActive;

      await FirebaseFirestore.instance.collection('Properties').doc(widget.property.id).update({'isActive': newStatus, 'updatedAt': FieldValue.serverTimestamp()});

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(newStatus ? 'Property activated successfully!' : 'Property deactivated successfully!'), backgroundColor: newStatus ? Colors.green : Colors.orange));
    } catch (e) {
      print('Error toggling property status: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating property: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _editProperty() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (context) => AddPropertyScreen(property: widget.property)));
  }

  Future<void> _addRoom() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (context) => AddRoomScreen(propertyId: widget.property.id)));
  }

  Future<void> _navigateToRoomDetails(Room room) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (context) => RoomDetailsScreen(property: widget.property, room: room)));
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AppAuthProvider>(context);
    final isVerified = authProvider.userData?['isVerified'] == true;

    return Scaffold(
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    // SliverAppBar with carousel
                    SliverAppBar(
                      expandedHeight: 300,
                      floating: false,
                      pinned: true,
                      backgroundColor: Colors.white,
                      iconTheme: const IconThemeData(color: Colors.white),
                      flexibleSpace: FlexibleSpaceBar(
                        background: Stack(
                          children: [
                            // Image carousel
                            _buildPropertyImagesCarousel(),

                            // Gradient overlay for better visibility of buttons
                            Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.center, colors: [Colors.black.withOpacity(0.5), Colors.transparent]))),

                            // Status badges overlaid on the image
                            Positioned(
                              bottom: 16,
                              left: 16,
                              child: Row(
                                children: [
                                  // Verification badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(color: widget.property.isVerified ? Colors.teal : Colors.orange, borderRadius: BorderRadius.circular(20)),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(widget.property.isVerified ? Icons.verified : Icons.pending, color: Colors.white, size: 16),
                                        const SizedBox(width: 4),
                                        Text(widget.property.isVerified ? 'Verified' : 'Pending', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Active/Inactive badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(color: widget.property.isActive ? Colors.green : Colors.grey, borderRadius: BorderRadius.circular(20)),
                                    child: Text(widget.property.isActive ? 'Active' : 'Inactive', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                ],
                              ),
                            ),

                            // Image counter indicator
                            if (widget.property.photos.isNotEmpty)
                              Positioned(
                                bottom: 16,
                                right: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(12)),
                                  child: Text('1/${widget.property.photos.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ),
                          ],
                        ),
                      ),
                      actions: [
                        // Share button
                        CircleAvatar(backgroundColor: Colors.white, radius: 16, child: IconButton(icon: const Icon(Icons.share, color: Colors.black, size: 16), onPressed: () {})),
                        const SizedBox(width: 8),
                        // Favorite/like button
                        CircleAvatar(backgroundColor: Colors.white, radius: 16, child: IconButton(icon: const Icon(Icons.favorite_border, color: Colors.black, size: 16), onPressed: () {})),
                        const SizedBox(width: 8),
                        // Edit button (for landlords)
                        CircleAvatar(backgroundColor: Colors.white, radius: 16, child: IconButton(icon: const Icon(Icons.edit, color: Colors.black, size: 16), onPressed: _editProperty)),
                        const SizedBox(width: 8),
                        // More options menu
                        CircleAvatar(
                          backgroundColor: Colors.white,
                          radius: 16,
                          child: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: Colors.black, size: 16),
                            onSelected: (value) {
                              if (value == 'status') {
                                _togglePropertyStatus();
                              }
                            },
                            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[PopupMenuItem<String>(value: 'status', child: Text(widget.property.isActive ? 'Mark as Inactive' : 'Mark as Active'))],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),

                    // Property title and location
                    SliverToBoxAdapter(child: _buildPropertyHeader()),

                    // Tab bar
                    SliverPersistentHeader(
                      delegate: _SliverAppBarDelegate(TabBar(controller: _tabController, tabs: const [Tab(text: 'Overview'), Tab(text: 'Rooms'), Tab(text: 'Bookings')], indicatorColor: AppTheme.primaryColor, labelColor: AppTheme.primaryColor, unselectedLabelColor: Colors.grey)),
                      pinned: true,
                    ),
                  ];
                },
                body: Stack(
                  children: [
                    TabBarView(controller: _tabController, children: [_buildOverviewTab(), _buildRoomsTab(isVerified), _buildBookingsTab()]),

                    // Sticky reserve/price bar at bottom
                    // Positioned(
                    //   left: 0,
                    //   right: 0,
                    //   bottom: 0,
                    //   child: Container(
                    //     padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    //     decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, -4))]),
                    //     child: Row(
                    //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    //       children: [
                    //         // Price info
                    //         Column(
                    //           crossAxisAlignment: CrossAxisAlignment.start,
                    //           mainAxisSize: MainAxisSize.min,
                    //           children: [
                    //             Row(children: [Text('\$${widget.property.minPrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const Text(' / night', style: TextStyle(fontSize: 16))]),
                    //             const SizedBox(height: 4),
                    //             Row(children: [const Icon(Icons.star, size: 14), const SizedBox(width: 4), const Text('4.92', style: TextStyle(fontSize: 14)), Text(' · 88 reviews', style: TextStyle(fontSize: 14, color: Colors.grey[600]))]),
                    //           ],
                    //         ),

                    //         // Reserve button
                    //         ElevatedButton(
                    //           onPressed: () {},
                    //           style: ElevatedButton.styleFrom(
                    //             backgroundColor: const Color(0xFFFF385C), // Airbnb red
                    //             foregroundColor: Colors.white,
                    //             padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    //             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    //           ),
                    //           child: const Text('Book Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    //         ),
                    //       ],
                    //     ),
                    //   ),
                    // ),
                  ],
                ),
              ),
    );
  }

  Widget _buildPropertyImagesCarousel() {
    return CarouselSlider(
      options: CarouselOptions(height: 300, viewportFraction: 1.0, enlargeCenterPage: false, autoPlay: widget.property.photos.length > 1, autoPlayInterval: const Duration(seconds: 4)),
      items:
          widget.property.photos.isNotEmpty
              ? widget.property.photos.map((url) {
                return Builder(
                  builder: (BuildContext context) {
                    return Image.network(url, fit: BoxFit.cover, width: double.infinity, errorBuilder: (ctx, error, stackTrace) => Container(color: Colors.grey.shade300, child: const Icon(Icons.image_not_supported, size: 50, color: Colors.white)));
                  },
                );
              }).toList()
              : [Container(color: Colors.grey.shade300, child: const Icon(Icons.apartment, size: 80, color: Colors.white))],
    );
  }

  Widget _buildPropertyHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Property name
          Text(widget.property.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          // Location
          Row(children: [const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey), const SizedBox(width: 4), Expanded(child: Text(widget.property.address, style: TextStyle(fontSize: 14, color: Colors.grey.shade700), maxLines: 1, overflow: TextOverflow.ellipsis))]),
          const SizedBox(height: 16),

          // Stats row (similar to original, but with Airbnb styling)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPropertyStat(Icons.meeting_room_outlined, 'Rooms', widget.property.totalRooms.toString()),
              _buildPropertyStat(Icons.bed_outlined, 'Bed Spaces', widget.property.totalBedSpaces.toString()),
              _buildPropertyStat(Icons.person_outlined, 'Occupied', '${widget.property.occupiedBedSpaces}/${widget.property.totalBedSpaces}'),
              _buildPropertyStat(Icons.calendar_today_outlined, 'Added', DateFormat('MMM d, yyyy').format(widget.property.createdAt)),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPropertyStat(IconData icon, String label, String value) {
    return Column(children: [Icon(icon, size: 24, color: AppTheme.primaryColor), const SizedBox(height: 4), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 2), Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))]);
  }

  Widget _buildOverviewTab() {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), // Bottom padding for the reserve button
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Host information
              Row(
                children: [
                  // Host image
                  CircleAvatar(radius: 24, backgroundImage: const NetworkImage('https://via.placeholder.com/100'), backgroundColor: Colors.grey[300]),
                  const SizedBox(width: 12),

                  // Host details
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Landloard ${widget.property.landlordId}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      // Row(children: [Icon(Icons.verified_user, size: 14, color: Colors.teal), const SizedBox(width: 4), Text('Superhost · 4 years hosting', style: TextStyle(fontSize: 14, color: Colors.grey[700]))]),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Property highlights
              // _buildHighlightItem(Icons.door_front_door_outlined, 'Self check-in', 'Check yourself in with the lockbox.'),
              // const SizedBox(height: 16),

              // _buildHighlightItem(Icons.landscape_outlined, 'Mountain and lake views', 'Guests say the views are amazing.'),
              // const SizedBox(height: 16),

              // _buildHighlightItem(Icons.local_parking_outlined, 'Park for free', 'This is one of the few places in the area with free parking.'),

              // const SizedBox(height: 24),
              Divider(height: 1, thickness: 1, color: Colors.grey[300]),
              const SizedBox(height: 24),

              // Description section
              _buildSectionHeader('Description'),
              const SizedBox(height: 12),
              Text(widget.property.description, style: TextStyle(fontSize: 16, color: Colors.grey.shade800, height: 1.5)),
              const SizedBox(height: 24),

              // Property type section
              _buildSectionHeader('Property Type'),
              const SizedBox(height: 12),
              Row(children: [Icon(_getPropertyTypeIcon(widget.property.propertyType), color: AppTheme.primaryColor), const SizedBox(width: 8), Text(widget.property.propertyType, style: const TextStyle(fontSize: 16))]),
              const SizedBox(height: 24),

              // Amenities section
              _buildSectionHeader('Amenities'),
              const SizedBox(height: 12),
              widget.property.amenities.isEmpty
                  ? Text('No amenities specified.', style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontStyle: FontStyle.italic))
                  : Column(
                    children: [
                      ...widget.property.amenities.take(6).map((amenity) => _buildAmenityItem(amenity)).toList(),
                      const SizedBox(height: 16),
                      if (widget.property.amenities.length > 6)
                        OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), side: BorderSide(color: Colors.grey[800]!), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          child: Text('Show all ${widget.property.amenities.length} amenities', style: TextStyle(color: Colors.grey[800], fontSize: 16)),
                        ),
                    ],
                  ),
              const SizedBox(height: 24),

              // House rules section
              _buildSectionHeader('House Rules'),
              const SizedBox(height: 12),
              widget.property.rules.isEmpty
                  ? Text('No house rules specified.', style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontStyle: FontStyle.italic))
                  : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:
                        widget.property.rules.map((rule) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.check_circle, size: 16, color: Colors.green.shade700), const SizedBox(width: 8), Expanded(child: Text(rule, style: TextStyle(fontSize: 16)))]),
                          );
                        }).toList(),
                  ),
              const SizedBox(height: 24),

              // Location map section
              _buildSectionHeader('Location'),
              const SizedBox(height: 12),
              widget.property.latitude != null && widget.property.longitude != null
                  ? Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          GoogleMap(
                            initialCameraPosition: CameraPosition(target: LatLng(widget.property.latitude!, widget.property.longitude!), zoom: 14.0),
                            markers: _markers,
                            mapType: MapType.normal,
                            onMapCreated: (GoogleMapController controller) {
                              _mapController.complete(controller);
                            },
                            zoomControlsEnabled: false,
                            compassEnabled: false,
                          ),

                          // Exact location provided after booking message
                          Positioned(
                            top: 10,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]),
                                child: const Text('Exact location provided after booking', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                              ),
                            ),
                          ),

                          // Expand map button
                          Positioned(
                            bottom: 10,
                            right: 10,
                            child: Container(
                              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]),
                              child: IconButton(icon: const Icon(Icons.fullscreen), onPressed: () {}, iconSize: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  : Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                    child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.map, size: 48, color: Colors.grey.shade400), const SizedBox(height: 8), Text('Location coordinates not available', style: TextStyle(color: Colors.grey.shade600))])),
                  ),
              const SizedBox(height: 24),

              // Reviews
              // _buildSectionHeader('Reviews'),
              // const SizedBox(height: 8),
              // Row(children: [const Icon(Icons.star, size: 18), const SizedBox(width: 4), Text('4.92', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), Text(' · 88 reviews', style: TextStyle(fontSize: 16, color: Colors.grey[800]))]),
              // const SizedBox(height: 16),

              // Sample reviews
              // Row(
              //   crossAxisAlignment: CrossAxisAlignment.start,
              //   children: [
              //     Expanded(child: _buildReviewItem('Kamogelo', 'Midrand, South Africa', 'I had lovely stay with my partner. Views were impeccable and the hosts made us feel just at home. Will definitely come back again.', '3 weeks ago')),
              //     const SizedBox(width: 16),
              //     Expanded(child: _buildReviewItem('Lindokuhle', '2 years on Airbnb', 'What a beautiful place with views of the dam and so peaceful. Very friendly hosts.', '4 weeks ago')),
              //   ],
              // ),
              const SizedBox(height: 24),

              // Show all reviews button
              // OutlinedButton(
              //   onPressed: () {},
              //   style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), side: BorderSide(color: Colors.grey[800]!), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              //   child: Text('Show all 88 reviews', style: TextStyle(color: Colors.grey[800], fontSize: 16)),
              // ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoomsTab(bool isVerified) {
    return Column(
      children: [
        // Add Room button (only for verified landlords with verified property)
        if (isVerified && widget.property.isVerified)
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _addRoom,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Add Room', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              ),
            ),
          ),

        // Rooms list
        Expanded(
          child:
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _rooms.isEmpty
                  ? EmptyStateWidget(
                    icon: Icons.meeting_room,
                    title: 'No Rooms Yet',
                    message: 'Add rooms to your property so you can define bed spaces for booking.',
                    buttonText: isVerified && widget.property.isVerified ? 'Add Room' : null,
                    onButtonPressed: isVerified && widget.property.isVerified ? _addRoom : null,
                    extraMessage: !widget.property.isVerified ? 'Your property needs to be verified before you can add rooms.' : null,
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _rooms.length,
                    itemBuilder: (context, index) {
                      return _buildRoomCard(_rooms[index]);
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildBookingsTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('Bookings Coming Soon', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[700])),
            const SizedBox(height: 8),
            Text('We\'re working on the booking management feature. Stay tuned!', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Container(width: 40, height: 3, color: AppTheme.primaryColor)]);
  }

  Widget _buildHighlightItem(IconData icon, String title, String description) {
    return Row(
      children: [
        Icon(icon, size: 28, color: AppTheme.primaryColor),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)), const SizedBox(height: 4), Text(description, style: TextStyle(fontSize: 14, color: Colors.grey[700]))])),
      ],
    );
  }

  Widget _buildAmenityItem(String amenity) {
    IconData iconData;

    // Assign appropriate icons based on amenity type
    if (amenity.toLowerCase().contains('wifi')) {
      iconData = Icons.wifi;
    } else if (amenity.toLowerCase().contains('pool')) {
      iconData = Icons.pool;
    } else if (amenity.toLowerCase().contains('kitchen')) {
      iconData = Icons.kitchen;
    } else if (amenity.toLowerCase().contains('tv')) {
      iconData = Icons.tv;
    } else if (amenity.toLowerCase().contains('air')) {
      iconData = Icons.ac_unit;
    } else if (amenity.toLowerCase().contains('parking')) {
      iconData = Icons.local_parking;
    } else if (amenity.toLowerCase().contains('washer')) {
      iconData = Icons.local_laundry_service;
    } else if (amenity.toLowerCase().contains('dryer')) {
      iconData = Icons.dry_cleaning;
    } else {
      iconData = Icons.check_circle_outline;
    }

    return Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Row(children: [Icon(iconData, size: 24, color: Colors.grey[800]), const SizedBox(width: 12), Expanded(child: Text(amenity, style: TextStyle(fontSize: 16, color: Colors.grey[800])))]));
  }

  Widget _buildReviewItem(String name, String location, String content, String date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(radius: 18, backgroundImage: const NetworkImage('https://via.placeholder.com/100')),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), Text(location, style: TextStyle(fontSize: 12, color: Colors.grey[600]))]),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.star, color: Colors.black, size: 14),
            Icon(Icons.star, color: Colors.black, size: 14),
            Icon(Icons.star, color: Colors.black, size: 14),
            Icon(Icons.star, color: Colors.black, size: 14),
            Icon(Icons.star, color: Colors.black, size: 14),
            const SizedBox(width: 8),
            Text(date, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
        const SizedBox(height: 8),
        Text(content, style: TextStyle(fontSize: 14, color: Colors.grey[800]), maxLines: 3, overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildRoomCard(Room room) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: () => _navigateToRoomDetails(room),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Room image
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                  child:
                      room.photos.isNotEmpty
                          ? Image.network(room.photos.first, height: 120, width: double.infinity, fit: BoxFit.cover, errorBuilder: (ctx, error, stackTrace) => Container(height: 120, color: Colors.grey.shade300, child: const Icon(Icons.meeting_room, size: 40, color: Colors.white)))
                          : Container(height: 120, color: Colors.grey.shade300, child: const Icon(Icons.meeting_room, size: 40, color: Colors.white)),
                ),
                // Room type badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.7), borderRadius: BorderRadius.circular(20)),
                    child: Text(room.roomType, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ],
            ),

            // Room details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Room name
                  Text(room.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),

                  // Room description
                  Text(room.description, style: TextStyle(fontSize: 14, color: Colors.grey.shade700), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 16),

                  // Room stats
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_buildRoomStat(Icons.bed, '${room.totalBedSpaces} Bed Spaces'), _buildRoomStat(Icons.straighten, '${room.area} m²'), _buildRoomStat(Icons.arrow_forward, 'View Details', isAction: true)]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomStat(IconData icon, String text, {bool isAction = false}) {
    return Row(
      children: [Icon(icon, size: 16, color: isAction ? AppTheme.primaryColor : Colors.grey.shade700), const SizedBox(width: 4), Text(text, style: TextStyle(fontSize: 13, color: isAction ? AppTheme.primaryColor : Colors.grey.shade800, fontWeight: isAction ? FontWeight.bold : FontWeight.normal))],
    );
  }

  IconData _getPropertyTypeIcon(String propertyType) {
    switch (propertyType) {
      case 'Apartment':
        return Icons.apartment;
      case 'House':
        return Icons.home;
      case 'Dormitory':
        return Icons.hotel;
      case 'Student Residence':
        return Icons.school;
      default:
        return Icons.house;
    }
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Colors.white, child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
