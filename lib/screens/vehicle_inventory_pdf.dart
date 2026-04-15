import 'dart:typed_data';
import 'package:flutter/material.dart' show BuildContext, Theme;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../utils/pdf_templates.dart';
import '../utils/app_theme.dart';

class InventoryReportPdf {
  static Future<void> generateAndShare({
    required BuildContext context,
    required String title,
    required List<Map<String, dynamic>> rows,
  }) async {
    final primaryColor = Theme.of(context).primaryColor;
    final pdfPrimaryColor = PdfColor.fromInt(primaryColor.value);
    final pdfBytes = await _buildPdf(title: title, rows: rows, primaryColor: pdfPrimaryColor);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
    );
  }

  static Future<Uint8List> _buildPdf({
    required String title,
    required List<Map<String, dynamic>> rows,
    required PdfColor primaryColor,
  }) async {
    final orgDetails = await PdfTemplates.fetchOrgDetails();
    // You can provide custom fonts here if needed using ThemeData.withFont(...)
    final doc = pw.Document();

    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
    final genAt = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    final headers = [
      'Date',
      'Created At',
      'Movement ID',
      'Doc ID',
      'Vehicle ID',
      'Driver',
      'From',
      'To',
      'Type',
      'Start',
      'End',
      'Distance Km',
      'Material',
      'Unit',
      'Qty',
      'Remarks',
    ];

    final data = rows.map((r) {
      String created = '';
      final ts = r['createdAt'];
      if (ts is DateTime) {
        created = dateFmt.format(ts);
      } else if (ts != null) {
        try {
          final toDate = ts.toDate(); // Firestore Timestamp support
          created = dateFmt.format(toDate);
        } catch (_) {
          created = ts.toString();
        }
      }
      return [
        '${r['date'] ?? ''}',
        created,
        '${r['movementId'] ?? ''}',
        '${r['docId'] ?? ''}',
        '${r['vehicleId'] ?? ''}',
        '${r['driverName'] ?? ''}',
        '${r['fromLocation'] ?? ''}',
        '${r['toLocation'] ?? ''}',
        '${r['movementType'] ?? ''}',
        '${r['startTime'] ?? ''}',
        '${r['endTime'] ?? ''}',
        '${r['distanceKm'] ?? ''}',
        '${r['materialType'] ?? ''}',
        '${r['materialUnit'] ?? ''}',
        '${r['quantity'] ?? ''}',
        '${r['remarks'] ?? ''}',
      ];
    }).toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => PdfTemplates.buildHeader(
          reportTitle: title,
          orgDetails: orgDetails,
          primaryColor: primaryColor,
        ),
        build: (context) => [
          pw.DefaultTextStyle(
            style: const pw.TextStyle(fontSize: 9),
            child: pw.Table.fromTextArray(
              headers: headers,
              data: data,
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.3),
              headerAlignment: pw.Alignment.centerLeft,
              cellAlignment: pw.Alignment.centerLeft,
              columnWidths: {
                0: const pw.FixedColumnWidth(58), // Date
                1: const pw.FixedColumnWidth(78), // Created
                2: const pw.FixedColumnWidth(54), // Move ID
                3: const pw.FixedColumnWidth(80), // Doc ID
                4: const pw.FixedColumnWidth(54), // Vehicle
                5: const pw.FixedColumnWidth(66), // Driver
                6: const pw.FixedColumnWidth(66), // From
                7: const pw.FixedColumnWidth(66), // To
                8: const pw.FixedColumnWidth(72), // Type
                9: const pw.FixedColumnWidth(40), // Start
                10: const pw.FixedColumnWidth(40), // End
                11: const pw.FixedColumnWidth(50), // Distance
                12: const pw.FixedColumnWidth(70), // Material
                13: const pw.FixedColumnWidth(36), // Unit
                14: const pw.FixedColumnWidth(36), // Qty
                15: const pw.FlexColumnWidth(), // Remarks
              },
              cellPadding: const pw.EdgeInsets.symmetric(
                vertical: 3,
                horizontal: 4,
              ),
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColors.grey100,
              ),
            ),
          ),
        ],
        footer: (context) => PdfTemplates.buildFooter(context),
      ),
    );

    return doc.save();
  }
}
