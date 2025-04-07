import 'package:flutter/material.dart';
import 'package:my_boarding_house_partner/screens/landloard/add_property_screen.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:my_boarding_house_partner/providers/auth_provider.dart';
import 'package:my_boarding_house_partner/screens/landloard/properties_screen.dart';
import 'package:my_boarding_house_partner/screens/landloard/landlord_bookings_screen.dart';
import 'package:my_boarding_house_partner/screens/landloard/landlord_earnings_screen.dart';
import 'package:my_boarding_house_partner/screens/landloard/landlord_messages_screen.dart';
import 'package:my_boarding_house_partner/screens/landloard/landlord_profile_screen.dart';

import 'package:my_boarding_house_partner/utils/app_theme.dart';

class LandlordDashboard extends StatefulWidget {
  const LandlordDashboard({Key? key}) : super(key: key);

  @override
  _LandlordDashboardState createState() => _LandlordDashboardState();
}

class _LandlordDashboardState extends State<LandlordDashboard> {
  int _currentIndex = 0;
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadLandlordStats();
  }

  Future<void> _loadLandlordStats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user == null) return;

      // Get property count
      final propertyQuery = await FirebaseFirestore.instance.collection('Properties').where('landlordId', isEqualTo: user.uid).get();

      int propertyCount = propertyQuery.docs.length;

      // Get room count
      int roomCount = 0;
      int bedSpaceCount = 0;
      double totalEarnings = 0;

      for (var property in propertyQuery.docs) {
        // Count rooms in each property
        final roomQuery = await FirebaseFirestore.instance.collection('Properties').doc(property.id).collection('Rooms').get();

        roomCount += roomQuery.docs.length;

        // Count bed spaces in each room
        for (var room in roomQuery.docs) {
          final bedSpaceQuery = await FirebaseFirestore.instance.collection('Properties').doc(property.id).collection('Rooms').doc(room.id).collection('BedSpaces').get();

          bedSpaceCount += bedSpaceQuery.docs.length;
        }
      }

      // Get active bookings
      final bookingQuery = await FirebaseFirestore.instance.collection('Bookings').where('landlordId', isEqualTo: user.uid).where('status', whereIn: ['confirmed', 'active']).get();

      int activeBookings = bookingQuery.docs.length;

      // Get earnings
      final earningsQuery = await FirebaseFirestore.instance.collection('Payments').where('landlordId', isEqualTo: user.uid).where('status', isEqualTo: 'completed').get();

      for (var payment in earningsQuery.docs) {
        totalEarnings += (payment.data()['amount'] as num).toDouble();
      }

      // Get unread messages
      final conversationsQuery = await FirebaseFirestore.instance.collection('Conversations').where('landlordId', isEqualTo: user.uid).get();

      int unreadMessages = 0;

      for (var conversation in conversationsQuery.docs) {
        // Check if the last message is from the student and unread
        if (conversation.data()['lastMessageFrom'] == 'student' && !(conversation.data()['landlordRead'] ?? true)) {
          unreadMessages++;
        }
      }

      setState(() {
        _stats = {'propertyCount': propertyCount, 'roomCount': roomCount, 'bedSpaceCount': bedSpaceCount, 'activeBookings': activeBookings, 'totalEarnings': totalEarnings, 'unreadMessages': unreadMessages};
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading landlord stats: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Initialize pages as empty containers - they will be populated in build
  final List<Widget> _pages = [
    Container(), // Dashboard
    Container(), // PropertiesScreen
    Container(), // LandlordBookingsScreen
    Container(), // LandlordMessagesScreen
    Container(), // LandlordProfileScreen
  ];

  @override
  Widget build(BuildContext context) {
    // Initialize the pages with proper context and IN THE CORRECT ORDER
    _pages[0] = _buildDashboardContent(); // Dashboard content
    _pages[1] = const PropertiesScreen(); // Properties screen should be index 1
    _pages[2] = const LandlordBookingsScreen(); // Bookings screen should be index 2
    _pages[3] = const LandlordMessagesScreen(); // Messages screen should be index 3
    _pages[4] = const LandlordProfileScreen(); // Profile screen should be index 4

    final authProvider = Provider.of<AppAuthProvider>(context);
    final userData = authProvider.userData;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Padding(
          padding: const EdgeInsets.only(left: 8.0), // optional: adjust for spacing
          child: Text(_getTitle(_currentIndex), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        ),
        centerTitle: false, // aligns title to the left
        actions: [
          if (_currentIndex == 0)
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
          BottomNavigationBarItem(icon: Icon(Icons.apartment_outlined), activeIcon: Icon(Icons.apartment), label: 'Properties'),
          BottomNavigationBarItem(icon: Icon(Icons.book_outlined), activeIcon: Icon(Icons.book), label: 'Bookings'),
          BottomNavigationBarItem(icon: Icon(Icons.message_outlined), activeIcon: Icon(Icons.message), label: 'Messages'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
      floatingActionButton:
          _currentIndex ==
                  1 // Show FAB only on Properties tab (index 1)
              ? FloatingActionButton.extended(
                backgroundColor: AppTheme.primaryColor,
                icon: const Icon(Icons.add),
                label: const Text('Add Property'), // <-- label shown on button
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => AddPropertyScreen())).then((_) {
                    _loadLandlordStats();
                  });
                },
              )
              : null,
    );
  }

  // Helper method to get title based on current index
  String _getTitle(int index) {
    switch (index) {
      case 0:
        return "Landlord Dashboard";
      case 1:
        return "My Properties";
      case 2:
        return "Bookings";
      case 3:
        return "Messages";
      case 4:
        return "My Profile";
      default:
        return "Landlord Dashboard";
    }
  }

  // Dashboard content method
  Widget _buildDashboardContent() {
    return RefreshIndicator(
      onRefresh: _loadLandlordStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            _buildWelcomeCard(),
            const SizedBox(height: 20),

            // Stats Section
            const Text("Your Dashboard", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
            const SizedBox(height: 12),

            // Stats Grid
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    _buildStatCard("Properties", _stats['propertyCount']?.toString() ?? "0", Icons.apartment, Colors.blue),
                    _buildStatCard("Bed Spaces", _stats['bedSpaceCount']?.toString() ?? "0", Icons.bed, Colors.purple),
                    _buildStatCard("Active Bookings", _stats['activeBookings']?.toString() ?? "0", Icons.book, Colors.orange),
                    _buildStatCard("Unread Messages", _stats['unreadMessages']?.toString() ?? "0", Icons.message, Colors.green),
                  ],
                ),
            const SizedBox(height: 20),

            // Quick Actions
            const Text("Quick Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildQuickActionButton("Add Property", Icons.add_home, AppTheme.primaryColor, () {
                  // Navigate to add property screen
                  Navigator.push(context, MaterialPageRoute(builder: (context) => AddPropertyScreen())).then((_) {
                    _loadLandlordStats();
                  });
                }),
                _buildQuickActionButton("View Bookings", Icons.calendar_today, Colors.orange, () {
                  setState(() {
                    _currentIndex = 2; // Navigate to bookings tab
                  });
                }),
                _buildQuickActionButton("Messages", Icons.message, Colors.green, () {
                  setState(() {
                    _currentIndex = 3; // Navigate to messages tab
                  });
                }),
              ],
            ),
            const SizedBox(height: 20),

            // Recent Activities
            const Text("Recent Activity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
            const SizedBox(height: 12),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : (_stats['activeBookings'] ?? 0) > 0
                ? _buildRecentActivitiesList()
                : _buildEmptyStateCard("No recent activities", "Your recent booking requests and messages will appear here.", Icons.history),
            const SizedBox(height: 20),

            // Earnings Overview
            const Text("Earnings Overview", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
            const SizedBox(height: 12),
            _buildEarningsCard(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // Welcome card widget
  Widget _buildWelcomeCard() {
    final authProvider = Provider.of<AppAuthProvider>(context);
    final userData = authProvider.userData;

    return Container(
      color: Colors.white,
      width: double.infinity,
      // padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar with M badge
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // Main avatar
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                    child: userData != null && userData['profileImageUrl'] != null ? ClipOval(child: Image.network(userData['profileImageUrl'], fit: BoxFit.cover, width: 72, height: 72)) : const Icon(Icons.person, size: 36, color: Colors.black87),
                  ),

                  // M badge
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: Center(child: Container(width: 24, height: 24, decoration: BoxDecoration(color: const Color(0xFFFFF3D6), borderRadius: BorderRadius.circular(4)), child: const Center(child: Text('M', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16))))),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Welcome text and verified badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text("Welcome, ${userData != null ? userData['displayName'] ?? 'Landlord' : 'Landlord'}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black), maxLines: 1, overflow: TextOverflow.ellipsis)),

              const SizedBox(width: 8),

              // Verified badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: userData != null && userData['isVerified'] == true ? const Color(0xFF77D175) : Colors.orange, borderRadius: BorderRadius.circular(20)),
                child: Text(userData != null && userData['isVerified'] == true ? "Verified Landlord" : "Verification Pending", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
              ),
            ],
          ),

          // Warning box for unverified users (keeping original functionality)
          if (userData != null && userData['isVerified'] != true) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.shade200)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Icon(Icons.info_outline, size: 16, color: Colors.orange.shade800), const SizedBox(width: 8), const Expanded(child: Text("Your account is pending verification", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor)))],
                  ),
                  const SizedBox(height: 4),
                  const Text("You can explore the app, but you won't be able to add properties or accept bookings until your account is verified by an administrator.", style: TextStyle(fontSize: 12, color: AppTheme.primaryColor)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
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

  Widget _buildQuickActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 28)),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivitiesList() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3, // Show max 3 items
        separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
        itemBuilder: (context, index) {
          return ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:
                    index == 0
                        ? Colors.blue.withOpacity(0.1)
                        : index == 1
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                index == 0
                    ? Icons.book
                    : index == 1
                    ? Icons.message
                    : Icons.payment,
                size: 20,
                color:
                    index == 0
                        ? Colors.blue
                        : index == 1
                        ? Colors.green
                        : Colors.orange,
              ),
            ),
            title: Text(
              index == 0
                  ? "New Booking Request"
                  : index == 1
                  ? "New Message"
                  : "Payment Received",
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
            ),
            subtitle: Text(
              index == 0
                  ? "Cozy Studio Near ZUT College"
                  : index == 1
                  ? "From: Emily Chibwabwe"
                  : "ZMW 650.00 - Bed Space Booking",
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            trailing: Text("2h ago", style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          );
        },
      ),
    );
  }

  Widget _buildEmptyStateCard(String title, String subtitle, IconData icon) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Total Earnings", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20)),
                  child: Row(children: [const Icon(Icons.arrow_upward, size: 14, color: Colors.green), const SizedBox(width: 4), Text("10%", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.green.shade700))]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text("ZMW ${_stats['totalEarnings']?.toStringAsFixed(2) ?? '0.00'}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [_buildEarningsStat("This Month", "ZMW ${(_stats['totalEarnings'] ?? 0) / 2}", Colors.blue), Container(height: 40, width: 1, color: Colors.grey.shade200), _buildEarningsStat("Last Month", "ZMW ${(_stats['totalEarnings'] ?? 0) / 4}", Colors.purple)],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _currentIndex = 2; // Navigate to earnings tab
                  });
                },
                style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
                child: const Text("View Full Earnings Report"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningsStat(String title, String value, Color color) {
    return Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [Text(title, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)), const SizedBox(height: 4), Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color))]));
  }
}
