import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import 'package:my_boarding_house_partner/models/message_model.dart';

class MessagingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Get all conversations for current user (landlord or admin)
  Stream<List<Conversation>> getConversations() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    // Get user role from Firestore
    return _firestore.collection('Users').doc(user.uid).snapshots().asyncMap((userDoc) async {
      final userData = userDoc.data();
      final String role = userData?['role'] ?? 'landlord';

      if (role == 'admin') {
        // Admins can see all conversations
        final snapshot = await _firestore.collection('Conversations').orderBy('lastMessageAt', descending: true).get();

        return snapshot.docs.map((doc) => Conversation.fromFirestore(doc)).toList();
      } else {
        // Landlords see only their own conversations
        final snapshot = await _firestore.collection('Conversations').where('landlordId', isEqualTo: user.uid).orderBy('lastMessageAt', descending: true).get();

        return snapshot.docs.map((doc) => Conversation.fromFirestore(doc)).toList();
      }
    });
  }

  // Get messages for a specific conversation
  Stream<List<Message>> getMessages(String conversationId) {
    return _firestore.collection('Conversations').doc(conversationId).collection('Messages').orderBy('createdAt', descending: true).snapshots().map((snapshot) => snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList());
  }

  // Create a new conversation or find existing one
  Future<String> getConversationId(String studentId, String propertyName) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    // Check if conversation already exists
    final query = await _firestore.collection('Conversations').where('landlordId', isEqualTo: user.uid).where('studentId', isEqualTo: studentId).limit(1).get();

    if (query.docs.isNotEmpty) {
      return query.docs.first.id;
    }

    // Create new conversation
    final newConversationRef = await _firestore.collection('Conversations').add({
      'landlordId': user.uid,
      'studentId': studentId,
      'lastMessage': '',
      'lastMessageFrom': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'landlordRead': true,
      'studentRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      'propertyName': propertyName,
    });

    return newConversationRef.id;
  }

  // Send a text message
  Future<void> sendTextMessage(String conversationId, String receiverId, String text) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final messageData = {'text': text, 'imageUrl': null, 'senderId': user.uid, 'receiverId': receiverId, 'isRead': false, 'createdAt': FieldValue.serverTimestamp()};

    // Add message to conversation
    await _firestore.collection('Conversations').doc(conversationId).collection('Messages').add(messageData);

    // Update conversation metadata
    await _firestore.collection('Conversations').doc(conversationId).update({
      'lastMessage': text,
      'lastMessageFrom': 'landlord', // Assuming this service is used by landlords
      'lastMessageAt': FieldValue.serverTimestamp(),
      'landlordRead': true,
      'studentRead': false,
    });
  }

  // Send an image message
  Future<void> sendImageMessage(String conversationId, String receiverId, File image, String? caption) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    // Upload image to Firebase Storage
    final String fileName = const Uuid().v4() + '.jpg';
    final Reference ref = _storage.ref().child('conversations').child(conversationId).child(fileName);

    final UploadTask uploadTask = ref.putFile(image);
    final TaskSnapshot snapshot = await uploadTask.whenComplete(() => null);
    final String downloadUrl = await snapshot.ref.getDownloadURL();

    // Create message data
    final messageData = {'text': caption ?? '', 'imageUrl': downloadUrl, 'senderId': user.uid, 'receiverId': receiverId, 'isRead': false, 'createdAt': FieldValue.serverTimestamp()};

    // Add message to conversation
    await _firestore.collection('Conversations').doc(conversationId).collection('Messages').add(messageData);

    // Update conversation metadata
    await _firestore.collection('Conversations').doc(conversationId).update({
      'lastMessage': caption != null && caption.isNotEmpty ? '[Image]: $caption' : '[Image]',
      'lastMessageFrom': 'landlord', // Assuming this service is used by landlords
      'lastMessageAt': FieldValue.serverTimestamp(),
      'landlordRead': true,
      'studentRead': false,
    });
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String conversationId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    // Get user role
    final userDoc = await _firestore.collection('Users').doc(user.uid).get();

    final String role = userDoc.data()?['role'] ?? 'landlord';
    final String readField = role == 'landlord' ? 'landlordRead' : 'studentRead';

    // Update conversation read status
    await _firestore.collection('Conversations').doc(conversationId).update({readField: true});

    // Get unread messages
    final query = await _firestore.collection('Conversations').doc(conversationId).collection('Messages').where('receiverId', isEqualTo: user.uid).where('isRead', isEqualTo: false).get();

    // Mark all as read in a batch
    final batch = _firestore.batch();
    for (final doc in query.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
  }

  // Get unread messages count
  Future<int> getUnreadMessagesCount() async {
    final user = _auth.currentUser;
    if (user == null) {
      return 0;
    }

    // Get user role
    final userDoc = await _firestore.collection('Users').doc(user.uid).get();

    final String role = userDoc.data()?['role'] ?? 'landlord';

    // Find conversations with unread messages
    final query = await _firestore.collection('Conversations').where(role == 'landlord' ? 'landlordId' : 'studentId', isEqualTo: user.uid).where(role == 'landlord' ? 'landlordRead' : 'studentRead', isEqualTo: false).get();

    return query.docs.length;
  }

  // Delete a message (mark as deleted)
  Future<void> deleteMessage(String conversationId, String messageId) async {
    await _firestore.collection('Conversations').doc(conversationId).collection('Messages').doc(messageId).update({'isDeleted': true, 'text': 'This message was deleted', 'imageUrl': null});
  }
}
