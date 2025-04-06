import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:my_boarding_house_partner/screens/landloard/messaging_screen.dart';
import 'package:provider/provider.dart';

import 'package:my_boarding_house_partner/models/message_model.dart';
import 'package:my_boarding_house_partner/providers/auth_provider.dart';
// import 'package:my_boarding_house_partner/screens/landlord/messaging_screen.dart';
import 'package:my_boarding_house_partner/utils/app_theme.dart';
import 'package:my_boarding_house_partner/widgets/empty_state_widget.dart';

class LandlordMessagesScreen extends StatefulWidget {
  const LandlordMessagesScreen({Key? key}) : super(key: key);

  @override
  _LandlordMessagesScreenState createState() => _LandlordMessagesScreenState();
}

class _LandlordMessagesScreenState extends State<LandlordMessagesScreen> {
  bool _isLoading = false;
  List<Conversation> _conversations = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Set up real-time listener for conversations
      FirebaseFirestore.instance
          .collection('Conversations')
          .where('landlordId', isEqualTo: user.uid)
          .orderBy('lastMessageAt', descending: true)
          .snapshots()
          .listen(
            (snapshot) {
              if (mounted) {
                setState(() {
                  _conversations =
                      snapshot.docs.map((doc) => Conversation.fromFirestore(doc)).where((conversation) {
                        if (_searchQuery.isEmpty) return true;

                        // We need to fetch student names for searching
                        // This is a simplified approach for demo purposes
                        // In a real app, you'd store the student name in the conversation
                        // or implement a more efficient search mechanism
                        return conversation.lastMessage.toLowerCase().contains(_searchQuery.toLowerCase());
                      }).toList();
                  _isLoading = false;
                });
              }
            },
            onError: (error) {
              print('Error loading conversations: $error');
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });

                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading conversations: ${error.toString()}'), backgroundColor: Colors.red));
              }
            },
          );
    } catch (e) {
      print('Error setting up conversation listener: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading conversations: ${e.toString()}'), backgroundColor: Colors.red));
      }
    }
  }

  void _handleSearch(String query) {
    setState(() {
      _searchQuery = query;
    });
    // For demo we're just filtering in-memory
    // In a real app, you'd query Firestore with the search query
  }

  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _navigateToMessageScreen(Conversation conversation, String studentName, String? studentAvatar) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => MessagingScreen(studentId: conversation.studentId, studentName: studentName, studentAvatar: studentAvatar, propertyName: conversation.propertyName)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search messages',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: _clearSearch) : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: _handleSearch,
            ),
          ),

          // Conversations list
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _conversations.isEmpty
                    ? EmptyStateWidget(icon: Icons.message_outlined, title: 'No Messages', message: 'You don\'t have any conversations yet. Messages from students inquiring about your properties will appear here.')
                    : RefreshIndicator(
                      onRefresh: _loadConversations,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _conversations.length,
                        itemBuilder: (context, index) {
                          return FutureBuilder<Map<String, dynamic>>(
                            future: _getStudentInfo(_conversations[index].studentId),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return _buildConversationSkeleton();
                              }

                              final studentName = snapshot.data?['name'] ?? 'Unknown Student';
                              final studentAvatar = snapshot.data?['profileImageUrl'];

                              return _buildConversationTile(_conversations[index], studentName, studentAvatar);
                            },
                          );
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationTile(Conversation conversation, String studentName, String? studentAvatar) {
    final isUnread = !conversation.landlordRead;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: isUnread ? 2 : 1,
      child: InkWell(
        onTap: () => _navigateToMessageScreen(conversation, studentName, studentAvatar),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Student avatar
              Stack(
                children: [
                  CircleAvatar(radius: 24, backgroundColor: Colors.grey.shade200, backgroundImage: studentAvatar != null ? NetworkImage(studentAvatar) : null, child: studentAvatar == null ? const Icon(Icons.person, size: 30, color: Colors.grey) : null),
                  if (isUnread) Positioned(right: 0, top: 0, child: Container(width: 14, height: 14, decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
                ],
              ),
              const SizedBox(width: 16),

              // Conversation details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Student name and time
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(studentName, style: TextStyle(fontWeight: isUnread ? FontWeight.bold : FontWeight.w500, fontSize: 16, color: AppTheme.primaryColor), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        Text(_formatTime(conversation.lastMessageAt), style: TextStyle(fontSize: 12, color: isUnread ? AppTheme.primaryColor : Colors.grey.shade600, fontWeight: isUnread ? FontWeight.bold : FontWeight.normal)),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Property name (if available)
                    if (conversation.propertyName != null) ...[Text(conversation.propertyName!, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 4)],

                    // Last message
                    Row(
                      children: [
                        // Sender indicator
                        if (conversation.lastMessageFrom == 'landlord')
                          Container(
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                            child: const Text('You', style: TextStyle(fontSize: 10, color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                          ),

                        Expanded(child: Text(conversation.lastMessage, style: TextStyle(fontSize: 14, color: isUnread ? AppTheme.primaryColor : Colors.grey.shade600, fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConversationSkeleton() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Avatar skeleton
            CircleAvatar(radius: 24, backgroundColor: Colors.grey.shade300),
            const SizedBox(width: 16),

            // Content skeleton
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [Container(width: 120, height: 16, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))), Container(width: 40, height: 12, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)))],
                  ),
                  const SizedBox(height: 8),
                  Container(width: double.infinity, height: 14, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 8),
                  Container(width: 200, height: 14, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDate = DateTime(time.year, time.month, time.day);

    if (messageDate == today) {
      return DateFormat('HH:mm').format(time);
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(time).inDays < 7) {
      return DateFormat('EEE').format(time); // Day of week
    } else {
      return DateFormat('MMM d').format(time); // Jan 5
    }
  }

  Future<Map<String, dynamic>> _getStudentInfo(String studentId) async {
    try {
      // Get student info from Firestore
      final studentDoc = await FirebaseFirestore.instance.collection('Users').doc(studentId).get();

      if (studentDoc.exists && studentDoc.data() != null) {
        return {'name': studentDoc.data()?['displayName'] ?? 'Unknown Student', 'profileImageUrl': studentDoc.data()?['profileImageUrl']};
      }

      return {'name': 'Unknown Student', 'profileImageUrl': null};
    } catch (e) {
      print('Error getting student info: $e');
      return {'name': 'Unknown Student', 'profileImageUrl': null};
    }
  }
}
