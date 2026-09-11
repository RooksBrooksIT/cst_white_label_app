import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:ebricks/utils/responsive.dart';
import 'package:ebricks/utils/app_theme.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:ebricks/utils/pdf_templates.dart';
import 'package:ebricks/services/firestore_service.dart';

class ContractorReportPage extends StatefulWidget {
  const ContractorReportPage({super.key});

  @override
  State<ContractorReportPage> createState() => _ContractorReportPageState();
}

class _ContractorReportPageState extends State<ContractorReportPage> {
  List<Map<String, dynamic>> expenses = [];
  bool isLoadingExpenses = false;
  double totalAmount = 0.0;
  String? selectedContractor;
  List<String> contractorNames = [];
  String? selectedSiteId;
  List<String> siteIdOptions = [];
  bool isLoadingContractors = false;
  bool isLoadingSites = false;

  @override
  void initState() {
    super.initState();
    _initializeAndFetch();
  }

  Future<void> _initializeAndFetch() async {
    if (!FirestoreService.isReady) {
      await FirestoreService.initialize();
    }
    await _fetchContractorNames();
  }

  Future<void> _fetchContractorNames() async {
    if (mounted) setState(() => isLoadingContractors = true);
    try {
      debugPrint(
        'ContractorReportPage: Fetching contractors from ${FirestoreService.contractors.path}',
      );

      // 1. Fetch from contractors collection
      final contractorsSnapshot = await FirestoreService.contractors
          .orderBy('contractorName')
          .limit(500)
          .get();

      final Set<String> allNames = {};

      for (var doc in contractorsSnapshot.docs) {
        final name = (doc.data()['contractorName'] as String?)?.trim();
        if (name != null && name.isNotEmpty) allNames.add(name);
      }

      // 2. Also check contractorEntries to ensure we have everyone who has entries
      final entriesSnapshot = await FirestoreService.contractorEntries
          .limit(500) // Just a sample to find active contractors
          .get();

      for (var doc in entriesSnapshot.docs) {
        final name = (doc.data()['contractorName'] as String?)?.trim();
        if (name != null && name.isNotEmpty) allNames.add(name);
      }

      final sortedNames = allNames.toList();
      sortedNames.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      debugPrint(
        'ContractorReportPage: Found ${sortedNames.length} contractors',
      );
      if (mounted) {
        setState(() {
          contractorNames = sortedNames;
          if (sortedNames.isNotEmpty) {
            selectedContractor = sortedNames.first;
          }
          isLoadingContractors = false;
        });
        if (selectedContractor != null) {
          await _fetchSiteIdsForContractor(selectedContractor!);
        }
      }
    } catch (e) {
      debugPrint('ContractorReportPage: Error fetching contractors: $e');
      if (mounted) setState(() => isLoadingContractors = false);
    }
  }

  Future<void> _fetchSiteIdsForContractor(String contractorName) async {
    if (mounted) {
      setState(() {
        isLoadingSites = true;
        siteIdOptions = [];
        selectedSiteId = null;
      });
    }
    try {
      debugPrint('ContractorReportPage: Fetching site IDs for $contractorName');

      final Set<String> allSiteIds = {};

      // 1. Fetch from projects collection
      Query<Map<String, dynamic>> projectQuery = FirestoreService.projects
          .where('isContractWork', isEqualTo: true);

      projectQuery = projectQuery.where(
        'contractorName',
        isEqualTo: contractorName,
      );

      final projectSnapshot = await projectQuery.limit(500).get();
      for (var doc in projectSnapshot.docs) {
        final sid = doc.data()['siteId']?.toString().trim();
        if (sid != null && sid.isNotEmpty) allSiteIds.add(sid);
      }

      // 2. Fetch from contractorEntries to ensure we have all sites with data
      Query<Map<String, dynamic>> entriesQuery =
          FirestoreService.contractorEntries;
      entriesQuery = entriesQuery.where(
        'contractorName',
        isEqualTo: contractorName,
      );

      final entriesSnapshot = await entriesQuery.limit(500).get();
      for (var doc in entriesSnapshot.docs) {
        final sid = doc.data()['siteId']?.toString().trim();
        if (sid != null && sid.isNotEmpty) allSiteIds.add(sid);
      }

      final sortedIds = allSiteIds.toList();
      sortedIds.sort();

      debugPrint('ContractorReportPage: Found ${sortedIds.length} site IDs');
      if (mounted) {
        setState(() {
          siteIdOptions = sortedIds;
          if (sortedIds.isNotEmpty) {
            selectedSiteId = sortedIds.first;
          }
          isLoadingSites = false;
        });
        if (selectedSiteId != null) {
          _fetchExpenses();
        }
      }
    } catch (e) {
      debugPrint('ContractorReportPage: Error fetching site IDs: $e');
      if (mounted) setState(() => isLoadingSites = false);
    }
  }

