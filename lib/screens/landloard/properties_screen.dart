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
  Map<String, bool> _favorites = {}; // Track favorited properties

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
        backgroundColor: isSelected ? Colors.grey.shade100 : Colors.grey.shade200, // lighter when inactive
        selectedColor: Colors.grey.shade100,
        checkmarkColor: AppTheme.primaryColor,
        labelStyle: TextStyle(color: isSelected ? AppTheme.primaryColor : Colors.black54, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
        side: BorderSide(color: isSelected ? AppTheme.primaryColor : Colors.grey.shade400, width: 1),
      ),
    );
  }

  Widget _buildPropertyCard(Property property) {
    // Determine if singular or plural for rooms
    final roomText = property.totalRooms == 1 ? '1 Room' : '${property.totalRooms} Rooms';
    final bedText = property.totalBedSpaces == 1 ? '1 Bed' : '${property.totalBedSpaces} Beds';

    // Get favorite status
    final isFavorite = _favorites[property.id] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToPropertyDetails(property),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Property image with heart icon
            Stack(
              children: [
                // Property image with border radius on all sides
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child:
                      property.photos.isNotEmpty
                          ? Image.network(property.photos.first, height: 300, width: double.infinity, fit: BoxFit.cover, errorBuilder: (ctx, error, stackTrace) => Container(height: 300, color: Colors.grey.shade300, child: const Icon(Icons.image_not_supported, size: 50, color: Colors.white)))
                          : Container(height: 300, color: Colors.grey.shade300, child: const Icon(Icons.apartment, size: 50, color: Colors.white)),
                ),

                // Heart icon - now toggleable
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    decoration: BoxDecoration(color: Colors.transparent, shape: BoxShape.circle),
                    child: IconButton(
                      icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? Colors.red : Colors.white, size: 28),
                      onPressed: () {
                        setState(() {
                          // Toggle favorite status
                          _favorites[property.id] = !isFavorite;
                        });
                      },
                    ),
                  ),
                ),

                // Status badge - styled to match the new design
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: _getStatusColor(property).withOpacity(0.8), borderRadius: BorderRadius.circular(20)),
                    child: Text(_getStatusText(property), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 12)),
                  ),
                ),

                // Verification badge if applicable - styled to match new design
                if (property.isVerified)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.teal.withOpacity(0.8), borderRadius: BorderRadius.circular(16)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.verified, color: Colors.white, size: 14), SizedBox(width: 4), Text('Verified', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 11))]),
                    ),
                  ),

                // Indicator dots
                Positioned(
                  bottom: 8,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 8, height: 8, margin: EdgeInsets.symmetric(horizontal: 2), decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
                      for (int i = 0; i < 4; i++) Container(width: 8, height: 8, margin: EdgeInsets.symmetric(horizontal: 2), decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.5))),
                    ],
                  ),
                ),
              ],
            ),

            // Property details - matching the exact layout in the image
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location and rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text("${property.address.split(',').first}, ${property.address.split(',').last.trim()}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Row(children: [Icon(Icons.star, size: 16, color: Colors.black), SizedBox(width: 4), Text("No Rating", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500))]),
                    ],
                  ),

                  SizedBox(height: 4),

                  // Description text - using original property name
                  Text(property.name, style: TextStyle(fontSize: 16, color: Colors.grey.shade700, fontWeight: FontWeight.normal), maxLines: 1, overflow: TextOverflow.ellipsis),

                  SizedBox(height: 4),

                  // Occupancy info (from original) - styled to fit new design
                  Text("${property.occupiedBedSpaces}/${property.totalBedSpaces} bed spaces occupied", style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),

                  SizedBox(height: 10),

                  // Stats in a clean, subtle row - with singular/plural forms
                  Row(children: [_buildNewStat(Icons.meeting_room_outlined, roomText), SizedBox(width: 16), _buildNewStat(Icons.bed_outlined, bedText)]),

                  SizedBox(height: 10),

                  // Price - removed "for 6 nights" text
                  Text("ZMW ${property.minPrice.toStringAsFixed(0)}", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, decoration: TextDecoration.underline)),

                  SizedBox(height: 8),

                  // Date added - styled to be subtle but present
                  Text('Added: ${DateFormat('MMM d, yyyy').format(property.createdAt)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Updated stat builder to match the new design
  Widget _buildNewStat(IconData icon, String text) {
    return Row(children: [Icon(icon, size: 14, color: Colors.grey.shade700), const SizedBox(width: 4), Text(text, style: TextStyle(fontSize: 14, color: Colors.grey.shade700))]);
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
