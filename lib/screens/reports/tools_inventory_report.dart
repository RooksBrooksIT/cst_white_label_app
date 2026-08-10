import 'package:flutter/material.dart';
import 'package:demo_cst/utils/responsive.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/screens/manager/tools_inventory_details.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';
import 'package:demo_cst/widgets/glass_card.dart';
import 'package:demo_cst/widgets/glass_button.dart';

class ToolsInventoryPage extends StatefulWidget {
  const ToolsInventoryPage({super.key});

  @override
  State<ToolsInventoryPage> createState() => _ToolsInventoryPageState();
}

class _ToolsInventoryPageState extends State<ToolsInventoryPage> {
  // Data state
  DataState _dataState = DataState.loading;
  List<ToolInventory> _toolsAtCompany = [];
  List<ToolInventory> _toolsAtSite = [];
  List<String> _allToolCodes = [];
  String? _errorMessage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadInventoryData();
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
      final toolCodes = results[2].docs
          .map((doc) => doc.data()['toolCode']?.toString() ?? '')
          .where((code) => code.isNotEmpty)
          .toList();

      setState(() {
        _toolsAtCompany = companyData;
        _toolsAtSite = siteData;
        _allToolCodes = toolCodes;
        _dataState = DataState.loaded;
      });
    } catch (e) {
      setState(() {
        _dataState = DataState.error;
        _errorMessage = 'Failed to load inventory: ${e.toString()}';
      });
    }
  }

  List<ToolInventorySummary> get _mergedInventory {
    final allToolCodes = {
      ..._toolsAtCompany.map((e) => e.toolCode),
      ..._toolsAtSite.map((e) => e.toolCode),
      ..._allToolCodes,
    };

    return allToolCodes.map((code) {
      final companyCount = _toolsAtCompany
          .firstWhere(
            (e) => e.toolCode == code,
            orElse: () => ToolInventory.empty(),
          )
          .availableCount;
      final siteCount = _toolsAtSite
          .firstWhere(
            (e) => e.toolCode == code,
            orElse: () => ToolInventory.empty(),
          )
          .availableCount;

      return ToolInventorySummary(
        toolCode: code,
        atCompany: companyCount,
        atSite: siteCount,
      );
    }).toList();
  }

  List<ToolInventorySummary> get _filteredInventory {
    if (_searchQuery.isEmpty) return _mergedInventory;

    return _mergedInventory
        .where(
          (tool) =>
              tool.toolCode.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  void _navigateToToolDetails(ToolInventorySummary tool) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ToolsInventoryDetailsPage(toolCode: tool.toolCode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.primaryColor,
      builder: (context, primaryColor, _) {
        final cardAccent = AppTheme.getCardAccent(primaryColor);

        return GlassScaffold(
          title: 'Tools Inventory',
          appBarForegroundColor: Colors.white,
          onBack: () => Navigator.pop(context),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _loadInventoryData,
              tooltip: 'Refresh',
            ),
          ],
          body: SafeArea(
            bottom: true,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isMobile ? double.infinity : 600,
                ),
                child: _buildBody(cardAccent),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(Color cardAccent) {
    switch (_dataState) {
      case DataState.loading:
        return const Center(child: CircularProgressIndicator());
      case DataState.error:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'Unknown error',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
              GlassButton(label: 'RETRY', onPressed: _loadInventoryData),
            ],
          ),
        );
      case DataState.loaded:
        return _buildInventoryList(cardAccent);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildInventoryList(Color cardAccent) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCards(cardAccent),
          const SizedBox(height: 16),
          _buildSearchBar(cardAccent),
          const SizedBox(height: 16),
          Expanded(
            child: _filteredInventory.isEmpty && _searchQuery.isNotEmpty
                ? _buildNoResults()
                : ListView.builder(
                    itemCount: _filteredInventory.length,
                    itemBuilder: (context, index) {
                      final tool = _filteredInventory[index];
                      return _ToolInventoryCard(
                        tool: tool,
                        cardAccent: cardAccent,
                        onTap: () => _navigateToToolDetails(tool),
                        isHighlighted: tool.toolCode.toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 48, color: Colors.white70),
          const SizedBox(height: 16),
          Text(
            'No tools found for "$_searchQuery"',
            style: const TextStyle(fontSize: 16, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          TextButton(
            child: const Text('Clear search'),
            onPressed: () {
              setState(() {
                _searchQuery = '';
              });
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(Color cardAccent) {
    final totalAtCompany = _toolsAtCompany.fold(
      0,
      (sum, tool) => sum + tool.availableCount,
    );
    final totalAtSite = _toolsAtSite.fold(
      0,
      (sum, tool) => sum + tool.availableCount,
    );
    final totalTools = totalAtCompany + totalAtSite;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;

        return isWide
            ? Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: 'Total Tools',
                      value: totalTools,
                      icon: Icons.construction,
                      cardAccent: cardAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'At Company',
                      value: totalAtCompany,
                      icon: Icons.business,
                      cardAccent: cardAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'At Site',
                      value: totalAtSite,
                      icon: Icons.location_city,
                      cardAccent: cardAccent,
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          title: 'Total Tools',
                          value: totalTools,
                          icon: Icons.construction,
                          cardAccent: cardAccent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          title: 'At Company',
                          value: totalAtCompany,
                          icon: Icons.business,
                          cardAccent: cardAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SummaryCard(
                    title: 'At Site',
                    value: totalAtSite,
                    icon: Icons.location_city,
                    cardAccent: cardAccent,
                    fullWidth: true,
                  ),
                ],
              );
      },
    );
  }

  Widget _buildSearchBar(Color cardAccent) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardAccent.withValues(alpha: 0.3)),
      ),
      child: TextField(
        cursorColor: cardAccent,
        style: const TextStyle(
          color: Color(0xFF0A183D),
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: 'Search tools...',
          hintStyle: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(Icons.search, color: cardAccent),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  color: cardAccent,
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color cardAccent;
  final bool fullWidth;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.cardAccent,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1942).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: cardAccent,
                    letterSpacing: 1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, color: cardAccent, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value.toString(),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolInventoryCard extends StatelessWidget {
  final ToolInventorySummary tool;
  final VoidCallback onTap;
  final Color cardAccent;
  final bool isHighlighted;

  const _ToolInventoryCard({
    required this.tool,
    required this.onTap,
    required this.cardAccent,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: cardAccent.withValues(alpha: 0.15),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      tool.toolCode,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.chevron_right, color: cardAccent),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _InventoryBadge(
                    label: 'Company',
                    count: tool.atCompany,
                    color: const Color(0xFF60A5FA),
                  ),
                  _InventoryBadge(
                    label: 'Site',
                    count: tool.atSite,
                    color: const Color(0xFF34D399),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: onTap,
                    style: TextButton.styleFrom(
                      foregroundColor: cardAccent,
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('View Details'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InventoryBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _InventoryBadge({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// Enums and Models (unchanged)
enum DataState { loading, loaded, error }

class ToolInventory {
  final String toolCode;
  final int availableCount;

  const ToolInventory({required this.toolCode, required this.availableCount});

  factory ToolInventory.fromMap(Map<String, dynamic> map) {
    return ToolInventory(
      toolCode: map['toolCode']?.toString() ?? '',
      availableCount: map['availableCount'] as int? ?? 0,
    );
  }

  factory ToolInventory.empty() =>
      const ToolInventory(toolCode: '', availableCount: 0);
}

class ToolInventorySummary {
  final String toolCode;
  final int atCompany;
  final int atSite;

  const ToolInventorySummary({
    required this.toolCode,
    required this.atCompany,
    required this.atSite,
  });

  factory ToolInventorySummary.empty() =>
      const ToolInventorySummary(toolCode: 'N/A', atCompany: 0, atSite: 0);
}
