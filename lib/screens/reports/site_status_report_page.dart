import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ebricks/services/firestore_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '/utils/pdf_templates.dart';
import 'package:ebricks/utils/app_theme.dart';

class SiteStatusReportPage extends StatefulWidget {
  final String status;
  final Map<String, Object> budgetData;

  const SiteStatusReportPage({
    super.key,
    required this.status,
    required this.budgetData,
  });

  @override
  State<SiteStatusReportPage> createState() => _SiteStatusReportPageState();
}

class _SiteStatusReportPageState extends State<SiteStatusReportPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _currentPage = 1;
  final int _rowsPerPage = 10;
  bool _isGeneratingPdf = false;

  Color getStatusColor(BuildContext context, String status) {
    final theme = Theme.of(context);
    switch (status.toLowerCase()) {
      case 'in-progress':
      case 'in progress':
      case 'ongoing':
        return theme.primaryColor;
      case 'pending':
        return const Color(0xFFFFA000); // Amber
      case 'planning':
        return const Color(0xFF7B1FA2); // Purple
      case 'on-hold':
      case 'on hold':
        return const Color(0xFFD32F2F); // Red
      case 'complete':
      case 'completed':
        return const Color(0xFF388E3C); // Green
      default:
        return theme.primaryColor;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesStatus(Map<String, dynamic> data) {
    final rawStatus = (data['currentStatus'] ?? data['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final target = widget.status.trim().toLowerCase();

    if (target == 'planning') {
      return rawStatus.contains('plan') ||
          rawStatus.contains('draft') ||
          rawStatus.contains('setup') ||
          rawStatus.contains('upcoming');
    } else if (target == 'in-progress' || target == 'in progress' || target == 'ongoing') {
      return rawStatus.contains('progress') ||
          rawStatus.contains('ongoing') ||
          rawStatus.contains('execution') ||
          rawStatus.contains('active');
    } else if (target == 'complete' || target == 'completed') {
      return rawStatus.contains('complete') ||
          rawStatus.contains('finish') ||
          rawStatus.contains('closed') ||
          rawStatus.contains('done');
    } else if (target == 'on-hold' || target == 'on hold' || target == 'pending') {
      return rawStatus.contains('hold') ||
          rawStatus.contains('delay') ||
          rawStatus.contains('overdue') ||
          rawStatus.contains('pause') ||
          rawStatus.contains('suspend');
    }
    return rawStatus == target || rawStatus.contains(target);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final primaryColor = Theme.of(context).primaryColor;
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final statusColor = getStatusColor(context, widget.status);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${widget.status} Sites Report',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                darkAccent,
                Color.alphaBlend(
                  primaryColor.withValues(alpha: 0.35),
                  darkAccent,
                ),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isMobile ? double.infinity : 680,
          ),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirestoreService.getCollection('projects').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(color: statusColor),
                );
              }

              final allDocs = snapshot.hasData ? snapshot.data!.docs : <QueryDocumentSnapshot<Map<String, dynamic>>>[];

              // Filter by status match
              final matchingDocs = allDocs.where((doc) {
                return _matchesStatus(doc.data());
              }).toList();

              // Filter by search query
              final q = _searchQuery.trim().toLowerCase();
              final filteredDocs = matchingDocs.where((doc) {
                if (q.isEmpty) return true;
                final data = doc.data();
                final name = (data['projectName'] ?? '').toString().toLowerCase();
                final owner = (data['ownerName'] ?? '').toString().toLowerCase();
                final loc = (data['siteLocation'] ?? '').toString().toLowerCase();
                final stage = (data['projectStage'] ?? '').toString().toLowerCase();
                final id = (data['siteId'] ?? doc.id).toString().toLowerCase();

                return name.contains(q) ||
                    owner.contains(q) ||
                    loc.contains(q) ||
                    stage.contains(q) ||
                    id.contains(q);
              }).toList();

              // Pagination calculations
              final totalCount = filteredDocs.length;
              final totalPages = totalCount > 0 ? ((totalCount - 1) ~/ _rowsPerPage) + 1 : 1;
              if (_currentPage > totalPages) {
                _currentPage = totalPages;
              }

              final startIndex = (_currentPage - 1) * _rowsPerPage;
              final endIndex = (startIndex + _rowsPerPage < totalCount)
                  ? startIndex + _rowsPerPage
                  : totalCount;
              final pagedDocs = totalCount > 0
                  ? filteredDocs.sublist(startIndex, endIndex)
                  : <QueryDocumentSnapshot<Map<String, dynamic>>>[];

              return Column(
                children: [
                  // 1. Search Bar & Generate PDF Action Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Search Bar
                        Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val;
                                _currentPage = 1; // Reset to page 1 on search
                              });
                            },
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search by project, location, owner...',
                              hintStyle: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF94A3B8),
                                fontWeight: FontWeight.w500,
                              ),
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color: Color(0xFF64748B),
                                size: 19,
                              ),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        color: Color(0xFF64748B),
                                        size: 17,
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {
                                          _searchQuery = '';
                                          _currentPage = 1;
                                        });
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 6,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Action Row: Total Sites Badge + Generate PDF Button
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: statusColor.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.analytics_rounded,
                                    size: 14,
                                    color: statusColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$totalCount ${widget.status} Sites',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: statusColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),

                            // Prominent Generate PDF Button
                            ElevatedButton.icon(
                              onPressed: _isGeneratingPdf || totalCount == 0
                                  ? null
                                  : () => _generatePdf(
                                        context,
                                        filteredDocs.map((d) => d.data()).toList(),
                                      ),
                              icon: _isGeneratingPdf
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.picture_as_pdf_rounded,
                                      size: 16,
                                    ),
                              label: Text(
                                _isGeneratingPdf ? 'Generating...' : 'Generate PDF',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: statusColor,
                                foregroundColor: Colors.white,
                                elevation: 1.5,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 2. Report List Content
                  Expanded(
                    child: totalCount == 0
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  size: 56,
                                  color: statusColor.withValues(alpha: 0.4),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'No Sites Found',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: statusColor,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No sites match "$_searchQuery"'
                                      : 'No sites found with "${widget.status}" status',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF7f8c8d),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                            itemCount: pagedDocs.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final data = pagedDocs[index].data();
                              final siteLocation =
                                  data['siteLocation']?.toString() ?? '-';
                              final ownerName =
                                  data['ownerName']?.toString() ?? '-';
                              final projectName =
                                  data['projectName']?.toString() ?? '-';
                              return _ExpandableSiteTile(
                                siteLocation: siteLocation,
                                ownerName: ownerName,
                                siteDetails: data,
                                statusColor: statusColor,
                                projectName: projectName,
                              );
                            },
                          ),
                  ),

                  // 3. Responsive Pagination Controls Footer
                  if (totalCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Showing X - Y of Z records
                          Text(
                            'Showing ${startIndex + 1}–$endIndex of $totalCount',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),

                          // Page Navigation Buttons
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Previous Button
                              IconButton(
                                icon: const Icon(
                                  Icons.chevron_left_rounded,
                                  size: 22,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                color: _currentPage > 1
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFFCBD5E1),
                                onPressed: _currentPage > 1
                                    ? () {
                                        HapticFeedback.lightImpact();
                                        setState(() => _currentPage--);
                                      }
                                    : null,
                              ),

                              // Page Indicator Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Text(
                                  '$_currentPage / $totalPages',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0A183D),
                                  ),
                                ),
                              ),

                              // Next Button
                              IconButton(
                                icon: const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 22,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                color: _currentPage < totalPages
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFFCBD5E1),
                                onPressed: _currentPage < totalPages
                                    ? () {
                                        HapticFeedback.lightImpact();
                                        setState(() => _currentPage++);
                                      }
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _generatePdf(
    BuildContext ctx,
    List<Map<String, dynamic>> sitesToExport,
  ) async {
    final statusColor = getStatusColor(ctx, widget.status);
    final pdfPrimaryColor = PdfColor.fromInt(statusColor.toARGB32());

    setState(() => _isGeneratingPdf = true);
    try {
      await PdfTemplates.loadFonts();
      final pdf = pw.Document();
      final orgDetails = await PdfTemplates.fetchOrgDetails();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => PdfTemplates.buildHeader(
            reportTitle: '${widget.status} Sites Report',
            orgDetails: orgDetails,
            primaryColor: pdfPrimaryColor,
          ),
          build: (pw.Context context) => [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                PdfTemplates.buildMetaBox('Status', widget.status, pdfPrimaryColor),
                PdfTemplates.buildMetaBox(
                  'Total Records',
                  '${sitesToExport.length}',
                  pdfPrimaryColor,
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              context: context,
              headers: ['Project', 'Location', 'Budget', 'Spent', 'Balance'],
              data: sitesToExport.map((data) {
                final projectName = data['projectName']?.toString() ?? '-';
                final location = data['siteLocation']?.toString() ?? '-';
                final budget =
                    double.tryParse(data['projectBudget']?.toString() ?? '0') ??
                    0;
                final spent =
                    double.tryParse(data['amountSpent']?.toString() ?? '0') ?? 0;
                final paid =
                    double.tryParse(data['amountPaid']?.toString() ?? '0') ?? 0;
                final balance = paid - spent;
                return [
                  projectName,
                  location,
                  '₹${budget.toStringAsFixed(0)}',
                  '₹${spent.toStringAsFixed(0)}',
                  '₹${balance.toStringAsFixed(0)}',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                font: PdfTemplates.boldFont,
              ),
              headerDecoration: pw.BoxDecoration(color: pdfPrimaryColor),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: pw.TextStyle(font: PdfTemplates.regularFont),
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            ),
          ],
          footer: (context) => PdfTemplates.buildFooter(context),
        ),
      );

      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    } catch (e) {
      debugPrint('Error generating PDF: $e');
      if (mounted) {
        AppTheme.showErrorToast(context, 'Failed to generate PDF: $e');
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
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
    final lighterStatusColor = widget.statusColor.withValues(alpha: 0.1);

    String durationValue = '-';
    DateTime? start = parseDate(details['plannedStartDate']);
    DateTime? end = parseDate(details['plannedEndDate']);
    if (start != null && end != null) {
      int days = end.difference(start).inDays + 1;
      durationValue = '$days Days';
    } else if (details['duration'] != null) {
      durationValue = details['duration'].toString();
    }

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
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: ListTile(
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
                        color: balanceColor.withValues(alpha: 0.5),
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
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
