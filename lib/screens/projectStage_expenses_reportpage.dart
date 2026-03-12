import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ProjectStageExpensesReportPage extends StatefulWidget {
  final String siteId;
  final String projectStage;
  final DateTime fromDate;
  final DateTime toDate;

  const ProjectStageExpensesReportPage({
    super.key,
    required this.siteId,
    required this.projectStage,
    required this.fromDate,
    required this.toDate,
  });

  @override
  State<ProjectStageExpensesReportPage> createState() =>
      _ProjectStageExpensesReportPageState();
}

class _ProjectStageExpensesReportPageState
    extends State<ProjectStageExpensesReportPage>
    with SingleTickerProviderStateMixin {
  static const Color primaryColor = Color(0xFF0b3470);
  static const Color accentColor = Color(0xFF4a7cda);
  static const Color backgroundColor = Color(0xFFf8f9fa);
  static const Color textColor = Color(0xFF2c3e50);
  static const Color cardColor = Colors.white;
  static const Color successColor = Color(0xFF2e7d32);
  static const Color warningColor = Color(0xFFed6c02);

  double supervisorTotal = 0;
  double managerTotal = 0;
  double organizationTotal = 0;
  double contractorTotal = 0;
  double incentiveTotal = 0;

  bool isLoading = true;

  List<Map<String, dynamic>> supervisorEntries = [];
  List<Map<String, dynamic>> managerEntries = [];
  List<Map<String, dynamic>> organizationEntries = [];
  List<Map<String, dynamic>> contractorEntries = [];
  List<Map<String, dynamic>> incentiveEntries = [];

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _loadReport();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// ✅ Safely convert dynamic value into double
  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  Future<void> _loadReport() async {
    setState(() => isLoading = true);

    supervisorEntries = await _fetchExpenses(
      collection: "siteSupervisorEntries",
      dateField: "date",
      amountField: "totalAmount",
    );
    supervisorTotal =
        supervisorEntries.fold(0, (sum, e) => sum + (e['amount'] ?? 0));

    managerEntries = await _fetchExpenses(
      collection: "managerEntries",
      dateField: "entryDate",
      amountField: "totalAmount",
    );
    managerTotal = managerEntries.fold(0, (sum, e) => sum + (e['amount'] ?? 0));

    organizationEntries = await _fetchExpenses(
      collection: "organizationEntries",
      dateField: "entryDate",
      amountField: "totalAmount",
    );
    organizationTotal =
        organizationEntries.fold(0, (sum, e) => sum + (e['amount'] ?? 0));

    contractorEntries = await _fetchExpenses(
      collection: "contractorEntries",
      dateField: "date",
      amountField: "totalAmount",
    );
    contractorTotal =
        contractorEntries.fold(0, (sum, e) => sum + (e['amount'] ?? 0));

    incentiveEntries = await _fetchExpenses(
      collection: "siteSupervisorIncentives",
      dateField: "updatedAt",
      amountField: "incentiveAmount",
    );
    incentiveTotal =
        incentiveEntries.fold(0, (sum, e) => sum + (e['amount'] ?? 0));

    setState(() => isLoading = false);
    _animationController.forward();
  }

  /// ✅ Firestore query + filtering
  Future<List<Map<String, dynamic>>> _fetchExpenses({
    required String collection,
    required String dateField,
    required String amountField,
  }) async {
    final snapshot = await FirebaseFirestore.instance
        .collection(collection)
        .where("siteId", isEqualTo: widget.siteId)
        .where("projectStage", isEqualTo: widget.projectStage)
        .get();

    List<Map<String, dynamic>> results = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();

      DateTime? entryDate;
      final rawDate = data[dateField];

      // ✅ handle both Timestamp and String
      if (rawDate is Timestamp) {
        entryDate = rawDate.toDate();
      } else if (rawDate is String) {
        try {
          entryDate = DateTime.parse(rawDate);
        } catch (e) {
          continue;
        }
      }

      if (entryDate == null) continue;

      // ✅ filter within date range
      if (entryDate
              .isAfter(widget.fromDate.subtract(const Duration(days: 1))) &&
          entryDate.isBefore(widget.toDate.add(const Duration(days: 1)))) {
        results.add({
          "date": entryDate,
          "amount": _toDouble(data[amountField]),
        });
      }
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    final grandTotal = supervisorTotal +
        managerTotal +
        organizationTotal +
        contractorTotal +
        incentiveTotal;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        title: Text(
          "Project Stage Expenses Report",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        iconTheme: IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            )
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    SizedBox(height: 24),
                    _buildSection(
                      "Site Supervisor Expenses",
                      supervisorEntries,
                      supervisorTotal,
                      Icons.supervisor_account,
                    ),
                    SizedBox(height: 16),
                    _buildSection(
                      "Manager Expenses",
                      managerEntries,
                      managerTotal,
                      Icons.manage_accounts,
                    ),
                    SizedBox(height: 16),
                    _buildSection(
                      "Organization Expenses",
                      organizationEntries,
                      organizationTotal,
                      Icons.business,
                    ),
                    SizedBox(height: 16),
                    _buildSection(
                      "Contractor Expenses",
                      contractorEntries,
                      contractorTotal,
                      Icons.engineering,
                    ),
                    SizedBox(height: 16),
                    _buildSection(
                      "Incentive Expenses",
                      incentiveEntries,
                      incentiveTotal,
                      Icons.emoji_events,
                    ),
                    SizedBox(height: 24),
                    _buildGrandTotalCard(grandTotal),
                  ],
                ),
              ),
            ),
    );
  }

  /// ✅ Report Header
  Widget _buildHeader() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: cardColor,
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.summarize, color: primaryColor, size: 24),
                SizedBox(width: 12),
                Text(
                  "REPORT SUMMARY",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildInfoRow("Site ID", widget.siteId),
            _buildInfoRow("Project Stage", widget.projectStage),
            _buildInfoRow("From", _formatDate(widget.fromDate)),
            _buildInfoRow("To", _formatDate(widget.toDate)),
            _buildInfoRow("Year", widget.fromDate.year.toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              "$label:",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: textColor.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  /// ✅ Each Expenses Section
  Widget _buildSection(
    String title,
    List<Map<String, dynamic>> entries,
    double total,
    IconData icon,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: cardColor,
      child: ExpansionTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: primaryColor, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        trailing: Text(
          "₹${total.toStringAsFixed(2)}",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        children: [
          if (entries.isEmpty)
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                "No records found",
                style: TextStyle(color: textColor.withOpacity(0.6)),
              ),
            )
          else
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  ...entries.map((e) => _buildExpenseItem(e)),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Subtotal:",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                        Text(
                          "₹${total.toStringAsFixed(2)}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExpenseItem(Map<String, dynamic> expense) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _formatDate(expense['date']),
            style: TextStyle(
              color: textColor,
              fontSize: 14,
            ),
          ),
          Text(
            "₹${expense['amount'].toStringAsFixed(2)}",
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ Grand Total Card
  Widget _buildGrandTotalCard(double grandTotal) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: primaryColor,
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "GRAND TOTAL",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.9),
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              "₹${grandTotal.toStringAsFixed(2)}",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
            Text(
              "Project Stage: ${widget.projectStage}",
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}