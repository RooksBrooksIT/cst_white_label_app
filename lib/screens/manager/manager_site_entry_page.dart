import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';
import 'package:demo_cst/widgets/glass_button.dart';

class ManagerSiteEntryPage extends StatefulWidget {
  final String userName;
  final Map<String, dynamic> userDetails;
  final bool hideAppBar;
  const ManagerSiteEntryPage({
    super.key,
    required this.userName,
    required this.userDetails,
    this.hideAppBar = false,
  });

  @override
  State<ManagerSiteEntryPage> createState() => _ManagerSiteEntryPageState();
}

class _ManagerSiteEntryPageState extends State<ManagerSiteEntryPage> {
  List<Map<String, dynamic>> materials = [];
  List<Map<String, dynamic>> labours = [];
  String? selectedMaterial;
  int materialQty = 0;
  final materialQtyController = TextEditingController(text: '0');
  String? selectedLabour;
  int labourQty = 0;
  final labourQtyController = TextEditingController(text: '0');
  final foodCost = TextEditingController(text: '0');
  final transportCost = TextEditingController(text: '0');
  final fuelCost = TextEditingController(text: '0');
  final morningStatusController = TextEditingController();
  final afternoonStatusController = TextEditingController();
  DateTime? selectedDate = DateTime.now();
  List<String> materialOptions = [];
  List<String> labourOptions = [];
  List<String>? _filteredMaterialOptions;
  List<String>? _filteredLabourOptions;
  bool isLoadingMaterials = true;
  bool isLoadingLabours = true;
  String? materialError;
  String? labourError;
  String? supervisorId;
  String? projectName;
  String siteCode = '';
  List<Map<String, String>> siteList = [];
  String? selectedSiteId;
  String? supervisorName;
  String? siteLocation;
  String? projectStage;
  bool isLoadingSites = true;
  bool isSaving = false;
  Map<String, num> materialPrices = {};
  Map<String, num> labourSalaries = {};

  // Custom material fields
  bool _showCustomMaterialFields = false;
  final _customMaterialNameController = TextEditingController();
  final _customMaterialQtyController = TextEditingController(text: '0');
  final _customMaterialPriceController = TextEditingController(text: '0');

  // Custom labour fields
  bool _showCustomLabourFields = false;
  final _customLabourNameController = TextEditingController();
  final _customLabourSalaryController = TextEditingController(text: '0');
  final _customLabourQtyController = TextEditingController(text: '0');

  // Update mode state
  bool isUpdateMode = false;
  String? _updateDocId;
  bool isLoadingEntryDates = false;
  List<Map<String, dynamic>> _existingEntries = [];
  DateTime? _selectedUpdateDate;

  Color get primaryColor => Theme.of(context).primaryColor;
  Color get successColor => const Color(0xFF27ae60);
  Color get warningColor => const Color(0xFFe67e22);
  Color get errorColor => Theme.of(context).colorScheme.error;

  @override
  void initState() {
    super.initState();
    _fetchMaterialOptions();
    _fetchLabourOptions();
    _fetchSites();
  }

  @override
  void dispose() {
    materialQtyController.dispose();
    labourQtyController.dispose();
    foodCost.dispose();
    transportCost.dispose();
    fuelCost.dispose();
    morningStatusController.dispose();
    afternoonStatusController.dispose();
    _customMaterialNameController.dispose();
    _customMaterialQtyController.dispose();
    _customMaterialPriceController.dispose();
    _customLabourNameController.dispose();
    _customLabourSalaryController.dispose();
    _customLabourQtyController.dispose();
    super.dispose();
  }

  Future<void> _fetchSites() async {
    if (!mounted) return;
    setState(() => isLoadingSites = true);
    try {
      final sitesSnapshot = await FirestoreService.sites.get();
      final Map<String, String> siteNames = {
        for (var doc in sitesSnapshot.docs)
          doc.id: doc.data()['siteName']?.toString() ?? 'Unnamed Site',
      };
      final snapshot = await FirestoreService.siteSupervisorMap.get();
      siteList = snapshot.docs
          .map((doc) {
            final data = doc.data();
            final sId = data['site']?.toString() ?? '';
            return {
              'siteId': sId,
              'siteName': siteNames[sId] ?? 'Unnamed Site',
              'supervisor': data['supervisor']?.toString() ?? 'Not Available',
              'supervisorId':
                  (data['Supervisor ID'] ?? data['supervisorId'])?.toString() ??
                  'Not Available',
              'location': data['location']?.toString() ?? 'Not Available',
              'projectStage':
                  data['projectStage']?.toString() ?? 'Not Available',
            };
          })
          .where((site) => site['siteId']!.isNotEmpty)
          .toList();

      if (siteList.isNotEmpty) {
        selectedSiteId = siteList.first['siteId'];
        _onSiteSelected(selectedSiteId!);
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => isLoadingSites = false);
    }
  }

