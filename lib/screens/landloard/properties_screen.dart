import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_boarding_house_partner/screens/landloard/add_property_screen.dart';
import 'package:my_boarding_house_partner/screens/landloard/property_details_screen.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:my_boarding_house_partner/providers/auth_provider.dart';
import 'package:my_boarding_house_partner/utils/app_theme.dart';
import 'package:my_boarding_house_partner/widgets/empty_state_widget.dart';
import 'package:my_boarding_house_partner/models/property_model.dart';

class PropertiesScreen extends StatefulWidget {
  const PropertiesScreen({Key? key}) : super(key: key);

  @override
  _PropertiesScreenState createState() => _PropertiesScreenState();
}

class _PropertiesScreenState extends State<PropertiesScreen> {
  bool _isLoading = true;
  List<Property> _properties = [];
  String _filterStatus = 'All'; // 'All', 'Active', 'Inactive', 'Pending'
  bool _showVerifiedOnly = false;

  @override
  void initState() {
    super.initState();
    // Small delay to ensure Firebase Auth is initialized properly
    Future.delayed(Duration.zero, () {
      _loadProperties();
    });
  }

  Future<void> _loadProperties() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You need to be logged in to view properties'), backgroundColor: Colors.red));
        return;
      }

      // First, check if any properties exist for this user at all
      final checkQuery = await FirebaseFirestore.instance.collection('Properties').where('landlordId', isEqualTo: user.uid).limit(1).get();

      // Create a query for this landlord's properties
      Query query = FirebaseFirestore.instance.collection('Properties').where('landlordId', isEqualTo: user.uid);

      // Apply status filter if not 'All'
      if (_filterStatus != 'All') {
        if (_filterStatus == 'Active') {
          query = query.where('isActive', isEqualTo: true);
        } else if (_filterStatus == 'Inactive') {
          query = query.where('isActive', isEqualTo: false);
        } else if (_filterStatus == 'Pending') {
          query = query.where('isVerified', isEqualTo: false);
        }
      }

      // Apply verification filter if needed
      if (_showVerifiedOnly) {
        query = query.where('isVerified', isEqualTo: true);
      }

      // Execute the query
      final snapshot = await query.get();

      // Parse the results
      _properties =
          snapshot.docs
              .map((doc) {
                try {
                  return Property.fromFirestore(doc);
                } catch (e) {
                  // Return null for properties that fail to parse
                  return null;
                }
              })
              .where((property) => property != null) // Filter out null properties
              .cast<Property>() // Cast to non-nullable Property
              .toList();

      // Sort properties: Active first, then by date (newest first)
      _properties.sort((a, b) {
        // First sort by active status
        if (a.isActive && !b.isActive) return -1;
        if (!a.isActive && b.isActive) return 1;

        // Then sort by creation date (newest first)
        return b.createdAt.compareTo(a.createdAt);
      });
    } catch (e) {
      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load properties: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToAddProperty() {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AddPropertyScreen())).then((_) => _loadProperties()); // Refresh when returning
  }

  void _navigateToPropertyDetails(Property property) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => PropertyDetailsScreen(property: property))).then((_) => _loadProperties()); // Refresh when returning
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AppAuthProvider>(context);
    final isVerified = authProvider.userData?['isVerified'] == true;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadProperties,
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  children: [
                    // Filter bar
                    _buildFilterBar(),

                    // Properties list or empty state
                    Expanded(
                      child:
                          _properties.isEmpty
                              ? EmptyStateWidget(icon: Icons.apartment, title: 'No Properties Found', message: 'You haven\'t added any properties yet. Tap the button below to add your first property.', buttonText: 'Add Property', onButtonPressed: isVerified ? _navigateToAddProperty : null)
                              : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _properties.length,
                                itemBuilder: (context, index) {
                                  return _buildPropertyCard(_properties[index]);
                                },
                              ),
                    ),
                  ],
                ),
      ),
      floatingActionButton:
          isVerified
              ? FloatingActionButton(backgroundColor: AppTheme.primaryColor, child: const Icon(Icons.add), onPressed: _navigateToAddProperty)
              : FloatingActionButton(
                backgroundColor: Colors.grey,
                child: const Icon(Icons.add),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your account needs to be verified before you can add properties.'), backgroundColor: Colors.orange));
                },
              ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Filter by:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [_filterChip('All'), _filterChip('Active'), _filterChip('Inactive'), _filterChip('Pending')]))),
            ],
          ),
          Row(
            children: [
              Checkbox(
                value: _showVerifiedOnly,
                activeColor: AppTheme.primaryColor,
                onChanged: (value) {
                  setState(() {
                    _showVerifiedOnly = value ?? false;
                    _loadProperties();
                  });
                },
              ),
              const Text('Show verified properties only'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String status) {
    final isSelected = _filterStatus == status;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(status),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _filterStatus = status;
            _loadProperties();
          });
        },
        backgroundColor: Colors.grey.shade200,
        selectedColor: AppTheme.primaryColor.withOpacity(0.2),
        checkmarkColor: AppTheme.primaryColor,
        labelStyle: TextStyle(color: isSelected ? AppTheme.primaryColor : AppTheme.primaryColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
      ),
    );
  }

  Widget _buildPropertyCard(Property property) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: () => _navigateToPropertyDetails(property),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Property image with status badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                  child:
                      property.photos.isNotEmpty
                          ? Image.network(property.photos.first, height: 160, width: double.infinity, fit: BoxFit.cover, errorBuilder: (ctx, error, stackTrace) => Container(height: 160, color: Colors.grey.shade300, child: const Icon(Icons.image_not_supported, size: 50, color: Colors.white)))
                          : Container(height: 160, color: Colors.grey.shade300, child: const Icon(Icons.apartment, size: 50, color: Colors.white)),
                ),
                // Status badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: _getStatusColor(property), borderRadius: BorderRadius.circular(20)),
                    child: Text(_getStatusText(property), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                // Verification badge if applicable
                if (property.isVerified)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.teal, borderRadius: BorderRadius.circular(20)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.verified, color: Colors.white, size: 16), SizedBox(width: 4), Text('Verified', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))]),
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
                  // Property name
                  Text(property.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  // Address
                  Row(children: [const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey), const SizedBox(width: 4), Expanded(child: Text(property.address, style: TextStyle(fontSize: 14, color: Colors.grey.shade700), maxLines: 1, overflow: TextOverflow.ellipsis))]),
                  const SizedBox(height: 16),
                  // Stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [_buildStat(Icons.meeting_room_outlined, '${property.totalRooms} Rooms'), _buildStat(Icons.bed_outlined, '${property.totalBedSpaces} Bed Spaces'), _buildStat(Icons.monetization_on_outlined, 'ZMW ${property.minPrice.toStringAsFixed(0)}')],
                  ),
                  const SizedBox(height: 16),
                  // Booking status row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle), child: Icon(Icons.book_outlined, size: 16, color: Colors.blue.shade700)),
                          const SizedBox(width: 8),
                          Text('${property.occupiedBedSpaces}/${property.totalBedSpaces} Occupied', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey.shade800)),
                        ],
                      ),
                      Text('Added: ${DateFormat('MMM d, yyyy').format(property.createdAt)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String text) {
    return Row(children: [Icon(icon, size: 16, color: Colors.grey.shade700), const SizedBox(width: 4), Text(text, style: TextStyle(fontSize: 13, color: Colors.grey.shade800))]);
  }

  Color _getStatusColor(Property property) {
    if (!property.isVerified) return Colors.orange;
    if (!property.isActive) return Colors.grey;
    return Colors.green;
  }

  String _getStatusText(Property property) {
    if (!property.isVerified) return 'Pending Verification';
    if (!property.isActive) return 'Inactive';
    return 'Active';
  }
}
