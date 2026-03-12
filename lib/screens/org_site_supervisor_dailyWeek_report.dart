import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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
      final snapshot = await FirebaseFirestore.instance
          .collection('siteSupervisorPayments')
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException(
                'Site details query timeout',
                const Duration(seconds: 10),
              );
            },
          );

      if (!mounted) return;

      final ids = <String>{};
      final details = <String, Map<String, String>>{};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final siteId = data['siteId']?.toString();
        if (siteId != null && siteId.isNotEmpty) {
          ids.add(siteId);
          details[siteId] = {
            'project': data['projectName']?.toString() ?? '',
            'supervisor': data['supervisorName']?.toString() ?? '',
          };
        }
      }

      if (mounted) {
        setState(() {
          siteIds = ids.toList();
          siteDetails = details;
        });
      }
    } on TimeoutException catch (e) {
      print('Timeout fetching site details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load site data. Please retry.'),
          ),
        );
      }
    } catch (e) {
      print('Error fetching site IDs and details: $e');
    }
  }

  void _updateProjectAndSupervisor() {
    if (selectedSiteId != null && siteDetails.containsKey(selectedSiteId)) {
      selectedProject = siteDetails[selectedSiteId]!['project'];
      selectedSupervisor = siteDetails[selectedSiteId]!['supervisor'];
      projectController.text = selectedProject ?? '';
      supervisorController.text = selectedSupervisor ?? '';
    } else {
      selectedProject = null;
      selectedSupervisor = null;
      projectController.text = '';
      supervisorController.text = '';
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
    final snapshot = await FirebaseFirestore.instance
        .collection('siteSupervisorPayments')
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
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Site Payment Report',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Site ID: ${selectedSiteId ?? ''}'),
              pw.Text('Project: ${selectedProject ?? ''}'),
              pw.Text('Supervisor: ${selectedSupervisor ?? ''}'),
              pw.Text(
                'Month: ${DateFormat.MMMM().format(DateTime(0, selectedMonth))}',
              ),
              pw.Text('Year: $selectedYear'),
              pw.Text(
                'Week: ${selectedWeekIndex != null ? selectedWeekIndex! + 1 : ''}',
              ),
              pw.SizedBox(height: 16),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFF772323),
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Date',
                          style: pw.TextStyle(
                            color: PdfColor.fromInt(0xFFFFFFFF),
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Payment',
                          style: pw.TextStyle(
                            color: PdfColor.fromInt(0xFFFFFFFF),
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  ...paymentRecords.map((rec) {
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
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(dateStr),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            rec['paymentAmount']?.toString() ?? '',
                          ),
                        ),
                      ],
                    );
                  }),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Total',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          totalAmount.toStringAsFixed(2),
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
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
    List<List<DateTime>> weeks = _getWeeksOfMonth(selectedYear, selectedMonth);
    final Color primaryColor = Color(0xFF003768);

    return Scaffold(
      backgroundColor: Color(0xFFF8F6F6),
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: LayoutBuilder(
          builder: (context, constraints) {
            double fontSizeBase = constraints.maxWidth / 25;
            if (fontSizeBase < 16) fontSizeBase = 16;
            return Text(
              'Site Payment Report',
              style: TextStyle(color: Colors.white),
            );
          },
        ),
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 2,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          double screenWidth = constraints.maxWidth;
          double horizontalPadding = screenWidth * 0.05;
          if (horizontalPadding < 16) horizontalPadding = 16;
          if (horizontalPadding > 40) horizontalPadding = 40;

          double fontSizeBase = screenWidth / 30;
          if (fontSizeBase < 14) fontSizeBase = 14;
          if (fontSizeBase > 22) fontSizeBase = 22;

          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 16,
            ),
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 700),
                  child: Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(horizontalPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Site ID',
                              labelStyle: TextStyle(fontSize: fontSizeBase),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: primaryColor,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                vertical: fontSizeBase * 1.2,
                                horizontal: fontSizeBase,
                              ),
                            ),
                            value: selectedSiteId,
                            items: siteIds
                                .map(
                                  (id) => DropdownMenuItem(
                                    value: id,
                                    child: Text(
                                      id,
                                      style: TextStyle(fontSize: fontSizeBase),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedSiteId = value;
                                _updateProjectAndSupervisor();
                                selectedWeekIndex = null;
                                weekDates = [];
                                paymentRecords = [];
                                totalAmount = 0.0;
                              });
                            },
                          ),
                          SizedBox(height: fontSizeBase * 1.5),
                          TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Project',
                              labelStyle: TextStyle(fontSize: fontSizeBase),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: primaryColor,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                vertical: fontSizeBase * 1.2,
                                horizontal: fontSizeBase,
                              ),
                            ),
                            readOnly: true,
                            style: TextStyle(fontSize: fontSizeBase),
                            controller: projectController,
                          ),
                          SizedBox(height: fontSizeBase * 1.5),
                          TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Supervisor',
                              labelStyle: TextStyle(fontSize: fontSizeBase),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: primaryColor,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                vertical: fontSizeBase * 1.2,
                                horizontal: fontSizeBase,
                              ),
                            ),
                            readOnly: true,
                            style: TextStyle(fontSize: fontSizeBase),
                            controller: supervisorController,
                          ),
                          SizedBox(height: fontSizeBase * 1.5),

                          // Fixed Month and Year Row to prevent overflow
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  decoration: InputDecoration(
                                    labelText: 'Month',
                                    labelStyle: TextStyle(
                                      fontSize: fontSizeBase,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: primaryColor,
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: fontSizeBase * 0.9,
                                      horizontal: fontSizeBase * 0.7,
                                    ),
                                  ),
                                  value: selectedMonth,
                                  items: List.generate(12, (i) => i + 1)
                                      .map(
                                        (m) => DropdownMenuItem(
                                          value: m,
                                          child: Text(
                                            DateFormat.MMMM().format(
                                              DateTime(0, m),
                                            ),
                                            style: TextStyle(
                                              fontSize: fontSizeBase,
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
                              ),
                              SizedBox(width: fontSizeBase * 0.8),
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  decoration: InputDecoration(
                                    labelText: 'Year',
                                    labelStyle: TextStyle(
                                      fontSize: fontSizeBase,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: primaryColor,
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: fontSizeBase * 0.9,
                                      horizontal: fontSizeBase * 0.7,
                                    ),
                                  ),
                                  value: selectedYear,
                                  items: years
                                      .map(
                                        (y) => DropdownMenuItem(
                                          value: y,
                                          child: Text(
                                            y.toString(),
                                            style: TextStyle(
                                              fontSize: fontSizeBase,
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
                              ),
                            ],
                          ),

                          SizedBox(height: fontSizeBase * 1.8),
                          Text(
                            'Weeks:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                              fontSize: fontSizeBase,
                            ),
                          ),
                          SizedBox(height: fontSizeBase),
                          Wrap(
                            spacing: fontSizeBase,
                            children: List.generate(weeks.length, (i) {
                              return ChoiceChip(
                                label: Text(
                                  'Week ${i + 1}',
                                  style: TextStyle(
                                    color: selectedWeekIndex == i
                                        ? Colors.white
                                        : primaryColor,
                                    fontSize: fontSizeBase,
                                  ),
                                ),
                                selected: selectedWeekIndex == i,
                                selectedColor: primaryColor,
                                backgroundColor: Color(0xFFF2EAEA),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                onSelected: (_) {
                                  _onWeekSelected(i);
                                },
                              );
                            }),
                          ),
                          SizedBox(height: fontSizeBase * 1.8),
                          if (selectedWeekIndex != null && weekDates.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Payments for Week ${selectedWeekIndex! + 1}:',
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: fontSizeBase,
                                  ),
                                ),
                                SizedBox(height: fontSizeBase),
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: primaryColor.withOpacity(0.3),
                                    ),
                                    color: Color(0xFFF9EDED),
                                  ),
                                  child: Table(
                                    border: TableBorder.symmetric(
                                      inside: BorderSide(
                                        color: primaryColor.withOpacity(0.15),
                                      ),
                                    ),
                                    columnWidths: {
                                      0: FlexColumnWidth(2),
                                      1: FlexColumnWidth(2),
                                    },
                                    children: [
                                      TableRow(
                                        decoration: BoxDecoration(
                                          color: primaryColor.withOpacity(0.9),
                                        ),
                                        children: [
                                          Padding(
                                            padding: EdgeInsets.all(
                                              fontSizeBase,
                                            ),
                                            child: Text(
                                              'Date',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                fontSize: fontSizeBase,
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: EdgeInsets.all(
                                              fontSizeBase,
                                            ),
                                            child: Text(
                                              'Payment',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                fontSize: fontSizeBase,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      ...paymentRecords.map((rec) {
                                        String dateStr = '';
                                        if (rec['paymentDate'] != null) {
                                          try {
                                            DateTime dt =
                                                (rec['paymentDate']
                                                        as Timestamp)
                                                    .toDate();
                                            dateStr = DateFormat(
                                              'EEE, MMM d, yyyy',
                                            ).format(dt);
                                          } catch (e) {
                                            dateStr = rec['paymentDate']
                                                .toString();
                                          }
                                        }
                                        return TableRow(
                                          children: [
                                            Padding(
                                              padding: EdgeInsets.all(
                                                fontSizeBase,
                                              ),
                                              child: Text(
                                                dateStr,
                                                style: TextStyle(
                                                  color: primaryColor,
                                                  fontSize: fontSizeBase,
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding: EdgeInsets.all(
                                                fontSizeBase,
                                              ),
                                              child: Text(
                                                rec['paymentAmount']
                                                        ?.toString() ??
                                                    '',
                                                style: TextStyle(
                                                  color: primaryColor,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: fontSizeBase,
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      }),
                                      if (paymentRecords.isNotEmpty)
                                        TableRow(
                                          children: [
                                            Padding(
                                              padding: EdgeInsets.all(
                                                fontSizeBase,
                                              ),
                                              child: Text(
                                                'Total',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: primaryColor,
                                                  fontSize: fontSizeBase,
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding: EdgeInsets.all(
                                                fontSizeBase,
                                              ),
                                              child: Text(
                                                totalAmount.toStringAsFixed(2),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: primaryColor,
                                                  fontSize: fontSizeBase,
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
                          SizedBox(height: fontSizeBase * 3),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF003768),
                                  shape: CircleBorder(), // Circular button
                                  padding: EdgeInsets.all(fontSizeBase * 1.5),
                                ),
                                child: Icon(
                                  Icons.cancel_outlined,
                                  size: fontSizeBase * 1.5,
                                  color: Colors.white,
                                ),
                              ),
                              ElevatedButton(
                                onPressed: _onCancel,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(
                                    255,
                                    250,
                                    185,
                                    88,
                                  ),
                                  shape: CircleBorder(), // Circular button
                                  padding: EdgeInsets.all(fontSizeBase * 1.5),
                                ),
                                child: Icon(
                                  Icons.restart_alt,
                                  size: fontSizeBase * 1.5,
                                  color: Colors.white,
                                ),
                              ),
                              ElevatedButton(
                                onPressed:
                                    (selectedWeekIndex != null &&
                                        paymentRecords.isNotEmpty)
                                    ? _onPrint
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(
                                    255,
                                    244,
                                    53,
                                    53,
                                  ),
                                  shape: CircleBorder(), // Circular button
                                  padding: EdgeInsets.all(fontSizeBase * 1.5),
                                ),
                                child: Icon(
                                  Icons.print,
                                  size: fontSizeBase * 1.5,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
