import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class WorkerReportPdf {
  static Future<Uint8List> build({required Map<String, dynamic> worker}) async {
    final pdf = pw.Document();
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
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'WORKER ATTENDANCE REPORT',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.Text(
                  month,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(thickness: 2, color: PdfColors.blue900),
            pw.SizedBox(height: 16),
          ],
        ),
        build: (context) => [
          // Worker & Site Info
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _buildInfoColumn('Worker Details', {
                  'Name': workerName,
                  'Designation': worker['designation'] ?? 'N/A',
                  'ID': worker['id'] ?? 'N/A',
                }),
              ),
              pw.SizedBox(width: 40),
              pw.Expanded(
                child: _buildInfoColumn('Project Details', {
                  'Site': site,
                  'Generated At': genAt,
                }),
              ),
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
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
            cellAlignment: pw.Alignment.center,
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
                    color: PdfColors.green900,
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
        footer: (context) => pw.Column(
          children: [
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Company Confidential Report',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ],
        ),
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
