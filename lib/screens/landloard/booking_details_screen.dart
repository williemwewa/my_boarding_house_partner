import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:my_boarding_house_partner/screens/landloard/messaging_screen.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:my_boarding_house_partner/models/booking_model.dart';
import 'package:my_boarding_house_partner/providers/auth_provider.dart';

import 'package:my_boarding_house_partner/utils/app_theme.dart';

class BookingDetailsScreen extends StatefulWidget {
  final Booking booking;

  const BookingDetailsScreen({Key? key, required this.booking}) : super(key: key);

  @override
  _BookingDetailsScreenState createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  bool _isLoading = false;
  bool _isUpdating = false;
  final TextEditingController _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _showAcceptConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Booking'),
          content: const Text('Are you sure you want to confirm this booking? This will grant the student access to the bed space during the specified dates.'),
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
                _updateBookingStatus('confirmed');
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Confirm Booking'),
            ),
          ],
        );
      },
    );
  }

  void _showDeclineDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Decline Booking'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [const Text('Please provide a reason for declining this booking:'), const SizedBox(height: 16), TextField(controller: _reasonController, decoration: const InputDecoration(hintText: 'Enter reason here', border: OutlineInputBorder()), maxLines: 3)],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please provide a reason for declining'), backgroundColor: Colors.red));
                  return;
                }

                Navigator.of(context).pop();
                _updateBookingStatus('cancelled', reason: _reasonController.text.trim());
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Decline Booking'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateBookingStatus(String status, {String? reason}) async {
    setState(() {
      _isUpdating = true;
    });

    try {
      // Update booking document in Firestore
      await FirebaseFirestore.instance.collection('Bookings').doc(widget.booking.id).update({'status': status, 'updatedAt': FieldValue.serverTimestamp(), if (reason != null) 'cancellationReason': reason});

      // If booking is confirmed, also update the bed space status
      if (status == 'confirmed') {
        await FirebaseFirestore.instance.collection('Properties').doc(widget.booking.propertyId).collection('Rooms').doc(widget.booking.roomId).collection('BedSpaces').doc(widget.booking.bedSpaceId).update({'status': 'booked'});

        // Also update property occupancy count
        final propertyDoc = await FirebaseFirestore.instance.collection('Properties').doc(widget.booking.propertyId).get();

        if (propertyDoc.exists) {
          final currentOccupied = propertyDoc.data()?['occupiedBedSpaces'] ?? 0;

          await FirebaseFirestore.instance.collection('Properties').doc(widget.booking.propertyId).update({'occupiedBedSpaces': currentOccupied + 1});
        }
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(status == 'confirmed' ? 'Booking confirmed successfully!' : 'Booking declined successfully!'), backgroundColor: status == 'confirmed' ? Colors.green : Colors.red));

      // Return to previous screen
      Navigator.pop(context);
    } catch (e) {
      print('Error updating booking status: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating booking: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  void _startChat() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => MessagingScreen(studentId: widget.booking.studentId, studentName: widget.booking.studentName, studentAvatar: widget.booking.studentProfileImage, propertyName: widget.booking.propertyName)));
  }

  Future<void> _makePhoneCall() async {
    final Uri phoneUri = Uri(scheme: 'tel', path: widget.booking.studentPhoneNumber);

    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not call ${widget.booking.studentPhoneNumber}'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Booking Details', style: TextStyle(color: AppTheme.primaryColor)), backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: AppTheme.primaryColor)),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status card
                    _buildStatusCard(),
                    const SizedBox(height: 24),

                    // Booking details section
                    _buildSectionHeader('Booking Details'),
                    _buildBookingDetailsCard(),
                    const SizedBox(height: 24),

                    // Property and bed space section
                    _buildSectionHeader('Property & Bed Space'),
                    _buildPropertyCard(),
                    const SizedBox(height: 24),

                    // Student information section
                    _buildSectionHeader('Student Information'),
                    _buildStudentCard(),
                    const SizedBox(height: 24),

                    // Payment information section
                    _buildSectionHeader('Payment Information'),
                    _buildPaymentCard(),
                    const SizedBox(height: 32),

                    // Action buttons for pending bookings
                    if (widget.booking.status == 'pending') _buildActionButtons(),
                  ],
                ),
              ),
    );
  }

  Widget _buildStatusCard() {
    String statusMessage;
    Color statusColor;
    IconData statusIcon;

    switch (widget.booking.status) {
      case 'pending':
        statusMessage = 'This booking is waiting for your confirmation';
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case 'confirmed':
        statusMessage = 'This booking has been confirmed';
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'active':
        statusMessage = 'This booking is currently active';
        statusColor = Colors.blue;
        statusIcon = Icons.event_available;
        break;
      case 'completed':
        statusMessage = 'This booking has been completed';
        statusColor = Colors.purple;
        statusIcon = Icons.done_all;
        break;
      case 'cancelled':
        statusMessage = 'This booking has been cancelled';
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusMessage = 'Unknown status';
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: statusColor.withOpacity(0.3))),
        child: Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 36),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                        child: Text(widget.booking.status.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor)),
                      ),
                      const Spacer(),
                      Text('Booking ID: #${widget.booking.bookingId}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(statusMessage, style: const TextStyle(fontSize: 14)),
                  if (widget.booking.status == 'cancelled' && widget.booking.cancellationReason != null) ...[const SizedBox(height: 8), Text('Reason: ${widget.booking.cancellationReason}', style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.grey.shade700))],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingDetailsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date range
            Row(children: [Icon(Icons.date_range, size: 18, color: Colors.grey.shade700), const SizedBox(width: 8), const Text('Date Range:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))]),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Row(children: [_buildDateCard('Check-in', DateFormat('EEE, MMM d, yyyy').format(widget.booking.startDate), Icons.login), const SizedBox(width: 16), _buildDateCard('Check-out', DateFormat('EEE, MMM d, yyyy').format(widget.booking.endDate), Icons.logout)]),
            ),
            const SizedBox(height: 16),

            // Duration
            Row(children: [Icon(Icons.timelapse, size: 18, color: Colors.grey.shade700), const SizedBox(width: 8), Text('Duration: ${widget.booking.nights} ${widget.booking.nights == 1 ? 'night' : 'nights'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))]),
            const SizedBox(height: 16),

            // Booking date
            Row(children: [Icon(Icons.event_note, size: 18, color: Colors.grey.shade700), const SizedBox(width: 8), Text('Booked on: ${DateFormat('MMMM d, yyyy').format(widget.booking.createdAt)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))]),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Property name
            Row(children: [Icon(Icons.apartment, size: 18, color: Colors.grey.shade700), const SizedBox(width: 8), Expanded(child: Text(widget.booking.propertyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis))]),
            const SizedBox(height: 16),

            // Bed space
            Row(
              children: [
                Icon(Icons.bed, size: 18, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                const Text('Bed Space:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(width: 4),
                Expanded(child: Text(widget.booking.bedSpaceName, style: const TextStyle(fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),

            // View property button
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                // Navigate to property details
              },
              icon: const Icon(Icons.visibility),
              label: const Text('View Property Details'),
              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student name and profile
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: widget.booking.studentProfileImage != null ? NetworkImage(widget.booking.studentProfileImage!) : null,
                  child: widget.booking.studentProfileImage == null ? const Icon(Icons.person, size: 30, color: Colors.grey) : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.booking.studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(children: [Icon(Icons.phone, size: 14, color: Colors.grey.shade600), const SizedBox(width: 4), Text(widget.booking.studentPhoneNumber, style: TextStyle(fontSize: 14, color: Colors.grey.shade600))]),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Contact buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _makePhoneCall,
                    icon: const Icon(Icons.call),
                    label: const Text('Call'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.green, side: const BorderSide(color: Colors.green), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _startChat,
                    icon: const Icon(Icons.message),
                    label: const Text('Message'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryColor, side: BorderSide(color: AppTheme.primaryColor), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Payment status
            Row(
              children: [
                Icon(Icons.payment, size: 18, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                const Text('Payment Status:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: _getPaymentStatusColor(widget.booking.paymentStatus).withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                  child: Text(widget.booking.paymentStatus.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _getPaymentStatusColor(widget.booking.paymentStatus))),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Payment details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text('Subtotal (${widget.booking.nights} ${widget.booking.nights == 1 ? 'night' : 'nights'})', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)), Text('ZMW ${widget.booking.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14))],
            ),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Service Fee', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)), Text('ZMW ${widget.booking.serviceFee.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14))]),
            const Divider(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text('ZMW ${widget.booking.totalPrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),

            // Payment method
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.credit_card, size: 18, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                const Text('Payment Method:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(width: 8),
                Text('Mobile Money', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
              ],
            ),

            // Download receipt button
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                // Generate and download receipt
              },
              icon: const Icon(Icons.download),
              label: const Text('Download Receipt'),
              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return _isUpdating
        ? const Center(child: CircularProgressIndicator())
        : Row(
          children: [
            Expanded(child: ElevatedButton(onPressed: _showDeclineDialog, style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('Decline Booking'))),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _showAcceptConfirmationDialog,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: const Text('Accept Booking'),
              ),
            ),
          ],
        );
  }

  Widget _buildSectionHeader(String title) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Container(width: 40, height: 3, color: AppTheme.primaryColor), const SizedBox(height: 12)]);
  }

  Widget _buildDateCard(String label, String date, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, size: 16, color: AppTheme.primaryColor), const SizedBox(width: 4), Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700))]),
            const SizedBox(height: 4),
            Text(date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Color _getPaymentStatusColor(String status) {
    switch (status) {
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
