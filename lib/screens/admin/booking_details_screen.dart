import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:my_boarding_house_partner/models/booking_model.dart';
import 'package:my_boarding_house_partner/models/property_model.dart';
import 'package:my_boarding_house_partner/models/user_model.dart';
import 'package:my_boarding_house_partner/utils/app_theme.dart';

class AdminBookingDetailsScreen extends StatefulWidget {
  final Booking booking;

  const AdminBookingDetailsScreen({Key? key, required this.booking}) : super(key: key);

  @override
  _AdminBookingDetailsScreenState createState() => _AdminBookingDetailsScreenState();
}

class _AdminBookingDetailsScreenState extends State<AdminBookingDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  bool _isUpdating = false;

  // Associated data
  Property? _property;
  AppUser? _student;
  AppUser? _landlord;
  Payment? _payment;

  // Controllers
  final TextEditingController _cancellationReasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadBookingDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cancellationReasonController.dispose();
    super.dispose();
  }

  Future<void> _loadBookingDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load property data
      final propertyDoc = await FirebaseFirestore.instance.collection('Properties').doc(widget.booking.propertyId).get();

      if (propertyDoc.exists) {
        _property = Property.fromFirestore(propertyDoc);
      }

      // Load student data
      final studentDoc = await FirebaseFirestore.instance.collection('Users').doc(widget.booking.studentId).get();

      if (studentDoc.exists) {
        _student = AppUser.fromFirestore(studentDoc);
      }

      // Load landlord data
      final landlordDoc = await FirebaseFirestore.instance.collection('Users').doc(widget.booking.landlordId).get();

      if (landlordDoc.exists) {
        _landlord = AppUser.fromFirestore(landlordDoc);
      }

      // Load payment data
      final paymentsQuery = await FirebaseFirestore.instance.collection('Payments').where('bookingId', isEqualTo: widget.booking.id).limit(1).get();

      if (paymentsQuery.docs.isNotEmpty) {
        _payment = Payment.fromFirestore(paymentsQuery.docs.first);
      }
    } catch (e) {
      print('Error loading booking details: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading booking details: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showStatusChangeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Change Booking Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select the new status for this booking:'),
              const SizedBox(height: 16),
              _buildStatusOption('pending', 'Pending'),
              _buildStatusOption('confirmed', 'Confirmed'),
              _buildStatusOption('active', 'Active'),
              _buildStatusOption('completed', 'Completed'),
              _buildStatusOption('cancelled', 'Cancelled'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusOption(String status, String label) {
    final isCurrentStatus = widget.booking.status == status;

    return ListTile(
      title: Text(label),
      leading: Icon(isCurrentStatus ? Icons.check_circle : Icons.radio_button_unchecked, color: isCurrentStatus ? Colors.green : Colors.grey),
      tileColor: isCurrentStatus ? Colors.green.withOpacity(0.1) : null,
      onTap:
          isCurrentStatus
              ? null
              : () {
                Navigator.of(context).pop();

                if (status == 'cancelled') {
                  _showCancellationReasonDialog();
                } else {
                  _updateBookingStatus(status);
                }
              },
    );
  }

  void _showCancellationReasonDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancellation Reason'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [const Text('Please provide a reason for cancellation:'), const SizedBox(height: 16), TextField(controller: _cancellationReasonController, decoration: const InputDecoration(hintText: 'Enter cancellation reason', border: OutlineInputBorder()), maxLines: 3)],
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
                if (_cancellationReasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please provide a cancellation reason'), backgroundColor: Colors.red));
                  return;
                }

                Navigator.of(context).pop();
                _updateBookingStatus('cancelled', reason: _cancellationReasonController.text.trim());
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Confirm Cancellation'),
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
      final updateData = {'status': status, 'updatedAt': FieldValue.serverTimestamp()};

      if (reason != null) {
        updateData['cancellationReason'] = reason;
      }

      // Update booking document
      await FirebaseFirestore.instance.collection('Bookings').doc(widget.booking.id).update(updateData);

      // If changing to cancelled, also handle refund logic if necessary
      if (status == 'cancelled' && _payment != null) {
        // For demo purposes, just mark the payment as refunded
        await FirebaseFirestore.instance.collection('Payments').doc(_payment!.id).update({'status': 'refunded'});
      }

      // Handle occupancy count updates for property if needed
      if (_property != null) {
        if (status == 'cancelled' && (widget.booking.status == 'confirmed' || widget.booking.status == 'active')) {
          // Decrement occupied count
          await FirebaseFirestore.instance.collection('Properties').doc(_property!.id).update({'occupiedBedSpaces': FieldValue.increment(-1)});
        } else if ((status == 'confirmed' || status == 'active') && widget.booking.status == 'cancelled') {
          // Increment occupied count
          await FirebaseFirestore.instance.collection('Properties').doc(_property!.id).update({'occupiedBedSpaces': FieldValue.increment(1)});
        }
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Booking status updated to ${status.toUpperCase()}'), backgroundColor: Colors.green));

      // Refresh the data
      _loadBookingDetails();
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

  Future<void> _contactUser(String userType, String method) async {
    final user = userType == 'student' ? _student : _landlord;
    if (user == null) return;

    if (method == 'phone' && user.phoneNumber != null) {
      final Uri phoneUri = Uri(scheme: 'tel', path: user.phoneNumber);

      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not call ${user.phoneNumber}'), backgroundColor: Colors.red));
      }
    } else if (method == 'email') {
      final Uri emailUri = Uri(scheme: 'mailto', path: user.email, query: 'subject=Regarding your booking #${widget.booking.bookingId}');

      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not email ${user.email}'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Details', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadBookingDetails)],
        bottom: TabBar(controller: _tabController, tabs: const [Tab(text: 'Overview'), Tab(text: 'Student'), Tab(text: 'Landlord')], indicatorColor: AppTheme.primaryColor, labelColor: AppTheme.primaryColor, unselectedLabelColor: Colors.grey),
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : TabBarView(controller: _tabController, children: [_buildOverviewTab(), _buildStudentTab(), _buildLandlordTab()]),
      bottomNavigationBar: _buildBottomButtons(),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Card
          _buildStatusCard(),
          const SizedBox(height: 24),

          // Booking Details Section
          _buildSectionHeader('Booking Details'),
          const SizedBox(height: 12),
          _buildBookingDetailsCard(),
          const SizedBox(height: 24),

          // Property Details Section
          _buildSectionHeader('Property & Bed Space'),
          const SizedBox(height: 12),
          _buildPropertyCard(),
          const SizedBox(height: 24),

          // Payment Details Section
          _buildSectionHeader('Payment Information'),
          const SizedBox(height: 12),
          _buildPaymentCard(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStudentTab() {
    if (_student == null) {
      return const Center(child: Text('Student information not available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Student Profile Card
          _buildUserProfileCard(_student!, 'Student'),
          const SizedBox(height: 24),

          // Student Contact Information
          _buildSectionHeader('Contact Information'),
          const SizedBox(height: 12),
          _buildContactInfoCard(_student!),
          const SizedBox(height: 24),

          // Booking History
          _buildSectionHeader('Booking History'),
          const SizedBox(height: 12),
          _buildBookingHistoryCard(_student!.id),
          const SizedBox(height: 24),

          // Contact Student Buttons
          _buildSectionHeader('Contact Student'),
          const SizedBox(height: 12),
          _buildContactButtons('student'),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildLandlordTab() {
    if (_landlord == null) {
      return const Center(child: Text('Landlord information not available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Landlord Profile Card
          _buildUserProfileCard(_landlord!, 'Landlord'),
          const SizedBox(height: 24),

          // Landlord Contact Information
          _buildSectionHeader('Contact Information'),
          const SizedBox(height: 12),
          _buildContactInfoCard(_landlord!),
          const SizedBox(height: 24),

          // Property Information
          _buildSectionHeader('Property Management'),
          const SizedBox(height: 12),
          _buildPropertyManagementCard(_landlord!.id),
          const SizedBox(height: 24),

          // Contact Landlord Buttons
          _buildSectionHeader('Contact Landlord'),
          const SizedBox(height: 12),
          _buildContactButtons('landlord'),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    String statusMessage;
    Color statusColor;
    IconData statusIcon;

    switch (widget.booking.status) {
      case 'pending':
        statusMessage = 'This booking is waiting for landlord confirmation';
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case 'confirmed':
        statusMessage = 'This booking has been confirmed by the landlord';
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                          OutlinedButton(
                            onPressed: _showStatusChangeDialog,
                            style: OutlinedButton.styleFrom(foregroundColor: statusColor, side: BorderSide(color: statusColor), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
                            child: const Text('Change Status'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(statusMessage, style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Divider(color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text('Booking ID: #${widget.booking.bookingId}', style: const TextStyle(fontWeight: FontWeight.bold)), Text('Created: ${DateFormat('MMM d, yyyy').format(widget.booking.createdAt)}', style: TextStyle(color: Colors.grey.shade700, fontSize: 12))],
            ),
            if (widget.booking.status == 'cancelled' && widget.booking.cancellationReason != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [const Text('Cancellation Reason:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), const SizedBox(height: 4), Text(widget.booking.cancellationReason!, style: TextStyle(fontSize: 14, color: Colors.red.shade800))],
                ),
              ),
            ],
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

            // People
            Row(children: [Icon(Icons.people, size: 18, color: Colors.grey.shade700), const SizedBox(width: 8), const Text('Parties:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))]),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [const Text('Student:', style: TextStyle(fontSize: 12, color: Colors.grey)), const SizedBox(height: 4), Text(_student?.displayName ?? widget.booking.studentName, style: const TextStyle(fontWeight: FontWeight.bold))],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [const Text('Landlord:', style: TextStyle(fontSize: 12, color: Colors.grey)), const SizedBox(height: 4), Text(_landlord?.displayName ?? 'Unknown Landlord', style: const TextStyle(fontWeight: FontWeight.bold))],
                    ),
                  ),
                ],
              ),
            ),
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
            Row(children: [Icon(Icons.apartment, size: 18, color: Colors.grey.shade700), const SizedBox(width: 8), Expanded(child: Text(_property?.name ?? widget.booking.propertyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis))]),
            if (_property != null) ...[const SizedBox(height: 8), Padding(padding: const EdgeInsets.only(left: 26), child: Text(_property!.address, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)))],
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

            if (_property != null) ...[
              const SizedBox(height: 16),
              // Property status
              Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.grey.shade700),
                  const SizedBox(width: 8),
                  const Text('Property Status:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: _property!.isVerified ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                    child: Text(_property!.isVerified ? 'Verified' : 'Pending Verification', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _property!.isVerified ? Colors.green : Colors.orange)),
                  ),
                ],
              ),
            ],

            // View property button
            const SizedBox(height: 16),
            if (_property != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Navigate to property details
                  },
                  icon: const Icon(Icons.visibility),
                  label: const Text('View Property Details'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                ),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [Icon(Icons.payment, size: 18, color: Colors.grey.shade700), const SizedBox(width: 8), const Text('Payment Status:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))]),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: _getPaymentStatusColor(_payment?.status ?? widget.booking.paymentStatus).withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                  child: Text((_payment?.status ?? widget.booking.paymentStatus).toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _getPaymentStatusColor(_payment?.status ?? widget.booking.paymentStatus))),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Payment method
            Row(children: [Icon(Icons.credit_card, size: 18, color: Colors.grey.shade700), const SizedBox(width: 8), Text('Payment Method: ${_payment?.paymentMethod ?? 'Mobile Money'}', style: const TextStyle(fontSize: 14))]),
            const SizedBox(height: 16),

            // Transaction ID
            if (_payment?.transactionId != null) Row(children: [Icon(Icons.receipt, size: 18, color: Colors.grey.shade700), const SizedBox(width: 8), Text('Transaction ID: ${_payment!.transactionId}', style: const TextStyle(fontSize: 14))]),

            const Divider(height: 32),

            // Payment breakdown
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text('Subtotal (${widget.booking.nights} ${widget.booking.nights == 1 ? 'night' : 'nights'})', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)), Text('ZMW ${widget.booking.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14))],
            ),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Service Fee', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)), Text('ZMW ${widget.booking.serviceFee.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14))]),
            const Divider(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text('ZMW ${widget.booking.totalPrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),

            // Download receipt button
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  // Generate and download receipt
                },
                icon: const Icon(Icons.download),
                label: const Text('Download Receipt'),
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserProfileCard(AppUser user, String role) {
    final Color roleColor = role == 'Student' ? Colors.green : Colors.blue;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(radius: 40, backgroundColor: Colors.grey.shade200, backgroundImage: user.profileImageUrl != null ? NetworkImage(user.profileImageUrl!) : null, child: user.profileImageUrl == null ? const Icon(Icons.person, size: 50, color: Colors.grey) : null),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.displayName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: roleColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: roleColor.withOpacity(0.5))),
                        child: Text(role.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: roleColor)),
                      ),
                      const SizedBox(width: 8),
                      if (role == 'Landlord')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: user.isVerified ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: user.isVerified ? Colors.green.withOpacity(0.5) : Colors.orange.withOpacity(0.5))),
                          child: Text(user.isVerified ? 'VERIFIED' : 'UNVERIFIED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: user.isVerified ? Colors.green : Colors.orange)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Joined: ${DateFormat('MMMM d, yyyy').format(user.createdAt)}', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactInfoCard(AppUser user) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoRow('Phone', user.phoneNumber ?? 'Not provided', Icons.phone),
            const Divider(height: 24),
            _buildInfoRow('Email', user.email, Icons.email),
            if (user.nrcNumber != null) ...[const Divider(height: 24), _buildInfoRow('NRC Number', user.nrcNumber!, Icons.credit_card)],
          ],
        ),
      ),
    );
  }

  Widget _buildBookingHistoryCard(String studentId) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('Bookings').where('studentId', isEqualTo: studentId).orderBy('createdAt', descending: true).limit(5).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())));
        }

        if (snapshot.hasError) {
          return Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.all(16), child: Center(child: Text('Error loading booking history: ${snapshot.error}'))));
        }

        final bookings = snapshot.data?.docs ?? [];

        if (bookings.isEmpty) {
          return Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('No booking history available'))));
        }

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Recent Bookings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), Text('Total: ${bookings.length}', style: TextStyle(fontSize: 14, color: Colors.grey.shade600))]),
                const SizedBox(height: 12),
                ...bookings.map((doc) {
                  final booking = Booking.fromFirestore(doc);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(booking.propertyName, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text('${DateFormat('MMM d, yyyy').format(booking.startDate)} - ${DateFormat('MMM d, yyyy').format(booking.endDate)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: _getStatusColor(booking.status).withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                              child: Text(booking.status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getStatusColor(booking.status))),
                            ),
                          ],
                        ),
                        const Divider(),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPropertyManagementCard(String landlordId) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('Properties').where('landlordId', isEqualTo: landlordId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())));
        }

        if (snapshot.hasError) {
          return Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.all(16), child: Center(child: Text('Error loading properties: ${snapshot.error}'))));
        }

        final properties = snapshot.data?.docs ?? [];

        if (properties.isEmpty) {
          return Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('No properties available'))));
        }

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Properties', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), Text('Total: ${properties.length}', style: TextStyle(fontSize: 14, color: Colors.grey.shade600))]),
                const SizedBox(height: 12),
                ...properties.map((doc) {
                  final property = Property.fromFirestore(doc);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(property.name, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text('${property.totalBedSpaces} bed spaces, ${property.occupiedBedSpaces} occupied', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: (property.isVerified ? Colors.green : Colors.orange).withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                              child: Text(property.isVerified ? 'VERIFIED' : 'PENDING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: property.isVerified ? Colors.green : Colors.orange)),
                            ),
                          ],
                        ),
                        const Divider(),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContactButtons(String userType) {
    final user = userType == 'student' ? _student : _landlord;
    if (user == null) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(child: OutlinedButton.icon(onPressed: user.phoneNumber != null ? () => _contactUser(userType, 'phone') : null, icon: const Icon(Icons.phone), label: const Text('Call'), style: OutlinedButton.styleFrom(foregroundColor: Colors.green, side: const BorderSide(color: Colors.green)))),
            const SizedBox(width: 16),
            Expanded(child: OutlinedButton.icon(onPressed: () => _contactUser(userType, 'email'), icon: const Icon(Icons.email), label: const Text('Email'), style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryColor, side: BorderSide(color: AppTheme.primaryColor)))),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
      child: Row(
        children: [
          Expanded(
            child:
                _isUpdating
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(onPressed: widget.booking.status == 'cancelled' ? null : () => _showCancellationReasonDialog(), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 16)), child: const Text('Cancel Booking')),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Container(width: 40, height: 3, color: AppTheme.primaryColor)]);
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

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: AppTheme.primaryColor, size: 24)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)), const SizedBox(height: 4), Text(value, style: const TextStyle(fontSize: 16))])),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getPaymentStatusColor(String status) {
    switch (status.toLowerCase()) {
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
