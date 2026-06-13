import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../utils/pdf_templates.dart';

class SiteStatusReportPage extends StatelessWidget {
  final String status;
  final Map<String, Object> budgetData;

  const SiteStatusReportPage({
    super.key,
    required this.status,
    required this.budgetData,
  });

  Color getStatusColor(BuildContext context, String status) {
    final theme = Theme.of(context);
    switch (status.toLowerCase()) {
      case 'in-progress':
        return theme.primaryColor;
      case 'pending':
        return const Color(0xFFFFA000); // Amber
      case 'planning':
        return const Color(0xFF7B1FA2); // Purple
      case 'on-hold':
        return const Color(0xFFD32F2F); // Red
      case 'complete':
        return const Color(0xFF388E3C); // Green
      default:
        return theme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 600;

    final statusColor = getStatusColor(context, status);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '$status Sites',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: statusColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.picture_as_pdf_outlined,
              color: Colors.white,
            ),
            onPressed: () => _generatePdf(context),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
          child: Container(
        color: const Color(0xFFF8F9FA), // Light background
        child: FutureBuilder<QuerySnapshot>(
          future: FirestoreService.getCollection(
            'projects',
          ).where('currentStatus', isEqualTo: status).get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: statusColor),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 64,
                      color: statusColor.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Sites Found',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No sites with "$status" status',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF7f8c8d),
                      ),
                    ),
                  ],
                ),
              );
            }

            final docs = snapshot.data!.docs;
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final siteLocation = data['siteLocation']?.toString() ?? '-';
                final ownerName = data['ownerName']?.toString() ?? '-';
                final projectName = data['projectName']?.toString() ?? '-';
                return _ExpandableSiteTile(
                  siteLocation: siteLocation,
                  ownerName: ownerName,
                  siteDetails: data,
                  statusColor: statusColor,
                  projectName: projectName,
                );
              },
            );
          },
        ),
      ),
        ),
      ),
    );
  }

  Future<void> _generatePdf(BuildContext context) async {
    final pdf = pw.Document();
    final pdfPrimaryColor = PdfColor.fromInt(
      getStatusColor(context, status).value,
    );
    final orgDetails = await PdfTemplates.fetchOrgDetails();

    final snapshot = await FirestoreService.getCollection(
      'projects',
    ).where('currentStatus', isEqualTo: status).get();

    final docs = snapshot.docs;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => PdfTemplates.buildHeader(
          reportTitle: '$status Sites Report',
          orgDetails: orgDetails,
          primaryColor: pdfPrimaryColor,
        ),
        build: (pw.Context context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              PdfTemplates.buildMetaBox('Status', status, pdfPrimaryColor),
              PdfTemplates.buildMetaBox(
                'Total Sites',
                '${docs.length}',
                pdfPrimaryColor,
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Table.fromTextArray(
            headers: ['Project', 'Site', 'Budget', 'Spent', 'Balance'],
            data: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final projectName = data['projectName']?.toString() ?? '-';
              final siteLocation = data['siteLocation']?.toString() ?? '-';
              final budget =
                  double.tryParse(data['projectBudget']?.toString() ?? '0') ??
                  0;
              final paid =
                  double.tryParse(data['amountPaid']?.toString() ?? '0') ?? 0;
              final spent =
                  double.tryParse(data['amountSpent']?.toString() ?? '0') ?? 0;
              final balance = paid - spent;
              return [
                projectName,
                siteLocation,
                '₹${budget.toStringAsFixed(0)}',
                '₹${spent.toStringAsFixed(0)}',
                '₹${balance.toStringAsFixed(0)}',
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(color: pdfPrimaryColor),
            cellAlignment: pw.Alignment.centerLeft,
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
          ),
        ],
        footer: (context) => PdfTemplates.buildFooter(context),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}

class _ExpandableSiteTile extends StatefulWidget {
  final String siteLocation;
  final String projectName;
  final String ownerName;
  final Map<String, dynamic> siteDetails;
  final Color statusColor;

  const _ExpandableSiteTile({
    required this.siteLocation,
    required this.ownerName,
    required this.siteDetails,
    required this.statusColor,
    required this.projectName,
  });

  @override
  State<_ExpandableSiteTile> createState() => _ExpandableSiteTileState();
}

class _ExpandableSiteTileState extends State<_ExpandableSiteTile> {
  bool expanded = false;

  String formatToDDMMYYYY(dynamic dateValue) {
    if (dateValue == null) return '-';
    DateTime? dt;
    if (dateValue is Timestamp) {
      dt = dateValue.toDate();
    } else if (dateValue is DateTime) {
      dt = dateValue;
    } else if (dateValue is String) {
      try {
        dt = DateTime.parse(dateValue);
      } catch (_) {
        return dateValue;
      }
    }
    if (dt == null) return '-';
    return DateFormat('dd/MM/yyyy').format(dt);
  }

  DateTime? parseDate(dynamic dateValue) {
    if (dateValue == null) return null;
    if (dateValue is Timestamp) {
      return dateValue.toDate();
    } else if (dateValue is DateTime) {
      return dateValue;
    } else if (dateValue is String) {
      try {
        return DateTime.parse(dateValue);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Color getBalanceIndicatorColor(Map<String, dynamic> details) {
    final projectBudget =
        double.tryParse(details['projectBudget']?.toString() ?? '0') ?? 0;
    final amountReceived =
        double.tryParse(details['amountPaid']?.toString() ?? '0') ?? 0;
    final amountSpent =
        double.tryParse(details['amountSpent']?.toString() ?? '0') ?? 0;
    final balanceAmount = amountReceived - amountSpent;

    if (projectBudget == 0) return const Color(0xFF7f8c8d); // Grey

    final balancePercent = (balanceAmount / projectBudget) * 100;

    if (balancePercent >= 75) {
      return const Color(0xFF388E3C); // Green
    } else if (balancePercent >= 50) {
      return const Color(0xFFFFA000); // Amber
    } else if (balancePercent >= 15) {
      return const Color(0xFFF57C00); // Orange
    } else {
      return const Color(0xFFD32F2F); // Red
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = widget.siteDetails;
    final balanceColor = getBalanceIndicatorColor(details);
    final lighterStatusColor = widget.statusColor.withOpacity(0.1);

    String durationValue = '-';
    DateTime? start = parseDate(details['plannedStartDate']);
    DateTime? end = parseDate(details['plannedEndDate']);
    if (start != null && end != null) {
      int days = end.difference(start).inDays + 1;
      durationValue = '$days Days';
    } else if (details['duration'] != null) {
      durationValue = details['duration'].toString();
    }

    // Calculate balance dynamically instead of using stored balance
    final amountReceived =
        double.tryParse(details['amountPaid']?.toString() ?? '0') ?? 0;
    final amountSpent =
        double.tryParse(details['amountSpent']?.toString() ?? '0') ?? 0;
    final balanceAmount = amountReceived - amountSpent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: lighterStatusColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.location_on,
                color: widget.statusColor,
                size: 20,
              ),
            ),
            title: Text(
              widget.projectName,
              style: TextStyle(
                color: widget.statusColor,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              widget.ownerName,
              style: const TextStyle(fontSize: 14, color: Color(0xFF7f8c8d)),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: balanceColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      width: 2,
                      color: balanceColor.withOpacity(0.5),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  color: widget.statusColor,
                ),
              ],
            ),
            onTap: () {
              setState(() {
                expanded = !expanded;
              });
            },
          ),
          if (expanded) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.business,
                    label: 'Project',
                    value: details['projectName']?.toString() ?? '-',
                    iconColor: widget.statusColor,
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.assessment,
                    label: 'Project Stage',
                    value: details['projectStage']?.toString() ?? '-',
                    iconColor: widget.statusColor,
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.date_range,
                    label: 'Start Date',
                    value: formatToDDMMYYYY(details['plannedStartDate']),
                    iconColor: widget.statusColor,
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.event_available,
                    label: 'End Date',
                    value: formatToDDMMYYYY(details['plannedEndDate']),
                    iconColor: widget.statusColor,
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.timelapse,
                    label: 'Duration',
                    value: durationValue,
                    iconColor: widget.statusColor,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _FinancialInfoCard(
                          title: 'Budget',
                          value:
                              '₹${details['projectBudget']?.toString() ?? '0'}',
                          icon: Icons.account_balance_wallet,
                          color: widget.statusColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _FinancialInfoCard(
                          title: 'Received',
                          value: '₹${amountReceived.toStringAsFixed(2)}',
                          icon: Icons.attach_money,
                          color: const Color(0xFF388E3C), // Green
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _FinancialInfoCard(
                          title: 'Spent',
                          value: '₹${amountSpent.toStringAsFixed(2)}',
                          icon: Icons.money_off,
                          color: const Color(0xFFD32F2F), // Red
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _FinancialInfoCard(
                          title: 'Balance',
                          value: '₹${balanceAmount.toStringAsFixed(2)}',
                          icon: Icons.account_balance,
                          color: balanceColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? Theme.of(context).primaryColor;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: effectiveIconColor),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: Color(0xFF7f8c8d),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Color(0xFF2c3e50),
            ),
          ),
        ),
      ],
    );
  }
}

class _FinancialInfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _FinancialInfoCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// Firestore update example function for incrementing amountReceived and amountSpent
Future<void> updateProjectAmounts(
  String projectId,
  double receivedIncrement,
  double spentIncrement,
) {
  final docRef = FirestoreService.getCollection('projects').doc(projectId);
  return docRef.update({
    'amountPaid': FieldValue.increment(receivedIncrement),
    'amountSpent': FieldValue.increment(spentIncrement),
  });
}
