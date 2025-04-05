import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:my_boarding_house_partner/models/user_model.dart';
import 'package:my_boarding_house_partner/models/property_model.dart';
import 'package:my_boarding_house_partner/models/booking_model.dart';
import 'package:my_boarding_house_partner/utils/app_theme.dart';

class UserDetailsScreen extends StatefulWidget {
  final AppUser user;

  const UserDetailsScreen({Key? key, required this.user}) : super(key: key);

  @override
  _UserDetailsScreenState createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  // Data for different tabs
  List<Property> _properties = [];
  List<Booking> _bookings = [];

  // Action states
  bool _isUpdatingVerification = false;
  bool _isBlockingUser = false;

  @override
  void initState() {
    super.initState();
    // Set up tabs based on user role
    if (widget.user.role == 'landlord') {
      _tabController = TabController(length: 2, vsync: this);
      _loadProperties();
    } else if (widget.user.role == 'student') {
      _tabController = TabController(length: 1, vsync: this);
      _loadBookings();
    } else {
      _tabController = TabController(length: 1, vsync: this);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProperties() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get properties for this landlord
      final propertiesQuery = await FirebaseFirestore.instance.collection('Properties').where('landlordId', isEqualTo: widget.user.id).get();

      setState(() {
        _properties = propertiesQuery.docs.map((doc) => Property.fromFirestore(doc)).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading properties: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get bookings for this student
      final bookingsQuery = await FirebaseFirestore.instance.collection('Bookings').where('studentId', isEqualTo: widget.user.id).get();

      setState(() {
        _bookings = bookingsQuery.docs.map((doc) => Booking.fromFirestore(doc)).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading bookings: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleVerification() async {
    // Toggle verification status for the user
    final bool newVerificationStatus = !widget.user.isVerified;

    setState(() {
      _isUpdatingVerification = true;
    });

    try {
      await FirebaseFirestore.instance.collection('Users').doc(widget.user.id).update({'isVerified': newVerificationStatus, 'updatedAt': FieldValue.serverTimestamp()});

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(newVerificationStatus ? '${widget.user.displayName} has been verified' : '${widget.user.displayName} verification has been revoked'), backgroundColor: newVerificationStatus ? Colors.green : Colors.orange));

      // Navigate back to refresh the user list
      Navigator.pop(context);
    } catch (e) {
      print('Error updating verification: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating verification: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingVerification = false;
        });
      }
    }
  }

  Future<void> _toggleUserBlock() async {
    // Implementation would depend on your specific blocking functionality
    // For now, we'll just show a placeholder dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Feature Coming Soon'),
          content: const Text('User blocking functionality will be available in a future update.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _makePhoneCall() async {
    if (widget.user.phoneNumber == null) return;

    final Uri phoneUri = Uri(scheme: 'tel', path: widget.user.phoneNumber);

    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not call ${widget.user.phoneNumber}'), backgroundColor: Colors.red));
    }
  }

  Future<void> _sendEmail() async {
    final Uri emailUri = Uri(scheme: 'mailto', path: widget.user.email, query: 'subject=Regarding your account on Dodo Doba Partner');

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not email ${widget.user.email}'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Details', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'block') {
                _toggleUserBlock();
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(value: 'block', child: Row(children: [Icon(Icons.block, color: Colors.red), SizedBox(width: 8), Text('Block User')])),
                ],
          ),
        ],
        bottom: TabBar(controller: _tabController, tabs: _getTabs(), indicatorColor: AppTheme.primaryColor, labelColor: AppTheme.primaryColor, unselectedLabelColor: Colors.grey),
      ),
      body: TabBarView(controller: _tabController, children: _getTabViews()),
    );
  }

  List<Widget> _getTabs() {
    if (widget.user.role == 'landlord') {
      return [const Tab(text: 'Profile'), const Tab(text: 'Properties')];
    } else if (widget.user.role == 'student') {
      return [const Tab(text: 'Profile'), const Tab(text: 'Bookings')];
    } else {
      return [const Tab(text: 'Profile')];
    }
  }

  List<Widget> _getTabViews() {
    if (widget.user.role == 'landlord') {
      return [_buildProfileTab(), _buildPropertiesTab()];
    } else if (widget.user.role == 'student') {
      return [_buildProfileTab(), _buildBookingsTab()];
    } else {
      return [_buildProfileTab()];
    }
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User header
          _buildUserHeader(),
          const SizedBox(height: 24),

          // User details section
          _buildSectionHeader('Personal Information'),
          _buildPersonalInfoCard(),
          const SizedBox(height: 24),

          // Account details section
          _buildSectionHeader('Account Information'),
          _buildAccountInfoCard(),
          const SizedBox(height: 24),

          // Actions section
          _buildSectionHeader('Actions'),
          _buildActionButtons(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildPropertiesTab() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _properties.isEmpty
        ? const Center(child: Text('No properties found for this user'))
        : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _properties.length,
          itemBuilder: (context, index) {
            return _buildPropertyCard(_properties[index]);
          },
        );
  }

  Widget _buildBookingsTab() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _bookings.isEmpty
        ? const Center(child: Text('No bookings found for this user'))
        : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _bookings.length,
          itemBuilder: (context, index) {
            return _buildBookingCard(_bookings[index]);
          },
        );
  }

  Widget _buildUserHeader() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(radius: 40, backgroundColor: Colors.grey.shade200, backgroundImage: widget.user.profileImageUrl != null ? NetworkImage(widget.user.profileImageUrl!) : null, child: widget.user.profileImageUrl == null ? const Icon(Icons.person, size: 50, color: Colors.grey) : null),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.user.displayName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(children: [_buildRoleBadge(widget.user.role), const SizedBox(width: 8), if (widget.user.role == 'landlord') _buildVerificationBadge(widget.user.isVerified)]),
                  const SizedBox(height: 8),
                  Text(widget.user.email, style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoRow('Phone', widget.user.phoneNumber ?? 'Not provided', Icons.phone),
            const Divider(height: 24),
            _buildInfoRow('Gender', widget.user.gender ?? 'Not specified', Icons.person),
            if (widget.user.nrcNumber != null) ...[const Divider(height: 24), _buildInfoRow('NRC Number', widget.user.nrcNumber!, Icons.credit_card)],
            if (widget.user.businessName != null && widget.user.businessName!.isNotEmpty) ...[const Divider(height: 24), _buildInfoRow('Business Name', widget.user.businessName!, Icons.business)],
          ],
        ),
      ),
    );
  }

  Widget _buildAccountInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoRow('Account Created', DateFormat('MMMM d, yyyy').format(widget.user.createdAt), Icons.calendar_today),
            const Divider(height: 24),
            _buildInfoRow('Last Updated', widget.user.updatedAt != null ? DateFormat('MMMM d, yyyy').format(widget.user.updatedAt!) : 'Never', Icons.update),
            if (widget.user.role == 'landlord') ...[const Divider(height: 24), _buildInfoRow('Properties', _properties.length.toString(), Icons.apartment)],
            if (widget.user.role == 'student') ...[const Divider(height: 24), _buildInfoRow('Bookings', _bookings.length.toString(), Icons.book)],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Contact buttons
            Row(
              children: [
                Expanded(child: OutlinedButton.icon(onPressed: widget.user.phoneNumber != null ? _makePhoneCall : null, icon: const Icon(Icons.phone), label: const Text('Call'), style: OutlinedButton.styleFrom(foregroundColor: Colors.green, side: const BorderSide(color: Colors.green)))),
                const SizedBox(width: 16),
                Expanded(child: OutlinedButton.icon(onPressed: _sendEmail, icon: const Icon(Icons.email), label: const Text('Email'), style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryColor, side: BorderSide(color: AppTheme.primaryColor)))),
              ],
            ),
            const SizedBox(height: 16),

            // Verification action (for landlords only)
            if (widget.user.role == 'landlord')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isUpdatingVerification ? null : _toggleVerification,
                  icon: Icon(widget.user.isVerified ? Icons.unpublished : Icons.verified_user),
                  label: _isUpdatingVerification ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(widget.user.isVerified ? 'Revoke Verification' : 'Verify User'),
                  style: ElevatedButton.styleFrom(backgroundColor: widget.user.isVerified ? Colors.orange : Colors.green),
                ),
              ),

            // Block user action
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isBlockingUser ? null : _toggleUserBlock,
                icon: const Icon(Icons.block),
                label: _isBlockingUser ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Block User'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyCard(Property property) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Property image
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                child:
                    property.photos.isNotEmpty
                        ? Image.network(property.photos.first, height: 150, width: double.infinity, fit: BoxFit.cover, errorBuilder: (ctx, error, stackTrace) => Container(height: 150, color: Colors.grey.shade300, child: const Icon(Icons.image_not_supported, size: 50, color: Colors.white)))
                        : Container(height: 150, color: Colors.grey.shade300, child: const Icon(Icons.apartment, size: 50, color: Colors.white)),
              ),
              // Status badge
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: property.isVerified ? Colors.green : Colors.orange, borderRadius: BorderRadius.circular(20)),
                  child: Text(property.isVerified ? 'Verified' : 'Pending Verification', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            ],
          ),

          // Property details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(property.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(children: [const Icon(Icons.location_on, size: 16, color: Colors.grey), const SizedBox(width: 4), Expanded(child: Text(property.address, style: TextStyle(fontSize: 14, color: Colors.grey.shade700), maxLines: 1, overflow: TextOverflow.ellipsis))]),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('ZMW ${property.minPrice.toStringAsFixed(2)} / month', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                    Text('Added: ${DateFormat('MMM d, yyyy').format(property.createdAt)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [_buildPropertyStat('Rooms', property.totalRooms.toString()), _buildPropertyStat('Bed Spaces', property.totalBedSpaces.toString()), _buildPropertyStat('Occupied', '${property.occupiedBedSpaces}/${property.totalBedSpaces}')],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(Booking booking) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Booking header
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(booking.propertyName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis), _buildStatusBadge(booking.status)]),
            const SizedBox(height: 8),
            Text('Bed Space: ${booking.bedSpaceName}', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
            const Divider(height: 24),
            // Booking details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Check-in', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)), const SizedBox(height: 4), Text(DateFormat('MMM d, yyyy').format(booking.startDate), style: const TextStyle(fontWeight: FontWeight.bold))]),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('Check-out', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)), const SizedBox(height: 4), Text(DateFormat('MMM d, yyyy').format(booking.endDate), style: const TextStyle(fontWeight: FontWeight.bold))]),
              ],
            ),
            const Divider(height: 24),
            // Payment details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text('Total Amount', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)), const SizedBox(height: 4), Text('ZMW ${booking.totalPrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))],
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('Booking Date', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)), const SizedBox(height: 4), Text(DateFormat('MMM d, yyyy').format(booking.createdAt), style: const TextStyle(fontSize: 14))]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Container(width: 40, height: 3, color: AppTheme.primaryColor), const SizedBox(height: 12)]);
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

  Widget _buildRoleBadge(String role) {
    Color color;
    switch (role.toLowerCase()) {
      case 'landlord':
        color = Colors.blue;
        break;
      case 'student':
        color = Colors.green;
        break;
      case 'admin':
        color = Colors.purple;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.5))),
      child: Text(role.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _buildVerificationBadge(bool isVerified) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: isVerified ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: isVerified ? Colors.green.withOpacity(0.5) : Colors.orange.withOpacity(0.5))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isVerified ? Icons.verified_user : Icons.pending, size: 12, color: isVerified ? Colors.green : Colors.orange),
          const SizedBox(width: 4),
          Text(isVerified ? 'VERIFIED' : 'PENDING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isVerified ? Colors.green : Colors.orange)),
        ],
      ),
    );
  }

  Widget _buildPropertyStat(String label, String value) {
    return Column(children: [Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)), const SizedBox(height: 4), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))]);
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String displayStatus;

    switch (status.toLowerCase()) {
      case 'pending':
        color = Colors.orange;
        displayStatus = 'PENDING';
        break;
      case 'confirmed':
      case 'active':
        color = Colors.green;
        displayStatus = status.toUpperCase();
        break;
      case 'completed':
        color = Colors.blue;
        displayStatus = 'COMPLETED';
        break;
      case 'cancelled':
        color = Colors.red;
        displayStatus = 'CANCELLED';
        break;
      default:
        color = Colors.grey;
        displayStatus = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.5))),
      child: Text(displayStatus, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
    );
  }
}
