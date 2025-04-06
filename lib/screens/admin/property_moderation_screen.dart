import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:my_boarding_house_partner/utils/app_theme.dart';
import 'package:my_boarding_house_partner/models/property_model.dart';
import 'package:my_boarding_house_partner/screens/admin/property_review_screen.dart';
import 'package:my_boarding_house_partner/widgets/empty_state_widget.dart';

class PropertyModerationScreen extends StatefulWidget {
  const PropertyModerationScreen({Key? key}) : super(key: key);

  @override
  _PropertyModerationScreenState createState() => _PropertyModerationScreenState();
}

class _PropertyModerationScreenState extends State<PropertyModerationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  List<Property> _properties = [];
  List<Property> _filteredProperties = [];

  final TextEditingController _searchController = TextEditingController();
  String _filterType = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadProperties();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _filterType = 'All';
        _searchController.clear();
      });
      _loadProperties();
    }
  }

  Future<void> _loadProperties() async {
    setState(() {
      _isLoading = true;
    });

    try {
      Query query = FirebaseFirestore.instance.collection('Properties');

      // Apply tab filters
      if (_tabController.index == 0) {
        // Pending tab - show unverified properties
        query = query.where('isVerified', isEqualTo: false);
      } else if (_tabController.index == 1) {
        // Verified tab - show verified properties
        query = query.where('isVerified', isEqualTo: true);
      }
      // Index 2 is All Properties - no filter

      // Apply property type filter if selected
      if (_filterType != 'All') {
        query = query.where('propertyType', isEqualTo: _filterType);
      }

      final propertiesSnapshot = await query.get();

      // Parse the results
      List<Property> fetchedProperties = propertiesSnapshot.docs.map((doc) => Property.fromFirestore(doc)).toList();

      // Sort: pending/newest first
      fetchedProperties.sort((a, b) {
        // If sorting pending tab or verification status differs, show unverified first
        if (_tabController.index == 0 || a.isVerified != b.isVerified) {
          return a.isVerified ? 1 : -1;
        }
        // Otherwise sort by creation date (newest first)
        return b.createdAt.compareTo(a.createdAt);
      });

      // Apply search filter
      _applySearchFilter(fetchedProperties, _searchController.text);
    } catch (e) {
      print('Error loading properties: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load properties: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _applySearchFilter(List<Property> properties, String query) {
    if (query.isEmpty) {
      setState(() {
        _properties = properties;
        _filteredProperties = properties;
      });
      return;
    }

    final searchLower = query.toLowerCase();
    final filtered =
        properties.where((property) {
          return property.name.toLowerCase().contains(searchLower) || property.address.toLowerCase().contains(searchLower) || property.description.toLowerCase().contains(searchLower);
        }).toList();

    setState(() {
      _properties = properties;
      _filteredProperties = filtered;
    });
  }

  void _handleSearch(String query) {
    _applySearchFilter(_properties, query);
  }

  void _clearSearch() {
    _searchController.clear();
    _applySearchFilter(_properties, '');
  }

  void _navigateToPropertyReview(Property property) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => PropertyReviewScreen(property: property))).then((_) => _loadProperties()); // Refresh when returning
  }

  void _showVerificationDialog(Property property) {
    final bool newVerificationStatus = !property.isVerified;
    final String actionText = newVerificationStatus ? 'Verify' : 'Unverify';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$actionText Property'),
          content: Text(
            'Are you sure you want to ${actionText.toLowerCase()} "${property.name}"?\n\n'
            'This will ${newVerificationStatus ? 'make it visible to students' : 'hide it from students'}.',
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
                _updatePropertyVerification(property, newVerificationStatus);
              },
              style: ElevatedButton.styleFrom(backgroundColor: newVerificationStatus ? Colors.green : Colors.orange),
              child: Text(actionText),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updatePropertyVerification(Property property, bool isVerified) async {
    try {
      await FirebaseFirestore.instance.collection('Properties').doc(property.id).update({'isVerified': isVerified, 'updatedAt': FieldValue.serverTimestamp()});

      // Refresh the property list
      _loadProperties();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isVerified ? '${property.name} has been verified successfully!' : '${property.name} verification has been revoked.'), backgroundColor: isVerified ? Colors.green : Colors.orange));
    } catch (e) {
      print('Error updating property verification: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating property: ${e.toString()}'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Tab bar
          Container(color: Colors.white, child: TabBar(controller: _tabController, tabs: const [Tab(text: 'Pending'), Tab(text: 'Verified'), Tab(text: 'All')], indicatorColor: AppTheme.primaryColor, labelColor: AppTheme.primaryColor, unselectedLabelColor: Colors.grey)),

          // Search and filter bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search properties',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: _clearSearch) : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: _handleSearch,
                ),

                const SizedBox(height: 12),

                // Property type filter
                SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [const Text('Type:'), const SizedBox(width: 8), _buildFilterChip('All'), _buildFilterChip('Apartment'), _buildFilterChip('House'), _buildFilterChip('Dormitory'), _buildFilterChip('Student Residence')])),
              ],
            ),
          ),

          // Properties list
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredProperties.isEmpty
                    ? EmptyStateWidget(icon: Icons.apartment_outlined, title: 'No Properties Found', message: _tabController.index == 0 ? 'There are no properties pending verification at the moment.' : 'No properties match your current filters or search criteria.')
                    : RefreshIndicator(
                      onRefresh: _loadProperties,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredProperties.length,
                        itemBuilder: (context, index) {
                          return _buildPropertyCard(_filteredProperties[index]);
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String type) {
    final isSelected = _filterType == type;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(type),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _filterType = type;
          });
          _loadProperties();
        },
        backgroundColor: Colors.grey.shade200,
        selectedColor: AppTheme.primaryColor.withOpacity(0.2),
        checkmarkColor: AppTheme.primaryColor,
        labelStyle: TextStyle(color: isSelected ? AppTheme.primaryColor : AppTheme.primaryColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
      ),
    );
  }

  Widget _buildPropertyCard(Property property) {
    // Get landlord name from property metadata
    Future<String> getLandlordName() async {
      try {
        final userDoc = await FirebaseFirestore.instance.collection('Users').doc(property.landlordId).get();

        if (userDoc.exists) {
          return userDoc.data()?['displayName'] ?? 'Unknown Landlord';
        }

        return 'Unknown Landlord';
      } catch (e) {
        print('Error getting landlord name: $e');
        return 'Unknown Landlord';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: () => _navigateToPropertyReview(property),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    decoration: BoxDecoration(color: property.isVerified ? Colors.green : Colors.orange, borderRadius: BorderRadius.circular(20)),
                    child: Text(property.isVerified ? 'VERIFIED' : 'PENDING', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                // Active/Inactive badge
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: property.isActive ? Colors.blue : Colors.grey, borderRadius: BorderRadius.circular(20)),
                    child: Text(property.isActive ? 'ACTIVE' : 'INACTIVE', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
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

                  // Property address
                  Row(children: [const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey), const SizedBox(width: 4), Expanded(child: Text(property.address, style: TextStyle(fontSize: 14, color: Colors.grey.shade700), maxLines: 1, overflow: TextOverflow.ellipsis))]),
                  const SizedBox(height: 8),

                  // Landlord name (using FutureBuilder)
                  FutureBuilder<String>(
                    future: getLandlordName(),
                    builder: (context, snapshot) {
                      return Row(children: [const Icon(Icons.person_outlined, size: 16, color: Colors.grey), const SizedBox(width: 4), Text('Landlord: ${snapshot.data ?? 'Loading...'}', style: TextStyle(fontSize: 14, color: Colors.grey.shade700))]);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [_buildStat(Icons.meeting_room_outlined, '${property.totalRooms} Rooms'), _buildStat(Icons.bed_outlined, '${property.totalBedSpaces} Bed Spaces'), _buildStat(Icons.monetization_on_outlined, 'ZMW ${property.minPrice.toStringAsFixed(0)}')],
                  ),
                  const SizedBox(height: 16),

                  // Date and action button row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Added: ${DateFormat('MMM d, yyyy').format(property.createdAt)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      OutlinedButton(
                        onPressed: () => _showVerificationDialog(property),
                        style: OutlinedButton.styleFrom(foregroundColor: property.isVerified ? Colors.orange : Colors.green, side: BorderSide(color: property.isVerified ? Colors.orange : Colors.green), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        child: Text(property.isVerified ? 'Unverify' : 'Verify'),
                      ),
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
}
