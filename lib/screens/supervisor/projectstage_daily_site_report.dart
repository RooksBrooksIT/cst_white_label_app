import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/services/firestore_service.dart';
import 'package:ebricks/services/expense_service.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import '/widgets/glass_scaffold.dart';
import '/widgets/glass_card.dart';
import '/widgets/glass_button.dart';
import '/utils/responsive.dart';
import '/utils/project_stage_pdf_helper.dart';
import 'package:ebricks/screens/reports/pdf_preview_page.dart';

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
  Map<String, String> siteHeader = {};
  List<DocumentSnapshot> managerEntries = [];
  List<DocumentSnapshot> orgEntries = [];
  List<DocumentSnapshot> contractorEntries = [];
  List<Map<String, dynamic>> pettyCashEntries = [];
  double grandTotal = 0;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => isLoading = true);
    try {
      final siteKeys = (await ExpenseService.resolveSiteKeys(widget.siteId ?? '')).toList();
      final ddMMyyyy = DateFormat('ddMMyyyy').format(widget.date);
      final yyyyMMdd = DateFormat('yyyy-MM-dd').format(widget.date);

      // Attempt direct doc gets for supervisor entries first
      final docIdsToTry = <String>{};
      for (final key in siteKeys) {
        docIdsToTry.add('${key}_$ddMMyyyy');
        docIdsToTry.add('${key}_$yyyyMMdd');
      }

      DocumentSnapshot? foundSupervisorDoc;
      for (final docId in docIdsToTry) {
        try {
          final doc = await FirestoreService.getCollection('siteSupervisorEntries').doc(docId).get();
          if (doc.exists) {
            foundSupervisorDoc = doc;
            break;
          }
        } catch (_) {}
      }

      final results = await Future.wait([
        _fetchCollectionBySite('siteSupervisorEntries', siteKeys),
        _fetchCollectionBySite('managerExpenses', siteKeys),
        _fetchCollectionBySite('organizationExpenses', siteKeys),
        _fetchCollectionBySite('contractorEntries', siteKeys),
        _fetchCollectionBySite('managerEntries', siteKeys),
        _fetchCollectionBySite('organizationEntries', siteKeys),
      ]);

      final supervisorDocs = results[0];
      final managerDocs = results[1];
      final orgDocs = results[2];
      final contractorDocs = results[3];
      final managerEntryDocs = results[4];
      final orgEntryDocs = results[5];

      final targetStage = widget.projectStage.trim().toLowerCase();

      bool filterEntry(DocumentSnapshot doc) {
        final data = doc.data() as Map<String, dynamic>;
        final docStage = (data['projectStage'] ?? data['projectField'] ?? data['stage'])
            ?.toString()
            .trim()
            .toLowerCase();
        if (docStage != null && targetStage.isNotEmpty && docStage != targetStage) {
          return false;
        }

        // 1. Check top-level date
        final rawDate = data['date'] ?? data['entryDate'] ?? data['createdAt'] ?? data['updatedAt'];
        if (ExpenseService.isSameDay(rawDate, widget.date)) return true;

        // 2. Check bills list
        final bills = data['bills'] as List? ?? [];
        return bills.any((bill) {
          if (bill is Map) {
            final billDateRaw = bill['billDate'] ?? bill['date'];
            return ExpenseService.isSameDay(billDateRaw, widget.date);
          }
          return false;
        });
      }

      // 1. Supervisor Data
      if (foundSupervisorDoc != null && foundSupervisorDoc.exists) {
        final data = foundSupervisorDoc.data() as Map<String, dynamic>?;
        final docStage = (data?['projectStage'] ?? data?['projectField'] ?? data?['stage'])
            ?.toString()
            .trim()
            .toLowerCase();
        if (docStage == null || targetStage.isEmpty || docStage == targetStage) {
          supervisorData = data;
        }
      }

      if (supervisorData == null) {
        for (final doc in supervisorDocs) {
          if (filterEntry(doc)) {
            supervisorData = doc.data() as Map<String, dynamic>;
            break;
          }
        }
      }

      // 2. Manager Data
      managerEntries = [
        ...managerDocs.where(filterEntry),
        ...managerEntryDocs.where(filterEntry),
      ];

      // 3. Org Data
      orgEntries = [
        ...orgDocs.where(filterEntry),
        ...orgEntryDocs.where(filterEntry),
      ];

      // 4. Contractor Data
      contractorEntries = contractorDocs.where(filterEntry).toList();

      // 5. Petty Cash Data
      pettyCashEntries = await ExpenseService.fetchPettyCashForSite(
        siteId: widget.siteId ?? '',
        date: widget.date,
        projectStage: widget.projectStage,
      );

      _calculateGrandTotal();

      final resolvedHeader = await _resolveHeaderDetails(
        siteKeys: siteKeys,
        supervisorEntryData: supervisorData,
      );

      setState(() {
        siteHeader = resolvedHeader;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading report: $e');
      setState(() => isLoading = false);
    }
  }

  Future<Map<String, String>> _resolveHeaderDetails({
    required List<String> siteKeys,
    Map<String, dynamic>? supervisorEntryData,
  }) async {
    String siteName = '';
    String supervisorName = '';
    String siteAddress = '';

    final rawSiteId = (widget.siteId ?? '').trim();

    // 1. Resolve canonical details via ExpenseService
    if (rawSiteId.isNotEmpty) {
      try {
        final details = await ExpenseService.resolveSiteDetails(rawSiteId);
        if (details.siteName.trim().isNotEmpty) {
          siteName = details.siteName.trim();
        } else if (details.projectName != null &&
            details.projectName!.trim().isNotEmpty) {
          siteName = details.projectName!.trim();
        }

        if (details.supervisor != null && details.supervisor!.trim().isNotEmpty) {
          supervisorName = details.supervisor!.trim();
        }

        if (details.location != null && details.location!.trim().isNotEmpty) {
          siteAddress = details.location!.trim();
        }
      } catch (e) {
        debugPrint('ProjectStageDailySiteReport: Error resolving SiteDetails: $e');
      }
    }

    // 2. Extract from supervisorEntryData if available
    if (supervisorEntryData != null) {
      if (siteName.isEmpty) {
        final fromEntry = (supervisorEntryData['projectName'] ??
                supervisorEntryData['siteName'] ??
                supervisorEntryData['site'])
            ?.toString()
            .trim();
        if (fromEntry != null && fromEntry.isNotEmpty) {
          siteName = fromEntry;
        }
      }

      if (supervisorName.isEmpty) {
        final fromEntry = (supervisorEntryData['supervisorName'] ??
                supervisorEntryData['userName'] ??
                supervisorEntryData['supervisor'])
            ?.toString()
            .trim();
        if (fromEntry != null && fromEntry.isNotEmpty) {
          supervisorName = fromEntry;
        }
      }

      if (siteAddress.isEmpty) {
        final fromEntry = (supervisorEntryData['siteLocation'] ??
                supervisorEntryData['location'] ??
                supervisorEntryData['address'] ??
                supervisorEntryData['siteAddress'])
            ?.toString()
            .trim();
        if (fromEntry != null && fromEntry.isNotEmpty) {
          siteAddress = fromEntry;
        }
      }
    }

    // 3. Fallback: Query 'Site' collection directly
    if (siteName.isEmpty || siteAddress.isEmpty || supervisorName.isEmpty) {
      final keysToCheck = [if (rawSiteId.isNotEmpty) rawSiteId, ...siteKeys];
      for (final key in keysToCheck) {
        if (key.isEmpty) continue;
        try {
          final doc = await FirestoreService.sites.doc(key).get();
          if (doc.exists && doc.data() != null) {
            final data = doc.data()!;
            if (siteName.isEmpty) {
              final n = (data['siteName'] ?? data['name'] ?? data['projectName'])
                  ?.toString()
                  .trim();
              if (n != null && n.isNotEmpty) siteName = n;
            }
            if (siteAddress.isEmpty) {
              final a = (data['address'] ??
                      data['siteAddress'] ??
                      data['location'] ??
                      data['siteLocation'])
                  ?.toString()
                  .trim();
              if (a != null && a.isNotEmpty) siteAddress = a;
            }
            if (supervisorName.isEmpty) {
              final s = (data['supervisor'] ?? data['supervisorName'])
                  ?.toString()
                  .trim();
              if (s != null && s.isNotEmpty) supervisorName = s;
            }
          }
        } catch (_) {}
        if (siteName.isNotEmpty &&
            siteAddress.isNotEmpty &&
            supervisorName.isNotEmpty) {
          break;
        }
      }
    }

    // 4. Fallback: Query 'projects' collection directly
    if (siteName.isEmpty || siteAddress.isEmpty || supervisorName.isEmpty) {
      final keysToCheck = [if (rawSiteId.isNotEmpty) rawSiteId, ...siteKeys];
      for (final key in keysToCheck) {
        if (key.isEmpty) continue;
        try {
          final doc = await FirestoreService.projects.doc(key).get();
          if (doc.exists && doc.data() != null) {
            final data = doc.data()!;
            if (siteName.isEmpty) {
              final n = (data['siteName'] ??
                      data['projectName'] ??
                      data['name'])
                  ?.toString()
                  .trim();
              if (n != null && n.isNotEmpty) siteName = n;
            }
            if (siteAddress.isEmpty) {
              final a = (data['location'] ??
                      data['address'] ??
                      data['siteLocation'] ??
                      data['siteAddress'])
                  ?.toString()
                  .trim();
              if (a != null && a.isNotEmpty) siteAddress = a;
            }
            if (supervisorName.isEmpty) {
              final s = (data['supervisor'] ?? data['supervisorName'])
                  ?.toString()
                  .trim();
              if (s != null && s.isNotEmpty) supervisorName = s;
            }
          }
        } catch (_) {}
        if (siteName.isNotEmpty &&
            siteAddress.isNotEmpty &&
            supervisorName.isNotEmpty) {
          break;
        }
      }
    }

    // 5. Fallback: Query 'supervisors' collection for Supervisor Name
    if (supervisorName.isEmpty) {
      final supId = widget.supervisorId.trim();
      if (supId.isNotEmpty) {
        try {
          final supDoc = await FirestoreService.supervisors.doc(supId).get();
          if (supDoc.exists && supDoc.data() != null) {
            final data = supDoc.data()!;
            final n = (data['name'] ??
                    data['supervisorName'] ??
                    data['userName'] ??
                    data['fullName'])
                ?.toString()
                .trim();
            if (n != null && n.isNotEmpty) supervisorName = n;
          }
        } catch (_) {}

        if (supervisorName.isEmpty) {
          try {
            final q = await FirestoreService.supervisors
                .where('supervisorId', isEqualTo: supId)
                .limit(1)
                .get();
            if (q.docs.isNotEmpty) {
              final data = q.docs.first.data();
              final n = (data['name'] ??
                      data['supervisorName'] ??
                      data['userName'] ??
                      data['fullName'])
                  ?.toString()
                  .trim();
              if (n != null && n.isNotEmpty) supervisorName = n;
            }
          } catch (_) {}
        }

        if (supervisorName.isEmpty &&
            !supId.contains(RegExp(r'^[0-9a-fA-F\-]{16,}'))) {
          supervisorName = supId;
        }
      }
    }

    // 6. Ensure clean fallbacks
    if (siteName.isEmpty) {
      siteName = rawSiteId.isNotEmpty ? rawSiteId : 'N/A';
    }
    if (supervisorName.isEmpty) {
      supervisorName = 'N/A';
    }
    if (siteAddress.isEmpty) {
      siteAddress = 'N/A';
    }

    return {
      'siteName': siteName,
      'supervisorName': supervisorName,
      'siteAddress': siteAddress,
    };
  }

  Future<List<DocumentSnapshot>> _fetchCollectionBySite(
    String collection,
    List<String> siteKeys,
  ) async {
    final keysToQuery = siteKeys.take(10).toList();
    final snapshots = await Future.wait([
      FirestoreService.getCollection(
        collection,
      ).where('siteId', whereIn: keysToQuery).get(),
      FirestoreService.getCollection(
        collection,
      ).where('site', whereIn: keysToQuery).get(),
    ]);
    final seen = <String>{};
    final docs = <DocumentSnapshot>[];
    for (var doc in [...snapshots[0].docs, ...snapshots[1].docs]) {
      if (seen.add(doc.id)) {
        docs.add(doc);
      }
    }
    return docs;
  }

  void _calculateGrandTotal() {
    double total = 0;

    // Supervisor Total
    if (supervisorData != null) {
      total += _toNum(supervisorData!['totalAmount']);
    }

    // Manager Total
    for (var doc in managerEntries) {
      final data = doc.data() as Map<String, dynamic>;
      final bills = data['bills'] as List? ?? [];
      if (bills.isNotEmpty) {
        for (var bill in bills) {
          if (bill is Map) {
            final billDateRaw = bill['billDate'] ?? bill['date'];
            if (ExpenseService.isSameDay(billDateRaw, widget.date)) {
              total += _toNum(bill['billAmount'] ?? bill['amount']);
            }
          }
        }
      } else {
        final rawDate = data['date'] ?? data['entryDate'] ?? data['createdAt'];
        if (ExpenseService.isSameDay(rawDate, widget.date)) {
          total += _toNum(data['totalAmount'] ?? data['amount']);
        }
      }
    }

    // Org Total
    for (var doc in orgEntries) {
      final data = doc.data() as Map<String, dynamic>;
      final bills = data['bills'] as List? ?? [];
      if (bills.isNotEmpty) {
        for (var bill in bills) {
          if (bill is Map) {
            final billDateRaw = bill['billDate'] ?? bill['date'];
            if (ExpenseService.isSameDay(billDateRaw, widget.date)) {
              total += _toNum(bill['billAmount'] ?? bill['amount']);
            }
          }
        }
      } else {
        final rawDate = data['date'] ?? data['entryDate'] ?? data['createdAt'];
        if (ExpenseService.isSameDay(rawDate, widget.date)) {
          total += _toNum(data['totalAmount'] ?? data['amount']);
        }
      }
    }

    // Contractor Total
    for (var doc in contractorEntries) {
      final data = doc.data() as Map<String, dynamic>;
      total += _toNum(data['totalAmount'] ?? data['amount']);
    }

    // Petty Cash Total
    for (var pc in pettyCashEntries) {
      total += _toNum(pc['amount']);
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
      onBack: () => Navigator.pop(context),
      appBarForegroundColor: Colors.white,
      actions: [
        IconButton(
          icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white),
          onPressed: _generatePdf,
        ),
      ],
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
          child: isLoading
          ? SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeaderSkeleton(theme),
                  const SizedBox(height: 48),
                  const Center(child: CircularProgressIndicator()),
                ],
              ),
            )
          : (supervisorData == null &&
                managerEntries.isEmpty &&
                orgEntries.isEmpty &&
                contractorEntries.isEmpty &&
                pettyCashEntries.isEmpty)
          ? _buildEmptyState(theme)
          : SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSiteHeaderSummary(theme, siteHeader),
                  const SizedBox(height: 16),
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
                  if (pettyCashEntries.isNotEmpty) ...[
                    _buildPettyCashBreakdown(theme),
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
        ),
      ),
    );
  }

  Widget _buildBillsBreakdown(
    ThemeData theme,
    String title,
    List<DocumentSnapshot> entries,
  ) {
    double sectionTotal = 0;
    final List<Map<String, dynamic>> dailyBills = [];

    for (var doc in entries) {
      final data = doc.data() as Map<String, dynamic>;
      final bills = data['bills'] as List? ?? [];
      if (bills.isNotEmpty) {
        for (var bill in bills) {
          if (bill is Map) {
            final billDateRaw = bill['billDate'] ?? bill['date'];
            if (ExpenseService.isSameDay(billDateRaw, widget.date)) {
              dailyBills.add(Map<String, dynamic>.from(bill));
              sectionTotal += _toNum(bill['billAmount'] ?? bill['amount']);
            }
          }
        }
      } else {
        final rawDate = data['date'] ?? data['entryDate'] ?? data['createdAt'];
        if (ExpenseService.isSameDay(rawDate, widget.date)) {
          dailyBills.add({
            'billVendor': data['vendorName'] ?? data['category'] ?? title,
            'billAmount': data['totalAmount'] ?? data['amount'] ?? 0,
          });
          sectionTotal += _toNum(data['totalAmount'] ?? data['amount']);
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
    final isMobile = Responsive.isMobile(context);
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSiteHeaderSummary(theme, siteHeader),
          const SizedBox(height: 48),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 64,
                  color: Colors.grey.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No records found for this date',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSkeleton(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final shimmerColor = isDark ? Colors.white10 : const Color(0xFFE2E8F0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: shimmerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: shimmerColor,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 70, height: 10, color: shimmerColor),
                    const SizedBox(height: 6),
                    Container(width: 140, height: 16, color: shimmerColor),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: shimmerColor, height: 1),
          ),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(width: 60, height: 9, color: shimmerColor),
                          const SizedBox(height: 4),
                          Container(width: 90, height: 13, color: shimmerColor),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(width: 60, height: 9, color: shimmerColor),
                          const SizedBox(height: 4),
                          Container(width: 100, height: 13, color: shimmerColor),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSiteHeaderSummary(
      ThemeData theme, Map<String, dynamic> siteHeader) {
    final siteName =
        (siteHeader['siteName']?.toString().trim().isNotEmpty == true)
            ? siteHeader['siteName'].toString().trim()
            : 'N/A';
    final supervisorName =
        (siteHeader['supervisorName']?.toString().trim().isNotEmpty == true)
            ? siteHeader['supervisorName'].toString().trim()
            : 'N/A';
    final siteAddress =
        (siteHeader['siteAddress']?.toString().trim().isNotEmpty == true)
            ? siteHeader['siteAddress'].toString().trim()
            : 'N/A';

    final primaryColor = theme.primaryColor;
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);
    final labelColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Site Name
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    Icon(Icons.business_rounded, color: primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SITE NAME',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: labelColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      siteName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: borderColor, height: 1),
          ),
          // 2. Supervisor Name & 3. Site Address (Responsive Layout)
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 420;
              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderDetailItem(
                      icon: Icons.person_rounded,
                      label: 'SUPERVISOR NAME',
                      value: supervisorName,
                      iconColor: const Color(0xFF0284C7),
                      labelColor: labelColor,
                      textColor: textColor,
                    ),
                    const SizedBox(height: 12),
                    _buildHeaderDetailItem(
                      icon: Icons.location_on_rounded,
                      label: 'SITE ADDRESS',
                      value: siteAddress,
                      iconColor: const Color(0xFFE11D48),
                      labelColor: labelColor,
                      textColor: textColor,
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildHeaderDetailItem(
                      icon: Icons.person_rounded,
                      label: 'SUPERVISOR NAME',
                      value: supervisorName,
                      iconColor: const Color(0xFF0284C7),
                      labelColor: labelColor,
                      textColor: textColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildHeaderDetailItem(
                      icon: Icons.location_on_rounded,
                      label: 'SITE ADDRESS',
                      value: siteAddress,
                      iconColor: const Color(0xFFE11D48),
                      labelColor: labelColor,
                      textColor: textColor,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderDetailItem({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
    required Color labelColor,
    required Color textColor,
  }) {
    final isUnset = value == 'N/A' ||
        value == 'Not Available' ||
        value == 'Not Assigned';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: labelColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isUnset ? FontWeight.normal : FontWeight.w600,
                  fontStyle: isUnset ? FontStyle.italic : FontStyle.normal,
                  color: isUnset ? labelColor : textColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
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

  Widget _buildPettyCashBreakdown(ThemeData theme) {
    double total = 0;
    for (var pc in pettyCashEntries) {
      total += _toNum(pc['amount']);
    }
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PETTY CASH EXPENSES',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.2,
                  color: theme.primaryColor,
                ),
              ),
              Text(
                '₹ ${total.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...pettyCashEntries.map((pc) {
            final cat = pc['category'] ?? 'Petty Cash';
            final desc = pc['description']?.toString() ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$cat${desc.isNotEmpty ? " - $desc" : ""}',
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                    ),
                  ),
                  Text(
                    '₹ ${_toNum(pc['amount']).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _generatePdf() async {
    if (supervisorData == null &&
        managerEntries.isEmpty &&
        orgEntries.isEmpty &&
        contractorEntries.isEmpty &&
        pettyCashEntries.isEmpty) {
      return;
    }

    final pdfPrimaryColor = PdfColor.fromInt(
      Theme.of(context).primaryColor.toARGB32(),
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
          DateTime? billDate;
          if (billDateRaw is Timestamp) {
            billDate = billDateRaw.toDate();
          } else if (billDateRaw is String) {
            billDate = DateTime.tryParse(billDateRaw);
          }

          if (billDate != null) {
            final billDateStr = DateFormat('yyyy-MM-dd').format(billDate);
            if (billDateStr == formattedDateYMD) {
              managerBills.add(Map<String, dynamic>.from(bill));
            }
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
          DateTime? billDate;
          if (billDateRaw is Timestamp) {
            billDate = billDateRaw.toDate();
          } else if (billDateRaw is String) {
            billDate = DateTime.tryParse(billDateRaw);
          }

          if (billDate != null) {
            final billDateStr = DateFormat('yyyy-MM-dd').format(billDate);
            if (billDateStr == formattedDateYMD) {
              organizationBills.add(Map<String, dynamic>.from(bill));
            }
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
        pettyCashExpenses: pettyCashEntries,
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
