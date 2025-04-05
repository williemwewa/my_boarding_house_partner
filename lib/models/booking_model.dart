import 'package:cloud_firestore/cloud_firestore.dart';

class Booking {
  final String id;
  final String bookingId; // Formatted reference number
  final String propertyId;
  final String roomId;
  final String bedSpaceId;
  final String studentId;
  final String landlordId;
  final String propertyName;
  final String bedSpaceName;
  final String studentName;
  final String studentPhoneNumber;
  final String? studentProfileImage;
  final DateTime startDate;
  final DateTime endDate;
  final double totalPrice;
  final double serviceFee;
  final String status; // pending, confirmed, active, completed, cancelled
  final String paymentStatus; // pending, completed, refunded, failed
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? cancellationReason;

  Booking({
    required this.id,
    required this.bookingId,
    required this.propertyId,
    required this.roomId,
    required this.bedSpaceId,
    required this.studentId,
    required this.landlordId,
    required this.propertyName,
    required this.bedSpaceName,
    required this.studentName,
    required this.studentPhoneNumber,
    this.studentProfileImage,
    required this.startDate,
    required this.endDate,
    required this.totalPrice,
    required this.serviceFee,
    required this.status,
    required this.paymentStatus,
    required this.createdAt,
    this.updatedAt,
    this.cancellationReason,
  });

  // Calculate the number of nights for the booking
  int get nights {
    return endDate.difference(startDate).inDays;
  }

  // Calculate the subtotal (without service fee)
  double get subtotal {
    return totalPrice - serviceFee;
  }

  // Check if the booking can be cancelled
  bool get canBeCancelled {
    // Can only cancel if status is pending or confirmed (not active, completed, or already cancelled)
    return status == 'pending' || status == 'confirmed';
  }

  // Check if the booking can be modified
  bool get canBeModified {
    // Can only modify if status is pending or confirmed (not active, completed, or cancelled)
    return status == 'pending' || status == 'confirmed';
  }

  // Factory method to create a Booking from a Firestore document
  factory Booking.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Handle Timestamps
    Timestamp startTimestamp = data['startDate'] as Timestamp;
    Timestamp endTimestamp = data['endDate'] as Timestamp;
    Timestamp createdTimestamp = data['createdAt'] as Timestamp;
    Timestamp? updatedTimestamp = data['updatedAt'] as Timestamp?;

    return Booking(
      id: doc.id,
      bookingId: data['bookingId'] ?? doc.id.substring(0, 8).toUpperCase(),
      propertyId: data['propertyId'] ?? '',
      roomId: data['roomId'] ?? '',
      bedSpaceId: data['bedSpaceId'] ?? '',
      studentId: data['studentId'] ?? '',
      landlordId: data['landlordId'] ?? '',
      propertyName: data['propertyName'] ?? 'Unknown Property',
      bedSpaceName: data['bedSpaceName'] ?? 'Unknown Bed Space',
      studentName: data['studentName'] ?? 'Unknown Student',
      studentPhoneNumber: data['studentPhoneNumber'] ?? '',
      studentProfileImage: data['studentProfileImage'],
      startDate: startTimestamp.toDate(),
      endDate: endTimestamp.toDate(),
      totalPrice: (data['totalPrice'] ?? 0).toDouble(),
      serviceFee: (data['serviceFee'] ?? 0).toDouble(),
      status: data['status'] ?? 'pending',
      paymentStatus: data['paymentStatus'] ?? 'pending',
      createdAt: createdTimestamp.toDate(),
      updatedAt: updatedTimestamp?.toDate(),
      cancellationReason: data['cancellationReason'],
    );
  }

  // Convert booking to map
  Map<String, dynamic> toMap() {
    return {
      'bookingId': bookingId,
      'propertyId': propertyId,
      'roomId': roomId,
      'bedSpaceId': bedSpaceId,
      'studentId': studentId,
      'landlordId': landlordId,
      'propertyName': propertyName,
      'bedSpaceName': bedSpaceName,
      'studentName': studentName,
      'studentPhoneNumber': studentPhoneNumber,
      'studentProfileImage': studentProfileImage,
      'startDate': startDate,
      'endDate': endDate,
      'totalPrice': totalPrice,
      'serviceFee': serviceFee,
      'status': status,
      'paymentStatus': paymentStatus,
      'updatedAt': FieldValue.serverTimestamp(),
      'cancellationReason': cancellationReason,
    };
  }

  // Create a copy with updated fields
  Booking copyWith({String? status, String? paymentStatus, DateTime? updatedAt, String? cancellationReason}) {
    return Booking(
      id: this.id,
      bookingId: this.bookingId,
      propertyId: this.propertyId,
      roomId: this.roomId,
      bedSpaceId: this.bedSpaceId,
      studentId: this.studentId,
      landlordId: this.landlordId,
      propertyName: this.propertyName,
      bedSpaceName: this.bedSpaceName,
      studentName: this.studentName,
      studentPhoneNumber: this.studentPhoneNumber,
      studentProfileImage: this.studentProfileImage,
      startDate: this.startDate,
      endDate: this.endDate,
      totalPrice: this.totalPrice,
      serviceFee: this.serviceFee,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      createdAt: this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt ?? DateTime.now(),
      cancellationReason: cancellationReason ?? this.cancellationReason,
    );
  }
}

class Payment {
  final String id;
  final String bookingId;
  final String studentId;
  final String landlordId;
  final double amount;
  final String status; // pending, completed, refunded, failed
  final String paymentMethod; // card, mobile money, etc.
  final String? transactionId;
  final DateTime createdAt;

  Payment({required this.id, required this.bookingId, required this.studentId, required this.landlordId, required this.amount, required this.status, required this.paymentMethod, this.transactionId, required this.createdAt});

  factory Payment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Handle Timestamp
    Timestamp createdTimestamp = data['createdAt'] as Timestamp;

    return Payment(
      id: doc.id,
      bookingId: data['bookingId'] ?? '',
      studentId: data['studentId'] ?? '',
      landlordId: data['landlordId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      status: data['status'] ?? 'pending',
      paymentMethod: data['paymentMethod'] ?? 'Unknown',
      transactionId: data['transactionId'],
      createdAt: createdTimestamp.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'bookingId': bookingId, 'studentId': studentId, 'landlordId': landlordId, 'amount': amount, 'status': status, 'paymentMethod': paymentMethod, 'transactionId': transactionId, 'createdAt': FieldValue.serverTimestamp()};
  }
}
