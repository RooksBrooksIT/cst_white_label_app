import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/expense_service.dart';
import '../services/firestore_service.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_button.dart';
import 'supervisor_dashboard.dart';

class SiteContractorEntryPage extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;
  final String userName;
  final Map<String, dynamic> userDetails;

  const SiteContractorEntryPage({
    super.key,
    required this.supervisorId,
    required this.supervisorName,
    required this.userName,
    required this.userDetails,
  });

  @override
  State<SiteContractorEntryPage> createState() =>
      _SiteContractorEntryPageState();
}

class _SiteContractorEntryPageState extends State<SiteContractorEntryPage> {
  final _contractorNameController = TextEditingController();
  String? _selectedContractorName;
  String? _selectedProjectField;
  final TextEditingController _projectFieldController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

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
  String siteLocation = '';
  String? projectStage;
  List<Map<String, String>> supervisorSites = [];
  String? selectedSiteId;
  bool isSaving = false;

  Map<String, num> materialPrices = {};
  Map<String, num> labourSalaries = {};

  bool _showCustomMaterialFields = false;
  final _customMaterialNameController = TextEditingController();
  final _customMaterialQtyController = TextEditingController(text: '0');
  final _customMaterialPriceController = TextEditingController(text: '0');

  bool _showCustomLabourFields = false;
  final _customLabourNameController = TextEditingController();
  final _customLabourSalaryController = TextEditingController(text: '0');

  Color get primaryColor => Theme.of(context).primaryColor;

  @override
  void initState() {
    super.initState();
    supervisorId = widget.supervisorId;
    selectedSiteId = widget.supervisorId;
    siteCode = widget.supervisorId;
    _dateController.text = DateFormat('yyyy-MM-dd').format(selectedDate!);
    _fetchMaterialOptions();
    _fetchLabourOptions();
    _fetchSupervisorData();
  }

