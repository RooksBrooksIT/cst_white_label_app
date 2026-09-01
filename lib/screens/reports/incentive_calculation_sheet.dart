import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:demo_cst/services/expense_service.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/pdf_templates.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';

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

    debugPrint(
      'IncentiveSheet: Fetching data for Site="${widget.siteId}", Stage="${widget.projectStage}"',
    );
    debugPrint('IncentiveSheet: OrgID is "${FirestoreService.currentOrgId}"');

    var scheduleSnapshot = await FirestoreService
        .siteSupervisorProjectStageSchedule
        .get();

    var actualSnapshot = await FirestoreService
        .siteSupervisorProjectStageActual
        .get();

    // Fallback to root collections if empty and org is initialized
    if (scheduleSnapshot.docs.isEmpty && FirestoreService.currentOrgId != 'uninitialized') {
      try {
        final rootSched = await FirebaseFirestore.instance.collection('siteSupervisorProjectStageSchedule').get();
        if (rootSched.docs.isNotEmpty) scheduleSnapshot = rootSched;
      } catch (_) {}
    }
    if (actualSnapshot.docs.isEmpty && FirestoreService.currentOrgId != 'uninitialized') {
      try {
        final rootAct = await FirebaseFirestore.instance.collection('siteSupervisorProjectStageActual').get();
        if (rootAct.docs.isNotEmpty) actualSnapshot = rootAct;
      } catch (_) {}
    }

    // Filter in memory for robustness (case-insensitive and trimmed)
    final siteId = widget.siteId.trim().toLowerCase();
    final stage = widget.projectStage.trim().toLowerCase();

    final scheduleDocs = scheduleSnapshot.docs.where((doc) {
      final data = doc.data();
      final dbSiteId = (data['siteId'] ?? data['site'] ?? data['siteCode'] ?? data['siteName'] ?? doc.id).toString().trim().toLowerCase();
      final dbStage = (data['projectStage'] ?? data['projectPhase'] ?? data['stage'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final isMatch = (dbSiteId == siteId || doc.id.toLowerCase() == siteId) && dbStage == stage;
      if (!isMatch && scheduleSnapshot.docs.length < 10) {
        debugPrint(
          'IncentiveSheet: No match for schedule doc ${doc.id}. DB(Site: "$dbSiteId", Stage: "$dbStage") vs Search(Site: "$siteId", Stage: "$stage")',
        );
      }
      return isMatch;
    }).toList();

    final actualDocs = actualSnapshot.docs.where((doc) {
      final data = doc.data();
      final dbSiteId = (data['siteId'] ?? data['site'] ?? data['siteCode'] ?? data['siteName'] ?? doc.id).toString().trim().toLowerCase();
      final dbStage = (data['projectStage'] ?? data['projectPhase'] ?? data['stage'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final isMatch = (dbSiteId == siteId || doc.id.toLowerCase() == siteId) && dbStage == stage;
      if (!isMatch && actualSnapshot.docs.length < 10) {
        debugPrint(
          'IncentiveSheet: No match for actual doc ${doc.id}. DB(Site: "$dbSiteId", Stage: "$dbStage") vs Search(Site: "$siteId", Stage: "$stage")',
        );
      }
      return isMatch;
    }).toList();

    debugPrint(
      'IncentiveSheet: Schedule Docs Found (filtered): ${scheduleDocs.length}',
    );
    debugPrint(
      'IncentiveSheet: Actual Docs Found (filtered): ${actualDocs.length}',
    );

    Map<String, int> actualCounts = {};
    double actualAmountPerDay = 0; // per-day actual amount
    int fetchedActualDays = 0;

    if (actualDocs.isNotEmpty) {
      final actualDoc = actualDocs.first.data();
      actualAmountPerDay = (actualDoc['actPayment'] ?? 0).toDouble();
      final List actLabours = actualDoc['actLabours'] ?? [];
      for (var l in actLabours) {
        final designation = (l['labourDesignation'] ?? '')
            .toString()
            .toLowerCase();
        final count = (l['labourCount'] ?? 0) as int;
        if (designation.isNotEmpty) {
          actualCounts[designation] = (actualCounts[designation] ?? 0) + count;
        }
      }
      fetchedActualDays = (actualDoc['actDays'] ?? 0) as int;
    }

    // Days summary variables
    int rDays = 0;
    int aDays = 0;
    int actDaysCount = fetchedActualDays;

    if (scheduleDocs.isNotEmpty) {
      final doc = scheduleDocs.first.data();
      rDays = (doc['reqDays'] ?? 0) as int;
      aDays = (doc['appDays'] ?? 0) as int;

      final List reqLabours = doc['reqLabours'] ?? [];
      final List appLabours = doc['appLabours'] ?? [];

      Map<String, int> requestedMap = {
        for (var l in reqLabours)
          (l['labourDesignation'] as String).toLowerCase():
              l['labourCount'] ?? 0,
      };
      Map<String, int> approvedMap = {
        for (var l in appLabours)
          (l['labourDesignation'] as String).toLowerCase():
              l['labourCount'] ?? 0,
      };

      final allDesignations = <String>{
        ...requestedMap.keys,
        ...approvedMap.keys,
        ...actualCounts.keys,
      };

      List<LabourData> loadedLabourData = allDesignations.map((designation) {
        return LabourData(
          labourType: designation.isNotEmpty
              ? designation[0].toUpperCase() + designation.substring(1)
              : '',
          requested: requestedMap[designation] ?? 0,
          approved: approvedMap[designation] ?? 0,
          actual: actualCounts[designation] ?? 0,
          days: 0,
        );
      }).toList();

      // Compute actualTotal as actualDays * actualAmountPerDay
      double computedActualTotal = fetchedActualDays * actualAmountPerDay;

      if (!mounted) return;
      setState(() {
        _labourData = loadedLabourData;
        requestedTotal = (doc['estimatedPayment'] ?? 0).toDouble();
        approvedTotal = (doc['approvedPayment'] ?? 0).toDouble();
        actualTotal = computedActualTotal;

        // Monetary math: clamp savings to >= 0
        savedAmount = math.max(approvedTotal - actualTotal, 0);

        requestedDays = rDays;
        approvedDays = aDays;
        actualDays = actDaysCount;

        _loading = false;
      });
    } else {
      // Use fetchedActualDays and actualAmountPerDay to compute actualTotal
      double computedActualTotal = fetchedActualDays * actualAmountPerDay;

      if (!mounted) return;
      setState(() {
        _labourData = [];
        requestedTotal = 0;
        approvedTotal = 0;
        actualTotal = computedActualTotal;

        savedAmount = math.max(approvedTotal - actualTotal, 0);

        requestedDays = 0;
        approvedDays = 0;
        actualDays = actDaysCount;

        _loading = false;
      });
    }
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

    if (!_loading && requestedDays == 0 && actualDays == 0) {
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
                      'No request data found for this site and stage.',
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
          Text(
            'Incentive Percentage',
            style: TextStyle(
              color: _textColor,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Slider(
            value: _incentivePercentage,
            min: 0,
            max: 20,
            divisions: 20,
            label: '${_incentivePercentage.round()}%',
            activeColor: _primaryColor,
            inactiveColor: _primaryColor.withValues(alpha: 0.2),
            onChanged: (value) {
              if (value > 20) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Percentage cannot exceed 20%'),
                  ),
                );
              } else {
                setState(() {
                  _incentivePercentage = value;
                });
              }
            },
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
              Text('20%', style: TextStyle(color: _subtextColor, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryCards() {
    return Row(
      children: [
        Expanded(
          child: _summaryCard('Saved Amount', savedAmount, _accentColor),
        ),
        const SizedBox(width: 12),
        savedAmount > 0
            ? Expanded(
                child: _summaryCard(
                  'Incentive',
                  savedAmount * (_incentivePercentage / 100),
                  _primaryColor,
                ),
              )
            : Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _borderColor),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.info_outline, color: _accentColor),
                      const SizedBox(height: 8),
                      Text(
                        'Your incentive is not allocated for this site.',
                        style: TextStyle(
                          color: _textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
      ],
    );
  }

  Widget _summaryCard(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 19,
              color: color,
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
    final docId =
        '${widget.siteId}_${widget.supervisor}_${widget.projectStage}';

    // Compute and round to nearest rupee
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
      // 1) Save detailed incentive document for history/audit
      await FirestoreService.siteSupervisorIncentives.doc(docId).set({
        'siteId': widget.siteId,
        'projectName': _resolvedProjectName ?? widget.siteId,
        'projectStage': widget.projectStage,
        'supervisorName': widget.supervisor,
        'actualAmount': actualTotal,
        'approvedAmount': approvedTotal,
        'estimatedAmount': requestedTotal,
        'savedAmount': savedAmount,
        'incentivePercentage': _incentivePercentage.round(),
        'incentiveAmount': amountToAdd,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 2) Update totalIncentiveExpenses in totalSiteExpensesPerDay for this siteId
      await FirestoreService.totalSiteExpensesPerDay.doc(widget.siteId).set({
        'totalIncentiveExpenses': amountToAdd,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3) Trigger totals recalculation for this site (sync all values)
      await ExpenseService.updateTotalSiteExpense(widget.siteId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Data saved successfully'),
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
          pw.Table.fromTextArray(
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
          pw.Table.fromTextArray(
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
