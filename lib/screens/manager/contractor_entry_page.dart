import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:demo_cst/services/expense_service.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/services/auth_service.dart';
import 'package:demo_cst/utils/app_theme.dart';

class ContractorEntryPage extends StatefulWidget {
  final String userName;
  final Map<String, dynamic> userDetails;
  final bool showLogout;

  const ContractorEntryPage({
    super.key,
    required this.userName,
    required this.userDetails,
    this.showLogout = true,
  });

  @override
  State<ContractorEntryPage> createState() => _ContractorEntryPageState();
}

class _ContractorEntryPageState extends State<ContractorEntryPage> {
  Color get _primaryColor => Theme.of(context).primaryColor;
  Color get _textColor => const Color(0xFF0A183D);
  Color get _borderColor => const Color(0xFFCBD5E1);
  Color get _errorColor => Theme.of(context).colorScheme.error;

  double getPad(double w) {
    if (w < 400) return 8;
    if (w < 600) return 12;
    return 20;
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
  Map<String, String> siteNameMap = {};
  String? selectedSiteIdForEntry;
  bool isLoadingSiteIds = true;
  String? siteIdError;
  dynamic contractStartDate;
  dynamic contractEndDate;

  List<Map<String, dynamic>> contractorDocs = [];
  List<String> contractorOptions = [];
  bool isLoadingContractors = true;

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
  final _customLabourQtyController = TextEditingController(text: '0');

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
    _fetchContractors();
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
    _customLabourQtyController.dispose();
    super.dispose();
  }

  Future<void> _fetchContractors() async {
    setState(() => isLoadingContractors = true);
    try {
      final snap = await FirestoreService.getCollection('contractors').get();
      contractorDocs = snap.docs.map((d) => d.data()).toList();
      contractorOptions = contractorDocs
          .map((d) => (d['contractorName'] ?? '').toString())
          .where((n) => n.isNotEmpty)
          .toSet()
          .toList();
      if (_selectedContractorName != null) {
        await _fetchProjectForContractor(_selectedContractorName!);
        await _fetchSiteIds();
      }
    } catch (e) {
      debugPrint('Error fetching contractors: $e');
    } finally {
      if (mounted) setState(() => isLoadingContractors = false);
    }
  }

