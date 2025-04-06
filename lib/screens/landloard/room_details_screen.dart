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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex, // Use the provided initial tab index
    );
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.room.name, style: const TextStyle(color: AppTheme.primaryColor)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.primaryColor),
        actions: [IconButton(icon: const Icon(Icons.edit), onPressed: _showEditRoomDialog)],
        bottom: TabBar(controller: _tabController, tabs: const [Tab(text: 'Details'), Tab(text: 'Bed Spaces')], indicatorColor: AppTheme.primaryColor, labelColor: AppTheme.primaryColor, unselectedLabelColor: Colors.grey),
      ),
      body: TabBarView(controller: _tabController, children: [_buildDetailsTab(), _buildBedSpacesTab()]),
      floatingActionButton: _tabController.index == 1 ? FloatingActionButton(backgroundColor: AppTheme.primaryColor, child: const Icon(Icons.add), onPressed: _navigateToAddBedSpace, tooltip: 'Add Bed Space') : null,
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Room images carousel
          _buildImagesCarousel(),
          const SizedBox(height: 24),

          // Room name and type
          Text(widget.room.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.primaryColor.withOpacity(0.5))),
                child: Text(widget.room.roomType.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Room description
          _buildSectionHeader('Description'),
          const SizedBox(height: 8),
          Text(widget.room.description, style: TextStyle(fontSize: 16, color: Colors.grey.shade800, height: 1.5)),
          const SizedBox(height: 24),

          // Room details
          _buildSectionHeader('Room Details'),
          const SizedBox(height: 12),
          _buildRoomDetailsCard(),
          const SizedBox(height: 24),

          // Room amenities
          _buildSectionHeader('Room Amenities'),
          const SizedBox(height: 12),
          _buildAmenitiesCard(),
          const SizedBox(height: 24),

          // Property info
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
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: _bedSpaces.length,
                    itemBuilder: (context, index) {
                      return _buildBedSpaceCard(_bedSpaces[index]);
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildImagesCarousel() {
    return widget.room.photos.isNotEmpty
        ? CarouselSlider(
          options: CarouselOptions(height: 200, viewportFraction: 1.0, enlargeCenterPage: false, autoPlay: widget.room.photos.length > 1, autoPlayInterval: const Duration(seconds: 4)),
          items:
              widget.room.photos.map((url) {
                return Builder(
                  builder: (BuildContext context) {
                    return Container(width: MediaQuery.of(context).size.width, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)));
                  },
                );
              }).toList(),
        )
        : Container(height: 200, width: double.infinity, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(12)), child: const Center(child: Icon(Icons.meeting_room, size: 80, color: Colors.white)));
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
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Available Bed Spaces', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Text('${_bedSpaces.where((b) => b.status == 'available').length} / ${_bedSpaces.length}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    _tabController.animateTo(1); // Switch to Bed Spaces tab
                  },
                  icon: const Icon(Icons.bed),
                  label: const Text('Manage Bed Spaces'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryColor, side: const BorderSide(color: AppTheme.primaryColor)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmenitiesCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(16), child: widget.room.amenities.isEmpty ? const Center(child: Text('No amenities specified for this room.')) : Wrap(spacing: 8, runSpacing: 8, children: widget.room.amenities.map((amenity) => _buildFeatureChip(amenity)).toList())),
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
                        ? Image.network(bedSpace.photos.first, height: 120, width: double.infinity, fit: BoxFit.cover, errorBuilder: (ctx, error, stackTrace) => Container(height: 120, color: Colors.grey.shade300, child: const Icon(Icons.bed, size: 40, color: Colors.white)))
                        : Container(height: 120, color: Colors.grey.shade300, child: const Icon(Icons.bed, size: 40, color: Colors.white)),
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Container(width: 40, height: 3, color: AppTheme.primaryColor)]);
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
