import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/expense_service.dart';
import 'package:demo_cst/services/firestore_service.dart';

class ContractorEntryPage extends StatefulWidget {
  final String userName;
  final Map<String, dynamic> userDetails;

  const ContractorEntryPage({
    super.key,
    required this.userName,
    required this.userDetails,
  });

  @override
  State<ContractorEntryPage> createState() => _ContractorEntryPageState();
}

class _ContractorEntryPageState extends State<ContractorEntryPage> {
  // --- Color Configuration and Utilities ---
  // Professional slate colors
  final Color _primaryColor = const Color(0xFF0b3470);
  final Color _textColor = const Color(0xFF1E293B);
  final Color _labelColor = const Color(0xFF64748B);
  final Color _borderColor = const Color(0xFFE2E8F0);
  final Color _secondaryColor = const Color(0xFF94A3B8); // Standard secondary slate
  final Color _sectionBgColor = const Color(0xFFF8FAFC); // Main background
  final Color _actionTextColor = Colors.white; // Text on primary background
  final Color _successColor = const Color(0xFF10B981);
  final Color _errorColor = const Color(0xFFEF4444);

  double getPad(double w) {
    if (w < 400) return 8;
    if (w < 600) return 12;
    return 24;
  }

  String _formatDate(dynamic date) {
    if (date == null || date.toString().isEmpty) return '';
    if (date is DateTime) {
      return DateFormat('dd/MM/yyyy').format(date);
    }
    if (date.runtimeType.toString() == 'Timestamp' && date.toDate != null) {
      return DateFormat('dd/MM/yyyy').format(date.toDate());
    }
    try {
      final dt = DateTime.parse(date.toString());
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {
      return date.toString();
    }
  }

  final _contractorNameController = TextEditingController();
  String? _selectedContractorName;
  String? _selectedProjectField;
  final TextEditingController _projectFieldController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  List<String> siteIdOptions = [];
  String? selectedSiteIdForEntry;
  bool isLoadingSiteIds = true;
  String? siteIdError;
  dynamic contractStartDate;
  dynamic contractEndDate;

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

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('yyyy-MM-dd').format(selectedDate!);
    final prefillName = widget.userDetails['contractorName'] as String?;
    final prefillField = widget.userDetails['contractorField'] as String?;
    if (prefillName != null && prefillName.isNotEmpty) {
      _selectedContractorName = prefillName;
      _contractorNameController.text = prefillName;
    }
    if (prefillField != null && prefillField.isNotEmpty) {
      _selectedProjectField = prefillField;
      _projectFieldController.text = prefillField;
    }
    _fetchMaterialOptions();
    _fetchLabourOptions();
    _fetchSiteIds();
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

  // --- Data fetching as in your logic, no change ---

  Future<void> _fetchSiteIds() async {
    setState(() {
      isLoadingSiteIds = true;
      siteIdError = null;
    });
    try {
      final contractor =
          _selectedContractorName ?? widget.userDetails['contractorName'];
      final snapshot = await FirebaseFirestore.instance
          .collection('projects')
          .where('isContractWork', isEqualTo: true)
          .where('contractorName', isEqualTo: contractor)
          .get();
      final ids = <String>[];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final id = data['siteId']?.toString() ?? '';
        if (id.isNotEmpty) ids.add(id);
      }
      setState(() {
        siteIdOptions = ids;
        selectedSiteIdForEntry =
            siteIdOptions.isNotEmpty ? siteIdOptions.first : null;
        isLoadingSiteIds = false;
      });
      if (siteIdOptions.isNotEmpty) {
        await _fetchContractDates(siteIdOptions.first);
      } else {
        setState(() {
          contractStartDate = null;
          contractEndDate = null;
        });
      }
    } catch (e) {
      setState(() {
        siteIdError = 'Failed to load Site IDs';
        isLoadingSiteIds = false;
      });
    }
  }

