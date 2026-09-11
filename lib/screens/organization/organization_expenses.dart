import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ebricks/services/expense_service.dart';
import 'package:ebricks/services/firestore_service.dart';
import 'package:ebricks/services/offline_sync_service.dart';
import 'package:ebricks/widgets/offline_sync_banner.dart';
import 'package:ebricks/utils/app_theme.dart';

class OrganizationExpenses extends StatefulWidget {
  const OrganizationExpenses({super.key});

  @override
  OrganizationExpensesState createState() => OrganizationExpensesState();
}

class OrganizationExpensesState extends State<OrganizationExpenses>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // --- ENTRY TAB STATE ---
  String? selectedSiteId;
  String? selectedSupervisorId;
  String? selectedProjectStage;
  DateTime selectedDate = DateTime.now();

  List<String> siteIds = [];
  Map<String, String> siteNameMap = {};
  bool isLoadingSites = true;
  bool isLoadingSiteDetails = false;
  bool isSubmitting = false;

  final billNoController = TextEditingController();
  final billVendorController = TextEditingController();
  final billAmountController = TextEditingController();
  final supervisorController = TextEditingController();
  final projectStageController = TextEditingController();

  List<Map<String, String>> bills = [];

  // --- LOGS TAB STATE ---
  final TextEditingController _logSearchController = TextEditingController();
  String _logSearchQuery = '';
  String _selectedLogSite = 'All';
  String _selectedLogStage = 'All';
  String _selectedLogDateFilter = 'All Time'; // 'All Time', 'Today', 'This Month'

  Color get primaryColor => Theme.of(context).colorScheme.primary;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadSiteIds();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _logSearchController.dispose();
    billNoController.dispose();
    billVendorController.dispose();
    billAmountController.dispose();
    supervisorController.dispose();
    projectStageController.dispose();
    super.dispose();
  }

  Future<void> _loadSiteIds() async {
    setState(() {
      isLoadingSites = true;
    });
    try {
      if (OfflineSyncService().isOnline) {
        final Map<String, String> names = {};
        final Map<String, String> nameOrCodeToCanonical = {};
        final Set<String> canonicalIds = {};

        // 1. Fetch from Site collection (Primary Source)
        final siteSnapshot = await FirestoreService.getCollection('Site').get();
        for (var doc in siteSnapshot.docs) {
          if (doc.id.isEmpty) continue;
          final data = doc.data();
          final sCode = (data['siteId'] ?? data['siteCode'] ?? '').toString().trim();
          final sName = (data['siteName'] ?? data['name'] ?? data['projectName'] ?? data['site'] ?? '').toString().trim();

          final canonical = ExpenseService.formatCanonicalSiteId(
            rawId: doc.id,
            siteCode: sCode,
            siteName: sName,
          );

          canonicalIds.add(canonical);
          if (sName.isNotEmpty) {
            names[canonical] = sName;
            nameOrCodeToCanonical[sName.toLowerCase()] = canonical;
            nameOrCodeToCanonical[sName.replaceAll(' ', '').toLowerCase()] = canonical;
          }
          if (sCode.isNotEmpty) {
            nameOrCodeToCanonical[sCode.toLowerCase()] = canonical;
          }
          nameOrCodeToCanonical[doc.id.toLowerCase()] = canonical;
        }

        // 2. Fetch from siteSupervisorMap
        final mapSnapshot = await FirestoreService.siteSupervisorMap.get();
        for (var doc in mapSnapshot.docs) {
          final data = doc.data();
          final sDocId = (data['siteDocId'] ?? '').toString().trim();
          final sId = (data['siteId'] ?? data['siteCode'] ?? '').toString().trim();
          final sSite = (data['site'] ?? '').toString().trim();
          final sName = (data['siteName'] ?? data['projectName'] ?? data['site_name'] ?? data['location'] ?? '').toString().trim();

          // Check if already mapped
          String? mapped = nameOrCodeToCanonical[sDocId.toLowerCase()] ??
              nameOrCodeToCanonical[sSite.toLowerCase()] ??
              nameOrCodeToCanonical[sId.toLowerCase()] ??
              nameOrCodeToCanonical[sName.toLowerCase()] ??
              nameOrCodeToCanonical[doc.id.toLowerCase()];

          if (mapped == null || !mapped.contains('_')) {
            final formatted = ExpenseService.formatCanonicalSiteId(
              rawId: sDocId.isNotEmpty ? sDocId : (sSite.isNotEmpty ? sSite : doc.id),
              siteCode: sId,
              siteName: sName,
            );
            if (formatted.contains('_')) {
              mapped = formatted;
            }
          }

          if (mapped != null && mapped.isNotEmpty) {
            canonicalIds.add(mapped);
            if (sName.isNotEmpty && (!names.containsKey(mapped) || names[mapped]!.isEmpty)) {
              names[mapped] = sName;
            }
          } else {
            final raw = sDocId.isNotEmpty ? sDocId : (sId.isNotEmpty ? sId : (sSite.isNotEmpty ? sSite : doc.id));
            if (raw.isNotEmpty) {
              final resolved = await ExpenseService.resolveCanonicalSiteDocId(raw);
              if (resolved.isNotEmpty) {
                canonicalIds.add(resolved);
                if (sName.isNotEmpty && (!names.containsKey(resolved) || names[resolved]!.isEmpty)) {
                  names[resolved] = sName;
                }
              }
            }
          }
        }

        siteNameMap = names;
        siteIds = ExpenseService.sanitizeSiteIds(canonicalIds);

        await OfflineSyncService.cacheMasterData('sites_list', siteIds);
        await OfflineSyncService.cacheMasterData('sites_map', siteNameMap);
      } else {
        final cachedIds = await OfflineSyncService.getCachedMasterData('sites_list');
        final cachedMap = await OfflineSyncService.getCachedMasterData('sites_map');

        if (cachedIds is List) {
          siteIds = ExpenseService.sanitizeSiteIds(cachedIds.map((e) => e.toString()));
        }
        if (cachedMap is Map) {
          siteNameMap = Map<String, String>.from(cachedMap.map((k, v) => MapEntry(k.toString(), v.toString())));
        }
      }

      setState(() {
        isLoadingSites = false;
      });
    } catch (e) {
      final cachedIds = await OfflineSyncService.getCachedMasterData('sites_list');
      final cachedMap = await OfflineSyncService.getCachedMasterData('sites_map');

      if (cachedIds is List) {
        siteIds = ExpenseService.sanitizeSiteIds(cachedIds.map((e) => e.toString()));
      }
      if (cachedMap is Map) {
        siteNameMap = Map<String, String>.from(cachedMap.map((k, v) => MapEntry(k.toString(), v.toString())));
      }

      setState(() {
        isLoadingSites = false;
      });
    }
  }

  Widget _buildLabeledTextField(
    String label,
    TextEditingController controller, {
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
    IconData? prefixIcon,
    required bool isDesktop,
    required bool isTablet,
    required bool isMobile,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0A183D),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontSize: 13.5,
            color: Color(0xFF0A183D),
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: 'Enter $label',
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: primaryColor, size: 20.0)
                : null,
            filled: true,
            fillColor: enabled ? Colors.white : Colors.grey.shade100,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor, width: 1.8),
            ),
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _buildBillTable(bool isDesktop, bool isTablet, bool isMobile) {
    if (bills.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Icon(
                Icons.receipt_long_rounded,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 8),
              const Text(
                'No bills added yet',
                style: TextStyle(
                  color: Color(0xFF0A183D),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Fill bill details above and click "Add Bill to List"',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    double total = 0;
    for (var bill in bills) {
      try {
        total += double.parse(
          bill['billAmount']!.replaceAll(RegExp(r'[^0-9.]'), ''),
        );
      } catch (_) {}
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${bills.length} Bill(s) Added',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A183D),
                  fontSize: 13,
                ),
              ),
              Text(
                'Total: ₹${total.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: primaryColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: bills.length,
          itemBuilder: (context, index) {
            final bill = bills[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.receipt_rounded,
                      color: primaryColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bill['billVendor'] ?? 'Vendor',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A183D),
                            fontSize: 13.5,
                          ),
                        ),
                        Text(
                          'Bill No: ${bill['billNo'] ?? 'N/A'}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹${bill['billAmount'] ?? '0'}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: primaryColor,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFEF4444),
                      size: 18,
                    ),
                    onPressed: () => _removeBill(index),
                    tooltip: 'Remove Bill',
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  void _addBill() {
    final no = billNoController.text.trim();
    final vendor = billVendorController.text.trim();
    final amountStr = billAmountController.text.trim();

    if (no.isEmpty || vendor.isEmpty || amountStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all bill fields before adding.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      bills.add({
        'billNo': no,
        'billVendor': vendor,
        'billAmount': amountStr,
      });
      billNoController.clear();
      billVendorController.clear();
      billAmountController.clear();
    });
  }

  void _removeBill(int index) {
    setState(() {
      bills.removeAt(index);
    });
  }

  void _resetForm() {
    setState(() {
      selectedSiteId = null;
      selectedSupervisorId = null;
      selectedProjectStage = null;
      selectedDate = DateTime.now();
      supervisorController.clear();
      projectStageController.clear();
      billNoController.clear();
      billVendorController.clear();
      billAmountController.clear();
      bills.clear();
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
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

  void _showConfirmationDialog(bool isDesktop, bool isTablet, bool isMobile) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Confirm Submission',
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0A183D)),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Site: ${selectedSiteId ?? 'Not selected'}', style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569))),
                Text('Date: ${DateFormat('dd/MM/yyyy').format(selectedDate)}', style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569))),
                Text('Total Bills: ${bills.length}', style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569))),
                const SizedBox(height: 14),
                const Text(
                  'Are you sure you want to submit this expense entry?',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0A183D)),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Submit', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(context).pop();
                _submitExpenseData(isDesktop, isTablet, isMobile);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitExpenseData(bool isDesktop, bool isTablet, bool isMobile) async {
    if (isSubmitting) return;
    setState(() {
      isSubmitting = true;
    });

    if (selectedSiteId == null ||
        selectedSupervisorId == null ||
        selectedProjectStage == null ||
        bills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all details and add at least one bill.'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        isSubmitting = false;
      });
      return;
    }

    if (!OfflineSyncService().isOnline) {
      try {
        final dateStr = DateFormat('ddMMyyyy').format(selectedDate);
        final newDocId = '${selectedSiteId}_$dateStr';

        double newTotal = 0;
        final billsData = bills.map((bill) {
          double amount = 0;
          try {
            amount = double.parse(
              bill['billAmount']!.replaceAll(RegExp(r'[^0-9.]'), ''),
            );
          } catch (_) {}
          newTotal += amount;
          return {
            'billNo': bill['billNo'],
            'billVendor': bill['billVendor'],
            'billAmount': amount,
            'billDate': selectedDate.toIso8601String(),
            'billCopy': 'billURL',
          };
        }).toList();

        final collectionPath = FirestoreService.organizationEntries.path;

        final payload = {
          'siteId': selectedSiteId,
          'supervisorName': selectedSupervisorId,
          'projectStage': selectedProjectStage,
          'projectName': siteNameMap[selectedSiteId] ?? '',
          'entryDate': selectedDate.toIso8601String(),
          'bills': billsData,
          'totalAmount': newTotal,
        };

        await OfflineSyncService().enqueueOfflineEntry(
          moduleName: 'Organization Expenses',
          collectionPath: collectionPath,
          documentId: newDocId,
          payload: payload,
        );

        _resetForm();

        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.cloud_off_rounded, color: Color(0xFFF59E0B), size: 60.0),
                  SizedBox(height: 16.0),
                  Text(
                    'Saved Offline',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A183D),
                    ),
                  ),
                  SizedBox(height: 6.0),
                  Text(
                    'This entry will sync automatically when the network is available.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        debugPrint('Error saving offline expense entry: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save offline expense entry'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            isSubmitting = false;
          });
        }
      }
      return;
    }

    try {
      String projectName = '';
      try {
        final projectSnap = await FirestoreService.siteSupervisorMap
            .where('site', isEqualTo: selectedSiteId)
            .limit(1)
            .get();
        if (projectSnap.docs.isNotEmpty) {
          projectName = projectSnap.docs.first.data()['projectName'] ?? '';
        }
      } catch (_) {}

      final dateStr = DateFormat('ddMMyyyy').format(selectedDate);
      final newDocId = '${selectedSiteId}_$dateStr';

      final entryRef = FirestoreService.organizationEntries.doc(newDocId);
      final entrySnap = await entryRef.get();

      List<dynamic> existingBills = [];
      double existingTotal = 0;
      if (entrySnap.exists) {
        final data = entrySnap.data() as Map<String, dynamic>;
        existingBills = data['bills'] ?? [];
        existingTotal = (data['totalAmount'] ?? 0).toDouble();
      }

      double newTotal = 0;
      final billsData = bills.map((bill) {
        double amount = 0;
        try {
          amount = double.parse(
            bill['billAmount']!.replaceAll(RegExp(r'[^0-9.]'), ''),
          );
        } catch (_) {}
        newTotal += amount;
        return {
          'billNo': bill['billNo'],
          'billVendor': bill['billVendor'],
          'billAmount': amount,
          'billDate': Timestamp.fromDate(selectedDate),
          'billCopy': 'billURL',
        };
      }).toList();

      final allBills = [...existingBills, ...billsData];
      final totalAmount = existingTotal + newTotal;

      final entry = {
        'siteId': selectedSiteId,
        'supervisorName': selectedSupervisorId,
        'projectStage': selectedProjectStage,
        'projectName': projectName,
        'entryDate': Timestamp.now(),
        'bills': allBills,
        'totalAmount': totalAmount,
      };

      await entryRef.set(entry);

      double orgExpenseTotalAmount = 0;
      final allEntrySnap = await entryRef.get();
      if (allEntrySnap.exists) {
        final data = allEntrySnap.data() as Map<String, dynamic>;
        final billsList = data['bills'] as List<dynamic>? ?? [];
        for (var bill in billsList) {
          final amt = (bill['billAmount'] ?? 0).toDouble();
          orgExpenseTotalAmount += amt;
        }
      }

      final summary = {
        'date': selectedDate.toIso8601String(),
        'orgExpenseTotalAmount': orgExpenseTotalAmount,
        'projectName': projectName,
        'projectStage': selectedProjectStage ?? '',
        'siteId': selectedSiteId ?? '',
      };

      await FirestoreService.organizationExpenseSummary
          .doc(newDocId)
          .set(summary);

      await ExpenseService.updateTotalOrgExpenseForSite(selectedSiteId!);

      _resetForm();

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 60.0),
                const SizedBox(height: 16.0),
                const Text(
                  'Expense Data Submitted!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0A183D),
                  ),
                ),
                const SizedBox(height: 6.0),
                const Text(
                  'Organization expense record has been successfully updated.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  _tabController.animateTo(1);
                },
                child: const Text('View Logs', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving to Firestore: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit expense data'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  String _getFormattedSiteDisplay(String siteId) {
    if (siteId.isEmpty) return '';

    if (siteId.contains('_')) {
      final parts = siteId.split('_');
      final code = parts[0].trim();
      final namePart = parts.sublist(1).join('_').trim().replaceAll(' ', '');
      if (namePart.isNotEmpty) {
        final formattedName = namePart[0].toUpperCase() + namePart.substring(1);
        return '${code}_$formattedName';
      }
      return siteId.replaceAll(' ', '');
    }

    final sName = siteNameMap[siteId]?.trim();
    if (sName != null && sName.isNotEmpty && sName.toLowerCase() != siteId.toLowerCase()) {
      return ExpenseService.formatCanonicalSiteDocId(siteId, sName);
    }

    return siteId;
  }

  Future<String?> _resolveSupervisorId(Map<String, dynamic> data) async {
    final explicitId = data['Supervisor ID'] ??
        data['supervisorId'] ??
        data['SupervisorId'] ??
        data['supervisor_id'] ??
        data['assignedSupervisor'];

    if (explicitId != null && explicitId.toString().trim().isNotEmpty) {
      return explicitId.toString().trim();
    }

    final nameOrUser = data['Supervisor'] ??
        data['supervisor'] ??
        data['supervisorName'] ??
        data['FullName'] ??
        data['fullName'];

    if (nameOrUser != null && nameOrUser.toString().trim().isNotEmpty) {
      final clean = nameOrUser.toString().trim();
      try {
        final queries = [
          FirestoreService.supervisors.where('supervisor', isEqualTo: clean),
          FirestoreService.supervisors.where('supervisorName', isEqualTo: clean),
          FirestoreService.supervisors.where('FullName', isEqualTo: clean),
          FirestoreService.supervisors.where('fullName', isEqualTo: clean),
          FirestoreService.supervisors.where('username', isEqualTo: clean),
          FirestoreService.supervisors.where('UserName', isEqualTo: clean),
        ];
        for (var q in queries) {
          final snap = await q.get();
          if (snap.docs.isNotEmpty) {
            final supData = snap.docs.first.data();
            final id = supData['Supervisor ID'] ??
                supData['supervisorId'] ??
                supData['SupervisorId'] ??
                supData['supervisor_id'] ??
                snap.docs.first.id;
            if (id.toString().trim().isNotEmpty) return id.toString().trim();
          }
        }
      } catch (_) {}
      return clean;
    }

    return null;
  }

  Future<void> _loadSiteDetails(String siteId) async {
    if (!mounted) return;
    setState(() {
      isLoadingSiteDetails = true;
    });

    String? foundSupervisorId;
    String? foundProjectStage;

    try {
      final siteKeys = await ExpenseService.resolveSiteKeys(siteId);

      // 1. Check Site collection document for any matching alias
      for (final key in siteKeys) {
        final siteDoc = await FirestoreService.getCollection('Site').doc(key).get();
        if (siteDoc.exists && siteDoc.data() != null) {
          final data = siteDoc.data()!;
          foundProjectStage ??= (data['projectStage'] ?? data['stage'] ?? data['projectPhase'])?.toString().trim();
          foundSupervisorId ??= await _resolveSupervisorId(data);
          if (foundSupervisorId != null && foundProjectStage != null) break;
        }
      }

      // 2. Check siteSupervisorMap doc by doc ID == key
      if (foundSupervisorId == null || foundProjectStage == null) {
        for (final key in siteKeys) {
          final mapDoc = await FirestoreService.siteSupervisorMap.doc(key).get();
          if (mapDoc.exists && mapDoc.data() != null) {
            final data = mapDoc.data()!;
            foundProjectStage ??= (data['projectStage'] ?? data['stage'] ?? data['projectPhase'])?.toString().trim();
            foundSupervisorId ??= await _resolveSupervisorId(data);
            if (foundSupervisorId != null && foundProjectStage != null) break;
          }
        }
      }

      // 3. Query siteSupervisorMap by site / siteId / siteName / siteDocId fields across all siteKeys
      if (foundSupervisorId == null || foundProjectStage == null) {
        for (final key in siteKeys) {
          final queriesToTry = [
            FirestoreService.siteSupervisorMap.where('siteDocId', isEqualTo: key),
            FirestoreService.siteSupervisorMap.where('site', isEqualTo: key),
            FirestoreService.siteSupervisorMap.where('siteId', isEqualTo: key),
            FirestoreService.siteSupervisorMap.where('siteName', isEqualTo: key),
          ];

          for (var q in queriesToTry) {
            final snap = await q.get();
            if (snap.docs.isNotEmpty) {
              final data = snap.docs.first.data();
              foundProjectStage ??= (data['projectStage'] ?? data['stage'] ?? data['projectPhase'])?.toString().trim();
              foundSupervisorId ??= await _resolveSupervisorId(data);
              if (foundSupervisorId != null && foundProjectStage != null) break;
            }
          }
          if (foundSupervisorId != null && foundProjectStage != null) break;
        }
      }

      // 4. Broad scan in siteSupervisorMap if still missing
      if (foundSupervisorId == null || foundProjectStage == null) {
        final mapSnapshot = await FirestoreService.siteSupervisorMap.get();
        final lowerKeys = siteKeys.map((k) => k.toLowerCase().trim()).toSet();

        for (var doc in mapSnapshot.docs) {
          final data = doc.data();
          final dSite = (data['site'] ?? '').toString().toLowerCase().trim();
          final dSiteId = (data['siteId'] ?? '').toString().toLowerCase().trim();
          final dSiteName = (data['siteName'] ?? '').toString().toLowerCase().trim();
          final dDocId = doc.id.toLowerCase().trim();

          final matches = lowerKeys.contains(dSite) ||
              lowerKeys.contains(dSiteId) ||
              lowerKeys.contains(dSiteName) ||
              lowerKeys.contains(dDocId) ||
              lowerKeys.any((k) => dDocId.startsWith('${k}_') || dDocId.contains(k));

          if (matches) {
            foundProjectStage ??= (data['projectStage'] ?? data['stage'] ?? data['projectPhase'])?.toString().trim();
            foundSupervisorId ??= await _resolveSupervisorId(data);
            if (foundSupervisorId != null && foundProjectStage != null) break;
          }
        }
      }

      // 5. Check projects collection if still missing
      if (foundSupervisorId == null || foundProjectStage == null) {
        for (final key in siteKeys) {
          final projDoc = await FirestoreService.projects.doc(key).get();
          if (projDoc.exists && projDoc.data() != null) {
            final data = projDoc.data()!;
            foundProjectStage ??= (data['projectStage'] ?? data['stage'] ?? data['projectPhase'])?.toString().trim();
            foundSupervisorId ??= await _resolveSupervisorId(data);
            if (foundSupervisorId != null && foundProjectStage != null) break;
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading site details in organization expenses: $e');
    }

    if (!mounted) return;
    setState(() {
      selectedSupervisorId = (foundSupervisorId != null && foundSupervisorId.isNotEmpty)
          ? foundSupervisorId
          : 'Not Assigned';
      selectedProjectStage = (foundProjectStage != null && foundProjectStage.isNotEmpty)
          ? foundProjectStage
          : 'Not Assigned';

      supervisorController.text = selectedSupervisorId!;
      projectStageController.text = selectedProjectStage!;
      isLoadingSiteDetails = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Organization Expenses',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
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
      ),
      body: SafeArea(
        child: Column(
          children: [
            const OfflineSyncBanner(),
            _buildCustomTabBar(primaryColor),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildEntryTab(context, primaryColor, darkAccent, isDesktop, isTablet, isMobile),
                  _buildLogsTab(context, primaryColor, darkAccent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryTab(
    BuildContext context,
    Color primaryColor,
    Color darkAccent,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isDesktop ? 850.0 : (isTablet ? 680.0 : double.infinity),
        ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.all(isDesktop ? 28.0 : 16.0),
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
                            Icons.business_center_rounded,
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
                                'Organization Expenses',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0A183D),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Record company expenditure, vendor bills & project stage logs',
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
                  const SyncStatusCard(margin: EdgeInsets.only(top: 14)),
                  const SizedBox(height: 14),

                  // SECTION 1: SITE & PROJECT INFO
                  _buildSectionHeader(
                    title: '1. Site & Project Details',
                    subtitle: 'Choose site ID and verify supervisor/stage info',
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
                              initialValue: siteIds.contains(selectedSiteId) ? selectedSiteId : null,
                              isExpanded: true,
                              dropdownColor: Colors.white,
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: Color(0xFF0A183D),
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Select Site ID',
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w400,
                                ),
                                prefixIcon: Icon(
                                  Icons.business_rounded,
                                  color: primaryColor,
                                  size: 20.0,
                                ),
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
                              ),
                              items: siteIds.map((site) {
                                return DropdownMenuItem<String>(
                                  value: site,
                                  child: Text(
                                    _getFormattedSiteDisplay(site),
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF0A183D),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  selectedSiteId = value;
                                });
                                if (value != null) {
                                  _loadSiteDetails(value);
                                }
                              },
                            ),
                            const SizedBox(height: 14),
                          ],
                        ),
                  _buildLabeledTextField(
                    'Supervisor ID',
                    supervisorController,
                    enabled: false,
                    prefixIcon: Icons.person_rounded,
                    isDesktop: isDesktop,
                    isTablet: isTablet,
                    isMobile: isMobile,
                  ),
                  _buildLabeledTextField(
                    'Project Stage',
                    projectStageController,
                    enabled: false,
                    prefixIcon: Icons.flag_rounded,
                    isDesktop: isDesktop,
                    isTablet: isTablet,
                    isMobile: isMobile,
                  ),

                  // Date Picker Row
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
                      InkWell(
                        onTap: () => _selectDate(context),
                        borderRadius: BorderRadius.circular(12.0),
                        child: Container(
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
                                'Expense Date:',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                DateFormat('dd/MM/yyyy').format(selectedDate),
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0A183D),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const Divider(color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 16),

                  // SECTION 2: ADD BILL DETAILS
                  _buildSectionHeader(
                    title: '2. Add Bill Details',
                    subtitle: 'Enter vendor, bill number and amount',
                    icon: Icons.receipt_long_rounded,
                    color: Colors.indigo,
                  ),
                  const SizedBox(height: 16),
                  _buildLabeledTextField(
                    'Bill No',
                    billNoController,
                    prefixIcon: Icons.numbers_rounded,
                    isDesktop: isDesktop,
                    isTablet: isTablet,
                    isMobile: isMobile,
                  ),
                  _buildLabeledTextField(
                    'Bill Vendor',
                    billVendorController,
                    prefixIcon: Icons.store_rounded,
                    isDesktop: isDesktop,
                    isTablet: isTablet,
                    isMobile: isMobile,
                  ),
                  _buildLabeledTextField(
                    'Bill Amount',
                    billAmountController,
                    prefixIcon: Icons.currency_rupee_rounded,
                    keyboardType: TextInputType.number,
                    isDesktop: isDesktop,
                    isTablet: isTablet,
                    isMobile: isMobile,
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _addBill,
                      icon: const Icon(
                        Icons.add_circle_outline_rounded,
                        color: Colors.white,
                        size: 20.0,
                      ),
                      label: const Text(
                        "Add Bill to List",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        elevation: 2.0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Divider(color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 16),

                  // SECTION 3: BILLS OVERVIEW
                  _buildSectionHeader(
                    title: '3. Expense Bills Overview',
                    subtitle: 'Review added bills before final submission',
                    icon: Icons.list_alt_rounded,
                    color: Colors.teal,
                  ),
                  const SizedBox(height: 16),
                  _buildBillTable(isDesktop, isTablet, isMobile),

                  const SizedBox(height: 28),

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
                            onPressed: isSubmitting
                                ? null
                                : () {
                                    if (selectedSiteId == null ||
                                        selectedSupervisorId == null ||
                                        selectedProjectStage == null ||
                                        bills.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Please fill all details and add at least one bill.',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }
                                    _showConfirmationDialog(isDesktop, isTablet, isMobile);
                                  },
                            icon: const Icon(Icons.check_circle_rounded, size: 20),
                            label: isSubmitting
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
                                    'Submit Expenses',
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
                            onPressed: isSubmitting ? null : _resetForm,
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
                ],
              ),
            ),
          ),
        );
  }

  // --- CUSTOM TAB BAR ---
  Widget _buildCustomTabBar(Color primaryColor) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: primaryColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.28),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF64748B),
        labelStyle: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        tabs: const [
          Tab(
            iconMargin: EdgeInsets.only(bottom: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.edit_document, size: 17),
                SizedBox(width: 8),
                Text('Expense Entry'),
              ],
            ),
          ),
          Tab(
            iconMargin: EdgeInsets.only(bottom: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_rounded, size: 17),
                SizedBox(width: 8),
                Text('Expense Logs'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- LOGS TAB ---
  Widget _buildLogsTab(
      BuildContext context, Color primaryColor, Color darkAccent) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.organizationEntries.snapshots(),
      builder: (context, orgSnap) {
        if (orgSnap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Error loading expense logs: ${orgSnap.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        if (orgSnap.connectionState == ConnectionState.waiting &&
            !orgSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirestoreService.getCollection('organizationExpenses').snapshots(),
          builder: (context, altOrgSnap) {
            final Map<String, Map<String, dynamic>> dedupedMap = {};

            void processDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc, String source) {
              final data = doc.data();
              final docId = doc.id;
              if (dedupedMap.containsKey(docId)) return;

              final siteId = (data['siteId'] ??
                      data['site'] ??
                      docId.split('_').firstOrNull ??
                      'N/A')
                  .toString();
              final projectName = (data['projectName'] ??
                      data['project'] ??
                      siteNameMap[siteId] ??
                      'Unnamed Project')
                  .toString();
              final siteName = siteNameMap[siteId] ?? projectName;
              final projectStage = (data['projectStage'] ??
                      data['stage'] ??
                      data['category'] ??
                      'General')
                  .toString();
              final supervisorName = (data['supervisorName'] ??
                      data['supervisor'] ??
                      data['raisedByName'] ??
                      data['raisedBy'] ??
                      'Organization Admin')
                  .toString();
              final raisedById = (data['raisedById'] ??
                      data['orgId'] ??
                      data['userId'] ??
                      'Organization')
                  .toString();
              final userRole = (data['userRole'] ??
                      data['role'] ??
                      'Organization')
                  .toString();

              final rawEntryDate = data['entryDate'] ??
                  data['createdAt'] ??
                  data['date'] ??
                  data['timestamp'];
              DateTime recordDate = DateTime.now();
              if (rawEntryDate is Timestamp) {
                recordDate = rawEntryDate.toDate();
              } else if (rawEntryDate is String) {
                recordDate = DateTime.tryParse(rawEntryDate) ?? DateTime.now();
              }

              final rawBills = data['bills'] as List<dynamic>? ?? [];
              final List<Map<String, dynamic>> parsedBills = [];
              double totalAmt = 0.0;

              for (var b in rawBills) {
                if (b is Map) {
                  final bAmt = _parseNum(b['billAmount'] ?? b['amount']).toDouble();
                  totalAmt += bAmt;

                  DateTime bDate = recordDate;
                  final rawBDate = b['billDate'];
                  if (rawBDate is Timestamp) {
                    bDate = rawBDate.toDate();
                  } else if (rawBDate is String) {
                    bDate = DateTime.tryParse(rawBDate) ?? recordDate;
                  }

                  DateTime? bCreatedAt;
                  final rawBCreatedAt = b['createdAt'];
                  if (rawBCreatedAt is Timestamp) {
                    bCreatedAt = rawBCreatedAt.toDate();
                  }

                  parsedBills.add({
                    'billNo': (b['billNo'] ?? 'N/A').toString(),
                    'billVendor': (b['billVendor'] ?? b['vendor'] ?? 'Vendor').toString(),
                    'billAmount': bAmt,
                    'billCopy': (b['billCopy'] ?? '').toString(),
                    'billDate': bDate,
                    'createdAt': bCreatedAt ?? recordDate,
                    'raisedBy': (b['raisedBy'] ?? raisedById).toString(),
                    'raisedByName': (b['raisedByName'] ?? supervisorName).toString(),
                    'userRole': (b['userRole'] ?? userRole).toString(),
                  });
                }
              }

              if (totalAmt == 0.0 && data['totalAmount'] != null) {
                totalAmt = _parseNum(data['totalAmount']).toDouble();
              } else if (totalAmt == 0.0 && data['orgExpenseTotalAmount'] != null) {
                totalAmt = _parseNum(data['orgExpenseTotalAmount']).toDouble();
              } else if (totalAmt == 0.0 && data['amount'] != null) {
                totalAmt = _parseNum(data['amount']).toDouble();
              }

              dedupedMap[docId] = {
                'docId': docId,
                'source': source,
                'siteId': siteId,
                'siteName': siteName,
                'projectName': projectName,
                'projectStage': projectStage,
                'supervisorName': supervisorName,
                'raisedById': raisedById,
                'raisedByName': supervisorName,
                'userRole': userRole,
                'totalAmount': totalAmt,
                'recordDate': recordDate,
                'bills': parsedBills,
                'rawData': data,
              };
            }

            if (orgSnap.hasData) {
              for (var doc in orgSnap.data!.docs) {
                processDoc(doc, 'Organization Entries');
              }
            }
            if (altOrgSnap.hasData) {
              for (var doc in altOrgSnap.data!.docs) {
                processDoc(doc, 'Organization Expenses');
              }
            }

            final List<Map<String, dynamic>> allLogs = dedupedMap.values.toList();

            // Sort logs descending (newest first)
            allLogs.sort((a, b) {
              final DateTime dateA = a['recordDate'] as DateTime;
              final DateTime dateB = b['recordDate'] as DateTime;
              return dateB.compareTo(dateA);
            });

            // Available stages for filtering
            final Set<String> availableStages = {'All'};
            for (var log in allLogs) {
              final st = log['projectStage'].toString().trim();
              if (st.isNotEmpty && st != 'N/A') {
                availableStages.add(st);
              }
            }

            // Apply filters & search
            final filteredLogs = allLogs.where((log) {
              final query = _logSearchQuery.toLowerCase();
              final matchesSearch = query.isEmpty ||
                  log['siteId'].toString().toLowerCase().contains(query) ||
                  log['siteName'].toString().toLowerCase().contains(query) ||
                  log['projectName'].toString().toLowerCase().contains(query) ||
                  log['projectStage'].toString().toLowerCase().contains(query) ||
                  log['supervisorName'].toString().toLowerCase().contains(query) ||
                  log['raisedById'].toString().toLowerCase().contains(query) ||
                  (log['bills'] as List<Map<String, dynamic>>).any((b) =>
                      b['billNo'].toString().toLowerCase().contains(query) ||
                      b['billVendor'].toString().toLowerCase().contains(query));

              final matchesSite = _selectedLogSite == 'All' ||
                  log['siteId'].toString().toLowerCase() ==
                      _selectedLogSite.toLowerCase();

              final matchesStage = _selectedLogStage == 'All' ||
                  log['projectStage'].toString().toLowerCase() ==
                      _selectedLogStage.toLowerCase();

              bool matchesDate = true;
              final now = DateTime.now();
              final logDate = log['recordDate'] as DateTime;
              if (_selectedLogDateFilter == 'Today') {
                matchesDate = logDate.year == now.year &&
                    logDate.month == now.month &&
                    logDate.day == now.day;
              } else if (_selectedLogDateFilter == 'This Month') {
                matchesDate =
                    logDate.year == now.year && logDate.month == now.month;
              }

              return matchesSearch && matchesSite && matchesStage && matchesDate;
            }).toList();

            // Calculate KPI totals
            double totalExpenseSum = 0.0;
            int totalBillsCount = 0;
            final Set<String> uniqueSites = {};

            for (var log in filteredLogs) {
              totalExpenseSum += (log['totalAmount'] as double);
              totalBillsCount += (log['bills'] as List).length;
              uniqueSites.add(log['siteId'].toString());
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 1024;
                final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 1024;

                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 900.0 : (isTablet ? 720.0 : double.infinity),
                    ),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        isDesktop ? 28.0 : 16.0,
                        12.0,
                        isDesktop ? 28.0 : 16.0,
                        40.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // KPI Summary Header Banner
                          _buildLogsKpiHeader(
                            primaryColor: primaryColor,
                            darkAccent: darkAccent,
                            totalExpense: totalExpenseSum,
                            totalLogs: filteredLogs.length,
                            totalBills: totalBillsCount,
                            totalSites: uniqueSites.length,
                          ),
                          const SizedBox(height: 18),

                          // Filter & Search Controls
                          _buildLogsFilterControls(primaryColor, availableStages.toList()),
                          const SizedBox(height: 16),

                          // Section Title & Count Badge
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: primaryColor,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Activity Logs & Audit Records',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: primaryColor.withValues(alpha: 0.16)),
                                ),
                                child: Text(
                                  '${filteredLogs.length} Records',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Logs List or Empty State
                          if (filteredLogs.isEmpty)
                            _buildEmptyLogsState(primaryColor)
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filteredLogs.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 14),
                              itemBuilder: (context, index) {
                                final log = filteredLogs[index];
                                return _buildExpenseLogCard(
                                  log: log,
                                  primaryColor: primaryColor,
                                  onTap: () => _showLogDetailsModal(context, log),
                                );
                              },
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
      },
    );
  }

  // --- LOGS KPI HEADER ---
  Widget _buildLogsKpiHeader({
    required Color primaryColor,
    required Color darkAccent,
    required double totalExpense,
    required int totalLogs,
    required int totalBills,
    required int totalSites,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            darkAccent,
            Color.alphaBlend(primaryColor.withValues(alpha: 0.45), darkAccent),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: darkAccent.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.analytics_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Organization Expense Audit',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.25)),
                ),
                child: const Text(
                  'Live Sync',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Text(
            '₹${_formatCurrency(totalExpense)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),
          const Text(
            'Total Logged Organization Expenditure',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLogsKpiSubItem(
                label: 'Total Logs',
                value: '$totalLogs',
                icon: Icons.receipt_long_rounded,
              ),
              _buildLogsKpiSubItem(
                label: 'Attached Bills',
                value: '$totalBills',
                icon: Icons.attach_file_rounded,
              ),
              _buildLogsKpiSubItem(
                label: 'Active Sites',
                value: '$totalSites',
                icon: Icons.domain_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogsKpiSubItem({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 14),
            const SizedBox(width: 5),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // --- LOGS FILTER CONTROLS ---
  Widget _buildLogsFilterControls(Color primaryColor, List<String> stageList) {
    final List<String> siteFilterList = ['All', ...siteIds];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Input
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: _logSearchController,
              onChanged: (val) {
                setState(() => _logSearchQuery = val.trim());
              },
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: 'Search by Supervisor, Vendor, Bill No, Site...',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade400,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: primaryColor,
                  size: 18,
                ),
                suffixIcon: _logSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () {
                          _logSearchController.clear();
                          setState(() => _logSearchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Filter Dropdowns Row
          Row(
            children: [
              // Site Dropdown
              Expanded(
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: siteFilterList.contains(_selectedLogSite)
                          ? _selectedLogSite
                          : 'All',
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down_rounded,
                          color: Color(0xFF64748B), size: 20),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      items: siteFilterList
                          .map((site) => DropdownMenuItem<String>(
                                value: site,
                                child: Text(
                                  site == 'All' ? 'All Sites' : site,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedLogSite = val);
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Stage Dropdown
              Expanded(
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: stageList.contains(_selectedLogStage)
                          ? _selectedLogStage
                          : 'All',
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down_rounded,
                          color: Color(0xFF64748B), size: 20),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      items: stageList
                          .map((stage) => DropdownMenuItem<String>(
                                value: stage,
                                child: Text(
                                  stage == 'All' ? 'All Stages' : stage,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedLogStage = val);
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Date Timeline Filter
              Expanded(
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedLogDateFilter,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down_rounded,
                          color: Color(0xFF64748B), size: 20),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      items: ['All Time', 'Today', 'This Month']
                          .map((filter) => DropdownMenuItem<String>(
                                value: filter,
                                child: Text(filter,
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedLogDateFilter = val);
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- LOG CARD COMPONENT ---
  Widget _buildExpenseLogCard({
    required Map<String, dynamic> log,
    required Color primaryColor,
    required VoidCallback onTap,
  }) {
    final String supervisorName = log['supervisorName']?.toString() ?? 'Organization Admin';
    final String raisedById = log['raisedById']?.toString() ?? 'Organization';
    final String userRole = log['userRole']?.toString() ?? 'Organization';
    final String siteId = log['siteId']?.toString() ?? 'N/A';
    final String siteName = log['siteName']?.toString() ?? siteId;
    final String projectStage = log['projectStage']?.toString() ?? 'General';
    final double totalAmount = (log['totalAmount'] is num) ? (log['totalAmount'] as num).toDouble() : 0.0;
    final DateTime recordDate = log['recordDate'] as DateTime;
    final List<Map<String, dynamic>> billsList =
        (log['bills'] as List).cast<Map<String, dynamic>>();

    const roleColor = Color(0xFF0284C7);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Role Badge, Supervisor & Timestamp
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              roleColor.withValues(alpha: 0.18),
                              roleColor.withValues(alpha: 0.08),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: roleColor.withValues(alpha: 0.25),
                            width: 1.2,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.corporate_fare_rounded,
                            color: roleColor,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    supervisorName,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                      letterSpacing: -0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: roleColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    userRole.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: roleColor,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'Logged by: $raisedById',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Date & Time Chip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule_rounded,
                          size: 12, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd MMM, hh:mm a').format(recordDate),
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFFF1F5F9), height: 1),
            const SizedBox(height: 12),

            // Middle: Site & Stage Badges + Expense Amount
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(6),
                              border:
                                  Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.apartment_rounded,
                                    size: 12, color: Color(0xFF059669)),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    siteId,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF059669),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (projectStage != 'N/A' && projectStage.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: const Color(0xFFBFDBFE)),
                                ),
                                child: Text(
                                  projectStage,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1D4ED8),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        siteName,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Total Amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${_formatCurrency(totalAmount)}',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: primaryColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      '${billsList.length} ${billsList.length == 1 ? "Bill" : "Bills"} logged',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Itemized Bills Chips / Preview if present
            if (billsList.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: billsList.take(2).map((bill) {
                    final vendor = bill['billVendor']?.toString() ?? 'Vendor';
                    final bNo = bill['billNo']?.toString() ?? 'N/A';
                    final bAmt = (bill['billAmount'] is num)
                        ? (bill['billAmount'] as num).toDouble()
                        : 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Icon(Icons.receipt_rounded,
                              size: 14, color: primaryColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '$vendor ($bNo)',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '₹${_formatCurrency(bAmt)}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            const SizedBox(height: 10),
            // Bottom Action Bar: View Audit Details Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Text(
                      'View Audit Breakdown',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: primaryColor,
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

  // --- LOG DETAILS MODAL ---
  void _showLogDetailsModal(BuildContext context, Map<String, dynamic> log) {
    final String supervisorName = log['supervisorName']?.toString() ?? 'Organization Admin';
    final String raisedById = log['raisedById']?.toString() ?? 'Organization';
    final String userRole = log['userRole']?.toString() ?? 'Organization';
    final String siteId = log['siteId']?.toString() ?? 'N/A';
    final String siteName = log['siteName']?.toString() ?? siteId;
    final String projectName = log['projectName']?.toString() ?? 'N/A';
    final String projectStage = log['projectStage']?.toString() ?? 'N/A';
    final double totalAmount = (log['totalAmount'] is num) ? (log['totalAmount'] as num).toDouble() : 0.0;
    final DateTime recordDate = log['recordDate'] as DateTime;
    final List<Map<String, dynamic>> billsList =
        (log['bills'] as List).cast<Map<String, dynamic>>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Modal Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 42,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),

                // Modal Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Expense Audit Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.4,
                            ),
                          ),
                          Text(
                            'Detailed raiser info and itemized bill copies',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            size: 22, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // Modal Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // User Raiser Profile Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ORGANIZATION AUDIT PROFILE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor:
                                        primaryColor.withValues(alpha: 0.15),
                                    child: Icon(Icons.corporate_fare_rounded,
                                        color: primaryColor, size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          supervisorName,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        Text(
                                          '$userRole • Logged ID: $raisedById',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Site & Timestamp Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              _buildModalInfoRow(
                                  'Site ID', siteId, Icons.business_rounded),
                              const Divider(
                                  height: 14, color: Color(0xFFF1F5F9)),
                              _buildModalInfoRow('Site Name', siteName,
                                  Icons.location_on_rounded),
                              const Divider(
                                  height: 14, color: Color(0xFFF1F5F9)),
                              _buildModalInfoRow('Project', projectName,
                                  Icons.assignment_rounded),
                              const Divider(
                                  height: 14, color: Color(0xFFF1F5F9)),
                              _buildModalInfoRow('Project Stage', projectStage,
                                  Icons.timeline_rounded),
                              const Divider(
                                  height: 14, color: Color(0xFFF1F5F9)),
                              _buildModalInfoRow(
                                'Recorded Date & Time',
                                DateFormat('dd MMM yyyy, hh:mm a')
                                    .format(recordDate),
                                Icons.calendar_today_rounded,
                              ),
                              const Divider(
                                  height: 14, color: Color(0xFFF1F5F9)),
                              _buildModalInfoRow(
                                'Total Expense',
                                '₹${_formatCurrency(totalAmount)}',
                                Icons.currency_rupee_rounded,
                                isBoldValue: true,
                                valueColor: primaryColor,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Itemized Bills Title
                        Text(
                          'Itemized Bills (${billsList.length})',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Itemized Bills List
                        if (billsList.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'No individual bills attached for this entry.',
                              style: TextStyle(
                                  fontSize: 13, color: Color(0xFF64748B)),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: billsList.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final b = billsList[index];
                              final vendor =
                                  b['billVendor']?.toString() ?? 'Vendor';
                              final bNo = b['billNo']?.toString() ?? 'N/A';
                              final bAmt = (b['billAmount'] is num)
                                  ? (b['billAmount'] as num).toDouble()
                                  : 0.0;
                              final bCopy = b['billCopy']?.toString() ?? '';
                              final bDate = b['billDate'] as DateTime?;

                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border:
                                      Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            vendor,
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '₹${_formatCurrency(bAmt)}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            color: primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          'Bill No: $bNo',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                        if (bDate != null) ...[
                                          const Text(' • ',
                                              style: TextStyle(
                                                  color: Color(0xFF94A3B8))),
                                          Text(
                                            DateFormat('dd MMM yyyy')
                                                .format(bDate),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (bCopy.isNotEmpty &&
                                        bCopy != 'billURL') ...[
                                      const SizedBox(height: 8),
                                      InkWell(
                                        onTap: () {
                                          _showBillImagePreview(context, bCopy);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: primaryColor
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.image_rounded,
                                                  size: 14,
                                                  color: primaryColor),
                                              const SizedBox(width: 4),
                                              Text(
                                                'View Attached Bill Copy',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: primaryColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModalInfoRow(
    String label,
    String value,
    IconData icon, {
    bool isBoldValue = false,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: isBoldValue ? 14 : 12.5,
              fontWeight: isBoldValue ? FontWeight.w800 : FontWeight.w700,
              color: valueColor ?? const Color(0xFF0F172A),
            ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showBillImagePreview(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Bill Attachment',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              backgroundColor: Colors.transparent,
              elevation: 0,
              foregroundColor: const Color(0xFF0F172A),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      children: const [
                        Icon(Icons.broken_image_rounded,
                            size: 40, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('Unable to load bill image preview',
                            style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyLogsState(Color primaryColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded, size: 54, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text(
            'No expense logs found',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Organization expense records and bills logged for sites will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          if (_logSearchQuery.isNotEmpty ||
              _selectedLogSite != 'All' ||
              _selectedLogStage != 'All' ||
              _selectedLogDateFilter != 'All Time') ...[
            const SizedBox(height: 16),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: primaryColor.withValues(alpha: 0.3)),
                ),
              ),
              onPressed: () {
                _logSearchController.clear();
                setState(() {
                  _logSearchQuery = '';
                  _selectedLogSite = 'All';
                  _selectedLogStage = 'All';
                  _selectedLogDateFilter = 'All Time';
                });
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text(
                'Reset Filters',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatCurrency(num value) {
    if (value == 0) return '0.00';
    final isNegative = value < 0;
    final absVal = value.abs();
    final parts = absVal.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];

    if (intPart.length <= 3) {
      final res = '$intPart.$decPart';
      return isNegative ? '-$res' : res;
    }

    final last3 = intPart.substring(intPart.length - 3);
    final remaining = intPart.substring(0, intPart.length - 3);
    final buffer = StringBuffer();
    for (int i = 0; i < remaining.length; i++) {
      if (i > 0 && (remaining.length - i) % 2 == 0) {
        buffer.write(',');
      }
      buffer.write(remaining[i]);
    }
    buffer.write(',');
    buffer.write(last3);
    final res = '${buffer.toString()}.$decPart';
    return isNegative ? '-$res' : res;
  }

  num _parseNum(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val;
    final s = val.toString().replaceAll(',', '').trim();
    return num.tryParse(s) ?? 0;
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
}