  void _onSiteSelected(String siteId) {
    final site = siteList.firstWhere(
      (s) => s['siteId'] == siteId,
      orElse: () => {},
    );
    setState(() {
      selectedSiteId = siteId;
      siteCode = siteId;
      supervisorName = site['supervisor'];
      supervisorId = site['supervisorId'] ?? 'Not Available';
      siteLocation = site['location'];
      projectStage = site['projectStage'];
      isUpdateMode = false;
      _updateDocId = null;
      _selectedUpdateDate = null;
    });
  }

  Future<void> _fetchMaterialOptions() async {
    if (!mounted) return;
    setState(() {
      isLoadingMaterials = true;
      materialError = null;
    });
    try {
      final snapshot = await FirestoreService.materials.get();
      final options = <String>[];
      final prices = <String, num>{};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final name = data['materialName']?.toString() ?? '';
        if (name.isNotEmpty) {
          options.add(name);
          final priceRaw = data['materialPrice'];
          num price = 0;
          if (priceRaw is num) {
            price = priceRaw;
          } else if (priceRaw is String) {
            price =
                num.tryParse(priceRaw.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
          }
          prices[name] = price;
        }
      }
      if (!mounted) return;
      setState(() {
        materialOptions = options;
        materialPrices = prices;
        selectedMaterial = materialOptions.isNotEmpty
            ? materialOptions.first
            : null;
        isLoadingMaterials = false;
      });
    } catch (e) {
      if (mounted) setState(() => isLoadingMaterials = false);
    }
  }

  Future<void> _fetchLabourOptions() async {
    if (!mounted) return;
    setState(() {
      isLoadingLabours = true;
      labourError = null;
    });
    try {
      final snapshot = await FirestoreService.labours.get();
      final options = <String>[];
      final salaries = <String, num>{};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final des = data['designation']?.toString() ?? '';
        if (des.isNotEmpty) {
          options.add(des);
          final salaryRaw = data['salary'];
          num salary = 0;
          if (salaryRaw is num) {
            salary = salaryRaw;
          } else if (salaryRaw is String) {
            salary =
                num.tryParse(salaryRaw.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
          }
          salaries[des] = salary;
        }
      }
      if (!mounted) return;
      setState(() {
        labourOptions = options;
        labourSalaries = salaries;
        selectedLabour = labourOptions.isNotEmpty ? labourOptions.first : null;
        isLoadingLabours = false;
      });
    } catch (e) {
      if (mounted) setState(() => isLoadingLabours = false);
    }
  }

  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  void _addMaterial() {
    if (selectedMaterial == null || selectedMaterial!.isEmpty) return;
    final qty = int.tryParse(materialQtyController.text) ?? 0;
    if (qty <= 0) return;

    final existingIndex = materials.indexWhere(
      (m) => m['type'] == selectedMaterial,
    );
    if (existingIndex >= 0) {
      setState(() {
        materials[existingIndex]['quantity'] += qty;
      });
    } else {
      setState(() {
        materials.add({
          'type': selectedMaterial,
          'quantity': qty,
          'unitPrice': materialPrices[selectedMaterial] ?? 0,
        });
      });
    }
    materialQtyController.text = '0';
  }

  void _addCustomMaterial() {
    final name = _customMaterialNameController.text.trim();
    final qty = int.tryParse(_customMaterialQtyController.text) ?? 0;
    final price = num.tryParse(_customMaterialPriceController.text) ?? 0;

    if (name.isEmpty || qty <= 0) return;

    setState(() {
      materials.add({
        'type': name,
        'quantity': qty,
        'unitPrice': price,
      });
      _customMaterialNameController.clear();
      _customMaterialQtyController.text = '0';
      _customMaterialPriceController.text = '0';
      _showCustomMaterialFields = false;
    });
  }

