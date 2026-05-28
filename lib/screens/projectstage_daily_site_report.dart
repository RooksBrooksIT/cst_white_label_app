import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_button.dart';
import '../utils/responsive.dart';
import '../utils/project_stage_pdf_helper.dart';
import './pdf_preview_page.dart';

class ProjectStageDailySiteExpensesReportPage extends StatefulWidget {
  final String supervisorId;
  final String? siteId;
  final DateTime date;
  final String projectStage;

  const ProjectStageDailySiteExpensesReportPage({
    super.key,
    required this.supervisorId,
    required this.siteId,
    required this.date,
    required this.projectStage,
  });

  @override
  State<ProjectStageDailySiteExpensesReportPage> createState() =>
      _ProjectStageDailySiteExpensesReportPageState();
}

class _ProjectStageDailySiteExpensesReportPageState
    extends State<ProjectStageDailySiteExpensesReportPage> {
  bool isLoading = true;
  Map<String, dynamic>? supervisorData;
  List<DocumentSnapshot> managerEntries = [];
  List<DocumentSnapshot> orgEntries = [];
  List<DocumentSnapshot> contractorEntries = [];
  double grandTotal = 0;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  String get _documentId {
    final formattedDate = DateFormat('ddMMyyyy').format(widget.date);
    return '${widget.siteId}_$formattedDate';
  }

  Future<void> _loadReport() async {
    setState(() => isLoading = true);
    try {
      final results = await Future.wait([
        FirestoreService.getCollection(
          'siteSupervisorEntries',
        ).doc(_documentId).get(),
        FirestoreService.getCollection(
          'managerExpenses',
        ).where('siteId', isEqualTo: widget.siteId).get(),
        FirestoreService.getCollection(
          'organizationExpenses',
        ).where('siteId', isEqualTo: widget.siteId).get(),
        FirestoreService.getCollection('contractorEntries')
            .where('siteId', isEqualTo: widget.siteId)
            .where(
              'date',
              isEqualTo: DateFormat('yyyy-MM-dd').format(widget.date),
            )
            .get(),
      ]);

      final supervisorDoc = results[0] as DocumentSnapshot;
      final managerSnap = results[1] as QuerySnapshot;
      final orgSnap = results[2] as QuerySnapshot;
      final contractorSnap = results[3] as QuerySnapshot;

      final targetStage = widget.projectStage.trim();
      final formattedDateYMD = DateFormat('yyyy-MM-dd').format(widget.date);

      // 1. Supervisor Data
      if (supervisorDoc.exists) {
        final data = supervisorDoc.data() as Map<String, dynamic>?;
        final docStage = (data?['projectStage'] ?? data?['projectField'])
            ?.toString()
            .trim();
        if (docStage == targetStage) {
          supervisorData = data;
        }
      }

      // 2. Manager Data (Filter by stage and date in bills)
      managerEntries = managerSnap.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final docStage = (data['projectStage'] ?? data['projectField'])
            ?.toString()
            .trim();
        if (docStage != targetStage) return false;

        final bills = data['bills'] as List? ?? [];
        return bills.any((bill) {
          final billDateRaw = bill['billDate'];
          String? billDateStr;
          if (billDateRaw is String)
            billDateStr = billDateRaw;
          else if (billDateRaw is Timestamp)
            billDateStr = DateFormat('yyyy-MM-dd').format(billDateRaw.toDate());
          return billDateStr == formattedDateYMD;
        });
      }).toList();

      // 3. Org Data (Filter by stage and date in bills)
      orgEntries = orgSnap.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final docStage = (data['projectStage'] ?? data['projectField'])
            ?.toString()
            .trim();
        if (docStage != targetStage) return false;

        final bills = data['bills'] as List? ?? [];
        return bills.any((bill) {
          final billDateRaw = bill['billDate'];
          String? billDateStr;
          if (billDateRaw is String)
            billDateStr = billDateRaw;
          else if (billDateRaw is Timestamp)
            billDateStr = DateFormat('yyyy-MM-dd').format(billDateRaw.toDate());
          return billDateStr == formattedDateYMD;
        });
      }).toList();

      // 4. Contractor Data (Already filtered by date in query, just check stage)
      contractorEntries = contractorSnap.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final docStage = (data['projectStage'] ?? data['projectField'])
            ?.toString()
            .trim();
        return docStage == targetStage;
      }).toList();

      _calculateGrandTotal();

      setState(() => isLoading = false);
    } catch (e) {
      print('Error loading report: $e');
      setState(() => isLoading = false);
    }
  }

  void _calculateGrandTotal() {
    double total = 0;
    final formattedDateYMD = DateFormat('yyyy-MM-dd').format(widget.date);

    // Supervisor Total
    if (supervisorData != null) {
      total += _toNum(supervisorData!['totalAmount']);
    }

    // Manager Total
    for (var doc in managerEntries) {
      final data = doc.data() as Map<String, dynamic>;
      final bills = data['bills'] as List? ?? [];
      for (var bill in bills) {
        final billDateRaw = bill['billDate'];
        String? billDateStr;
        if (billDateRaw is String)
          billDateStr = billDateRaw;
        else if (billDateRaw is Timestamp)
          billDateStr = DateFormat('yyyy-MM-dd').format(billDateRaw.toDate());

        if (billDateStr == formattedDateYMD) {
          total += _toNum(bill['billAmount']);
        }
      }
    }

    // Org Total
    for (var doc in orgEntries) {
      final data = doc.data() as Map<String, dynamic>;
      final bills = data['bills'] as List? ?? [];
      for (var bill in bills) {
        final billDateRaw = bill['billDate'];
        String? billDateStr;
        if (billDateRaw is String)
          billDateStr = billDateRaw;
        else if (billDateRaw is Timestamp)
          billDateStr = DateFormat('yyyy-MM-dd').format(billDateRaw.toDate());

        if (billDateStr == formattedDateYMD) {
          total += _toNum(bill['billAmount']);
        }
      }
    }

    // Contractor Total
    for (var doc in contractorEntries) {
      final data = doc.data() as Map<String, dynamic>;
      total += _toNum(data['totalAmount']);
    }

    grandTotal = total;
  }

  double _toNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);

    return GlassScaffold(
      title: 'Daily Site Report',
      actions: [
        IconButton(
          icon: const Icon(Icons.picture_as_pdf_outlined),
          onPressed: _generatePdf,
        ),
      ],
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : (supervisorData == null &&
                managerEntries.isEmpty &&
                orgEntries.isEmpty &&
                contractorEntries.isEmpty)
          ? _buildEmptyState(theme)
          : SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(theme),
                  const SizedBox(height: 24),
                  _buildTotalCard(theme),
                  const SizedBox(height: 24),
                  if (supervisorData != null) ...[
                    _buildCategoryBreakdown(theme),
                    const SizedBox(height: 24),
                  ],
                  if (managerEntries.isNotEmpty) ...[
                    _buildBillsBreakdown(
                      theme,
                      'Manager Expenses',
                      managerEntries,
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (orgEntries.isNotEmpty) ...[
                    _buildBillsBreakdown(
                      theme,
                      'Organization Expenses',
                      orgEntries,
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (contractorEntries.isNotEmpty) ...[
                    _buildContractorBreakdown(theme),
                    const SizedBox(height: 24),
                  ],
                  const SizedBox(height: 32),
                  GlassButton(
                    label: 'Generate PDF',
                    icon: Icons.picture_as_pdf_rounded,
                    onPressed: _generatePdf,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildBillsBreakdown(
    ThemeData theme,
    String title,
    List<DocumentSnapshot> entries,
  ) {
    final formattedDateYMD = DateFormat('yyyy-MM-dd').format(widget.date);
    double sectionTotal = 0;
    final List<Map<String, dynamic>> dailyBills = [];

    for (var doc in entries) {
      final data = doc.data() as Map<String, dynamic>;
      final bills = data['bills'] as List? ?? [];
      for (var bill in bills) {
        final billDateRaw = bill['billDate'];
        String? billDateStr;
        if (billDateRaw is String)
          billDateStr = billDateRaw;
        else if (billDateRaw is Timestamp)
          billDateStr = DateFormat('yyyy-MM-dd').format(billDateRaw.toDate());

        if (billDateStr == formattedDateYMD) {
          dailyBills.add(bill);
          sectionTotal += _toNum(bill['billAmount']);
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        ...dailyBills.map(
          (b) => _categoryItem(
            b['billVendor'] ?? 'Unknown Vendor',
            _toNum(b['billAmount']),
            Icons.receipt_long_outlined,
            theme,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, right: 8),
          child: Text(
            'Total: ₹ ${sectionTotal.toStringAsFixed(2)}',
            textAlign: TextAlign.end,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContractorBreakdown(ThemeData theme) {
    double sectionTotal = 0;
    for (var doc in contractorEntries) {
      sectionTotal += _toNum((doc.data() as Map)['totalAmount']);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CONTRACTOR EXPENSES',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        ...contractorEntries.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return _categoryItem(
            data['contractorName'] ?? 'Contractor Entry',
            _toNum(data['totalAmount']),
            Icons.construction_outlined,
            theme,
          );
        }),
        Padding(
          padding: const EdgeInsets.only(top: 4, right: 8),
          child: Text(
            'Total: ₹ ${sectionTotal.toStringAsFixed(2)}',
            textAlign: TextAlign.end,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No records found for this date',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DAILY SUMMARY',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            DateFormat('EEEE, dd MMMM yyyy').format(widget.date),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Stage: ${widget.projectStage}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard(ThemeData theme) {
    return GlassCard(
      color: theme.primaryColor,
      child: Column(
        children: [
          const Text(
            'TOTAL EXPENSES',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹ ${grandTotal.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CATEGORIES',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        _categoryItem(
          'Material Costs',
          _calculateMaterials(),
          Icons.shopping_bag_outlined,
          theme,
        ),
        _categoryItem(
          'Labour Charges',
          _calculateLabours(),
          Icons.people_outline,
          theme,
        ),
        _categoryItem(
          'Site Expenses',
          _calculateMisc(),
          Icons.miscellaneous_services_outlined,
          theme,
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _parseEntryList(dynamic rawData) {
    if (rawData == null) return [];
    if (rawData is List) {
      return rawData.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    if (rawData is Map) {
      final Map<dynamic, dynamic> map = rawData;
      final List<Map<String, dynamic>> list = [];
      final sortedKeys =
          map.keys
              .map((k) => int.tryParse(k.toString()))
              .where((k) => k != null)
              .cast<int>()
              .toList()
            ..sort();
      for (var key in sortedKeys) {
        final val = map[key.toString()] ?? map[key];
        if (val is Map) {
          list.add(Map<String, dynamic>.from(val));
        }
      }
      return list;
    }
    return [];
  }

  double _calculateMaterials() {
    double total = 0;
    final list = _parseEntryList(supervisorData?['materials']);
    for (var m in list) {
      total += _toNum(m['amount']);
    }
    return total;
  }

  double _calculateLabours() {
    double total = 0;
    final list = _parseEntryList(supervisorData?['labours']);
    for (var l in list) {
      total += _toNum(l['amount']);
    }
    return total;
  }

  double _calculateMisc() {
    return _toNum(supervisorData?['food']) +
        _toNum(supervisorData?['fuel']) +
        _toNum(supervisorData?['transport']);
  }

  Widget _categoryItem(
    String label,
    double amount,
    IconData icon,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: theme.primaryColor, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              '₹ ${amount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generatePdf() async {
    if (supervisorData == null &&
        managerEntries.isEmpty &&
        orgEntries.isEmpty &&
        contractorEntries.isEmpty)
      return;

    final pdfPrimaryColor = PdfColor.fromInt(
      Theme.of(context).primaryColor.value,
    );
    final formattedDateYMD = DateFormat('yyyy-MM-dd').format(widget.date);

    try {
      // Collect manager bills for this specific day
      final List<Map<String, dynamic>> managerBills = [];
      for (var doc in managerEntries) {
        final data = doc.data() as Map<String, dynamic>;
        final bills = data['bills'] as List? ?? [];
        for (var bill in bills) {
          final billDateRaw = bill['billDate'];
          String? billDateStr;
          if (billDateRaw is String)
            billDateStr = billDateRaw;
          else if (billDateRaw is Timestamp)
            billDateStr = DateFormat('yyyy-MM-dd').format(billDateRaw.toDate());
          if (billDateStr == formattedDateYMD) {
            managerBills.add(Map<String, dynamic>.from(bill));
          }
        }
      }

      // Collect org bills for this specific day
      final List<Map<String, dynamic>> organizationBills = [];
      for (var doc in orgEntries) {
        final data = doc.data() as Map<String, dynamic>;
        final bills = data['bills'] as List? ?? [];
        for (var bill in bills) {
          final billDateRaw = bill['billDate'];
          String? billDateStr;
          if (billDateRaw is String)
            billDateStr = billDateRaw;
          else if (billDateRaw is Timestamp)
            billDateStr = DateFormat('yyyy-MM-dd').format(billDateRaw.toDate());
          if (billDateStr == formattedDateYMD) {
            organizationBills.add(Map<String, dynamic>.from(bill));
          }
        }
      }

      // Collect contractor expenses
      final List<Map<String, dynamic>> contractorExpenses = contractorEntries
          .map((doc) => Map<String, dynamic>.from(doc.data() as Map))
          .toList();

      final pdfBytes = await ProjectStagePdfHelper.buildDailyReport(
        siteId: widget.siteId ?? 'N/A',
        supervisorId: widget.supervisorId,
        date: widget.date,
        projectStage: widget.projectStage,
        supervisorData: supervisorData,
        managerBills: managerBills,
        organizationBills: organizationBills,
        contractorExpenses: contractorExpenses,
        grandTotal: grandTotal,
        primaryColor: pdfPrimaryColor,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfPreviewPage(
            pdfBytes: pdfBytes,
            fileName:
                'DailyReport_${widget.siteId}_${DateFormat('ddMMyyyy').format(widget.date)}.pdf',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to generate PDF: $e')));
    }
  }
}
