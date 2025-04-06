import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:my_boarding_house_partner/providers/auth_provider.dart';
import 'package:my_boarding_house_partner/screens/admin/user_management_screen.dart';
import 'package:my_boarding_house_partner/screens/admin/property_moderation_screen.dart';
import 'package:my_boarding_house_partner/screens/admin/booking_management_screen.dart';
import 'package:my_boarding_house_partner/screens/admin/admin_profile_screen.dart';
import 'package:my_boarding_house_partner/utils/app_theme.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadAdminStats();
  }

  Future<void> _loadAdminStats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      // Get total users count
      final usersQuery = await firestore.collection('Users').get();
      final int totalUsers = usersQuery.docs.length;

      // Count users by role
      int studentsCount = 0;
      int landlordsCount = 0;
      int adminsCount = 0;

      for (var doc in usersQuery.docs) {
        final role = doc.data()['role'] as String?;
        if (role == 'student') {
          studentsCount++;
        } else if (role == 'landlord') {
          landlordsCount++;
        } else if (role == 'admin') {
          adminsCount++;
        }
      }

      // Get properties count
      final propertiesQuery = await firestore.collection('Properties').get();
      final int totalProperties = propertiesQuery.docs.length;

      // Count properties by verification status
      int verifiedProperties = 0;
      int pendingProperties = 0;

      for (var doc in propertiesQuery.docs) {
        final isVerified = doc.data()['isVerified'] as bool?;
        if (isVerified == true) {
          verifiedProperties++;
        } else {
          pendingProperties++;
        }
      }

      // Get bookings count
      final bookingsQuery = await firestore.collection('Bookings').get();
      final int totalBookings = bookingsQuery.docs.length;

      // Count bookings by status
      int pendingBookings = 0;
      int confirmedBookings = 0;
      int completedBookings = 0;
      int cancelledBookings = 0;

      for (var doc in bookingsQuery.docs) {
        final status = doc.data()['status'] as String?;
        if (status == 'pending') {
          pendingBookings++;
        } else if (status == 'confirmed' || status == 'active') {
          confirmedBookings++;
        } else if (status == 'completed') {
          completedBookings++;
        } else if (status == 'cancelled') {
          cancelledBookings++;
        }
      }

      // Get total bed spaces and occupancy rate
      int totalBedSpaces = 0;
      int occupiedBedSpaces = 0;

      for (var property in propertiesQuery.docs) {
        totalBedSpaces += (property.data()['totalBedSpaces'] as int?) ?? 0;
        occupiedBedSpaces += (property.data()['occupiedBedSpaces'] as int?) ?? 0;
      }

      // Calculate occupancy rate
      double occupancyRate = totalBedSpaces > 0 ? (occupiedBedSpaces / totalBedSpaces) * 100 : 0;

      // Get total revenue
      final paymentsQuery = await firestore.collection('Payments').where('status', isEqualTo: 'completed').get();

      double totalRevenue = 0;
      for (var doc in paymentsQuery.docs) {
        totalRevenue += (doc.data()['amount'] as num?)?.toDouble() ?? 0;
      }

      // Set the stats in state
      setState(() {
        _stats = {
          'totalUsers': totalUsers,
          'studentsCount': studentsCount,
          'landlordsCount': landlordsCount,
          'adminsCount': adminsCount,
          'totalProperties': totalProperties,
          'verifiedProperties': verifiedProperties,
          'pendingProperties': pendingProperties,
          'totalBookings': totalBookings,
          'pendingBookings': pendingBookings,
          'confirmedBookings': confirmedBookings,
          'completedBookings': completedBookings,
          'cancelledBookings': cancelledBookings,
          'totalBedSpaces': totalBedSpaces,
          'occupiedBedSpaces': occupiedBedSpaces,
          'occupancyRate': occupancyRate,
          'totalRevenue': totalRevenue,
        };
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading admin stats: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  final List<Widget> _pages = [
    Container(), // AdminDashboardHome
    Container(), // UserManagementScreen
    Container(), // PropertyModerationScreen
    Container(), // BookingManagementScreen
    Container(), // AdminProfileScreen
  ];

  @override
  Widget build(BuildContext context) {
    // Initialize the pages with proper context
    _pages[0] = _buildDashboardHome(context);
    _pages[1] = const UserManagementScreen();
    _pages[2] = const PropertyModerationScreen();
    _pages[3] = const BookingManagementScreen();
    _pages[4] = const AdminProfileScreen();

    final authProvider = Provider.of<AppAuthProvider>(context);
    final userData = authProvider.userData;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(_currentIndex == 0 ? "Admin Dashboard" : _getTitle(_currentIndex), style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          if (_currentIndex == 0) // Only show notifications on dashboard
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              color: AppTheme.primaryColor,
              onPressed: () {
                // Navigate to notifications
              },
            ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: Colors.grey.shade600,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outlined), activeIcon: Icon(Icons.people), label: 'Users'),
          BottomNavigationBarItem(icon: Icon(Icons.apartment_outlined), activeIcon: Icon(Icons.apartment), label: 'Properties'),
          BottomNavigationBarItem(icon: Icon(Icons.book_outlined), activeIcon: Icon(Icons.book), label: 'Bookings'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  String _getTitle(int index) {
    switch (index) {
      case 1:
        return "User Management";
      case 2:
        return "Property Moderation";
      case 3:
        return "Booking Management";
      case 4:
        return "Admin Profile";
      default:
        return "Admin Dashboard";
    }
  }

  Widget _buildDashboardHome(BuildContext context) {
    final authProvider = Provider.of<AppAuthProvider>(context);
    final userData = authProvider.userData;

    return RefreshIndicator(
      onRefresh: _loadAdminStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppTheme.primaryColor,
                      backgroundImage: userData != null && userData['profileImageUrl'] != null ? NetworkImage(userData['profileImageUrl']) : null,
                      child: userData == null || userData['profileImageUrl'] == null ? const Icon(Icons.person, size: 32, color: Colors.white) : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Welcome, ${userData != null ? userData['displayName'] ?? 'Admin' : 'Admin'}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                            child: const Text("System Administrator", style: TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // System Overview
            const Text("System Overview", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
            const SizedBox(height: 12),

            // Stats Cards
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildSystemStatCard("Total Users", _stats['totalUsers']?.toString() ?? "0", Icons.people, Colors.blue)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildSystemStatCard("Properties", _stats['totalProperties']?.toString() ?? "0", Icons.apartment, Colors.orange)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildSystemStatCard("Bookings", _stats['totalBookings']?.toString() ?? "0", Icons.book, Colors.green)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildSystemStatCard("Revenue", "ZMW ${NumberFormat('#,##0.00').format(_stats['totalRevenue'] ?? 0)}", Icons.monetization_on, Colors.purple)),
                      ],
                    ),
                  ],
                ),
            const SizedBox(height: 24),

            // Pending Actions
            const Text("Pending Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
            const SizedBox(height: 12),

            // Pending Actions Cards
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  children: [
                    _buildPendingActionCard(
                      "Landlord Verifications",
                      "2", // Hardcoded for demo, would normally be from _stats
                      "New landlord accounts waiting for verification",
                      Icons.verified_user,
                      Colors.orange,
                      () {
                        setState(() {
                          _currentIndex = 1; // Navigate to users tab
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildPendingActionCard("Property Approvals", _stats['pendingProperties']?.toString() ?? "0", "Properties waiting for approval", Icons.home_work, Colors.blue, () {
                      setState(() {
                        _currentIndex = 2; // Navigate to properties tab
                      });
                    }),
                    const SizedBox(height: 12),
                    _buildPendingActionCard("Booking Issues", _stats['pendingBookings']?.toString() ?? "0", "Booking issues requiring attention", Icons.warning_amber, Colors.red, () {
                      setState(() {
                        _currentIndex = 3; // Navigate to bookings tab
                      });
                    }),
                  ],
                ),
            const SizedBox(height: 24),

            // System Statistics
            const Text("System Statistics", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
            const SizedBox(height: 12),

            // Statistics Cards
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  children: [
                    _buildStatisticsCard("User Distribution", [
                      {'label': 'Students', 'value': _stats['studentsCount'] ?? 0, 'color': Colors.blue},
                      {'label': 'Landlords', 'value': _stats['landlordsCount'] ?? 0, 'color': Colors.orange},
                      {'label': 'Admins', 'value': _stats['adminsCount'] ?? 0, 'color': Colors.purple},
                    ]),
                    const SizedBox(height: 12),
                    _buildStatisticsCard("Property Status", [
                      {'label': 'Verified', 'value': _stats['verifiedProperties'] ?? 0, 'color': Colors.green},
                      {'label': 'Pending', 'value': _stats['pendingProperties'] ?? 0, 'color': Colors.orange},
                    ]),
                    const SizedBox(height: 12),
                    _buildStatisticsCard("Booking Status", [
                      {'label': 'Confirmed', 'value': _stats['confirmedBookings'] ?? 0, 'color': Colors.green},
                      {'label': 'Pending', 'value': _stats['pendingBookings'] ?? 0, 'color': Colors.orange},
                      {'label': 'Completed', 'value': _stats['completedBookings'] ?? 0, 'color': Colors.blue},
                      {'label': 'Cancelled', 'value': _stats['cancelledBookings'] ?? 0, 'color': Colors.red},
                    ]),
                    const SizedBox(height: 12),
                    _buildOccupancyCard("Bed Space Occupancy", _stats['occupiedBedSpaces'] ?? 0, _stats['totalBedSpaces'] ?? 0),
                  ],
                ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemStatCard(String title, String value, IconData icon, Color color) {
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
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 24, color: color)),
                const Spacer(),
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
              ],
            ),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingActionCard(String title, String count, String description, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 28, color: color)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(description, style: TextStyle(fontSize: 14, color: Colors.grey.shade600))])),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)), child: Text(count, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsCard(String title, List<Map<String, dynamic>> items) {
    // Calculate total for percentages
    int total = items.fold(0, (sum, item) => sum + (item['value'] as int));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...items.map((item) {
              double percentage = total > 0 ? (item['value'] as int) / total * 100 : 0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(item['label'] as String, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                      Row(children: [Text('${item['value']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), const SizedBox(width: 4), Text('(${percentage.toStringAsFixed(1)}%)', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))]),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: percentage / 100, backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation<Color>(item['color'] as Color)),
                  const SizedBox(height: 16),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildOccupancyCard(String title, int occupied, int total) {
    double occupancyRate = total > 0 ? occupied / total * 100 : 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    children: [
                      Center(child: SizedBox(width: 100, height: 100, child: CircularProgressIndicator(value: occupancyRate / 100, backgroundColor: Colors.grey.shade200, strokeWidth: 10, valueColor: const AlwaysStoppedAnimation<Color>(Colors.green)))),
                      Center(child: Text('${occupancyRate.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(children: [const Text('Occupied', style: TextStyle(fontSize: 14, color: Colors.grey)), const SizedBox(height: 4), Text('$occupied', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green))]),
                Container(height: 30, width: 1, margin: const EdgeInsets.symmetric(horizontal: 20), color: Colors.grey.shade300),
                Column(children: [const Text('Total', style: TextStyle(fontSize: 14, color: Colors.grey)), const SizedBox(height: 4), Text('$total', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