  void _removeMaterial(int index) {
    setState(() {
      materials.removeAt(index);
    });
  }

  void _addLabour() {
    if (selectedLabour == null || selectedLabour!.isEmpty) return;
    final count = int.tryParse(labourQtyController.text) ?? 0;
    if (count <= 0) return;

    final existingIndex = labours.indexWhere(
      (l) => l['type'] == selectedLabour,
    );
    if (existingIndex >= 0) {
      setState(() {
        labours[existingIndex]['count'] += count;
      });
    } else {
      setState(() {
        labours.add({
          'type': selectedLabour,
          'count': count,
          'salary': labourSalaries[selectedLabour] ?? 0,
        });
      });
    }
    labourQtyController.text = '0';
  }

  void _addCustomLabour() {
    final type = _customLabourNameController.text.trim();
    final salary = num.tryParse(_customLabourSalaryController.text) ?? 0;
    final count = int.tryParse(_customLabourQtyController.text) ?? 0;

    if (type.isEmpty || count <= 0) return;

    setState(() {
      labours.add({
        'type': type,
        'count': count,
        'salary': salary,
      });
      _customLabourNameController.clear();
      _customLabourSalaryController.text = '0';
      _customLabourQtyController.text = '0';
      _showCustomLabourFields = false;
    });
  }

  void _removeLabour(int index) {
    setState(() {
      labours.removeAt(index);
    });
  }

  num _getTotalAmount() {
    num total = 0;
    for (var m in materials) {
      total += (m['quantity'] as int) * (m['unitPrice'] as num);
    }
    for (var l in labours) {
      total += (l['count'] as int) * (l['salary'] as num);
    }
    total += int.tryParse(foodCost.text) ?? 0;
    total += int.tryParse(transportCost.text) ?? 0;
    total += int.tryParse(fuelCost.text) ?? 0;
    return total;
  }

  String _calculateMaterialAmount(String type, int qty) {
    final price = materialPrices[type] ?? 0;
    return '₹${qty * price}';
  }

  String _calculateLabourAmount(String type, int count) {
    final salary = labourSalaries[type] ?? 0;
    return '₹${count * salary}';
  }

  void _resetForm() {
    setState(() {
      materials.clear();
      labours.clear();
      materialQtyController.text = '0';
      labourQtyController.text = '0';
      foodCost.text = '0';
      transportCost.text = '0';
      fuelCost.text = '0';
      morningStatusController.clear();
      afternoonStatusController.clear();
      _customMaterialNameController.clear();
      _customMaterialQtyController.text = '0';
      _customMaterialPriceController.text = '0';
      _customLabourNameController.clear();
      _customLabourSalaryController.text = '0';
      _customLabourQtyController.text = '0';
      _showCustomMaterialFields = false;
      _showCustomLabourFields = false;
      isUpdateMode = false;
      _updateDocId = null;
      _selectedUpdateDate = null;
      selectedDate = DateTime.now();
    });
  }

  void _refreshData() {
    _fetchSites();
    _fetchMaterialOptions();
    _fetchLabourOptions();
  }

