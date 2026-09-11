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

class OrganizationExpensesState extends State<OrganizationExpenses> {
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

  Color get primaryColor => Theme.of(context).colorScheme.primary;

  @override
  void initState() {
    super.initState();
    _loadSiteIds();
  }

  @override
  void dispose() {
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
            onPressed: _loadSiteIds,
            tooltip: 'Refresh Sites',
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
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
}
