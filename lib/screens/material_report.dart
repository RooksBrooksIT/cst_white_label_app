import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_button.dart';
import '../utils/responsive.dart';

class MaterialReportPage extends StatefulWidget {
  const MaterialReportPage({super.key});

  @override
  State<MaterialReportPage> createState() => _MaterialReportPageState();
}

class _MaterialReportPageState extends State<MaterialReportPage> {
  List<String> materialNames = [];
  String? selectedMaterial;
  bool isLoadingNames = true;
  bool isReportLoading = false;
  List<_SiteMaterialRow> reportRows = [];

  @override
  void initState() {
    super.initState();
    _initAndFetch();
  }

  Future<void> _initAndFetch() async {
    await FirestoreService.initialize();
    await _fetchMaterialNames();
  }

  Future<void> _fetchMaterialNames() async {
    try {
      final snapshot = await FirestoreService.materials.get();
      final names = snapshot.docs
          .map((doc) => (doc.data()['materialName'] ?? '').toString().trim())
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList();
      names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      setState(() {
        materialNames = names;
        isLoadingNames = false;
      });
    } catch (e) {
      setState(() => isLoadingNames = false);
    }
  }

  Future<void> _fetchMaterialReport(String materialName) async {
    setState(() {
      isReportLoading = true;
      reportRows = [];
    });

    try {
      final q = await FirestoreService.getCollection('materialsInventory').where('materialName', isEqualTo: materialName).get();
      final Map<String, double> qtyBySite = {};
      for (final doc in q.docs) {
        final data = doc.data();
        final sites = data['sites'];
        if (sites is List) {
          for (final s in sites) {
            if (s is Map<String, dynamic>) {
              final siteId = (s['siteId'] ?? s['siteid'] ?? '').toString().trim();
              if (siteId.isEmpty) continue;
              final qty = _parseNumber(s['materialQty']);
              qtyBySite.update(siteId, (prev) => prev + qty, ifAbsent: () => qty);
            }
          }
        }
      }

      final rows = qtyBySite.entries.map((e) => _SiteMaterialRow(siteId: e.key, qty: e.value)).toList();
      rows.sort((a, b) => a.siteId.toLowerCase().compareTo(b.siteId.toLowerCase()));

      setState(() {
        reportRows = rows;
        isReportLoading = false;
      });
    } catch (e) {
      setState(() => isReportLoading = false);
    }
  }

  double _parseNumber(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(RegExp(r'[^0-9.+-]'), '')) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);

    return GlassScaffold(
      title: 'Material Report',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: selectedMaterial != null ? () => _fetchMaterialReport(selectedMaterial!) : null,
        ),
      ],
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSelectionCard(theme),
            const SizedBox(height: 24),
            if (selectedMaterial != null) ...[
              _buildReportHeader(theme),
              const SizedBox(height: 16),
              if (isReportLoading)
                const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
              else if (reportRows.isEmpty)
                _buildEmptyState(theme)
              else
                _buildReportTable(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionCard(ThemeData theme) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Inventory Insights', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text('Select a material to view its distribution across sites.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 20),
          if (isLoadingNames)
            const LinearProgressIndicator()
          else
            DropdownButtonFormField<String>(
              value: selectedMaterial,
              decoration: InputDecoration(
                labelText: 'Material Name',
                prefixIcon: const Icon(Icons.inventory_2_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: theme.colorScheme.surface,
              ),
              items: materialNames.map((name) => DropdownMenuItem(
                value: name,
                child: Text(name, style: TextStyle(color: theme.colorScheme.onSurface)),
              )).toList(),
              dropdownColor: theme.colorScheme.surfaceContainerHighest,
              onChanged: (val) {
                setState(() => selectedMaterial = val);
                if (val != null) _fetchMaterialReport(val);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildReportHeader(ThemeData theme) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(color: theme.primaryColor, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 12),
        Text('DISTRIBUTION REPORT', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.2, color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return GlassCard(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            children: [
              Icon(Icons.inbox_outlined, size: 48, color: theme.colorScheme.outlineVariant),
              const SizedBox(height: 16),
              const Text('No site data found for this material.', style: TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportTable(ThemeData theme) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.05), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Across active sites', style: TextStyle(fontWeight: FontWeight.w600)),
                Text('${reportRows.length} sites', style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: reportRows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final row = reportRows[i];
              return ListTile(
                title: Text(row.siteId, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                trailing: Text(row.qty.toStringAsFixed(row.qty % 1 == 0 ? 0 : 2), style: TextStyle(fontWeight: FontWeight.bold, color: theme.primaryColor, fontSize: 16)),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SiteMaterialRow {
  final String siteId;
  final double qty;
  _SiteMaterialRow({required this.siteId, required this.qty});
}
