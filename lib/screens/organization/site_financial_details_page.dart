import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:ebricks/services/expense_service.dart';
import 'package:ebricks/services/firestore_service.dart';
import 'package:ebricks/utils/app_theme.dart';
import 'package:ebricks/utils/responsive.dart';
import 'package:ebricks/screens/organization/org_site_payment_menu_page.dart';
import 'package:ebricks/screens/organization/organization_expenses.dart';

class SiteFinancialDetailsPage extends StatefulWidget {
  final String siteId;
  final String siteName;
  final String projectName;
  final String ownerName;
  final Map<String, dynamic>? initialData;

  const SiteFinancialDetailsPage({
    super.key,
    required this.siteId,
    required this.siteName,
    required this.projectName,
    required this.ownerName,
    this.initialData,
  });

  @override
  State<SiteFinancialDetailsPage> createState() =>
      _SiteFinancialDetailsPageState();
}

class _SiteFinancialDetailsPageState extends State<SiteFinancialDetailsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  Map<String, dynamic>? _projectData;
  Map<String, dynamic>? _siteTotalsData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.initialData != null && widget.initialData!.isNotEmpty) {
      _projectData = Map<String, dynamic>.from(widget.initialData!);
      _isLoading = false;
    }
    _fetchFinancialDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchFinancialDetails() async {
    if (_projectData == null) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final projectsCol = FirestoreService.getCollection('projects');
      final siteCol = FirestoreService.getCollection('Site');
      final totalsCol = FirestoreService.getCollection('totalSiteExpensesPerDay');

      // 1. Fetch initial documents concurrently in parallel
      final results = await Future.wait([
        projectsCol.doc(widget.siteId).get(),
        siteCol.doc(widget.siteId).get(),
        totalsCol.doc(widget.siteId).get(),
      ]);

      final directProjDoc = results[0];
      final directSiteDoc = results[1];
      final directTotalsDoc = results[2];

      if (directProjDoc.exists && directProjDoc.data() != null) {
        _projectData = directProjDoc.data();
      } else {
        // Query projects collection by siteId / site / siteName if direct id lookup didn't match
        var projQuery = await projectsCol.where('siteId', isEqualTo: widget.siteId).limit(1).get();
        if (projQuery.docs.isEmpty) {
          projQuery = await projectsCol.where('site', isEqualTo: widget.siteId).limit(1).get();
        }
        if (projQuery.docs.isEmpty && widget.siteName.isNotEmpty) {
          projQuery = await projectsCol.where('siteName', isEqualTo: widget.siteName).limit(1).get();
        }

        if (projQuery.docs.isNotEmpty) {
          _projectData = projQuery.docs.first.data();
        } else if (directSiteDoc.exists && directSiteDoc.data() != null) {
          _projectData = directSiteDoc.data();
        } else if (widget.initialData != null) {
          _projectData = widget.initialData;
        }
      }

      // Merge Site doc fields if available
      if (directSiteDoc.exists && directSiteDoc.data() != null) {
        final sData = directSiteDoc.data()!;
        _projectData ??= {};
        sData.forEach((k, v) {
          if (v != null && (_projectData![k] == null || _projectData![k] == 0)) {
            _projectData![k] = v;
          }
        });
      }

      // Set category totals if available
      if (directTotalsDoc.exists && directTotalsDoc.data() != null) {
        _siteTotalsData = directTotalsDoc.data();
      } else {
        final queryTotals = await totalsCol.where('siteId', isEqualTo: widget.siteId).limit(1).get();
        if (queryTotals.docs.isNotEmpty) {
          _siteTotalsData = queryTotals.docs.first.data();
        }
      }

      // Display data immediately to the user
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      // 2. Perform background fresh recalculation & sync without blocking page render
      ExpenseService.recalcTotalsAndSyncProject(widget.siteId).then((_) async {
        if (!mounted) return;
        try {
          final refreshedDoc = await totalsCol.doc(widget.siteId).get();
          final refreshedProj = await projectsCol.doc(widget.siteId).get();
          if (mounted) {
            setState(() {
              if (refreshedDoc.exists && refreshedDoc.data() != null) {
                _siteTotalsData = refreshedDoc.data();
              }
              if (refreshedProj.exists && refreshedProj.data() != null) {
                final pData = refreshedProj.data()!;
                _projectData ??= {};
                pData.forEach((k, v) {
                  if (v != null) _projectData![k] = v;
                });
              }
            });
          }
        } catch (_) {}
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load financial details: $e';
          _isLoading = false;
        });
      }
    }
  }

  double _computeTotalSpent(Map<String, dynamic> data) {
    final rawSpent = _parseNum(
      data['amountSpent'] ?? data['amountSpend'] ?? data['spent'] ?? data['totalAllExpenses'],
    );
    final totals = _siteTotalsData ?? {};
    final totalFromTotals = _parseNum(totals['totalAllExpenses']);
    final sumCategoryTotals = _parseNum(totals['totalSiteExpense']) +
        _parseNum(totals['totalMgrExpense']) +
        _parseNum(totals['totalOrgExpense']) +
        _parseNum(totals['totalContractorExpense']) +
        _parseNum(totals['totalIncentiveExpenses']);

    if (totalFromTotals > 0) {
      return totalFromTotals;
    } else if (sumCategoryTotals > 0) {
      return sumCategoryTotals;
    }
    return rawSpent;
  }

  String _formatCurrency(num value) {
    if (value == 0) return '0';
    final isNegative = value < 0;
    final absVal = value.abs().round();
    final str = absVal.toString();
    if (str.length <= 3) {
      return isNegative ? '-$str' : str;
    }

    final last3 = str.substring(str.length - 3);
    final remaining = str.substring(0, str.length - 3);
    final buffer = StringBuffer();
    for (int i = 0; i < remaining.length; i++) {
      if (i > 0 && (remaining.length - i) % 2 == 0) {
        buffer.write(',');
      }
      buffer.write(remaining[i]);
    }
    buffer.write(',');
    buffer.write(last3);
    final formatted = buffer.toString();
    return isNegative ? '-$formatted' : formatted;
  }

  double _parseNum(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) {
      final clean = val.replaceAll(',', '').replaceAll('₹', '').trim();
      return double.tryParse(clean) ?? 0.0;
    }
    return 0.0;
  }

  String _formatDate(dynamic dateVal) {
    if (dateVal == null) return 'N/A';
    DateTime? dt;
    if (dateVal is Timestamp) {
      dt = dateVal.toDate();
    } else if (dateVal is DateTime) {
      dt = dateVal;
    } else if (dateVal is String) {
      dt = DateTime.tryParse(dateVal);
    }
    if (dt != null) {
      return DateFormat('dd MMM yyyy').format(dt);
    }
    return dateVal.toString();
  }

  Color _getStatusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('complete') || s.contains('finish') || s.contains('done')) {
      return const Color(0xFF10B981);
    }
    if (s.contains('plan') || s.contains('draft') || s.contains('setup')) {
      return const Color(0xFF6366F1);
    }
    if (s.contains('hold') || s.contains('pause') || s.contains('pending')) {
      return const Color(0xFFF59E0B);
    }
    if (s.contains('delay') || s.contains('overdue')) {
      return const Color(0xFFEF4444);
    }
    return const Color(0xFF0284C7); // Live / In Progress
  }

  Future<void> _generateAndPreviewPdf() async {
    final pdf = pw.Document();
    final data = _projectData ?? {};

    final budget = _parseNum(data['projectBudget'] ?? data['budget']);
    final received = _parseNum(data['amountPaid'] ?? data['paid'] ?? data['amountReceived']);
    final spent = _computeTotalSpent(data);
    final customerCashBalance = received - spent;
    final budgetRemaining = budget - spent;
    final usagePercent = budget > 0 ? ((spent / budget) * 100).clamp(0, 100).toStringAsFixed(1) : '0';

    final font = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'FINANCIAL STATUS STATEMENT',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 18,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Site: ${widget.siteName} (${widget.siteId})',
                        style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  pw.Text(
                    DateFormat('dd MMM yyyy').format(DateTime.now()),
                    style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600),
                  ),
                ],
              ),
              pw.Divider(thickness: 1.5, color: PdfColors.grey300),
              pw.SizedBox(height: 12),

              // Project Info Table
              pw.Text(
                'PROJECT INFORMATION',
                style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.blue800),
              ),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Project Name:', style: pw.TextStyle(font: fontBold, fontSize: 9)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(widget.projectName.isNotEmpty ? widget.projectName : widget.siteName, style: pw.TextStyle(font: font, fontSize: 9)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Client / Owner:', style: pw.TextStyle(font: fontBold, fontSize: 9)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(widget.ownerName.isNotEmpty ? widget.ownerName : 'N/A', style: pw.TextStyle(font: font, fontSize: 9)),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Category:', style: pw.TextStyle(font: fontBold, fontSize: 9)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('${data['projectCategory'] ?? 'Standard'} • ${data['projectSubCategory'] ?? 'General'}', style: pw.TextStyle(font: font, fontSize: 9)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Current Status:', style: pw.TextStyle(font: fontBold, fontSize: 9)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('${data['currentStatus'] ?? data['status'] ?? 'Active'}', style: pw.TextStyle(font: font, fontSize: 9)),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 18),

              // Financial Summary Table
              pw.Text(
                'FINANCIAL BREAKDOWN',
                style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.blue800),
              ),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Metric', style: pw.TextStyle(font: fontBold, fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Amount (INR)', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: fontBold, fontSize: 10))),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Total Project Budget', style: pw.TextStyle(font: font, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Rs. ${_formatCurrency(budget)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: fontBold, fontSize: 9))),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Customer Amount Received (Paid by Client)', style: pw.TextStyle(font: font, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Rs. ${_formatCurrency(received)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.green800))),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Total Actual Expenses Spent', style: pw.TextStyle(font: font, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Rs. ${_formatCurrency(spent)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.orange800))),
                    ],
                  ),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.green50),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Balance from Customer Received (Cash in Hand)', style: pw.TextStyle(font: fontBold, fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Rs. ${_formatCurrency(customerCashBalance)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: fontBold, fontSize: 10, color: customerCashBalance < 0 ? PdfColors.red800 : PdfColors.green900))),
                    ],
                  ),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Budget Remaining (Total Budget - Expenses)', style: pw.TextStyle(font: fontBold, fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Rs. ${_formatCurrency(budgetRemaining)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.blue900))),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Budget Utilization Rate', style: pw.TextStyle(font: font, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('$usagePercent %', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: font, fontSize: 9))),
                    ],
                  ),
                ],
              ),
              pw.Spacer(),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('CST White Label App • Financial Statement', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey500)),
                  pw.Text('Generated dynamically from Firestore backend', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey500)),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Financial_Statement_${widget.siteId}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.primaryColor,
      builder: (context, primaryColor, _) {
        final darkAccent = AppTheme.getDarkAccent(primaryColor);
        final dynamicGradientColors =
            AppTheme.getBackgroundGradientColors(primaryColor);

        return Theme(
          data: AppTheme.getTheme(primaryColor),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dynamicGradientColors,
                stops: const [0.0, 0.35, 0.7, 1.0],
              ),
            ),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: _buildAppBar(context, primaryColor, darkAccent),
              body: SafeArea(
                bottom: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: Responsive.maxContentWidth,
                    ),
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _errorMessage != null
                            ? _buildErrorView(primaryColor)
                            : _buildMainContent(context, primaryColor, darkAccent),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    Color primaryColor,
    Color darkAccent,
  ) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primaryColor, darkAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ),
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.white,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Site Financial Details',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          Text(
            widget.siteName.isNotEmpty ? widget.siteName : widget.siteId,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.picture_as_pdf_rounded,
            color: Colors.white,
            size: 22,
          ),
          tooltip: 'Export Financial Statement',
          onPressed: _generateAndPreviewPdf,
        ),
        IconButton(
          icon: const Icon(
            Icons.refresh_rounded,
            color: Colors.white,
            size: 22,
          ),
          tooltip: 'Refresh Financial Data',
          onPressed: _fetchFinancialDetails,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildErrorView(Color primaryColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: Color(0xFFEF4444),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'An error occurred',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _fetchFinancialDetails,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    Color primaryColor,
    Color darkAccent,
  ) {
    final data = _projectData ?? {};
    final hPad = Responsive.horizontalPadding(context);

    final budget = _parseNum(data['projectBudget'] ?? data['budget']);
    final received = _parseNum(data['amountPaid'] ?? data['paid'] ?? data['amountReceived']);
    final spent = _computeTotalSpent(data);
    final customerCashBalance = (received - spent);
    final budgetRemaining = (budget - spent);
    final status = (data['currentStatus'] ?? data['status'] ?? 'Live').toString();
    final statusColor = _getStatusColor(status);
    final category = (data['projectCategory'] ?? 'House').toString();
    final subCategory = (data['projectSubCategory'] ?? '2BHK').toString();
    final ownerName = (data['ownerName'] ?? widget.ownerName).toString();
    final ownerPhone = (data['ownerPhoneNumber'] ?? '').toString();
    final location = (data['siteLocation'] ?? data['location'] ?? 'Site Location').toString();
    final startDate = _formatDate(data['actualStartDate'] ?? data['plannedStartDate'] ?? data['startDate']);
    final endDate = _formatDate(data['actualEndDate'] ?? data['plannedEndDate'] ?? data['endDate']);

    final usageRatio = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;
    final usagePercent = (usageRatio * 100).toStringAsFixed(1);

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Site Info Header Card
                _buildSiteHeaderCard(
                  projectName: widget.projectName.isNotEmpty ? widget.projectName : widget.siteName,
                  siteId: widget.siteId,
                  status: status,
                  statusColor: statusColor,
                  category: category,
                  subCategory: subCategory,
                  ownerName: ownerName,
                  ownerPhone: ownerPhone,
                  location: location,
                  startDate: startDate,
                  endDate: endDate,
                  primaryColor: primaryColor,
                ),
                const SizedBox(height: 16),

                // 2. Financial Summary KPIs Matrix
                _buildFinancialKpiGrid(
                  budget: budget,
                  received: received,
                  spent: spent,
                  customerCashBalance: customerCashBalance,
                  budgetRemaining: budgetRemaining,
                  usageRatio: usageRatio,
                  usagePercent: usagePercent,
                  primaryColor: primaryColor,
                ),
                const SizedBox(height: 16),

                // 3. Quick Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickCtaButton(
                        label: 'Site Payment',
                        icon: Icons.payments_rounded,
                        color: const Color(0xFF10B981),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const OrgSitePaymentMenuPage(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickCtaButton(
                        label: 'Record Expense',
                        icon: Icons.receipt_long_rounded,
                        color: const Color(0xFFEF4444),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const OrganizationExpenses(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 4. Tab Header
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: const Color(0xFF64748B),
                    labelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    tabs: const [
                      Tab(text: 'Summary'),
                      Tab(text: 'Client Income'),
                      Tab(text: 'Expenses'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Detailed Breakdown & Category Summary
          _buildSummaryTab(budget, received, spent, customerCashBalance, budgetRemaining, primaryColor),

          // Tab 2: Client Payments / Income
          _buildClientIncomeTab(primaryColor, received),

          // Tab 3: Detailed Itemized Expenses
          _buildExpensesTab(primaryColor),
        ],
      ),
    );
  }

  Widget _buildSiteHeaderCard({
    required String projectName,
    required String siteId,
    required String status,
    required Color statusColor,
    required String category,
    required String subCategory,
    required String ownerName,
    required String ownerPhone,
    required String location,
    required String startDate,
    required String endDate,
    required Color primaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Project Name & Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      projectName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Site ID: $siteId',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 22, color: Color(0xFFF1F5F9)),

          // Row 2: Category, Owner, Timeline Info Chips
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildMetaTag(
                icon: Icons.category_rounded,
                text: '$category • $subCategory',
              ),
              _buildMetaTag(
                icon: Icons.person_outline_rounded,
                text: ownerPhone.isNotEmpty ? '$ownerName ($ownerPhone)' : ownerName,
              ),
              _buildMetaTag(
                icon: Icons.location_on_outlined,
                text: location,
              ),
              _buildMetaTag(
                icon: Icons.calendar_month_outlined,
                text: '$startDate → $endDate',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaTag({required IconData icon, required String text}) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialKpiGrid({
    required double budget,
    required double received,
    required double spent,
    required double customerCashBalance,
    required double budgetRemaining,
    required double usageRatio,
    required String usagePercent,
    required Color primaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Financial Summary',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 14),

          // Grid 2x2 of Financial KPI tiles
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.1,
            children: [
              _buildKpiTile(
                title: 'Estimated Budget',
                amount: '₹ ${_formatCurrency(budget)}',
                color: const Color(0xFF0284C7),
                icon: Icons.account_balance_wallet_rounded,
                bgColor: const Color(0xFFF0F9FF),
              ),
              _buildKpiTile(
                title: 'Customer Received',
                amount: '₹ ${_formatCurrency(received)}',
                color: const Color(0xFF10B981),
                icon: Icons.arrow_downward_rounded,
                bgColor: const Color(0xFFECFDF5),
              ),
              _buildKpiTile(
                title: 'Expenses Spent',
                amount: '₹ ${_formatCurrency(spent)}',
                color: const Color(0xFFEF4444),
                icon: Icons.arrow_upward_rounded,
                bgColor: const Color(0xFFFEF2F2),
              ),
              _buildKpiTile(
                title: 'Balance from Received',
                amount: '₹ ${_formatCurrency(customerCashBalance)}',
                color: customerCashBalance < 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                icon: Icons.savings_rounded,
                bgColor: customerCashBalance < 0 ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Budget Remaining Card Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.pie_chart_outline_rounded, size: 16, color: Color(0xFF64748B)),
                    SizedBox(width: 6),
                    Text(
                      'Budget Remaining (Budget - Spent):',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
                Text(
                  '₹ ${_formatCurrency(budgetRemaining)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Budget Utilization Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Budget Utilization',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
              Text(
                '$usagePercent%',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: usageRatio > 0.85
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF0284C7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: usageRatio,
              minHeight: 8,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(
                usageRatio > 0.85
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF0284C7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiTile({
    required String title,
    required String amount,
    required Color color,
    required IconData icon,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color.withValues(alpha: 0.9),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCtaButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------- TAB 1: SUMMARY --------------------
  Widget _buildSummaryTab(
    double budget,
    double received,
    double spent,
    double customerCashBalance,
    double budgetRemaining,
    Color primaryColor,
  ) {
    final totals = _siteTotalsData ?? {};
    final supervisorExp = _parseNum(totals['totalSiteExpense']);
    final managerExp = _parseNum(totals['totalMgrExpense']);
    final orgExp = _parseNum(totals['totalOrgExpense']);
    final contractorExp = _parseNum(totals['totalContractorExpense']);
    final incentiveExp = _parseNum(totals['totalIncentiveExpenses']);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      children: [
        // Category Breakdown Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Expense Category Distribution',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 14),
              _buildCategoryRow('Site & Daily Supervisor Expenses', supervisorExp, const Color(0xFF0284C7)),
              _buildCategoryRow('Manager Expenses', managerExp, const Color(0xFF8B5CF6)),
              _buildCategoryRow('Organization Expenses', orgExp, const Color(0xFFF59E0B)),
              _buildCategoryRow('Contractor Payments', contractorExp, const Color(0xFF10B981)),
              _buildCategoryRow('Incentives & Extra', incentiveExp, const Color(0xFFEC4899)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Financial Ratio Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Financial Performance Indicators',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 14),
              _buildPerformanceRow(
                'Payment Realization',
                budget > 0 ? '${((received / budget) * 100).toStringAsFixed(1)}%' : '0%',
                'Client paid vs Total Contract',
                const Color(0xFF10B981),
              ),
              const Divider(height: 18, color: Color(0xFFF1F5F9)),
              _buildPerformanceRow(
                'Cost Efficiency',
                budget > 0 ? '${(((budget - spent) / budget) * 100).toStringAsFixed(1)}%' : '100%',
                'Remaining margin cushion',
                const Color(0xFF0284C7),
              ),
              const Divider(height: 18, color: Color(0xFFF1F5F9)),
              _buildPerformanceRow(
                'Cash Flow Health',
                received >= spent ? 'Positive (+ ₹ ${_formatCurrency(received - spent)})' : 'Negative (- ₹ ${_formatCurrency(spent - received)})',
                'Client payments vs Expenses spent',
                received >= spent ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryRow(String title, double amount, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '₹ ${_formatCurrency(amount)}',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceRow(
    String label,
    String value,
    String subtitle,
    Color valueColor,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  // -------------------- TAB 2: CLIENT INCOME / PAYMENTS --------------------
  Widget _buildClientIncomeTab(Color primaryColor, double totalReceived) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.getCollection('SitePayment')
          .where('siteId', isEqualTo: widget.siteId)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.hasData ? snapshot.data!.docs : <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          children: [
            // Income Summary Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF065F46), Color(0xFF047857)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF047857).withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Income Received',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Client Milestones & Payments',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '₹ ${_formatCurrency(totalReceived)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (docs.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 44,
                      color: Color(0xFF94A3B8),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'No individual payment records logged yet',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Amount recorded under total project paid balance',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...docs.map((doc) {
                final d = doc.data();
                final amt = _parseNum(d['amount'] ?? d['paymentAmount']);
                final date = _formatDate(d['paymentDate'] ?? d['date'] ?? d['createdAt']);
                final note = (d['notes'] ?? d['description'] ?? d['stageName'] ?? 'Client Payment').toString();

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.arrow_downward_rounded,
                                color: Color(0xFF10B981),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    note,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    date,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF64748B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '+ ₹ ${_formatCurrency(amt)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  DateTime _parseDateTimeVal(dynamic dateVal) {
    if (dateVal == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (dateVal is Timestamp) return dateVal.toDate();
    if (dateVal is DateTime) return dateVal;
    if (dateVal is String) {
      final parsed = DateTime.tryParse(dateVal);
      if (parsed != null) return parsed;
      try {
        return DateFormat('dd/MM/yyyy').parseLoose(dateVal);
      } catch (_) {}
      try {
        return DateFormat('yyyy-MM-dd').parseLoose(dateVal);
      } catch (_) {}
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  double _parseSupervisorDocAmount(Map<String, dynamic> d) {
    final amt = _parseNum(d['totalAmount'] ?? d['amount']);
    if (amt > 0) return amt;
    double sum = 0.0;
    sum += _parseNum(d['food']);
    sum += _parseNum(d['fuel']);
    sum += _parseNum(d['transport']);
    final labours = d['labours'];
    if (labours is List) {
      for (var l in labours) {
        if (l is Map) {
          final lAmt = _parseNum(l['amount']);
          if (lAmt > 0) {
            sum += lAmt;
          } else {
            sum += (_parseNum(l['count']) * _parseNum(l['unitSalary'] ?? l['salary']));
          }
        }
      }
    }
    final materials = d['materials'];
    if (materials is List) {
      for (var m in materials) {
        if (m is Map) {
          final mAmt = _parseNum(m['amount']);
          if (mAmt > 0) {
            sum += mAmt;
          } else {
            sum += (_parseNum(m['quantity'] ?? m['qty']) * _parseNum(m['unitPrice'] ?? m['price']));
          }
        }
      }
    }
    return sum;
  }

  // -------------------- TAB 3: ITEMIZED EXPENSES --------------------
  Widget _buildExpensesTab(Color primaryColor) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.getCollection('siteSupervisorEntries').snapshots(),
      builder: (context, supEntriesSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirestoreService.organizationEntries.snapshots(),
          builder: (context, orgExpSnap) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirestoreService.managerEntries.snapshots(),
              builder: (context, mgrExpSnap) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirestoreService.contractorEntries.snapshots(),
                  builder: (context, conExpSnap) {
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirestoreService.siteSupervisorIncentives.snapshots(),
                      builder: (context, incExpSnap) {
                        final List<Map<String, dynamic>> allExpenses = [];
                        final siteIdFilter = widget.siteId.trim();
                        final siteNameFilter = widget.siteName.trim();

                        bool matchesSite(Map<String, dynamic> d, String docId) {
                          if (siteIdFilter.isEmpty) return true;
                          final sId = (d['siteId'] ?? '').toString().trim();
                          final sSite = (d['site'] ?? '').toString().trim();
                          final sName = (d['siteName'] ?? '').toString().trim();
                          final sLoc = (d['siteLocation'] ?? '').toString().trim();

                          if (sId == siteIdFilter || sSite == siteIdFilter || sName == siteIdFilter || sLoc == siteIdFilter) {
                            return true;
                          }
                          if (siteNameFilter.isNotEmpty && (sId == siteNameFilter || sSite == siteNameFilter || sName == siteNameFilter || sLoc == siteNameFilter)) {
                            return true;
                          }
                          if (docId.startsWith('${siteIdFilter}_') || docId.toLowerCase().startsWith('${siteIdFilter.toLowerCase()}_')) {
                            return true;
                          }
                          return false;
                        }

                        if (supEntriesSnap.hasData) {
                          for (var doc in supEntriesSnap.data!.docs) {
                            final d = doc.data();
                            if (!matchesSite(d, doc.id)) continue;
                            final isMgr = d['isManagerEntry'] == true || d['createdBy'] == 'manager';
                            final isOrg = d['isOrgEntry'] == true || d['createdBy'] == 'manager_org';
                            final category = isOrg ? 'Organization' : (isMgr ? 'Manager' : 'Supervisor');
                            final title = d['expenseType'] ??
                                d['category'] ??
                                d['materialName'] ??
                                (d['projectStage'] != null && d['projectStage'].toString().isNotEmpty
                                    ? 'Site Entry - ${d['projectStage']}'
                                    : 'Daily Site Entry');
                            allExpenses.add({
                              'title': title,
                              'amount': _parseSupervisorDocAmount(d),
                              'date': d['date'] ?? d['createdAt'] ?? d['timestamp'],
                              'category': category,
                              'vendor': (d['vendorName'] ?? d['supplier'] ?? d['supervisorName'] ?? '').toString(),
                            });
                          }
                        }

                        if (orgExpSnap.hasData) {
                          for (var doc in orgExpSnap.data!.docs) {
                            final d = doc.data();
                            if (!matchesSite(d, doc.id)) continue;
                            final bills = d['bills'] as List<dynamic>? ?? [];
                            if (bills.isNotEmpty) {
                              for (var b in bills) {
                                if (b is Map) {
                                  allExpenses.add({
                                    'title': (b['billNo'] != null && b['billNo'].toString().isNotEmpty)
                                        ? 'Bill #${b['billNo']}'
                                        : (d['projectStage'] ?? 'Org Expense'),
                                    'amount': _parseNum(b['billAmount'] ?? b['amount']),
                                    'date': b['billDate'] ?? d['entryDate'] ?? d['date'] ?? d['createdAt'],
                                    'category': 'Organization',
                                    'vendor': (b['billVendor'] ?? '').toString(),
                                  });
                                }
                              }
                            } else {
                              allExpenses.add({
                                'title': d['projectStage'] ?? d['expenseName'] ?? d['description'] ?? 'Org Expense',
                                'amount': _parseNum(d['totalAmount'] ?? d['amount']),
                                'date': d['entryDate'] ?? d['date'] ?? d['createdAt'],
                                'category': 'Organization',
                                'vendor': (d['vendorName'] ?? '').toString(),
                              });
                            }
                          }
                        }

                        if (mgrExpSnap.hasData) {
                          for (var doc in mgrExpSnap.data!.docs) {
                            final d = doc.data();
                            if (!matchesSite(d, doc.id)) continue;
                            allExpenses.add({
                              'title': d['expenseType'] ?? d['category'] ?? d['materialName'] ?? 'Manager Entry',
                              'amount': _parseNum(d['totalAmount'] ?? d['amount']),
                              'date': d['date'] ?? d['createdAt'] ?? d['timestamp'],
                              'category': 'Manager',
                              'vendor': (d['vendorName'] ?? d['supplier'] ?? '').toString(),
                            });
                          }
                        }

                        if (conExpSnap.hasData) {
                          for (var doc in conExpSnap.data!.docs) {
                            final d = doc.data();
                            if (!matchesSite(d, doc.id)) continue;
                            allExpenses.add({
                              'title': d['contractorName'] ?? d['category'] ?? 'Contractor Payment',
                              'amount': _parseNum(d['totalAmount'] ?? d['amount']),
                              'date': d['date'] ?? d['createdAt'],
                              'category': 'Contractor',
                              'vendor': (d['contractorName'] ?? '').toString(),
                            });
                          }
                        }

                        if (incExpSnap.hasData) {
                          for (var doc in incExpSnap.data!.docs) {
                            final d = doc.data();
                            if (!matchesSite(d, doc.id)) continue;
                            allExpenses.add({
                              'title': d['supervisorName'] != null
                                  ? 'Incentive - ${d['supervisorName']}'
                                  : (d['role'] != null ? 'Incentive - ${d['role']}' : 'Supervisor Incentive'),
                              'amount': _parseNum(d['incentiveAmount'] ?? d['amount']),
                              'date': d['date'] ?? d['createdAt'],
                              'category': 'Incentive',
                              'vendor': (d['supervisorName'] ?? '').toString(),
                            });
                          }
                        }

                    // Sort newest to oldest
                    allExpenses.sort((a, b) {
                      final da = _parseDateTimeVal(a['date']);
                      final db = _parseDateTimeVal(b['date']);
                      return db.compareTo(da);
                    });

                    if (allExpenses.isEmpty) {
                      return Center(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_outlined,
                                size: 44,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'No detailed expenses recorded yet',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF475569),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Site expense entries will automatically appear here.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF94A3B8),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                      itemCount: allExpenses.length,
                      itemBuilder: (context, index) {
                        final exp = allExpenses[index];
                        final amt = exp['amount'] as double;
                        final dateStr = _formatDate(exp['date']);
                        final title = exp['title'].toString();
                        final cat = exp['category'].toString();
                        final vendor = exp['vendor'].toString();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.arrow_upward_rounded,
                                        color: Color(0xFFEF4444),
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF0F172A),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Text(
                                                dateStr,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                              if (vendor.isNotEmpty) ...[
                                                const Text(' • ', style: TextStyle(color: Color(0xFFCBD5E1))),
                                                Flexible(
                                                  child: Text(
                                                    vendor,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: Color(0xFF475569),
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                              const Text(' • ', style: TextStyle(color: Color(0xFFCBD5E1))),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF1F5F9),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  cat,
                                                  style: const TextStyle(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF475569),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '- ₹ ${_formatCurrency(amt)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  },
);
}
}
