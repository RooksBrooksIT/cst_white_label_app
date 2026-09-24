import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ebricks/services/firestore_service.dart';
import 'package:ebricks/services/material_inventory_service.dart';
import 'package:ebricks/services/auth_service.dart';
import 'package:ebricks/utils/app_theme.dart';
import 'package:intl/intl.dart';

class MaterialAvailability extends StatefulWidget {
  const MaterialAvailability({super.key});

  @override
  State<MaterialAvailability> createState() => _MaterialAvailabilityState();
}

class _MaterialAvailabilityState extends State<MaterialAvailability> {
  // Tabs: 0 = Company Stock (Add/Update), 1 = Allocate to Site, 2 = Site Material Pool
  int _selectedTabIndex = 0;
  bool _isLoading = false;
  bool _isLoadingInitial = true;

  // Sites state
  List<Map<String, dynamic>> _sites = [];
  String? _selectedSiteId;
  String? _selectedSiteName;
  String? _selectedProjectName;

  // Materials master catalog state
  List<Map<String, dynamic>> _masterMaterials = [];
  String? _selectedMaterialName;
  String _selectedCategory = '';
  String _selectedSubCategory = '';
  String _selectedUnit = 'Units';
  double _masterPrice = 0.0;
  List<String> _availableUnits = [];

  // Form controllers for Allocation
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _unitRateController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  DateTime _allocationDate = DateTime.now();

  // Company Stock Tab State
  Map<String, int> _companyStockMap = {};
  bool _isLoadingStock = false;
  final TextEditingController _stockSearchController = TextEditingController();
  String _stockSearchQuery = '';
  StreamSubscription? _stockSubscription;

