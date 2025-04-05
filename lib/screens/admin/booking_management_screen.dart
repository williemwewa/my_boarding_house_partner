import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:my_boarding_house_partner/utils/app_theme.dart';
import 'package:my_boarding_house_partner/models/booking_model.dart';
import 'package:my_boarding_house_partner/screens/admin/booking_details_screen.dart';
import 'package:my_boarding_house_partner/widgets/empty_state_widget.dart';

class BookingManagementScreen extends StatefulWidget {
  const BookingManagementScreen({Key? key}) : super(key: key);

  @override
  _BookingManagementScreenState createState() => _BookingManagementScreenState();
}

class _BookingManagementScreenState extends State<BookingManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  List<Booking> _bookings = [];
  List<Booking> _filteredBookings = [];

  final TextEditingController _searchController = TextEditingController();
  String _filterStatus = 'All';
  String _dateFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadBookings();
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
        _filterStatus = 'All';
        _dateFilter = 'All';
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
      QuerySnapshot bookingsSnapshot;
      Query query = FirebaseFirestore.instance.collection('Bookings');

      // Apply tab-specific filters
      switch (_tabController.index) {
        case 0: // All
          break;
        case 1: // Pending
          query = query.where('status', isEqualTo: 'pending');
          break;
        case 2: // Active
          query = query.where('status', whereIn: ['confirmed', 'active']);
          break;
        case 3: // Completed/Cancelled
          query = query.where('status', whereIn: ['completed', 'cancelled']);
          break;
      }

      // Apply payment status filter if not "All"
      if (_filterStatus != 'All') {
        query = query.where('paymentStatus', isEqualTo: _filterStatus.toLowerCase());
      }

      // Apply date filter
      if (_dateFilter != 'All') {
        final now = DateTime.now();
        late DateTime startDate;

        switch (_dateFilter) {
          case 'Today':
            startDate = DateTime(now.year, now.month, now.day);
            query = query.where('createdAt', isGreaterThanOrEqualTo: startDate);
            break;
          case 'This Week':
            // Start of week (Monday)
            startDate = now.subtract(Duration(days: now.weekday - 1));
            startDate = DateTime(startDate.year, startDate.month, startDate.day);
            query = query.where('createdAt', isGreaterThanOrEqualTo: startDate);
            break;
          case 'This Month':
            startDate = DateTime(now.year, now.month, 1);
            query = query.where('createdAt', isGreaterThanOrEqualTo: startDate);
            break;
        }
      }

      // Order by creation date (newest first)
      query = query.orderBy('createdAt', descending: true);

      // Execute query
      bookingsSnapshot = await query.get();

      // Parse results
      List<Booking> fetchedBookings = bookingsSnapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();

      // Apply search filter
      _applySearchFilter(fetchedBookings, _searchController.text);
    } catch (e) {
      print('Error loading bookings: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load bookings: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _applySearchFilter(List<Booking> bookings, String query) {
    if (query.isEmpty) {
      setState(() {
        _bookings = bookings;
        _filteredBookings = bookings;
      });
      return;
    }

    final searchLower = query.toLowerCase();
    final filtered =
        bookings.where((booking) {
          return booking.propertyName.toLowerCase().contains(searchLower) || booking.studentName.toLowerCase().contains(searchLower) || booking.bookingId.toLowerCase().contains(searchLower);
        }).toList();

    setState(() {
      _bookings = bookings;
      _filteredBookings = filtered;
    });
  }

  void _handleSearch(String query) {
    _applySearchFilter(_bookings, query);
  }

  void _clearSearch() {
    _searchController.clear();
    _applySearchFilter(_bookings, '');
  }

  void _navigateToBookingDetails(Booking booking) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => AdminBookingDetailsScreen(booking: booking))).then((_) => _loadBookings()); // Refresh when returning
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Tab bar
          Container(
            color: Colors.white,
            child: TabBar(controller: _tabController, tabs: const [Tab(text: 'All'), Tab(text: 'Pending'), Tab(text: 'Active'), Tab(text: 'Past')], indicatorColor: AppTheme.primaryColor, labelColor: AppTheme.primaryColor, unselectedLabelColor: Colors.grey, isScrollable: true),
          ),

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
                    suffixIcon: _searchController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: _clearSearch) : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: _handleSearch,
                ),

                const SizedBox(height: 12),

                // Filter options
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Payment Status:'),
                          const SizedBox(height: 4),
                          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [_buildStatusFilterChip('All'), _buildStatusFilterChip('Pending'), _buildStatusFilterChip('Completed'), _buildStatusFilterChip('Refunded')])),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Date:'),
                          const SizedBox(height: 4),
                          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [_buildDateFilterChip('All'), _buildDateFilterChip('Today'), _buildDateFilterChip('This Week'), _buildDateFilterChip('This Month')])),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Bookings list
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredBookings.isEmpty
                    ? EmptyStateWidget(
                      icon: Icons.book_outlined,
                      title: 'No Bookings Found',
                      message:
                          _tabController.index == 1
                              ? 'There are no pending bookings at the moment.'
                              : _tabController.index == 2
                              ? 'There are no active bookings at the moment.'
                              : 'No bookings match your current filters or search criteria.',
                    )
                    : RefreshIndicator(
                      onRefresh: _loadBookings,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredBookings.length,
                        itemBuilder: (context, index) {
                          return _buildBookingCard(_filteredBookings[index]);
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChip(String status) {
    final isSelected = _filterStatus == status;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(status),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _filterStatus = status;
          });
          _loadBookings();
        },
        backgroundColor: Colors.grey.shade200,
        selectedColor: AppTheme.primaryColor.withOpacity(0.2),
        checkmarkColor: AppTheme.primaryColor,
        labelStyle: TextStyle(color: isSelected ? AppTheme.primaryColor : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
      ),
    );
  }

  Widget _buildDateFilterChip(String filter) {
    final isSelected = _dateFilter == filter;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(filter),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _dateFilter = filter;
          });
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
              // Booking ID and status badges
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [Text('Booking #${booking.bookingId}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 4), Text(DateFormat('MMM d, yyyy').format(booking.createdAt), style: TextStyle(fontSize: 12, color: Colors.grey.shade600))],
                    ),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [_buildStatusBadge(booking.status, _getStatusColor(booking.status)), const SizedBox(height: 4), _buildStatusBadge(booking.paymentStatus, _getPaymentStatusColor(booking.paymentStatus))]),
                ],
              ),
              const Divider(height: 24),

              // Property and student info
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Property info
                        const Text('Property', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(booking.propertyName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text('Bed Space: ${booking.bedSpaceName}', style: TextStyle(fontSize: 13, color: Colors.grey.shade700), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Student info
                        const Text('Student', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(booking.studentName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(booking.studentPhoneNumber, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Booking details
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [const Text('Check-in', style: TextStyle(fontSize: 12, color: Colors.grey)), const SizedBox(height: 4), Text(DateFormat('MMM d, yyyy').format(booking.startDate), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))],
                  ),
                  const Icon(Icons.arrow_forward, color: Colors.grey, size: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [const Text('Check-out', style: TextStyle(fontSize: 12, color: Colors.grey)), const SizedBox(height: 4), Text(DateFormat('MMM d, yyyy').format(booking.endDate), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Payment info and action button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [const Text('Amount', style: TextStyle(fontSize: 12, color: Colors.grey)), const SizedBox(height: 4), Text('ZMW ${booking.totalPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor))],
                  ),
                  OutlinedButton(
                    onPressed: () => _navigateToBookingDetails(booking),
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryColor, side: BorderSide(color: AppTheme.primaryColor), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: const Text('View Details'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, Color color) {
    String displayText = status.toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.5))),
      child: Text(displayText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
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

  Color _getPaymentStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'refunded':
        return Colors.blue;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
