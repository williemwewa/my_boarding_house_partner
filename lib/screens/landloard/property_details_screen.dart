import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:carousel_slider/carousel_slider.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRooms();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _roomsSubscription?.cancel();
    super.dispose();
  }

  void _loadRooms() {
    _isLoading = true;

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
                    SliverAppBar(
                      expandedHeight: 250,
                      floating: false,
                      pinned: true,
                      backgroundColor: Colors.white,
                      iconTheme: const IconThemeData(color: Colors.white),
                      flexibleSpace: FlexibleSpaceBar(background: _buildPropertyImagesCarousel()),
                      actions: [
                        IconButton(icon: const Icon(Icons.edit, color: Colors.white), onPressed: _editProperty),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.white),
                          onSelected: (value) {
                            if (value == 'status') {
                              _togglePropertyStatus();
                            }
                          },
                          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[PopupMenuItem<String>(value: 'status', child: Text(widget.property.isActive ? 'Mark as Inactive' : 'Mark as Active'))],
                        ),
                      ],
                    ),
                    SliverToBoxAdapter(child: _buildPropertyHeader()),
                    SliverPersistentHeader(
                      delegate: _SliverAppBarDelegate(TabBar(controller: _tabController, tabs: const [Tab(text: 'Overview'), Tab(text: 'Rooms'), Tab(text: 'Bookings')], indicatorColor: AppTheme.primaryColor, labelColor: AppTheme.primaryColor, unselectedLabelColor: Colors.grey)),
                      pinned: true,
                    ),
                  ];
                },
                body: TabBarView(controller: _tabController, children: [_buildOverviewTab(), _buildRoomsTab(isVerified), _buildBookingsTab()]),
              ),
    );
  }

  Widget _buildPropertyImagesCarousel() {
    return Stack(
      children: [
        // Images carousel
        widget.property.photos.isNotEmpty
            ? CarouselSlider(
              options: CarouselOptions(height: 250, viewportFraction: 1.0, enlargeCenterPage: false, autoPlay: widget.property.photos.length > 1, autoPlayInterval: const Duration(seconds: 4)),
              items:
                  widget.property.photos.map((url) {
                    return Builder(
                      builder: (BuildContext context) {
                        return Image.network(url, fit: BoxFit.cover, width: double.infinity, errorBuilder: (ctx, error, stackTrace) => Container(color: Colors.grey.shade300, child: const Icon(Icons.image_not_supported, size: 50, color: Colors.white)));
                      },
                    );
                  }).toList(),
            )
            : Container(color: Colors.grey.shade300, child: const Icon(Icons.apartment, size: 80, color: Colors.white)),

        // Gradient overlay for better readability of action buttons
        Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.center, colors: [AppTheme.primaryColor.withOpacity(0.7), Colors.transparent]))),

        // Status badges
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
                    Text(widget.property.isVerified ? 'Verified' : 'Pending Verification', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
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
      ],
    );
  }

  Widget _buildPropertyHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.property.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(children: [const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey), const SizedBox(width: 4), Expanded(child: Text(widget.property.address, style: TextStyle(fontSize: 14, color: Colors.grey.shade700), maxLines: 1, overflow: TextOverflow.ellipsis))]),
          const SizedBox(height: 16),

          // Stats row
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description section
          _buildSectionHeader('Description'),
          const SizedBox(height: 8),
          Text(widget.property.description, style: TextStyle(fontSize: 14, color: Colors.grey.shade800, height: 1.5)),
          const SizedBox(height: 24),

          // Property type
          _buildSectionHeader('Property Type'),
          const SizedBox(height: 8),
          Row(children: [Icon(_getPropertyTypeIcon(widget.property.propertyType), color: AppTheme.primaryColor), const SizedBox(width: 8), Text(widget.property.propertyType, style: const TextStyle(fontSize: 14))]),
          const SizedBox(height: 24),

          // Amenities section
          _buildSectionHeader('Amenities'),
          const SizedBox(height: 8),
          widget.property.amenities.isEmpty ? Text('No amenities specified.', style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontStyle: FontStyle.italic)) : Wrap(spacing: 8, runSpacing: 8, children: widget.property.amenities.map((amenity) => _buildFeatureChip(amenity)).toList()),
          const SizedBox(height: 24),

          // Rules section
          _buildSectionHeader('House Rules'),
          const SizedBox(height: 8),
          widget.property.rules.isEmpty
              ? Text('No house rules specified.', style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontStyle: FontStyle.italic))
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children:
                    widget.property.rules.map((rule) {
                      return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [Icon(Icons.check_circle, size: 16, color: Colors.green.shade700), const SizedBox(width: 8), Text(rule)]));
                    }).toList(),
              ),
          const SizedBox(height: 24),

          // Map section (placeholder for now)
          _buildSectionHeader('Location'),
          const SizedBox(height: 8),
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
            child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.map, size: 48, color: Colors.grey.shade400), const SizedBox(height: 8), Text('Map view coming soon', style: TextStyle(color: Colors.grey.shade600))])),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildRoomsTab(bool isVerified) {
    return Column(
      children: [
        // Add Room button
        if (isVerified && widget.property.isVerified)
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _addRoom,
                icon: const Icon(Icons.add, color: Colors.white), // Optional: make icon white
                label: const Text(
                  'Add Room',
                  style: TextStyle(color: Colors.white), // Text color white
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8), // Circular radius of 8
                  ),
                ),
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
    return const Center(child: Text('Bookings tab content coming soon'));
  }

  Widget _buildSectionHeader(String title) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Container(width: 40, height: 3, color: AppTheme.primaryColor)]);
  }

  Widget _buildFeatureChip(String feature) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3))),
      child: Text(feature, style: TextStyle(fontSize: 12, color: AppTheme.primaryColor)),
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

                  // Room details
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