  Future<void> _fetchContractDates(String? siteId) async {
    if (siteId == null || siteId.isEmpty) {
      setState(() {
        contractStartDate = null;
        contractEndDate = null;
      });
      return;
    }
    try {
      final contractor =
          _selectedContractorName ?? widget.userDetails['contractorName'];
      final query = await FirebaseFirestore.instance
          .collection('projects')
          .where('siteId', isEqualTo: siteId)
          .where('contractorName', isEqualTo: contractor)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        setState(() {
          contractStartDate = data['contractStartDate'];
          contractEndDate = data['contractEndDate'];
        });
      } else {
        setState(() {
          contractStartDate = null;
          contractEndDate = null;
        });
      }
    } catch (e) {
      setState(() {
        contractStartDate = null;
        contractEndDate = null;
      });
    }
  }

  Future<void> _fetchMaterialOptions() async {
    setState(() {
      isLoadingMaterials = true;
      materialError = null;
    });
    try {
      final snapshot =
          await FirestoreService.getCollection('materials').get();
      final options = <String>[];
      final prices = <String, num>{};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data.containsKey('materialName')) {
          final name = data['materialName']?.toString() ?? '';
          if (name.isNotEmpty) {
            options.add(name);
            var priceRaw = data['materialPrice'];
            num price = 0;
            if (priceRaw is num) {
              price = priceRaw;
            } else if (priceRaw is String)
              price =
                  num.tryParse(priceRaw.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
            prices[name] = price;
          }
        }
      }
      setState(() {
        materialOptions = options;
        materialPrices = prices;
        selectedMaterial =
            materialOptions.isNotEmpty ? materialOptions.first : null;
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
    setState(() {
      isLoadingLabours = true;
      labourError = null;
    });
    try {
      final snapshot =
          await FirestoreService.getCollection('labours').get();
      final options = <String>[];
      final salaries = <String, num>{};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data.containsKey('designation')) {
          final designation = data['designation']?.toString() ?? '';
          if (designation.isNotEmpty) {
            options.add(designation);
            var salaryRaw = data['salary'];
            num salary = 0;
            if (salaryRaw is num) {
              salary = salaryRaw;
            } else if (salaryRaw is String)
              salary =
                  num.tryParse(salaryRaw.replaceAll(RegExp(r'[^\d.]'), '')) ??
                      0;
            salaries[designation] = salary;
          }
        }
      }
      setState(() {
        labourOptions = options;
        labourSalaries = salaries;
        selectedLabour = labourOptions.isNotEmpty ? labourOptions.first : null;
        isLoadingLabours = false;
      });
    } catch (e) {
      setState(() {
        labourError = 'Failed to load labours';
        isLoadingLabours = false;
      });
    }
  }

  // --- Add/Remove Logic as in your code, unchanged ---

  void _addMaterial() {
    int qty = int.tryParse(materialQtyController.text) ?? 0;
    if (selectedMaterial != null && qty > 0) {
      setState(() {
        materials.add({'type': selectedMaterial!, 'quantity': qty});
        materialQty = 0;
        materialQtyController.text = '0';
      });
    }
  }

  void _addLabour() {
    int qty = int.tryParse(labourQtyController.text) ?? 0;
    if (selectedLabour != null && qty > 0) {
      setState(() {
        labours.add({'type': selectedLabour!, 'count': qty});
        labourQty = 0;
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
    // Parse contractStartDate and contractEndDate to DateTime
    DateTime? startDate;
    DateTime? endDate;
    if (contractStartDate != null) {
      if (contractStartDate is DateTime) {
        startDate = contractStartDate;
      } else if (contractStartDate is String) {
        startDate = DateTime.tryParse(contractStartDate);
      } else if (contractStartDate.runtimeType.toString() == 'Timestamp' &&
          contractStartDate.toDate != null) {
        startDate = contractStartDate.toDate();
      }
    }
    if (contractEndDate != null) {
      if (contractEndDate is DateTime) {
        endDate = contractEndDate;
      } else if (contractEndDate is String) {
        endDate = DateTime.tryParse(contractEndDate);
      } else if (contractEndDate.runtimeType.toString() == 'Timestamp' &&
          contractEndDate.toDate != null) {
        endDate = contractEndDate.toDate();
      }
    }
    // Ensure initialDate is within range
    DateTime? initial = selectedDate;
    if (startDate != null && endDate != null) {
      if (initial == null ||
          initial.isBefore(startDate) ||
          initial.isAfter(endDate)) {
        initial = startDate;
      }
    } else if (startDate != null) {
      initial = startDate;
    } else if (endDate != null) {
      initial = endDate;
    } else {
      initial = DateTime.now();
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: startDate ?? DateTime(2000),
      lastDate: endDate ?? DateTime(2100),
      selectableDayPredicate: (date) {
        if (startDate != null && endDate != null) {
          return !date.isBefore(startDate) && !date.isAfter(endDate);
        } else if (startDate != null) {
          return date.isAtSameMomentAs(startDate);
        } else if (endDate != null) {
          return date.isAtSameMomentAs(endDate);
        }
        return false;
      },
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: _primaryColor,
            onPrimary: Colors.white,
            onSurface: Colors.black,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _saveToFirestore() async {
    if (_selectedContractorName == null ||
        _selectedContractorName!.isEmpty ||
        _selectedProjectField == null ||
        _selectedProjectField!.isEmpty ||
        selectedDate == null ||
        selectedSiteIdForEntry == null ||
        selectedSiteIdForEntry!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Select contractor, project field, date and site ID'),
          backgroundColor: _errorColor,
        ),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final laboursList = labours.map((l) {
        final type = (l['type'] ?? '').toString();
        final count = (l['count'] ?? 0) as int;
        final unitSalary = labourSalaries[type] ?? 0;
        final amount = (unitSalary * count).toInt();
        return {
          'amount': amount,
          'count': count,
          'type': type,
          'unitSalary': unitSalary is int ? unitSalary : (unitSalary).toInt(),
        };
      }).toList();

      final materialsList = materials.map((m) {
        final type = (m['type'] ?? '').toString();
        final qty = (m['quantity'] ?? 0) as int;
        final unitPrice = materialPrices[type] ?? 0;
        final amount = (unitPrice * qty).toInt();
        return {
          'amount': amount,
          'quantity': qty,
          'type': type,
          'unitPrice': unitPrice is int ? unitPrice : (unitPrice).toInt(),
        };
      }).toList();

      final totalAmount = _getTotalAmount().toInt();
      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate!);
      final contractorNameForId = _selectedContractorName!
          .trim()
          .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '-');
      final siteIdForId = (selectedSiteIdForEntry ?? '')
          .trim()
          .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '-');
      final docId = '${contractorNameForId}_$dateStr$siteIdForId';

      // Check for duplicate entry for this contractor, site, and date
      final duplicateQuery = await FirebaseFirestore.instance
          .collection('contractorEntries')
          .where('contractorName', isEqualTo: _selectedContractorName)
          .where('siteId', isEqualTo: selectedSiteIdForEntry)
          .where('date', isEqualTo: dateStr)
          .limit(1)
          .get();
      if (duplicateQuery.docs.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Entry for this contractor, site, and date already exists.'),
            backgroundColor: _errorColor,
          ),
        );
        setState(() => isSaving = false);
        return;
      }

      final data = {
        'contractorName': _selectedContractorName,
        'projectStage': _selectedProjectField ?? '',
        'date': dateStr,
        'siteId': selectedSiteIdForEntry ?? '',
        'food': int.tryParse(foodCost.text) ?? 0,
        'fuel': int.tryParse(fuelCost.text) ?? 0,
        'labours': laboursList,
        'materials': materialsList,
        'totalAmount': totalAmount,
        'transport': int.tryParse(transportCost.text) ?? 0,
        'contractorStartDate': contractStartDate,
        'contractorEndDate': contractEndDate,
      };

      await FirebaseFirestore.instance
          .collection('contractorEntries')
          .doc(docId)
          .set(data);

      try {
        await ExpenseService.recalcTotalsAndSyncProject(
            selectedSiteIdForEntry!);
      } catch (e) {
        debugPrint(
            'Failed to update totals for siteId $selectedSiteIdForEntry: $e');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Contractor entry saved'),
          backgroundColor: _successColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save entry: $e'),
          backgroundColor: _errorColor,
        ),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  // ------------------
  // Section Headers
  // ------------------
  Widget _buildSectionHeader(String title, IconData icon, {Color? color}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (color ?? _primaryColor).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color ?? _primaryColor, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: _textColor,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  // ------------------
  // Input Wrapper
  // ------------------
  Widget _buildInputField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: _labelColor,
            fontSize: 13,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: child,
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _buildCostInput(
      String label, TextEditingController controller, IconData icon) {
    return _buildInputField(
      label: label,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: Icon(icon, size: 20, color: _secondaryColor),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        keyboardType: TextInputType.number,
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildSummaryTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 16,
          horizontalMargin: 12,
          headingRowHeight: 48,
          dataRowHeight: 48,
          headingTextStyle: TextStyle(
            fontWeight: FontWeight.bold,
            color: _labelColor,
            fontSize: 12,
          ),
          columns: const [
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('Item')),
            DataColumn(label: Text('Qty')),
            DataColumn(label: Text('Amount')),
            DataColumn(label: SizedBox(width: 40)),
          ],
          rows: [
            ...materials.asMap().entries.map((entry) {
              int idx = entry.key;
              var m = entry.value;
              return DataRow(cells: [
                DataCell(Text('Material', style: TextStyle(fontSize: 12, color: _textColor))),
                DataCell(Text(m['type']?.toString() ?? '', style: TextStyle(fontSize: 12, color: _textColor))),
                DataCell(Text('${m['quantity'] ?? 0}', style: TextStyle(fontSize: 12, color: _textColor))),
                DataCell(Text(
                  _calculateMaterialAmount(m['type']?.toString() ?? '', m['quantity'] ?? 0),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textColor),
                )),
                DataCell(IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: _errorColor, size: 20),
                  onPressed: () => _removeMaterial(idx),
                )),
              ]);
            }),
            ...labours.asMap().entries.map((entry) {
              int idx = entry.key;
              var l = entry.value;
              return DataRow(cells: [
                DataCell(Text('Labour', style: TextStyle(fontSize: 12, color: _textColor))),
                DataCell(Text(l['type']?.toString() ?? '', style: TextStyle(fontSize: 12, color: _textColor))),
                DataCell(Text('${l['count'] ?? 0}', style: TextStyle(fontSize: 12, color: _textColor))),
                DataCell(Text(
                  _calculateLabourAmount(l['type']?.toString() ?? '', l['count'] ?? 0),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textColor),
                )),
                DataCell(IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: _errorColor, size: 20),
                  onPressed: () => _removeLabour(idx),
                )),
              ]);
            }),
            DataRow(cells: [
              DataCell(Text('Food', style: TextStyle(fontSize: 12, color: _labelColor))),
              DataCell(Text('-', style: TextStyle(fontSize: 12))),
              DataCell(Text('-', style: TextStyle(fontSize: 12))),
              DataCell(Text('₹${foodCost.text}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textColor))),
              DataCell(const SizedBox.shrink()),
            ]),
            DataRow(cells: [
              DataCell(Text('Transport', style: TextStyle(fontSize: 12, color: _labelColor))),
              DataCell(Text('-', style: TextStyle(fontSize: 12))),
              DataCell(Text('-', style: TextStyle(fontSize: 12))),
              DataCell(Text('₹${transportCost.text}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textColor))),
              DataCell(const SizedBox.shrink()),
            ]),
            DataRow(cells: [
              DataCell(Text('Fuel', style: TextStyle(fontSize: 12, color: _labelColor))),
              DataCell(Text('-', style: TextStyle(fontSize: 12))),
              DataCell(Text('-', style: TextStyle(fontSize: 12))),
              DataCell(Text('₹${fuelCost.text}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textColor))),
              DataCell(const SizedBox.shrink()),
            ]),
            DataRow(
              color: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              cells: [
                const DataCell(SizedBox.shrink()),
                const DataCell(SizedBox.shrink()),
                const DataCell(Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)))),
                DataCell(Text(
                  '₹${_getTotalAmount()}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _primaryColor),
                )),
                const DataCell(SizedBox.shrink()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context, bool isDark, double hPad) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: SizedBox(
          height: kToolbarHeight,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 20, color: Color(0xFF1E293B)),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'CONTRACTOR ENTRY',
                      style: TextStyle(
                        color: _primaryColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 48), // Spacer for balance
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --------- Section Cards -----------
  Widget _buildContractorDetailsCard(bool isDark) {
    return Card(
      elevation: 3,
      shadowColor: Colors.black12,
      
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Contractor Details', Icons.engineering,
                color: _primaryColor),
            const SizedBox(height: 18),
            _buildInputField(
              label: 'Contractor Name',
              child: TextField(
                controller: _contractorNameController,
                readOnly: true,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Enter contractor name',
                ),
              ),
            ),
            _buildInputField(
              label: 'Project Field',
              child: TextField(
                controller: _projectFieldController,
                readOnly: true,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Enter project field',
                ),
              ),
            ),
            _buildInputField(
              label: 'Date',
              child: TextField(
                controller: _dateController,
                readOnly: true,
                onTap: _pickDate,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  suffixIcon:
                      Icon(Icons.calendar_today, color: _secondaryColor),
                ),
              ),
            ),
            isLoadingSiteIds
                ? Center(child: CircularProgressIndicator(color: _primaryColor))
                : siteIdError != null
                    ? Text(siteIdError!, style: TextStyle(color: _errorColor))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInputField(
                            label: 'Site ID',
                            child: DropdownButtonFormField<String>(
                              value: selectedSiteIdForEntry,
                              items: siteIdOptions
                                  .map((id) => DropdownMenuItem<String>(
                                        value: id,
                                        child: Text(id),
                                      ))
                                  .toList(),
                              onChanged: (val) async {
                                setState(() => selectedSiteIdForEntry = val);
                                await _fetchContractDates(val);
                              },
                              decoration:
                                  InputDecoration(border: InputBorder.none),
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: _buildInputField(
                                  label: 'Contract Start Date',
                                  child: Text(
                                    _formatDate(contractStartDate),
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildInputField(
                                  label: 'Contract End Date',
                                  child: Text(
                                    _formatDate(contractEndDate),
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialSection() {
    return Card(
      elevation: 3,
      shadowColor: Colors.black12,
      
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Material Details', Icons.add_box,
                color: Colors.brown),
            const SizedBox(height: 16),
            isLoadingMaterials
                ? Center(child: CircularProgressIndicator(color: _primaryColor))
                : materialError != null
                    ? Text(materialError!, style: TextStyle(color: _errorColor))
                    : Column(
                        children: [
                          TextField(
                            decoration: InputDecoration(
                              labelText: 'Search Material...',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              prefixIcon:
                                  Icon(Icons.search, color: _secondaryColor),
                            ),
                            onChanged: (query) {
                              setState(() {
                                final q = query.toLowerCase();
                                final filtered = materialOptions
                                    .where((item) =>
                                        item.toLowerCase().contains(q))
                                    .toList();
                                _filteredMaterialOptions = filtered;
                                if (filtered.isNotEmpty &&
                                    !filtered.contains(selectedMaterial)) {
                                  selectedMaterial = filtered.first;
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DropdownButtonFormField<String>(
                                value: selectedMaterial,
                                decoration: InputDecoration(
                                  labelText: 'Material',
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                items: (_filteredMaterialOptions ??
                                        materialOptions)
                                    .map((item) => DropdownMenuItem(
                                          value: item,
                                          child: Text(item),
                                        ))
                                    .toList(),
                                onChanged: (value) =>
                                    setState(() => selectedMaterial = value),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: materialQtyController,
                                decoration: InputDecoration(
                                  labelText: 'Qty',
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            icon: Icon(Icons.add, size: 18),
                            onPressed: _addMaterial,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            label: Text('Add Material'),
                          ),
                        ],
                      ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => setState(
                  () => _showCustomMaterialFields = !_showCustomMaterialFields),
              style: ElevatedButton.styleFrom(
                backgroundColor: _secondaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Custom Material'),
            ),
            if (_showCustomMaterialFields) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _customMaterialNameController,
                decoration: InputDecoration(
                  labelText: 'Material Name',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customMaterialQtyController,
                      decoration: InputDecoration(
                        labelText: 'Qty',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _customMaterialPriceController,
                      decoration: InputDecoration(
                        labelText: 'Unit Price (₹)',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _addCustomMaterial,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('Add'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          setState(() => _showCustomMaterialFields = false),
                      child: Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLabourSection() {
    return Card(
      elevation: 3,
      shadowColor: Colors.black12,
      
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Labour Details', Icons.groups,
                color: Colors.teal[700]),
            const SizedBox(height: 16),
            isLoadingLabours
                ? Center(child: CircularProgressIndicator(color: _primaryColor))
                : labourError != null
                    ? Text(labourError!, style: TextStyle(color: _errorColor))
                    : Column(
                        children: [
                          TextField(
                            decoration: InputDecoration(
                              labelText: 'Search Labour...',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              prefixIcon:
                                  Icon(Icons.search, color: _secondaryColor),
                            ),
                            onChanged: (query) {
                              setState(() {
                                final q = query.toLowerCase();
                                final filtered = labourOptions
                                    .where((item) =>
                                        item.toLowerCase().contains(q))
                                    .toList();
                                _filteredLabourOptions = filtered;
                                if (filtered.isNotEmpty &&
                                    !filtered.contains(selectedLabour)) {
                                  selectedLabour = filtered.first;
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DropdownButtonFormField<String>(
                                value: selectedLabour,
                                decoration: InputDecoration(
                                  labelText: 'Labour',
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                items: (_filteredLabourOptions ?? labourOptions)
                                    .map((item) => DropdownMenuItem(
                                          value: item,
                                          child: Text(item),
                                        ))
                                    .toList(),
                                onChanged: (value) =>
                                    setState(() => selectedLabour = value),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: labourQtyController,
                                decoration: InputDecoration(
                                  labelText: 'Count',
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            icon: Icon(Icons.add, size: 18),
                            onPressed: _addLabour,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            label: Text('Add Labour'),
                          ),
                        ],
                      ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => setState(
                  () => _showCustomLabourFields = !_showCustomLabourFields),
              style: ElevatedButton.styleFrom(
                backgroundColor: _secondaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Custom Labour'),
            ),
            if (_showCustomLabourFields) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _customLabourNameController,
                decoration: InputDecoration(
                  labelText: 'Labour Type',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _customLabourSalaryController,
                decoration: InputDecoration(
                  labelText: 'Salary',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: labourQtyController,
                decoration: InputDecoration(
                  labelText: 'Count',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _addCustomLabour,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('Add'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          setState(() => _showCustomLabourFields = false),
                      child: Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalCostsSection() {
    return Card(
      elevation: 3,
      shadowColor: Colors.black12,
      
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Additional Costs', Icons.attach_money,
                color: Colors.deepOrange),
            const SizedBox(height: 16),
            _buildCostInput('Food Cost', foodCost, Icons.fastfood),
            _buildCostInput(
                'Transport Cost', transportCost, Icons.directions_car),
            _buildCostInput('Fuel Cost', fuelCost, Icons.local_gas_station),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
    return Container(
      width: double.infinity,
      
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader('Summary', Icons.summarize,
                    color: _primaryColor),
                Text(
                  'Total: ₹${_getTotalAmount()}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: _primaryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: _buildSummaryTable(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final double hPad = getPad(width);
    final double sectionSpacing = width < 400
        ? 8
        : width < 600
            ? 12
            : 18;
    final double cardPadding = width < 400
        ? 10
        : width < 600
            ? 14
            : 18;
    final double fontSize = width < 400
        ? 12
        : width < 600
            ? 14
            : 16;
    return Scaffold(
      backgroundColor: _sectionBgColor,
      body: Column(
        children: [
          _buildHeaderSection(context, false, hPad),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                  horizontal: hPad, vertical: sectionSpacing),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(cardPadding),
                    child: _buildContractorDetailsCard(false),
                  ),
                  SizedBox(height: sectionSpacing),
                  Padding(
                    padding: EdgeInsets.all(cardPadding),
                    child: _buildMaterialSection(),
                  ),
                  SizedBox(height: sectionSpacing),
                  Padding(
                    padding: EdgeInsets.all(cardPadding),
                    child: _buildLabourSection(),
                  ),
                  SizedBox(height: sectionSpacing),
                  Padding(
                    padding: EdgeInsets.all(cardPadding),
                    child: _buildAdditionalCostsSection(),
                  ),
                  SizedBox(height: sectionSpacing),
                  Padding(
                    padding: EdgeInsets.all(cardPadding),
                    child: _buildSummarySection(),
                  ),
                  SizedBox(height: sectionSpacing * 1.5),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSaving ? null : _saveToFirestore,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        // Save button text color as per your requirement
                        foregroundColor: _actionTextColor,
                        padding:
                            EdgeInsets.symmetric(vertical: sectionSpacing + 2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        textStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: fontSize,
                        ),
                        elevation: 2,
                      ),
                      child: isSaving
                          ? SizedBox(
                              height: fontSize + 10,
                              width: fontSize + 10,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, ),
                            )
                          : Text(
                              'Save Entry',
                              style: TextStyle(),
                            ),
                    ),
                  ),
                  SizedBox(height: sectionSpacing * 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