  Future<void> _fetchExpenses() async {
    if (selectedContractor == null || selectedSiteId == null) return;
    if (mounted) {
      setState(() {
        isLoadingExpenses = true;
        expenses = [];
        totalAmount = 0.0;
      });
    }
    try {
      debugPrint(
        'ContractorReportPage: Fetching expenses for $selectedContractor at $selectedSiteId',
      );

      final querySnapshot = await FirestoreService.contractorEntries
          .where('contractorName', isEqualTo: selectedContractor)
          .where('siteId', isEqualTo: selectedSiteId)
          .limit(1000)
          .get();

      if (!mounted) return;
      double sum = 0.0;
      final List<Map<String, dynamic>> fetched = [];
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final amt = data['totalAmount'] ?? data['amount'] ?? 0;
        sum += (amt is num)
            ? amt.toDouble()
            : (double.tryParse(amt.toString()) ?? 0.0);
        fetched.add(data);
      }
      debugPrint(
        'ContractorReportPage: Found ${fetched.length} entries, total: $sum',
      );
      if (mounted) {
        setState(() {
          expenses = fetched;
          totalAmount = sum;
          isLoadingExpenses = false;
        });
      }
    } catch (e) {
      debugPrint('ContractorReportPage: Error fetching expenses: $e');
      if (mounted) setState(() => isLoadingExpenses = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading report: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.primaryColor,
      builder: (context, primaryColor, _) {
        final darkAccent = AppTheme.getDarkAccent(primaryColor);

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text(
              'Contractor Report',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: -0.3,
              ),
            ),
            centerTitle: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
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
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 20),
                onPressed: expenses.isNotEmpty ? _generatePdf : null,
                tooltip: 'Export PDF Report',
              ),
            ],
          ),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isMobile ? double.infinity : 680,
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.all(isMobile ? 16 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildFilterCard(primaryColor, darkAccent),
                      const SizedBox(height: 20),
                      if (isLoadingExpenses)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(48),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (expenses.isNotEmpty)
                        _buildReportSection(primaryColor)
                      else if (selectedContractor != null && selectedSiteId != null)
                        _buildEmptyState(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterCard(Color primaryColor, Color darkAccent) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.tune_rounded, color: primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Report Parameters',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Select contractor & site location',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildDropdown(
            label: 'Contractor Name',
            items: contractorNames,
            value: selectedContractor,
            onChanged: (v) async {
              setState(() => selectedContractor = v);
              if (v != null) {
                await _fetchSiteIdsForContractor(v);
                _fetchExpenses();
              }
            },
            loading: isLoadingContractors,
            icon: Icons.person_rounded,
            primaryColor: primaryColor,
          ),
          const SizedBox(height: 16),
          _buildDropdown(
            label: 'Site ID',
            items: siteIdOptions,
            value: selectedSiteId,
            onChanged: (v) {
              setState(() => selectedSiteId = v);
              _fetchExpenses();
            },
            loading: isLoadingSites,
            icon: Icons.location_on_rounded,
            primaryColor: primaryColor,
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.analytics_rounded, size: 20),
              label: const Text(
                'GENERATE REPORT',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE2E8F0),
                disabledForegroundColor: const Color(0xFF94A3B8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
                shadowColor: primaryColor.withValues(alpha: 0.25),
              ),
              onPressed: selectedContractor != null && selectedSiteId != null
                  ? _fetchExpenses
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required List<String> items,
    required String? value,
    required Function(String?) onChanged,
    required bool loading,
    required IconData icon,
    required Color primaryColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF64748B),
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 7),
        DropdownButtonFormField<String>(
          initialValue: (value != null && items.contains(value)) ? value : null,
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(14),
          icon: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF64748B),
                ),
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: 'Select $label',
            hintStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Icon(icon, color: primaryColor, size: 20),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: primaryColor, width: 1.5),
            ),
          ),
          items: items
              .map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Text(
                    s,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildReportSection(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Summary KPI Cards ──────────────────────────────────────────
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _buildKpiCard(
                title: 'Total Payable',
                value: '₹ ${totalAmount.toStringAsFixed(2)}',
                subtitle: selectedContractor ?? '',
                icon: Icons.payments_rounded,
                accentColor: const Color(0xFFDC2626),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _buildKpiCard(
                title: 'Total Entries',
                value: '${expenses.length}',
                subtitle: 'Site: ${selectedSiteId ?? '-'}',
                icon: Icons.receipt_long_rounded,
                accentColor: primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ── Export PDF Action Button ─────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
            label: const Text(
              'EXPORT CONTRACTOR PDF',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 2,
              shadowColor: primaryColor.withValues(alpha: 0.25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: expenses.isNotEmpty ? _generatePdf : null,
          ),
        ),
        const SizedBox(height: 24),

        // ── Section Title ───────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'EXPENSE ENTRIES LOG',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF64748B),
                letterSpacing: 0.8,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${expenses.length} Records',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Entries List ────────────────────────────────────────────
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: expenses.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) {
            final exp = expenses[i];
            final date = _formatDate(exp['date']);
            final amt = exp['totalAmount'] ?? exp['amount'] ?? 0;
            final double numAmt = (amt is num)
                ? amt.toDouble()
                : (double.tryParse(amt.toString()) ?? 0.0);

            final food = (exp['food'] is num)
                ? (exp['food'] as num).toDouble()
                : (double.tryParse(exp['food']?.toString() ?? '') ?? 0.0);
            final fuel = (exp['fuel'] is num)
                ? (exp['fuel'] as num).toDouble()
                : (double.tryParse(exp['fuel']?.toString() ?? '') ?? 0.0);
            final transport = (exp['transport'] is num)
                ? (exp['transport'] as num).toDouble()
                : (double.tryParse(exp['transport']?.toString() ?? '') ?? 0.0);
            final hasBreakdown = food > 0 || fuel > 0 || transport > 0;

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0A183D).withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _showEntryDetails(exp, primaryColor),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.receipt_long_rounded,
                                color: primaryColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    date,
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on_rounded,
                                        size: 13,
                                        color: Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        'Site: ${exp['siteId'] ?? selectedSiteId}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹ ${numAmt.toStringAsFixed(numAmt == numAmt.roundToDouble() ? 0 : 2)}',
                                  style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'View Breakdown',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: primaryColor,
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      size: 15,
                                      color: primaryColor,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (hasBreakdown) ...[
                          const SizedBox(height: 12),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              if (food > 0)
                                _buildCostPill('Food: ₹${food.toStringAsFixed(0)}', const Color(0xFFD97706)),
                              if (fuel > 0)
                                _buildCostPill('Fuel: ₹${fuel.toStringAsFixed(0)}', const Color(0xFF2563EB)),
                              if (transport > 0)
                                _buildCostPill('Transport: ₹${transport.toStringAsFixed(0)}', const Color(0xFF059669)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.6,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: accentColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCostPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 40,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Expense Records Found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No expense entries found for $selectedContractor at $selectedSiteId.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic d) {
    if (d == null) return '-';
    if (d is Timestamp) return DateFormat('dd MMM yyyy').format(d.toDate());
    if (d is String) return d;
    return '-';
  }

  void _showEntryDetails(Map<String, dynamic> exp, Color primaryColor) {
    final amt = exp['totalAmount'] ?? exp['amount'] ?? 0;
    final date = _formatDate(exp['date']);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.receipt_long_rounded, color: primaryColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Contractor Entry Breakdown',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Entry date: $date',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _detailRow('Contractor', exp['contractorName'] ?? selectedContractor ?? '-'),
                  const Divider(height: 16, color: Color(0xFFE2E8F0)),
                  _detailRow('Site ID', exp['siteId'] ?? selectedSiteId ?? '-'),
                  const Divider(height: 16, color: Color(0xFFE2E8F0)),
                  _detailRow('Food Cost', '₹ ${exp['food'] ?? 0}'),
                  const Divider(height: 16, color: Color(0xFFE2E8F0)),
                  _detailRow('Fuel Cost', '₹ ${exp['fuel'] ?? 0}'),
                  const Divider(height: 16, color: Color(0xFFE2E8F0)),
                  _detailRow('Transport Cost', '₹ ${exp['transport'] ?? 0}'),
                  const Divider(height: 20, color: Color(0xFFCBD5E1)),
                  _detailRow(
                    'Total Payable',
                    '₹ $amt',
                    isBold: true,
                    highlightColor: const Color(0xFF0F172A),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  foregroundColor: const Color(0xFF0F172A),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'CLOSE',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value, {
    bool isBold = false,
    Color? highlightColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 14.5 : 13.5,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: isBold ? const Color(0xFF0F172A) : const Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 13.5,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            color: highlightColor ?? (isBold ? const Color(0xFF0F172A) : const Color(0xFF0F172A)),
          ),
        ),
      ],
    );
  }

  Future<void> _generatePdf() async {
    final primaryColor = Theme.of(context).primaryColor;
    await PdfTemplates.loadFonts();
    final pdf = pw.Document();
    final pdfPrimaryColor = PdfColor.fromInt(
      primaryColor.toARGB32(),
    );
    final orgDetails = await PdfTemplates.fetchOrgDetails();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => PdfTemplates.buildHeader(
          reportTitle: 'Contractor Report',
          orgDetails: orgDetails,
          primaryColor: pdfPrimaryColor,
        ),
        build: (pw.Context context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              PdfTemplates.buildMetaBox(
                'Contractor',
                selectedContractor ?? 'N/A',
                pdfPrimaryColor,
              ),
              PdfTemplates.buildMetaBox(
                'Site ID',
                selectedSiteId ?? 'N/A',
                pdfPrimaryColor,
              ),
              PdfTemplates.buildMetaBox(
                'Total Payable',
                '₹ ${totalAmount.toStringAsFixed(2)}',
                pdfPrimaryColor,
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Details', 'Amount'],
            data: expenses.map((exp) {
              final date = _formatDate(exp['date']);
              final amt = exp['totalAmount'] ?? exp['amount'] ?? 0;
              final details =
                  'Food: ${exp['food'] ?? 0}, Fuel: ${exp['fuel'] ?? 0}, Trans: ${exp['transport'] ?? 0}';
              return [date, details, '₹ $amt'];
            }).toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              font: PdfTemplates.boldFont,
            ),
            headerDecoration: pw.BoxDecoration(color: pdfPrimaryColor),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: pw.TextStyle(font: PdfTemplates.regularFont),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
          ),
        ],
        footer: (context) => PdfTemplates.buildFooter(context),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}
