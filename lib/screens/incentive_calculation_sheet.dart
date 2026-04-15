import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/expense_service.dart';
import '../utils/pdf_templates.dart';

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
  Color get _accentColor => Theme.of(context).colorScheme.secondary;
  Color get _backgroundColor => Theme.of(context).scaffoldBackgroundColor;
  Color get _cardColor => Theme.of(context).cardColor;
  Color get _textColor => Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF2d3748);

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

  @override
  void initState() {
    super.initState();
    _fetchLabourData();
  }

  Future<void> _fetchLabourData() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final scheduleQuery = await FirebaseFirestore.instance
        .collection('siteSupervisorProjectStageSchedule')
        .where('siteId', isEqualTo: widget.siteId)
        .where('projectStage', isEqualTo: widget.projectStage)
        .limit(1)
        .get();

    final actualQuery = await FirebaseFirestore.instance
        .collection('siteSupervisorProjectStageActual')
        .where('siteId', isEqualTo: widget.siteId)
        .where('projectStage', isEqualTo: widget.projectStage)
        .limit(1)
        .get();

    Map<String, int> actualCounts = {};
    double actualAmountPerDay = 0; // per-day actual amount
    int fetchedActualDays = 0;

    if (actualQuery.docs.isNotEmpty) {
      final actualDoc = actualQuery.docs.first.data();
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

    // Fetch days summary (requested/approved/actual)
    final daysSummary = await _fetchDaysSummary();

    if (scheduleQuery.docs.isNotEmpty) {
      final doc = scheduleQuery.docs.first.data();
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
          labourType: designation[0].toUpperCase() + designation.substring(1),
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

        requestedDays = daysSummary['requested'] ?? 0;
        approvedDays = daysSummary['approved'] ?? 0;
        actualDays = daysSummary['actual'] ?? 0;

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

        requestedDays = daysSummary['requested'] ?? 0;
        approvedDays = daysSummary['approved'] ?? 0;
        actualDays = daysSummary['actual'] ?? 0;

        _loading = false;
      });
    }
  }

  Future<Map<String, int>> _fetchDaysSummary() async {
    final scheduleQuery = await FirebaseFirestore.instance
        .collection('siteSupervisorProjectStageSchedule')
        .where('siteId', isEqualTo: widget.siteId)
        .where('projectStage', isEqualTo: widget.projectStage)
        .limit(1)
        .get();

    int rDays = 0;
    int aDays = 0;
    if (scheduleQuery.docs.isNotEmpty) {
      final doc = scheduleQuery.docs.first.data();
      rDays = (doc['reqDays'] ?? 0) as int;
      aDays = (doc['appDays'] ?? 0) as int;
    }

    final actualQuery = await FirebaseFirestore.instance
        .collection('siteSupervisorProjectStageActual')
        .where('siteId', isEqualTo: widget.siteId)
        .where('projectStage', isEqualTo: widget.projectStage)
        .limit(1)
        .get();

    int actDays = 0;
    if (actualQuery.docs.isNotEmpty) {
      actDays = (actualQuery.docs.first.data()['actDays'] ?? 0) as int;
    }

    return {'requested': rDays, 'approved': aDays, 'actual': actDays};
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
    if (requestedDays == 0 ||
        approvedDays == 0 ||
        actualDays == 0 && !_loading) {
      // Show message when requestedDays is 0 and data loading complete
      return Scaffold(
        backgroundColor: _backgroundColor,
        appBar: AppBar(
          backgroundColor: _primaryColor,
          title: const Text(
            'Incentive Sheet',
            style: TextStyle(),
          ),
          iconTheme: const IconThemeData(),
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, size: 48, color: _primaryColor),
                const SizedBox(height: 16),
                Text(
                  'Request is not available for this site.',
                  style: TextStyle(
                    color: _primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        return await _showUnsavedChangesDialog();
      },
      child: Scaffold(
        backgroundColor: _backgroundColor,
        appBar: AppBar(
          backgroundColor: _primaryColor,
          title: const Text(
            'Incentive Sheet',
            style: TextStyle(),
          ),
          iconTheme: const IconThemeData(),
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: _generatePdf,
            ),
          ],
        ),
        body: _loading
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
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
    );
  }

  Widget _labourTableSection() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: _cardColor,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 24,
          horizontalMargin: 16,
          headingRowHeight: 50,
          dataRowHeight: 40,
          headingRowColor: WidgetStateProperty.all(
            _primaryColor.withOpacity(0.9),
          ),
          headingTextStyle: const TextStyle(
            
            fontWeight: FontWeight.w600,
            fontSize: 14,
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
                    Text(data.labourType, style: TextStyle(color: _textColor)),
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
                return _primaryColor.withOpacity(0.05);
              }),
              cells: [
                const DataCell(
                  Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                DataCell(
                  Text(
                    '₹${requestedTotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataCell(
                  Text(
                    '₹${approvedTotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataCell(
                  Text(
                    '₹${(actualTotal).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
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
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      color: _cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Incentive Percentage',
              style: TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.w600,
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
              inactiveColor: _primaryColor.withOpacity(0.3),
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
                Text('0%', style: TextStyle(color: _primaryColor)),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_incentivePercentage.round()}%',
                    style: const TextStyle(
                      
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text('20%', style: TextStyle(color: _primaryColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCards() {
    return Row(
      children: [
        Expanded(
          child: _summaryCard('Saved Amount', savedAmount, _primaryColor),
        ),
        const SizedBox(width: 12),
        savedAmount > 0
            ? Expanded(
                child: _summaryCard(
                  'Incentive',
                  savedAmount * (_incentivePercentage / 100),
                  _accentColor,
                ),
              )
            : Expanded(
                child: Card(
                  color: _cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.info_outline, color: _primaryColor),
                        const SizedBox(height: 8),
                        Text(
                          'Your incentive is not allocated for this site.',
                          style: TextStyle(
                            color: _primaryColor,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ],
    );
  }

  Widget _summaryCard(String label, double amount, Color color) {
    return Card(
      color: _cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.2), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '₹${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 18,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _daysSummaryCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: _cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _stepChip(
              Icons.assignment,
              'Requested',
              requestedDays,
              const Color(0xFF4299e1),
            ),
            _stepChip(
              Icons.verified,
              'Approved',
              approvedDays,
              const Color(0xFFed8936),
            ),
            _stepChip(
              Icons.today,
              'Actual',
              actualDays,
              const Color(0xFF48bb78),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: _cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoColumn(Icons.location_on, 'Site', widget.siteId),
            const SizedBox(height: 16),
            _infoColumn(Icons.person, 'Supervisor', widget.supervisor),
            const SizedBox(height: 16),
            _infoColumn(Icons.construction, 'Stage', widget.projectStage),
          ],
        ),
      ),
    );
  }

  Widget _infoColumn(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _primaryColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: _primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                softWrap: true,
                style: TextStyle(
                  fontSize: 14,
                  color: _textColor,
                  fontWeight: FontWeight.bold,
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
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: color,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$value',
            style: TextStyle(
              fontWeight: FontWeight.bold,
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
        _styledButton('Save', _save, _primaryColor, Colors.white),
        const SizedBox(width: 12),
        _styledButton(
          'Cancel',
          () async {
            final leave = await _showUnsavedChangesDialog();
            if (leave) {
              if (mounted) Navigator.pop(context);
            }
          },
          Colors.white,
          _primaryColor,
          border: true,
        ),
      ],
    );
  }

  Widget _styledButton(
    String label,
    VoidCallback onPressed,
    Color bg,
    Color fg, {
    bool border = false,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        side: border ? BorderSide(color: _primaryColor, width: 1) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
      child: Text(label, style: TextStyle(fontWeight: FontWeight.w600)),
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
      await FirebaseFirestore.instance
          .collection('siteSupervisorIncentives')
          .doc(docId)
          .set({
            'siteId': widget.siteId,
            'projectName':
                widget.siteId, // Adjust if you have a separate project name
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
      await FirebaseFirestore.instance
          .collection('totalSiteExpensesPerDay')
          .doc(widget.siteId)
          .set({
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

  void _reset() {
    setState(() {
      for (var data in _labourData) {
        data.requested = 0;
        data.approved = 0;
        data.actual = 0;
      }
      _incentivePercentage = 10.0;
      requestedTotal = 0;
      approvedTotal = 0;
      actualTotal = 0;
      savedAmount = 0;

      requestedDays = 0;
      approvedDays = 0;
      actualDays = 0;
    });
  }

  Future<void> _generatePdf() async {
    final pdf = pw.Document();
    final pdfPrimaryColor = PdfColor.fromInt(_primaryColor.value);
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
              PdfTemplates.buildMetaBox('Site ID', widget.siteId, pdfPrimaryColor),
              PdfTemplates.buildMetaBox('Supervisor', widget.supervisor, pdfPrimaryColor),
              PdfTemplates.buildMetaBox('Stage', widget.projectStage, pdfPrimaryColor),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              PdfTemplates.buildMetaBox('Saved Amount', '₹ ${savedAmount.toStringAsFixed(2)}', pdfPrimaryColor),
              PdfTemplates.buildMetaBox('Incentive %', '${_incentivePercentage.round()}%', pdfPrimaryColor),
              PdfTemplates.buildMetaBox('Incentive Amount', '₹ ${(savedAmount * (_incentivePercentage / 100)).toStringAsFixed(2)}', pdfPrimaryColor),
            ],
          ),
          pw.SizedBox(height: 32),
          pw.Text('Labour Breakdown', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: ['Labour Type', 'Requested', 'Approved', 'Actual'],
            data: _labourData.map((l) => [
              l.labourType,
              l.requested.toString(),
              l.approved.toString(),
              l.actual.toString()
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: pdfPrimaryColor),
            cellAlignment: pw.Alignment.centerLeft,
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
          ),
          pw.SizedBox(height: 24),
          pw.Table.fromTextArray(
            headers: ['Metric', 'Requested Total', 'Approved Total', 'Actual Total'],
            data: [
              ['Amount', '₹ ${requestedTotal.toStringAsFixed(2)}', '₹ ${approvedTotal.toStringAsFixed(2)}', '₹ ${actualTotal.toStringAsFixed(2)}'],
              ['Days', requestedDays.toString(), approvedDays.toString(), actualDays.toString()],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
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
