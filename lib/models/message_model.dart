import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String text;
  final String? imageUrl;
  final String senderId;
  final String receiverId;
  final bool isRead;
  final DateTime createdAt;

  Message({required this.id, required this.text, this.imageUrl, required this.senderId, required this.receiverId, required this.isRead, required this.createdAt});

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Handle Timestamp
    Timestamp createdTimestamp = data['createdAt'] as Timestamp? ?? Timestamp.now();

    return Message(id: doc.id, text: data['text'] ?? '', imageUrl: data['imageUrl'], senderId: data['senderId'] ?? '', receiverId: data['receiverId'] ?? '', isRead: data['isRead'] ?? false, createdAt: createdTimestamp.toDate());
  }

  Map<String, dynamic> toMap() {
    return {'text': text, 'imageUrl': imageUrl, 'senderId': senderId, 'receiverId': receiverId, 'isRead': isRead, 'createdAt': FieldValue.serverTimestamp()};
  }
}

class Conversation {
  final String id;
  final String landlordId;
  final String studentId;
  final String lastMessage;
  final String lastMessageFrom; // 'landlord' or 'student'
  final DateTime lastMessageAt;
  final bool landlordRead;
  final bool studentRead;
  final DateTime createdAt;
  final String? propertyName;

  Conversation({required this.id, required this.landlordId, required this.studentId, required this.lastMessage, required this.lastMessageFrom, required this.lastMessageAt, required this.landlordRead, required this.studentRead, required this.createdAt, this.propertyName});

  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Handle Timestamps
    Timestamp lastMessageTimestamp = data['lastMessageAt'] as Timestamp? ?? Timestamp.now();
    Timestamp createdTimestamp = data['createdAt'] as Timestamp? ?? Timestamp.now();

    return Conversation(
      id: doc.id,
      landlordId: data['landlordId'] ?? '',
      studentId: data['studentId'] ?? '',
      lastMessage: data['lastMessage'] ?? '',
      lastMessageFrom: data['lastMessageFrom'] ?? '',
      lastMessageAt: lastMessageTimestamp.toDate(),
      landlordRead: data['landlordRead'] ?? true,
      studentRead: data['studentRead'] ?? true,
      createdAt: createdTimestamp.toDate(),
      propertyName: data['propertyName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {'landlordId': landlordId, 'studentId': studentId, 'lastMessage': lastMessage, 'lastMessageFrom': lastMessageFrom, 'lastMessageAt': FieldValue.serverTimestamp(), 'landlordRead': landlordRead, 'studentRead': studentRead, 'createdAt': createdAt, 'propertyName': propertyName};
  }

  // Check if a new message is from the landlord
  bool isFromLandlord(String userId) {
    return userId == landlordId;
  }
}
