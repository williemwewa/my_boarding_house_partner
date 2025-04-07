import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:intl/intl.dart';

import 'package:my_boarding_house_partner/models/property_model.dart';
import 'package:my_boarding_house_partner/screens/landloard/add_bed_space_screen.dart';
import 'package:my_boarding_house_partner/screens/landloard/edit_room_screen.dart';
import 'package:my_boarding_house_partner/screens/landloard/edit_bed_space_screen.dart';

import 'package:my_boarding_house_partner/utils/app_theme.dart';
import 'package:my_boarding_house_partner/widgets/empty_state_widget.dart';

class RoomDetailsScreen extends StatefulWidget {
  final Property property;
  final Room room;
  final int initialTabIndex;

  const RoomDetailsScreen({
    Key? key,
    required this.property,
    required this.room,
    this.initialTabIndex = 0, // Default to details tab, but can be overridden
  }) : super(key: key);

  @override
  _RoomDetailsScreenState createState() => _RoomDetailsScreenState();
}

class _RoomDetailsScreenState extends State<RoomDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  List<BedSpace> _bedSpaces = [];
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex, // Use the provided initial tab index
    );

    // Listener to ensure the UI rebuilds when tabs change
    _tabController.addListener(() {
      setState(() {}); // This will trigger a rebuild when tab changes
    });

    _loadBedSpaces();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBedSpaces() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final bedSpacesQuery = await FirebaseFirestore.instance.collection('Properties').doc(widget.property.id).collection('Rooms').doc(widget.room.id).collection('BedSpaces').get();

      setState(() {
        _bedSpaces = bedSpacesQuery.docs.map((doc) => BedSpace.fromFirestore(doc)).toList();

        // Sort by status and name
        _bedSpaces.sort((a, b) {
          // First by status - available first
          if (a.status != b.status) {
            if (a.status == 'available') return -1;
            if (b.status == 'available') return 1;
          }
          // Then by name
          return a.name.compareTo(b.name);
        });

        _isLoading = false;
      });
    } catch (e) {
      print('Error loading bed spaces: $e');
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading bed spaces: ${e.toString()}'), backgroundColor: Colors.red));
    }
  }

  void _navigateToAddBedSpace() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => AddBedSpaceScreen(propertyId: widget.property.id, roomId: widget.room.id, propertyName: widget.property.name, roomName: widget.room.name))).then((_) => _loadBedSpaces()); // Refresh when returning
  }

  void _showEditRoomDialog() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => EditRoomScreen(property: widget.property, room: widget.room))).then((result) {
      if (result == 'deleted') {
        // Room was deleted, go back to property details
        Navigator.pop(context);
      } else if (result == true) {
        // Room was updated, refresh data
        // This should trigger a rebuild with the latest data from Firestore
        setState(() {});
      }
    });
  }

  Future<void> _toggleBedSpaceStatus(BedSpace bedSpace) async {
    // Only toggle if the bed space is available or maintenance
    // (don't allow changing booked to available directly)
    if (bedSpace.status == 'booked') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot change status of a booked bed space. The booking must be cancelled first.'), backgroundColor: Colors.orange));
      return;
    }

    final String newStatus = bedSpace.status == 'available' ? 'maintenance' : 'available';

    try {
      await FirebaseFirestore.instance.collection('Properties').doc(widget.property.id).collection('Rooms').doc(widget.room.id).collection('BedSpaces').doc(bedSpace.id).update({'status': newStatus});

      // Refresh the list
      _loadBedSpaces();

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bed space status updated to ${newStatus.toUpperCase()}'), backgroundColor: Colors.green));
    } catch (e) {
      print('Error updating bed space status: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating status: ${e.toString()}'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate average price for all available bed spaces
    double averagePrice = 0;
    if (_bedSpaces.isNotEmpty) {
      final availableBedSpaces = _bedSpaces.where((space) => space.status == 'available').toList();
      if (availableBedSpaces.isNotEmpty) {
        averagePrice = availableBedSpaces.map((space) => space.price).reduce((a, b) => a + b) / availableBedSpaces.length;
      } else if (_bedSpaces.isNotEmpty) {
        // If no available bed spaces, use the average of all bed spaces
        averagePrice = _bedSpaces.map((space) => space.price).reduce((a, b) => a + b) / _bedSpaces.length;
      }
    }

    return Scaffold(
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                children: [
                  // Main content
                  NestedScrollView(
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
                                _buildImagesCarousel(),

                                // Gradient overlay for better visibility of buttons
                                Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.center, colors: [Colors.black.withOpacity(0.5), Colors.transparent]))),

                                // Room type badge
                                Positioned(
                                  bottom: 16,
                                  left: 16,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(20)),
                                    child: Text(widget.room.roomType.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                ),

                                // Image counter indicator
                                if (widget.room.photos.isNotEmpty)
                                  Positioned(
                                    bottom: 16,
                                    right: 16,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(12)),
                                      child: Text('${_currentImageIndex + 1}/${widget.room.photos.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          leading: Padding(padding: const EdgeInsets.all(8.0), child: CircleAvatar(backgroundColor: Colors.white, child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black, size: 20), onPressed: () => Navigator.pop(context)))),
                          actions: [
                            // Share button
                            Padding(padding: const EdgeInsets.all(8.0), child: CircleAvatar(backgroundColor: Colors.white, child: IconButton(icon: const Icon(Icons.share, color: Colors.black, size: 20), onPressed: () {}))),
                            // Favorite button
                            Padding(padding: const EdgeInsets.all(8.0), child: CircleAvatar(backgroundColor: Colors.white, child: IconButton(icon: const Icon(Icons.favorite_border, color: Colors.black, size: 20), onPressed: () {}))),
                            // Edit button
                            Padding(padding: const EdgeInsets.all(8.0), child: CircleAvatar(backgroundColor: Colors.white, child: IconButton(icon: const Icon(Icons.edit, color: Colors.black, size: 20), onPressed: _showEditRoomDialog))),
                          ],
                        ),

                        // Room title and basic info
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Room name
                                Text(widget.room.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),

                                // Location
                                Text('In ${widget.property.name}, ${widget.property.address}', style: TextStyle(fontSize: 16, color: Colors.grey[800])),
                                const SizedBox(height: 12),

                                // Room stats
                                Row(children: [Text('${widget.room.totalBedSpaces} bed spaces', style: TextStyle(fontSize: 14, color: Colors.grey[800])), Text(' · ', style: TextStyle(color: Colors.grey[800])), Text('${widget.room.area} m²', style: TextStyle(fontSize: 14, color: Colors.grey[800]))]),
                              ],
                            ),
                          ),
                        ),

                        // Tab bar
                        SliverPersistentHeader(delegate: _SliverAppBarDelegate(TabBar(controller: _tabController, tabs: const [Tab(text: 'Details'), Tab(text: 'Bed Spaces')], indicatorColor: AppTheme.primaryColor, labelColor: AppTheme.primaryColor, unselectedLabelColor: Colors.grey)), pinned: true),
                      ];
                    },
                    body: TabBarView(controller: _tabController, children: [_buildDetailsTab(), _buildBedSpacesTab()]),
                  ),

                  // Floating action button for adding bed spaces
                  if (_tabController.index == 1 && !_isLoading)
                    Positioned(
                      right: 16,
                      bottom: 90, // Position above the price/reserve bar
                      child: FloatingActionButton(onPressed: _navigateToAddBedSpace, backgroundColor: AppTheme.primaryColor, child: const Icon(Icons.add)),
                    ),

                  // Sticky price/reserve bar at bottom
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
                  //             Row(children: [Text('ZMW ${averagePrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const Text(' / night', style: TextStyle(fontSize: 16))]),
                  //             const SizedBox(height: 4),
                  //             Text('${_bedSpaces.where((b) => b.status == 'available').length} bed spaces available', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
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
                  //           child: const Text('Reserve', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  //         ),
                  //       ],
                  //     ),
                  //   ),
                  // ),
                ],
              ),
    );
  }

  Widget _buildImagesCarousel() {
    return widget.room.photos.isNotEmpty
        ? CarouselSlider(
          options: CarouselOptions(
            height: 300,
            viewportFraction: 1.0,
            enlargeCenterPage: false,
            autoPlay: widget.room.photos.length > 1,
            autoPlayInterval: const Duration(seconds: 4),
            onPageChanged: (index, reason) {
              setState(() {
                _currentImageIndex = index;
              });
            },
          ),
          items:
              widget.room.photos.map((url) {
                return Builder(
                  builder: (BuildContext context) {
                    return Image.network(url, fit: BoxFit.cover, width: double.infinity, errorBuilder: (ctx, error, stackTrace) => Container(color: Colors.grey.shade300, child: const Icon(Icons.image_not_supported, size: 50, color: Colors.white)));
                  },
                );
              }).toList(),
        )
        : Container(color: Colors.grey.shade300, child: const Icon(Icons.meeting_room, size: 80, color: Colors.white));
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), // Bottom padding for the reserve button
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Room description
          _buildSectionHeader('About this room'),
          const SizedBox(height: 12),
          Text(widget.room.description, style: TextStyle(fontSize: 16, color: Colors.grey.shade800, height: 1.5)),
          const SizedBox(height: 24),

          // Room amenities
          _buildSectionHeader('Room Amenities'),
          const SizedBox(height: 12),
          widget.room.amenities.isEmpty ? Text('No amenities specified for this room.', style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontStyle: FontStyle.italic)) : Wrap(spacing: 8, runSpacing: 8, children: widget.room.amenities.map((amenity) => _buildFeatureChip(amenity)).toList()),
          const SizedBox(height: 24),

          // Room details
          _buildSectionHeader('Room Details'),
          const SizedBox(height: 12),
          _buildRoomDetailsCard(),
          const SizedBox(height: 24),

          // Available bed spaces summary
          _buildSectionHeader('Bed Spaces'),
          const SizedBox(height: 8),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Available Bed Spaces', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                  const SizedBox(height: 4),
                  Text('${_bedSpaces.where((b) => b.status == 'available').length} / ${_bedSpaces.length}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                ],
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () {
                  _tabController.animateTo(1); // Switch to Bed Spaces tab
                },
                icon: const Icon(Icons.bed),
                label: const Text('View All Bed Spaces'),
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryColor, side: const BorderSide(color: AppTheme.primaryColor), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Property information
          _buildSectionHeader('Property Information'),
          const SizedBox(height: 12),
          _buildPropertyInfoCard(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildBedSpacesTab() {
    final int availableCount = _bedSpaces.where((b) => b.status == 'available').length;
    final int bookedCount = _bedSpaces.where((b) => b.status == 'booked').length;
    final int maintenanceCount = _bedSpaces.where((b) => b.status == 'maintenance').length;

    return Column(
      children: [
        // Summary card
        Card(
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_buildStatusCount('Available', availableCount, AppTheme.primaryColor), _buildStatusCount('Booked', bookedCount, Colors.blue), _buildStatusCount('Maintenance', maintenanceCount, Colors.orange)]),
          ),
        ),

        // Bed spaces list
        Expanded(
          child:
              _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                  : _bedSpaces.isEmpty
                  ? EmptyStateWidget(icon: Icons.bed, title: 'No Bed Spaces', message: 'This room doesn\'t have any bed spaces yet. Tap the button below to add your first bed space.', buttonText: 'Add Bed Space', onButtonPressed: _navigateToAddBedSpace)
                  : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80), // Add bottom padding for the bottom bar
                    itemCount: _bedSpaces.length,
                    itemBuilder: (context, index) {
                      return _buildBedSpaceCard(_bedSpaces[index]);
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildRoomDetailsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_buildRoomDetailItem('Room Type', widget.room.roomType), _buildRoomDetailItem('Area', '${widget.room.area} m²'), _buildRoomDetailItem('Bed Spaces', widget.room.totalBedSpaces.toString())]),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.property.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(children: [const Icon(Icons.location_on, size: 16, color: AppTheme.primaryColor), const SizedBox(width: 4), Expanded(child: Text(widget.property.address, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)))]),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Total Rooms', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)), const SizedBox(height: 4), Text('${widget.property.totalRooms}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text('Total Bed Spaces', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)), const SizedBox(height: 4), Text('${widget.property.totalBedSpaces}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text('Occupancy', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)), const SizedBox(height: 4), Text('${widget.property.occupiedBedSpaces}/${widget.property.totalBedSpaces}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBedSpaceCard(BedSpace bedSpace) {
    // Determine status color
    Color statusColor;
    switch (bedSpace.status) {
      case 'available':
        statusColor = AppTheme.primaryColor;
        break;
      case 'booked':
        statusColor = Colors.blue;
        break;
      case 'maintenance':
        statusColor = Colors.orange;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bed space image
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                child:
                    bedSpace.photos.isNotEmpty
                        ? Image.network(bedSpace.photos.first, height: 150, width: double.infinity, fit: BoxFit.cover, errorBuilder: (ctx, error, stackTrace) => Container(height: 150, color: Colors.grey.shade300, child: const Icon(Icons.bed, size: 40, color: Colors.white)))
                        : Container(height: 150, color: Colors.grey.shade300, child: const Icon(Icons.bed, size: 40, color: Colors.white)),
              ),
              // Status badge
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(20)),
                  child: Text(bedSpace.status.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            ],
          ),

          // Bed space details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bed space name and price
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(bedSpace.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text('ZMW ${bedSpace.price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                  ],
                ),
                Text(bedSpace.priceUnit, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 8),

                // Bed space description
                Text(bedSpace.description, style: TextStyle(fontSize: 14, color: Colors.grey.shade700), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 16),

                // Features
                if (bedSpace.features.isNotEmpty) ...[
                  const Text('Features:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: bedSpace.features.map((feature) => _buildFeatureChip(feature, small: true)).toList()),
                  const SizedBox(height: 16),
                ],

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // Navigate to edit bed space
                          Navigator.push(context, MaterialPageRoute(builder: (context) => EditBedSpaceScreen(propertyId: widget.property.id, roomId: widget.room.id, bedSpace: bedSpace, propertyName: widget.property.name, roomName: widget.room.name))).then((result) {
                            if (result == 'deleted' || result == true) {
                              // Bed space was deleted or updated, refresh data
                              _loadBedSpaces();
                            }
                          });
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit'),
                        style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryColor, side: const BorderSide(color: AppTheme.primaryColor), padding: const EdgeInsets.symmetric(vertical: 8)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: bedSpace.status != 'booked' ? () => _toggleBedSpaceStatus(bedSpace) : null,
                        icon: Icon(bedSpace.status == 'available' ? Icons.construction : Icons.check_circle),
                        label: Text(bedSpace.status == 'available' ? 'Maintenance' : 'Available'),
                        style: OutlinedButton.styleFrom(foregroundColor: bedSpace.status == 'available' ? Colors.orange : AppTheme.primaryColor, side: BorderSide(color: bedSpace.status == 'available' ? Colors.orange : AppTheme.primaryColor), padding: const EdgeInsets.symmetric(vertical: 8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Container(width: 40, height: 3, color: AppTheme.primaryColor)]);
  }

  Widget _buildFeatureChip(String text, {bool small = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 12, vertical: small ? 4 : 6),
      decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3))),
      child: Text(text, style: TextStyle(fontSize: small ? 10 : 12, color: AppTheme.primaryColor)),
    );
  }

  Widget _buildRoomDetailItem(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)), const SizedBox(height: 4), Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]);
  }

  Widget _buildStatusCount(String status, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(
            status == 'Available'
                ? Icons.check_circle
                : status == 'Booked'
                ? Icons.event_available
                : Icons.construction,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(count.toString(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(status, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
      ],
    );
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
