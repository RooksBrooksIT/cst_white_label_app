import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:intl/intl.dart';

class SiteWeeklyFinancialReport2 extends StatelessWidget {
  final Map<String, dynamic>? siteDetails;
  final String? paymentPeriod;

  // Updated color scheme with navy blue (#0b3470)
  final Color primaryColor = const Color(0xFF0b3470);
  final Color primaryLightColor = const Color(0xFF1e4a8e);
  final Color accentColor = const Color(0xFF4285F4);
  final Color successColor = const Color(0xFF34A853);
  final Color warningColor = const Color(0xFFFBBC05);
  final Color dangerColor = const Color(0xFFEA4335);
  final Color backgroundColor = const Color(0xFFF8F9FA);
  final Color cardColor = Colors.white;
  final Color textColor = const Color(0xFF2c3e50);
  final Color secondaryTextColor = const Color(0xFF7f8c8d);

  const SiteWeeklyFinancialReport2({
    super.key,
    this.siteDetails,
    this.paymentPeriod,
  });

  @override
  Widget build(BuildContext context) {
    final String? siteId = siteDetails != null
        ? (siteDetails!['siteId'] ?? siteDetails!['site'])?.toString()
        : null;
    final String? paymentPeriod = this.paymentPeriod;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          "Weekly Financial Report",
          style: TextStyle(fontWeight: FontWeight.w600, ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (siteId == null ||
                    siteId.isEmpty ||
                    paymentPeriod == null ||
                    paymentPeriod.isEmpty)
                  Center(child: CircularProgressIndicator(color: primaryColor))
                else
                  StreamBuilder<QuerySnapshot>(
                    stream: FirestoreService
                        .getCollection('siteSupervisorPayments')
                        .where('siteId', isEqualTo: siteId)
                        .where('paymentPeriod', isEqualTo: paymentPeriod)
                        .snapshots()
                        .timeout(
                          const Duration(seconds: 15),
                          onTimeout: (controller) {
                            print('Stream timeout for payments');
                            controller.close();
                          },
                        ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: CircularProgressIndicator(color: primaryColor),
                        );
                      }
                      if (snapshot.hasError) {
                        print('Stream error: ${snapshot.error}');
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: dangerColor.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Error Loading Data',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: dangerColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Please try again later',
                                style: TextStyle(color: secondaryTextColor),
                              ),
                            ],
                          ),
                        );
                      }
                      if (!snapshot.hasData) {
                        return Center(
                          child: CircularProgressIndicator(color: primaryColor),
                        );
                      }
                      if (snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long,
                                size: 64,
                                color: primaryColor.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No Payment Records',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: primaryColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No payment records found for this period',
                                style: TextStyle(color: secondaryTextColor),
                              ),
                            ],
                          ),
                        );
                      }

                      final doc = snapshot.data!.docs.first;
                      final summary = doc.data() as Map<String, dynamic>;
                      final List<dynamic> payments =
                          (summary['payments'] ?? []) as List<dynamic>;
                      // Sort payments by paymentDate ascending
                      payments.sort(
                        (a, b) => (a['paymentDate'] ?? '').compareTo(
                          b['paymentDate'] ?? '',
                        ),
                      );
                      final List<String> paymentDates = payments
                          .map((p) => p['paymentDate']?.toString() ?? '')
                          .where((date) => date.isNotEmpty)
                          .toSet()
                          .toList();

                      // Calculate previous week's paymentPeriod
                      String? prevPaymentPeriod;
                      if (summary['paymentPeriod'] != null) {
                        final period = summary['paymentPeriod'] as String;
                        final reg = RegExp(r'^(\d{4})_(\w{3})_Week(\d+)$');
                        final match = reg.firstMatch(period);
                        if (match != null) {
                          final year = int.parse(match.group(1)!);
                          final month = match.group(2)!;
                          final week = int.parse(match.group(3)!);
                          if (week > 1) {
                            prevPaymentPeriod =
                                '${year}_${month}_Week${week - 1}';
                          }
                        }
                      }

                      return FutureBuilder<Map<String, dynamic>>(
                        future: _fetchOpeningBalance(
                          siteId,
                          prevPaymentPeriod,
                          paymentDates,
                        ),
                        builder: (context, openingSnapshot) {
                          final openingBalance =
                              openingSnapshot.data?['openingBalance'] ?? 0;
                          final expensesByDate =
                              openingSnapshot.data?['expensesByDate'] ??
                              <String, num>{};

                          // Calculate totals from payments array
                          int totalPayment = 0;
                          int totalExpenses = 0;
                          for (var p in payments) {
                            final String date = p['paymentDate'] ?? '';
                            final int paymentAmount = (p['paymentAmount'] ?? 0)
                                .toInt();
                            final int expensesAmount =
                                expensesByDate.containsKey(date)
                                ? (expensesByDate[date] ?? 0).toInt()
                                : 0;
                            totalPayment += paymentAmount;
                            totalExpenses += expensesAmount;
                          }
                          int totalAmount =
                              (openingBalance as int) + totalPayment;
                          int totalNet = totalAmount - totalExpenses;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Site Info Card
                              _buildSiteInfoCard(summary),
                              const SizedBox(height: 16),

                              // Opening Balance Card
                              _buildSummaryCard(
                                'Opening Balance',
                                openingBalance,
                                Icons.account_balance,
                                primaryLightColor,
                              ),
                              const SizedBox(height: 12),

                              // Summary Cards
                              _buildSummaryCard(
                                'Total Payment',
                                totalPayment,
                                Icons.payment_outlined,
                                primaryColor,
                              ),
                              const SizedBox(height: 12),
                              _buildSummaryCard(
                                'Total Amount',
                                totalAmount,
                                Icons.attach_money_outlined,
                                accentColor,
                              ),
                              const SizedBox(height: 12),
                              _buildSummaryCard(
                                'Total Expenses',
                                totalExpenses,
                                Icons.receipt_outlined,
                                warningColor,
                              ),
                              const SizedBox(height: 12),
                              _buildSummaryCard(
                                'Net Amount',
                                totalNet,
                                Icons.account_balance_wallet_outlined,
                                totalNet >= 0 ? successColor : dangerColor,
                              ),
                              const SizedBox(height: 24),

                              // Table Title
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                ),
                                child: Text(
                                  'Daily Breakdown',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Data Table
                              _buildPaymentsDataTable(
                                payments,
                                expensesByDate,
                                openingBalance,
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSiteInfoCard(Map<String, dynamic> summary) {
    return Card(
      elevation: 2,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Site Information',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.location_on_outlined,
              'Site ID',
              summary['siteId'] ?? '',
            ),
            _buildInfoRow(
              Icons.person_outline,
              'Supervisor',
              summary['supervisorName'] ?? '',
            ),
            _buildInfoRow(
              Icons.work_outline,
              'Project',
              summary['projectName'] ?? '',
            ),
            _buildInfoRow(
              Icons.layers_outlined,
              'Stage',
              summary['projectStage'] ?? '',
            ),
            _buildInfoRow(
              Icons.calendar_today_outlined,
              'Period',
              summary['paymentPeriod'] ?? '',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: secondaryTextColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 13, color: secondaryTextColor),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsDataTable(
    List<dynamic> payments,
    Map<String, num> expensesByDate,
    int openingBalance,
  ) {
    // Calculate totals
    int totalPayment = payments.fold<int>(
      0,
      (sum, p) => sum + ((p['paymentAmount'] ?? 0) as int),
    );
    int totalExpenses = payments.fold<int>(0, (sum, p) {
      final String date = p['paymentDate'] ?? '';
      return sum +
          (expensesByDate.containsKey(date)
              ? (expensesByDate[date] ?? 0).toInt()
              : 0);
    });
    int totalAmount = openingBalance + totalPayment;
    int totalNet = totalAmount - totalExpenses;

    return Card(
      elevation: 2,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 24,
          horizontalMargin: 16,
          headingRowHeight: 48,
          dataRowHeight: 48,
          headingTextStyle: TextStyle(
            fontWeight: FontWeight.bold,
            
            fontSize: 14,
          ),
          headingRowColor: WidgetStateProperty.all(primaryColor),
          columns: [
            DataColumn(label: Text('Date'), numeric: false),
            DataColumn(label: Text('Payment'), numeric: true),
            DataColumn(label: Text('Expenses'), numeric: true),
            DataColumn(label: Text('Net'), numeric: true),
          ],
          rows: [
            // Opening balance row
            DataRow(
              cells: [
                DataCell(Text('Opening', style: TextStyle(color: textColor))),
                const DataCell(Text('-')),
                const DataCell(Text('-')),
                DataCell(
                  Text(
                    NumberFormat.currency(
                      locale: 'en_IN',
                      symbol: '₹',
                    ).format(openingBalance),
                    style: TextStyle(
                      color: primaryLightColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            // Payment rows
            ...payments.map((p) {
              final String date = p['paymentDate'] ?? '';
              final int paymentAmount = (p['paymentAmount'] ?? 0).toInt();
              final int expensesAmount = expensesByDate.containsKey(date)
                  ? (expensesByDate[date] ?? 0).toInt()
                  : 0;
              final int netAmount = paymentAmount - expensesAmount;

              return DataRow(
                cells: [
                  DataCell(Text(date, style: TextStyle(color: textColor))),
                  DataCell(
                    Text(
                      NumberFormat.currency(
                        locale: 'en_IN',
                        symbol: '₹',
                      ).format(paymentAmount),
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      NumberFormat.currency(
                        locale: 'en_IN',
                        symbol: '₹',
                      ).format(expensesAmount),
                      style: TextStyle(
                        color: warningColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      NumberFormat.currency(
                        locale: 'en_IN',
                        symbol: '₹',
                      ).format(netAmount),
                      style: TextStyle(
                        color: netAmount >= 0 ? successColor : dangerColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              );
            }),
            // Total row
            DataRow(
              color: WidgetStateProperty.all(backgroundColor),
              cells: [
                DataCell(
                  Text(
                    'TOTAL',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    NumberFormat.currency(
                      locale: 'en_IN',
                      symbol: '₹',
                    ).format(totalPayment),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    NumberFormat.currency(
                      locale: 'en_IN',
                      symbol: '₹',
                    ).format(totalExpenses),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: warningColor,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    NumberFormat.currency(
                      locale: 'en_IN',
                      symbol: '₹',
                    ).format(totalNet),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: totalNet >= 0 ? successColor : dangerColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    int amount,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: secondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    NumberFormat.currency(
                      locale: 'en_IN',
                      symbol: '₹',
                    ).format(amount),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color,
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

  Future<Map<String, dynamic>> _fetchOpeningBalance(
    String siteId,
    String? prevPaymentPeriod,
    List<String> paymentDates,
  ) async {
    int openingBalance = 0;
    if (prevPaymentPeriod != null) {
      // Opening balance of current week should be the NET amount of previous week
      openingBalance = await _computeNetForPeriod(
        siteId,
        prevPaymentPeriod,
        {},
      );
    }
    // Fetch expenses for current week
    final expensesByDate = await _fetchExpenses(siteId, paymentDates);
    return {'openingBalance': openingBalance, 'expensesByDate': expensesByDate};
  }

  // Recursively compute the NET amount for a given payment period so that
  // the next week's opening balance equals this net amount.
  Future<int> _computeNetForPeriod(
    String siteId,
    String paymentPeriod,
    Map<String, int> netCache,
  ) async {
    if (netCache.containsKey(paymentPeriod)) return netCache[paymentPeriod]!;

    // Fetch payments for this period
    final snap = await FirestoreService
        .getCollection('siteSupervisorPayments')
        .where('siteId', isEqualTo: siteId)
        .where('paymentPeriod', isEqualTo: paymentPeriod)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      netCache[paymentPeriod] = 0;
      return 0;
    }

    final data = snap.docs.first.data();
    final List<dynamic> payments = (data['payments'] ?? []) as List<dynamic>;

    // Build date list for expenses lookup
    final List<String> dates = payments
        .map((p) => p['paymentDate']?.toString() ?? '')
        .where((d) => d.isNotEmpty)
        .toList();

    // Determine previous payment period
    final prev = _getPreviousPaymentPeriod(paymentPeriod);

    int opening = 0;
    if (prev != null) {
      opening = await _computeNetForPeriod(siteId, prev, netCache);
    }

    // Fetch expenses for this period
    final expensesByDate = await _fetchExpenses(siteId, dates);

    int totalPayment = 0;
    int totalExpenses = 0;
    for (var p in payments) {
      final String date = p['paymentDate'] ?? '';
      final int paymentAmount = (p['paymentAmount'] ?? 0).toInt();
      final int expensesAmount = expensesByDate.containsKey(date)
          ? (expensesByDate[date] ?? 0).toInt()
          : 0;
      totalPayment += paymentAmount;
      totalExpenses += expensesAmount;
    }

    final int totalAmount = opening + totalPayment;
    final int net = totalAmount - totalExpenses;

    netCache[paymentPeriod] = net;
    return net;
  }

  String? _getPreviousPaymentPeriod(String period) {
    final reg = RegExp(r'^(\d{4})_(\w{3})_Week(\d+)$');
    final match = reg.firstMatch(period);
    if (match == null) return null;
    final year = match.group(1)!;
    final month = match.group(2)!;
    final week = int.parse(match.group(3)!);
    if (week <= 1) return null;
    return '${year}_${month}_Week${week - 1}';
  }

  Future<Map<String, num>> _fetchExpenses(
    String siteId,
    List<String> dates,
  ) async {
    Map<String, num> result = {};

    try {
      QuerySnapshot entrySnap = await FirestoreService
          .getCollection('siteSupervisorEntries')
          .where('siteId', isEqualTo: siteId)
          .get();

      for (var doc in entrySnap.docs) {
        final data = doc.data() as Map<String, dynamic>;

        try {
          String entryDate = '';
          if (data['date'] is String) {
            entryDate = DateFormat(
              'yyyy-MM-dd',
            ).format(DateTime.parse(data['date'] as String));
          } else if (data['date'] is Timestamp) {
            entryDate = DateFormat(
              'yyyy-MM-dd',
            ).format((data['date'] as Timestamp).toDate());
          }

          if (entryDate.isNotEmpty && dates.contains(entryDate)) {
            num totalAmount = (data['totalAmount'] ?? 0) as num;

            if (result.containsKey(entryDate)) {
              result[entryDate] = result[entryDate]! + totalAmount;
            } else {
              result[entryDate] = totalAmount;
            }
          }
        } catch (e) {
          debugPrint('Error processing document ${doc.id}: $e');
          continue;
        }
      }
    } catch (e) {
      debugPrint('Error fetching expenses: $e');
    }

    for (var date in dates) {
      if (!result.containsKey(date)) {
        result[date] = 0;
      }
    }

    return result;
  }
}
