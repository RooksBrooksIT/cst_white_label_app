import 'package:flutter/material.dart';
import '/services/firestore_service.dart';
import '/services/expense_service.dart';
import 'package:intl/intl.dart';
import '/utils/app_theme.dart';

class OrganizationSiteEntry extends StatefulWidget {
  final String userName;
  final Map<String, dynamic> userDetails;
  const OrganizationSiteEntry({
    super.key,
    required this.userName,
    required this.userDetails,
  });

  @override
  State<OrganizationSiteEntry> createState() => _OrganizationSiteEntryState();
}

class _OrganizationSiteEntryState extends State<OrganizationSiteEntry> {
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

  Color get primaryColor => Theme.of(context).colorScheme.primary;

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
    _customMaterialNameController.dispose();
    _customMaterialQtyController.dispose();
    _customMaterialPriceController.dispose();
    _customLabourNameController.dispose();
    _customLabourSalaryController.dispose();
    super.dispose();
  }

  Future<void> _fetchSites() async {
    setState(() {
      isLoadingSites = true;
    });
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
      debugPrint('Error fetching sites: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoadingSites = false;
        });
      }
    }
  }

  void _onSiteSelected(String siteId) {
    final site = siteList.firstWhere(
      (s) => s['siteId'] == siteId,
      orElse: () => {
        'siteId': '',
        'supervisor': '',
        'supervisorId': '',
        'location': '',
        'projectStage': '',
      },
    );
    setState(() {
      selectedSiteId = siteId;
      supervisorName = site['supervisor'];
      supervisorId = site['supervisorId'];
      siteLocation = site['location'];
      projectStage = site['projectStage'];
      siteCode = siteId;
    });
  }

  Future<void> _fetchMaterialOptions() async {
    try {
      final snapshot = await FirestoreService.getCollection('materials').get();
      List<String> options = [];
      Map<String, num> prices = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final name = data['materialName'] as String?;
        final price = data['unitPrice'] as num?;
        if (name != null && name.isNotEmpty) {
          options.add(name);
          if (price != null) {
            prices[name] = price;
          }
        }
      }
      setState(() {
        materialOptions = options;
        materialPrices = prices;
        isLoadingMaterials = false;
      });
    } catch (e) {
      setState(() {
        materialError = 'Failed to load materials';
        isLoadingMaterials = false;
      });
    }
  }

  Future<void> _fetchLabourOptions() async {
    try {
      final snapshot = await FirestoreService.getCollection('labours').get();
      List<String> options = [];
      Map<String, num> salaries = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final designation = data['designationName'] as String?;
        final salary = data['salary'] as num?;
        if (designation != null && designation.isNotEmpty) {
          options.add(designation);
          if (salary != null) {
            salaries[designation] = salary;
          }
        }
      }
      setState(() {
        labourOptions = options;
        labourSalaries = salaries;
        isLoadingLabours = false;
      });
    } catch (e) {
      setState(() {
        labourError = 'Failed to load labours';
        isLoadingLabours = false;
      });
    }
  }

  void _addMaterial() {
    if (selectedMaterial != null && materialQty > 0) {
      setState(() {
        materials.add({'type': selectedMaterial, 'quantity': materialQty});
        selectedMaterial = null;
        materialQty = 0;
        materialQtyController.text = '0';
      });
    }
  }

  void _addLabour() {
    if (selectedLabour != null && labourQty > 0) {
      setState(() {
        labours.add({'type': selectedLabour, 'count': labourQty});
        selectedLabour = null;
        labourQty = 0;
        labourQtyController.text = '0';
      });
    }
  }

  void _addCustomMaterial() {
    final name = _customMaterialNameController.text.trim();
    final qty = int.tryParse(_customMaterialQtyController.text) ?? 0;
    final price = num.tryParse(_customMaterialPriceController.text) ?? 0;

    if (name.isNotEmpty && qty > 0) {
      setState(() {
        if (!materialOptions.contains(name)) {
          materialOptions.add(name);
        }
        materialPrices[name] = price;

        materials.add({'type': name, 'quantity': qty});

        _customMaterialNameController.clear();
        _customMaterialQtyController.text = '0';
        _customMaterialPriceController.text = '0';
        _showCustomMaterialFields = false;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a valid material name and quantity greater than 0',
          ),
        ),
      );
    }
  }

  void _addCustomLabour() {
    final name = _customLabourNameController.text.trim();
    final salary = num.tryParse(_customLabourSalaryController.text) ?? 0;
    final count = int.tryParse(labourQtyController.text) ?? 1;

    if (name.isNotEmpty) {
      setState(() {
        if (!labourOptions.contains(name)) {
          labourOptions.add(name);
        }
        labourSalaries[name] = salary;

        labours.add({'type': name, 'count': count > 0 ? count : 1});

        _customLabourNameController.clear();
        _customLabourSalaryController.text = '0';
        labourQtyController.text = '0';
        labourQty = 0;
        _showCustomLabourFields = false;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid designation name'),
        ),
      );
    }
  }

  void _removeMaterial(int index) {
    setState(() {
      materials.removeAt(index);
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
      final price = materialPrices[m['type']] ?? 0;
      final qty = m['quantity'] ?? 0;
      total += price * qty;
    }
    for (var l in labours) {
      final salary = labourSalaries[l['type']] ?? 0;
      final count = l['count'] ?? 0;
      total += salary * count;
    }
    total += num.tryParse(foodCost.text) ?? 0;
    total += num.tryParse(transportCost.text) ?? 0;
    total += num.tryParse(fuelCost.text) ?? 0;
    return total;
  }

  String _calculateMaterialAmount(String type, int qty) {
    final price = materialPrices[type] ?? 0;
    return '₹${price * qty}';
  }

  String _calculateLabourAmount(String type, int count) {
    final salary = labourSalaries[type] ?? 0;
    return '₹${salary * count}';
  }

  void _resetForm() {
    setState(() {
      materials.clear();
      labours.clear();
      selectedMaterial = null;
      materialQty = 0;
      materialQtyController.text = '0';
      selectedLabour = null;
      labourQty = 0;
      labourQtyController.text = '0';
      foodCost.text = '0';
      transportCost.text = '0';
      fuelCost.text = '0';
      selectedDate = DateTime.now();
      _showCustomMaterialFields = false;
      _showCustomLabourFields = false;
      _customMaterialNameController.clear();
      _customMaterialQtyController.text = '0';
      _customMaterialPriceController.text = '0';
      _customLabourNameController.clear();
      _customLabourSalaryController.text = '0';
    });
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: const Color(0xFF0A183D),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  void _showConfirmationDialog() {
    if (selectedSiteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a site first.')),
      );
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Confirm Submission',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0A183D)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Site ID: $siteCode', style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569))),
            Text(
              'Date: ${selectedDate != null ? DateFormat('dd/MM/yyyy').format(selectedDate!) : 'Not set'}',
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569)),
            ),
            Text('Total Amount: ₹${_getTotalAmount()}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0A183D))),
            const SizedBox(height: 12),
            const Text(
              'Are you sure you want to save this daily site entry?',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0A183D)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _saveEntry();
            },
            child: const Text('Submit', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveEntry() async {
    if (selectedSiteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a site first.')),
      );
      return;
    }
    setState(() {
      isSaving = true;
    });
    final dateStr = selectedDate != null
        ? DateFormat('ddMMyyyy').format(selectedDate!)
        : DateFormat('ddMMyyyy').format(DateTime.now());
    final docId = '${siteCode}_$dateStr';

    final data = {
      "date": selectedDate != null
          ? DateFormat('yyyy-MM-dd').format(selectedDate!)
          : DateFormat('yyyy-MM-dd').format(DateTime.now()),
      "entryTime": DateFormat('HH:mm:ss').format(DateTime.now()),
      "food": int.tryParse(foodCost.text) ?? 0,
      "fuel": int.tryParse(fuelCost.text) ?? 0,
      "labours": labours
          .map(
            (l) => {
              "type": l['type'] ?? '',
              "count": l['count'] ?? 0,
              "salary": labourSalaries[l['type'] ?? ''] ?? 0,
              "amount":
                  (labourSalaries[l['type'] ?? ''] ?? 0) * (l['count'] ?? 0),
            },
          )
          .toList(),
      "materials": materials
          .map(
            (m) => {
              "type": m['type'] ?? '',
              "quantity": m['quantity'] ?? 0,
              "unitPrice": materialPrices[m['type'] ?? ''] ?? 0,
              "amount":
                  (materialPrices[m['type'] ?? ''] ?? 0) * (m['quantity'] ?? 0),
            },
          )
          .toList(),
      "Supervisor ID": supervisorId ?? 'Not Available',
      "transport": int.tryParse(transportCost.text) ?? 0,
      "totalAmount": _getTotalAmount(),
      "siteLocation": siteLocation,
      "siteId": siteCode,
      "supervisorName": supervisorName,
      "projectStage": projectStage,
      "isOrgEntry": true,
      "createdBy": "manager_org",
    };
    try {
      final existing = await FirestoreService.siteSupervisorEntries
          .doc(docId)
          .get();
      if (existing.exists) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'Duplicate Entry',
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0A183D)),
            ),
            content: const Text(
              'An entry for this site and date already exists.',
              style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        setState(() {
          isSaving = false;
        });
        return;
      }
      await FirestoreService.siteSupervisorEntries.doc(docId).set(data);
      await ExpenseService.updateTotalSiteExpense(siteCode);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Entry saved successfully!'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      _resetForm();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save entry: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    await _fetchSites();
    await _fetchMaterialOptions();
    await _fetchLabourOptions();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Refreshed site & material data!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Organiser Daily Site Entry',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
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
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
            onPressed: _refreshData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isMobile ? double.infinity : 750.0,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Banner Card
                  Container(
                    padding: const EdgeInsets.all(16),
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
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.edit_note_rounded,
                            color: primaryColor,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Organiser Daily Site Entry',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0A183D),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Log daily site materials, labor deployment & operational costs',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // SECTION 1: SITE & PROJECT DETAILS
                  _buildSectionHeader(
                    title: '1. Site & Project Details',
                    subtitle: 'Select site ID and view supervisor/location details',
                    icon: Icons.location_on_rounded,
                    color: primaryColor,
                  ),
                  const SizedBox(height: 16),
                  isLoadingSites
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Site ID *',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0A183D),
                              ),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: siteList.any((s) => s['siteId'] == selectedSiteId)
                                  ? selectedSiteId
                                  : null,
                              isExpanded: true,
                              dropdownColor: Colors.white,
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: Color(0xFF0A183D),
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: _inputDecoration('Select Site ID', Icons.construction_rounded),
                              items: siteList
                                  .map(
                                    (site) => DropdownMenuItem(
                                      value: site['siteId'],
                                      child: Text(
                                        '${site['siteId']} - ${site['siteName']}',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          color: Color(0xFF0A183D),
                                          fontWeight: FontWeight.w600,
                                        ),
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
                            const SizedBox(height: 14),
                          ],
                        ),

                  _buildInfoTile(Icons.person_rounded, 'Supervisor', '${supervisorName ?? '-'} (${supervisorId ?? '-'})'),
                  _buildInfoTile(Icons.location_on_rounded, 'Location', siteLocation ?? '-'),
                  _buildInfoTile(Icons.timeline_rounded, 'Project Stage', projectStage ?? '-'),

                  // Date Row
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Entry Date *',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A183D),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12.0),
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              color: primaryColor,
                              size: 20.0,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Date:',
                              style: TextStyle(
                                fontSize: 13.5,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              selectedDate != null
                                  ? DateFormat('dd MMM yyyy').format(selectedDate!)
                                  : 'No date chosen',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0A183D),
                              ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: _pickDate,
                              icon: Icon(Icons.edit_calendar_rounded, size: 16, color: primaryColor),
                              label: Text(
                                'Change',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const Divider(color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 16),

                  // SECTION 2: MATERIAL DETAILS
                  _buildSectionHeader(
                    title: '2. Material Details',
                    subtitle: 'Add site materials and set quantity',
                    icon: Icons.category_rounded,
                    color: Colors.indigo,
                  ),
                  const SizedBox(height: 16),
                  if (isLoadingMaterials)
                    const Center(child: CircularProgressIndicator())
                  else if (materialError != null)
                    Text(
                      materialError!,
                      style: const TextStyle(color: Colors.red),
                    )
                  else ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Material *',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A183D),
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: selectedMaterial,
                          isExpanded: true,
                          dropdownColor: Colors.white,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: Color(0xFF0A183D),
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: _inputDecoration('Select Material', Icons.category_outlined),
                          items: (_filteredMaterialOptions ?? materialOptions)
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(
                                    item,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF0A183D),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            setState(() {
                              selectedMaterial = val;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Material Quantity *',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A183D),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: materialQtyController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: Color(0xFF0A183D),
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: _inputDecoration('Quantity', Icons.production_quantity_limits_rounded),
                          onChanged: (val) {
                            setState(() {
                              materialQty = int.tryParse(val) ?? 0;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _addMaterial,
                              icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 20),
                              label: const Text(
                                'Add Material',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: () => setState(
                                () => _showCustomMaterialFields =
                                    !_showCustomMaterialFields,
                              ),
                              icon: const Icon(Icons.more_horiz_rounded, size: 20, color: Color(0xFF0A183D)),
                              label: Text(
                                _showCustomMaterialFields ? 'Hide Custom' : 'Custom Material',
                                style: const TextStyle(color: Color(0xFF0A183D), fontWeight: FontWeight.bold, fontSize: 13.5),
                              ),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (_showCustomMaterialFields) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Add Custom Material',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF0A183D),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _customMaterialNameController,
                            style: const TextStyle(fontSize: 13.5, color: Color(0xFF0A183D), fontWeight: FontWeight.w600),
                            decoration: _inputDecoration('Material Name', Icons.edit_note_rounded),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _customMaterialQtyController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 13.5, color: Color(0xFF0A183D), fontWeight: FontWeight.w600),
                                  decoration: _inputDecoration('Qty', Icons.numbers_rounded),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _customMaterialPriceController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 13.5, color: Color(0xFF0A183D), fontWeight: FontWeight.w600),
                                  decoration: _inputDecoration('Unit Price (₹)', Icons.currency_rupee_rounded),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton.icon(
                              onPressed: _addCustomMaterial,
                              icon: const Icon(Icons.playlist_add_rounded, color: Colors.white, size: 18),
                              label: const Text('Add Custom Material', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  const Divider(color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 16),

                  // SECTION 3: LABOUR DETAILS
                  _buildSectionHeader(
                    title: '3. Labour Details',
                    subtitle: 'Assign labour designations and head counts',
                    icon: Icons.engineering_rounded,
                    color: Colors.teal,
                  ),
                  const SizedBox(height: 16),
                  if (isLoadingLabours)
                    const Center(child: CircularProgressIndicator())
                  else if (labourError != null)
                    Text(
                      labourError!,
                      style: const TextStyle(color: Colors.red),
                    )
                  else ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Labour Designation *',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A183D),
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: selectedLabour,
                          isExpanded: true,
                          dropdownColor: Colors.white,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: Color(0xFF0A183D),
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: _inputDecoration('Select Labour Designation', Icons.work_outline_rounded),
                          items: (_filteredLabourOptions ?? labourOptions)
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(
                                    item,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF0A183D),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            setState(() {
                              selectedLabour = val;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Labour Count *',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A183D),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: labourQtyController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: Color(0xFF0A183D),
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: _inputDecoration('Count', Icons.groups_rounded),
                          onChanged: (val) {
                            setState(() {
                              labourQty = int.tryParse(val) ?? 0;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _addLabour,
                              icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 20),
                              label: const Text(
                                'Add Labour',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: () => setState(
                                () => _showCustomLabourFields =
                                    !_showCustomLabourFields,
                              ),
                              icon: const Icon(Icons.more_horiz_rounded, size: 20, color: Color(0xFF0A183D)),
                              label: Text(
                                _showCustomLabourFields ? 'Hide Custom' : 'Custom Labour',
                                style: const TextStyle(color: Color(0xFF0A183D), fontWeight: FontWeight.bold, fontSize: 13.5),
                              ),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (_showCustomLabourFields) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Add Custom Labour Designation',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF0A183D),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _customLabourNameController,
                            style: const TextStyle(fontSize: 13.5, color: Color(0xFF0A183D), fontWeight: FontWeight.w600),
                            decoration: _inputDecoration('Designation Name', Icons.badge_rounded),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _customLabourSalaryController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 13.5, color: Color(0xFF0A183D), fontWeight: FontWeight.w600),
                            decoration: _inputDecoration('Daily Salary (₹)', Icons.currency_rupee_rounded),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton.icon(
                              onPressed: _addCustomLabour,
                              icon: const Icon(Icons.playlist_add_rounded, color: Colors.white, size: 18),
                              label: const Text('Add Custom Labour', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  const Divider(color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 16),

                  // SECTION 4: OPERATIONAL COSTS
                  _buildSectionHeader(
                    title: '4. Operational Costs',
                    subtitle: 'Enter food, transport and fuel expenditures',
                    icon: Icons.account_balance_wallet_rounded,
                    color: Colors.amber.shade800,
                  ),
                  const SizedBox(height: 16),
                  _buildCostInput('Food Cost', foodCost, Icons.restaurant_rounded),
                  _buildCostInput('Transport Cost', transportCost, Icons.local_shipping_rounded),
                  _buildCostInput('Fuel Cost', fuelCost, Icons.local_gas_station_rounded),

                  const SizedBox(height: 24),
                  const Divider(color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 16),

                  // SECTION 5: DAILY SUMMARY OVERVIEW
                  if (materials.isNotEmpty || labours.isNotEmpty) ...[
                    _buildSectionHeader(
                      title: '5. Entry Summary Overview',
                      subtitle: 'Review materials, labour and expenses before submission',
                      icon: Icons.list_alt_rounded,
                      color: primaryColor,
                    ),
                    const SizedBox(height: 16),
                    _buildSummaryTable(),
                    const SizedBox(height: 28),
                  ],

                  // ACTION BUTTONS ROW
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 3.0,
                              shadowColor: primaryColor.withValues(alpha: 0.35),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14.0),
                              ),
                            ),
                            onPressed: isSaving ? null : _showConfirmationDialog,
                            icon: const Icon(Icons.check_circle_rounded, size: 20),
                            label: isSaving
                                ? const SizedBox(
                                    width: 22.0,
                                    height: 22.0,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'Save Daily Entry',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15.0,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 50,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF0A183D),
                              side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14.0),
                              ),
                            ),
                            onPressed: isSaving ? null : _resetForm,
                            icon: const Icon(Icons.restart_alt_rounded, size: 18, color: Color(0xFF64748B)),
                            label: const Text(
                              'Reset',
                              style: TextStyle(
                                color: Color(0xFF0A183D),
                                fontSize: 15.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A183D),
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: primaryColor),
            const SizedBox(width: 10),
            Text(
              '$label: ',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A183D),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostInput(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF0A183D),
            fontWeight: FontWeight.bold,
            fontSize: 12.5,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: const TextStyle(
            fontSize: 13.5,
            color: Color(0xFF0A183D),
            fontWeight: FontWeight.w600,
          ),
          decoration: _inputDecoration('Enter $label', icon),
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: Colors.grey.shade400,
        fontSize: 12.5,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Icon(icon, color: primaryColor, size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor, width: 1.8),
      ),
    );
  }

  Widget _buildSummaryTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width - 48,
          ),
          child: DataTable(
            columnSpacing: 16,
            horizontalMargin: 12,
            headingRowHeight: 44,
            dataRowMinHeight: 42,
            dataRowMaxHeight: 42,
            headingRowColor: WidgetStateProperty.all(
              primaryColor.withValues(alpha: 0.1),
            ),
            columns: const [
              DataColumn(
                label: SizedBox(
                  width: 80,
                  child: Text(
                    'Type',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0A183D)),
                  ),
                ),
              ),
              DataColumn(
                label: SizedBox(
                  width: 100,
                  child: Text(
                    'Item',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0A183D)),
                  ),
                ),
              ),
              DataColumn(
                label: SizedBox(
                  width: 60,
                  child: Text(
                    'Qty',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0A183D)),
                  ),
                ),
              ),
              DataColumn(
                label: SizedBox(
                  width: 100,
                  child: Text(
                    'Amount',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0A183D)),
                  ),
                ),
              ),
              DataColumn(label: SizedBox(width: 40)),
            ],
            rows: [
              ...materials.asMap().entries.map((entry) {
                int idx = entry.key;
                var m = entry.value;
                return DataRow(
                  cells: [
                    const DataCell(
                      SizedBox(
                        width: 80,
                        child: Text('Material', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 100,
                        child: Text(
                          m['type']?.toString() ?? '',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF0A183D), fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 60,
                        child: Text(
                          '${m['quantity'] ?? 0}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF0A183D)),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 100,
                        child: Text(
                          _calculateMaterialAmount(
                            m['type']?.toString() ?? '',
                            m['quantity'] ?? 0,
                          ),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF0A183D), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Color(0xFFEF4444),
                            size: 18,
                          ),
                          onPressed: () => _removeMaterial(idx),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                );
              }),
              ...labours.asMap().entries.map((entry) {
                int idx = entry.key;
                var l = entry.value;
                return DataRow(
                  cells: [
                    const DataCell(
                      SizedBox(
                        width: 80,
                        child: Text('Labour', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 100,
                        child: Text(
                          l['type']?.toString() ?? '',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF0A183D), fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 60,
                        child: Text(
                          '${l['count'] ?? 0}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF0A183D)),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 100,
                        child: Text(
                          _calculateLabourAmount(
                            l['type']?.toString() ?? '',
                            l['count'] ?? 0,
                          ),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF0A183D), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Color(0xFFEF4444),
                            size: 18,
                          ),
                          onPressed: () => _removeLabour(idx),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                );
              }),
              DataRow(
                cells: [
                  const DataCell(SizedBox(width: 80, child: Text('Food', style: TextStyle(fontSize: 12, color: Color(0xFF475569))))),
                  const DataCell(SizedBox(width: 100, child: Text('-', style: TextStyle(fontSize: 12, color: Color(0xFF475569))))),
                  const DataCell(SizedBox(width: 60, child: Text('-', style: TextStyle(fontSize: 12, color: Color(0xFF475569))))),
                  DataCell(SizedBox(width: 100, child: Text('₹${foodCost.text}', style: const TextStyle(fontSize: 12, color: Color(0xFF0A183D), fontWeight: FontWeight.bold)))),
                  const DataCell(SizedBox(width: 40)),
                ],
              ),
              DataRow(
                cells: [
                  const DataCell(SizedBox(width: 80, child: Text('Transport', style: TextStyle(fontSize: 12, color: Color(0xFF475569))))),
                  const DataCell(SizedBox(width: 100, child: Text('-', style: TextStyle(fontSize: 12, color: Color(0xFF475569))))),
                  const DataCell(SizedBox(width: 60, child: Text('-', style: TextStyle(fontSize: 12, color: Color(0xFF475569))))),
                  DataCell(SizedBox(width: 100, child: Text('₹${transportCost.text}', style: const TextStyle(fontSize: 12, color: Color(0xFF0A183D), fontWeight: FontWeight.bold)))),
                  const DataCell(SizedBox(width: 40)),
                ],
              ),
              DataRow(
                cells: [
                  const DataCell(SizedBox(width: 80, child: Text('Fuel', style: TextStyle(fontSize: 12, color: Color(0xFF475569))))),
                  const DataCell(SizedBox(width: 100, child: Text('-', style: TextStyle(fontSize: 12, color: Color(0xFF475569))))),
                  const DataCell(SizedBox(width: 60, child: Text('-', style: TextStyle(fontSize: 12, color: Color(0xFF475569))))),
                  DataCell(SizedBox(width: 100, child: Text('₹${fuelCost.text}', style: const TextStyle(fontSize: 12, color: Color(0xFF0A183D), fontWeight: FontWeight.bold)))),
                  const DataCell(SizedBox(width: 40)),
                ],
              ),
              DataRow(
                cells: [
                  const DataCell(SizedBox(width: 80, child: Text(''))),
                  const DataCell(SizedBox(width: 100, child: Text(''))),
                  const DataCell(
                    SizedBox(
                      width: 60,
                      child: Text(
                        'Total',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF0A183D),
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 100,
                      child: Text(
                        '₹${_getTotalAmount()}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ),
                  const DataCell(SizedBox(width: 40, child: Text(''))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
