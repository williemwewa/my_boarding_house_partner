import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:my_boarding_house_partner/screens/admin/user_details_screen.dart';
import 'package:my_boarding_house_partner/utils/app_theme.dart';
import 'package:my_boarding_house_partner/models/user_model.dart';
import 'package:my_boarding_house_partner/widgets/empty_state_widget.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({Key? key}) : super(key: key);

  @override
  _UserManagementScreenState createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<AppUser> _users = [];
  List<AppUser> _filteredUsers = [];

  final TextEditingController _searchController = TextEditingController();
  String _filterRole = 'All';
  bool _showUnverifiedOnly = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadUsers();
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
        _filterRole = 'All';
        _showUnverifiedOnly = false;
        _searchController.clear();
      });
      _loadUsers();
    }
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      QuerySnapshot usersSnapshot;

      // Create base query based on tab index
      Query query = FirebaseFirestore.instance.collection('Users');

      if (_tabController.index == 0) {
        // All Users tab - no extra filter
      } else if (_tabController.index == 1) {
        // Landlords tab
        query = query.where('role', isEqualTo: 'landlord');
      } else if (_tabController.index == 2) {
        // Students tab
        query = query.where('role', isEqualTo: 'student');
      }

      // Apply verification filter if needed
      if (_showUnverifiedOnly) {
        query = query.where('isVerified', isEqualTo: false);
      }

      // If there's a role filter other than "All" and we're on the All Users tab
      if (_filterRole != 'All' && _tabController.index == 0) {
        query = query.where('role', isEqualTo: _filterRole.toLowerCase());
      }

      // Execute the query
      usersSnapshot = await query.get();

      // Parse the results
      List<AppUser> fetchedUsers = usersSnapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList();

      // Apply search filter
      _applySearchFilter(fetchedUsers, _searchController.text);

      // Sort users: most recent first
      _filteredUsers.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      print('Error loading users: $e');
      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load users: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _applySearchFilter(List<AppUser> users, String query) {
    if (query.isEmpty) {
      setState(() {
        _users = users;
        _filteredUsers = users;
      });
      return;
    }

    final searchLower = query.toLowerCase();
    final filtered =
        users.where((user) {
          return user.displayName.toLowerCase().contains(searchLower) || user.email.toLowerCase().contains(searchLower) || (user.phoneNumber?.toLowerCase().contains(searchLower) ?? false);
        }).toList();

    setState(() {
      _users = users;
      _filteredUsers = filtered;
    });
  }

  void _handleSearch(String query) {
    _applySearchFilter(_users, query);
  }

  void _clearSearch() {
    _searchController.clear();
    _applySearchFilter(_users, '');
  }

  void _navigateToUserDetails(AppUser user) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => UserDetailsScreen(user: user))).then((_) => _loadUsers()); // Refresh when returning
  }

  void _toggleVerificationDialog(AppUser user) {
    final bool newVerificationStatus = !user.isVerified;
    final String actionText = newVerificationStatus ? 'Verify' : 'Unverify';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$actionText User'),
          content: Text('Are you sure you want to ${actionText.toLowerCase()} ${user.displayName}?'),
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
                _updateUserVerification(user, newVerificationStatus);
              },
              style: ElevatedButton.styleFrom(backgroundColor: newVerificationStatus ? Colors.green : Colors.orange),
              child: Text(actionText),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateUserVerification(AppUser user, bool isVerified) async {
    try {
      // Update user verification status
      await FirebaseFirestore.instance.collection('Users').doc(user.id).update({'isVerified': isVerified, 'updatedAt': FieldValue.serverTimestamp()});

      // Refresh the user list
      _loadUsers();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isVerified ? '${user.displayName} has been verified successfully!' : '${user.displayName} verification has been revoked.'), backgroundColor: isVerified ? Colors.green : Colors.orange));
    } catch (e) {
      print('Error updating user verification: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating user: ${e.toString()}'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Tab bar
          Container(color: Colors.white, child: TabBar(controller: _tabController, tabs: const [Tab(text: 'All Users'), Tab(text: 'Landlords'), Tab(text: 'Students')], indicatorColor: AppTheme.primaryColor, labelColor: AppTheme.primaryColor, unselectedLabelColor: Colors.grey)),

          // Search and filter bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name, email or phone',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: _clearSearch) : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: _handleSearch,
                ),

                const SizedBox(height: 12),

                // Filter options
                if (_tabController.index == 0) // Show role filter only on All Users tab
                  SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [const Text('Filter by:'), const SizedBox(width: 8), _buildFilterChip('All'), _buildFilterChip('Landlord'), _buildFilterChip('Student'), _buildFilterChip('Admin')])),

                // Show unverified only checkbox
                if (_tabController.index != 2) // Not on Students tab
                  Row(
                    children: [
                      Checkbox(
                        value: _showUnverifiedOnly,
                        activeColor: AppTheme.primaryColor,
                        onChanged: (value) {
                          setState(() {
                            _showUnverifiedOnly = value ?? false;
                          });
                          _loadUsers();
                        },
                      ),
                      const Text('Show unverified users only'),
                    ],
                  ),
              ],
            ),
          ),

          // User list
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredUsers.isEmpty
                    ? EmptyStateWidget(icon: Icons.people_outline, title: 'No Users Found', message: 'No users match your current filters or search criteria.')
                    : RefreshIndicator(
                      onRefresh: _loadUsers,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          return _buildUserCard(_filteredUsers[index]);
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String role) {
    final isSelected = _filterRole == role;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(role),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _filterRole = role;
          });
          _loadUsers();
        },
        backgroundColor: Colors.grey.shade200,
        selectedColor: AppTheme.primaryColor.withOpacity(0.2),
        checkmarkColor: AppTheme.primaryColor,
        labelStyle: TextStyle(color: isSelected ? AppTheme.primaryColor : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
      ),
    );
  }

  Widget _buildUserCard(AppUser user) {
    final Color roleColor = _getRoleColor(user.role);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: () => _navigateToUserDetails(user),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User name and role
              Row(
                children: [
                  CircleAvatar(radius: 24, backgroundColor: Colors.grey.shade200, backgroundImage: user.profileImageUrl != null ? NetworkImage(user.profileImageUrl!) : null, child: user.profileImageUrl == null ? const Icon(Icons.person, size: 30, color: Colors.grey) : null),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            // Role badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: roleColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: roleColor.withOpacity(0.5))),
                              child: Text(user.role.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: roleColor)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(user.email, style: TextStyle(fontSize: 14, color: Colors.grey.shade700), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // User details
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: _buildUserDetail(Icons.phone, 'Phone', user.phoneNumber ?? 'Not provided')), Expanded(child: _buildUserDetail(Icons.calendar_today, 'Joined', DateFormat('MMM d, yyyy').format(user.createdAt)))]),

              // Verification status
              if (user.role == 'landlord') ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Verification status
                    Row(
                      children: [
                        Icon(user.isVerified ? Icons.verified_user : Icons.pending, size: 16, color: user.isVerified ? Colors.green : Colors.orange),
                        const SizedBox(width: 4),
                        Text(user.isVerified ? 'Verified' : 'Verification Pending', style: TextStyle(fontSize: 14, color: user.isVerified ? Colors.green : Colors.orange, fontWeight: FontWeight.w500)),
                      ],
                    ),

                    // Verify/Unverify button
                    OutlinedButton(
                      onPressed: () => _toggleVerificationDialog(user),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: user.isVerified ? Colors.orange : Colors.green,
                        side: BorderSide(color: user.isVerified ? Colors.orange : Colors.green),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      ),
                      child: Text(user.isVerified ? 'Unverify' : 'Verify'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserDetail(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Row(children: [Icon(icon, size: 14, color: Colors.grey.shade700), const SizedBox(width: 4), Expanded(child: Text(value, style: const TextStyle(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis))]),
      ],
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'landlord':
        return Colors.blue;
      case 'student':
        return Colors.green;
      case 'admin':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