  @override
  void dispose() {
    _contractorNameController.dispose();
    _projectFieldController.dispose();
    _dateController.dispose();
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

  Future<void> _fetchSupervisorData() async {
    try {
      final snapshot = await FirestoreService.siteSupervisorMap
          .where('supervisor', isEqualTo: widget.userName)
          .get();
      if (snapshot.docs.isNotEmpty) {
        final sites = snapshot.docs
            .map((doc) {
              final data = doc.data();
              return {
                'siteId': data['site']?.toString() ?? '',
                'location': data['location']?.toString() ?? 'Unknown',
                'supervisorId': data['Supervisor ID']?.toString() ?? '',
                'projectName': data['projectName']?.toString() ?? '',
                'projectStage': data['projectStage']?.toString() ?? '',
              };
            })
            .where((site) => site['siteId']!.isNotEmpty)
            .toList();
        if (!mounted) return;
        setState(() {
          supervisorSites = sites;
          if (sites.isNotEmpty) {
            selectedSiteId = sites.first['siteId'];
            siteCode = sites.first['siteId']!;
            siteLocation = sites.first['location']!;
            supervisorId = sites.first['supervisorId']!;
            projectName = sites.first['projectName']!;
            projectStage = sites.first['projectStage']!;
          }
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _fetchMaterialOptions() async {
    if (!mounted) return;
    setState(() {
      isLoadingMaterials = true;
      materialError = null;
    });
    try {
      // 1. Fetch materialCategories to build a lookup map
      final categoriesSnapshot = await FirestoreService.getCollection(
        'materialCategories',
      ).get();
      final categoryMap = <String, String>{};
      for (var doc in categoriesSnapshot.docs) {
        final data = doc.data();
        final name = (data['matCategory'] ?? '').toString().trim();
        if (name.isNotEmpty) {
          categoryMap[doc.reference.path] = name;
          categoryMap[doc.id] = name;
        }
      }

      // 2. Fetch specific materials
      final snapshot = await FirestoreService.getCollection('materials').get();
      final options = <String>[];
      final prices = <String, num>{};
      for (var doc in snapshot.docs) {
        final data = doc.data();

        // Resolve materialCategory reference
        String? resolvedCategory;
        final catRef = data['materialCategory'];
        if (catRef is DocumentReference) {
          resolvedCategory = categoryMap[catRef.path] ?? categoryMap[catRef.id];
        } else if (catRef is String && catRef.isNotEmpty) {
          resolvedCategory =
              categoryMap[catRef] ?? categoryMap[catRef.split('/').last];
        }

        // Fallback if not resolved
        final name =
            (resolvedCategory ??
                    data['materialName'] ??
                    data['matCategory'] ??
                    '')
                .toString()
                .trim();
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
      if (mounted)
        setState(() {
          materialError = 'Failed to load materials';
          isLoadingMaterials = false;
        });
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
        if (data.containsKey('designation')) {
          final designation = data['designation']?.toString() ?? '';
          if (designation.isNotEmpty) {
            options.add(designation);
            final salaryRaw = data['salary'];
            num salary = 0;
            if (salaryRaw is num) {
              salary = salaryRaw;
            } else if (salaryRaw is String) {
              salary =
                  num.tryParse(salaryRaw.replaceAll(RegExp(r'[^\d.]'), '')) ??
                  0;
            }
            salaries[designation] = salary;
          }
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
      if (mounted)
        setState(() {
          labourError = 'Failed to load labours';
          isLoadingLabours = false;
        });
    }
  }

  void _addMaterial() {
    int qty = int.tryParse(materialQtyController.text) ?? 0;
    if (selectedMaterial != null && qty > 0) {
      setState(() {
        materials.add({'type': selectedMaterial!, 'quantity': qty});
        materialQtyController.text = '0';
      });
    }
  }

  void _addLabour() {
    int qty = int.tryParse(labourQtyController.text) ?? 0;
    if (selectedLabour != null && qty > 0) {
      setState(() {
        labours.add({'type': selectedLabour!, 'count': qty});
        labourQtyController.text = '0';
      });
    }
  }

  void _addCustomMaterial() {
    final name = _customMaterialNameController.text.trim();
    final qty = int.tryParse(_customMaterialQtyController.text) ?? 0;
    final price = int.tryParse(_customMaterialPriceController.text) ?? 0;
    if (name.isNotEmpty && qty > 0) {
      setState(() {
        materials.add({'type': name, 'quantity': qty});
        materialPrices[name] = price;
        _showCustomMaterialFields = false;
        _customMaterialNameController.clear();
        _customMaterialQtyController.text = '0';
        _customMaterialPriceController.text = '0';
      });
    }
  }

  void _addCustomLabour() {
    final name = _customLabourNameController.text.trim();
    final qty = int.tryParse(labourQtyController.text) ?? 0;
    final salary = int.tryParse(_customLabourSalaryController.text) ?? 0;
    if (name.isNotEmpty && qty > 0) {
      setState(() {
        labours.add({'type': name, 'count': qty});
        labourSalaries[name] = salary;
        _showCustomLabourFields = false;
        _customLabourNameController.clear();
        labourQtyController.text = '0';
        _customLabourSalaryController.text = '0';
      });
    }
  }

  void _removeMaterial(int index) {
    setState(() => materials.removeAt(index));
  }

  void _removeLabour(int index) {
    setState(() => labours.removeAt(index));
  }

  String _calculateMaterialAmount(String material, int qty) {
    final price = materialPrices[material] ?? 0;
    return '₹${(price * qty).toStringAsFixed(0)}';
  }

  String _calculateLabourAmount(String labour, int qty) {
    final salary = labourSalaries[labour] ?? 0;
    return '₹${(salary * qty).toStringAsFixed(0)}';
  }

  int _getTotalAmount() {
    int total = 0;
    for (var m in materials) {
      final price = materialPrices[m['type'] ?? ''] ?? 0;
      total += (price * (m['quantity'] ?? 0)).toInt();
    }
    for (var l in labours) {
      final salary = labourSalaries[l['type'] ?? ''] ?? 0;
      total += (salary * (l['count'] ?? 0)).toInt();
    }
    total += int.tryParse(foodCost.text) ?? 0;
    total += int.tryParse(transportCost.text) ?? 0;
    total += int.tryParse(fuelCost.text) ?? 0;
    return total;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        selectedDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _saveToFirestore() async {
    final siteIdForEntry = siteCode;

    if (_selectedContractorName == null ||
        _selectedContractorName!.isEmpty ||
        _selectedProjectField == null ||
        _selectedProjectField!.isEmpty ||
        selectedDate == null ||
        siteIdForEntry.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select contractor, project field, date and site ID'),
        ),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final laboursList = labours.map((l) {
        final type = (l['type'] ?? '').toString();
        final count = (l['count'] ?? 0) as int;
        final unitSalary = (labourSalaries[type] ?? 0);
        return {
          'amount': (unitSalary * count).toInt(),
          'count': count,
          'type': type,
          'unitSalary': unitSalary.toInt(),
        };
      }).toList();

      final materialsList = materials.map((m) {
        final type = (m['type'] ?? '').toString();
        final qty = (m['quantity'] ?? 0) as int;
        final unitPrice = (materialPrices[type] ?? 0);
        return {
          'amount': (unitPrice * qty).toInt(),
          'quantity': qty,
          'type': type,
          'unitPrice': unitPrice.toInt(),
        };
      }).toList();

      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate!);
      final contractorNameForId = _selectedContractorName!.trim().replaceAll(
        RegExp(r'[^A-Za-z0-9_-]'),
        '-',
      );
      final docId = '${contractorNameForId}_$dateStr';

      final data = {
        'contractorName': _selectedContractorName,
        'projectField': _selectedProjectField ?? '',
        'date': dateStr,
        'food': int.tryParse(foodCost.text) ?? 0,
        'fuel': int.tryParse(fuelCost.text) ?? 0,
        'labours': laboursList,
        'materials': materialsList,
        'totalAmount': _getTotalAmount(),
        'transport': int.tryParse(transportCost.text) ?? 0,
        'siteId': siteIdForEntry,
      };

      await FirestoreService.contractorEntries.doc(docId).set(data);
      await ExpenseService.recalcTotalsAndSyncProject(siteIdForEntry);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Contractor entry saved')));
      _resetForm();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  void _resetForm() {
    setState(() {
      materials.clear();
      labours.clear();
      _selectedContractorName = null;
      _selectedProjectField = null;
      _projectFieldController.clear();
      _contractorNameController.clear();
      foodCost.text = '0';
      transportCost.text = '0';
      fuelCost.text = '0';
    });
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Contractor Entry',
      onBack: () => Navigator.pop(context),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.white),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => SupervisorDashboard(
                  username: widget.userName,
                  supervisorId: '',
                  supervisorName: '',
                ),
              ),
              (route) => false,
            );
          },
        ),
      ],
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
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
                    GlassCard(
                      title: 'Contractor Selection',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow(
                            'Site ID',
                            siteCode,
                            Icons.construction,
                          ),
                          _buildInfoRow(
                            'Supervisor',
                            widget.supervisorName,
                            Icons.person,
                          ),
                          const SizedBox(height: 16),
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: FirestoreService.contractors
                                .orderBy('contractorName')
                                .snapshots(),
                            builder: (context, snapshot) {
                              final docs = snapshot.data?.docs ?? [];
                              final names = <String>[];
                              final fieldByName = <String, String>{};
                              for (final d in docs) {
                                final data = d.data();
                                final name = (data['contractorName'] ?? '')
                                    .toString();
                                if (name.isNotEmpty) {
                                  names.add(name);
                                  fieldByName[name] =
                                      (data['contractorField'] ?? '')
                                          .toString();
                                }
                              }
                              return DropdownButtonFormField<String>(
                                value: names.contains(_selectedContractorName)
                                    ? _selectedContractorName
                                    : null,
                                decoration: const InputDecoration(
                                  labelText: 'Select Contractor',
                                  border: OutlineInputBorder(),
                                ),
                                items: names
                                    .map(
                                      (n) => DropdownMenuItem(
                                        value: n,
                                        child: Text(n),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) => setState(() {
                                  _selectedContractorName = val;
                                  _selectedProjectField = val != null
                                      ? fieldByName[val]
                                      : null;
                                  _projectFieldController.text =
                                      _selectedProjectField ?? '';
                                }),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            'Project Field',
                            _projectFieldController,
                            readOnly: true,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            'Date',
                            _dateController,
                            readOnly: true,
                            onTap: _pickDate,
                            icon: Icons.calendar_today,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    GlassCard(
                      title: 'Material Details',
                      child: Column(
                        children: [
                          isLoadingMaterials
                              ? const CircularProgressIndicator()
                              : DropdownButtonFormField<String>(
                                  value: selectedMaterial,
                                  decoration: const InputDecoration(
                                    labelText: 'Select Material',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: materialOptions
                                      .map(
                                        (m) => DropdownMenuItem(
                                          value: m,
                                          child: Text(m),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => selectedMaterial = v),
                                ),
                          const SizedBox(height: 12),
                          _buildQtyField('Quantity', materialQtyController),
                          const SizedBox(height: 12),
                          GlassButton(
                            label: 'ADD MATERIAL',
                            icon: Icons.add,
                            onPressed: _addMaterial,
                            isSecondary: true,
                          ),
                          TextButton(
                            onPressed: () => setState(
                              () => _showCustomMaterialFields =
                                  !_showCustomMaterialFields,
                            ),
                            child: Text(
                              _showCustomMaterialFields
                                  ? 'Hide Custom'
                                  : 'Add Custom Material',
                            ),
                          ),
                          if (_showCustomMaterialFields) ...[
                            _buildTextField(
                              'Material Name',
                              _customMaterialNameController,
                            ),
                            const SizedBox(height: 8),
                            _buildQtyField('Qty', _customMaterialQtyController),
                            const SizedBox(height: 8),
                            _buildQtyField(
                              'Price',
                              _customMaterialPriceController,
                            ),
                            const SizedBox(height: 8),
                            GlassButton(
                              label: 'ADD CUSTOM',
                              icon: Icons.check,
                              onPressed: _addCustomMaterial,
                              isSecondary: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    GlassCard(
                      title: 'Labour Details',
                      child: Column(
                        children: [
                          isLoadingLabours
                              ? const CircularProgressIndicator()
                              : DropdownButtonFormField<String>(
                                  value: selectedLabour,
                                  decoration: const InputDecoration(
                                    labelText: 'Select Labour',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: labourOptions
                                      .map(
                                        (l) => DropdownMenuItem(
                                          value: l,
                                          child: Text(l),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => selectedLabour = v),
                                ),
                          const SizedBox(height: 12),
                          _buildQtyField('Count', labourQtyController),
                          const SizedBox(height: 12),
                          GlassButton(
                            label: 'ADD LABOUR',
                            icon: Icons.person_add,
                            onPressed: _addLabour,
                            isSecondary: true,
                          ),
                          TextButton(
                            onPressed: () => setState(
                              () => _showCustomLabourFields =
                                  !_showCustomLabourFields,
                            ),
                            child: Text(
                              _showCustomLabourFields
                                  ? 'Hide Custom'
                                  : 'Add Custom Labour',
                            ),
                          ),
                          if (_showCustomLabourFields) ...[
                            _buildTextField(
                              'Labour Type',
                              _customLabourNameController,
                            ),
                            const SizedBox(height: 8),
                            _buildQtyField(
                              'Salary',
                              _customLabourSalaryController,
                            ),
                            const SizedBox(height: 8),
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
                    const SizedBox(height: 24),

                    GlassCard(
                      title: 'Other Expenses',
                      child: Column(
                        children: [
                          _buildQtyField(
                            'Food (₹)',
                            foodCost,
                            icon: Icons.fastfood,
                          ),
                          const SizedBox(height: 8),
                          _buildQtyField(
                            'Transport (₹)',
                            transportCost,
                            icon: Icons.directions_car,
                          ),
                          const SizedBox(height: 8),
                          _buildQtyField(
                            'Fuel (₹)',
                            fuelCost,
                            icon: Icons.local_gas_station,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (materials.isNotEmpty || labours.isNotEmpty)
                      GlassCard(
                        title:
                            'Today\'s Summary (Total: ₹${_getTotalAmount()})',
                        child: _buildSummaryTable(),
                      ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: GlassButton(
                            label: 'SAVE ENTRY',
                            icon: Icons.save,
                            onPressed: _saveToFirestore,
                            isLoading: isSaving,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GlassButton(
                            label: 'RESET',
                            icon: Icons.refresh,
                            onPressed: _resetForm,
                            isSecondary: true,
                          ),
                        ),
                      ],
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

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: primaryColor),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController ctrl, {
    bool readOnly = false,
    VoidCallback? onTap,
    IconData? icon,
  }) {
    return TextField(
      controller: ctrl,
      readOnly: readOnly,
      onTap: onTap,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        suffixIcon: icon != null ? Icon(icon, color: primaryColor) : null,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildQtyField(
    String label,
    TextEditingController ctrl, {
    IconData? icon,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: icon != null ? Icon(icon, color: primaryColor) : null,
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildSummaryTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 20,
        columns: const [
          DataColumn(
            label: Text('Item', style: TextStyle(color: Colors.white70)),
          ),
          DataColumn(
            label: Text('Qty', style: TextStyle(color: Colors.white70)),
          ),
          DataColumn(
            label: Text('Amt', style: TextStyle(color: Colors.white70)),
          ),
          DataColumn(
            label: Text('', style: TextStyle(color: Colors.white70)),
          ),
        ],
        rows: [
          ...materials.asMap().entries.map(
            (e) => DataRow(
              cells: [
                DataCell(
                  Text(
                    e.value['type'],
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                DataCell(
                  Text(
                    '${e.value['quantity']}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
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
                      Icons.delete,
                      color: Colors.redAccent,
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
                DataCell(
                  Text(
                    e.value['type'],
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                DataCell(
                  Text(
                    '${e.value['count']}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                DataCell(
                  Text(
                    _calculateLabourAmount(e.value['type'], e.value['count']),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                DataCell(
                  IconButton(
                    icon: const Icon(
                      Icons.delete,
                      color: Colors.redAccent,
                      size: 18,
                    ),
                    onPressed: () => _removeLabour(e.key),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
