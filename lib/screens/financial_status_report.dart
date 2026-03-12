import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class FinancialStatusReportPage extends StatefulWidget {
  final String siteId;
  final String siteName;
  final String projectName;
  final String ownerName;

  const FinancialStatusReportPage({
    super.key,
    required this.siteId,
    required this.siteName,
    required this.projectName,
    required this.ownerName,
  });

  @override
  State<FinancialStatusReportPage> createState() =>
      _FinancialStatusReportPageState();
}

class _FinancialStatusReportPageState extends State<FinancialStatusReportPage> {
  // Color constants
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

  Future<void> _generateAndPreviewPDF() async {
    final pdf = pw.Document();
    final project = projectData ?? {};
    final budget = _parseNumber(project['projectBudget']);
    final spent = _parseNumber(project['amountSpent']);
    final received = _parseNumber(project['amountPaid']);
    final balance = _parseNumber(project['amountBalance']);
    final duration = _calculateDurationInDays(project);
    final startDate = _formatDate(project['actualStartDate']);
    final endDate = _formatDate(project['plannedEndDate']);
    final currentDate = _formatDate(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Financial Status Report',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromInt(primaryColor.value),
                ),
              ),
              pw.Container(
                width: 60,
                height: 60,
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(primaryColor.value),
                  shape: pw.BoxShape.circle,
                ),
                child: pw.Center(
                  child: pw.Text(
                    'FSR',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Project Information',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromInt(primaryColor.value),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            cellStyle: pw.TextStyle(fontSize: 12),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(
              color: PdfColor.fromInt(primaryColor.value),
            ),
            data: [
              ['Site ID', project['siteid'] ?? project['siteId'] ?? '-'],
              ['Project Name', project['projectName'] ?? '-'],
              ['Site Location', project['siteLocation'] ?? '-'],
              ['Owner Name', project['ownerName'] ?? '-'],
              ['Actual Start Date', startDate],
              ['Planned End Date', endDate],
              ['Current Date', currentDate],
              ['Duration (Days)', duration.toString()],
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Financial Summary',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromInt(primaryColor.value),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            cellStyle: pw.TextStyle(fontSize: 12),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(
              color: PdfColor.fromInt(primaryColor.value),
            ),
            data: [
              ['Project Budget', '₹${budget.toStringAsFixed(2)}'],
              ['Amount Received', '₹${received.toStringAsFixed(2)}'],
              ['Amount Spent', '₹${spent.toStringAsFixed(2)}'],
              ['Balance Amount', '₹${balance.toStringAsFixed(2)}'],
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(primaryColor.value),
              border: pw.Border.all(
                color: PdfColor.fromInt(primaryColor.value),
                width: 1,
              ),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(
              'Budget Utilization: ${budget > 0 ? (spent / budget * 100).clamp(0, 100).toStringAsFixed(1) : '0'}%',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromInt(primaryColor.value),
              ),
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Generated on ${DateFormat('dd MMM yyyy - HH:mm').format(DateTime.now())}',
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColor.fromInt(secondaryTextColor.value),
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Map<String, dynamic>? projectData;
  bool isLoading = true;
  String? errorMsg;

  @override
  void initState() {
    super.initState();
    _fetchProjectData();
  }

  Future<void> _fetchProjectData() async {
    try {
      final col = FirebaseFirestore.instance.collection('projects');
      QuerySnapshot<Map<String, dynamic>> query = await col
          .where('siteId', isEqualTo: widget.siteId)
          .limit(1)
          .get();
      if (query.docs.isEmpty) {
        query = await col
            .where('siteid', isEqualTo: widget.siteId)
            .limit(1)
            .get();
      }
      if (query.docs.isNotEmpty) {
        setState(() {
          projectData = query.docs.first.data();
          isLoading = false;
        });
      } else {
        setState(() {
          errorMsg = 'Project not found';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMsg = 'Error loading project: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Financial Status Report',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : errorMsg != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: dangerColor),
                  const SizedBox(height: 16),
                  Text(
                    errorMsg!,
                    style: TextStyle(fontSize: 16, color: textColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _fetchProjectData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Project Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: primaryColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.business,
                                size: 20,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.projectName,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.siteName,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: secondaryTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Divider(color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 16,
                              color: secondaryTextColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.ownerName,
                              style: TextStyle(
                                fontSize: 14,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Project Information Section
                  _buildSectionHeader(
                    'Project Information',
                    Icons.info_outline,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    children: [
                      _buildInfoItem(
                        'Site ID',
                        projectData?['siteid'] ?? projectData?['siteId'] ?? '-',
                        Icons.tag,
                      ),
                      _buildInfoItem(
                        'Site Location',
                        projectData?['siteLocation'] ?? '-',
                        Icons.location_on,
                      ),
                      _buildInfoItem(
                        'Planned Start Date',
                        _formatDate(projectData?['plannedStartDate']),
                        Icons.calendar_today,
                      ),
                      _buildInfoItem(
                        'Actual Start Date',
                        _formatDate(projectData?['actualStateDate']),
                        Icons.calendar_today,
                      ),
                      _buildInfoItem(
                        'Current Date',
                        _formatDate(DateTime.now()),
                        Icons.calendar_today,
                      ),
                      _buildInfoItem(
                        'Duration',
                        '${_calculateDurationInDays(projectData)} days',
                        Icons.timelapse,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Financial Summary Section
                  _buildSectionHeader('Financial Summary', Icons.attach_money),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    children: [
                      _buildFinancialItem(
                        'Project Budget',
                        projectData?['projectBudget'],
                        Icons.account_balance_wallet,
                        primaryColor,
                      ),
                      _buildFinancialItem(
                        'Amount Received',
                        projectData?['amountPaid'],
                        Icons.arrow_downward,
                        successColor,
                      ),
                      _buildFinancialItem(
                        'Amount Spent',
                        projectData?['amountSpent'],
                        Icons.arrow_upward,
                        dangerColor,
                      ),
                      _buildFinancialItem(
                        'Balance Amount',
                        projectData?['amountBalance'],
                        Icons.account_balance,
                        accentColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Visual Financial Summary
                  if (projectData?['projectBudget'] != null &&
                      projectData?['amountSpent'] != null)
                    _buildFinancialProgress(),
                  const SizedBox(height: 32),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.picture_as_pdf, size: 20),
                          label: const Text('Export as PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _generateAndPreviewPDF,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.arrow_back, size: 20),
                          label: const Text('Go Back'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryColor,
                            side: BorderSide(color: primaryColor),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: secondaryTextColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 14, color: secondaryTextColor),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
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

  Widget _buildFinancialItem(
    String label,
    dynamic value,
    IconData icon,
    Color color,
  ) {
    final amount = _formatCurrency(value);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 14, color: secondaryTextColor),
                ),
                const SizedBox(height: 2),
                Text(
                  amount,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialProgress() {
    final budget = _parseNumber(projectData?['projectBudget']);
    final spent = _parseNumber(projectData?['amountSpent']);
    final percentage = budget > 0 ? (spent / budget * 100).clamp(0, 100) : 0;

    Color progressColor;
    if (percentage > 80) {
      progressColor = dangerColor;
    } else if (percentage > 50) {
      progressColor = warningColor;
    } else {
      progressColor = successColor;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Budget Utilization',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 12,
            borderRadius: BorderRadius.circular(6),
            backgroundColor: Colors.grey[200],
            color: progressColor,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${percentage.toStringAsFixed(1)}% used',
                style: TextStyle(
                  color: progressColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${_formatCurrency(spent)} of ${_formatCurrency(budget)}',
                style: TextStyle(color: secondaryTextColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _parseNumber(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    }
    return 0;
  }

  String _formatDate(dynamic date) {
    if (date == null) return '-';
    if (date is String) {
      try {
        final dt = DateTime.parse(date);
        return DateFormat('dd MMM yyyy').format(dt);
      } catch (_) {
        return date;
      }
    } else if (date is Timestamp) {
      return DateFormat('dd MMM yyyy').format(date.toDate());
    } else if (date is DateTime) {
      return DateFormat('dd MMM yyyy').format(date);
    }
    return date.toString();
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return '-';
    final number = _parseNumber(value);
    return NumberFormat.currency(symbol: '₹', decimalDigits: 2).format(number);
  }

  int _calculateDurationInDays(Map<String, dynamic>? data) {
    if (data == null || data['actualStateDate'] == null) return 0;

    DateTime? startDate;
    final start = data['actualStateDate'];

    // Parse start date
    if (start is String) {
      startDate = DateTime.tryParse(start);
    } else if (start is Timestamp) {
      startDate = start.toDate();
    }

    if (startDate == null) return 0;

    // Use current date as end date
    final endDate = DateTime.now();

    // Calculate difference in days
    final difference = endDate.difference(startDate);
    return difference.inDays;
  }
}
