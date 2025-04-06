import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:my_boarding_house_partner/utils/app_theme.dart';
import 'package:my_boarding_house_partner/models/message_model.dart';

class MessagingScreen extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String? studentAvatar;
  final String? propertyName;

  const MessagingScreen({Key? key, required this.studentId, required this.studentName, this.studentAvatar, this.propertyName}) : super(key: key);

  @override
  _MessagingScreenState createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  bool _isSending = false;
  String? _conversationId;
  List<Message> _messages = [];
  File? _imageToSend;
  bool _showAttachmentOptions = false;

  @override
  void initState() {
    super.initState();
    _setupConversation();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _setupConversation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final landlordId = _auth.currentUser?.uid;
      if (landlordId == null) return;

      // Check if conversation already exists
      final conversationsQuery = await _firestore.collection('Conversations').where('landlordId', isEqualTo: landlordId).where('studentId', isEqualTo: widget.studentId).limit(1).get();

      if (conversationsQuery.docs.isNotEmpty) {
        // Conversation exists
        final conversationDoc = conversationsQuery.docs.first;
        _conversationId = conversationDoc.id;

        // Mark messages as read
        await conversationDoc.reference.update({'landlordRead': true});
      } else {
        // Create new conversation
        final newConversationRef = await _firestore.collection('Conversations').add({
          'landlordId': landlordId,
          'studentId': widget.studentId,
          'lastMessage': '',
          'lastMessageFrom': '',
          'lastMessageAt': FieldValue.serverTimestamp(),
          'landlordRead': true,
          'studentRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          'propertyName': widget.propertyName,
        });

        _conversationId = newConversationRef.id;
      }

      // Set up message listener
      if (_conversationId != null) {
        _firestore.collection('Conversations').doc(_conversationId).collection('Messages').orderBy('createdAt', descending: true).snapshots().listen((snapshot) {
          if (mounted) {
            setState(() {
              _messages = snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList();
            });

            // Mark messages as read
            _markMessagesAsRead();
          }
        });
      }
    } catch (e) {
      print('Error setting up conversation: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading messages: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markMessagesAsRead() async {
    try {
      if (_conversationId == null) return;

      final landlordId = _auth.currentUser?.uid;
      if (landlordId == null) return;

      // Update conversation read status
      await _firestore.collection('Conversations').doc(_conversationId).update({'landlordRead': true});

      // Mark all messages from student as read
      final unreadMessagesQuery = await _firestore.collection('Conversations').doc(_conversationId).collection('Messages').where('senderId', isEqualTo: widget.studentId).where('isRead', isEqualTo: false).get();

      final batch = _firestore.batch();
      for (final doc in unreadMessagesQuery.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty && _imageToSend == null) return;

    setState(() {
      _isSending = true;
    });

    try {
      final landlordId = _auth.currentUser?.uid;
      if (landlordId == null || _conversationId == null) return;

      String? imageUrl;
      if (_imageToSend != null) {
        // Upload image to Firebase Storage
        final fileName = '${const Uuid().v4()}.jpg';
        final ref = FirebaseStorage.instance.ref().child('messages').child(_conversationId!).child(fileName);

        await ref.putFile(_imageToSend!);
        imageUrl = await ref.getDownloadURL();
      }

      // Clear text field
      _messageController.clear();
      setState(() {
        _imageToSend = null;
        _showAttachmentOptions = false;
      });

      // Add message to Firestore
      await _firestore.collection('Conversations').doc(_conversationId).collection('Messages').add({'text': message, 'imageUrl': imageUrl, 'senderId': landlordId, 'receiverId': widget.studentId, 'isRead': false, 'createdAt': FieldValue.serverTimestamp()});

      // Update conversation metadata
      await _firestore.collection('Conversations').doc(_conversationId).update({
        'lastMessage': imageUrl != null ? '[Image]' + (message.isNotEmpty ? ': $message' : '') : message,
        'lastMessageFrom': 'landlord',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'landlordRead': true,
        'studentRead': false,
      });

      // Scroll to bottom
      _scrollToBottom();
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sending message: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024, imageQuality: 80);

    if (image != null && mounted) {
      setState(() {
        _imageToSend = File(image.path);
        _showAttachmentOptions = false;
      });
    }
  }

  Future<void> _takePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera, maxWidth: 1024, maxHeight: 1024, imageQuality: 80);

    if (image != null && mounted) {
      setState(() {
        _imageToSend = File(image.path);
        _showAttachmentOptions = false;
      });
    }
  }

  void _toggleAttachmentOptions() {
    setState(() {
      _showAttachmentOptions = !_showAttachmentOptions;
    });
  }

  void _clearAttachment() {
    setState(() {
      _imageToSend = null;
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(radius: 16, backgroundColor: Colors.grey.shade200, backgroundImage: widget.studentAvatar != null ? NetworkImage(widget.studentAvatar!) : null, child: widget.studentAvatar == null ? const Icon(Icons.person, size: 20, color: Colors.grey) : null),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.studentName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (widget.propertyName != null) Text(widget.propertyName!, style: TextStyle(fontSize: 12, color: Colors.grey.shade700), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.primaryColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {
              // Make call action
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // Show more options
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final isMe = message.senderId == _auth.currentUser?.uid;
                        final showDate = index == _messages.length - 1 || _isDifferentDay(_messages[index].createdAt, _messages[index + 1].createdAt);

                        return Column(children: [if (showDate) _buildDateSeparator(message.createdAt), _buildMessageBubble(message, isMe)]);
                      },
                    ),
          ),

          // Image preview (if any)
          if (_imageToSend != null) _buildImagePreview(),

          // Attachment options
          if (_showAttachmentOptions) _buildAttachmentOptions(),

          // Message input
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No messages yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          Text('Start the conversation by sending a message', style: TextStyle(fontSize: 14, color: Colors.grey.shade600), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.shade300)),
          const SizedBox(width: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(16)), child: Text(_formatDateForSeparator(date), style: TextStyle(fontSize: 12, color: Colors.grey.shade700))),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: Colors.grey.shade300)),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isMe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Sender avatar (for student messages only)
          if (!isMe) CircleAvatar(radius: 14, backgroundColor: Colors.grey.shade200, backgroundImage: widget.studentAvatar != null ? NetworkImage(widget.studentAvatar!) : null, child: widget.studentAvatar == null ? const Icon(Icons.person, size: 16, color: Colors.grey) : null),

          // Message bubble
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
            margin: EdgeInsets.only(left: isMe ? 0 : 8, right: isMe ? 0 : 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: isMe ? AppTheme.primaryColor.withOpacity(0.1) : Colors.grey.shade100, borderRadius: BorderRadius.circular(16), border: Border.all(color: isMe ? AppTheme.primaryColor.withOpacity(0.3) : Colors.grey.shade300, width: 1)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image (if any)
                if (message.imageUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      message.imageUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(height: 150, width: 200, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)), child: const Center(child: CircularProgressIndicator()));
                      },
                      errorBuilder: (context, error, stackTrace) => Container(height: 150, width: 200, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)), child: const Center(child: Icon(Icons.error_outline, color: Colors.red))),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Message text
                if (message.text.isNotEmpty) Text(message.text, style: TextStyle(fontSize: 14, color: isMe ? AppTheme.primaryColor : AppTheme.primaryColor)),

                // Timestamp
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(DateFormat('HH:mm').format(message.createdAt), style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                    const SizedBox(width: 4),
                    if (isMe) Icon(message.isRead ? Icons.done_all : Icons.done, size: 12, color: message.isRead ? Colors.blue : Colors.grey.shade600),
                  ],
                ),
              ],
            ),
          ),

          // Sender avatar (for my messages only)
          if (isMe) Container(margin: const EdgeInsets.only(left: 8), width: 14, height: 14, decoration: BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle), child: const Icon(Icons.person, size: 10, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          Stack(
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(_imageToSend!, height: 80, width: 80, fit: BoxFit.cover)),
              Positioned(top: 0, right: 0, child: GestureDetector(onTap: _clearAttachment, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Icon(Icons.close, size: 14, color: Colors.white)))),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(child: Text('Ready to send this image', style: TextStyle(fontSize: 14, color: Colors.grey.shade700))),
        ],
      ),
    );
  }

  Widget _buildAttachmentOptions() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildAttachmentOption(icon: Icons.photo_library, label: 'Gallery', onTap: _pickImage),
          _buildAttachmentOption(icon: Icons.camera_alt, label: 'Camera', onTap: _takePhoto),
          _buildAttachmentOption(
            icon: Icons.insert_drive_file,
            label: 'Document',
            onTap: () {
              // Pick document action
              setState(() {
                _showAttachmentOptions = false;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentOption({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))]), child: Icon(icon, color: AppTheme.primaryColor, size: 24)),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, -2))]),
      child: Row(
        children: [
          // Attachment button
          IconButton(icon: Icon(Icons.attach_file, color: _showAttachmentOptions ? AppTheme.primaryColor : Colors.grey.shade700), onPressed: _toggleAttachmentOptions),

          // Message text field
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(hintText: 'Type a message...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none), filled: true, fillColor: Colors.grey.shade100, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          const SizedBox(width: 8),

          // Send button
          Container(
            decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
            child: IconButton(icon: _isSending ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send, color: Colors.white), onPressed: _isSending ? null : _sendMessage),
          ),
        ],
      ),
    );
  }

  bool _isDifferentDay(DateTime date1, DateTime date2) {
    return date1.year != date2.year || date1.month != date2.month || date1.day != date2.day;
  }

  String _formatDateForSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMMM d, yyyy').format(date);
    }
  }
}
