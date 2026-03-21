import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'tools_inventory_details.dart';

class ToolsInventoryPage extends StatefulWidget {
  const ToolsInventoryPage({super.key});

  @override
  State<ToolsInventoryPage> createState() => _ToolsInventoryPageState();
}

class _ToolsInventoryPageState extends State<ToolsInventoryPage> {
  // Updated Colors
  static const _primaryColor = Color(0xFF0b3470); // Your main professional blue
  static const _secondaryColor = Color(0xFFF9FAFB); // Light background for neat UI
  static const _cardColor = Colors.white;
  static const _highlightColor = Color(0xFFE8F4F8);

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
        FirebaseFirestore.instance.collection('toolsAtCompany').get(),
        FirebaseFirestore.instance.collection('toolsAtSite').get(),
        FirebaseFirestore.instance.collection('tools').get(),
      ]);

      final companyData = results[0].docs
          .map((doc) => ToolInventory.fromMap(doc.data()))
          .toList();
      final siteData =
          results[1].docs.map((doc) => ToolInventory.fromMap(doc.data())).toList();
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
          .firstWhere((e) => e.toolCode == code, orElse: () => ToolInventory.empty())
          .availableCount;
      final siteCount = _toolsAtSite
          .firstWhere((e) => e.toolCode == code, orElse: () => ToolInventory.empty())
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
        .where((tool) =>
            tool.toolCode.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  void _navigateToToolDetails(ToolInventorySummary tool) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ToolsInventoryDetailsPage(toolCode: tool.toolCode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _secondaryColor,
      appBar: AppBar(
        title: const Text(
          'Tools Inventory',
          style: TextStyle( fontWeight: FontWeight.bold),
        ),
        backgroundColor: _primaryColor,
        elevation: 2,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInventoryData,
            tooltip: 'Refresh',
            
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_dataState) {
      case DataState.loading:
        return const Center(child: CircularProgressIndicator());
      case DataState.error:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(_errorMessage ?? 'Unknown error',
                  style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadInventoryData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      case DataState.loaded:
        return _buildInventoryList();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildInventoryList() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCards(),
          const SizedBox(height: 16),
          _buildSearchBar(),
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
                        onTap: () => _navigateToToolDetails(tool),
                        isHighlighted: tool.toolCode
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase()),
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
          const Icon(Icons.search_off, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'No tools found for "$_searchQuery"',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              setState(() {
                _searchQuery = '';
              });
            },
            style: TextButton.styleFrom(
              foregroundColor: _primaryColor,
            ),
            child: const Text('Clear search'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final totalAtCompany =
        _toolsAtCompany.fold(0, (sum, tool) => sum + tool.availableCount);
    final totalAtSite =
        _toolsAtSite.fold(0, (sum, tool) => sum + tool.availableCount);
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
                      primaryColor: _primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'At Company',
                      value: totalAtCompany,
                      icon: Icons.business,
                      primaryColor: _primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'At Site',
                      value: totalAtSite,
                      icon: Icons.location_city,
                      primaryColor: _primaryColor,
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
                          primaryColor: _primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          title: 'At Company',
                          value: totalAtCompany,
                          icon: Icons.business,
                          primaryColor: _primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SummaryCard(
                    title: 'At Site',
                    value: totalAtSite,
                    icon: Icons.location_city,
                    primaryColor: _primaryColor,
                    fullWidth: true,
                  ),
                ],
              );
      },
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.12),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search tools...',
          prefixIcon: Icon(Icons.search, color: _primaryColor),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  color: _primaryColor,
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
        ),
        cursorColor: _primaryColor,
        style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w600),
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
  final Color primaryColor;
  final bool fullWidth;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.primaryColor,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
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
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: primaryColor.withOpacity(0.75),
                  letterSpacing: 1.2,
                ),
              ),
              Icon(icon, color: primaryColor.withOpacity(0.7)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: primaryColor,
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
  final bool isHighlighted;

  const _ToolInventoryCard({
    required this.tool,
    required this.onTap,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      color: isHighlighted ? const Color(0xFFE8F4F8) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: Colors.blue.withOpacity(0.15),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    tool.toolCode,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _InventoryBadge(
                    label: 'Company',
                    count: tool.atCompany,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 12),
                  _InventoryBadge(
                    label: 'Site',
                    count: tool.atSite,
                    color: Colors.green.shade700,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: onTap,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF0b3470),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600),
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

  const ToolInventory({
    required this.toolCode,
    required this.availableCount,
  });

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
