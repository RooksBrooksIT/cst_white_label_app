import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_button.dart';
import '../utils/responsive.dart';

class ContractorReportPage extends StatefulWidget {
  const ContractorReportPage({super.key});

  @override
  _ContractorReportPageState createState() => _ContractorReportPageState();
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
    _fetchContractorNames();
  }

  Future<void> _fetchContractorNames() async {
    setState(() => isLoadingContractors = true);
    try {
      final querySnapshot = await FirebaseFirestore.instance.collection('contractors').orderBy('contractorName').get();
      final names = querySnapshot.docs
          .map((doc) => (doc.data()['contractorName'] as String?)?.trim())
          .where((name) => name != null && name.isNotEmpty)
          .map((name) => name!)
          .toSet()
          .toList();
      names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      setState(() {
        contractorNames = names;
        isLoadingContractors = false;
      });
    } catch (e) {
      setState(() => isLoadingContractors = false);
    }
  }

  Future<void> _fetchSiteIdsForContractor(String contractorName) async {
    setState(() {
      isLoadingSites = true;
      siteIdOptions = [];
      selectedSiteId = null;
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('projects')
          .where('isContractWork', isEqualTo: true)
          .where('contractorName', isEqualTo: contractorName)
          .get();
      final ids = snapshot.docs.map((doc) => doc.data()['siteId']?.toString() ?? '').where((id) => id.isNotEmpty).toList();
      setState(() {
        siteIdOptions = ids;
        if (ids.isNotEmpty) selectedSiteId = ids.first;
        isLoadingSites = false;
      });
    } catch (e) {
      setState(() => isLoadingSites = false);
    }
  }

  Future<void> _fetchExpenses() async {
    if (selectedContractor == null || selectedSiteId == null) return;
    setState(() {
      isLoadingExpenses = true;
      expenses = [];
      totalAmount = 0.0;
    });
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('contractorEntries')
          .where('contractorName', isEqualTo: selectedContractor)
          .where('siteId', isEqualTo: selectedSiteId)
          .get();
      double sum = 0.0;
      final List<Map<String, dynamic>> fetched = [];
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final amt = data['totalAmount'] ?? data['amount'] ?? 0;
        sum += (amt is num) ? amt.toDouble() : (double.tryParse(amt.toString()) ?? 0.0);
        fetched.add(data);
      }
      setState(() {
        expenses = fetched;
        totalAmount = sum;
        isLoadingExpenses = false;
      });
    } catch (e) {
      setState(() => isLoadingExpenses = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);

    return GlassScaffold(
      title: 'Contractor Report',
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFilterCard(theme),
            const SizedBox(height: 24),
            if (isLoadingExpenses)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            else if (expenses.isNotEmpty)
              _buildReportSection(theme)
            else if (selectedContractor != null && selectedSiteId != null)
              _buildEmptyState(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterCard(ThemeData theme) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Report Parameters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 20),
          _buildDropdown('Contractor Name', contractorNames, selectedContractor, (v) {
            setState(() => selectedContractor = v);
            if (v != null) _fetchSiteIdsForContractor(v);
          }, isLoadingContractors),
          const SizedBox(height: 16),
          _buildDropdown('Site ID', siteIdOptions, selectedSiteId, (v) => setState(() => selectedSiteId = v), isLoadingSites),
          const SizedBox(height: 24),
          GlassButton(
            label: 'GENERATE REPORT',
            onPressed: selectedContractor != null && selectedSiteId != null ? _fetchExpenses : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? value, Function(String?) onChanged, bool loading) {
    final theme = Theme.of(context);
    return DropdownButtonFormField<String>(
      value: (value != null && items.contains(value)) ? value : null,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: theme.cardColor,
        suffixIcon: loading ? const SizedBox(width: 12, height: 12, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))) : null,
      ),
      items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildReportSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassCard(
          color: theme.primaryColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL PAYABLE', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              Text('₹ ${totalAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('ENTRY LOG', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.2, color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: expenses.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) {
            final exp = expenses[i];
            final date = _formatDate(exp['date']);
            final amt = exp['totalAmount'] ?? exp['amount'] ?? 0;
            return GlassCard(
              onTap: () => _showEntryDetails(exp),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.receipt_outlined, color: theme.primaryColor, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(date, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Site: ${exp['siteId']}', style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Text('₹ $amt', style: TextStyle(fontWeight: FontWeight.bold, color: theme.primaryColor)),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40.0),
        child: Text('No records found for this selection.'),
      ),
    );
  }

  String _formatDate(dynamic d) {
    if (d == null) return '-';
    if (d is Timestamp) return DateFormat('dd MMM yyyy').format(d.toDate());
    if (d is String) return d;
    return '-';
  }

  void _showEntryDetails(Map<String, dynamic> exp) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GlassCard(
        borderRadius: 24,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Entry Breakdown', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              _detailRow('Date', _formatDate(exp['date'])),
              _detailRow('Food', '₹ ${exp['food'] ?? 0}'),
              _detailRow('Fuel', '₹ ${exp['fuel'] ?? 0}'),
              _detailRow('Transport', '₹ ${exp['transport'] ?? 0}'),
              const Divider(height: 32),
              _detailRow('Total Amount', '₹ ${exp['totalAmount'] ?? exp['amount'] ?? 0}', isBold: true),
              const SizedBox(height: 24),
              GlassButton(label: 'CLOSE', onPressed: () => Navigator.pop(context), isSecondary: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}