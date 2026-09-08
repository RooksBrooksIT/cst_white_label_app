import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:ebricks/models/petty_cash_models.dart';
import 'package:ebricks/services/firestore_service.dart';
import 'package:ebricks/utils/pdf_templates.dart';

class PettyCashReportPdfHelper {
  /// Generates and previews/downloads the Petty Cash PDF Report
  static Future<void> generateAndDownloadPdf({
    required BuildContext context,
    required List<PettyCashRequest> requests,
    List<PettyCashTransaction>? transactions,
    String? selectedMonth,
    Color? primaryColor,
  }) async {
    final effectiveColor = primaryColor ?? Theme.of(context).primaryColor;
    final pdfColor = PdfColor.fromInt(effectiveColor.toARGB32());

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => const Center(
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Generating Petty Cash PDF Report...',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // If requests list is empty, attempt to fetch from Firestore
      List<PettyCashRequest> activeRequests = List.from(requests);
      if (activeRequests.isEmpty) {
        try {
          final snap = await FirestoreService.pettyCashRequests.get();
          activeRequests = snap.docs
              .map((d) => PettyCashRequest.fromMap(d.id, d.data()))
              .toList();
        } catch (e) {
          debugPrint('Error fetching petty cash requests for PDF: $e');
        }
      }

      // Filter by selectedMonth if specified (e.g. "Aug 2026")
      if (selectedMonth != null && selectedMonth.isNotEmpty && selectedMonth != 'All') {
        activeRequests = activeRequests.where((r) {
          final d = r.orgApprovedAt ?? r.allocatedAt ?? r.createdAt;
          if (d == null) return false;
          return DateFormat('MMM yyyy').format(d) == selectedMonth;
        }).toList();
      }

      // Sort by approval date / creation date descending
      activeRequests.sort((a, b) {
        final tA = a.orgApprovedAt ?? a.allocatedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tB = b.orgApprovedAt ?? b.allocatedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return tB.compareTo(tA);
      });

      final pdfBytes = await buildPdfBytes(
        requests: activeRequests,
        transactions: transactions ?? [],
        selectedMonth: selectedMonth,
        primaryColor: pdfColor,
      );

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // dismiss loading dialog
      }

      final fileName = selectedMonth != null && selectedMonth.isNotEmpty && selectedMonth != 'All'
          ? 'Petty_Cash_Report_${selectedMonth.replaceAll(' ', '_')}.pdf'
          : 'Petty_Cash_Report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: fileName,
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF report: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// Builds the complete PDF bytes document
  static Future<Uint8List> buildPdfBytes({
    required List<PettyCashRequest> requests,
    required List<PettyCashTransaction> transactions,
    String? selectedMonth,
    required PdfColor primaryColor,
  }) async {
    await PdfTemplates.loadFonts();
    final orgDetails = await PdfTemplates.fetchOrgDetails();

    final pdf = pw.Document();

    // Summary calculations
    double totalApprovedAmount = 0.0;
    double totalConfirmedReceived = 0.0;
    int confirmedCount = 0;
    int pendingCount = 0;
    int rejectedCount = 0;

    for (final req in requests) {
      final double approvedAmt = req.approvedAmount > 0
          ? req.approvedAmount
          : (req.allocatedAmount > 0 ? req.allocatedAmount : req.requestedAmount);

      totalApprovedAmount += approvedAmt;

      final isConfirmed = req.isReceived || req.receivedAt != null || req.status == 'received';
      final isRejected = req.status == 'rejected_by_org' || req.status == 'rejected_by_manager';

      if (isConfirmed) {
        totalConfirmedReceived += approvedAmt;
        confirmedCount++;
      } else if (isRejected) {
        rejectedCount++;
      } else {
        pendingCount++;
      }
    }

    final String generatedAt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final String periodLabel = (selectedMonth != null && selectedMonth.isNotEmpty && selectedMonth != 'All')
        ? 'Period: $selectedMonth'
        : 'All Active Records';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        header: (pw.Context ctx) => _buildPdfHeader(
          orgDetails: orgDetails,
          primaryColor: primaryColor,
          periodLabel: periodLabel,
          generatedAt: generatedAt,
        ),
        footer: (pw.Context ctx) => PdfTemplates.buildFooter(ctx),
        build: (pw.Context ctx) {
          return [
            // ── Executive KPI Summary Row ──
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem('TOTAL REQUESTS', '${requests.length}', primaryColor),
                  _buildSummaryItem('TOTAL APPROVED', _formatCurrency(totalApprovedAmount), PdfColors.blue800),
                  _buildSummaryItem('CONFIRMED RECEIVED', '${_formatCurrency(totalConfirmedReceived)} ($confirmedCount)', PdfColors.green800),
                  _buildSummaryItem('PENDING CONFIRMATION', '$pendingCount', PdfColors.amber800),
                  if (rejectedCount > 0)
                    _buildSummaryItem('DECLINED / REJECTED', '$rejectedCount', PdfColors.red800),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // ── Table Title ──
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'PETTY CASH REQUESTS, ALLOCATIONS & SUPERVISOR CONFIRMATION RECORDS',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    font: PdfTemplates.boldFont,
                    color: PdfColors.blueGrey900,
                  ),
                ),
                pw.Text(
                  'Showing ${requests.length} entries',
                  style: pw.TextStyle(
                    fontSize: 9.5,
                    font: PdfTemplates.regularFont,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 8),

            // ── Main Data Table ──
            if (requests.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 28),
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Text(
                  'No petty cash records found for the selected period.',
                  style: pw.TextStyle(
                    fontSize: 12,
                    font: PdfTemplates.boldFont,
                    color: PdfColors.grey600,
                  ),
                ),
              )
            else
              pw.TableHelper.fromTextArray(
                headers: [
                  '#',
                  'APPROVAL DATE',
                  'APPROVED AMOUNT',
                  'SUPERVISOR NAME',
                  'MANAGER NAME',
                  'RECEIVED CONFIRMATION',
                  'CONFIRMATION DATE / STATUS',
                ],
                data: List<List<String>>.generate(requests.length, (index) {
                  final req = requests[index];

                  // 1. Approval Date
                  DateTime? approvalDate = req.orgApprovedAt ?? req.allocatedAt;
                  if (approvalDate == null && req.approvalHistory.isNotEmpty) {
                    for (final h in req.approvalHistory) {
                      final act = h['action']?.toString().toLowerCase() ?? '';
                      if (act.contains('approv') || act.contains('authoriz')) {
                        if (h['timestamp'] != null) {
                          try {
                            if (h['timestamp'] is Timestamp) {
                              approvalDate = (h['timestamp'] as Timestamp).toDate();
                            }
                          } catch (_) {}
                        }
                      }
                    }
                  }
                  approvalDate ??= (req.status == 'approved' || req.status == 'received' || req.allocatedAmount > 0)
                      ? (req.createdAt ?? DateTime.now())
                      : null;

                  final String approvalDateStr = approvalDate != null
                      ? DateFormat('dd/MM/yyyy').format(approvalDate)
                      : (req.status.contains('pending') ? 'Pending' : 'N/A');

                  // 2. Approved Amount
                  final double approvedAmt = req.approvedAmount > 0
                      ? req.approvedAmount
                      : (req.allocatedAmount > 0 ? req.allocatedAmount : req.requestedAmount);
                  final String approvedAmountStr = _formatCurrency(approvedAmt);

                  // 3. Supervisor Name
                  final String supName = req.supervisorName.isNotEmpty
                      ? req.supervisorName
                      : (req.receivedBySupervisorName ?? req.supervisorId);

                  // 4. Manager Name
                  final String mgrName = req.managerName.isNotEmpty
                      ? req.managerName
                      : (req.managerReviewedBy ?? 'Manager');

                  // 5. Received Confirmation
                  final bool isConfirmed = req.isReceived || req.receivedAt != null || req.status == 'received';
                  final bool isRejected = req.status == 'rejected_by_org' || req.status == 'rejected_by_manager';
                  final bool isAwaiting = req.status == 'awaiting_confirmation' ||
                      req.status == 'awaiting_receipt_confirmation' ||
                      (req.allocatedAmount > 0 && req.receivedAt == null);

                  String confirmationText;
                  if (isConfirmed) {
                    confirmationText = 'YES (CONFIRMED)';
                  } else if (isRejected) {
                    confirmationText = 'REJECTED';
                  } else if (isAwaiting) {
                    confirmationText = 'AWAITING CONFIRM';
                  } else {
                    confirmationText = 'PENDING APPROVAL';
                  }

                  // 6. Confirmation Date / Status Detail
                  String statusDateDetail;
                  if (req.receivedAt != null) {
                    statusDateDetail = 'Confirmed on ${DateFormat('dd/MM/yyyy HH:mm').format(req.receivedAt!)}';
                  } else if (isConfirmed) {
                    statusDateDetail = 'Received & Added to Balance';
                  } else if (isRejected) {
                    statusDateDetail = req.rejectionReason.isNotEmpty
                        ? 'Declined: ${req.rejectionReason}'
                        : 'Declined by Org/Mgr';
                  } else if (isAwaiting) {
                    statusDateDetail = 'Awaiting Physical Cash Receipt';
                  } else if (req.status == 'pending_org_approval') {
                    statusDateDetail = 'Awaiting HQ Org Authorization';
                  } else {
                    statusDateDetail = req.statusDisplay.isNotEmpty
                        ? req.statusDisplay
                        : 'Pending Review';
                  }

                  return [
                    '${index + 1}',
                    approvalDateStr,
                    approvedAmountStr,
                    supName,
                    mgrName,
                    confirmationText,
                    statusDateDetail,
                  ];
                }),
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.6,
                ),
                headerStyle: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  font: PdfTemplates.boldFont,
                  color: PdfColors.white,
                ),
                headerDecoration: pw.BoxDecoration(color: primaryColor),
                headerAlignment: pw.Alignment.centerLeft,
                cellStyle: pw.TextStyle(
                  fontSize: 8,
                  font: PdfTemplates.regularFont,
                  color: PdfColors.grey900,
                ),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                cellAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerLeft,
                  4: pw.Alignment.centerLeft,
                  5: pw.Alignment.center,
                  6: pw.Alignment.centerLeft,
                },
                columnWidths: {
                  0: const pw.FlexColumnWidth(0.5), // #
                  1: const pw.FlexColumnWidth(1.4), // Approval Date
                  2: const pw.FlexColumnWidth(1.6), // Approved Amount
                  3: const pw.FlexColumnWidth(1.8), // Supervisor Name
                  4: const pw.FlexColumnWidth(1.6), // Manager Name
                  5: const pw.FlexColumnWidth(1.8), // Received Confirmation
                  6: const pw.FlexColumnWidth(2.6), // Confirmation Date/Status
                },
                oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
              ),

            pw.SizedBox(height: 18),

            // ── Total Summary Row Table ──
            if (requests.isNotEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: PdfColors.blue200, width: 0.8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'TOTAL PETTY CASH AUTHORIZED ACROSS ALL SITES:',
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                        font: PdfTemplates.boldFont,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.Text(
                      _formatCurrency(totalApprovedAmount),
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        font: PdfTemplates.boldFont,
                        color: PdfColors.blue900,
                      ),
                    ),
                  ],
                ),
              ),

            pw.SizedBox(height: 24),

            // ── Sign-off Authentication Section ──
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildSignBox('Prepared By (Accounts Officer)'),
                _buildSignBox('Verified By (Project Manager)'),
                _buildSignBox('Authorized By (HQ Managing Director)'),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildPdfHeader({
    required Map<String, String> orgDetails,
    required PdfColor primaryColor,
    required String periodLabel,
    required String generatedAt,
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
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    font: PdfTemplates.boldFont,
                    color: primaryColor,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  orgDetails['address']!,
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    font: PdfTemplates.regularFont,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Text(
                  'Phone: ${orgDetails['orgPhone']}',
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    font: PdfTemplates.regularFont,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'ORGANIZATION PETTY CASH REPORT',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    font: PdfTemplates.boldFont,
                    color: PdfColors.grey800,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  periodLabel,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    font: PdfTemplates.boldFont,
                    color: primaryColor,
                  ),
                ),
                pw.Text(
                  'Generated On: $generatedAt',
                  style: pw.TextStyle(
                    fontSize: 8,
                    font: PdfTemplates.regularFont,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Divider(thickness: 1.2, color: primaryColor),
        pw.SizedBox(height: 10),
      ],
    );
  }

  static pw.Widget _buildSummaryItem(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 7.5,
            fontWeight: pw.FontWeight.bold,
            font: PdfTemplates.boldFont,
            color: PdfColors.grey600,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            font: PdfTemplates.boldFont,
            color: color,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildSignBox(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          width: 140,
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.8)),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 7.5,
            font: PdfTemplates.regularFont,
            color: PdfColors.grey700,
          ),
        ),
      ],
    );
  }

  static String _formatCurrency(num amount) {
    final formatter = NumberFormat('#,##,##0.00');
    return 'Rs. ${formatter.format(amount)}';
  }
}
