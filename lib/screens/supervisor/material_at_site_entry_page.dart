import 'package:flutter/material.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/services/material_inventory_service.dart';
import 'package:demo_cst/utils/app_theme.dart';

class MaterialAtSiteEntryPage extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;

  const MaterialAtSiteEntryPage({
    super.key,
    required this.supervisorId,
    required this.supervisorName,
  });

  @override
  State<MaterialAtSiteEntryPage> createState() =>
      _MaterialAtSiteEntryPageState();
}

class _MaterialAtSiteEntryPageState extends State<MaterialAtSiteEntryPage> {
  // Theme helper
  Color get primaryColor => Theme.of(context).colorScheme.primary;

  // Site state - Site ID only (e.g. ST001_shek)
  List<String> assignedSiteIds = [];
  String? selectedSiteId;

  // Transferred Materials Inventory state
  List<Map<String, dynamic>> transferredMaterials = [];
  bool isLoadingSites = true;
  bool isLoadingMaterials = false;
  String? errorMsg;
  String searchQuery = '';
  final TextEditingController searchController = TextEditingController();

  // Selected Material for details popup/card
  Map<String, dynamic>? selectedMaterialDetail;

  @override
  void initState() {
    super.initState();
    fetchAssignedSites();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  /// Safely extracts the clean Site ID (e.g. ST001_shek) from document data, ignoring physical location/address strings
  String _extractCleanSiteId(Map<String, dynamic> data, String docId) {
    final location = (data['location'] ?? '').toString().trim();
    final site = (data['site'] ?? '').toString().trim();
    final siteId = (data['siteId'] ?? '').toString().trim();

    // Prefer 'site' or 'siteId' if it does not match the full address/location
    if (site.isNotEmpty && site != location) {
      return site;
    }
    if (siteId.isNotEmpty && siteId != location) {
      return siteId;
    }
    if (docId.isNotEmpty && docId != location) {
      return docId.trim();
    }
    return site.isNotEmpty ? site : (siteId.isNotEmpty ? siteId : docId);
  }

  /// Fetches sites assigned to the current supervisor from `siteSupervisorMap`
  Future<void> fetchAssignedSites() async {
    setState(() {
      isLoadingSites = true;
      errorMsg = null;
    });

    try {
      if (!FirestoreService.isReady) {
        await FirestoreService.initialize();
      }

      final query = FirestoreService.siteSupervisorMap;

      // Query by Supervisor ID first
      var snapshot = await query
          .where('Supervisor ID', isEqualTo: widget.supervisorId)
          .get();

      // Fallback by supervisor name
      if (snapshot.docs.isEmpty) {
        snapshot = await query
            .where('supervisor', isEqualTo: widget.supervisorName)
            .get();
      }

      List<String> parsedSiteIds = [];

      if (snapshot.docs.isNotEmpty) {
        for (final doc in snapshot.docs) {
          final sId = _extractCleanSiteId(doc.data(), doc.id);
          if (sId.isNotEmpty) {
            parsedSiteIds.add(sId);
          }
        }
      } else {
        // Broad search across all siteSupervisorMap documents
        final allDocs = await query.get();
        for (final doc in allDocs.docs) {
          final data = doc.data();
          final supId = (data['Supervisor ID'] ?? '').toString().trim().toLowerCase();
          final supName = (data['supervisor'] ?? data['supervisorName'] ?? '').toString().trim().toLowerCase();

          if (supId == widget.supervisorId.toLowerCase() ||
              supName == widget.supervisorName.toLowerCase() ||
              widget.supervisorId.isEmpty) {
            final sId = _extractCleanSiteId(data, doc.id);
            if (sId.isNotEmpty) {
              parsedSiteIds.add(sId);
            }
          }
        }

        // If still empty, list all available site IDs so supervisor can select
        if (parsedSiteIds.isEmpty && allDocs.docs.isNotEmpty) {
          for (final doc in allDocs.docs) {
            final sId = _extractCleanSiteId(doc.data(), doc.id);
            if (sId.isNotEmpty) {
              parsedSiteIds.add(sId);
            }
          }
        }
      }

      // Deduplicate site IDs
      final uniqueSiteIds = parsedSiteIds.toSet().toList();

      if (mounted) {
        setState(() {
          assignedSiteIds = uniqueSiteIds;
          isLoadingSites = false;
          if (uniqueSiteIds.isNotEmpty) {
            selectedSiteId = uniqueSiteIds.first;
          }
        });

        if (selectedSiteId != null) {
          await fetchSiteStockFromMaterialTransfer(selectedSiteId!);
        }
      }
    } catch (e) {
      debugPrint('Error fetching assigned sites: $e');
      if (mounted) {
        setState(() {
          isLoadingSites = false;
          errorMsg = "Failed to load assigned sites: ${e.toString()}";
        });
      }
    }
  }

  /// Fetches material data directly from `materialTransfer` collection,
  /// using the selected site's `siteId` (e.g. ST001_shek) to match the entry in `siteInventories` array.
  Future<void> fetchSiteStockFromMaterialTransfer(String siteId) async {
    final cleanSiteId = siteId.trim();
    if (cleanSiteId.isEmpty) {
      setState(() {
        transferredMaterials = [];
        isLoadingMaterials = false;
      });
      return;
    }

    setState(() {
      isLoadingMaterials = true;
      errorMsg = null;
      selectedMaterialDetail = null;
    });

    try {
      if (!FirestoreService.isReady) {
        await FirestoreService.initialize();
      }

      final Map<String, Map<String, dynamic>> siteMaterialsMap = {};

      // 1. Fetch directly from universal siteMaterialPool
      final poolItems = await MaterialInventoryService.fetchSiteMaterialPool(cleanSiteId);
      for (final p in poolItems) {
        final docKey = p.materialName.toLowerCase().trim();
        siteMaterialsMap[docKey] = {
          'materialId': p.id,
          'materialName': p.materialName,
          'displayName': p.materialName,
          'category': p.category,
          'unit': p.unit,
          'availableCount': p.remainingQty.toInt(),
          'siteAvailableCount': p.remainingQty.toInt(),
          'remainingQty': p.remainingQty,
          'allocatedQty': p.allocatedQty,
          'consumedQty': p.consumedQty,
          'effectiveUnitRate': p.effectiveUnitRate,
          'allocatedAmount': p.allocatedAmount,
          'consumedAmount': p.consumedAmount,
          'remainingAmount': p.remainingAmount,
          'companyAvailableCount': 0,
          'totalAvailableCount': p.remainingQty.toInt(),
          'siteId': cleanSiteId,
          'projectName': '',
        };
      }

      // 2. Fallback / Merge with legacy materialTransfer & materialsAvailability
      final transferSnap = await FirestoreService.getCollection('materialTransfer').get();
      final availSnap = await FirestoreService.getCollection('materialsAvailability').get();
      final allDocs = [...transferSnap.docs, ...availSnap.docs];

      for (final doc in allDocs) {
        final data = doc.data();
        final matName = (data['materialName'] ?? data['displayName'] ?? doc.id).toString().trim();
        if (matName.isEmpty) continue;
        final docKey = matName.toLowerCase().trim();
        if (siteMaterialsMap.containsKey(docKey)) continue;

        final rawSites = data['siteInventories'];
        if (rawSites is! List) continue;

        for (final s in rawSites) {
          if (s is! Map) continue;
          final sMap = Map<String, dynamic>.from(s);
          final sId = (sMap['siteId'] ?? sMap['siteid'] ?? '').toString().trim();
          final sName = (sMap['siteName'] ?? sMap['sitename'] ?? '').toString().trim();

          final cleanLow = cleanSiteId.toLowerCase();
          final sIdLow = sId.toLowerCase();
          final sNameLow = sName.toLowerCase();

          final bool isMatch = sIdLow == cleanLow ||
              (sNameLow.isNotEmpty && sNameLow == cleanLow) ||
              (cleanLow.contains('_') && sIdLow.isNotEmpty && (cleanLow.startsWith('$sIdLow' '_') || cleanLow.endsWith('_$sIdLow'))) ||
              (cleanLow.contains('_') && sNameLow.isNotEmpty && (cleanLow.startsWith('$sNameLow' '_') || cleanLow.endsWith('_$sNameLow'))) ||
              (sIdLow.contains('_') && cleanLow.isNotEmpty && (sIdLow.startsWith('$cleanLow' '_') || sIdLow.endsWith('_$cleanLow')));

          if (isMatch) {
            final availableCount = (sMap['availableCount'] as num?)?.toInt() ??
                (sMap['count'] as num?)?.toInt() ??
                (sMap['quantity'] as num?)?.toInt() ??
                int.tryParse((sMap['availableCount'] ?? sMap['count'] ?? '0').toString()) ??
                0;

            final unit = (data['unit'] ?? data['materialUnit'] ?? 'Bags').toString().trim();
            final displayName = (data['displayName'] ?? data['materialName'] ?? matName).toString().trim();
            final materialId = (data['materialId'] ?? doc.id).toString().trim();
            final category = (data['category'] ?? data['materialCategory'] ?? '').toString().trim();
            final companyAvailableCount = (data['companyAvailableCount'] as num?)?.toInt() ?? 0;
            final totalAvailableCount = (data['totalAvailableCount'] as num?)?.toInt() ?? (companyAvailableCount + availableCount);

            siteMaterialsMap[docKey] = {
              'materialId': materialId,
              'materialName': matName,
              'displayName': displayName.isNotEmpty ? displayName : matName,
              'category': category,
              'unit': unit,
              'availableCount': availableCount,
              'siteAvailableCount': availableCount,
              'remainingQty': availableCount.toDouble(),
              'allocatedQty': availableCount.toDouble(),
              'consumedQty': 0.0,
              'effectiveUnitRate': (data['unitPrice'] as num?)?.toDouble() ??
                  double.tryParse((data['materialPrice'] ?? '0').toString()) ??
                  (sMap['unitPrice'] as num?)?.toDouble() ??
                  0.0,
              'allocatedAmount': 0.0,
              'consumedAmount': 0.0,
              'remainingAmount': 0.0,
              'companyAvailableCount': companyAvailableCount,
              'totalAvailableCount': totalAvailableCount,
              'siteId': sId.isNotEmpty ? sId : cleanSiteId,
              'projectName': (sMap['projectName'] ?? '').toString(),
            };
            break;
          }
        }
      }

      final list = siteMaterialsMap.values.toList();
      list.sort((a, b) => (a['displayName'] as String).toLowerCase().compareTo((b['displayName'] as String).toLowerCase()));

      if (mounted) {
        setState(() {
          transferredMaterials = list;
          isLoadingMaterials = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching site materials from materialTransfer: $e');
      if (mounted) {
        setState(() {
          isLoadingMaterials = false;
          errorMsg = "Failed to load material stock: ${e.toString()}";
        });
      }
    }
  }

  void _onSiteChanged(String? newSiteId) async {
    if (newSiteId == null || newSiteId == selectedSiteId) return;

    setState(() {
      selectedSiteId = newSiteId;
      searchQuery = '';
      searchController.clear();
      selectedMaterialDetail = null;
    });

    await fetchSiteStockFromMaterialTransfer(newSiteId);
  }

  /// Opens detailed stock popup for a selected material
  void _showMaterialDetailsSheet(Map<String, dynamic> mat) {
    setState(() {
      selectedMaterialDetail = mat;
    });

    final matName = (mat['displayName'] ?? mat['materialName'] ?? '').toString();
    final count = mat['availableCount'] as int? ?? 0;
    final unit = (mat['unit'] ?? 'Bags').toString();
    final materialId = (mat['materialId'] ?? '').toString();
    final siteId = (mat['siteId'] ?? selectedSiteId ?? '').toString();
    final isAvailable = count > 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isAvailable
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.inventory_2_rounded,
                      size: 24,
                      color: isAvailable
                          ? const Color(0xFF059669)
                          : const Color(0xFFDC2626),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          matName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (materialId.isNotEmpty)
                          Text(
                            'Material ID: $materialId',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Prominent Available Stock Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isAvailable
                        ? [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)]
                        : [const Color(0xFFFEF2F2), const Color(0xFFFEE2E2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isAvailable
                        ? const Color(0xFFA7F3D0)
                        : const Color(0xFFFECACA),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Available Stock at Site',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isAvailable
                                ? const Color(0xFF047857)
                                : const Color(0xFFB91C1C),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: isAvailable
                                    ? const Color(0xFF065F46)
                                    : const Color(0xFF991B1B),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              unit,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isAvailable
                                    ? const Color(0xFF047857)
                                    : const Color(0xFFB91C1C),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isAvailable ? 'IN STOCK' : 'OUT OF STOCK',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isAvailable
                              ? const Color(0xFF059669)
                              : const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (mat['allocatedQty'] != null && (mat['allocatedQty'] as num) > 0) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Allocated', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              '${mat['allocatedQty']} $unit',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            if ((mat['allocatedAmount'] as num? ?? 0) > 0)
                              Text('₹${(mat['allocatedAmount'] as num).toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Consumed', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              '${mat['consumedQty']} $unit',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                            ),
                            if ((mat['consumedAmount'] as num? ?? 0) > 0)
                              Text('₹${(mat['consumedAmount'] as num).toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Effective Rate', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              '₹${((mat['effectiveUnitRate'] as num?) ?? 0).toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            Text('per $unit', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Site Information details - Site ID only
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildDetailRow('Site ID', siteId),
                    if ((mat['projectName'] ?? '').toString().isNotEmpty && mat['projectName'] != siteId) ...[
                      const Divider(height: 16),
                      _buildDetailRow('Project Name', mat['projectName']),
                    ],
                    if ((mat['category'] ?? '').toString().isNotEmpty && mat['category'] != 'General Material') ...[
                      const Divider(height: 16),
                      _buildDetailRow('Category', mat['category']),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'CLOSE',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value.isNotEmpty ? value : '-',
          style: const TextStyle(
            fontSize: 13.5,
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final isMobile = MediaQuery.of(context).size.width < 600;

    // Filtered materials
    final filtered = transferredMaterials.where((mat) {
      if (searchQuery.trim().isEmpty) return true;
      final q = searchQuery.trim().toLowerCase();
      final name = (mat['materialName'] ?? '').toString().toLowerCase();
      final dName = (mat['displayName'] ?? '').toString().toLowerCase();
      final cat = (mat['category'] ?? '').toString().toLowerCase();
      return name.contains(q) || dName.contains(q) || cat.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Materials at Site',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: -0.3,
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
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 700),
          child: RefreshIndicator(
            onRefresh: () async {
              if (selectedSiteId != null) {
                await fetchSiteStockFromMaterialTransfer(selectedSiteId!);
              } else {
                await fetchAssignedSites();
              }
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                // Site Selection Dropdown Card (Site ID only)
                _buildSiteDropdownCard(primaryColor),
                const SizedBox(height: 14),

                // Search Bar
                if (transferredMaterials.isNotEmpty || searchQuery.isNotEmpty) ...[
                  _buildSearchBar(),
                  const SizedBox(height: 14),
                ],

                // Content Views
                if (isLoadingSites || isLoadingMaterials)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    ),
                  )
                else if (errorMsg != null)
                  _buildErrorState(primaryColor)
                else if (selectedSiteId == null || assignedSiteIds.isEmpty)
                  _buildNoSitesAssignedState()
                else if (transferredMaterials.isEmpty)
                  _buildEmptyState()
                else if (filtered.isEmpty)
                  _buildNoSearchResults()
                else
                  _buildMaterialsList(filtered, primaryColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Site Selection Dropdown containing only assigned site IDs (e.g. ST001_shek)
  Widget _buildSiteDropdownCard(Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.apartment_rounded, color: primaryColor, size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'Select Assigned Site *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (assignedSiteIds.isEmpty && !isLoadingSites)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: const Text(
                'No sites assigned to this supervisor.',
                style: TextStyle(color: Color(0xFFDC2626), fontSize: 13),
              ),
            )
          else
            DropdownButtonFormField<String>(
              key: ValueKey('site_dropdown_${selectedSiteId}_${assignedSiteIds.length}'),
              initialValue: selectedSiteId,
              isExpanded: true,
              style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'Select Assigned Site',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                isDense: true,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primaryColor, width: 1.8),
                ),
              ),
              items: assignedSiteIds.map((sId) {
                return DropdownMenuItem<String>(
                  value: sId,
                  child: Text(
                    sId,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
              onChanged: _onSiteChanged,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
        ],
      ),
    );
  }

  /// Search Bar
  Widget _buildSearchBar() {
    return TextField(
      controller: searchController,
      onChanged: (val) => setState(() => searchQuery = val),
      style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
      decoration: InputDecoration(
        hintText: 'Search material by name...',
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
        suffixIcon: searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded, size: 16),
                onPressed: () {
                  searchController.clear();
                  setState(() => searchQuery = '');
                },
              )
            : null,
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primaryColor, width: 1.8),
        ),
      ),
    );
  }

  /// Materials List displaying Material Name & Available Stock Count
  Widget _buildMaterialsList(List<Map<String, dynamic>> items, Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Available Stock (${selectedSiteId ?? ""})',
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${items.length} materials',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final mat = items[index];
              final matName = (mat['displayName'] ?? mat['materialName'] ?? '').toString().trim();
              final unit = (mat['unit'] ?? 'Bags').toString().trim();
              final count = mat['availableCount'] as int? ?? 0;
              final isAvailable = count > 0;

              return InkWell(
                onTap: () => _showMaterialDetailsSheet(mat),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isAvailable ? const Color(0xFFF8FAFC) : const Color(0xFFFFF7F7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isAvailable ? const Color(0xFFE2E8F0) : const Color(0xFFFECACA),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Material Icon
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: isAvailable
                                  ? const Color(0xFFECFDF5)
                                  : const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isAvailable
                                  ? Icons.inventory_2_rounded
                                  : Icons.inventory_2_outlined,
                              size: 20,
                              color: isAvailable
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFDC2626),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Material Name
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  matName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                if ((mat['category'] ?? '').toString().isNotEmpty && mat['category'] != 'General Material')
                                  Text(
                                    mat['category'].toString(),
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // Available Stock Count Badge
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isAvailable
                                      ? const Color(0xFFECFDF5)
                                      : const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isAvailable
                                        ? const Color(0xFFA7F3D0)
                                        : const Color(0xFFFECACA),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      count.toString(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isAvailable
                                            ? const Color(0xFF059669)
                                            : const Color(0xFFDC2626),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      unit,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        color: isAvailable
                                            ? const Color(0xFF047857)
                                            : const Color(0xFFB91C1C),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isAvailable ? 'Available Stock' : 'Out of Stock',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isAvailable
                                      ? const Color(0xFF059669)
                                      : const Color(0xFFDC2626),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: Color(0xFF94A3B8),
                          ),
                        ],
                      ),
                      if (mat['allocatedQty'] != null && (mat['allocatedQty'] as num) > 0) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Allocated: ${mat['allocatedQty']} $unit',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'Consumed: ${mat['consumedQty']} $unit',
                                style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                              ),
                              if ((mat['effectiveUnitRate'] as num? ?? 0) > 0)
                                Text(
                                  'Rate: ₹${(mat['effectiveUnitRate'] as num).toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Empty State View
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warehouse_rounded,
              size: 40,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No Stock at Site (${selectedSiteId ?? ""})',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Materials transferred to this site by the manager will be automatically displayed here with their available counts.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// No Sites Assigned View
  Widget _buildNoSitesAssignedState() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.location_off_rounded, size: 40, color: Color(0xFF94A3B8)),
            SizedBox(height: 12),
            Text(
              'No Assigned Sites',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
            ),
            SizedBox(height: 6),
            Text(
              'You currently have no assigned construction sites. Please contact the manager.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }

  /// No Search Results View
  Widget _buildNoSearchResults() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.search_off_rounded, size: 36, color: Color(0xFF94A3B8)),
            const SizedBox(height: 10),
            Text(
              'No materials matching "$searchQuery"',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Try checking your spelling or clearing search filter',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  /// Error State View
  Widget _buildErrorState(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, size: 40, color: Color(0xFFEF4444)),
          const SizedBox(height: 12),
          Text(
            errorMsg!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFDC2626),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: fetchAssignedSites,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
