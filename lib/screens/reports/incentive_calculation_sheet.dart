import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:ebricks/services/expense_service.dart';
import 'package:ebricks/services/firestore_service.dart';
import 'package:ebricks/services/approval_workflow_service.dart';
import 'package:ebricks/utils/pdf_templates.dart';
import 'package:ebricks/utils/app_theme.dart';
import 'package:ebricks/widgets/glass_scaffold.dart';

class LabourData {
  String labourType;
  int requested;
  int approved;
  int actual;
  int days;

  LabourData({
    required this.labourType,
    required this.requested,
    required this.approved,
    required this.actual,
    required this.days,
  });
}

class IncentiveCalculationSheet extends StatefulWidget {
  final String siteId;
  final String supervisor;
  final String projectStage;

  const IncentiveCalculationSheet({
    required this.siteId,
    required this.supervisor,
    required this.projectStage,
    super.key,
  });

  @override
  State<IncentiveCalculationSheet> createState() =>
      _IncentiveCalculationSheetState();
}

class _IncentiveCalculationSheetState extends State<IncentiveCalculationSheet> {
  Color get _primaryColor => Theme.of(context).primaryColor;
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _accentColor => _isDark ? AppTheme.getCardAccent(_primaryColor) : _primaryColor;
  Color get _cardColor => _isDark ? const Color(0xFF1E293B) : Colors.white;
  Color get _textColor => _isDark ? Colors.white : const Color(0xFF0A183D);
  Color get _subtextColor => _isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
  Color get _borderColor => _isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFCBD5E1);

  List<LabourData> _labourData = [];
  double _incentivePercentage = 10.0;

  // Amount totals (currency)
  double requestedTotal = 0;
  double approvedTotal = 0;
  double actualTotal = 0;

  // Derived
  double savedAmount = 0;

  // Days (for display only; not used in monetary math)
  int requestedDays = 0;
  int approvedDays = 0;
  int actualDays = 0;

  bool _loading = true;
  String? _resolvedProjectName;

  @override
  void initState() {
    super.initState();
    _fetchProjectName();
    _fetchLabourData();
  }

  Future<void> _fetchProjectName() async {
    try {
      final siteSnap = await FirestoreService.sites.doc(widget.siteId).get();
      if (siteSnap.exists) {
        setState(() {
          _resolvedProjectName = siteSnap.data()?['siteName']?.toString();
        });
      }

      if (_resolvedProjectName == null) {
        final projectSnap = await FirestoreService.projects
            .where('siteId', isEqualTo: widget.siteId)
            .limit(1)
            .get();
        if (projectSnap.docs.isNotEmpty) {
          setState(() {
            _resolvedProjectName = projectSnap.docs.first
                .data()['projectName']
                ?.toString();
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching project name: $e');
    }
  }

  Future<void> _fetchLabourData() async {
    if (!mounted) return;
    setState(() => _loading = true);

    if (!FirestoreService.isReady) {
      await FirestoreService.initialize();
    }

    final siteDetails = await ExpenseService.resolveSiteDetails(widget.siteId);
    final siteKeys = siteDetails.allKeys;
    final canonicalSiteDocId = siteDetails.canonicalDocId;

    debugPrint(
      'IncentiveSheet: Fetching data for Site="${widget.siteId}" (canonical="$canonicalSiteDocId"), Stage="${widget.projectStage}"',
    );

    // Fetch schedule, actuals, incentives and entries snapshots concurrently
    final snapshots = await Future.wait([
      FirestoreService.siteSupervisorProjectStageSchedule.get(),
      FirestoreService.siteSupervisorProjectStageActual.get(),
      FirestoreService.siteSupervisorIncentives.get(),
      FirestoreService.siteSupervisorEntries.get(),
    ]);

    final scheduleSnapshot = snapshots[0];
    final actualSnapshot = snapshots[1];
    final incentivesSnapshot = snapshots[2];
    final entriesSnapshot = snapshots[3];

    final stageTarget = widget.projectStage.trim().toLowerCase();

    bool matchesSite(Map<String, dynamic> data, String docId) {
      final dSiteId = (data['siteId'] ?? data['site'] ?? data['siteCode'] ?? '').toString().trim().toLowerCase();
      final dSiteName = (data['siteName'] ?? data['projectName'] ?? '').toString().trim().toLowerCase();
      final dDocId = docId.trim().toLowerCase();

      for (final k in siteKeys) {
        final lk = k.trim().toLowerCase();
        if (lk.isEmpty) continue;
        if (dSiteId == lk || dSiteName == lk || dDocId == lk) return true;
        if (dDocId.startsWith('${lk}_') || dDocId.contains(lk)) return true;
        if (dSiteId.contains(lk) || lk.contains(dSiteId)) return true;
      }
      return false;
    }

    bool matchesStage(Map<String, dynamic> data) {
      final dbStage = (data['projectStage'] ?? data['projectPhase'] ?? data['stage'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      return dbStage == stageTarget ||
          dbStage.replaceAll(' ', '') == stageTarget.replaceAll(' ', '') ||
          dbStage.contains(stageTarget) ||
          stageTarget.contains(dbStage);
    }

    // 1. Filter schedule docs
    final scheduleDocs = scheduleSnapshot.docs.where((doc) {
      return matchesSite(doc.data(), doc.id) && matchesStage(doc.data());
    }).toList();

    // Prioritize approved requests first, then newest
    scheduleDocs.sort((a, b) {
      final aData = a.data();
      final bData = b.data();
      final aApproved = ApprovalWorkflowService.parseStatus(aData['status'] ?? aData['approvalStatus']) == ApprovalStage.approved ||
          (aData['approvalStatus']?.toString().toLowerCase() == 'approved') ||
          (aData['status']?.toString().toLowerCase() == 'approved');
      final bApproved = ApprovalWorkflowService.parseStatus(bData['status'] ?? bData['approvalStatus']) == ApprovalStage.approved ||
          (bData['approvalStatus']?.toString().toLowerCase() == 'approved') ||
          (bData['status']?.toString().toLowerCase() == 'approved');
      if (aApproved && !bApproved) return -1;
      if (!aApproved && bApproved) return 1;

      final aDate = (aData['updatedAt'] ?? aData['createdAt']) as Timestamp?;
      final bDate = (bData['updatedAt'] ?? bData['createdAt']) as Timestamp?;
      if (aDate != null && bDate != null) {
        return bDate.compareTo(aDate);
      }
      return 0;
    });

    // 2. Filter actual docs from siteSupervisorProjectStageActual
    final actualDocs = actualSnapshot.docs.where((doc) {
      return matchesSite(doc.data(), doc.id) && matchesStage(doc.data());
    }).toList();

    // 3. Filter daily site entries as fallback / verification
    final entryDocs = entriesSnapshot.docs.where((doc) {
      return matchesSite(doc.data(), doc.id) && matchesStage(doc.data());
    }).toList();

    // 4. Check for existing saved incentive record to restore configured percentage
    Map<String, dynamic>? existingIncentiveData;
    for (final doc in incentivesSnapshot.docs) {
      final data = doc.data();
      if (matchesSite(data, doc.id) && matchesStage(data)) {
        existingIncentiveData = data;
        break;
      }
    }

    // Determine actual totals
    Map<String, int> actualCounts = {};
    double computedActualPayment = 0.0;
    int fetchedActualDays = 0;

    if (actualDocs.isNotEmpty) {
      final actualDoc = actualDocs.first.data();
      // In eBricks, actPayment in siteSupervisorProjectStageActual stores the cumulative total spent for this stage
      computedActualPayment = (actualDoc['actPayment'] ?? actualDoc['actualPayment'] ?? 0).toDouble();
      fetchedActualDays = (actualDoc['actDays'] ?? actualDoc['actualDays'] ?? 0) as int;

      final List actLabours = actualDoc['actLabours'] ?? [];
      for (var l in actLabours) {
        if (l is Map) {
          final designation = (l['labourDesignation'] ?? l['designation'] ?? l['type'] ?? '')
              .toString()
              .toLowerCase();
          final count = (l['labourCount'] ?? l['count'] ?? 0) as int;
          if (designation.isNotEmpty) {
            actualCounts[designation] = (actualCounts[designation] ?? 0) + count;
          }
        }
      }
    }

    // Fallback to siteSupervisorEntries if actual payment or days is missing or 0
    if (computedActualPayment == 0 && entryDocs.isNotEmpty) {
      final distinctDates = <String>{};
      for (var doc in entryDocs) {
        final d = doc.data();
        computedActualPayment += (d['totalAmount'] ?? d['amount'] ?? 0).toDouble();
        final dateStr = (d['date'] ?? doc.id).toString();
        distinctDates.add(dateStr);

        final labours = d['labours'];
        if (labours is List) {
          for (var l in labours) {
            if (l is Map) {
              final designation = (l['type'] ?? l['labourDesignation'] ?? '').toString().toLowerCase();
              final count = (l['count'] ?? l['labourCount'] ?? 0) as int;
              if (designation.isNotEmpty) {
                actualCounts[designation] = (actualCounts[designation] ?? 0) + count;
              }
            }
          }
        }
      }
      if (fetchedActualDays == 0) {
        fetchedActualDays = distinctDates.length;
      }
    }

    // Determine requested & approved data
    int rDays = 0;
    int aDays = 0;
    double reqAmount = 0.0;
    double appAmount = 0.0;
    Map<String, int> requestedMap = {};
    Map<String, int> approvedMap = {};

    if (scheduleDocs.isNotEmpty) {
      final doc = scheduleDocs.first.data();
      final isApproved = ApprovalWorkflowService.parseStatus(doc['status'] ?? doc['approvalStatus']) == ApprovalStage.approved ||
          (doc['approvalStatus']?.toString().toLowerCase() == 'approved') ||
          (doc['status']?.toString().toLowerCase() == 'approved');

      rDays = (doc['reqDays'] ?? doc['requestedDays'] ?? 0) as int;
      aDays = (doc['appDays'] ?? doc['approvedDays'] ?? (isApproved ? rDays : 0)) as int;

      reqAmount = (doc['estimatedPayment'] ?? doc['reqPayment'] ?? doc['requestedPayment'] ?? 0).toDouble();
      final rawAppPayment = (doc['approvedPayment'] ?? doc['approvedAmount'] ?? 0).toDouble();
      // If approved and no explicit override amount was entered, budget equals estimatedPayment
      appAmount = rawAppPayment > 0 ? rawAppPayment : (isApproved ? reqAmount : 0.0);

      // In incentive_flow.txt: actualTotal = actDays * actPayment (actPayment as per-day rate).
      // In site_entry_page.dart: actPayment accumulates total spend (existingActPayment + totalAmt).
      // Support both specifications safely without duplicate multiplication:
      if (fetchedActualDays > 1 && computedActualPayment > 0 && appAmount > 0 &&
          (computedActualPayment * fetchedActualDays <= appAmount * 1.5) &&
          (computedActualPayment < appAmount * 0.5)) {
        computedActualPayment = computedActualPayment * fetchedActualDays;
      }

      final List reqLabours = doc['reqLabours'] ?? [];
      final List appLabours = (doc['appLabours'] as List?)?.isNotEmpty == true
          ? (doc['appLabours'] as List)
          : (isApproved ? reqLabours : []);

      for (var l in reqLabours) {
        if (l is Map) {
          final des = (l['labourDesignation'] ?? l['designation'] ?? l['type'] ?? '').toString().toLowerCase();
          final cnt = (l['labourCount'] ?? l['count'] ?? 0) as int;
          if (des.isNotEmpty) requestedMap[des] = cnt;
        }
      }

      for (var l in appLabours) {
        if (l is Map) {
          final des = (l['labourDesignation'] ?? l['designation'] ?? l['type'] ?? '').toString().toLowerCase();
          final cnt = (l['labourCount'] ?? l['count'] ?? 0) as int;
          if (des.isNotEmpty) approvedMap[des] = cnt;
        }
      }
    }

    // If actual counts accumulated across multiple days, normalize to average daily count for display table
    final normalizedActualCounts = <String, int>{};
    for (var entry in actualCounts.entries) {
      if (fetchedActualDays > 1) {
        normalizedActualCounts[entry.key] = (entry.value / fetchedActualDays).round();
      } else {
        normalizedActualCounts[entry.key] = entry.value;
      }
    }

    final allDesignations = <String>{
      ...requestedMap.keys,
      ...approvedMap.keys,
      ...normalizedActualCounts.keys,
    };

    List<LabourData> loadedLabourData = allDesignations.map((designation) {
      return LabourData(
        labourType: designation.isNotEmpty
            ? designation[0].toUpperCase() + designation.substring(1)
            : '',
        requested: requestedMap[designation] ?? 0,
        approved: approvedMap[designation] ?? 0,
        actual: normalizedActualCounts[designation] ?? 0,
        days: 0,
      );
    }).toList();

    // Monetary math: clamp savings to >= 0
    double computedSavedAmount = math.max(appAmount - computedActualPayment, 0.0);

    // Restore previously saved incentive percentage if exists
    double restoredPercentage = _incentivePercentage;
    if (existingIncentiveData != null) {
      final savedPct = (existingIncentiveData['incentivePercentage'] as num?)?.toDouble();
      if (savedPct != null && savedPct > 0) {
        restoredPercentage = savedPct;
      }
    }

    if (!mounted) return;
    setState(() {
      _labourData = loadedLabourData;
      requestedTotal = reqAmount;
      approvedTotal = appAmount;
      actualTotal = computedActualPayment;
      savedAmount = computedSavedAmount;
      _incentivePercentage = restoredPercentage;

      requestedDays = rDays;
      approvedDays = aDays;
      actualDays = fetchedActualDays;

      _loading = false;
    });
  }

  Future<bool> _showUnsavedChangesDialog() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Unsaved Changes',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('Please save your data before leaving this page.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Leave', style: TextStyle(color: _primaryColor)),
          ),
        ],
      ),
    );
    return shouldLeave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;
    final maxContentWidth = 900.0;

    if (!_loading && (requestedDays == 0 || actualDays == 0)) {
      return GlassScaffold(
        title: 'Incentive Sheet',
        onBack: () => Navigator.pop(context),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, size: 48, color: _accentColor),
                    const SizedBox(height: 16),
                    Text(
                      'Request is not available for this site.',
                      style: TextStyle(
                        color: _textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Site ID: ${widget.siteId}\nStage: ${widget.projectStage}',
                      style: TextStyle(color: _subtextColor),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _fetchLabourData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'RETRY',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final darkAccent = AppTheme.getDarkAccent(_primaryColor);

    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: AppBar(
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Incentive Sheet',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  darkAccent,
                  Color.alphaBlend(
                    _primaryColor.withValues(alpha: 0.35),
                    darkAccent,
                  ),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(child: CircularProgressIndicator(color: _primaryColor)),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        final shouldLeave = await _showUnsavedChangesDialog();
        if (shouldLeave && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: AppBar(
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Incentive Calculation Sheet',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  darkAccent,
                  Color.alphaBlend(
                    _primaryColor.withValues(alpha: 0.35),
                    darkAccent,
                  ),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
            onPressed: () async {
              final shouldLeave = await _showUnsavedChangesDialog();
              if (shouldLeave && context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 20),
              tooltip: 'Export PDF Report',
              onPressed: _generatePdf,
            ),
          ],
        ),  body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 24 : (isTablet ? 20 : 16),
                vertical: 16,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: Column(
                    children: [
                      _headerCard(),
                      const SizedBox(height: 20),
                      _daysSummaryCard(),
                      const SizedBox(height: 20),
                      _labourTableSection(),
                      const SizedBox(height: 20),
                      _summaryCards(),
                      const SizedBox(height: 20),
                      _incentiveSlider(),
                      const SizedBox(height: 30),
                      _actionButtons(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _labourTableSection() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 24,
          horizontalMargin: 16,
          headingRowHeight: 48,
          dataRowMinHeight: 40,
          dataRowMaxHeight: 48,
          headingRowColor: WidgetStateProperty.all(
            _isDark ? _primaryColor.withValues(alpha: 0.25) : _primaryColor.withValues(alpha: 0.08),
          ),
          headingTextStyle: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: _textColor,
          ),
          columns: const [
            DataColumn(label: Text('Labour Type')),
            DataColumn(label: Text('Requested'), numeric: true),
            DataColumn(label: Text('Approved'), numeric: true),
            DataColumn(label: Text('Actual'), numeric: true),
          ],
          rows: [
            ..._labourData.map(
              (data) => DataRow(
                cells: [
                  DataCell(
                    Text(data.labourType, style: TextStyle(color: _textColor, fontWeight: FontWeight.w600)),
                  ),
                  DataCell(
                    Text(
                      '${data.requested}',
                      style: TextStyle(color: _textColor),
                    ),
                  ),
                  DataCell(
                    Text(
                      '${data.approved}',
                      style: TextStyle(color: _textColor),
                    ),
                  ),
                  DataCell(
                    Text('${data.actual}', style: TextStyle(color: _textColor)),
                  ),
                ],
              ),
            ),
            DataRow(
              color: WidgetStateProperty.resolveWith<Color>((
                Set<WidgetState> states,
              ) {
                return _primaryColor.withValues(alpha: 0.08);
              }),
              cells: [
                DataCell(
                  Text('Total', style: TextStyle(fontWeight: FontWeight.w800, color: _textColor)),
                ),
                DataCell(
                  Text(
                    '₹${requestedTotal.toStringAsFixed(2)}',
                    style: TextStyle(fontWeight: FontWeight.w800, color: _textColor),
                  ),
                ),
                DataCell(
                  Text(
                    '₹${approvedTotal.toStringAsFixed(2)}',
                    style: TextStyle(fontWeight: FontWeight.w800, color: _textColor),
                  ),
                ),
                DataCell(
                  Text(
                    '₹${(actualTotal).toStringAsFixed(2)}',
                    style: TextStyle(fontWeight: FontWeight.w800, color: _accentColor),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _incentiveSlider() {
    final liveIncentive = savedAmount * (_incentivePercentage / 100);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Incentive Percentage',
                    style: TextStyle(
                      color: _textColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Customizable 0% - 100%',
                    style: TextStyle(
                      fontSize: 12,
                      color: _subtextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: savedAmount > 0
                      ? _primaryColor.withValues(alpha: 0.12)
                      : Colors.grey.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: savedAmount > 0
                        ? _primaryColor.withValues(alpha: 0.3)
                        : Colors.grey.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Incentive: ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: savedAmount > 0 ? _primaryColor : Colors.grey,
                      ),
                    ),
                    Text(
                      '₹${liveIncentive.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: savedAmount > 0 ? _primaryColor : Colors.grey,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Slider(
            value: _incentivePercentage.clamp(0.0, 100.0),
            min: 0,
            max: 100,
            divisions: 100,
            label: '${_incentivePercentage.round()}%',
            activeColor: _primaryColor,
            inactiveColor: _primaryColor.withValues(alpha: 0.2),
            onChanged: savedAmount > 0
                ? (value) {
                    setState(() {
                      _incentivePercentage = value;
                    });
                  }
                : null,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0%', style: TextStyle(color: _subtextColor, fontWeight: FontWeight.w700)),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _primaryColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '${_incentivePercentage.round()}%',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
              Text('100%', style: TextStyle(color: _subtextColor, fontWeight: FontWeight.w700)),
            ],
          ),
          if (savedAmount <= 0) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFEE2E2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Color(0xFFDC2626), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your incentive is not allocated for this site (Actual spend exceeds approved budget).',
                      style: TextStyle(
                        color: Color(0xFF991B1B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _summaryCard('Estimated Payment', requestedTotal, const Color(0xFF3B82F6)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _summaryCard('Approved Payment', approvedTotal, _primaryColor),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _summaryCard('Actual Payment', actualTotal, const Color(0xFFEF4444)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _summaryCard(
                'Savings Amount',
                savedAmount,
                const Color(0xFF10B981),
                isHighlighted: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _summaryCard(String label, double amount, Color color, {bool isHighlighted = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighlighted ? const Color(0xFFECFDF5) : _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHighlighted ? const Color(0xFF10B981) : color.withValues(alpha: 0.4),
          width: isHighlighted ? 2.0 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isHighlighted ? 0.18 : 0.08),
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
              if (isHighlighted) ...[
                const Icon(Icons.savings_rounded, color: Color(0xFF10B981), size: 16),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isHighlighted ? const Color(0xFF047857) : color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 18.5,
              color: isHighlighted ? const Color(0xFF065F46) : color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _daysSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stepChip(
            Icons.assignment_rounded,
            'Requested',
            requestedDays,
            const Color(0xFF3B82F6),
          ),
          _stepChip(
            Icons.verified_rounded,
            'Approved',
            approvedDays,
            const Color(0xFFF59E0B),
          ),
          _stepChip(
            Icons.today_rounded,
            'Actual',
            actualDays,
            const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }

  Widget _headerCard() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoColumn(Icons.location_on_rounded, 'Site ID', widget.siteId),
          const SizedBox(height: 14),
          _infoColumn(Icons.person_rounded, 'Supervisor', widget.supervisor),
          const SizedBox(height: 14),
          _infoColumn(Icons.construction_rounded, 'Stage', widget.projectStage),
        ],
      ),
    );
  }

  Widget _infoColumn(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _accentColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: _subtextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                softWrap: true,
                style: TextStyle(
                  fontSize: 15,
                  color: _textColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepChip(IconData icon, String label, int value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: color,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$value',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: color,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check_circle_rounded, size: 18),
            label: const Text(
              'Save',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
              shadowColor: _primaryColor.withValues(alpha: 0.4),
            ),
            onPressed: _save,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text(
              'Cancel',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _textColor,
              side: BorderSide(color: _borderColor),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final leave = await _showUnsavedChangesDialog();
              if (leave) {
                if (mounted) Navigator.pop(context);
              }
            },
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final amountToAdd = savedAmount * (_incentivePercentage / 100);

    // Guard against non-positive writes
    if (amountToAdd <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incentive amount must be greater than 0'),
        ),
      );
      return;
    }

    try {
      final siteDetails = await ExpenseService.resolveSiteDetails(widget.siteId);
      final canonicalSiteDocId = siteDetails.canonicalDocId.isNotEmpty
          ? siteDetails.canonicalDocId
          : await ExpenseService.resolveCanonicalSiteDocId(widget.siteId);

      final cleanStage = widget.projectStage.trim().replaceAll(' ', '_');
      final cleanSup = widget.supervisor.trim().replaceAll(' ', '_');

      // Standardized canonical document ID: e.g. ST001_AbineshHouse_John_Foundation or ST001_AbineshHouse_Foundation
      final docId = cleanSup.isNotEmpty
          ? '${canonicalSiteDocId}_${cleanSup}_$cleanStage'
          : '${canonicalSiteDocId}_$cleanStage';

      // 1) Save detailed incentive document for history/audit
      await FirestoreService.siteSupervisorIncentives.doc(docId).set({
        'siteId': canonicalSiteDocId,
        'rawSiteId': widget.siteId,
        'siteCode': siteDetails.siteCode,
        'siteName': siteDetails.siteName,
        'projectName': _resolvedProjectName ?? siteDetails.siteName,
        'projectStage': widget.projectStage,
        'supervisorName': widget.supervisor,
        'actualAmount': actualTotal,
        'approvedAmount': approvedTotal,
        'estimatedAmount': requestedTotal,
        'savedAmount': savedAmount,
        'incentivePercentage': _incentivePercentage.round(),
        'incentiveAmount': amountToAdd,
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Clean up any legacy or duplicate document variants for this site & stage
      final candidateLegacyDocIds = <String>{
        '${widget.siteId}_${widget.supervisor}_${widget.projectStage}',
        '${widget.siteId}__${widget.projectStage}',
        '${canonicalSiteDocId}__$cleanStage',
        '${widget.siteId}_$cleanStage',
      };
      candidateLegacyDocIds.remove(docId);
      for (final legId in candidateLegacyDocIds) {
        try {
          final legDoc = await FirestoreService.siteSupervisorIncentives.doc(legId).get();
          if (legDoc.exists) {
            await FirestoreService.siteSupervisorIncentives.doc(legId).delete();
          }
        } catch (_) {}
      }

      // 2) Dynamically calculate total incentive expenses across all stages for this site to prevent overwriting
      double totalSiteIncentives = 0.0;
      final siteKeys = siteDetails.allKeys;
      final incentiveQuerySnaps = await Future.wait([
        FirestoreService.siteSupervisorIncentives.get(),
      ]);
      for (final doc in incentiveQuerySnaps.first.docs) {
        final data = doc.data();
        final docSiteId = (data['siteId'] ?? '').toString().trim().toLowerCase();
        final docSiteCode = (data['siteCode'] ?? '').toString().trim().toLowerCase();
        final docDocId = doc.id.trim().toLowerCase();
        final isMatch = siteKeys.any((k) {
          final lk = k.trim().toLowerCase();
          return lk.isNotEmpty && (docSiteId == lk || docSiteCode == lk || docDocId.startsWith('${lk}_') || docDocId.contains(lk));
        });
        if (isMatch) {
          final val = (data['incentiveAmount'] ?? data['amount'] ?? 0) as num;
          totalSiteIncentives += val.toDouble();
        }
      }
      if (totalSiteIncentives <= 0) {
        totalSiteIncentives = amountToAdd;
      }

      // Update totalIncentiveExpenses in totalSiteExpensesPerDay for this siteId (strictly using canonical doc ID)
      await FirestoreService.totalSiteExpensesPerDay.doc(canonicalSiteDocId).set({
        'siteId': canonicalSiteDocId,
        'totalIncentiveExpenses': totalSiteIncentives,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Clean up legacy duplicate document in totalSiteExpensesPerDay if widget.siteId was non-canonical
      if (widget.siteId != canonicalSiteDocId) {
        try {
          final legacyDoc = await FirestoreService.totalSiteExpensesPerDay
              .doc(widget.siteId)
              .get();
          if (legacyDoc.exists) {
            await FirestoreService.totalSiteExpensesPerDay
                .doc(widget.siteId)
                .delete();
          }
        } catch (_) {}
      }

      // 3) Trigger totals recalculation for this site (sync all values across project & site)
      await ExpenseService.updateTotalSiteExpense(canonicalSiteDocId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Data saved successfully. (Incentive: ₹${amountToAdd.toStringAsFixed(2)})'),
          backgroundColor: _primaryColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _generatePdf() async {
    final pdf = pw.Document();
    final pdfPrimaryColor = PdfColor.fromInt(_primaryColor.toARGB32());
    final orgDetails = await PdfTemplates.fetchOrgDetails();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => PdfTemplates.buildHeader(
          reportTitle: 'Incentive Calculation Sheet',
          orgDetails: orgDetails,
          primaryColor: pdfPrimaryColor,
        ),
        build: (pw.Context context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              PdfTemplates.buildMetaBox(
                'Project',
                _resolvedProjectName ?? widget.siteId,
                pdfPrimaryColor,
              ),
              PdfTemplates.buildMetaBox(
                'Site ID',
                widget.siteId,
                pdfPrimaryColor,
              ),
              PdfTemplates.buildMetaBox(
                'Supervisor',
                widget.supervisor,
                pdfPrimaryColor,
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              PdfTemplates.buildMetaBox(
                'Stage',
                widget.projectStage,
                pdfPrimaryColor,
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              PdfTemplates.buildMetaBox(
                'Saved Amount',
                '₹ ${savedAmount.toStringAsFixed(2)}',
                pdfPrimaryColor,
              ),
              PdfTemplates.buildMetaBox(
                'Incentive %',
                '${_incentivePercentage.round()}%',
                pdfPrimaryColor,
              ),
              PdfTemplates.buildMetaBox(
                'Incentive Amount',
                '₹ ${(savedAmount * (_incentivePercentage / 100)).toStringAsFixed(2)}',
                pdfPrimaryColor,
              ),
            ],
          ),
          pw.SizedBox(height: 32),
          pw.Text(
            'Labour Breakdown',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: ['Labour Type', 'Requested', 'Approved', 'Actual'],
            data: _labourData
                .map(
                  (l) => [
                    l.labourType,
                    l.requested.toString(),
                    l.approved.toString(),
                    l.actual.toString(),
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(color: pdfPrimaryColor),
            cellAlignment: pw.Alignment.centerLeft,
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
          ),
          pw.SizedBox(height: 24),
          pw.TableHelper.fromTextArray(
            headers: [
              'Metric',
              'Requested Total',
              'Approved Total',
              'Actual Total',
            ],
            data: [
              [
                'Amount',
                '₹ ${requestedTotal.toStringAsFixed(2)}',
                '₹ ${approvedTotal.toStringAsFixed(2)}',
                '₹ ${actualTotal.toStringAsFixed(2)}',
              ],
              [
                'Days',
                requestedDays.toString(),
                approvedDays.toString(),
                actualDays.toString(),
              ],
              [
                'Savings',
                '-',
                '-',
                '₹ ${savedAmount.toStringAsFixed(2)}',
              ],
              [
                'Incentive (${_incentivePercentage.round()}%)',
                '-',
                '-',
                '₹ ${(savedAmount * (_incentivePercentage / 100)).toStringAsFixed(2)}',
              ],
            ],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(color: pdfPrimaryColor),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
        footer: (context) => PdfTemplates.buildFooter(context),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}
