import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/utils/pdf_templates.dart';
import 'dart:async';

class DailySitePaymentReportScreen extends StatefulWidget {
  const DailySitePaymentReportScreen({super.key});

  @override
  DailySitePaymentReportScreenState createState() =>
      DailySitePaymentReportScreenState();
}

class DailySitePaymentReportScreenState
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

          final docProjectName = data['projectName']?.toString() ?? '';

          details[siteId] = {
            'project': docProjectName,
            'supervisor': data['supervisor']?.toString() ?? '',
          };

          if (docProjectName.isEmpty && siteId.contains('_')) {
            final parts = siteId.split('_');
            if (parts.length > 1) {
              details[siteId]!['project'] = parts.sublist(1).join('_');
            }
          }
        }
      }

      final projectsSnapshot = await FirestoreService.projects.get();
      for (var doc in projectsSnapshot.docs) {
        final data = doc.data();
        final siteId = data['siteId']?.toString();
        final fetchedProjectName = data['projectName']?.toString() ?? '';
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
      DateTime firstDay = DateTime(year, month, 1);
      DateTime lastDayOfMonth = month == 12
          ? DateTime(year + 1, 1, 1).subtract(const Duration(days: 1))
          : DateTime(year, month + 1, 1).subtract(const Duration(days: 1));

      int dayOffset = firstDay.weekday - 1;
      DateTime weekStart = firstDay.subtract(Duration(days: dayOffset));

      while (weekStart.isBefore(lastDayOfMonth) ||
          weekStart.isAtSameMomentAs(lastDayOfMonth)) {
        List<DateTime> week = [];

        for (int i = 0; i < 7; i++) {
          DateTime day = weekStart.add(Duration(days: i));
          if (day.month == month && day.year == year) {
            week.add(day);
          }
        }

        if (week.isNotEmpty) {
          weeks.add(week);
        }

        weekStart = weekStart.add(const Duration(days: 7));

        if (weekStart.month > month || (weekStart.month == 1 && month == 12)) {
          break;
        }
      }
    } catch (e) {
      debugPrint('Error calculating weeks: $e');
      weeks = [];
    }
    return weeks;
  }

  Future<void> _fetchPaymentsForWeek(List<DateTime> dates) async {
    if (selectedSiteId == null || dates.isEmpty) return;

    try {
      final snapshot = await FirestoreService.getCollection(
        'siteSupervisorPayments',
      ).where('siteId', isEqualTo: selectedSiteId).get();

      final List<Map<String, dynamic>> records = [];
      double sum = 0.0;

      for (var date in dates) {
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        double dayTotal = 0.0;

        for (var doc in snapshot.docs) {
          final data = doc.data();

          if (data['paymentDate'] != null) {
            DateTime? pDate;
            if (data['paymentDate'] is String) {
              pDate = DateTime.tryParse(data['paymentDate']);
            } else if (data['paymentDate'] is Timestamp) {
              pDate = (data['paymentDate'] as Timestamp).toDate();
            }

            if (pDate != null) {
              final docDateStr = DateFormat('yyyy-MM-dd').format(pDate);
              if (docDateStr == dateStr) {
                final amt =
                    double.tryParse(data['amount']?.toString() ?? '0') ?? 0.0;
                dayTotal += amt;
              }
            }
          }
        }

        records.add({'paymentDate': dateStr, 'paymentAmount': dayTotal});

        sum += dayTotal;
      }

      if (mounted) {
        setState(() {
          paymentRecords = records;
          totalAmount = sum;
        });
      }
    } catch (e) {
      debugPrint('Error fetching payments: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load payment details')),
        );
      }
    }
  }

  Future<void> _generatePdfReport() async {
    final pdf = pw.Document();
    final genAt = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    final pdfPrimaryColor = PdfColor.fromInt(Theme.of(context).primaryColor.toARGB32());
    final orgDetails = await PdfTemplates.fetchOrgDetails();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          PdfTemplates.buildHeader(
            reportTitle: 'SITE PAYMENT REPORT',
            orgDetails: orgDetails,
            primaryColor: pdfPrimaryColor,
          ),
          pw.SizedBox(height: 16),

          pw.Row(
            children: [
              pw.Expanded(
                child: PdfTemplates.buildMetaBox(
                  'Site ID',
                  selectedSiteId ?? 'N/A',
                  pdfPrimaryColor,
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: PdfTemplates.buildMetaBox(
                  'Project',
                  projectController.text.isNotEmpty
                      ? projectController.text
                      : 'N/A',
                  pdfPrimaryColor,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            children: [
              pw.Expanded(
                child: PdfTemplates.buildMetaBox(
                  'Supervisor',
                  supervisorController.text.isNotEmpty
                      ? supervisorController.text
                      : 'N/A',
                  pdfPrimaryColor,
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: PdfTemplates.buildMetaBox(
                  'Period / Generated',
                  '${DateFormat.MMMM().format(DateTime(0, selectedMonth))} $selectedYear (W${(selectedWeekIndex ?? 0) + 1}) • $genAt',
                  pdfPrimaryColor,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 24),

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

  Color get primaryColor => Theme.of(context).colorScheme.primary;

  @override
  void dispose() {
    projectController.dispose();
    supervisorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Site Payment Report',
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isMobile ? double.infinity : 680.0,
            ),
            child: _buildBody(context),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0A183D).withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.assessment_rounded,
                    color: primaryColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Site Payment Report',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0A183D),
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Filter and generate supervisor weekly payment reports',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // SECTION 1: SITE & LOCATION
          _buildSectionHeader(
            title: '1. Select Site & Location',
            subtitle: 'Choose site ID, project & supervisor details',
            icon: Icons.place_rounded,
            color: primaryColor,
          ),
          const SizedBox(height: 16),
          _buildDropdownField(
            label: 'Site ID *',
            value: selectedSiteId,
            items: siteIds,
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
          const SizedBox(height: 14),
          _buildTextField(
            label: 'Project',
            controller: projectController,
          ),
          const SizedBox(height: 14),
          _buildTextField(
            label: 'Supervisor',
            controller: supervisorController,
          ),
          const SizedBox(height: 24),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 16),

          // SECTION 2: YEAR & MONTH
          _buildSectionHeader(
            title: '2. Select Year & Month',
            subtitle: 'Choose reporting month and year',
            icon: Icons.calendar_month_rounded,
            color: Colors.indigo,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildMonthDropdown()),
              const SizedBox(width: 12),
              Expanded(child: _buildYearDropdown()),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 16),

          // SECTION 3: WEEK PERIOD
          _buildSectionHeader(
            title: '3. Select Week Period',
            subtitle: 'Pick week timeframe to compile report',
            icon: Icons.date_range_rounded,
            color: Colors.teal,
          ),
          const SizedBox(height: 16),
          _buildWeekChips(_getWeeksOfMonth(selectedYear, selectedMonth)),
          const SizedBox(height: 20),

          if (selectedWeekIndex != null && weekDates.isNotEmpty) ...[
            _buildPaymentTable(),
            const SizedBox(height: 24),
          ],

          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A183D),
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0A183D),
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: items.contains(value) ? value : null,
          isExpanded: true,
          dropdownColor: Colors.white,
          style: const TextStyle(
            fontSize: 13.5,
            color: Color(0xFF0A183D),
            fontWeight: FontWeight.w600,
          ),
          decoration: _inputDecoration('Select $label', Icons.place_rounded),
          items: items
              .map(
                (id) => DropdownMenuItem(
                  value: id,
                  child: Text(
                    id,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF0A183D),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0A183D),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          readOnly: true,
          style: const TextStyle(
            fontSize: 13.5,
            color: Color(0xFF0A183D),
            fontWeight: FontWeight.w600,
          ),
          decoration: _inputDecoration(label, Icons.info_outline_rounded).copyWith(
            fillColor: Colors.grey.shade100,
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: primaryColor, size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor, width: 1.8),
      ),
    );
  }

  Widget _buildMonthDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Month *',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0A183D),
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<int>(
          initialValue: selectedMonth,
          isExpanded: true,
          dropdownColor: Colors.white,
          style: const TextStyle(
            fontSize: 13.5,
            color: Color(0xFF0A183D),
            fontWeight: FontWeight.w600,
          ),
          decoration: _inputDecoration('Select Month', Icons.calendar_month_rounded),
          items: List.generate(12, (i) => i + 1)
              .map(
                (m) => DropdownMenuItem(
                  value: m,
                  child: Text(
                    DateFormat.MMMM().format(DateTime(0, m)),
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF0A183D),
                      fontWeight: FontWeight.w600,
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
        ),
      ],
    );
  }

  Widget _buildYearDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Year *',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0A183D),
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<int>(
          initialValue: selectedYear,
          isExpanded: true,
          dropdownColor: Colors.white,
          style: const TextStyle(
            fontSize: 13.5,
            color: Color(0xFF0A183D),
            fontWeight: FontWeight.w600,
          ),
          decoration: _inputDecoration('Select Year', Icons.calendar_today_rounded),
          items: years
              .map(
                (y) => DropdownMenuItem(
                  value: y,
                  child: Text(
                    y.toString(),
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF0A183D),
                      fontWeight: FontWeight.w600,
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
        ),
      ],
    );
  }

  Widget _buildWeekChips(List<List<DateTime>> weeks) {
    if (weeks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: const Text(
          'No weeks available for selected month',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13.0),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double spacing = 10.0;
        final double width = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: List.generate(weeks.length, (i) {
            final week = weeks[i];
            final startDate = DateFormat('MMM dd').format(week.first);
            final endDate = DateFormat('MMM dd').format(week.last);
            final isSelected = selectedWeekIndex == i;

            return InkWell(
              onTap: () {
                setState(() {
                  selectedWeekIndex = i;
                  weekDates = week;
                });
                _fetchPaymentsForWeek(week);
              },
              borderRadius: BorderRadius.circular(12.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: width,
                padding: const EdgeInsets.symmetric(
                  vertical: 12.0,
                  horizontal: 10.0,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? primaryColor : Colors.white,
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(
                    color: isSelected ? primaryColor : const Color(0xFFCBD5E1),
                    width: isSelected ? 2.0 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.3),
                            blurRadius: 8.0,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isSelected) ...[
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Colors.white,
                            size: 15,
                          ),
                          const SizedBox(width: 5),
                        ],
                        Text(
                          'Week ${i + 1}',
                          style: TextStyle(
                            fontSize: 14.0,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : const Color(0xFF0A183D),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$startDate - $endDate',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? Colors.white70 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildPaymentTable() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Weekly Payment Records',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0A183D),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '₹${totalAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(1),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                children: const [
                  Padding(
                    padding: EdgeInsets.all(10.0),
                    child: Text(
                      'Date',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0A183D),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(10.0),
                    child: Text(
                      'Amount (₹)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0A183D),
                      ),
                    ),
                  ),
                ],
              ),
              ...paymentRecords.map((rec) {
                String dateStr = rec['paymentDate'] ?? '';
                try {
                  DateTime dt = DateFormat('yyyy-MM-dd').parse(dateStr);
                  dateStr = DateFormat('EEE, MMM d, yyyy').format(dt);
                } catch (_) {}
                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF0A183D),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        '₹${rec['paymentAmount']}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF0A183D),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: (selectedSiteId != null && selectedWeekIndex != null)
            ? _generatePdfReport
            : null,
        icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
        label: const Text(
          'Generate & Download PDF Report',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