  Future<void> _fetchProjectForContractor(String name) async {
    try {
      final snap = await FirestoreService.getCollection('contractors')
          .where('contractorName', isEqualTo: name)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        final field = snap.docs.first.data()['contractorField'] as String?;
        if (field != null && field.isNotEmpty) {
          setState(() {
            _selectedProjectField = field;
            _projectFieldController.text = field;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching project field for contractor: $e');
    }
  }

  Future<void> _fetchSiteIds() async {
    setState(() {
      isLoadingSiteIds = true;
      siteIdError = null;
    });
    try {
      Query query = FirestoreService.getCollection('siteSupervisorMap');

      final userRole = widget.userDetails['role'] ?? '';
      final userSupervisorName = widget.userDetails['name'] ?? widget.userName;

      if (userRole == 'Supervisor') {
        query = query.where('supervisor', isEqualTo: userSupervisorName);
      } else if (_selectedContractorName != null) {
        query = query.where('supervisor', isEqualTo: _selectedContractorName);
      }

      final snapshot = await query.get();
      final docs = snapshot.docs;

      final ids = <String>[];
      final Map<String, String> names = {};

      for (var doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        final siteId = data['site'] as String?;
        final siteName = data['projectName'] as String?;
        if (siteId != null && siteId.isNotEmpty) {
          ids.add(siteId);
          names[siteId] = siteName ?? 'Unnamed Site';
        }
      }

      setState(() {
        siteIdOptions = ids;
        siteNameMap = names;
        if (siteIdOptions.isNotEmpty) {
          selectedSiteIdForEntry = siteIdOptions.first;
          _fetchContractDates(selectedSiteIdForEntry!);
        } else {
          selectedSiteIdForEntry = null;
        }
        isLoadingSiteIds = false;
      });
    } catch (e) {
      setState(() {
        siteIdError = 'Failed to load site IDs: $e';
        isLoadingSiteIds = false;
      });
    }
  }

  Future<void> _fetchContractDates(String siteId) async {
    try {
      final snap = await FirestoreService.getCollection('siteSupervisorMap')
          .where('site', isEqualTo: siteId)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        setState(() {
          contractStartDate = data['contractStartDate'];
          contractEndDate = data['contractEndDate'];
        });
      }
    } catch (e) {
      debugPrint('Error fetching contract dates: $e');
    }
  }

  Future<void> _fetchMaterialOptions() async {
    try {
      final snap = await FirestoreService.getCollection('materials').get();
      final options = <String>[];
      final prices = <String, num>{};
      for (var doc in snap.docs) {
        final data = doc.data();
        final name = data['materialName'] as String?;
        final price = data['unitPrice'] as num? ?? 0;
        if (name != null && name.isNotEmpty) {
          options.add(name);
          prices[name] = price;
        }
      }
      setState(() {
        materialOptions = options;
        materialPrices = prices;
        if (options.isNotEmpty) {
          selectedMaterial = options.first;
        }
        isLoadingMaterials = false;
      });
    } catch (e) {
      setState(() {
        materialError = 'Failed to load materials: $e';
        isLoadingMaterials = false;
      });
    }
  }

  Future<void> _fetchLabourOptions() async {
    try {
      final snap = await FirestoreService.getCollection('labours').get();
      final options = <String>[];
      final salaries = <String, num>{};
      for (var doc in snap.docs) {
        final data = doc.data();
        final des = data['designation'] as String?;
        final salaryStr = data['salary'] as String?;
        final salaryNum = num.tryParse(salaryStr ?? '') ?? 0;
        if (des != null && des.isNotEmpty) {
          options.add(des);
          salaries[des] = salaryNum;
        }
      }
      setState(() {
        labourOptions = options;
        labourSalaries = salaries;
        if (options.isNotEmpty) {
          selectedLabour = options.first;
        }
        isLoadingLabours = false;
      });
    } catch (e) {
      setState(() {
        labourError = 'Failed to load labours: $e';
        isLoadingLabours = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _pickContractStartDate() async {
    final initial = contractStartDate is DateTime
        ? contractStartDate
        : DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => contractStartDate = picked);
    }
  }

  Future<void> _pickContractEndDate() async {
    final initial = contractEndDate is DateTime
        ? contractEndDate
        : DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => contractEndDate = picked);
    }
  }

  void _addMaterial() {
    if (selectedMaterial == null) return;
    final qty = int.tryParse(materialQtyController.text) ?? 0;
    if (qty <= 0) return;
    final unitPrice = materialPrices[selectedMaterial] ?? 0;
    setState(() {
      materials.add({
        'name': selectedMaterial,
        'qty': qty,
        'unitPrice': unitPrice,
        'totalPrice': qty * unitPrice,
      });
      materialQtyController.text = '0';
    });
  }

  void _addCustomMaterial() {
    final name = _customMaterialNameController.text.trim();
    final qty = int.tryParse(_customMaterialQtyController.text) ?? 0;
    final price = num.tryParse(_customMaterialPriceController.text) ?? 0;
    if (name.isEmpty || qty <= 0 || price < 0) return;
    setState(() {
      materials.add({
        'name': name,
        'qty': qty,
        'unitPrice': price,
        'totalPrice': qty * price,
      });
      _customMaterialNameController.clear();
      _customMaterialQtyController.text = '0';
      _customMaterialPriceController.text = '0';
      _showCustomMaterialFields = false;
    });
  }

  void _removeMaterial(int index) {
    setState(() => materials.removeAt(index));
  }

  void _addLabour() {
    if (selectedLabour == null) return;
    final count = int.tryParse(labourQtyController.text) ?? 0;
    if (count <= 0) return;
    final salary = labourSalaries[selectedLabour] ?? 0;
    setState(() {
      labours.add({
        'type': selectedLabour,
        'count': count,
        'salary': salary,
        'totalSalary': count * salary,
      });
      labourQtyController.text = '0';
    });
  }

  void _addCustomLabour() {
    final type = _customLabourNameController.text.trim();
    final count = int.tryParse(_customLabourQtyController.text) ?? 0;
    final salary = num.tryParse(_customLabourSalaryController.text) ?? 0;
    if (type.isEmpty || count <= 0 || salary < 0) return;
    setState(() {
      labours.add({
        'type': type,
        'count': count,
        'salary': salary,
        'totalSalary': count * salary,
      });
      _customLabourNameController.clear();
      _customLabourQtyController.text = '0';
      _customLabourSalaryController.text = '0';
      _showCustomLabourFields = false;
    });
  }

  void _removeLabour(int index) {
    setState(() => labours.removeAt(index));
  }

  num _getTotalMaterialCost() {
    return materials.fold(
      0,
      (acc, item) => acc + ((item['totalPrice'] as num?) ?? 0),
    );
  }

  num _getTotalLabourCost() {
    return labours.fold(
      0,
      (acc, item) => acc + ((item['totalSalary'] as num?) ?? 0),
    );
  }

  num _getAdditionalCosts() {
    final food = num.tryParse(foodCost.text) ?? 0;
    final trans = num.tryParse(transportCost.text) ?? 0;
    final fuel = num.tryParse(fuelCost.text) ?? 0;
    return food + trans + fuel;
  }

  num _getTotalAmount() {
    return _getTotalMaterialCost() +
        _getTotalLabourCost() +
        _getAdditionalCosts();
  }

  Future<void> _handleLogout() async {
    await AuthService().logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/landing',
      (route) => false,
    );
  }

  Future<void> _saveToFirestore() async {
    if (selectedSiteIdForEntry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a Site ID.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    if (_selectedContractorName == null || _selectedContractorName!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or enter Contractor Name.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => isSaving = true);
    try {
      final docId =
          'CT_${selectedSiteIdForEntry}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';
      final totalAmount = _getTotalAmount();

      final data = {
        'contractorName': _selectedContractorName,
        'contractorField': _selectedProjectField,
        'date': Timestamp.fromDate(selectedDate!),
        'siteId': selectedSiteIdForEntry,
        'siteName': siteNameMap[selectedSiteIdForEntry] ?? '',
        'contractStartDate': contractStartDate != null
            ? (contractStartDate is DateTime
                ? Timestamp.fromDate(contractStartDate)
                : contractStartDate)
            : null,
        'contractEndDate': contractEndDate != null
            ? (contractEndDate is DateTime
                ? Timestamp.fromDate(contractEndDate)
                : contractEndDate)
            : null,
        'materials': materials,
        'labours': labours,
        'additionalCosts': {
          'food': num.tryParse(foodCost.text) ?? 0,
          'transport': num.tryParse(transportCost.text) ?? 0,
          'fuel': num.tryParse(fuelCost.text) ?? 0,
        },
        'totalAmount': totalAmount,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': widget.userName,
      };

      await FirestoreService.getCollection('ContractorEntry').doc(docId).set(data);

      await ExpenseService.recalcTotalsAndSyncProject(selectedSiteIdForEntry!);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contractor Entry saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        materials.clear();
        labours.clear();
        foodCost.text = '0';
        transportCost.text = '0';
        fuelCost.text = '0';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save entry: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    final double width = MediaQuery.of(context).size.width;
    final double hPad = getPad(width);
    final darkAccent = AppTheme.getDarkAccent(_primaryColor);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Contractor Daily Entry',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
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
                  _primaryColor.withValues(alpha: 0.35),
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
        actions: widget.showLogout
            ? [
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                  onPressed: _handleLogout,
                  tooltip: 'Logout',
                ),
              ]
            : null,
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isMobile ? double.infinity : 600,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 16),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildContractorDetailsCard(),
                  const SizedBox(height: 14),
                  _buildMaterialSection(),
                  const SizedBox(height: 14),
                  _buildLabourSection(),
                  const SizedBox(height: 14),
                  _buildAdditionalCostsSection(),
                  const SizedBox(height: 14),
                  _buildSummarySection(),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isSaving ? null : _saveToFirestore,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      child: isSaving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'SAVE ENTRY',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.04),
            blurRadius: 10,
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
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: _textColor,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildContractorDetailsCard() {
    return _buildSectionCard(
      title: 'Contractor & Site Details',
      icon: Icons.assignment_ind_rounded,
      iconColor: _primaryColor,
      children: [
        isLoadingContractors
            ? const Center(child: CircularProgressIndicator())
            : _buildInputField(
                label: 'Contractor Name',
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: contractorOptions.contains(_selectedContractorName)
                      ? _selectedContractorName
                      : null,
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  style: TextStyle(color: _textColor, fontSize: 14.5, fontWeight: FontWeight.w700),
                  items: contractorOptions
                      .map(
                        (name) => DropdownMenuItem<String>(
                          value: name,
                          child: Text(name),
                        ),
                      )
                      .toList(),
                  onChanged: widget.showLogout
                      ? null
                      : (val) async {
                          setState(() {
                            _selectedContractorName = val;
                            if (val != null) {
                              _contractorNameController.text = val;
                            }
                          });
                          if (val != null) {
                            await _fetchProjectForContractor(val);
                            await _fetchSiteIds();
                          }
                        },
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    hintText: 'Select contractor',
                    hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5, fontWeight: FontWeight.w400),
                  ),
                ),
              ),
        const SizedBox(height: 12),
        _buildInputField(
          label: 'Project Field',
          child: TextField(
            controller: _projectFieldController,
            readOnly: widget.showLogout || _selectedContractorName != null,
            onChanged: (val) => _selectedProjectField = val,
            style: TextStyle(color: _textColor, fontSize: 14.5, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              hintText: 'Auto-filled project stage',
              hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5, fontWeight: FontWeight.w400),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildInputField(
          label: 'Date',
          child: TextField(
            controller: _dateController,
            readOnly: true,
            onTap: _pickDate,
            style: TextStyle(color: _textColor, fontSize: 14.5, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              suffixIcon: Icon(Icons.calendar_today_rounded, color: _primaryColor, size: 18),
            ),
          ),
        ),
        const SizedBox(height: 12),
        isLoadingSiteIds
            ? const Center(child: CircularProgressIndicator())
            : siteIdError != null
            ? Text(siteIdError!, style: TextStyle(color: _errorColor))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInputField(
                    label: 'Site ID',
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: selectedSiteIdForEntry,
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      style: TextStyle(color: _textColor, fontSize: 14.5, fontWeight: FontWeight.w700),
                      items: siteIdOptions
                          .map(
                            (id) => DropdownMenuItem<String>(
                              value: id,
                              child: Text(
                                '$id - ${siteNameMap[id] ?? "Unnamed Site"}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) async {
                        setState(() => selectedSiteIdForEntry = val);
                        if (val != null) await _fetchContractDates(val);
                      },
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInputField(
                          label: 'Contract Start Date',
                          child: InkWell(
                            onTap: widget.showLogout ? null : _pickContractStartDate,
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Text(
                                _formatDate(contractStartDate).isEmpty
                                    ? 'Select Date'
                                    : _formatDate(contractStartDate),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _textColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildInputField(
                          label: 'Contract End Date',
                          child: InkWell(
                            onTap: widget.showLogout ? null : _pickContractEndDate,
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Text(
                                _formatDate(contractEndDate).isEmpty
                                    ? 'Select Date'
                                    : _formatDate(contractEndDate),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _textColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ],
    );
  }

  Widget _buildMaterialSection() {
    return _buildSectionCard(
      title: 'Material Details',
      icon: Icons.inventory_2_rounded,
      iconColor: const Color(0xFFD97706),
      children: [
        isLoadingMaterials
            ? const Center(child: CircularProgressIndicator())
            : materialError != null
            ? Text(materialError!, style: TextStyle(color: _errorColor))
            : Column(
                children: [
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _borderColor),
                    ),
                    child: TextField(
                      style: TextStyle(color: _textColor, fontSize: 13.5, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Search Material...',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.search_rounded, color: _primaryColor, size: 20),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      ),
                      onChanged: (query) {
                        setState(() {
                          final q = query.toLowerCase();
                          final filtered = materialOptions
                              .where((item) => item.toLowerCase().contains(q))
                              .toList();
                          _filteredMaterialOptions = filtered;
                          if (filtered.isNotEmpty && !filtered.contains(selectedMaterial)) {
                            selectedMaterial = filtered.first;
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInputField(
                    label: 'Material',
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: (_filteredMaterialOptions ?? materialOptions).contains(selectedMaterial)
                          ? selectedMaterial
                          : null,
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      style: TextStyle(color: _textColor, fontSize: 14.5, fontWeight: FontWeight.w700),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      items: (_filteredMaterialOptions ?? materialOptions)
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => selectedMaterial = value),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildInputField(
                    label: 'Quantity',
                    child: TextField(
                      controller: materialQtyController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: _textColor, fontSize: 14.5, fontWeight: FontWeight.w700),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: _addMaterial,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Material', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () => setState(() => _showCustomMaterialFields = !_showCustomMaterialFields),
          style: OutlinedButton.styleFrom(
            foregroundColor: _primaryColor,
            side: BorderSide(color: _primaryColor),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
          label: const Text('Custom Material'),
        ),
        if (_showCustomMaterialFields) ...[
          const SizedBox(height: 14),
          _buildInputField(
            label: 'Custom Material Name',
            child: TextField(
              controller: _customMaterialNameController,
              style: TextStyle(color: _textColor, fontSize: 14.5, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildInputField(
                  label: 'Qty',
                  child: TextField(
                    controller: _customMaterialQtyController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: _textColor, fontSize: 14.5, fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildInputField(
                  label: 'Unit Price (₹)',
                  child: TextField(
                    controller: _customMaterialPriceController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: _textColor, fontSize: 14.5, fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Add Custom Material'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () => setState(() => _showCustomMaterialFields = false),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildLabourSection() {
    return _buildSectionCard(
      title: 'Labour Details',
      icon: Icons.groups_rounded,
      iconColor: const Color(0xFF2563EB),
      children: [
        isLoadingLabours
            ? const Center(child: CircularProgressIndicator())
            : labourError != null
            ? Text(labourError!, style: TextStyle(color: _errorColor))
            : Column(
                children: [
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _borderColor),
                    ),
                    child: TextField(
                      style: TextStyle(color: _textColor, fontSize: 13.5, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Search Labour...',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.search_rounded, color: _primaryColor, size: 20),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      ),
                      onChanged: (query) {
                        setState(() {
                          final q = query.toLowerCase();
                          final filtered = labourOptions
                              .where((item) => item.toLowerCase().contains(q))
                              .toList();
                          _filteredLabourOptions = filtered;
                          if (filtered.isNotEmpty && !filtered.contains(selectedLabour)) {
                            selectedLabour = filtered.first;
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInputField(
                    label: 'Labour Type',
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: (_filteredLabourOptions ?? labourOptions).contains(selectedLabour)
                          ? selectedLabour
                          : null,
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      style: TextStyle(color: _textColor, fontSize: 14.5, fontWeight: FontWeight.w700),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      items: (_filteredLabourOptions ?? labourOptions)
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => selectedLabour = value),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildInputField(
                    label: 'Count',
                    child: TextField(
                      controller: labourQtyController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: _textColor, fontSize: 14.5, fontWeight: FontWeight.w700),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: _addLabour,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Labour', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () => setState(() => _showCustomLabourFields = !_showCustomLabourFields),
          style: OutlinedButton.styleFrom(
            foregroundColor: _primaryColor,
            side: BorderSide(color: _primaryColor),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
          label: const Text('Custom Labour'),
        ),
        if (_showCustomLabourFields) ...[
          const SizedBox(height: 14),
          _buildInputField(
            label: 'Labour Type Name',
            child: TextField(
              controller: _customLabourNameController,
              style: TextStyle(color: _textColor, fontSize: 14.5, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildInputField(
                  label: 'Salary (₹)',
                  child: TextField(
                    controller: _customLabourSalaryController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: _textColor, fontSize: 14.5, fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildInputField(
                  label: 'Count',
                  child: TextField(
                    controller: _customLabourQtyController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: _textColor, fontSize: 14.5, fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),
            ],
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Add Custom Labour'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () => setState(() => _showCustomLabourFields = false),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildAdditionalCostsSection() {
    return _buildSectionCard(
      title: 'Additional Costs',
      icon: Icons.payments_rounded,
      iconColor: const Color(0xFFEA580C),
      children: [
        _buildCostInput('Food Cost', foodCost, Icons.fastfood_rounded),
        const SizedBox(height: 10),
        _buildCostInput('Transport Cost', transportCost, Icons.directions_bus_rounded),
        const SizedBox(height: 10),
        _buildCostInput('Fuel Cost', fuelCost, Icons.local_gas_station_rounded),
      ],
    );
  }

  Widget _buildSummarySection() {
    return _buildSectionCard(
      title: 'Entry Summary',
      icon: Icons.summarize_rounded,
      iconColor: const Color(0xFF16A34A),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total Entry Cost',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            Text(
              '₹${_getTotalAmount()}',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                color: _primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildSummaryTable(),
      ],
    );
  }

  Widget _buildInputField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: _textColor,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _borderColor),
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _buildCostInput(String label, TextEditingController controller, IconData icon) {
    return _buildInputField(
      label: label,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        onChanged: (_) => setState(() {}),
        style: TextStyle(color: _textColor, fontSize: 14.5, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          prefixIcon: Icon(icon, color: _primaryColor, size: 20),
          prefixText: '₹ ',
          prefixStyle: TextStyle(color: _textColor, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildSummaryTable() {
    return Column(
      children: [
        if (materials.isNotEmpty) ...[
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Materials Added',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0A183D)),
            ),
          ),
          const SizedBox(height: 6),
          ...materials.asMap().entries.map((e) {
            final idx = e.key;
            final item = e.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item['name']} (x${item['qty']})',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    ),
                  ),
                  Text(
                    '₹${item['totalPrice']}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0A183D)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded, size: 18, color: Colors.redAccent),
                    onPressed: () => _removeMaterial(idx),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 10),
        ],
        if (labours.isNotEmpty) ...[
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Labour Added',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0A183D)),
            ),
          ),
          const SizedBox(height: 6),
          ...labours.asMap().entries.map((e) {
            final idx = e.key;
            final item = e.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item['type']} (x${item['count']})',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    ),
                  ),
                  Text(
                    '₹${item['totalSalary']}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0A183D)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded, size: 18, color: Colors.redAccent),
                    onPressed: () => _removeLabour(idx),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}
