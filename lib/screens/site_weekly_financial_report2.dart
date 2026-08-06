import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../utils/pdf_templates.dart';
import '../utils/app_theme.dart';

class SiteWeeklyFinancialReport2 extends StatelessWidget {
  final Map<String, dynamic>? siteDetails;
  final String? paymentPeriod;

  const SiteWeeklyFinancialReport2({
    super.key,
    this.siteDetails,
    this.paymentPeriod,
  });

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 600;

    final String? siteId = siteDetails != null
        ? (siteDetails!['siteId'] ?? siteDetails!['site'])?.toString()
        : null;
    final String? paymentPeriod = this.paymentPeriod;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Financial Report",
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
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => _generatePdf(context, siteId ?? 'N/A', paymentPeriod ?? 'N/A'),
          ),
        ],
      ),
      body:
          Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
          child: siteId == null ||
              siteId.isEmpty ||
              paymentPeriod == null ||
              paymentPeriod.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: FirestoreService.getCollection('siteSupervisorPayments')
                  .where('siteId', isEqualTo: siteId)
                  .where('paymentPeriod', isEqualTo: paymentPeriod)
                  .snapshots()
                  .timeout(const Duration(seconds: 15)),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError ||
                    !snapshot.hasData ||
                    snapshot.data!.docs.isEmpty) {
                  return _buildErrorOrEmpty(context, snapshot);
                }

                final doc = snapshot.data!.docs.first;
                final summary = doc.data() as Map<String, dynamic>;
                final List<dynamic> payments =
                    (summary['payments'] ?? []) as List<dynamic>;
                payments.sort(
                  (a, b) => (a['paymentDate'] ?? '').compareTo(
                    b['paymentDate'] ?? '',
                  ),
                );
                final List<String> paymentDates = payments
                    .map((p) => p['paymentDate']?.toString() ?? '')
                    .where((date) => date.isNotEmpty)
                    .toSet()
                    .toList();

                String? prevPaymentPeriod = _getPrevPeriod(
                  summary['paymentPeriod'],
                );

                return FutureBuilder<Map<String, dynamic>>(
                  future: _fetchOpeningBalance(
                    siteId,
                    prevPaymentPeriod,
                    paymentDates,
                  ),
                  builder: (context, openingSnapshot) {
                    if (!openingSnapshot.hasData)
                      return const Center(child: CircularProgressIndicator());

                    final int openingBalance =
                        (openingSnapshot.data?['openingBalance'] as num? ?? 0)
                            .toInt();
                    final Map<String, num> expensesByDate =
                        Map<String, num>.from(
                          openingSnapshot.data?['expensesByDate'] ?? {},
                        );

                    int totalPayment = 0;
                    int totalExpenses = 0;
                    for (var p in payments) {
                      final String date = p['paymentDate'] ?? '';
                      totalPayment += (p['paymentAmount'] as num? ?? 0).toInt();
                      totalExpenses += (expensesByDate[date] ?? 0).toInt();
                    }

                    int totalAmount = openingBalance + totalPayment;
                    int totalNet = totalAmount - totalExpenses;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 24,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 800),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSiteInfoCard(context, summary),
                              const SizedBox(height: 24),
                              _buildSummaryGrid(
                                context,
                                openingBalance,
                                totalPayment,
                                totalAmount,
                                totalExpenses,
                                totalNet,
                                colorScheme,
                              ),
                              const SizedBox(height: 32),
                              Text(
                                'Daily Breakdown',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildPaymentsTable(
                                context,
                                payments,
                                expensesByDate,
                                openingBalance,
                                colorScheme,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
        ),
      ),
    );
  }

  Widget _buildErrorOrEmpty(BuildContext context, AsyncSnapshot snapshot) {
    bool isError = snapshot.hasError;
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.receipt_long_rounded,
            size: 80,
            color: colorScheme.onSurfaceVariant.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            isError ? 'Error Loading Data' : 'No Records Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSiteInfoCard(
    BuildContext context,
    Map<String, dynamic> summary,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Color(0xFF64748B),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Site Details',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colorScheme.primary.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  summary['paymentPeriod'] ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 32,
            runSpacing: 16,
            children: [
              _buildDetailItem(context, 'Site ID', summary['siteId'] ?? ''),
              _buildDetailItem(
                context,
                'Supervisor',
                summary['supervisorName'] ?? '',
              ),
              _buildDetailItem(
                context,
                'Project',
                summary['projectName'] ?? '',
              ),
              _buildDetailItem(context, 'Stage', summary['projectStage'] ?? ''),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryGrid(
    BuildContext context,
    int opening,
    int payment,
    int amount,
    int expenses,
    int net,
    ColorScheme colorScheme,
  ) {
    // Use LayoutBuilder so item width/height are always based on actual available space.
    final cards = [
      _buildSummaryItem(context, 'Opening', opening, Icons.account_balance_rounded, const Color(0xFF64748B)),
      _buildSummaryItem(context, 'Payments', payment, Icons.payment_rounded, colorScheme.primary),
      _buildSummaryItem(context, 'Expenses', expenses, Icons.receipt_long_rounded, const Color(0xFFF59E0B)),
      _buildSummaryItem(
        context, 'Net Amount', net, Icons.account_balance_wallet_rounded,
        net >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
      ),
    ];
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final double itemWidth = (constraints.maxWidth - 16) / 2;
        const double itemHeight = 88;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: cards
              .map((c) => SizedBox(width: itemWidth, height: itemHeight, child: c))
              .toList(),
        );
      },
    );
  }

  Widget _buildSummaryItem(
    BuildContext context,
    String title,
    int amount,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    NumberFormat.currency(
                      locale: 'en_IN',
                      symbol: '₹',
                      decimalDigits: 0,
                    ).format(amount),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsTable(
    BuildContext context,
    List<dynamic> payments,
    Map<String, num> expensesByDate,
    int openingBalance,
    ColorScheme colorScheme,
  ) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(1.2),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(1),
          3: FlexColumnWidth(1),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.05),
            ),
            children: [
              _buildTableCell(context, 'Date', isHeader: true),
              _buildTableCell(context, 'Payment', isHeader: true),
              _buildTableCell(context, 'Expenses', isHeader: true),
              _buildTableCell(context, 'Net', isHeader: true),
            ],
          ),
          TableRow(
            children: [
              _buildTableCell(context, 'Opening'),
              _buildTableCell(context, '-'),
              _buildTableCell(context, '-'),
              _buildTableCell(
                context,
                NumberFormat.currency(
                  locale: 'en_IN',
                  symbol: '₹',
                  decimalDigits: 0,
                ).format(openingBalance),
                isNet: true,
                netValue: openingBalance,
              ),
            ],
          ),
          ...payments.map((p) {
            final String date = p['paymentDate'] ?? '';
            final int pAmt = (p['paymentAmount'] ?? 0).toInt() as int;
            final int eAmt = (expensesByDate[date] ?? 0).toInt();
            final int net = pAmt - eAmt;
            return TableRow(
              children: [
                _buildTableCell(context, date),
                _buildTableCell(
                  context,
                  NumberFormat.currency(
                    locale: 'en_IN',
                    symbol: '₹',
                    decimalDigits: 0,
                  ).format(pAmt),
                ),
                _buildTableCell(
                  context,
                  NumberFormat.currency(
                    locale: 'en_IN',
                    symbol: '₹',
                    decimalDigits: 0,
                  ).format(eAmt),
                ),
                _buildTableCell(
                  context,
                  NumberFormat.currency(
                    locale: 'en_IN',
                    symbol: '₹',
                    decimalDigits: 0,
                  ).format(net),
                  isNet: true,
                  netValue: net,
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTableCell(
    BuildContext context,
    String text, {
    bool isHeader = false,
    bool isNet = false,
    int netValue = 0,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    Color? txtColor = colorScheme.onSurface;
    if (isHeader) txtColor = colorScheme.onSurfaceVariant;
    if (isNet)
      txtColor = netValue >= 0
          ? const Color(0xFF10B981)
          : const Color(0xFFEF4444);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(
        text,
        textAlign: isHeader ? TextAlign.start : TextAlign.start,
        style: TextStyle(
          fontWeight: isHeader || isNet ? FontWeight.bold : FontWeight.normal,
          color: txtColor,
          fontSize: isHeader ? 11 : 12,
        ),
      ),
    );
  }

  String? _getPrevPeriod(String? period) {
    if (period == null) return null;
    final reg = RegExp(r'^(\d{4})_(\w{3})_Week(\d+)$');
    final match = reg.firstMatch(period);
    if (match != null) {
      final year = match.group(1)!;
      final month = match.group(2)!;
      final week = int.parse(match.group(3)!);
      if (week > 1) return '${year}_${month}_Week${week - 1}';
    }
    return null;
  }

  Future<Map<String, dynamic>> _fetchOpeningBalance(
    String siteId,
    String? prevPeriod,
    List<String> dates,
  ) async {
    int opening = 0;
    if (prevPeriod != null) {
      opening = await _computeNetForPeriod(siteId, prevPeriod, {});
    }
    final exp = await _fetchExpenses(siteId, dates);
    return {'openingBalance': opening, 'expensesByDate': exp};
  }

  Future<int> _computeNetForPeriod(
    String siteId,
    String period,
    Map<String, int> cache,
  ) async {
    if (cache.containsKey(period)) return cache[period]!;
    final snap = await FirestoreService.getCollection('siteSupervisorPayments')
        .where('siteId', isEqualTo: siteId)
        .where('paymentPeriod', isEqualTo: period)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return 0;

    final data = snap.docs.first.data() as Map<String, dynamic>;
    final List<dynamic> payments = (data['payments'] ?? []) as List<dynamic>;
    final List<String> dates = payments
        .map((p) => p['paymentDate']?.toString() ?? '')
        .where((d) => d.isNotEmpty)
        .toList();
    final prev = _getPrevPeriod(period);

    int opening = 0;
    if (prev != null) opening = await _computeNetForPeriod(siteId, prev, cache);

    final exp = await _fetchExpenses(siteId, dates);
    int tPay = 0, tExp = 0;
    for (var p in payments) {
      tPay += (p['paymentAmount'] as num? ?? 0).toInt();
      tExp += (exp[p['paymentDate']] ?? 0).toInt();
    }
    int net = opening + tPay - tExp;
    cache[period] = net;
    return net;
  }

  Future<Map<String, num>> _fetchExpenses(
    String siteId,
    List<String> dates,
  ) async {
    Map<String, num> result = {};
    try {
      QuerySnapshot entrySnap = await FirestoreService.getCollection(
        'siteSupervisorEntries',
      ).where('siteId', isEqualTo: siteId).get();
      for (var doc in entrySnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        String entryDate = '';
        if (data['date'] is String) {
          entryDate = DateFormat(
            'yyyy-MM-dd',
          ).format(DateTime.parse(data['date']));
        } else if (data['date'] is Timestamp) {
          entryDate = DateFormat(
            'yyyy-MM-dd',
          ).format((data['date'] as Timestamp).toDate());
        }
        if (dates.contains(entryDate)) {
          num amt = (data['totalAmount'] ?? 0) as num;
          result[entryDate] = (result[entryDate] ?? 0) + amt;
        }
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
    for (var d in dates) {
      if (!result.containsKey(d)) result[d] = 0;
    }
    return result;
  }

  Future<void> _generatePdf(BuildContext context, String siteId, String period) async {
    final pdf = pw.Document();
    final pdfPrimaryColor = PdfColor.fromInt(Theme.of(context).primaryColor.value);
    final orgDetails = await PdfTemplates.fetchOrgDetails();

    // Fetch same data as in build
    final prevPeriod = _getPrevPeriod(period);
    final snap = await FirestoreService.getCollection('siteSupervisorPayments')
        .where('siteId', isEqualTo: siteId)
        .where('paymentPeriod', isEqualTo: period)
        .limit(1)
        .get();
    
    if (snap.docs.isEmpty) return;
    final summary = snap.docs.first.data() as Map<String, dynamic>;
    final List<dynamic> payments = (summary['payments'] ?? []) as List<dynamic>;
    final List<String> dates = payments.map((p) => p['paymentDate']?.toString() ?? '').where((d) => d.isNotEmpty).toList();
    
    final openingData = await _fetchOpeningBalance(siteId, prevPeriod, dates);
    final int openingBalance = (openingData['openingBalance'] as num? ?? 0).toInt();
    final Map<String, num> expensesByDate = Map<String, num>.from(openingData['expensesByDate'] ?? {});

    int totalPayment = 0;
    int totalExpenses = 0;
    for (var p in payments) {
      totalPayment += (p['paymentAmount'] as num? ?? 0).toInt();
      totalExpenses += (expensesByDate[p['paymentDate']] ?? 0).toInt();
    }
    int totalNet = openingBalance + totalPayment - totalExpenses;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(12 * PdfPageFormat.mm),
        header: (context) => PdfTemplates.buildHeader(
          reportTitle: 'Weekly Financial Report',
          orgDetails: orgDetails,
          primaryColor: pdfPrimaryColor,
        ),
        build: (pw.Context context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              PdfTemplates.buildMetaBox('Site ID', siteId, pdfPrimaryColor),
              PdfTemplates.buildMetaBox('Period', period, pdfPrimaryColor),
              PdfTemplates.buildMetaBox('Net Balance', '₹ $totalNet', pdfPrimaryColor),
            ],
          ),
          pw.SizedBox(height: 24),

          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
               PdfTemplates.buildMetaBox('Opening Balance', '₹ $openingBalance', pdfPrimaryColor),
               PdfTemplates.buildMetaBox('Total Received', '₹ $totalPayment', pdfPrimaryColor),
               PdfTemplates.buildMetaBox('Total Spent', '₹ $totalExpenses', pdfPrimaryColor),
            ],
          ),
          pw.SizedBox(height: 32),

          pw.Text('Daily Breakdown', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: ['Date', 'Payment', 'Expenses', 'Net'],
            data: payments.map((p) {
              final String date = p['paymentDate'] ?? '';
              final int pAmt = (p['paymentAmount'] ?? 0).toInt();
              final int eAmt = (expensesByDate[date] ?? 0).toInt();
              return [date, '₹ $pAmt', '₹ $eAmt', '₹ ${pAmt - eAmt}'];
            }).toList(),
            headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
            headerDecoration: pw.BoxDecoration(color: pdfPrimaryColor),
            cellAlignment: pw.Alignment.centerLeft,
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
          ),
        ],
        footer: (context) => PdfTemplates.buildFooter(context),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}