  // Site Pool / Overview Tab State
  String? _filterSiteId;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<SiteMaterialPoolItem> _sitePoolItems = [];
  bool _isLoadingPool = false;
  StreamSubscription? _poolSubscription;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _poolSubscription?.cancel();
    _stockSubscription?.cancel();
    _quantityController.dispose();
    _unitRateController.dispose();
    _amountController.dispose();
    _remarksController.dispose();
    _searchController.dispose();
    _stockSearchController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoadingInitial = true);
    try {
      if (!FirestoreService.isReady) {
        await FirestoreService.initialize();
      }

      await Future.wait([
        _loadSites(),
        _loadMaterials(),
        _loadUnits(),
      ]);

      await Future.wait([
        _loadCompanyStockData(),
        _loadSitePoolData(),
      ]);

      _initRealtimeStreams();
    } catch (e) {
      debugPrint('Error initializing Material Availability: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingInitial = false);
      }
    }
  }

  void _initRealtimeStreams() {
    _poolSubscription = FirestoreService.siteMaterialPool.snapshots().listen((_) {
      if (mounted) {
        _loadSitePoolData(isSilent: true);
      }
    });

    _stockSubscription = FirestoreService.getCollection('materialsAvailability').snapshots().listen((_) {
      if (mounted) {
        _loadCompanyStockData(isSilent: true);
      }
    });
  }

  Future<void> _loadSites() async {
    try {
      final results = await Future.wait([
        FirestoreService.getCollection('Site').get(),
        FirestoreService.projects.get(),
      ]);

      final siteDocs = results[0].docs;
      final projDocs = results[1].docs;

      final Map<String, Map<String, dynamic>> map = {};

      for (var d in siteDocs) {
        final data = d.data();
        final sId = (data['siteId'] ?? d.id).toString().trim();
        final sName = (data['siteName'] ?? data['name'] ?? sId).toString().trim();
        final pName = (data['projectName'] ?? '').toString().trim();
        if (sId.isNotEmpty) {
          map[sId.toLowerCase()] = {
            'siteId': sId,
            'siteName': sName,
            'projectName': pName,
          };
        }
      }

      for (var d in projDocs) {
        final data = d.data();
        final sId = (data['siteId'] ?? d.id).toString().trim();
        final sName = (data['siteName'] ?? data['projectName'] ?? sId).toString().trim();
        final pName = (data['projectName'] ?? '').toString().trim();
        if (sId.isNotEmpty) {
          if (!map.containsKey(sId.toLowerCase())) {
            map[sId.toLowerCase()] = {
              'siteId': sId,
              'siteName': sName,
              'projectName': pName,
            };
          } else if (pName.isNotEmpty && (map[sId.toLowerCase()]!['projectName'] as String).isEmpty) {
            map[sId.toLowerCase()]!['projectName'] = pName;
          }
        }
      }

      final list = map.values.toList();
      list.sort((a, b) => (a['siteName'] as String).toLowerCase().compareTo((b['siteName'] as String).toLowerCase()));

      if (mounted) {
        setState(() {
          _sites = list;
          if (_sites.isNotEmpty && _selectedSiteId == null) {
            _selectedSiteId = _sites.first['siteId'];
            _selectedSiteName = _sites.first['siteName'];
            _selectedProjectName = _sites.first['projectName'];
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading sites: $e');
    }
  }

  Future<void> _loadMaterials() async {
    try {
      final querySnapshot = await FirestoreService.getCollection('materials').get();
      final List<Map<String, dynamic>> mats = [];

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final name = (data['materialName'] ?? data['matName'] ?? '').toString().trim();
        if (name.isEmpty) continue;

        mats.add({
          'docId': doc.id,
          'materialName': name,
          'category': (data['category'] ?? data['materialCategory'] ?? 'General Material').toString().trim(),
          'subCategory': (data['subCategory'] ?? data['materialSubCategory'] ?? '').toString().trim(),
          'unit': (data['unit'] ?? data['materialUnit'] ?? 'Units').toString().trim(),
          'unitPrice': (data['unitPrice'] as num?)?.toDouble() ??
              double.tryParse((data['materialPrice'] ?? '0').toString()) ??
              0.0,
        });
      }

      mats.sort((a, b) => (a['materialName'] as String).toLowerCase().compareTo((b['materialName'] as String).toLowerCase()));

      if (mounted) {
        setState(() {
          _masterMaterials = mats;
        });
      }
    } catch (e) {
      debugPrint('Error loading materials master: $e');
    }
  }

  Future<void> _loadUnits() async {
    try {
      final snap = await FirestoreService.getCollection('materialUnits').get();
      final units = snap.docs.map((d) => (d.data()['matUnit'] ?? d.id).toString().trim()).where((u) => u.isNotEmpty).toSet().toList();

      if (!units.contains('Bags')) units.add('Bags');
      if (!units.contains('KG')) units.add('KG');
      if (!units.contains('Ton')) units.add('Ton');
      if (!units.contains('Nos')) units.add('Nos');
      if (!units.contains('Sq.ft')) units.add('Sq.ft');
      if (!units.contains('Litre')) units.add('Litre');
      if (!units.contains('Meter')) units.add('Meter');
      if (!units.contains('Box')) units.add('Box');

      units.sort();
      if (mounted) {
        setState(() {
          _availableUnits = units;
        });
      }
    } catch (e) {
      debugPrint('Error loading units: $e');
    }
  }

  Future<void> _loadCompanyStockData({bool isSilent = false}) async {
    if (!isSilent) {
      setState(() => _isLoadingStock = true);
    }
    try {
      final results = await Future.wait([
        FirestoreService.getCollection('materialsAvailability').get(),
        FirestoreService.getCollection('materialTransfer').get(),
        FirestoreService.getCollection('materials').get(),
      ]);

      final availDocs = results[0].docs;
      final transferDocs = results[1].docs;
      final masterDocs = results[2].docs;

      final Map<String, int> stockMap = {};

      // 1. From master materials
      for (var d in masterDocs) {
        final data = d.data();
        final name = (data['materialName'] ?? data['matName'] ?? '').toString().trim().toLowerCase();
        if (name.isEmpty) continue;
        final c = (data['availableCount'] as num?)?.toInt() ??
            (data['count'] as num?)?.toInt() ??
            (data['companyAvailableCount'] as num?)?.toInt() ??
            0;
        stockMap[name] = c;
      }

      // 2. From materialTransfer docs
      for (var d in transferDocs) {
        final data = d.data();
        final name = (data['materialName'] ?? data['displayName'] ?? '').toString().trim().toLowerCase();
        if (name.isEmpty) continue;
        if (data.containsKey('companyAvailableCount') || data.containsKey('count')) {
          stockMap[name] = (data['companyAvailableCount'] as num?)?.toInt() ??
              (data['count'] as num?)?.toInt() ??
              0;
        }
      }

      // 3. From canonical materialsAvailability docs
      for (var d in availDocs) {
        final data = d.data();
        final name = (data['materialName'] ?? data['displayName'] ?? '').toString().trim().toLowerCase();
        if (name.isEmpty) continue;
        if (data.containsKey('companyAvailableCount') || data.containsKey('count') || data.containsKey('availableCount')) {
          stockMap[name] = (data['companyAvailableCount'] as num?)?.toInt() ??
              (data['count'] as num?)?.toInt() ??
              (data['availableCount'] as num?)?.toInt() ??
              0;
        }
      }

      if (mounted) {
        setState(() {
          _companyStockMap = stockMap;
          _isLoadingStock = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading company stock data: $e');
      if (mounted) {
        setState(() => _isLoadingStock = false);
      }
    }
  }

  Future<void> _loadSitePoolData({bool isSilent = false}) async {
    if (!isSilent) {
      setState(() => _isLoadingPool = true);
    }
    try {
      final List<SiteMaterialPoolItem> allItems = [];

      if (_filterSiteId != null && _filterSiteId!.isNotEmpty) {
        final siteItems = await MaterialInventoryService.fetchSiteMaterialPool(_filterSiteId!);
        allItems.addAll(siteItems);
      } else {
        final snap = await FirestoreService.siteMaterialPool.get();
        for (var doc in snap.docs) {
          allItems.add(SiteMaterialPoolItem.fromMap(doc.id, doc.data()));
        }

        if (allItems.isEmpty && _sites.isNotEmpty) {
          for (var s in _sites) {
            final sId = s['siteId'] as String;
            final sItems = await MaterialInventoryService.fetchSiteMaterialPool(sId);
            allItems.addAll(sItems);
          }
        }
      }

      allItems.sort((a, b) => a.materialName.toLowerCase().compareTo(b.materialName.toLowerCase()));

      if (mounted) {
        setState(() {
          _sitePoolItems = allItems;
          _isLoadingPool = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading site pool data: $e');
      if (mounted) {
        setState(() => _isLoadingPool = false);
      }
    }
  }

  int _getCompanyStockForMaterial(String materialName) {
    return _companyStockMap[materialName.trim().toLowerCase()] ?? 0;
  }

  void _onMaterialSelected(String? materialName) {
    if (materialName == null) return;
    final match = _masterMaterials.firstWhere(
      (m) => m['materialName'] == materialName,
      orElse: () => {},
    );

    setState(() {
      _selectedMaterialName = materialName;
      _selectedCategory = (match['category'] ?? 'General Material').toString();
      _selectedSubCategory = (match['subCategory'] ?? '').toString();
      _selectedUnit = (match['unit'] ?? 'Units').toString();
      _masterPrice = (match['unitPrice'] as num?)?.toDouble() ?? 0.0;
      if (_masterPrice > 0) {
        _unitRateController.text = _masterPrice.truncateToDouble() == _masterPrice
            ? _masterPrice.toInt().toString()
            : _masterPrice.toStringAsFixed(2);
      } else {
        _unitRateController.clear();
      }
      _recalculateAmount();
    });
  }

  void _recalculateAmount() {
    final qty = double.tryParse(_quantityController.text) ?? 0.0;
    final rate = double.tryParse(_unitRateController.text) ?? _masterPrice;
    if (qty > 0 && rate > 0) {
      final total = qty * rate;
      _amountController.text = total.truncateToDouble() == total
          ? total.toInt().toString()
          : total.toStringAsFixed(2);
    } else if (qty <= 0) {
      _amountController.clear();
    }
  }

  void _onQuantityChanged(String v) {
    _recalculateAmount();
    setState(() {});
  }

  void _onUnitRateChanged(String v) {
    _recalculateAmount();
    setState(() {});
  }

  Future<void> _pickAllocationDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _allocationDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              onSurface: const Color(0xFF0A183D),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _allocationDate = picked);
    }
  }

  double get _currentEffectiveRate {
    final rate = double.tryParse(_unitRateController.text);
    if (rate != null && rate > 0) return rate;
    if (_masterPrice > 0) return _masterPrice;
    final qty = double.tryParse(_quantityController.text) ?? 0.0;
    final amt = double.tryParse(_amountController.text) ?? 0.0;
    if (qty > 0 && amt > 0) {
      return amt / qty;
    }
    return 0.0;
  }

  Future<void> _submitAllocation() async {
    if (_selectedSiteId == null || _selectedSiteId!.isEmpty) {
      _showErrorDialog('Please select a site to allocate materials to.');
      return;
    }

    if (_selectedMaterialName == null || _selectedMaterialName!.isEmpty) {
      _showErrorDialog('Please select a material.');
      return;
    }

    final qty = double.tryParse(_quantityController.text) ?? 0.0;
    if (qty <= 0) {
      _showErrorDialog('Please enter a valid quantity greater than 0.');
      return;
    }

    final amt = double.tryParse(_amountController.text) ?? 0.0;
    if (amt <= 0) {
      _showErrorDialog('Please enter a valid allocated amount (₹) greater than 0.');
      return;
    }

    final currentAvailableStock = _getCompanyStockForMaterial(_selectedMaterialName!);
    if (qty > currentAvailableStock && currentAvailableStock > 0) {
      final shouldProceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 24),
              SizedBox(width: 8),
              Text('Stock Warning', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
          content: Text(
            'The allocation quantity ($qty $_selectedUnit) exceeds the available company warehouse stock ($currentAvailableStock $_selectedUnit).\n\nCompany stock will be depleted to 0. Do you want to proceed?',
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155), height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Proceed', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
      if (shouldProceed != true) return;
    }

    if (!mounted) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final formattedDate = DateFormat('yyyy-MM-dd').format(_allocationDate);
      final siteMatch = _sites.firstWhere(
        (s) => s['siteId'] == _selectedSiteId,
        orElse: () => {'siteName': _selectedSiteId, 'projectName': ''},
      );

      final rateVal = _currentEffectiveRate;
      final authUser = AuthService().userData;
      final activeManagerName = (authUser['FullName'] ??
              authUser['fullName'] ??
              authUser['Name'] ??
              authUser['name'] ??
              authUser['managerName'] ??
              authUser['username'] ??
              authUser['userName'] ??
              'Manager')
          .toString()
          .trim();

      final allocation = await MaterialInventoryService.allocateMaterialToSite(
        siteId: _selectedSiteId!,
        siteName: siteMatch['siteName'],
        projectName: siteMatch['projectName'] ?? _selectedProjectName,
        materialName: _selectedMaterialName!,
        category: _selectedCategory,
        subCategory: _selectedSubCategory,
        quantity: qty,
        unit: _selectedUnit,
        unitRate: rateVal,
        allocatedAmount: amt,
        allocationDate: formattedDate,
        remarks: _remarksController.text.trim(),
        managerName: activeManagerName.isNotEmpty ? activeManagerName : 'Manager',
      );

      final rateStr = allocation.unitRate.truncateToDouble() == allocation.unitRate
          ? allocation.unitRate.toInt().toString()
          : allocation.unitRate.toStringAsFixed(2);
      final qtyStr = qty.truncateToDouble() == qty ? qty.toInt().toString() : qty.toStringAsFixed(2);
      final newRemainingCompanyStock = (currentAvailableStock - qty.toInt()).clamp(0, 999999999);

      _showSuccessDialog(
        'Material Allocated Successfully!\n\n'
        '• Site: ${_selectedSiteName ?? _selectedSiteId}\n'
        '• Material: $_selectedMaterialName\n'
        '• Allocated Quantity: $qtyStr $_selectedUnit\n'
        '• Fixed Rate: ₹$rateStr / $_selectedUnit\n'
        '• Total Amount: ₹${amt.toStringAsFixed(0)}\n'
        '• Deducted from Company Stock: -$qtyStr $_selectedUnit\n'
        '• Remaining Company Warehouse Stock: $newRemainingCompanyStock $_selectedUnit\n'
        '• Notification: Automatically sent to the assigned Supervisor for this site.\n\n'
        'This material is now live in the site pool for supervisor usage.',
      );

      _resetForm();
      await Future.wait([
        _loadCompanyStockData(isSilent: true),
        _loadSitePoolData(isSilent: true),
      ]);
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to allocate material: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _resetForm() {
    setState(() {
      _selectedMaterialName = null;
      _selectedCategory = '';
      _selectedSubCategory = '';
      _selectedUnit = 'Units';
      _masterPrice = 0.0;
      _quantityController.clear();
      _unitRateController.clear();
      _amountController.clear();
      _remarksController.clear();
      _allocationDate = DateTime.now();
    });
  }

  // ---------------------------------------------------------------------------
  // MANUALLY ADD / UPDATE STOCK DIALOG
  // ---------------------------------------------------------------------------

  void _showAddStockDialog({Map<String, dynamic>? preselectedMaterial}) {
    String? selectedMat = preselectedMaterial?['materialName'] ??
        (_masterMaterials.isNotEmpty ? _masterMaterials.first['materialName'] : null);

    Map<String, dynamic> matData = _masterMaterials.firstWhere(
      (m) => m['materialName'] == selectedMat,
      orElse: () => preselectedMaterial ?? {},
    );

    int currentStock = selectedMat != null ? _getCompanyStockForMaterial(selectedMat) : 0;
    bool isAddition = true; // true: Add to stock (+), false: Set exact total count (=)

    final TextEditingController countCtrl = TextEditingController();
    final TextEditingController priceCtrl = TextEditingController(
      text: matData['unitPrice'] != null && (matData['unitPrice'] as num) > 0
          ? (matData['unitPrice'] as num).toString()
          : '',
    );
    final TextEditingController notesCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final effectiveMatName = selectedMat ?? '';
            final unitStr = (matData['unit'] ?? 'Units').toString();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: SingleChildScrollView(
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
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.add_business_rounded, color: Color(0xFF059669), size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Add Material Stock',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  'Update company warehouse available inventory',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      // Material Selector
                      const Text(
                        'Select Material *',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0A183D)),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: selectedMat,
                        isExpanded: true,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                        ),
                        items: _masterMaterials.map((m) {
                          final name = m['materialName'] as String;
                          return DropdownMenuItem<String>(
                            value: name,
                            child: Text(name, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          setModalState(() {
                            selectedMat = val;
                            matData = _masterMaterials.firstWhere(
                              (m) => m['materialName'] == val,
                              orElse: () => {},
                            );
                            currentStock = _getCompanyStockForMaterial(val);
                            if (matData['unitPrice'] != null && (matData['unitPrice'] as num) > 0) {
                              priceCtrl.text = (matData['unitPrice'] as num).toString();
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      // Current Available Stock Banner
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Current Warehouse Stock:',
                              style: TextStyle(fontSize: 13, color: Color(0xFF1E3A8A), fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '$currentStock $unitStr',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1D4ED8)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Update Mode: Add to stock vs Set total stock
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setModalState(() => isAddition = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isAddition ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: isAddition
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.05),
                                              blurRadius: 4,
                                            )
                                          ]
                                        : [],
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '+ Add to Stock',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setModalState(() => isAddition = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: !isAddition ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: !isAddition
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.05),
                                              blurRadius: 4,
                                            )
                                          ]
                                        : [],
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '= Set Total Count',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Quantity to add or set
                      Text(
                        isAddition ? 'Quantity to Add ($unitStr) *' : 'New Total Stock ($unitStr) *',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0A183D)),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: countCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                        decoration: InputDecoration(
                          hintText: isAddition ? 'e.g. 50, 100' : 'e.g. 150',
                          prefixIcon: const Icon(Icons.pin_rounded, size: 18),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Unit Rate
                      const Text(
                        'Unit Rate (₹) (Optional)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0A183D)),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          hintText: 'Rate per $unitStr',
                          prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 18),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Notes
                      const Text(
                        'Notes / Supplier PO (Optional)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0A183D)),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: notesCtrl,
                        decoration: InputDecoration(
                          hintText: 'e.g. PO #9942, Fresh cement shipment',
                          prefixIcon: const Icon(Icons.description_outlined, size: 18),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Submit Button
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () async {
                            final val = int.tryParse(countCtrl.text.trim()) ?? 0;
                            if (val <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter a valid quantity greater than 0'),
                                  backgroundColor: Color(0xFFEF4444),
                                ),
                              );
                              return;
                            }
                            if (effectiveMatName.isEmpty) return;

                            Navigator.pop(context);
                            setState(() => _isLoadingStock = true);

                            try {
                              final rate = double.tryParse(priceCtrl.text.trim());
                              final newTotal = await MaterialInventoryService.setCompanyStock(
                                materialName: effectiveMatName,
                                count: val,
                                isAddition: isAddition,
                                category: (matData['category'] ?? 'General Material').toString(),
                                subCategory: (matData['subCategory'] ?? '').toString(),
                                unit: unitStr,
                                unitPrice: rate,
                              );

                              _showSuccessDialog(
                                'Company Stock Updated Successfully!\n\n'
                                '• Material: $effectiveMatName\n'
                                '• ${isAddition ? 'Quantity Added' : 'Updated Count'}: $val $unitStr\n'
                                '• Total Company Warehouse Stock: $newTotal $unitStr\n\n'
                                'This stock is now ready for site allocations.',
                              );

                              await _loadCompanyStockData(isSilent: true);
                            } catch (e) {
                              _showErrorDialog('Failed to update stock: $e');
                            } finally {
                              if (mounted) setState(() => _isLoadingStock = false);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: Text(
                            isAddition ? 'ADD STOCK TO INVENTORY' : 'UPDATE COMPANY STOCK',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, letterSpacing: 0.3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // RETURN TO COMPANY DIALOG
  // ---------------------------------------------------------------------------

  void _showReturnMaterialDialog(SiteMaterialPoolItem item) {
    if (item.remainingQty <= 0) {
      _showErrorDialog('No remaining stock of ${item.displayName} at ${item.siteName} to return.');
      return;
    }

    final TextEditingController returnQtyCtrl = TextEditingController();
    final TextEditingController remarksCtrl = TextEditingController();
    final maxReturn = item.remainingQty;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: SingleChildScrollView(
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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.assignment_return_rounded, color: Color(0xFFD97706), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Return Material to Company',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Return surplus stock from ${item.siteName}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Material Info Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.displayName,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Site: ${item.siteName} (${item.siteId})',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Surplus Remaining at Site:',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                            ),
                            Text(
                              '${item.remainingQty.truncateToDouble() == item.remainingQty ? item.remainingQty.toInt() : item.remainingQty.toStringAsFixed(1)} ${item.unit}',
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF059669)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Return Quantity Input
                  Text(
                    'Return Quantity (${item.unit}) *',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0A183D)),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: returnQtyCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      hintText: 'Max: ${maxReturn.toInt()}',
                      prefixIcon: const Icon(Icons.pin_rounded, size: 18),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Remarks Input
                  const Text(
                    'Reason for Return (Optional)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0A183D)),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: remarksCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. Foundation pour completed, returning surplus',
                      prefixIcon: const Icon(Icons.notes_rounded, size: 18),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Submit Return Button
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        final val = int.tryParse(returnQtyCtrl.text.trim()) ?? 0;
                        if (val <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a valid quantity greater than 0'),
                              backgroundColor: Color(0xFFEF4444),
                            ),
                          );
                          return;
                        }
                        if (val > maxReturn) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Cannot return more than available at site ($maxReturn ${item.unit})'),
                              backgroundColor: const Color(0xFFEF4444),
                            ),
                          );
                          return;
                        }

                        Navigator.pop(context);
                        setState(() => _isLoadingPool = true);

                        try {
                          await MaterialInventoryService.transferSiteToCompany(
                            materialName: item.materialName,
                            siteId: item.siteId,
                            quantity: val,
                            siteName: item.siteName,
                            projectName: item.projectName,
                            displayName: item.displayName,
                            managerName: 'Organization',
                          );

                          _showSuccessDialog(
                            'Material Returned Successfully!\n\n'
                            '• Material: ${item.displayName}\n'
                            '• From Site: ${item.siteName}\n'
                            '• Returned Quantity: $val ${item.unit}\n'
                            '• Added back to Company Warehouse Stock!\n\n'
                            'Company stock has been credited and site pool deducted.',
                          );

                          await Future.wait([
                            _loadSitePoolData(isSilent: true),
                            _loadCompanyStockData(isSilent: true),
                          ]);
                        } catch (e) {
                          _showErrorDialog('Failed to return material: $e');
                        } finally {
                          if (mounted) setState(() => _isLoadingPool = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'CONFIRM RETURN TO COMPANY',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, letterSpacing: 0.3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
              SizedBox(width: 10),
              Text(
                'Action Confirmed',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 26),
              SizedBox(width: 10),
              Text('Error', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.redAccent)),
            ],
          ),
          content: Text(message, style: const TextStyle(fontSize: 14, color: Color(0xFF334155))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showAllocationHistoryDialog(SiteMaterialPoolItem item) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(20),
              child: FutureBuilder<List<SiteMaterialAllocation>>(
                future: MaterialInventoryService.fetchSiteMaterialAllocations(
                  siteId: item.siteId,
                  materialName: item.materialName,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final list = snapshot.data ?? [];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.displayName,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Site: ${item.siteName} (${item.siteId})',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${list.length} Allocations',
                              style: const TextStyle(color: Color(0xFF2563EB), fontSize: 12, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      if (list.isEmpty)
                        const Expanded(
                          child: Center(
                            child: Text(
                              'No individual allocation history found for this item.',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.separated(
                            controller: scrollController,
                            itemCount: list.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, idx) {
                              final alloc = list[idx];
                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Batch #${list.length - idx}',
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1E293B)),
                                        ),
                                        Text(
                                          alloc.allocationDate,
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Quantity: ${alloc.quantity.toStringAsFixed(0)} ${alloc.unit}',
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                          ),
                                        ),
                                        Text(
                                          '₹${alloc.allocatedAmount.toStringAsFixed(0)}',
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF059669)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Effective Rate: ₹${alloc.unitRate.toStringAsFixed(2)} / ${alloc.unit}',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w700),
                                    ),
                                    if (alloc.remarks.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Note: ${alloc.remarks}',
                                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Materials Availability',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                darkAccent,
                Color.alphaBlend(primaryColor.withValues(alpha: 0.35), darkAccent),
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
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 3-Mode Switcher Tabs
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCBD5E1)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0A183D).withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _buildTabButton(
                    index: 0,
                    title: 'Stock',
                    icon: Icons.inventory_2_rounded,
                    primaryColor: primaryColor,
                  ),
                  _buildTabButton(
                    index: 1,
                    title: 'Allocate',
                    icon: Icons.hub_rounded,
                    primaryColor: primaryColor,
                  ),
                  _buildTabButton(
                    index: 2,
                    title: 'Site Pool',
                    icon: Icons.storefront_rounded,
                    primaryColor: primaryColor,
                  ),
                ],
              ),
            ),

            // Main Content Area
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 680),
                  child: _isLoadingInitial
                      ? Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                          ),
                        )
                      : SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: _selectedTabIndex == 0
                              ? _buildCompanyStockSection()
                              : _selectedTabIndex == 1
                                  ? _buildAllocationFormSection()
                                  : _buildSiteMaterialPoolSection(),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required int index,
    required String title,
    required IconData icon,
    required Color primaryColor,
  }) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedTabIndex = index);
          if (index == 0) _loadCompanyStockData();
          if (index == 2) _loadSitePoolData();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.1,
                      color: isSelected ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. COMPANY STOCK TAB (MANUALLY ADD / UPDATE STOCK)
  // ---------------------------------------------------------------------------

  Widget _buildCompanyStockSection() {
    final filteredMaterials = _masterMaterials.where((m) {
      final name = (m['materialName'] ?? '').toString().toLowerCase();
      final cat = (m['category'] ?? '').toString().toLowerCase();
      final sub = (m['subCategory'] ?? '').toString().toLowerCase();
      final q = _stockSearchQuery.toLowerCase();
      return q.isEmpty || name.contains(q) || cat.contains(q) || sub.contains(q);
    }).toList();

    int totalAvailableUnits = 0;
    for (var m in _masterMaterials) {
      final name = m['materialName'] as String;
      totalAvailableUnits += _getCompanyStockForMaterial(name);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // KPI & Add Stock Quick Action Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warehouse_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Company Inventory Stock',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showAddStockDialog(),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add Stock'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Materials',
                          style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_masterMaterials.length} Items',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 28, color: Colors.white24),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Warehouse Units',
                            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$totalAvailableUnits Units',
                            style: const TextStyle(color: Color(0xFF34D399), fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Search Box
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _stockSearchController,
                  onChanged: (val) => setState(() => _stockSearchQuery = val),
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Search material by name or category...',
                    hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                    border: InputBorder.none,
                  ),
                ),
              ),
              if (_stockSearchQuery.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF64748B)),
                  onPressed: () {
                    _stockSearchController.clear();
                    setState(() => _stockSearchQuery = '');
                  },
                ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF0F172A)),
                tooltip: 'Refresh',
                onPressed: () => _loadCompanyStockData(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Materials Stock List
        if (_isLoadingStock)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (filteredMaterials.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Column(
              children: [
                Icon(Icons.inventory_2_outlined, size: 36, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Text(
                  _stockSearchQuery.isNotEmpty
                      ? 'No materials found matching "$_stockSearchQuery"'
                      : 'No materials configured in catalog yet.',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredMaterials.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final mat = filteredMaterials[index];
              final matName = mat['materialName'] as String;
              final unit = (mat['unit'] ?? 'Units').toString();
              final category = (mat['category'] ?? 'General Material').toString();
              final currentStock = _getCompanyStockForMaterial(matName);
              final isOutOfStock = currentStock <= 0;

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0A183D).withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isOutOfStock
                            ? const Color(0xFFF1F5F9)
                            : const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.inventory_2_rounded,
                        color: isOutOfStock ? const Color(0xFF94A3B8) : const Color(0xFF059669),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            matName,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            category,
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isOutOfStock
                                ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                                : const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isOutOfStock ? '0 $unit' : '$currentStock $unit',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: isOutOfStock ? const Color(0xFFDC2626) : const Color(0xFF059669),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () => _showAddStockDialog(preselectedMaterial: mat),
                          borderRadius: BorderRadius.circular(6),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_circle_outline_rounded, size: 13, color: Color(0xFF2563EB)),
                                SizedBox(width: 3),
                                Text(
                                  'Update',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: 60),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 2. ALLOCATION FORM TAB
  // ---------------------------------------------------------------------------

  Widget _buildAllocationFormSection() {
    final effectiveRate = _currentEffectiveRate;
    final enteredQty = double.tryParse(_quantityController.text) ?? 0.0;
    final currentWarehouseStock = _selectedMaterialName != null
        ? _getCompanyStockForMaterial(_selectedMaterialName!)
        : 0;
    final isOverStock = enteredQty > currentWarehouseStock && currentWarehouseStock > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Form Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFCBD5E1)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0A183D).withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.hub_rounded, color: Color(0xFF2563EB), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Allocate Material to Site',
                          style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: Color(0xFF0A183D), letterSpacing: -0.3),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Stock is deducted from company & added to site pool',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 28),

              // 1. Site Dropdown
              _buildWhiteDropdown(
                label: 'Destination Site *',
                value: _selectedSiteId,
                icon: Icons.location_on_rounded,
                hintText: _sites.isEmpty ? 'No sites available' : 'Select site',
                items: _sites.map((s) {
                  final sId = s['siteId'] as String;
                  final sName = s['siteName'] as String;
                  final label = sName != sId ? '$sName ($sId)' : sId;
                  return DropdownMenuItem<String>(
                    value: sId,
                    child: Text(label, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) return;
                  final match = _sites.firstWhere((s) => s['siteId'] == value, orElse: () => {});
                  setState(() {
                    _selectedSiteId = value;
                    _selectedSiteName = match['siteName'];
                    _selectedProjectName = match['projectName'];
                  });
                },
              ),
              const SizedBox(height: 16),

              // 2. Material Master Dropdown
              _buildWhiteDropdown(
                label: 'Construction Material *',
                value: _selectedMaterialName,
                icon: Icons.inventory_2_rounded,
                hintText: _masterMaterials.isEmpty ? 'No materials configured' : 'Select material',
                items: _masterMaterials.map((m) {
                  final name = m['materialName'] as String;
                  return DropdownMenuItem<String>(
                    value: name,
                    child: Text(name, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: _onMaterialSelected,
              ),

              // Live Company Stock Display for selected material
              if (_selectedMaterialName != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: currentWarehouseStock > 0
                        ? const Color(0xFFEFF6FF)
                        : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: currentWarehouseStock > 0
                          ? const Color(0xFFBFDBFE)
                          : const Color(0xFFFECACA),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        currentWarehouseStock > 0
                            ? Icons.check_circle_rounded
                            : Icons.warning_amber_rounded,
                        size: 15,
                        color: currentWarehouseStock > 0
                            ? const Color(0xFF2563EB)
                            : const Color(0xFFDC2626),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Available in Company Warehouse: ',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: currentWarehouseStock > 0
                              ? const Color(0xFF1E3A8A)
                              : const Color(0xFF991B1B),
                        ),
                      ),
                      Text(
                        '$currentWarehouseStock $_selectedUnit',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: currentWarehouseStock > 0
                              ? const Color(0xFF1D4ED8)
                              : const Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_selectedCategory.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Category: $_selectedCategory',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                      ),
                    ),
                    if (_selectedSubCategory.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Sub: $_selectedSubCategory',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF7C3AED)),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),

              // 3. Quantity and Unit in Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: _buildWhiteTextField(
                      label: 'Quantity *',
                      icon: Icons.pin_rounded,
                      hintText: 'e.g. 50, 1000',
                      controller: _quantityController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: _onQuantityChanged,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 4,
                    child: _buildWhiteDropdown(
                      label: 'Unit *',
                      value: _selectedUnit,
                      icon: Icons.straighten_rounded,
                      hintText: 'Unit',
                      items: _availableUnits.map((u) {
                        return DropdownMenuItem<String>(
                          value: u,
                          child: Text(u, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedUnit = val);
                      },
                    ),
                  ),
                ],
              ),

              if (isOverStock) ...[
                const SizedBox(height: 6),
                Text(
                  '⚠️ Entered quantity exceeds warehouse stock ($currentWarehouseStock $_selectedUnit). Company stock will be depleted to 0.',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFFD97706), fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 16),

              // 4. Fixed Unit Rate & Total Allocated Amount in Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: _buildWhiteTextField(
                      label: 'Unit Rate (₹) *',
                      icon: Icons.sell_rounded,
                      hintText: 'e.g. 500',
                      controller: _unitRateController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: _onUnitRateChanged,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 5,
                    child: _buildWhiteTextField(
                      label: 'Total Amount (₹) *',
                      icon: Icons.currency_rupee_rounded,
                      hintText: 'Auto: Qty × Rate',
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 5. Fixed Rate Live Preview Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: effectiveRate > 0 ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: effectiveRate > 0 ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.sell_rounded,
                      color: effectiveRate > 0 ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Fixed Material Unit Rate',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            effectiveRate > 0
                                ? '₹${effectiveRate.toStringAsFixed(2)} / $_selectedUnit'
                                : 'Select material to see fixed rate',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: effectiveRate > 0 ? const Color(0xFF1D4ED8) : const Color(0xFF94A3B8),
                            ),
                          ),
                          if (enteredQty > 0 && effectiveRate > 0) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${enteredQty.truncateToDouble() == enteredQty ? enteredQty.toInt() : enteredQty} $_selectedUnit × ₹${effectiveRate.toStringAsFixed(effectiveRate.truncateToDouble() == effectiveRate ? 0 : 2)} = ₹${(enteredQty * effectiveRate).toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (effectiveRate > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Fixed Rate',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 6. Allocation Date
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Allocation Date',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0A183D),
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 7),
                  InkWell(
                    onTap: _pickAllocationDate,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_month_rounded, color: Theme.of(context).primaryColor, size: 18),
                          const SizedBox(width: 10),
                          Text(
                            DateFormat('dd MMM yyyy').format(_allocationDate),
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0A183D)),
                          ),
                          const Spacer(),
                          const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF64748B), size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 7. Remarks
              _buildWhiteTextField(
                label: 'Remarks / PO Reference (Optional)',
                icon: Icons.notes_rounded,
                hintText: 'e.g. PO #1049, Batch 1 for foundation pour',
                controller: _remarksController,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Submit Button
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitAllocation,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'ALLOCATE MATERIAL TO SITE',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 60),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 3. SITE MATERIAL POOL TAB
  // ---------------------------------------------------------------------------

  Widget _buildSiteMaterialPoolSection() {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    final filteredList = _sitePoolItems.where((item) {
      final matchesSearch = item.displayName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.siteName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.siteId.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesSite = _filterSiteId == null || _filterSiteId!.isEmpty || item.siteId.toLowerCase() == _filterSiteId!.toLowerCase();

      return matchesSearch && matchesSite;
    }).toList();

    double totalAllocValue = 0.0;
    double totalConsumedValue = 0.0;
    double totalRemainingValue = 0.0;

    for (var it in filteredList) {
      totalAllocValue += it.totalAllocatedAmount;
      totalConsumedValue += it.consumedAmount;
      totalRemainingValue += it.remainingAmount;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Site Filter & Search Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFCBD5E1)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0A183D).withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Site selector
              Row(
                children: [
                  const Icon(Icons.filter_alt_rounded, size: 18, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  const Text('Filter by Site:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButton<String?>(
                      value: _filterSiteId,
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      hint: const Text('All Sites', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Sites (Organization)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                        ..._sites.map((s) {
                          final sId = s['siteId'] as String;
                          final sName = s['siteName'] as String;
                          return DropdownMenuItem<String?>(
                            value: sId,
                            child: Text('$sName ($sId)', style: const TextStyle(fontSize: 13)),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setState(() => _filterSiteId = val);
                        _loadSitePoolData();
                      },
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh_rounded, color: primaryColor, size: 20),
                    tooltip: 'Refresh',
                    onPressed: () => _loadSitePoolData(),
                  ),
                ],
              ),
              const Divider(height: 12),

              // Search box
              TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                textAlignVertical: TextAlignVertical.center,
                style: const TextStyle(
                  color: Color(0xFF0A183D),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  hintText: 'Search material, category, or site...',
                  hintStyle: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 8),
                    child: Icon(Icons.search_rounded, color: primaryColor, size: 18),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primaryColor, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Financial Separation Summary Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.account_balance_wallet_rounded, color: Colors.white70, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Site Material Pool Financials',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildKpiStat(
                      label: 'Allocated Value',
                      value: '₹${NumberFormat.compact().format(totalAllocValue)}',
                      color: const Color(0xFF60A5FA),
                    ),
                  ),
                  Container(width: 1, height: 32, color: Colors.white24),
                  Expanded(
                    child: _buildKpiStat(
                      label: 'Consumed Value',
                      value: '₹${NumberFormat.compact().format(totalConsumedValue)}',
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                  Container(width: 1, height: 32, color: Colors.white24),
                  Expanded(
                    child: _buildKpiStat(
                      label: 'Remaining Value',
                      value: '₹${NumberFormat.compact().format(totalRemainingValue)}',
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 3. Pool Items List
        if (_isLoadingPool)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (filteredList.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Column(
              children: [
                Icon(Icons.inventory_2_outlined, size: 40, color: Colors.grey.shade400),
                const SizedBox(height: 10),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'No pool records matching "$_searchQuery"'
                      : 'No material allocations recorded for this site yet.\nSwitch to "ALLOCATE TO SITE" to create the first allocation.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 13.5, height: 1.4),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredList.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = filteredList[index];
              return _buildPoolItemCard(item);
            },
          ),

        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildKpiStat({required String label, required String value, required Color color}) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildPoolItemCard(SiteMaterialPoolItem item) {
    final rateStr = item.effectiveUnitRate.truncateToDouble() == item.effectiveUnitRate
        ? item.effectiveUnitRate.toInt().toString()
        : item.effectiveUnitRate.toStringAsFixed(2);

    final remQtyStr = item.remainingQty.truncateToDouble() == item.remainingQty
        ? item.remainingQty.toInt().toString()
        : item.remainingQty.toStringAsFixed(1);

    final allocQtyStr = item.totalAllocatedQty.truncateToDouble() == item.totalAllocatedQty
        ? item.totalAllocatedQty.toInt().toString()
        : item.totalAllocatedQty.toStringAsFixed(1);

    final consQtyStr = item.consumedQty.truncateToDouble() == item.consumedQty
        ? item.consumedQty.toInt().toString()
        : item.consumedQty.toStringAsFixed(1);

    final isLowStock = item.remainingQty <= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header: Material Name + Category + Site Pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayName,
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.category,
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF64748B).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Site: ${item.siteName}',
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: isLowStock ? const Color(0xFFEF4444).withValues(alpha: 0.12) : const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isLowStock ? 'Exhausted' : 'Rate: ₹$rateStr / ${item.unit}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: isLowStock ? const Color(0xFFDC2626) : const Color(0xFF059669),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3 Metric Blocks: Allocated | Consumed | Remaining
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Allocated', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('$allocQtyStr ${item.unit}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                      Text('₹${item.totalAllocatedAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                Container(width: 1, height: 28, color: const Color(0xFFCBD5E1)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Consumed', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('$consQtyStr ${item.unit}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFD97706))),
                        Text('₹${item.consumedAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ),
                Container(width: 1, height: 28, color: const Color(0xFFCBD5E1)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Remaining', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          '$remQtyStr ${item.unit}',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: isLowStock ? Colors.redAccent : const Color(0xFF059669),
                          ),
                        ),
                        Text('₹${item.remainingAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Actions Row: Return to Company & Allocation History
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              if (item.remainingQty > 0) ...[
                TextButton.icon(
                  onPressed: () => _showReturnMaterialDialog(item),
                  icon: const Icon(Icons.assignment_return_rounded, size: 15),
                  label: const Text('Return to Company', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFD97706),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(0, 32),
                  ),
                ),
              ],
              TextButton.icon(
                onPressed: () => _showAllocationHistoryDialog(item),
                icon: const Icon(Icons.history_rounded, size: 16),
                label: const Text('Allocation History', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: const Size(0, 32),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPER FORM WIDGETS
  // ---------------------------------------------------------------------------

  Widget _buildFieldLabel(String label) {
    final isRequired = label.contains('*');
    final cleanText = label.replaceAll('*', '').trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          text: cleanText,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0A183D),
            letterSpacing: -0.1,
          ),
          children: isRequired
              ? const [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ]
              : null,
        ),
      ),
    );
  }

  Widget _buildWhiteTextField({
    required String label,
    required IconData icon,
    required String hintText,
    required TextEditingController controller,
    TextInputType? keyboardType,
    void Function(String)? onChanged,
    int maxLines = 1,
  }) {
    final brandIconColor = Theme.of(context).primaryColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: onChanged,
          textAlignVertical: TextAlignVertical.center,
          style: const TextStyle(
            color: Color(0xFF0A183D),
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            hintText: hintText,
            hintStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Icon(icon, color: brandIconColor, size: 18),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 38,
              minHeight: 38,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12.5,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: brandIconColor, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWhiteDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
    IconData icon = Icons.list_alt_rounded,
    String? hintText,
  }) {
    final brandIconColor = Theme.of(context).primaryColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label),
        DropdownButtonFormField<String>(
          key: ValueKey(value),
          isExpanded: true,
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          initialValue: (value != null && items.any((i) => i.value == value))
              ? value
              : null,
          style: const TextStyle(
            color: Color(0xFF0A183D),
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            hintText: hintText ?? 'Select $label',
            hintStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Icon(icon, color: brandIconColor, size: 18),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 38,
              minHeight: 38,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12.5,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: brandIconColor, width: 1.5),
            ),
          ),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
