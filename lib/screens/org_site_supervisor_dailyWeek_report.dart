import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/firestore_service.dart';
import '../utils/app_theme.dart';
import '../utils/pdf_templates.dart';
import 'dart:async';

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
        if (siteId != null && details.containsKey(siteId) && fetchedProjectName.isNotEmpty) {
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
              PdfTemplates.buildMetaBox('Year', selectedYear.toString(), pdfPrimaryColor),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Site Payment Report',
          style: TextStyle(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: colorScheme.onPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(context),
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
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                    border: Border.all(color: const Color(0xFFE2E8F0)),
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
    final colorScheme = Theme.of(context).colorScheme;
    final weeks = _getWeeksOfMonth(selectedYear, selectedMonth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            // Call AFTER setState so selectedSiteId is committed before auto-fill reads it
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
        Row(
          children: [
            Expanded(child: _buildMonthDropdown(fontSizeBase)),
            SizedBox(width: fontSizeBase),
            Expanded(child: _buildYearDropdown(fontSizeBase)),
          ],
        ),
        SizedBox(height: fontSizeBase * 2.5),
        const Text(
          'Weeks:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF64748B),
            fontSize: 14,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: fontSizeBase),
        _buildWeekChips(weeks, fontSizeBase, colorScheme),
        SizedBox(height: fontSizeBase * 2.5),
        if (selectedWeekIndex != null && weekDates.isNotEmpty)
          _buildPaymentTable(fontSizeBase, colorScheme),
        SizedBox(height: fontSizeBase * 3),
        _buildActionButtons(fontSizeBase, colorScheme),
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
    return DropdownButtonFormField<String>(
      decoration: _inputDecoration(label, fontSizeBase),
      value: value,
      dropdownColor: theme.cardColor,
      items: items
          .map(
            (id) => DropdownMenuItem(
              value: id,
              child: Text(id, style: TextStyle(fontSize: fontSizeBase)),
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
    return TextFormField(
      decoration: _inputDecoration(label, fontSizeBase),
      readOnly: true,
      style: TextStyle(fontSize: fontSizeBase, color: const Color(0xFF1E293B)),
      controller: controller,
    );
  }

  Widget _buildMonthDropdown(double fontSizeBase) {
    final theme = Theme.of(context);
    return DropdownButtonFormField<int>(
      decoration: _inputDecoration('Month', fontSizeBase * 0.9),
      value: selectedMonth,
      dropdownColor: theme.cardColor,
      items: List.generate(12, (i) => i + 1)
          .map(
            (m) => DropdownMenuItem(
              value: m,
              child: Text(
                DateFormat.MMMM().format(DateTime(0, m)),
                style: TextStyle(fontSize: fontSizeBase),
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
    return DropdownButtonFormField<int>(
      decoration: _inputDecoration('Year', fontSizeBase * 0.9),
      value: selectedYear,
      dropdownColor: theme.cardColor,
      items: years
          .map(
            (y) => DropdownMenuItem(
              value: y,
              child: Text(
                y.toString(),
                style: TextStyle(fontSize: fontSizeBase),
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
    ColorScheme colorScheme,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(weeks.length, (i) {
        final isSelected = selectedWeekIndex == i;
        return ChoiceChip(
          label: Text(
            'Week ${i + 1}',
            style: TextStyle(
              color: isSelected
                  ? colorScheme.onPrimary
                  : const Color(0xFF64748B),
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          selected: isSelected,
          selectedColor: colorScheme.primary,
          backgroundColor: const Color(0xFFF1F5F9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: (_) => _onWeekSelected(i),
          showCheckmark: false,
        );
      }),
    );
  }

  Widget _buildPaymentTable(double fontSizeBase, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payments for Week ${selectedWeekIndex! + 1}:',
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(1.2),
              1: FlexColumnWidth(0.8),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.05),
                ),
                children: [
                  _buildTableCell('Date', isHeader: true),
                  _buildTableCell('Payment', isHeader: true),
                ],
              ),
              ...paymentRecords.map((rec) {
                String dateStr = '';
                if (rec['paymentDate'] != null) {
                  try {
                    DateTime dt = (rec['paymentDate'] as Timestamp).toDate();
                    dateStr = DateFormat('EEE, MMM d, y').format(dt);
                  } catch (e) {
                    dateStr = rec['paymentDate'].toString();
                  }
                }
                return TableRow(
                  children: [
                    _buildTableCell(dateStr),
                    _buildTableCell(rec['paymentAmount']?.toString() ?? '0'),
                  ],
                );
              }),
              TableRow(
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.02),
                ),
                children: [
                  _buildTableCell('Total', isTotal: true),
                  _buildTableCell(
                    totalAmount.toStringAsFixed(2),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isHeader || isTotal ? FontWeight.bold : FontWeight.normal,
          color: isHeader ? const Color(0xFF64748B) : const Color(0xFF1E293B),
          fontSize: isHeader ? 12 : 14,
        ),
      ),
    );
  }

  Widget _buildActionButtons(double fontSizeBase, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          onTap: _onCancel,
          icon: Icons.refresh_rounded,
          color: const Color(0xFFF59E0B), // Amber 500
          label: 'Reset',
        ),
        _buildActionButton(
          onTap: _onPrint,
          icon: Icons.print_rounded,
          color: colorScheme.primary,
          label: 'Print',
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required VoidCallback onTap,
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, double fontSize) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