  Future<void> _openUpdateEntrySelector() async {
    if (selectedSiteId == null || selectedSiteId!.isEmpty) return;

    setState(() => isLoadingEntryDates = true);

    try {
      final snapshot = await FirestoreService.getCollection('ManagerSiteEntry')
          .where('siteCode', isEqualTo: selectedSiteId)
          .orderBy('createdAt', descending: true)
          .get();

      _existingEntries = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        DateTime? date;
        if (data['date'] is Timestamp) {
          date = (data['date'] as Timestamp).toDate();
        } else if (data['createdAt'] is Timestamp) {
          date = (data['createdAt'] as Timestamp).toDate();
        }
        return {
          'docId': doc.id,
          'date': date,
          'data': data,
        };
      }).toList();

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        backgroundColor: AppTheme.getDarkAccent(primaryColor),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Existing Entry to Update',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                if (_existingEntries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'No past entries found for this site.',
                      style: TextStyle(color: Color(0xFFCBD5E1)),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _existingEntries.length,
                      itemBuilder: (context, index) {
                        final entry = _existingEntries[index];
                        final dateStr = entry['date'] != null
                            ? DateFormat('yyyy-MM-dd HH:mm').format(entry['date'])
                            : 'Unknown Date';
                        return ListTile(
                          leading: const Icon(
                            Icons.receipt_long_rounded,
                            color: Colors.white,
                          ),
                          title: Text(
                            dateStr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _loadEntryForUpdate(entry['docId'], entry['data']);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      debugPrint('Error fetching entry dates: $e');
    } finally {
      if (mounted) setState(() => isLoadingEntryDates = false);
    }
  }

  void _loadEntryForUpdate(String docId, Map<String, dynamic> data) {
    setState(() {
      isUpdateMode = true;
      _updateDocId = docId;

      if (data['date'] is Timestamp) {
        _selectedUpdateDate = (data['date'] as Timestamp).toDate();
      }

      materials = List<Map<String, dynamic>>.from(data['materials'] ?? []);
      labours = List<Map<String, dynamic>>.from(data['labours'] ?? []);

      final expenses = data['otherExpenses'] as Map<String, dynamic>? ?? {};
      foodCost.text = (expenses['food'] ?? 0).toString();
      transportCost.text = (expenses['transport'] ?? 0).toString();
      fuelCost.text = (expenses['fuel'] ?? 0).toString();

      morningStatusController.text = data['morningStatus']?.toString() ?? '';
      afternoonStatusController.text = data['afternoonStatus']?.toString() ?? '';
    });
  }

  Future<void> _saveEntry() async {
    if (selectedSiteId == null) return;
    setState(() => isSaving = true);

    try {
      final entryData = {
        'siteCode': selectedSiteId,
        'userName': widget.userName,
        'supervisorName': supervisorName,
        'supervisorId': supervisorId,
        'siteLocation': siteLocation,
        'projectStage': projectStage,
        'date': selectedDate != null
            ? Timestamp.fromDate(selectedDate!)
            : FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'materials': materials,
        'labours': labours,
        'otherExpenses': {
          'food': int.tryParse(foodCost.text) ?? 0,
          'transport': int.tryParse(transportCost.text) ?? 0,
          'fuel': int.tryParse(fuelCost.text) ?? 0,
        },
        'morningStatus': morningStatusController.text.trim(),
        'afternoonStatus': afternoonStatusController.text.trim(),
        'totalCost': _getTotalAmount(),
      };

      await FirestoreService.getCollection('ManagerSiteEntry').add(entryData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Site entry saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _resetForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save entry: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _updateExistingEntry() async {
    if (_updateDocId == null) return;
    setState(() => isSaving = true);

    try {
      final updateData = {
        'materials': materials,
        'labours': labours,
        'otherExpenses': {
          'food': int.tryParse(foodCost.text) ?? 0,
          'transport': int.tryParse(transportCost.text) ?? 0,
          'fuel': int.tryParse(fuelCost.text) ?? 0,
        },
        'morningStatus': morningStatusController.text.trim(),
        'afternoonStatus': afternoonStatusController.text.trim(),
        'totalCost': _getTotalAmount(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirestoreService.getCollection('ManagerSiteEntry')
          .doc(_updateDocId)
          .update(updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Site entry updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _resetForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update entry: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Save'),
        content: const Text('Are you sure you want to save this daily site entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _saveEntry();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color darkCardBg = isDark ? AppTheme.getDarkAccent(primaryColor) : Colors.white;

    return GlassScaffold(
      title: widget.hideAppBar ? null : 'Manager Daily Site Entry',
      appBarForegroundColor: Colors.white,
      onBack: widget.hideAppBar ? null : () => Navigator.pop(context),
      actions: [
        if (!widget.hideAppBar)
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.getDarkAccent(AppTheme.primaryColor.value),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.getDarkAccent(AppTheme.primaryColor.value).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  onPressed: _refreshData,
                ),
              ),
            ),
          ),
      ],
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 600,
                  minHeight: constraints.maxHeight,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Site Information Card ─────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: darkCardBg,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: darkCardBg.withValues(alpha: 0.25),
                            blurRadius: 16,
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
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.18),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.construction_rounded,
                                  size: 22,
                                  color: primaryColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: isLoadingSites
                                    ? const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.08),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: DropdownButtonFormField<String>(
                                          value: selectedSiteId,
                                          isExpanded: true,
                                          dropdownColor: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          style: const TextStyle(
                                            color: Color(0xFF0A183D),
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: 'Select Site ID',
                                            hintStyle: const TextStyle(
                                              color: Color(0xFF94A3B8),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              borderSide: BorderSide.none,
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                          ),
                                          items: siteList
                                              .map(
                                                (site) => DropdownMenuItem(
                                                  value: site['siteId'],
                                                  child: Text(
                                                    '${site['siteId']} - ${site['siteName']}',
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: (value) {
                                            if (value != null) {
                                              _onSiteSelected(value);
                                            }
                                          },
                                        ),
                                      ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            Icons.person_rounded,
                            'Supervisor',
                            supervisorName ?? '-',
                          ),
                          if (supervisorId != null && supervisorId!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 28.0, top: 2),
                              child: Text(
                                'ID: ${supervisorId ?? '-'}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFFCBD5E1),
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          const SizedBox(height: 4),
                          _buildInfoRow(
                            Icons.location_on_rounded,
                            'Location',
                            siteLocation ?? '-',
                          ),
                          _buildInfoRow(
                            Icons.timeline_rounded,
                            'Project Stage',
                            projectStage ?? '-',
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 18,
                                color: primaryColor,
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  selectedDate != null
                                      ? DateFormat('yyyy-MM-dd')
                                          .format(selectedDate!)
                                      : 'No date chosen',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Spacer(),
                              if (!isUpdateMode)
                                TextButton.icon(
                                  onPressed: _pickDate,
                                  icon: const Icon(
                                    Icons.edit_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  label: const Text(
                                    'Change',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.15),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Update Entry Card ─────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: darkCardBg,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: darkCardBg.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSectionHeader('Update Entry'),
                          const SizedBox(height: 12),
                          if (isUpdateMode && _selectedUpdateDate != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10.0),
                              child: Text(
                                'Loaded entry for: ${DateFormat('yyyy-MM-dd').format(_selectedUpdateDate!)}',
                                style: const TextStyle(
                                  color: Color(0xFF4ADE80),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(
                                      Icons.history_rounded,
                                      size: 18,
                                    ),
                                    onPressed: isLoadingSites ||
                                            selectedSiteId == null ||
                                            selectedSiteId!.isEmpty
                                        ? null
                                        : _openUpdateEntrySelector,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      foregroundColor: const Color(0xFF0A183D),
                                      disabledBackgroundColor:
                                          Colors.white.withValues(alpha: 0.12),
                                      disabledForegroundColor:
                                          Colors.white.withValues(alpha: 0.45),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      elevation: 4,
                                      shadowColor: primaryColor
                                          .withValues(alpha: 0.4),
                                    ),
                                    label: const Text(
                                      'Select Existing Entry',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (isUpdateMode) const SizedBox(width: 10),
                              if (isUpdateMode)
                                Expanded(
                                  child: SizedBox(
                                    height: 48,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          isUpdateMode = false;
                                          _updateDocId = null;
                                          _selectedUpdateDate = null;
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            Colors.white.withValues(alpha: 0.15),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          side: BorderSide(
                                            color: Colors.white
                                                .withValues(alpha: 0.3),
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: const Text(
                                        'Exit Update',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Form Section Header ───────────────────────────────────
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 20,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A183D),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Add Entry',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0A183D),
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Material Section Card ─────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: darkCardBg,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: darkCardBg.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSectionHeader('Material Details'),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                flex: 3,
                                child: isLoadingMaterials
                                    ? const Center(
                                        child: CircularProgressIndicator(),
                                      )
                                    : Column(
                                        children: [
                                          _buildTextField(
                                            'Search Material',
                                            null,
                                            hintText: 'Search Material...',
                                            icon: Icons.search_rounded,
                                            onChanged: (query) {
                                              setState(() {
                                                final q = query.toLowerCase();
                                                final filtered = materialOptions
                                                    .where(
                                                      (item) => item
                                                          .toLowerCase()
                                                          .startsWith(q),
                                                    )
                                                    .toList();
                                                filtered.sort(
                                                  (a, b) => a
                                                      .toLowerCase()
                                                      .compareTo(b.toLowerCase()),
                                                );
                                                if (filtered.isNotEmpty) {
                                                  selectedMaterial =
                                                      filtered.contains(
                                                            selectedMaterial,
                                                          )
                                                          ? selectedMaterial
                                                          : filtered.first;
                                                } else {
                                                  selectedMaterial = null;
                                                }
                                                _filteredMaterialOptions =
                                                    filtered;
                                              });
                                            },
                                          ),
                                          const SizedBox(height: 12),
                                          _buildMaterialDropdown(),
                                        ],
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: _buildQtyField(
                                  'Qty',
                                  materialQtyController,
                                  onChanged: (value) {
                                    setState(() {
                                      materialQty =
                                          int.tryParse(value) ?? 0;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              height: 44,
                              child: ElevatedButton.icon(
                                icon: const Icon(
                                  Icons.add_circle_outline_rounded,
                                  size: 18,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: const Color(0xFF0A183D),
                                  disabledBackgroundColor:
                                      Colors.white.withValues(alpha: 0.12),
                                  disabledForegroundColor:
                                      Colors.white.withValues(alpha: 0.45),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 4,
                                  shadowColor: primaryColor
                                      .withValues(alpha: 0.4),
                                ),
                                onPressed: isLoadingMaterials ||
                                        materialOptions.isEmpty
                                    ? null
                                    : _addMaterial,
                                label: const Text(
                                  'Add Material',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              icon: Icon(
                                _showCustomMaterialFields
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: primaryColor,
                              ),
                              onPressed: () {
                                setState(() {
                                  _showCustomMaterialFields =
                                      !_showCustomMaterialFields;
                                });
                              },
                              label: Text(
                                _showCustomMaterialFields
                                    ? 'Hide Other Materials'
                                    : 'Other Materials',
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          if (_showCustomMaterialFields) ...[
                            const SizedBox(height: 10),
                            _buildTextField(
                              'Material Name',
                              _customMaterialNameController,
                              hintText: 'Enter material name',
                            ),
                            const SizedBox(height: 10),
                            _buildQtyField(
                              'Qty',
                              _customMaterialQtyController,
                            ),
                            const SizedBox(height: 10),
                            _buildQtyField(
                              'Unit Price',
                              _customMaterialPriceController,
                            ),
                            const SizedBox(height: 12),
                            GlassButton(
                              label: 'ADD OTHER MATERIAL',
                              icon: Icons.check,
                              onPressed: _addCustomMaterial,
                              isSecondary: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Labour Details Card ───────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: darkCardBg,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: darkCardBg.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSectionHeader('Labour Details'),
                          const SizedBox(height: 16),
                          isLoadingLabours
                              ? const CircularProgressIndicator()
                              : _buildLabourDropdown(),
                          const SizedBox(height: 14),
                          _buildQtyField('Count', labourQtyController),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              height: 44,
                              child: ElevatedButton.icon(
                                icon: const Icon(
                                  Icons.person_add_rounded,
                                  size: 18,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: const Color(0xFF0A183D),
                                  disabledBackgroundColor:
                                      Colors.white.withValues(alpha: 0.12),
                                  disabledForegroundColor:
                                      Colors.white.withValues(alpha: 0.45),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 4,
                                  shadowColor: primaryColor
                                      .withValues(alpha: 0.4),
                                ),
                                onPressed: _addLabour,
                                label: const Text(
                                  'ADD LABOUR',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              icon: Icon(
                                _showCustomLabourFields
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: primaryColor,
                              ),
                              onPressed: () {
                                setState(() {
                                  _showCustomLabourFields =
                                      !_showCustomLabourFields;
                                });
                              },
                              label: Text(
                                _showCustomLabourFields
                                    ? 'Hide Custom Labour'
                                    : 'Add Custom Labour',
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          if (_showCustomLabourFields) ...[
                            const SizedBox(height: 10),
                            _buildTextField(
                              'Labour Type',
                              _customLabourNameController,
                              hintText: 'Enter designation',
                            ),
                            const SizedBox(height: 10),
                            _buildQtyField(
                              'Salary',
                              _customLabourSalaryController,
                            ),
                            const SizedBox(height: 10),
                            _buildQtyField('Count', _customLabourQtyController),
                            const SizedBox(height: 12),
                            GlassButton(
                              label: 'ADD CUSTOM',
                              icon: Icons.check,
                              onPressed: _addCustomLabour,
                              isSecondary: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Other Expenses Card ───────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: darkCardBg,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: darkCardBg.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSectionHeader('Other Expenses'),
                          const SizedBox(height: 16),
                          _buildQtyField(
                            'Food (₹)',
                            foodCost,
                            icon: Icons.fastfood_rounded,
                          ),
                          const SizedBox(height: 12),
                          _buildQtyField(
                            'Transport (₹)',
                            transportCost,
                            icon: Icons.directions_car_rounded,
                          ),
                          const SizedBox(height: 12),
                          _buildQtyField(
                            'Fuel (₹)',
                            fuelCost,
                            icon: Icons.local_gas_station_rounded,
                          ),
                          const SizedBox(height: 16),
                          GlassButton(
                            label: 'ADD',
                            icon: Icons.add,
                            onPressed: () {
                              FocusScope.of(context).unfocus();
                              setState(() {});
                            },
                            isSecondary: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Today's Summary Card ──────────────────────────────────
                    if (materials.isNotEmpty ||
                        labours.isNotEmpty ||
                        (int.tryParse(foodCost.text) ?? 0) > 0 ||
                        (int.tryParse(transportCost.text) ?? 0) > 0 ||
                        (int.tryParse(fuelCost.text) ?? 0) > 0)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: darkCardBg,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: darkCardBg.withValues(alpha: 0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Today\'s Summary (Total: ₹${_getTotalAmount()})',
                              style: const TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildSummaryTable(),
                          ],
                        ),
                      ),
                    if (materials.isNotEmpty ||
                        labours.isNotEmpty ||
                        (int.tryParse(foodCost.text) ?? 0) > 0 ||
                        (int.tryParse(transportCost.text) ?? 0) > 0 ||
                        (int.tryParse(fuelCost.text) ?? 0) > 0)
                      const SizedBox(height: 20),

                    // ── Bottom Save & Reset Actions ───────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: darkCardBg,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: darkCardBg.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: isSaving
                                    ? null
                                    : (isUpdateMode
                                        ? _updateExistingEntry
                                        : _showConfirmationDialog),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: const Color(0xFF0A183D),
                                  disabledBackgroundColor:
                                      Colors.white.withValues(alpha: 0.15),
                                  disabledForegroundColor:
                                      Colors.white.withValues(alpha: 0.45),
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 6,
                                  shadowColor:
                                      primaryColor.withValues(alpha: 0.4),
                                ),
                                child: isSaving
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            Color(0xFF0A183D),
                                          ),
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            isUpdateMode
                                                ? Icons.update_rounded
                                                : Icons.save_rounded,
                                            size: 20,
                                            color: const Color(0xFF0A183D),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            isUpdateMode ? 'UPDATE' : 'SAVE',
                                            style: const TextStyle(
                                              color: Color(0xFF0A183D),
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _resetForm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.15),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                                elevation: 0,
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.refresh_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'RESET',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── HELPER BUILDERS ───────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 18,
        color: isDark ? Colors.white : const Color(0xFF0A183D),
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: isDark ? AppTheme.getCardAccent(primaryColor) : primaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
              fontSize: 13.5,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0A183D),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialDropdown() {
    final brandIconColor = AppTheme.getDarkAccent(primaryColor);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: selectedMaterial,
        isExpanded: true,
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(16),
        style: const TextStyle(
          color: Color(0xFF0A183D),
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: 'Select Material',
          hintStyle: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(
              Icons.category_rounded,
              color: brandIconColor,
              size: 22,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        items: (_filteredMaterialOptions ?? materialOptions)
            .map(
              (item) => DropdownMenuItem(
                value: item,
                child: Text(
                  item,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: (value) => setState(() => selectedMaterial = value),
      ),
    );
  }

  Widget _buildLabourDropdown() {
    final brandIconColor = AppTheme.getDarkAccent(primaryColor);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: selectedLabour,
        isExpanded: true,
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(16),
        style: const TextStyle(
          color: Color(0xFF0A183D),
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: 'Select Labour',
          hintStyle: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(
              Icons.engineering_rounded,
              color: brandIconColor,
              size: 22,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        items: labourOptions
            .map(
              (l) => DropdownMenuItem(
                value: l,
                child: Text(l, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: (v) => setState(() => selectedLabour = v),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController? ctrl, {
    String? hintText,
    IconData? icon,
    ValueChanged<String>? onChanged,
  }) {
    final brandIconColor = AppTheme.getDarkAccent(primaryColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: ctrl,
            onChanged: onChanged,
            style: const TextStyle(
              color: Color(0xFF0A183D),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: hintText ?? 'Enter $label',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: icon != null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(icon, color: brandIconColor, size: 22),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQtyField(
    String label,
    TextEditingController ctrl, {
    IconData? icon,
    ValueChanged<String>? onChanged,
  }) {
    final brandIconColor = AppTheme.getDarkAccent(primaryColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            onChanged: onChanged,
            style: const TextStyle(
              color: Color(0xFF0A183D),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: icon != null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(icon, color: brandIconColor, size: 22),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 20,
        headingRowColor: WidgetStateProperty.all(
          Colors.white.withValues(alpha: 0.1),
        ),
        columns: const [
          DataColumn(
            label: Text(
              'Item',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'Qty',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'Amt',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          DataColumn(label: Text('')),
        ],
        rows: [
          ...materials.asMap().entries.map(
            (e) => DataRow(
              cells: [
                DataCell(Text(
                  e.value['type'],
                  style: const TextStyle(color: Colors.white),
                )),
                DataCell(Text(
                  '${e.value['quantity']}',
                  style: const TextStyle(color: Colors.white),
                )),
                DataCell(
                  Text(
                    _calculateMaterialAmount(
                      e.value['type'],
                      e.value['quantity'],
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                DataCell(
                  IconButton(
                    icon: const Icon(
                      Icons.delete_rounded,
                      color: Color(0xFFF87171),
                      size: 18,
                    ),
                    onPressed: () => _removeMaterial(e.key),
                  ),
                ),
              ],
            ),
          ),
          ...labours.asMap().entries.map(
            (e) => DataRow(
              cells: [
                DataCell(Text(
                  e.value['type'],
                  style: const TextStyle(color: Colors.white),
                )),
                DataCell(Text(
                  '${e.value['count']}',
                  style: const TextStyle(color: Colors.white),
                )),
                DataCell(
                  Text(
                    _calculateLabourAmount(e.value['type'], e.value['count']),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                DataCell(
                  IconButton(
                    icon: const Icon(
                      Icons.delete_rounded,
                      color: Color(0xFFF87171),
                      size: 18,
                    ),
                    onPressed: () => _removeLabour(e.key),
                  ),
                ),
              ],
            ),
          ),
          if ((int.tryParse(foodCost.text) ?? 0) > 0)
            DataRow(
              cells: [
                const DataCell(Text(
                  'Food',
                  style: TextStyle(color: Colors.white),
                )),
                const DataCell(Text(
                  '-',
                  style: TextStyle(color: Colors.white),
                )),
                DataCell(Text(
                  '₹${foodCost.text}',
                  style: const TextStyle(color: Colors.white),
                )),
                DataCell(
                  IconButton(
                    icon: const Icon(
                      Icons.delete_rounded,
                      color: Color(0xFFF87171),
                      size: 18,
                    ),
                    onPressed: () => setState(() => foodCost.text = '0'),
                  ),
                ),
              ],
            ),
          if ((int.tryParse(transportCost.text) ?? 0) > 0)
            DataRow(
              cells: [
                const DataCell(Text(
                  'Transport',
                  style: TextStyle(color: Colors.white),
                )),
                const DataCell(Text(
                  '-',
                  style: TextStyle(color: Colors.white),
                )),
                DataCell(Text(
                  '₹${transportCost.text}',
                  style: const TextStyle(color: Colors.white),
                )),
                DataCell(
                  IconButton(
                    icon: const Icon(
                      Icons.delete_rounded,
                      color: Color(0xFFF87171),
                      size: 18,
                    ),
                    onPressed: () => setState(() => transportCost.text = '0'),
                  ),
                ),
              ],
            ),
          if ((int.tryParse(fuelCost.text) ?? 0) > 0)
            DataRow(
              cells: [
                const DataCell(Text(
                  'Fuel',
                  style: TextStyle(color: Colors.white),
                )),
                const DataCell(Text(
                  '-',
                  style: TextStyle(color: Colors.white),
                )),
                DataCell(Text(
                  '₹${fuelCost.text}',
                  style: const TextStyle(color: Colors.white),
                )),
                DataCell(
                  IconButton(
                    icon: const Icon(
                      Icons.delete_rounded,
                      color: Color(0xFFF87171),
                      size: 18,
                    ),
                    onPressed: () => setState(() => fuelCost.text = '0'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
