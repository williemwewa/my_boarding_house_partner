import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:my_boarding_house_partner/providers/auth_provider.dart';
import 'package:my_boarding_house_partner/utils/app_theme.dart';
import 'package:my_boarding_house_partner/models/booking_model.dart';
import 'package:my_boarding_house_partner/widgets/empty_state_widget.dart';

class LandlordEarningsScreen extends StatefulWidget {
  const LandlordEarningsScreen({Key? key}) : super(key: key);

  @override
  _LandlordEarningsScreenState createState() => _LandlordEarningsScreenState();
}

class _LandlordEarningsScreenState extends State<LandlordEarningsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  List<Payment> _payments = [];

  // Stats and summaries
  double _totalEarnings = 0;
  double _monthlyEarnings = 0;
  double _weeklyEarnings = 0;
  Map<String, double> _earningsByMonth = {};
  Map<String, double> _earningsByProperty = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadEarningsData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadEarningsData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Load all payments for this landlord
      final paymentsQuery = await FirebaseFirestore.instance.collection('Payments').where('landlordId', isEqualTo: user.uid).where('status', isEqualTo: 'completed').orderBy('createdAt', descending: true).get();

      final List<Payment> payments = paymentsQuery.docs.map((doc) => Payment.fromFirestore(doc)).toList();

      // Calculate stats
      final now = DateTime.now();
      final oneWeekAgo = now.subtract(const Duration(days: 7));
      final oneMonthAgo = DateTime(now.year, now.month - 1, now.day);

      double totalEarnings = 0;
      double monthlyEarnings = 0;
      double weeklyEarnings = 0;

      Map<String, double> earningsByMonth = {};
      Map<String, double> earningsByProperty = {};

      for (final payment in payments) {
        // Total earnings
        totalEarnings += payment.amount;

        // Period-based earnings
        if (payment.createdAt.isAfter(oneMonthAgo)) {
          monthlyEarnings += payment.amount;

          if (payment.createdAt.isAfter(oneWeekAgo)) {
            weeklyEarnings += payment.amount;
          }
        }

        // Group by month
        final monthYear = DateFormat('MMM yyyy').format(payment.createdAt);
        earningsByMonth[monthYear] = (earningsByMonth[monthYear] ?? 0) + payment.amount;

        // Get property info for payment
        final bookingDoc = await FirebaseFirestore.instance.collection('Bookings').doc(payment.bookingId).get();

        if (bookingDoc.exists) {
          final propertyName = bookingDoc.data()?['propertyName'] ?? 'Unknown Property';
          earningsByProperty[propertyName] = (earningsByProperty[propertyName] ?? 0) + payment.amount;
        }
      }

      setState(() {
        _payments = payments;
        _totalEarnings = totalEarnings;
        _monthlyEarnings = monthlyEarnings;
        _weeklyEarnings = weeklyEarnings;
        _earningsByMonth = earningsByMonth;
        _earningsByProperty = earningsByProperty;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading earnings data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load earnings data: ${e.toString()}'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // Earnings summary section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 5, offset: const Offset(0, 2))]),
                    child: Column(
                      children: [
                        // Total earnings
                        Text('ZMW ${_totalEarnings.toStringAsFixed(2)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                        const Text('Total Earnings', style: TextStyle(fontSize: 14, color: Colors.grey)),
                        const SizedBox(height: 20),

                        // Period stats
                        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_buildEarningPeriodCard('This Week', _weeklyEarnings), _buildEarningPeriodCard('This Month', _monthlyEarnings)]),
                      ],
                    ),
                  ),

                  // Tab bar
                  Container(color: Colors.white, child: TabBar(controller: _tabController, tabs: const [Tab(text: 'Analytics'), Tab(text: 'Transactions')], indicatorColor: AppTheme.primaryColor, labelColor: AppTheme.primaryColor, unselectedLabelColor: Colors.grey)),

                  // Tab views
                  Expanded(child: TabBarView(controller: _tabController, children: [_buildAnalyticsTab(), _buildTransactionsTab()])),
                ],
              ),
    );
  }

  Widget _buildAnalyticsTab() {
    return _earningsByMonth.isEmpty
        ? EmptyStateWidget(icon: Icons.show_chart, title: 'No Earnings Data', message: 'You don\'t have any earnings data yet. Once you start receiving payments, your earnings analytics will appear here.')
        : SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Monthly earnings chart
              _buildSectionHeader('Monthly Earnings'),
              const SizedBox(height: 16),
              _buildMonthlyEarningsChart(),
              const SizedBox(height: 24),

              // Properties earnings chart
              _buildSectionHeader('Earnings by Property'),
              const SizedBox(height: 16),
              _buildPropertiesEarningsChart(),
              const SizedBox(height: 16),
            ],
          ),
        );
  }

  Widget _buildTransactionsTab() {
    return _payments.isEmpty
        ? EmptyStateWidget(icon: Icons.receipt_long, title: 'No Transactions', message: 'You don\'t have any completed transactions yet. Once payments are processed, they will appear here.')
        : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _payments.length,
          itemBuilder: (context, index) {
            return _buildTransactionCard(_payments[index]);
          },
        );
  }

  Widget _buildEarningPeriodCard(String period, double amount) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
      child: Column(children: [Text('ZMW ${amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), Text(period, style: TextStyle(fontSize: 12, color: Colors.grey.shade700))]),
    );
  }

  Widget _buildMonthlyEarningsChart() {
    // Sort months chronologically
    final sortedMonths =
        _earningsByMonth.keys.toList()..sort((a, b) {
          final DateFormat format = DateFormat('MMM yyyy');
          final DateTime dateA = format.parse(a);
          final DateTime dateB = format.parse(b);
          return dateA.compareTo(dateB);
        });

    // Keep last 6 months for better visibility
    if (sortedMonths.length > 6) {
      sortedMonths.removeRange(0, sortedMonths.length - 6);
    }

    // Prepare bar chart data
    final barGroups =
        sortedMonths
            .asMap()
            .map((index, month) {
              return MapEntry(index, BarChartGroupData(x: index, barRods: [BarChartRodData(toY: _earningsByMonth[month]!, color: AppTheme.primaryColor, width: 16, borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)))]));
            })
            .values
            .toList();

    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 5, offset: const Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Last ${sortedMonths.length} Months', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
          const SizedBox(height: 16),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _earningsByMonth.values.reduce((a, b) => a > b ? a : b) * 1.2,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    // tooltipBgColor: Colors.grey.shade800,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem('ZMW ${rod.toY.toStringAsFixed(2)}\n', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), children: [TextSpan(text: sortedMonths[group.x.toInt()], style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.normal))]);
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value < 0 || value >= sortedMonths.length) {
                          return const SizedBox();
                        }

                        final parts = sortedMonths[value.toInt()].split(' ');
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            parts[0], // Only show month abbreviation
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 60,
                      getTitlesWidget: (value, meta) {
                        return Padding(padding: const EdgeInsets.only(right: 8), child: Text('ZMW ${value.toInt()}', style: TextStyle(color: Colors.grey.shade700, fontSize: 10)));
                      },
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: _earningsByMonth.values.reduce((a, b) => a > b ? a : b) / 5),
                borderData: FlBorderData(show: false),
                barGroups: barGroups,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertiesEarningsChart() {
    if (_earningsByProperty.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 5, offset: const Offset(0, 2))]),
        child: const Center(child: Text('No property earnings data available')),
      );
    }

    // Sort properties by earnings (descending)
    final sortedProperties = _earningsByProperty.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    // Calculate percentages
    final total = _earningsByProperty.values.reduce((a, b) => a + b);
    final List<PieChartSectionData> sections = [];

    // Define colors for sections
    final List<Color> sectionColors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.teal, Colors.red, Colors.amber];

    // Create pie sections
    for (int i = 0; i < sortedProperties.length; i++) {
      final property = sortedProperties[i];
      final percentage = (property.value / total) * 100;

      sections.add(PieChartSectionData(color: sectionColors[i % sectionColors.length], value: property.value, title: '${percentage.toStringAsFixed(1)}%', radius: 100, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)));
    }

    return Container(
      height: 400,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 5, offset: const Offset(0, 2))]),
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 40,
                sectionsSpace: 2,
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    // Handle touch response if needed
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Legend
          Expanded(
            child: ListView.builder(
              itemCount: sortedProperties.length,
              itemBuilder: (context, index) {
                final property = sortedProperties[index];
                final percentage = (property.value / total) * 100;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(width: 16, height: 16, decoration: BoxDecoration(color: sectionColors[index % sectionColors.length], shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(property.key, style: const TextStyle(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Text('ZMW ${property.value.toStringAsFixed(2)} (${percentage.toStringAsFixed(1)}%)', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Payment payment) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('Bookings').doc(payment.bookingId).get(),
      builder: (context, snapshot) {
        String propertyName = 'Loading...';
        String bedSpaceName = '';

        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            propertyName = data['propertyName'] ?? 'Unknown Property';
            bedSpaceName = data['bedSpaceName'] ?? 'Unknown Bed Space';
          } else {
            propertyName = 'Unknown Property';
          }
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Amount and date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('ZMW ${payment.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.green.withOpacity(0.5))),
                      child: const Text('COMPLETED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Property and bed space
                Text(propertyName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                if (bedSpaceName.isNotEmpty) Text('Bed Space: $bedSpaceName', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                const SizedBox(height: 12),

                // Payment details
                Row(
                  children: [
                    // Payment method
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [Text('Payment Method', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)), const SizedBox(height: 4), Text(payment.paymentMethod, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))],
                      ),
                    ),

                    // Transaction ID
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [Text('Transaction ID', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)), const SizedBox(height: 4), Text(payment.transactionId ?? 'N/A', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Payment date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade700), const SizedBox(width: 4), Text(DateFormat('MMM d, yyyy').format(payment.createdAt), style: TextStyle(fontSize: 12, color: Colors.grey.shade700))]),
                    Text(DateFormat('h:mm a').format(payment.createdAt), style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Container(width: 40, height: 3, color: AppTheme.primaryColor)]);
  }
}
