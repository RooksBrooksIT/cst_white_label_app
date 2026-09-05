import 'package:flutter/material.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/screens/supervisor/supervisor_tools_view_request_screen.dart';

class ToolsAtSitePage extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;

  const ToolsAtSitePage({
    super.key,
    required this.supervisorId,
    required this.supervisorName,
  });

  @override
  State<ToolsAtSitePage> createState() => _ToolsAtSitePageState();
}

class _ToolsAtSitePageState extends State<ToolsAtSitePage> {
  // Theme helper
  Color get primaryColor => Theme.of(context).colorScheme.primary;

  // Site state - Site ID only (e.g. ST001_shek)
  List<String> assignedSiteIds = [];
  String? selectedSiteId;

  // Tools at Site Inventory state
  List<Map<String, dynamic>> siteTools = [];
  bool isLoadingSites = true;
  bool isLoadingTools = false;
  String? errorMsg;
  String searchQuery = '';
  final TextEditingController searchController = TextEditingController();

  // Selected Tool for details popup/card
  Map<String, dynamic>? selectedToolDetail;

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
          await fetchSiteTools(selectedSiteId!);
        }
      }
    } catch (e) {
      debugPrint('Error fetching assigned sites for tools: $e');
      if (mounted) {
        setState(() {
          isLoadingSites = false;
          errorMsg = "Failed to load assigned sites: ${e.toString()}";
        });
      }
    }
  }

  /// Fetches tool stock for the selected site from `toolsInventory` and `tools` master collections.
  Future<void> fetchSiteTools(String siteId) async {
    final cleanSiteId = siteId.trim();
    if (cleanSiteId.isEmpty) {
      setState(() {
        siteTools = [];
        isLoadingTools = false;
      });
      return;
    }

    setState(() {
      isLoadingTools = true;
      errorMsg = null;
      selectedToolDetail = null;
    });

    try {
      if (!FirestoreService.isReady) {
        await FirestoreService.initialize();
      }

      // 1. Fetch master tools
      final toolsSnap = await FirestoreService.getCollection('tools').get();
      final Map<String, Map<String, dynamic>> masterToolsMap = {};

      for (final doc in toolsSnap.docs) {
        final data = doc.data();
        final toolCode = (data['toolCode'] ?? doc.id).toString().trim();
        final toolName = (data['toolName'] ?? toolCode).toString().trim();
        final toolId = (data['toolId'] ?? doc.id).toString().trim();
        final description = (data['description'] ?? '').toString().trim();
        final toolOwner = (data['toolOwner'] ?? 'Org').toString().trim();

        final key = toolCode.isNotEmpty ? toolCode.toLowerCase() : doc.id.toLowerCase();
        masterToolsMap[key] = {
          'docId': doc.id,
          'toolId': toolId,
          'toolCode': toolCode,
          'toolName': toolName,
          'description': description,
          'toolOwner': toolOwner,
          'unit': (data['unit'] ?? 'Units').toString().trim(),
        };
      }

      // 2. Fetch tool distribution from toolsInventory
      final inventorySnap = await FirestoreService.getCollection('toolsInventory').get();
      final Map<String, Map<String, dynamic>> siteToolsMap = {};

      final cleanLow = cleanSiteId.toLowerCase();

      for (final doc in inventorySnap.docs) {
        final data = doc.data();
        final toolCode = (data['toolCode'] ?? doc.id).toString().trim();
        final key = toolCode.isNotEmpty ? toolCode.toLowerCase() : doc.id.toLowerCase();

        int availableCount = 0;

        // Check Map format: availableCountAtSites: { siteId: count }
        if (data['availableCountAtSites'] is Map) {
          final sitesMap = Map<String, dynamic>.from(data['availableCountAtSites']);
          sitesMap.forEach((k, v) {
            final kLow = k.toString().trim().toLowerCase();
            final bool isMatch = kLow == cleanLow ||
                (cleanLow.contains('_') && kLow.isNotEmpty && (cleanLow.startsWith('$kLow' '_') || cleanLow.endsWith('_$kLow'))) ||
                (kLow.contains('_') && cleanLow.isNotEmpty && (kLow.startsWith('$cleanLow' '_') || kLow.endsWith('_$cleanLow')));

            if (isMatch) {
              final c = (v as num?)?.toInt() ?? int.tryParse(v.toString()) ?? 0;
              availableCount += c;
            }
          });
        }

        // Check List format: sites: [{ siteId, count }] or siteInventories: [{ siteId, count }]
        final rawSitesList = data['sites'] ?? data['siteInventories'];
        if (rawSitesList is List) {
          for (var s in rawSitesList) {
            if (s is! Map) continue;
            final sMap = Map<String, dynamic>.from(s);
            final sId = (sMap['siteId'] ?? sMap['siteid'] ?? '').toString().trim().toLowerCase();
            final sName = (sMap['siteName'] ?? sMap['sitename'] ?? '').toString().trim().toLowerCase();

            final bool isMatch = sId == cleanLow ||
                (sName.isNotEmpty && sName == cleanLow) ||
                (cleanLow.contains('_') && sId.isNotEmpty && (cleanLow.startsWith('$sId' '_') || cleanLow.endsWith('_$sId'))) ||
                (sId.contains('_') && cleanLow.isNotEmpty && (sId.startsWith('$cleanLow' '_') || sId.endsWith('_$cleanLow')));

            if (isMatch) {
              final c = (sMap['availableCount'] as num?)?.toInt() ??
                  (sMap['count'] as num?)?.toInt() ??
                  (sMap['toolCount'] as num?)?.toInt() ??
                  int.tryParse((sMap['availableCount'] ?? sMap['count'] ?? '0').toString()) ??
                  0;
              availableCount += c;
            }
          }
        }

        // Get master metadata or use inventory data
        final master = masterToolsMap[key] ?? {};
        final toolName = (master['toolName'] ?? data['toolName'] ?? toolCode).toString().trim();
        final toolId = (master['toolId'] ?? data['toolId'] ?? doc.id).toString().trim();
        final description = (master['description'] ?? data['description'] ?? '').toString().trim();
        final toolOwner = (master['toolOwner'] ?? data['toolOwner'] ?? 'Org').toString().trim();
        final unit = (master['unit'] ?? data['unit'] ?? 'Units').toString().trim();

        if (availableCount > 0) {
          siteToolsMap[key] = {
            'toolId': toolId,
            'toolCode': toolCode,
            'toolName': toolName,
            'displayName': toolName,
            'description': description,
            'toolOwner': toolOwner,
            'unit': unit,
            'availableCount': availableCount,
            'siteId': cleanSiteId,
          };
        }
      }

      // Fallback: If toolsInventory is empty or not yet seeded, check toolsMovement dispatches for this site
      if (siteToolsMap.isEmpty) {
        try {
          final movementSnap = await FirestoreService.getCollection('toolsMovement')
              .where('mtSiteId', isEqualTo: cleanSiteId)
              .get();

          final Map<String, int> movementCounts = {};

          for (final doc in movementSnap.docs) {
            final data = doc.data();
            final toolsList = data['tools'];
            if (toolsList is List) {
              for (final t in toolsList) {
                if (t is Map) {
                  final tCode = (t['toolCode'] ?? t['toolId'] ?? '').toString().trim();
                  final tCount = (t['toolCount'] as num?)?.toInt() ?? (t['count'] as num?)?.toInt() ?? 1;
                  if (tCode.isNotEmpty) {
                    movementCounts[tCode.toLowerCase()] = (movementCounts[tCode.toLowerCase()] ?? 0) + tCount;
                  }
                }
              }
            }
          }

          // Subtract any returns from toolsReturn
          final returnSnap = await FirestoreService.getCollection('toolsReturn')
              .where('rfSiteId', isEqualTo: cleanSiteId)
              .get();

          for (final doc in returnSnap.docs) {
            final data = doc.data();
            final toolsList = data['tools'];
            if (toolsList is List) {
              for (final t in toolsList) {
                if (t is Map) {
                  final tCode = (t['toolCode'] ?? t['toolId'] ?? '').toString().trim();
                  final tCount = (t['toolCount'] as num?)?.toInt() ?? (t['count'] as num?)?.toInt() ?? 1;
                  if (tCode.isNotEmpty) {
                    final curr = movementCounts[tCode.toLowerCase()] ?? 0;
                    final remain = curr - tCount;
                    if (remain <= 0) {
                      movementCounts.remove(tCode.toLowerCase());
                    } else {
                      movementCounts[tCode.toLowerCase()] = remain;
                    }
                  }
                }
              }
            }
          }

          // Build siteToolsMap from calculated movements
          movementCounts.forEach((k, count) {
            if (count > 0) {
              final master = masterToolsMap[k] ?? {};
              final toolName = (master['toolName'] ?? k).toString().trim();
              final toolId = (master['toolId'] ?? k).toString().trim();
              final toolCode = (master['toolCode'] ?? k).toString().trim();
              final description = (master['description'] ?? '').toString().trim();
              final toolOwner = (master['toolOwner'] ?? 'Org').toString().trim();
              final unit = (master['unit'] ?? 'Units').toString().trim();

              siteToolsMap[k] = {
                'toolId': toolId,
                'toolCode': toolCode,
                'toolName': toolName,
                'displayName': toolName,
                'description': description,
                'toolOwner': toolOwner,
                'unit': unit,
                'availableCount': count,
                'siteId': cleanSiteId,
              };
            }
          });
        } catch (_) {}
      }

      final list = siteToolsMap.values.toList();
      list.sort((a, b) => (a['displayName'] as String).toLowerCase().compareTo((b['displayName'] as String).toLowerCase()));

      if (mounted) {
        setState(() {
          siteTools = list;
          isLoadingTools = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching site tools: $e');
      if (mounted) {
        setState(() {
          isLoadingTools = false;
          errorMsg = "Failed to load tools stock: ${e.toString()}";
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
      selectedToolDetail = null;
    });

    await fetchSiteTools(newSiteId);
  }

  /// Opens detailed tool stock popup for a selected tool
  void _showToolDetailsSheet(Map<String, dynamic> tool) {
    setState(() {
      selectedToolDetail = tool;
    });

    final toolName = (tool['displayName'] ?? tool['toolName'] ?? '').toString();
    final count = tool['availableCount'] as int? ?? 0;
    final unit = (tool['unit'] ?? 'Units').toString();
    final toolId = (tool['toolId'] ?? '').toString();
    final toolCode = (tool['toolCode'] ?? '').toString();
    final description = (tool['description'] ?? '').toString();
    final toolOwner = (tool['toolOwner'] ?? 'Org').toString();
    final siteId = (tool['siteId'] ?? selectedSiteId ?? '').toString();
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
                      Icons.home_repair_service_rounded,
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
                          toolName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (toolCode.isNotEmpty)
                          Text(
                            'Code: $toolCode',
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
                          'Available Tools at Site',
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
              const SizedBox(height: 16),

              // Tool Information Details
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
                    if (toolId.isNotEmpty && toolId != toolCode) ...[
                      const Divider(height: 16),
                      _buildDetailRow('Tool ID', toolId),
                    ],
                    if (toolOwner.isNotEmpty) ...[
                      const Divider(height: 16),
                      _buildDetailRow('Owner', toolOwner),
                    ],
                    if (description.isNotEmpty) ...[
                      const Divider(height: 16),
                      _buildDetailRow('Description', description),
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
        Flexible(
          child: Text(
            value.isNotEmpty ? value : '-',
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
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

    // Filtered tools
    final filtered = siteTools.where((tool) {
      if (searchQuery.trim().isEmpty) return true;
      final q = searchQuery.trim().toLowerCase();
      final name = (tool['toolName'] ?? '').toString().toLowerCase();
      final dName = (tool['displayName'] ?? '').toString().toLowerCase();
      final code = (tool['toolCode'] ?? '').toString().toLowerCase();
      final desc = (tool['description'] ?? '').toString().toLowerCase();
      return name.contains(q) || dName.contains(q) || code.contains(q) || desc.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Tools at Site',
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
        actions: [
          IconButton(
            icon: const Icon(Icons.fact_check_rounded, color: Colors.white, size: 20),
            tooltip: 'Tool Requisitions & Arrivals',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SupervisorToolsViewRequestScreen(
                  supervisorId: widget.supervisorId,
                  supervisorName: widget.supervisorName,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 700),
          child: RefreshIndicator(
            onRefresh: () async {
              if (selectedSiteId != null) {
                await fetchSiteTools(selectedSiteId!);
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
                if (siteTools.isNotEmpty || searchQuery.isNotEmpty) ...[
                  _buildSearchBar(),
                  const SizedBox(height: 14),
                ],

                // Content Views
                if (isLoadingSites || isLoadingTools)
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
                else if (siteTools.isEmpty)
                  _buildEmptyState()
                else if (filtered.isEmpty)
                  _buildNoSearchResults()
                else
                  _buildToolsList(filtered, primaryColor),
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
              key: ValueKey('site_dropdown_tools_${selectedSiteId}_${assignedSiteIds.length}'),
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
        hintText: 'Search tool by name or code...',
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

  /// Tools List displaying Tool Name & Available Stock Count
  Widget _buildToolsList(List<Map<String, dynamic>> items, Color primaryColor) {
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
                'Available Tools (${selectedSiteId ?? ""})',
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
                  '${items.length} tools',
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
              final tool = items[index];
              final toolName = (tool['displayName'] ?? tool['toolName'] ?? '').toString().trim();
              final toolCode = (tool['toolCode'] ?? '').toString().trim();
              final unit = (tool['unit'] ?? 'Units').toString().trim();
              final count = tool['availableCount'] as int? ?? 0;
              final isAvailable = count > 0;

              return InkWell(
                onTap: () => _showToolDetailsSheet(tool),
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
                  child: Row(
                    children: [
                      // Tool Icon
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
                              ? Icons.home_repair_service_rounded
                              : Icons.home_repair_service_outlined,
                          size: 20,
                          color: isAvailable
                              ? const Color(0xFF059669)
                              : const Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Tool Name & Code
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              toolName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            if (toolCode.isNotEmpty)
                              Text(
                                'Code: $toolCode',
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
              Icons.home_repair_service_rounded,
              size: 40,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No Tools at Site (${selectedSiteId ?? ""})',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tools dispatched to this site will be automatically displayed here with their available counts.',
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
              'No tools matching "$searchQuery"',
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
