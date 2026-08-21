import 'package:flutter/material.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/screens/manager/tools_inventory_details.dart';
import 'package:demo_cst/services/firestore_service.dart';

class ToolsInventoryPage extends StatefulWidget {
  const ToolsInventoryPage({super.key});

  @override
  State<ToolsInventoryPage> createState() => _ToolsInventoryPageState();
}

class _ToolsInventoryPageState extends State<ToolsInventoryPage> {
  DataState _dataState = DataState.loading;
  List<ToolInventory> _toolsAtCompany = [];
  List<ToolInventory> _toolsAtSite = [];
  List<Map<String, dynamic>> _masterTools = [];
  String? _errorMessage;
  String _searchQuery = '';
  String _selectedFilter = 'All'; // 'All', 'At Company', 'At Sites'

  final TextEditingController _searchController = TextEditingController();

  Color get primaryColor => Theme.of(context).primaryColor;

  @override
  void initState() {
    super.initState();
    _loadInventoryData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInventoryData() async {
    setState(() => _dataState = DataState.loading);
    try {
      final results = await Future.wait([
        FirestoreService.getCollection('toolsAtCompany').get(),
        FirestoreService.getCollection('toolsAtSite').get(),
        FirestoreService.getCollection('tools').get(),
      ]);

      final companyData = results[0].docs
          .map((doc) => ToolInventory.fromMap(doc.data()))
          .toList();
      final siteData = results[1].docs
          .map((doc) => ToolInventory.fromMap(doc.data()))
          .toList();
      final masterData = results[2].docs.map((doc) {
        final d = doc.data();
        return {
          'toolId': d['toolId'] ?? '',
          'toolName': d['toolName'] ?? '',
          'toolCode': d['toolCode'] ?? '',
          'toolOwner': d['toolOwner'] ?? 'Org',
          'description': d['description'] ?? '',
        };
      }).toList();

      if (mounted) {
        setState(() {
          _toolsAtCompany = companyData;
          _toolsAtSite = siteData;
          _masterTools = masterData;
          _dataState = DataState.loaded;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _dataState = DataState.error;
          _errorMessage = 'Failed to load inventory: ${e.toString()}';
        });
      }
    }
  }

  List<ToolInventorySummary> get _mergedInventory {
    final Map<String, ToolInventorySummary> summaryMap = {};

    // First populate from master tools
    for (var m in _masterTools) {
      final code = m['toolCode'] as String? ?? '';
      if (code.isNotEmpty) {
        summaryMap[code] = ToolInventorySummary(
          toolCode: code,
          toolName: m['toolName'] as String? ?? '',
          toolOwner: m['toolOwner'] as String? ?? 'Org',
          description: m['description'] as String? ?? '',
          atCompany: 0,
          atSite: 0,
        );
      }
    }

    // Add / update from toolsAtCompany
    for (var c in _toolsAtCompany) {
      if (c.toolCode.isNotEmpty) {
        final existing = summaryMap[c.toolCode];
        summaryMap[c.toolCode] = ToolInventorySummary(
          toolCode: c.toolCode,
          toolName: existing?.toolName ?? '',
          toolOwner: existing?.toolOwner ?? 'Org',
          description: existing?.description ?? '',
          atCompany: c.availableCount,
          atSite: existing?.atSite ?? 0,
        );
      }
    }

    // Add / update from toolsAtSite
    for (var s in _toolsAtSite) {
      if (s.toolCode.isNotEmpty) {
        final existing = summaryMap[s.toolCode];
        summaryMap[s.toolCode] = ToolInventorySummary(
          toolCode: s.toolCode,
          toolName: existing?.toolName ?? '',
          toolOwner: existing?.toolOwner ?? 'Org',
          description: existing?.description ?? '',
          atCompany: existing?.atCompany ?? 0,
          atSite: s.availableCount,
        );
      }
    }

    return summaryMap.values.toList();
  }

  List<ToolInventorySummary> get _filteredInventory {
    return _mergedInventory.where((tool) {
      final query = _searchQuery.toLowerCase().trim();
      final matchesQuery = query.isEmpty ||
          tool.toolCode.toLowerCase().contains(query) ||
          tool.toolName.toLowerCase().contains(query) ||
          tool.toolOwner.toLowerCase().contains(query);

      bool matchesFilter = true;
      if (_selectedFilter == 'At Company') {
        matchesFilter = tool.atCompany > 0;
      } else if (_selectedFilter == 'At Sites') {
        matchesFilter = tool.atSite > 0;
      }

      return matchesQuery && matchesFilter;
    }).toList();
  }

  void _navigateToToolDetails(ToolInventorySummary tool) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ToolsInventoryDetailsPage(toolCode: tool.toolCode),
      ),
    ).then((_) => _loadInventoryData());
  }

  @override
  Widget build(BuildContext context) {
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Tools Inventory Overview',
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
            tooltip: 'Refresh Inventory',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
            onPressed: _loadInventoryData,
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isMobile ? double.infinity : 700,
            ),
            child: _buildBody(darkAccent),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(Color darkAccent) {
    switch (_dataState) {
      case DataState.loading:
        return const Center(child: CircularProgressIndicator());
      case DataState.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'Failed to load tools inventory',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _loadInventoryData,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('RETRY'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        );
      case DataState.loaded:
        return _buildInventoryList(darkAccent);
    }
  }

  Widget _buildInventoryList(Color darkAccent) {
    final totalAtCompany = _toolsAtCompany.fold<int>(
      0,
      (acc, tool) => acc + tool.availableCount,
    );
    final totalAtSite = _toolsAtSite.fold<int>(
      0,
      (acc, tool) => acc + tool.availableCount,
    );
    final totalTools = totalAtCompany + totalAtSite;
    final filtered = _filteredInventory;

    return RefreshIndicator(
      onRefresh: _loadInventoryData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── KPI Summary Cards ───────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Total Stock',
                    value: '$totalTools',
                    subtitle: 'Units in org',
                    icon: Icons.inventory_2_rounded,
                    accentColor: primaryColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    title: 'At Company',
                    value: '$totalAtCompany',
                    subtitle: 'Storage stock',
                    icon: Icons.warehouse_rounded,
                    accentColor: const Color(0xFF0EA5E9),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    title: 'At Sites',
                    value: '$totalAtSite',
                    subtitle: 'Deployed units',
                    icon: Icons.location_city_rounded,
                    accentColor: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Search & Filter Box ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
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
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Search tool name, code, owner...',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                      prefixIcon: Icon(Icons.search_rounded, color: primaryColor, size: 22),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryColor, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text(
                        'Filter:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip('All'),
                      const SizedBox(width: 6),
                      _buildFilterChip('At Company'),
                      const SizedBox(width: 6),
                      _buildFilterChip('At Sites'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Tools Inventory Cards List ──────────────────────────────────
            if (filtered.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
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
                        Icons.search_off_rounded,
                        size: 40,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _searchQuery.isEmpty ? 'No Tools in Inventory' : 'No Matching Tools Found',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: darkAccent,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _searchQuery.isEmpty
                          ? 'Register tools in Tools Master to see inventory distribution.'
                          : 'Try searching with a different name or clearing filter.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  final total = item.atCompany + item.atSite;
                  final companyRatio = total > 0 ? (item.atCompany / total) : 0.0;
                  final isRental = item.toolOwner.toLowerCase() == 'rental';

                  return Container(
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
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _navigateToToolDetails(item),
                        borderRadius: BorderRadius.circular(18),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Row: Avatar + Title + Total Badge
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: isRental
                                          ? Colors.amber.shade50
                                          : primaryColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isRental
                                            ? Colors.amber.shade300
                                            : primaryColor.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.handyman_rounded,
                                      color: isRental ? Colors.amber.shade800 : primaryColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isRental
                                                    ? Colors.amber.withValues(alpha: 0.15)
                                                    : const Color(0xFF10B981).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                isRental ? 'RENTAL' : 'ORG OWNED',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  color: isRental
                                                      ? Colors.amber.shade900
                                                      : const Color(0xFF047857),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          item.toolName.isNotEmpty ? item.toolName : item.toolCode,
                                          style: TextStyle(
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w800,
                                            color: darkAccent,
                                          ),
                                        ),
                                        Text(
                                          item.toolCode,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'monospace',
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          '$total',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: darkAccent,
                                          ),
                                        ),
                                        const Text(
                                          'TOTAL',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Progress bar representing Company vs Site allocation
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: SizedBox(
                                  height: 6,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: (companyRatio * 100).round().clamp(0, 100),
                                        child: Container(color: const Color(0xFF0EA5E9)),
                                      ),
                                      Expanded(
                                        flex: ((1.0 - companyRatio) * 100).round().clamp(0, 100),
                                        child: Container(color: const Color(0xFF10B981)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Breakdown Badges Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      _buildDistributionBadge(
                                        label: 'Company',
                                        count: item.atCompany,
                                        color: const Color(0xFF0EA5E9),
                                      ),
                                      const SizedBox(width: 8),
                                      _buildDistributionBadge(
                                        label: 'Sites',
                                        count: item.atSite,
                                        color: const Color(0xFF10B981),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        'View Sites',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: primaryColor,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Icon(Icons.chevron_right_rounded, size: 18, color: primaryColor),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: accentColor, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionBadge({
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            '$label: ',
            style: TextStyle(
              color: const Color(0xFF475569),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              color: const Color(0xFF0F172A),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// MODELS & ENUMS
// -----------------------------------------------------------------------------

enum DataState { loading, loaded, error }

class ToolInventory {
  final String toolCode;
  final int availableCount;

  const ToolInventory({required this.toolCode, required this.availableCount});

  factory ToolInventory.fromMap(Map<String, dynamic> map) {
    return ToolInventory(
      toolCode: map['toolCode']?.toString() ?? '',
      availableCount: (map['availableCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class ToolInventorySummary {
  final String toolCode;
  final String toolName;
  final String toolOwner;
  final String description;
  final int atCompany;
  final int atSite;

  const ToolInventorySummary({
    required this.toolCode,
    required this.toolName,
    required this.toolOwner,
    required this.description,
    required this.atCompany,
    required this.atSite,
  });
}
