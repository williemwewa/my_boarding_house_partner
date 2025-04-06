import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:my_boarding_house_partner/models/property_model.dart';
import 'package:my_boarding_house_partner/models/user_model.dart';
import 'package:my_boarding_house_partner/utils/app_theme.dart';

class PropertyReviewScreen extends StatefulWidget {
  final Property property;

  const PropertyReviewScreen({Key? key, required this.property}) : super(key: key);

  @override
  _PropertyReviewScreenState createState() => _PropertyReviewScreenState();
}

class _PropertyReviewScreenState extends State<PropertyReviewScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  bool _isUpdating = false;
  AppUser? _landlord;
  List<Room> _rooms = [];
  final TextEditingController _rejectReasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPropertyDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _rejectReasonController.dispose();
    super.dispose();
  }

  Future<void> _loadPropertyDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load landlord data
      final landlordDoc = await FirebaseFirestore.instance.collection('Users').doc(widget.property.landlordId).get();

      if (landlordDoc.exists) {
        _landlord = AppUser.fromFirestore(landlordDoc);
      }

      // Load rooms data
      final roomsQuery = await FirebaseFirestore.instance.collection('Properties').doc(widget.property.id).collection('Rooms').get();

      _rooms = roomsQuery.docs.map((doc) => Room.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error loading property details: $e');
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading property details: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showVerificationDialog(bool approve) {
    if (approve) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Verify Property'),
            content: const Text(
              'Are you sure you want to verify this property?\n\n'
              'This will make it visible to students and allow bookings.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _updatePropertyVerification(true);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Approve Property'),
              ),
            ],
          );
        },
      );
    } else {
      // Show rejection dialog with reason field
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Reject Property'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [const Text('Please provide a reason for rejecting this property:'), const SizedBox(height: 16), TextField(controller: _rejectReasonController, decoration: const InputDecoration(hintText: 'Enter reason for rejection', border: OutlineInputBorder()), maxLines: 3)],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_rejectReasonController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please provide a rejection reason'), backgroundColor: Colors.red));
                    return;
                  }

                  Navigator.of(context).pop();
                  _updatePropertyVerification(false);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Reject Property'),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _updatePropertyVerification(bool isVerified) async {
    setState(() {
      _isUpdating = true;
    });

    try {
      final Map<String, dynamic> updateData = {'isVerified': isVerified, 'updatedAt': FieldValue.serverTimestamp()};

      // Add rejection reason if rejecting
      if (!isVerified && _rejectReasonController.text.trim().isNotEmpty) {
        updateData['rejectionReason'] = _rejectReasonController.text.trim();
      }

      await FirebaseFirestore.instance.collection('Properties').doc(widget.property.id).update(updateData);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isVerified ? 'Property has been verified successfully!' : 'Property has been rejected.'), backgroundColor: isVerified ? Colors.green : Colors.red));

      // Return to previous screen
      Navigator.pop(context);
    } catch (e) {
      print('Error updating property verification: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating property: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _togglePropertyActiveStatus() async {
    final bool newActiveStatus = !widget.property.isActive;

    try {
      await FirebaseFirestore.instance.collection('Properties').doc(widget.property.id).update({'isActive': newActiveStatus, 'updatedAt': FieldValue.serverTimestamp()});

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(newActiveStatus ? 'Property has been activated.' : 'Property has been deactivated.'), backgroundColor: newActiveStatus ? Colors.green : Colors.orange));

      // Return to previous screen
      Navigator.pop(context);
    } catch (e) {
      print('Error updating property active status: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating property: ${e.toString()}'), backgroundColor: Colors.red));
    }
  }

  Future<void> _contactLandlord(String method) async {
    if (_landlord == null) return;

    if (method == 'phone' && _landlord!.phoneNumber != null) {
      final Uri phoneUri = Uri(scheme: 'tel', path: _landlord!.phoneNumber);

      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not call ${_landlord!.phoneNumber}'), backgroundColor: Colors.red));
      }
    } else if (method == 'email') {
      final Uri emailUri = Uri(scheme: 'mailto', path: _landlord!.email, query: 'subject=Regarding your property: ${widget.property.name}');

      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not email ${_landlord!.email}'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Property Review', style: TextStyle(color: AppTheme.primaryColor)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.primaryColor),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'toggle_active') {
                _togglePropertyActiveStatus();
              }
            },
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    value: 'toggle_active',
                    child: Row(children: [Icon(widget.property.isActive ? Icons.unpublished : Icons.check_circle, color: widget.property.isActive ? Colors.orange : Colors.green), const SizedBox(width: 8), Text(widget.property.isActive ? 'Deactivate Property' : 'Activate Property')]),
                  ),
                ],
          ),
        ],
        bottom: TabBar(controller: _tabController, tabs: const [Tab(text: 'Details'), Tab(text: 'Rooms'), Tab(text: 'Landlord')], indicatorColor: AppTheme.primaryColor, labelColor: AppTheme.primaryColor, unselectedLabelColor: Colors.grey),
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : TabBarView(controller: _tabController, children: [_buildDetailsTab(), _buildRoomsTab(), _buildLandlordTab()]),
      bottomNavigationBar: _buildBottomButtons(),
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Property images carousel
          _buildImagesCarousel(),
          const SizedBox(height: 20),

          // Status badges
          Row(
            children: [
              _buildStatusBadge(widget.property.isVerified ? 'Verified' : 'Pending', widget.property.isVerified ? Colors.green : Colors.orange),
              const SizedBox(width: 8),
              _buildStatusBadge(widget.property.isActive ? 'Active' : 'Inactive', widget.property.isActive ? Colors.blue : Colors.grey),
            ],
          ),
          const SizedBox(height: 20),

          // Property name and type
          Text(widget.property.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(children: [const Icon(Icons.home_work, size: 16, color: Colors.grey), const SizedBox(width: 8), Text('Type: ${widget.property.propertyType}', style: TextStyle(fontSize: 16, color: Colors.grey.shade700))]),
          const SizedBox(height: 8),
          Row(children: [const Icon(Icons.location_on, size: 16, color: Colors.grey), const SizedBox(width: 8), Expanded(child: Text(widget.property.address, style: TextStyle(fontSize: 16, color: Colors.grey.shade700)))]),
          const SizedBox(height: 20),

          // Description
          _buildSectionHeader('Description'),
          const SizedBox(height: 8),
          Text(widget.property.description, style: TextStyle(fontSize: 16, color: Colors.grey.shade800, height: 1.5)),
          const SizedBox(height: 24),

          // Property stats
          _buildSectionHeader('Property Information'),
          const SizedBox(height: 12),
          _buildStatsCard(),
          const SizedBox(height: 24),

          // Amenities
          _buildSectionHeader('Amenities'),
          const SizedBox(height: 12),
          _buildAmenitiesCard(),
          const SizedBox(height: 24),

          // House rules
          _buildSectionHeader('House Rules'),
          const SizedBox(height: 12),
          _buildRulesCard(),
          const SizedBox(height: 24),

          // Dates
          _buildSectionHeader('Submission Information'),
          const SizedBox(height: 12),
          _buildDatesCard(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildRoomsTab() {
    return _rooms.isEmpty
        ? const Center(child: Text('No rooms have been added to this property yet.'))
        : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _rooms.length,
          itemBuilder: (context, index) {
            return _buildRoomCard(_rooms[index]);
          },
        );
  }

  Widget _buildLandlordTab() {
    return _landlord == null
        ? const Center(child: Text('Landlord information not available.'))
        : SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Landlord header card
              _buildLandlordHeaderCard(),
              const SizedBox(height: 24),

              // Landlord details
              _buildSectionHeader('Contact Information'),
              const SizedBox(height: 12),
              _buildLandlordContactCard(),
              const SizedBox(height: 24),

              // Verification status
              _buildSectionHeader('Verification Status'),
              const SizedBox(height: 12),
              _buildLandlordVerificationCard(),
              const SizedBox(height: 24),

              // Contact landlord buttons
              _buildSectionHeader('Contact Landlord'),
              const SizedBox(height: 12),
              _buildContactButtonsCard(),
              const SizedBox(height: 40),
            ],
          ),
        );
  }

  Widget _buildImagesCarousel() {
    return widget.property.photos.isNotEmpty
        ? Column(
          children: [
            CarouselSlider(
              options: CarouselOptions(height: 200, viewportFraction: 1.0, enlargeCenterPage: false, autoPlay: widget.property.photos.length > 1, autoPlayInterval: const Duration(seconds: 4)),
              items:
                  widget.property.photos.map((url) {
                    return Builder(
                      builder: (BuildContext context) {
                        return Container(width: MediaQuery.of(context).size.width, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)));
                      },
                    );
                  }).toList(),
            ),
            const SizedBox(height: 8),
            Text('${widget.property.photos.length} photos provided', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        )
        : Container(height: 200, width: double.infinity, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('No photos available')));
  }

  Widget _buildStatsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(Icons.meeting_room, 'Rooms', widget.property.totalRooms.toString()),
                _buildStatItem(Icons.bed, 'Bed Spaces', widget.property.totalBedSpaces.toString()),
                _buildStatItem(Icons.person, 'Occupied', '${widget.property.occupiedBedSpaces}/${widget.property.totalBedSpaces}'),
              ],
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Minimum Price', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Text('ZMW ${widget.property.minPrice.toStringAsFixed(2)} / month', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    // Navigate to the map view
                  },
                  icon: const Icon(Icons.map),
                  label: const Text('View on Map'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryColor),
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
      child: Padding(padding: const EdgeInsets.all(16), child: widget.property.amenities.isEmpty ? const Center(child: Text('No amenities specified for this property.')) : Wrap(spacing: 8, runSpacing: 8, children: widget.property.amenities.map((amenity) => _buildFeatureChip(amenity)).toList())),
    );
  }

  Widget _buildRulesCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child:
            widget.property.rules.isEmpty
                ? const Center(child: Text('No house rules specified for this property.'))
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:
                      widget.property.rules.map((rule) {
                        return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.check_circle, size: 16, color: Colors.green), const SizedBox(width: 8), Expanded(child: Text(rule))]));
                      }).toList(),
                ),
      ),
    );
  }

  Widget _buildDatesCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [_buildInfoRow('Created On', DateFormat('MMMM d, yyyy').format(widget.property.createdAt), Icons.calendar_today), const Divider(height: 24), _buildInfoRow('Last Updated', DateFormat('MMMM d, yyyy').format(widget.property.updatedAt), Icons.update)]),
      ),
    );
  }

  Widget _buildRoomCard(Room room) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Room image
          ClipRRect(
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            child:
                room.photos.isNotEmpty
                    ? Image.network(room.photos.first, height: 150, width: double.infinity, fit: BoxFit.cover, errorBuilder: (ctx, error, stackTrace) => Container(height: 150, color: Colors.grey.shade300, child: const Icon(Icons.meeting_room, size: 50, color: Colors.white)))
                    : Container(height: 150, color: Colors.grey.shade300, child: const Icon(Icons.meeting_room, size: 50, color: Colors.white)),
          ),

          // Room details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Room name and type
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(room.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.blue.withOpacity(0.5))),
                      child: Text(room.roomType, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Room description
                Text(room.description, style: TextStyle(fontSize: 14, color: Colors.grey.shade700), maxLines: 3, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 16),

                // Room stats
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_buildRoomStat('Bed Spaces', room.totalBedSpaces.toString()), _buildRoomStat('Area', '${room.area} m²'), _buildRoomStat('Photos', room.photos.length.toString())]),

                if (room.amenities.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Room Amenities:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: room.amenities.map((amenity) => _buildFeatureChip(amenity, small: true)).toList()),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLandlordHeaderCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(radius: 40, backgroundColor: Colors.grey.shade200, backgroundImage: _landlord!.profileImageUrl != null ? NetworkImage(_landlord!.profileImageUrl!) : null, child: _landlord!.profileImageUrl == null ? const Icon(Icons.person, size: 50, color: Colors.grey) : null),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_landlord!.displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.blue.withOpacity(0.5))),
                        child: const Text('LANDLORD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _landlord!.isVerified ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _landlord!.isVerified ? Colors.green.withOpacity(0.5) : Colors.orange.withOpacity(0.5)),
                        ),
                        child: Text(_landlord!.isVerified ? 'VERIFIED' : 'UNVERIFIED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _landlord!.isVerified ? Colors.green : Colors.orange)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_landlord!.businessName != null && _landlord!.businessName!.isNotEmpty) Text('Business: ${_landlord!.businessName}', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                  Text('Joined: ${DateFormat('MMMM d, yyyy').format(_landlord!.createdAt)}', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLandlordContactCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoRow('Email', _landlord!.email, Icons.email),
            const Divider(height: 24),
            _buildInfoRow('Phone', _landlord!.phoneNumber ?? 'Not provided', Icons.phone),
            if (_landlord!.nrcNumber != null) ...[const Divider(height: 24), _buildInfoRow('NRC Number', _landlord!.nrcNumber!, Icons.credit_card)],
          ],
        ),
      ),
    );
  }

  Widget _buildLandlordVerificationCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_landlord!.isVerified ? Icons.verified_user : Icons.pending, color: _landlord!.isVerified ? Colors.green : Colors.orange, size: 24),
                const SizedBox(width: 8),
                Text(_landlord!.isVerified ? 'Landlord is verified' : 'Landlord verification pending', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _landlord!.isVerified ? Colors.green : Colors.orange)),
              ],
            ),
            const SizedBox(height: 8),
            Text(_landlord!.isVerified ? 'The identity of this landlord has been verified by an administrator.' : 'This landlord\'s identity has not yet been verified.', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
            const SizedBox(height: 16),
            if (!_landlord!.isVerified)
              OutlinedButton.icon(
                onPressed: () {
                  // Navigate to verify landlord
                },
                icon: const Icon(Icons.verified_user),
                label: const Text('Verify Landlord'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.green, side: const BorderSide(color: Colors.green)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactButtonsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(child: OutlinedButton.icon(onPressed: _landlord!.phoneNumber != null ? () => _contactLandlord('phone') : null, icon: const Icon(Icons.phone), label: const Text('Call'), style: OutlinedButton.styleFrom(foregroundColor: Colors.green, side: const BorderSide(color: Colors.green)))),
            const SizedBox(width: 16),
            Expanded(child: OutlinedButton.icon(onPressed: () => _contactLandlord('email'), icon: const Icon(Icons.email), label: const Text('Email'), style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryColor, side: BorderSide(color: AppTheme.primaryColor)))),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: widget.property.isVerified || _isUpdating ? null : () => _showVerificationDialog(false),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _isUpdating ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Reject'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: widget.property.isVerified || _isUpdating ? null : () => _showVerificationDialog(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _isUpdating ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Approve'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Container(width: 40, height: 3, color: AppTheme.primaryColor)]);
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.5))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            text.toLowerCase() == 'verified' || text.toLowerCase() == 'active'
                ? Icons.check_circle
                : text.toLowerCase() == 'pending'
                ? Icons.pending
                : Icons.cancel,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(text.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(String text, {bool small = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 12, vertical: small ? 4 : 6),
      decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3))),
      child: Text(text, style: TextStyle(fontSize: small ? 10 : 12, color: AppTheme.primaryColor)),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(children: [Icon(icon, size: 24, color: AppTheme.primaryColor), const SizedBox(height: 8), Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))]);
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: AppTheme.primaryColor, size: 24)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)), const SizedBox(height: 4), Text(value, style: const TextStyle(fontSize: 16))])),
      ],
    );
  }

  Widget _buildRoomStat(String label, String value) {
    return Column(children: [Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)), const SizedBox(height: 4), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))]);
  }
}
