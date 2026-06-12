import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../utils/pdf_templates.dart';
import '../utils/app_theme.dart';

class OverallReportPdf {
  static Future<Uint8List> build({
    required List<Map<String, dynamic>> workers,
    required String site,
    required String month,
    required double overallPercentage,
    required PdfColor primaryColor,
  }) async {
    final pdf = pw.Document();
    final orgDetails = await PdfTemplates.fetchOrgDetails();
    final now = DateTime.now();
    final String genAt = DateFormat('dd/MM/yyyy HH:mm').format(now);
    
    double totalPayout = 0;
    for (var w in workers) {
      totalPayout += (w['calculatedSalary'] as num?)?.toDouble() ?? 0;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => PdfTemplates.buildHeader(
          reportTitle: 'Overall Attendance Summary',
          orgDetails: orgDetails,
          primaryColor: primaryColor,
        ),
        build: (context) => [
          // Report Metadata
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              PdfTemplates.buildMetaBox('Project Site', site, primaryColor),
              PdfTemplates.buildMetaBox('Workforce Size', '${workers.length} Workers', primaryColor),
              PdfTemplates.buildMetaBox('Overall Presence', '${overallPercentage.toStringAsFixed(1)}%', primaryColor),
              PdfTemplates.buildMetaBox('Generated At', genAt, primaryColor),
            ],
          ),
          pw.SizedBox(height: 24),

          // Workforce Table
          pw.Table.fromTextArray(
            headers: [
              'Worker Name', 
              'Designation', 
              'Present', 
              'Absent', 
              'Overtime', 
              'Half Day',
              'Not Marked',
              'Total Salary (INR)'
            ],
            data: workers.map((w) {
              return [
                w['name'] ?? 'N/A',
                w['designation'] ?? 'N/A',
                w['present'] ?? 0,
                w['absent'] ?? 0,
                w['overtime'] ?? 0,
                w['halfDay'] ?? 0,
                w['notMarked'] ?? 0,
                (w['calculatedSalary'] as num?)?.toStringAsFixed(2) ?? '0.00'
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: primaryColor),
            cellAlignment: pw.Alignment.centerLeft,
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FixedColumnWidth(50),
              3: const pw.FixedColumnWidth(50),
              4: const pw.FixedColumnWidth(50),
              5: const pw.FixedColumnWidth(50),
              6: const pw.FixedColumnWidth(70),
              7: const pw.FlexColumnWidth(1.5),
            },
          ),
          pw.SizedBox(height: 24),

          // Grand Totals Section
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  'Grand Total Payout:',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(width: 24),
                pw.Text(
                  'INR ${totalPayout.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
        footer: (context) => PdfTemplates.buildFooter(context),
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildMetaBox(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label.toUpperCase(),
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
        ),
      ],
    );
  }
}
