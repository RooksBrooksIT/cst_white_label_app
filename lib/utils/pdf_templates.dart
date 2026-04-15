import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import 'app_theme.dart';

class PdfTemplates {
  /// Fetches organization data for PDF headers.
  static Future<Map<String, String>> fetchOrgDetails() async {
    try {
      final doc = await FirestoreService.orgDataDoc.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'orgName': data['orgName']?.toString() ?? AppTheme.appName.value,
          'address': data['address']?.toString() ?? 'N/A',
          'orgPhone': data['orgPhone']?.toString() ?? 'N/A',
        };
      }
    } catch (e) {
      print('Error fetching org details for PDF: $e');
    }
    return {
      'orgName': AppTheme.appName.value,
      'address': 'N/A',
      'orgPhone': 'N/A',
    };
  }

  /// Builds a professional standard header for all reports.
  static pw.Widget buildHeader({
    required String reportTitle,
    required Map<String, String> orgDetails,
    required PdfColor primaryColor,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  orgDetails['orgName']!.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  orgDetails['address']!,
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                ),
                pw.Text(
                  'Phone: ${orgDetails['orgPhone']}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                ),
              ],
            ),
            pw.Text(
              reportTitle.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(thickness: 1.5, color: primaryColor),
        pw.SizedBox(height: 16),
      ],
    );
  }

  /// Helper to build metadata boxes in rows
  static pw.Widget buildMetaBox(String label, String value, PdfColor primaryColor) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label.toUpperCase(),
          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: primaryColor,
          ),
        ),
      ],
    );
  }

  /// Standard footer for reports
  static pw.Widget buildFooter(pw.Context context) {
    return pw.Column(
      children: [
        pw.Divider(thickness: 0.5, color: PdfColors.grey400),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generated via ${AppTheme.appName.value} | Confidential',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
          ],
        ),
      ],
    );
  }
}
