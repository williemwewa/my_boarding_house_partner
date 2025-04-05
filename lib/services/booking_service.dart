import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'package:my_boarding_house_partner/models/booking_model.dart';

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get all bookings for a landlord
  Future<List<Booking>> getLandlordBookings({String? status}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    Query query = _firestore.collection('Bookings').where('landlordId', isEqualTo: user.uid);

    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    final snapshot = await query.get();

    return snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();
  }

  // Get all bookings for a specific property
  Future<List<Booking>> getPropertyBookings(String propertyId, {String? status}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    Query query = _firestore.collection('Bookings').where('propertyId', isEqualTo: propertyId);

    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    final snapshot = await query.get();

    return snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();
  }

  // Get all bookings for a specific bed space
  Future<List<Booking>> getBedSpaceBookings(String bedSpaceId, {String? status}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    Query query = _firestore.collection('Bookings').where('bedSpaceId', isEqualTo: bedSpaceId);

    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    final snapshot = await query.get();

    return snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();
  }

  // Get a single booking by ID
  Future<Booking?> getBookingById(String bookingId) async {
    final doc = await _firestore.collection('Bookings').doc(bookingId).get();

    if (doc.exists) {
      return Booking.fromFirestore(doc);
    }

    return null;
  }

  // Accept a booking
  Future<void> acceptBooking(String bookingId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    // Get the booking details first
    final bookingDoc = await _firestore.collection('Bookings').doc(bookingId).get();
    if (!bookingDoc.exists) {
      throw Exception('Booking not found');
    }

    final booking = Booking.fromFirestore(bookingDoc);

    // Make sure the booking belongs to this landlord
    if (booking.landlordId != user.uid) {
      throw Exception('Not authorized to modify this booking');
    }

    // Make sure the booking is in pending status
    if (booking.status != 'pending') {
      throw Exception('Booking is not in pending status');
    }

    // Update booking status
    await _firestore.collection('Bookings').doc(bookingId).update({'status': 'confirmed', 'updatedAt': FieldValue.serverTimestamp()});

    // Update the bed space status to booked
    await _firestore.collection('Properties').doc(booking.propertyId).collection('Rooms').doc(booking.roomId).collection('BedSpaces').doc(booking.bedSpaceId).update({'status': 'booked'});

    // Update property occupancy count
    final propertyDoc = await _firestore.collection('Properties').doc(booking.propertyId).get();

    if (propertyDoc.exists) {
      final currentOccupied = propertyDoc.data()?['occupiedBedSpaces'] ?? 0;

      await _firestore.collection('Properties').doc(booking.propertyId).update({'occupiedBedSpaces': currentOccupied + 1});
    }
  }

  // Reject a booking with a reason
  Future<void> rejectBooking(String bookingId, String reason) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    // Get the booking details first
    final bookingDoc = await _firestore.collection('Bookings').doc(bookingId).get();
    if (!bookingDoc.exists) {
      throw Exception('Booking not found');
    }

    final booking = Booking.fromFirestore(bookingDoc);

    // Make sure the booking belongs to this landlord
    if (booking.landlordId != user.uid) {
      throw Exception('Not authorized to modify this booking');
    }

    // Make sure the booking is in pending status
    if (booking.status != 'pending') {
      throw Exception('Booking is not in pending status');
    }

    // Update booking status
    await _firestore.collection('Bookings').doc(bookingId).update({'status': 'cancelled', 'cancellationReason': reason, 'updatedAt': FieldValue.serverTimestamp()});
  }

  // Get landlord's earnings for a specific period
  Future<Map<String, dynamic>> getLandlordEarnings({DateTime? startDate, DateTime? endDate}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    Query query = _firestore.collection('Payments').where('landlordId', isEqualTo: user.uid).where('status', isEqualTo: 'completed');

    if (startDate != null) {
      query = query.where('createdAt', isGreaterThanOrEqualTo: startDate);
    }

    if (endDate != null) {
      query = query.where('createdAt', isLessThanOrEqualTo: endDate);
    }

    final snapshot = await query.get();

    // Calculate total earnings
    double totalEarnings = 0;
    for (var doc in snapshot.docs) {
      totalEarnings = 0; //+= (doc.data()['amount'] as num).toDouble();
    }

    // Get monthly breakdown
    Map<String, double> monthlyEarnings = {};

    for (var doc in snapshot.docs) {
      final payment = Payment.fromFirestore(doc);
      final monthYear = DateFormat('MMM yyyy').format(payment.createdAt);

      if (monthlyEarnings.containsKey(monthYear)) {
        monthlyEarnings[monthYear] = monthlyEarnings[monthYear]! + payment.amount;
      } else {
        monthlyEarnings[monthYear] = payment.amount;
      }
    }

    return {'totalEarnings': totalEarnings, 'paymentsCount': snapshot.docs.length, 'monthlyEarnings': monthlyEarnings};
  }

  // Get bookings stats for a landlord
  Future<Map<String, dynamic>> getBookingsStats() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final snapshot = await _firestore.collection('Bookings').where('landlordId', isEqualTo: user.uid).get();

    int totalBookings = snapshot.docs.length;
    int pendingBookings = 0;
    int confirmedBookings = 0;
    int activeBookings = 0;
    int completedBookings = 0;
    int cancelledBookings = 0;

    for (var doc in snapshot.docs) {
      final status = doc.data()['status'] as String?;

      switch (status) {
        case 'pending':
          pendingBookings++;
          break;
        case 'confirmed':
          confirmedBookings++;
          break;
        case 'active':
          activeBookings++;
          break;
        case 'completed':
          completedBookings++;
          break;
        case 'cancelled':
          cancelledBookings++;
          break;
      }
    }

    return {'totalBookings': totalBookings, 'pendingBookings': pendingBookings, 'confirmedBookings': confirmedBookings, 'activeBookings': activeBookings, 'completedBookings': completedBookings, 'cancelledBookings': cancelledBookings};
  }
}
