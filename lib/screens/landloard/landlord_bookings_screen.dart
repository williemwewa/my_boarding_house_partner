import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:my_boarding_house_partner/screens/landloard/booking_details_screen.dart';
import 'package:provider/provider.dart';

import 'package:my_boarding_house_partner/models/booking_model.dart';
import 'package:my_boarding_house_partner/providers/auth_provider.dart';
// import 'package:my_boarding_house_partner/screens/landlord/booking_details_screen.dart';
import 'package:my_boarding_house_partner/utils/app_theme.dart';
import 'package:my_boarding_house_partner/widgets/empty_state_widget.dart';

class LandlordBookingsScreen extends StatefulWidget {
  const LandlordBookingsScreen({Key? key}) : super(key: key);

  @override
  _LandlordBookingsScreenState createState() => _LandlordBookingsScreenState();
}

class _LandlordBookingsScreenState extends State<LandlordBookingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  List<Booking> _bookings = [];
  final ValueNotifier<String> _filterStatus = ValueNotifier<String>('All');
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadBookings();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    _filterStatus.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _filterStatus.value = 'All';
        _searchQuery = '';
        _searchController.clear();
      });
      _loadBookings();
    }
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      QuerySnapshot bookingsSnapshot;
      String status = '';

      switch (_tabController.index) {
        case 0: // Pending
          status = 'pending';
          break;
        case 1: // Active
          status = 'active';
          break;
        case 2: // Past
          status = 'completed';
          break;
      }

      // Create base query
      Query query = FirebaseFirestore.instance.collection('Bookings').where('landlordId', isEqualTo: user.uid);

      // Apply status filter
      if (status.isNotEmpty) {
        query = query.where('status', isEqualTo: status);
      }

      // Apply additional filter if selected
      if (_filterStatus.value != 'All') {
        if (_filterStatus.value == 'Today') {
          final today = DateTime.now();
          final startOfDay = DateTime(today.year, today.month, today.day);
          final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

          query = query.where('createdAt', isGreaterThanOrEqualTo: startOfDay);
          query = query.where('createdAt', isLessThanOrEqualTo: endOfDay);
        } else if (_filterStatus.value == 'This Week') {
          final now = DateTime.now();
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          final startDateTime = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

          query = query.where('createdAt', isGreaterThanOrEqualTo: startDateTime);
        } else if (_filterStatus.value == 'This Month') {
          final now = DateTime.now();
          final startOfMonth = DateTime(now.year, now.month, 1);

          query = query.where('createdAt', isGreaterThanOrEqualTo: startOfMonth);
        }
      }

      // Get bookings
      bookingsSnapshot = await query.get();

      // Parse bookings
      List<Booking> fetchedBookings = [];
      for (var doc in bookingsSnapshot.docs) {
        final booking = Booking.fromFirestore(doc);

        // Apply search filter if provided
        if (_searchQuery.isNotEmpty) {
          final searchLower = _searchQuery.toLowerCase();
          if (booking.propertyName.toLowerCase().contains(searchLower) || booking.studentName.toLowerCase().contains(searchLower) || booking.bookingId.toLowerCase().contains(searchLower)) {
            fetchedBookings.add(booking);
          }
        } else {
          fetchedBookings.add(booking);
        }
      }

      // Sort bookings: recent first
      fetchedBookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (mounted) {
        setState(() {
          _bookings = fetchedBookings;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading bookings: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading bookings: ${e.toString()}'), backgroundColor: Colors.red));
      }
    }
  }

  void _handleSearch(String query) {
    setState(() {
      _searchQuery = query;
    });
    _loadBookings();
  }

  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
    });
    _loadBookings();
  }

  void _navigateToBookingDetails(Booking booking) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => BookingDetailsScreen(booking: booking))).then((_) => _loadBookings()); // Refresh when returning
  }

  String _getTabTitle(int index) {
    switch (index) {
      case 0:
        return 'Pending';
      case 1:
        return 'Active';
      case 2:
        return 'Past';
      default:
        return 'Bookings';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Tab bar
          Container(color: Colors.white, child: TabBar(controller: _tabController, tabs: const [Tab(text: 'Pending'), Tab(text: 'Active'), Tab(text: 'Past')], indicatorColor: AppTheme.primaryColor, labelColor: AppTheme.primaryColor, unselectedLabelColor: Colors.grey)),

          // Search and filter bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by property, student or booking ID',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: _clearSearch) : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: _handleSearch,
                ),

                const SizedBox(height: 8),

                // Filter chips
                ValueListenableBuilder<String>(
                  valueListenable: _filterStatus,
                  builder: (context, value, child) {
                    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [_buildFilterChip('All', value), _buildFilterChip('Today', value), _buildFilterChip('This Week', value), _buildFilterChip('This Month', value)]));
                  },
                ),
              ],
            ),
          ),

          // Bookings list
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _bookings.isEmpty
                    ? EmptyStateWidget(
                      icon: Icons.book_outlined,
                      title: 'No ${_getTabTitle(_tabController.index)} Bookings',
                      message:
                          _tabController.index == 0
                              ? 'You don\'t have any pending booking requests at the moment.'
                              : _tabController.index == 1
                              ? 'You don\'t have any active bookings at the moment.'
                              : 'You don\'t have any past bookings at the moment.',
                    )
                    : RefreshIndicator(
                      onRefresh: _loadBookings,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _bookings.length,
                        itemBuilder: (context, index) {
                          return _buildBookingCard(_bookings[index]);
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String selectedValue) {
    final isSelected = selectedValue == label;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          _filterStatus.value = label;
          _loadBookings();
        },
        backgroundColor: Colors.grey.shade200,
        selectedColor: AppTheme.primaryColor.withOpacity(0.2),
        checkmarkColor: AppTheme.primaryColor,
        labelStyle: TextStyle(color: isSelected ? AppTheme.primaryColor : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
      ),
    );
  }

  Widget _buildBookingCard(Booking booking) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: () => _navigateToBookingDetails(booking),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Property name and booking status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(booking.propertyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: _getStatusColor(booking.status).withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: _getStatusColor(booking.status).withOpacity(0.5))),
                    child: Text(_getFormattedStatus(booking.status), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _getStatusColor(booking.status))),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Bed space info
              Row(children: [const Icon(Icons.bed, size: 16, color: Colors.grey), const SizedBox(width: 4), Expanded(child: Text('Bed Space: ${booking.bedSpaceName}', style: TextStyle(fontSize: 14, color: Colors.grey.shade700), maxLines: 1, overflow: TextOverflow.ellipsis))]),

              const SizedBox(height: 8),

              // Date range
              Row(children: [const Icon(Icons.date_range, size: 16, color: Colors.grey), const SizedBox(width: 4), Text('${DateFormat('MMM d, yyyy').format(booking.startDate)} - ${DateFormat('MMM d, yyyy').format(booking.endDate)}', style: TextStyle(fontSize: 14, color: Colors.grey.shade700))]),

              const SizedBox(height: 8),

              // Student info
              Row(children: [const Icon(Icons.person, size: 16, color: Colors.grey), const SizedBox(width: 4), Text('Student: ${booking.studentName}', style: TextStyle(fontSize: 14, color: Colors.grey.shade700))]),

              const Divider(height: 24),

              // Booking details: Price, date, ID
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text('Total Price', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)), const SizedBox(height: 2), Text('ZMW ${booking.totalPrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))],
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('Booking Date', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)), const SizedBox(height: 2), Text(DateFormat('MMM d, yyyy').format(booking.createdAt), style: const TextStyle(fontSize: 14))]),
                ],
              ),

              const SizedBox(height: 16),

              // Action buttons
              _tabController.index ==
                      0 // Pending bookings have accept/decline
                  ? Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            // Show reject confirmation dialog
                          },
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          child: const Text('Decline'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            // Accept booking action
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          child: const Text('Accept'),
                        ),
                      ),
                    ],
                  )
                  : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Booking ID: #${booking.bookingId.substring(0, 8)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      OutlinedButton(onPressed: () => _navigateToBookingDetails(booking), style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('View Details')),
                    ],
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getFormattedStatus(String status) {
    switch (status) {
      case 'pending':
        return 'Pending Approval';
      case 'confirmed':
        return 'Confirmed';
      case 'active':
        return 'Active';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status.capitalize();
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}
