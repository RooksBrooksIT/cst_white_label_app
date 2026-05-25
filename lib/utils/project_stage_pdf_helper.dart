import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import './pdf_templates.dart';

class ProjectStagePdfHelper {
  /// Builds the PDF for the Daily Site Expenses report.
  static Future<Uint8List> buildDailyReport({
    required String siteId,
    required String? supervisorId,
    required DateTime date,
    required String projectStage,
    required Map<String, dynamic>? supervisorData,
    required double grandTotal,
    required PdfColor primaryColor,
  }) async {
    final pdf = pw.Document();
    final orgDetails = await PdfTemplates.fetchOrgDetails();
    final dateFormat = DateFormat('dd MMM yyyy');

    double toNum(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(
            v.toString().replaceAll(RegExp(r'[^\d.]'), ''),
          ) ??
          0;
    }

    List<Map<String, dynamic>> parseEntryList(dynamic rawData) {
      if (rawData == null) return [];
      if (rawData is List) {
        return rawData.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      if (rawData is Map) {
        final Map<dynamic, dynamic> map = rawData;
        final List<Map<String, dynamic>> list = [];
        final sortedKeys = map.keys
            .map((k) => int.tryParse(k.toString()))
            .where((k) => k != null)
            .cast<int>()
            .toList()
          ..sort();
        for (var key in sortedKeys) {
          final val = map[key.toString()] ?? map[key];
          if (val is Map) {
            list.add(Map<String, dynamic>.from(val));
          }
        }
        return list;
      }
      return [];
    }

    final materialsList = parseEntryList(supervisorData?['materials']);
    final laboursList = parseEntryList(supervisorData?['labours']);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => PdfTemplates.buildHeader(
          reportTitle: 'Daily Project Report',
          orgDetails: orgDetails,
          primaryColor: primaryColor,
        ),
        build: (pw.Context context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              PdfTemplates.buildMetaBox('Site ID', siteId, primaryColor),
              PdfTemplates.buildMetaBox(
                'Date',
                dateFormat.format(date),
                primaryColor,
              ),
              PdfTemplates.buildMetaBox('Stage', projectStage, primaryColor),
            ],
          ),
          pw.SizedBox(height: 24),

          // Materials Table
          if (materialsList.isNotEmpty) ...[
            pw.Text(
              'Materials Detailed Breakdown',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
            ),
            pw.SizedBox(height: 8),
            pw.Table.fromTextArray(
              headers: ['Material', 'Quantity', 'Amount'],
              data: materialsList
                  .map(
                    (m) => [
                      (m['materialName'] ?? m['type'] ?? 'N/A').toString(),
                      (m['quantity'] ?? m['count'] ?? '0').toString(),
                      '₹ ${toNum(m['amount']).toStringAsFixed(2)}',
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
              ),
              headerDecoration: pw.BoxDecoration(color: primaryColor),
              cellAlignment: pw.Alignment.centerLeft,
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColors.grey100,
              ),
            ),
            pw.SizedBox(height: 20),
          ],

          // Labours Table
          if (laboursList.isNotEmpty) ...[
            pw.Text(
              'Labour Detailed Breakdown',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
            ),
            pw.SizedBox(height: 8),
            pw.Table.fromTextArray(
              headers: ['Labour Type', 'Count', 'Amount'],
              data: laboursList
                  .map(
                    (l) => [
                      (l['labourType'] ?? l['type'] ?? 'N/A').toString(),
                      (l['labourCount'] ?? l['count'] ?? '0').toString(),
                      '₹ ${toNum(l['amount']).toStringAsFixed(2)}',
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
              ),
              headerDecoration: pw.BoxDecoration(color: primaryColor),
              cellAlignment: pw.Alignment.centerLeft,
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColors.grey100,
              ),
            ),
            pw.SizedBox(height: 20),
          ],

          // Other Expenses
          pw.Text(
            'Other Expenses Summary',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
          ),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headers: ['Category', 'Amount'],
            data: [
              [
                'Food / Mess',
                '₹ ${toNum(supervisorData?['food']).toStringAsFixed(2)}',
              ],
              [
                'Fuel',
                '₹ ${toNum(supervisorData?['fuel']).toStringAsFixed(2)}',
              ],
              [
                'Transport / Travel',
                '₹ ${toNum(supervisorData?['transport']).toStringAsFixed(2)}',
              ],
            ],
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
            ),
            headerDecoration: pw.BoxDecoration(color: primaryColor),
            cellAlignment: pw.Alignment.centerLeft,
          ),
          pw.SizedBox(height: 32),

          // Grand Total
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: primaryColor,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'GRAND TOTAL',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                pw.Text(
                  '₹ ${grandTotal.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 18,
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

  /// Builds the PDF for the Expense Range report.
  static Future<Uint8List> buildExpenseRangeReport({
    required String siteId,
    required String projectStage,
    required DateTime fromDate,
    required DateTime toDate,
    required double supervisorTotal,
    required double managerTotal,
    required double organizationTotal,
    required double contractorTotal,
    required double incentiveTotal,
    required PdfColor primaryColor,
  }) async {
    final pdf = pw.Document();
    final orgDetails = await PdfTemplates.fetchOrgDetails();
    final dateFormat = DateFormat('dd MMM yyyy');
    final grandTotal =
        supervisorTotal +
        managerTotal +
        organizationTotal +
        contractorTotal +
        incentiveTotal;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => PdfTemplates.buildHeader(
          reportTitle: 'Stage Expense Range Report',
          orgDetails: orgDetails,
          primaryColor: primaryColor,
        ),
        build: (pw.Context context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              PdfTemplates.buildMetaBox('Site ID', siteId, primaryColor),
              PdfTemplates.buildMetaBox('Stage', projectStage, primaryColor),
              PdfTemplates.buildMetaBox(
                'From',
                dateFormat.format(fromDate),
                primaryColor,
              ),
              PdfTemplates.buildMetaBox(
                'To',
                dateFormat.format(toDate),
                primaryColor,
              ),
            ],
          ),
          pw.SizedBox(height: 32),
          pw.Text(
            'Expense Breakdown by Category',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
          ),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: ['Category', 'Total Amount (₹)'],
            data: [
              ['Supervisor Expenses', supervisorTotal.toStringAsFixed(2)],
              ['Manager Expenses', managerTotal.toStringAsFixed(2)],
              ['Organization Expenses', organizationTotal.toStringAsFixed(2)],
              ['Contractor Expenses', contractorTotal.toStringAsFixed(2)],
              ['Incentives', incentiveTotal.toStringAsFixed(2)],
            ],
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
            ),
            headerDecoration: pw.BoxDecoration(color: primaryColor),
            cellAlignment: pw.Alignment.centerLeft,
            oddRowDecoration: const pw.BoxDecoration(
              color: PdfColors.grey100,
            ),
          ),
          pw.SizedBox(height: 32),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: primaryColor,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'GRAND TOTAL',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                pw.Text(
                  '₹ ${grandTotal.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 18,
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

  /// Builds the PDF for the Site Summary report.
  static Future<Uint8List> buildSiteSummaryReport({
    required String siteId,
    required String projectStage,
    required Map<String, dynamic>? projectInfo,
    required Map<String, num> expenseTotals,
    required num grandTotal,
    required PdfColor primaryColor,
  }) async {
    final pdf = pw.Document();
    final orgDetails = await PdfTemplates.fetchOrgDetails();

    num toNum(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v;
      return num.tryParse(
            v.toString().replaceAll(RegExp(r'[^\d.]'), ''),
          ) ??
          0;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => PdfTemplates.buildHeader(
          reportTitle: 'Project Stage Summary',
          orgDetails: orgDetails,
          primaryColor: primaryColor,
        ),
        build: (pw.Context context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              PdfTemplates.buildMetaBox(
                'Project',
                projectInfo?['projectName'] ?? 'N/A',
                primaryColor,
              ),
              PdfTemplates.buildMetaBox('Site ID', siteId, primaryColor),
              PdfTemplates.buildMetaBox('Stage', projectStage, primaryColor),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              PdfTemplates.buildMetaBox(
                'Location',
                projectInfo?['siteLocation'] ?? 'N/A',
                primaryColor,
              ),
              PdfTemplates.buildMetaBox(
                'Status',
                projectInfo?['status'] ?? 'Active',
                primaryColor,
              ),
              PdfTemplates.buildMetaBox(
                'Budget',
                '₹ ${toNum(projectInfo?['projectBudget']).toStringAsFixed(0)}',
                primaryColor,
              ),
            ],
          ),
          pw.SizedBox(height: 32),
          pw.Text(
            'Expense Category Summary',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
          ),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: ['Category', 'Total Amount'],
            data: expenseTotals.entries
                .map((e) => [e.key, '₹ ${e.value.toStringAsFixed(2)}'])
                .toList(),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
            ),
            headerDecoration: pw.BoxDecoration(color: primaryColor),
            cellAlignment: pw.Alignment.centerLeft,
            oddRowDecoration: const pw.BoxDecoration(
              color: PdfColors.grey100,
            ),
          ),
          pw.SizedBox(height: 32),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: primaryColor,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'STAGE GRAND TOTAL',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                pw.Text(
                  '₹ ${grandTotal.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 18,
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
}
