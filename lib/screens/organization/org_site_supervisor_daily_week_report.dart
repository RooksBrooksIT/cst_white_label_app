import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/utils/pdf_templates.dart';
import 'dart:async';
import 'package:demo_cst/widgets/glass_scaffold.dart';

class DailySitePaymentReportScreen extends StatefulWidget {
  const DailySitePaymentReportScreen({super.key});

  @override
  _DailySitePaymentReportScreenState createState() =>
      _DailySitePaymentReportScreenState();
}

class _DailySitePaymentReportScreenState
    extends State<DailySitePaymentReportScreen> {
  List<String> siteIds = [];
  Map<String, Map<String, String>> siteDetails = {};

  String? selectedSiteId;
  String? selectedProject;
  String? selectedSupervisor;

  final TextEditingController projectController = TextEditingController();
  final TextEditingController supervisorController = TextEditingController();

  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;

  int? selectedWeekIndex;
  List<DateTime> weekDates = [];
  List<Map<String, dynamic>> paymentRecords = [];
  double totalAmount = 0.0;

  List<int> years = List.generate(
    5,
    (index) => DateTime.now().year - 2 + index,
  );

  @override
  void initState() {
    super.initState();
    _fetchSiteIdsAndDetails();
  }

  Future<void> _fetchSiteIdsAndDetails() async {
    try {
      // 1. Fetch all site mappings
      final mappingSnapshot = await FirestoreService.siteSupervisorMap
          .get()
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      final ids = <String>{};
      final details = <String, Map<String, String>>{};

      for (var doc in mappingSnapshot.docs) {
        final data = doc.data();
        final siteId = data['site']?.toString() ?? doc.id;
        if (siteId.isNotEmpty) {
          ids.add(siteId);

          // Read projectName directly from the siteSupervisorMap document first
          final docProjectName = data['projectName']?.toString() ?? '';

          details[siteId] = {
            'project': docProjectName,
            'supervisor': data['supervisor']?.toString() ?? '',
          };

          // Fallback: try to extract project name from siteId pattern (siteName_projectName)
          // Only use this if projectName wasn't found in the document
          if (docProjectName.isEmpty && siteId.contains('_')) {
            final parts = siteId.split('_');
            if (parts.length > 1) {
              details[siteId]!['project'] = parts.sublist(1).join('_');
            }
          }
        }
      }

      // 2. Fetch Projects to enhance/override project names where available
      final projectsSnapshot = await FirestoreService.projects.get();
      for (var doc in projectsSnapshot.docs) {
        final data = doc.data();
        final siteId = data['siteId']?.toString();
        final fetchedProjectName = data['projectName']?.toString() ?? '';
        // Only override if we get a non-empty name from projects collection
        if (siteId != null &&
            details.containsKey(siteId) &&
            fetchedProjectName.isNotEmpty) {
          details[siteId]!['project'] = fetchedProjectName;
        }
      }

      if (mounted) {
        setState(() {
          siteIds = ids.toList()..sort();
          siteDetails = details;
        });
      }
    } catch (e) {
      debugPrint('Error fetching site IDs and details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load site data')),
        );
      }
    }
  }

  void _updateProjectAndSupervisor() {
    if (selectedSiteId != null && siteDetails.containsKey(selectedSiteId)) {
      final project = siteDetails[selectedSiteId]!['project'] ?? '';
      final supervisor = siteDetails[selectedSiteId]!['supervisor'] ?? '';
      projectController.text = project;
      supervisorController.text = supervisor;
      // Also update state variables and trigger rebuild
      setState(() {
        selectedProject = project.isNotEmpty ? project : null;
        selectedSupervisor = supervisor.isNotEmpty ? supervisor : null;
      });
    } else {
      projectController.text = '';
      supervisorController.text = '';
      setState(() {
        selectedProject = null;
        selectedSupervisor = null;
      });
    }
  }

  List<List<DateTime>> _getWeeksOfMonth(int year, int month) {
    List<List<DateTime>> weeks = [];
    try {
      // Get the first day of the month
      DateTime firstDay = DateTime(year, month, 1);

      // Get the last day of the month by going to the first day of next month and subtracting 1 day
      DateTime lastDayOfMonth = month == 12
          ? DateTime(year + 1, 1, 1).subtract(const Duration(days: 1))
          : DateTime(year, month + 1, 1).subtract(const Duration(days: 1));

      // Calculate the start of the first week (Monday-based)
      int dayOffset = firstDay.weekday - 1; // 0 for Monday
      DateTime weekStart = firstDay.subtract(Duration(days: dayOffset));

      // Generate weeks until we've covered the entire month
      while (weekStart.isBefore(lastDayOfMonth) ||
          weekStart.isAtSameMomentAs(lastDayOfMonth)) {
        List<DateTime> week = [];

        // Add days of this week that fall in the current month
        for (int i = 0; i < 7; i++) {
          DateTime day = weekStart.add(Duration(days: i));
          if (day.month == month && day.year == year) {
            week.add(day);
          }
        }

        if (week.isNotEmpty) {
          weeks.add(week);
        }

        // Move to next week
        weekStart = weekStart.add(const Duration(days: 7));

        // Break if we've gone past the month
        if (weekStart.month > month || (weekStart.month == 1 && month == 12)) {
          break;
        }
      }
    } catch (e) {
      print('Error calculating weeks of month: $e');
      // Return empty list if there's an error
      weeks = [];
    }
    return weeks;
  }

  Future<void> _onWeekSelected(int index) async {
    setState(() {
      selectedWeekIndex = index;
      List<List<DateTime>> weeks = _getWeeksOfMonth(
        selectedYear,
        selectedMonth,
      );
      weekDates = weeks[index];
      paymentRecords = [];
      totalAmount = 0.0;
    });
    await _fetchPaymentsForSelectedPeriod();
  }

  Future<void> _fetchPaymentsForSelectedPeriod() async {
    if (selectedSiteId == null || selectedWeekIndex == null) return;
    String monthStr = DateFormat(
      'MMM',
    ).format(DateTime(selectedYear, selectedMonth));
    String period = '${selectedYear}_${monthStr}_Week${selectedWeekIndex! + 1}';
    final snapshot = await FirestoreService.siteSupervisorPayments
        .where('siteId', isEqualTo: selectedSiteId)
        .where('paymentPeriod', isEqualTo: period)
        .get();

    List<Map<String, dynamic>> paymentsList = [];
    double sum = 0.0;
    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['payments'] != null && data['payments'] is List) {
        for (var p in data['payments']) {
          if (p is Map<String, dynamic>) {
            paymentsList.add(p);
            sum += double.tryParse(p['paymentAmount'].toString()) ?? 0.0;
          }
        }
      }
    }
    setState(() {
      paymentRecords = paymentsList;
      totalAmount = sum;
    });
  }

  void _onCancel() {
    setState(() {
      selectedSiteId = null;
      selectedProject = null;
      selectedSupervisor = null;
      projectController.text = '';
      supervisorController.text = '';
      selectedMonth = DateTime.now().month;
      selectedYear = DateTime.now().year;
      selectedWeekIndex = null;
      weekDates = [];
      paymentRecords = [];
      totalAmount = 0.0;
    });
  }

  Future<void> _onPrint() async {
    final pdf = pw.Document();
    final primaryColor = Theme.of(context).primaryColor;
    final pdfPrimaryColor = PdfColor.fromInt(primaryColor.value);

    final orgDetails = await PdfTemplates.fetchOrgDetails();

    final now = DateTime.now();
    final String genAt = DateFormat('dd/MM/yyyy HH:mm').format(now);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => PdfTemplates.buildHeader(
          reportTitle: 'Site Payment Report',
          orgDetails: orgDetails,
          primaryColor: pdfPrimaryColor,
        ),
        build: (context) => [
          // Report Metadata
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              PdfTemplates.buildMetaBox(
                'Site ID',
                selectedSiteId ?? 'N/A',
                pdfPrimaryColor,
              ),
              PdfTemplates.buildMetaBox(
                'Project',
                selectedProject ?? 'N/A',
                pdfPrimaryColor,
              ),
              PdfTemplates.buildMetaBox(
                'Supervisor',
                selectedSupervisor ?? 'N/A',
                pdfPrimaryColor,
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              PdfTemplates.buildMetaBox(
                'Month',
                DateFormat.MMMM().format(DateTime(0, selectedMonth)),
                pdfPrimaryColor,
              ),
              PdfTemplates.buildMetaBox(
                'Year',
                selectedYear.toString(),
                pdfPrimaryColor,
              ),
              PdfTemplates.buildMetaBox(
                'Week',
                selectedWeekIndex != null
                    ? 'Week ${selectedWeekIndex! + 1}'
                    : 'N/A',
                pdfPrimaryColor,
              ),
              PdfTemplates.buildMetaBox('Generated At', genAt, pdfPrimaryColor),
            ],
          ),
          pw.SizedBox(height: 24),

          // Workforce Table
          pw.Table.fromTextArray(
            headers: ['Date', 'Payment Amount (INR)'],
            data: paymentRecords.map((rec) {
              String dateStr = '';
              if (rec['paymentDate'] != null) {
                try {
                  DateTime dt = DateFormat(
                    'yyyy-MM-dd',
                  ).parse(rec['paymentDate']);
                  dateStr = DateFormat('EEE, MMM d, yyyy').format(dt);
                } catch (e) {
                  dateStr = rec['paymentDate'].toString();
                }
              }
              return [dateStr, rec['paymentAmount']?.toString() ?? '0.00'];
            }).toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(color: pdfPrimaryColor),
            cellAlignment: pw.Alignment.centerLeft,
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(1),
            },
          ),
          pw.SizedBox(height: 24),

          // Grand Totals Section
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: const pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  'Total Payment for Week:',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(width: 24),
                pw.Text(
                  'INR ${totalAmount.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: pdfPrimaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
        footer: (context) => PdfTemplates.buildFooter(context),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  @override
  void dispose() {
    projectController.dispose();
    supervisorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 600;

    return GlassScaffold(
      title: 'Site Payment Report',
      onBack: () => Navigator.pop(context),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double screenWidth = constraints.maxWidth;
        double horizontalPadding = screenWidth * 0.05;
        if (horizontalPadding < 16) horizontalPadding = 16;
        if (horizontalPadding > 40) horizontalPadding = 40;

        double fontSizeBase = screenWidth / 30;
        if (fontSizeBase < 14) fontSizeBase = 14;
        if (fontSizeBase > 22) fontSizeBase = 22;

        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final borderColor = isDark
            ? Colors.white.withValues(alpha: 0.12)
            : const Color(0xFFE2E8F0);

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 24,
          ),
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Container(
                  padding: EdgeInsets.all(horizontalPadding),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.25)
                            : theme.primaryColor.withValues(alpha: 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                    border: Border.all(color: borderColor),
                  ),
                  child: _buildReportForm(context, fontSizeBase),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReportForm(BuildContext context, double fontSizeBase) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;
    final weeks = _getWeeksOfMonth(selectedYear, selectedMonth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Form Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: primaryColor.withValues(alpha: isDark ? 0.35 : 0.2),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.assessment_rounded,
                color: isDark ? AppTheme.getCardAccent(primaryColor) : primaryColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Site Payment Report',
                    style: TextStyle(
                      fontSize: fontSizeBase * 1.25,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0A183D),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Filter and generate supervisor weekly payment reports',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: fontSizeBase * 1.5),
        _buildDropdownField(
          label: 'Site ID',
          value: selectedSiteId,
          items: siteIds,
          fontSizeBase: fontSizeBase,
          onChanged: (value) {
            setState(() {
              selectedSiteId = value;
              selectedWeekIndex = null;
              weekDates = [];
              paymentRecords = [];
              totalAmount = 0.0;
            });
            _updateProjectAndSupervisor();
          },
        ),
        SizedBox(height: fontSizeBase * 1.5),
        _buildTextField(
          label: 'Project',
          controller: projectController,
          fontSizeBase: fontSizeBase,
        ),
        SizedBox(height: fontSizeBase * 1.5),
        _buildTextField(
          label: 'Supervisor',
          controller: supervisorController,
          fontSizeBase: fontSizeBase,
        ),
        SizedBox(height: fontSizeBase * 2),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 400) {
              return Column(
                children: [
                  _buildMonthDropdown(fontSizeBase),
                  SizedBox(height: fontSizeBase),
                  _buildYearDropdown(fontSizeBase),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: _buildMonthDropdown(fontSizeBase)),
                SizedBox(width: fontSizeBase),
                Expanded(child: _buildYearDropdown(fontSizeBase)),
              ],
            );
          },
        ),
        SizedBox(height: fontSizeBase * 2.0),
        Row(
          children: [
            Icon(
              Icons.date_range_rounded,
              size: 18,
              color: isDark ? AppTheme.getCardAccent(primaryColor) : primaryColor,
            ),
            const SizedBox(width: 8),
            Text(
              'SELECT WEEK',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : primaryColor,
                fontSize: 13,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        SizedBox(height: fontSizeBase),
        _buildWeekChips(weeks, fontSizeBase),
        SizedBox(height: fontSizeBase * 2.5),
        if (selectedWeekIndex != null && weekDates.isNotEmpty)
          _buildPaymentTable(fontSizeBase),
        SizedBox(height: fontSizeBase * 2.5),
        _buildActionButtons(fontSizeBase),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required double fontSizeBase,
    required ValueChanged<String?> onChanged,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;
    final dropdownBg = isDark ? AppTheme.getDarkAccent(primaryColor) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0A183D);

    return DropdownButtonFormField<String>(
      decoration: _inputDecoration(label, fontSizeBase),
      value: value,
      dropdownColor: dropdownBg,
      style: TextStyle(
        fontSize: fontSizeBase,
        color: textColor,
        fontWeight: FontWeight.w700,
      ),
      items: items
          .map(
            (id) => DropdownMenuItem(
              value: id,
              child: Text(
                id,
                style: TextStyle(
                  fontSize: fontSizeBase,
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required double fontSizeBase,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      decoration: _inputDecoration(label, fontSizeBase),
      readOnly: true,
      style: TextStyle(
        fontSize: fontSizeBase,
        color: isDark ? Colors.white : const Color(0xFF0A183D),
        fontWeight: FontWeight.w700,
      ),
      controller: controller,
    );
  }

  Widget _buildMonthDropdown(double fontSizeBase) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;
    final dropdownBg = isDark ? AppTheme.getDarkAccent(primaryColor) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0A183D);

    return DropdownButtonFormField<int>(
      decoration: _inputDecoration('Month', fontSizeBase * 0.9),
      value: selectedMonth,
      isExpanded: true,
      dropdownColor: dropdownBg,
      style: TextStyle(
        fontSize: fontSizeBase,
        color: textColor,
        fontWeight: FontWeight.w700,
      ),
      items: List.generate(12, (i) => i + 1)
          .map(
            (m) => DropdownMenuItem(
              value: m,
              child: Text(
                DateFormat.MMMM().format(DateTime(0, m)),
                style: TextStyle(
                  fontSize: fontSizeBase,
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          )
          .toList(),
      onChanged: (value) {
        setState(() {
          selectedMonth = value!;
          selectedWeekIndex = null;
          weekDates = [];
          paymentRecords = [];
          totalAmount = 0.0;
        });
      },
    );
  }

  Widget _buildYearDropdown(double fontSizeBase) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;
    final dropdownBg = isDark ? AppTheme.getDarkAccent(primaryColor) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0A183D);

    return DropdownButtonFormField<int>(
      decoration: _inputDecoration('Year', fontSizeBase * 0.9),
      value: selectedYear,
      isExpanded: true,
      dropdownColor: dropdownBg,
      style: TextStyle(
        fontSize: fontSizeBase,
        color: textColor,
        fontWeight: FontWeight.w700,
      ),
      items: years
          .map(
            (y) => DropdownMenuItem(
              value: y,
              child: Text(
                y.toString(),
                style: TextStyle(
                  fontSize: fontSizeBase,
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          )
          .toList(),
      onChanged: (value) {
        setState(() {
          selectedYear = value!;
          selectedWeekIndex = null;
          weekDates = [];
          paymentRecords = [];
          totalAmount = 0.0;
        });
      },
    );
  }

  Widget _buildWeekChips(
    List<List<DateTime>> weeks,
    double fontSizeBase,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;
    final darkAccent = AppTheme.getDarkAccent(primaryColor);

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(weeks.length, (i) {
        final isSelected = selectedWeekIndex == i;
        final chipBg = isSelected
            ? (isDark ? primaryColor : darkAccent)
            : (isDark
                ? Colors.white.withValues(alpha: 0.08)
                : primaryColor.withValues(alpha: 0.05));

        final chipBorder = isSelected
            ? (isDark ? AppTheme.getCardAccent(primaryColor) : primaryColor)
            : (isDark
                ? Colors.white.withValues(alpha: 0.15)
                : const Color(0xFFCBD5E1));

        final chipTextColor = isSelected
            ? Colors.white
            : (isDark ? Colors.white : const Color(0xFF0A183D));

        return InkWell(
          onTap: () => _onWeekSelected(i),
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: chipBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: chipBorder,
                width: isSelected ? 2.0 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: (isDark ? primaryColor : darkAccent)
                            .withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) ...[
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  'Week ${i + 1}',
                  style: TextStyle(
                    color: chipTextColor,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildPaymentTable(double fontSizeBase) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;
    final titleColor = isDark ? Colors.white : const Color(0xFF0A183D);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : const Color(0xFFCBD5E1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.receipt_rounded,
              size: 18,
              color: isDark ? AppTheme.getCardAccent(primaryColor) : primaryColor,
            ),
            const SizedBox(width: 8),
            Text(
              'Payments for Week ${selectedWeekIndex! + 1}:',
              style: TextStyle(
                color: titleColor,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.15)
                    : primaryColor.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(1.2),
              1: FlexColumnWidth(0.8),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: primaryColor,
                ),
                children: [
                  _buildTableCell('Date', isHeader: true),
                  _buildTableCell('Payment (₹)', isHeader: true),
                ],
              ),
              ...paymentRecords.map((rec) {
                String dateStr = '';
                if (rec['paymentDate'] != null) {
                  try {
                    DateTime dt = DateFormat('yyyy-MM-dd').parse(rec['paymentDate'].toString());
                    dateStr = DateFormat('EEE, MMM d, y').format(dt);
                  } catch (e) {
                    dateStr = rec['paymentDate'].toString();
                  }
                }
                return TableRow(
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.03)
                        : const Color(0xFFF8FAFC),
                  ),
                  children: [
                    _buildTableCell(dateStr),
                    _buildTableCell(rec['paymentAmount']?.toString() ?? '0'),
                  ],
                );
              }),
              TableRow(
                decoration: BoxDecoration(
                  color: isDark
                      ? primaryColor.withValues(alpha: 0.2)
                      : primaryColor.withValues(alpha: 0.08),
                ),
                children: [
                  _buildTableCell('Total Payment', isTotal: true),
                  _buildTableCell(
                    '₹${totalAmount.toStringAsFixed(2)}',
                    isTotal: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    bool isTotal = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;

    Color cellTextColor;
    if (isHeader) {
      cellTextColor = Colors.white;
    } else if (isTotal) {
      cellTextColor = isDark ? AppTheme.getCardAccent(primaryColor) : primaryColor;
    } else {
      cellTextColor = isDark ? Colors.white : const Color(0xFF0A183D);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isHeader || isTotal ? FontWeight.w800 : FontWeight.w500,
          color: cellTextColor,
          fontSize: isHeader ? 13 : (isTotal ? 15 : 14),
        ),
      ),
    );
  }

  Widget _buildActionButtons(double fontSizeBase) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;
    final buttonBg = isDark ? primaryColor : AppTheme.getDarkAccent(primaryColor);

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _onCancel,
              icon: Icon(
                Icons.refresh_rounded,
                size: 18,
                color: isDark ? Colors.white : const Color(0xFF0A183D),
              ),
              label: Text(
                'Reset',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0A183D),
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white,
                foregroundColor: isDark ? Colors.white : const Color(0xFF0A183D),
                side: BorderSide(
                  color: isDark ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFCBD5E1),
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _onPrint,
              icon: const Icon(
                Icons.print_rounded,
                size: 20,
                color: Colors.white,
              ),
              label: const Text(
                'Print PDF Report',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonBg,
                foregroundColor: Colors.white,
                elevation: 6,
                shadowColor: buttonBg.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, double fontSize) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;
    final labelColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
    final fieldBg = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFCBD5E1);

    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        fontSize: 14,
        color: labelColor,
        fontWeight: FontWeight.w600,
      ),
      filled: true,
      fillColor: fieldBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor, width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: primaryColor,
          width: 1.8,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
