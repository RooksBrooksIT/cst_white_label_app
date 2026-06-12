import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../utils/pdf_templates.dart';
import '../utils/app_theme.dart';

class WorkerReportPdf {
  static Future<Uint8List> build({
    required Map<String, dynamic> worker,
    required PdfColor primaryColor,
  }) async {
    final pdf = pw.Document();
    final orgDetails = await PdfTemplates.fetchOrgDetails();
    final String workerName = worker['name'] ?? 'Unknown';
    final String month = worker['month'] ?? 'N/A';
    final String site = worker['site'] ?? 'N/A';
    final Map<String, dynamic> attendanceData =
        worker['attendanceData'] as Map<String, dynamic>? ?? {};

    final now = DateTime.now();
    final String genAt = DateFormat('dd/MM/yyyy HH:mm').format(now);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => PdfTemplates.buildHeader(
          reportTitle: 'Worker Attendance Report',
          orgDetails: orgDetails,
          primaryColor: primaryColor,
        ),
        build: (context) => [
          // Worker & Site Info
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              PdfTemplates.buildMetaBox('Worker Name', workerName, primaryColor),
              PdfTemplates.buildMetaBox('Designation', worker['designation'] ?? 'N/A', primaryColor),
              PdfTemplates.buildMetaBox('Month', month, primaryColor),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              PdfTemplates.buildMetaBox('Site', site, primaryColor),
              PdfTemplates.buildMetaBox('Employee ID', worker['id'] ?? 'N/A', primaryColor),
              PdfTemplates.buildMetaBox('Generated At', genAt, primaryColor),
            ],
          ),
          pw.SizedBox(height: 24),

          // Attendance Summary Table
          pw.Text(
            'Monthly Summary',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headers: [
              'Present',
              'Absent',
              'Overtime',
              'Half Day',
              'Not Marked',
            ],
            data: [
              [
                worker['present'] ?? 0,
                worker['absent'] ?? 0,
                worker['overtime'] ?? 0,
                worker['halfDay'] ?? 0,
                worker['notMarked'] ?? 0,
              ],
            ],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(color: primaryColor),
            cellAlignment: pw.Alignment.center,
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
          ),
          pw.SizedBox(height: 24),

          // Financial Summary
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Estimated Total Salary:',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'INR ${worker['calculatedSalary']?.toStringAsFixed(2) ?? '0.00'}',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),

          // Daily Breakdown
          pw.Text(
            'Daily Attendance Breakdown',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          _buildDailyAttendanceTable(attendanceData),
        ],
        footer: (context) => PdfTemplates.buildFooter(context),
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildInfoColumn(String title, Map<String, String> info) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
        pw.SizedBox(height: 4),
        ...info.entries.map(
          (e) => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: '${e.key}: ',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                  pw.TextSpan(
                    text: e.value,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildDailyAttendanceTable(Map<String, dynamic> data) {
    final sortedKeys = data.keys.toList()..sort();

    return pw.Table.fromTextArray(
      headers: ['Date', 'Status', 'Designation', 'Daily Salary'],
      data: sortedKeys.map((date) {
        final details = data[date] as Map<String, dynamic>? ?? {};
        return [
          date,
          details['attendance']?.toString().toUpperCase() ?? 'N/A',
          details['designation'] ?? 'N/A',
          details['salary'] ?? '0',
        ];
      }).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellAlignment: pw.Alignment.centerLeft,
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
    );
  }
}
