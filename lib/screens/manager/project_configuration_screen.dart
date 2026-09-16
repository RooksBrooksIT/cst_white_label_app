import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ebricks/services/firestore_service.dart';
import 'package:ebricks/utils/dialog_utils.dart';
import 'package:ebricks/widgets/glass_card.dart';
import 'package:ebricks/utils/app_theme.dart';

enum ProjectConfigType {
  category,
  subCategory,
  stage,
  contract,
  status,
}

class ConfigTypeMeta {
  final ProjectConfigType type;
  final String title;
  final String subtitle;
  final String hintText;
  final String collectionName;
  final String idField;
  final String nameField;
  final String idPrefix;
  final IconData icon;
  final Color themeColor;

  const ConfigTypeMeta({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.hintText,
    required this.collectionName,
    required this.idField,
    required this.nameField,
    required this.idPrefix,
    required this.icon,
    required this.themeColor,
  });
}

class ProjectConfigurationScreen extends StatefulWidget {
  final int initialIndex;

  const ProjectConfigurationScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<ProjectConfigurationScreen> createState() =>
      _ProjectConfigurationScreenState();
}

class _ProjectConfigurationScreenState
    extends State<ProjectConfigurationScreen> {
  static const List<ConfigTypeMeta> configSections = [
    ConfigTypeMeta(
      type: ProjectConfigType.category,
      title: 'Project Category',
      subtitle: 'Define and manage project categories',
      hintText: 'Enter category name (e.g. Residential, Commercial)',
      collectionName: 'projectCategories',
      idField: 'projectCategoryId',
      nameField: 'projectCategory',
      idPrefix: 'PC',
      icon: Icons.category_rounded,
      themeColor: Colors.orange,
    ),
    ConfigTypeMeta(
      type: ProjectConfigType.subCategory,
      title: 'Project Sub Category',
      subtitle: 'Define detailed project sub-categories',
      hintText: 'Enter sub-category name (e.g. Renovation, Villa)',
      collectionName: 'projectSubCategories',
      idField: 'subCategoryId',
      nameField: 'projectSubCategory',
      idPrefix: 'PSC',
      icon: Icons.subtitles_rounded,
      themeColor: Colors.purple,
    ),
    ConfigTypeMeta(
      type: ProjectConfigType.stage,
      title: 'Project Stage',
      subtitle: 'Configure project work stages & milestones',
      hintText: 'Enter stage name (e.g. Excavation, Foundation)',
      collectionName: 'projectStages',
      idField: 'projectStageId',
      nameField: 'projectStage',
      idPrefix: 'PST',
      icon: Icons.flag_rounded,
      themeColor: Colors.red,
    ),
    ConfigTypeMeta(
      type: ProjectConfigType.contract,
      title: 'Project Contract',
      subtitle: 'Manage legal contracts & agreements',
      hintText: 'Enter contract type (e.g. Fixed Price, Unit Price)',
      collectionName: 'projectContracts',
      idField: 'contractId',
      nameField: 'projectContract',
      idPrefix: 'CT',
      icon: Icons.assignment_rounded,
      themeColor: Colors.teal,
    ),
    ConfigTypeMeta(
      type: ProjectConfigType.status,
      title: 'Project Status',
      subtitle: 'Configure project execution status indicators',
      hintText: 'Enter status name (e.g. Planning, In Progress)',
      collectionName: 'projectStatus',
      idField: 'projectStatusId',
      nameField: 'projectStatus',
      idPrefix: 'PSTU',
      icon: Icons.donut_large_rounded,
      themeColor: Colors.blue,
    ),
  ];

  void _showHelpGuidanceDialog(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final isMobile = MediaQuery.of(context).size.width < 600;

    final steps = [
      {
        'step': '1',
        'title': 'Project Category',
        'example': 'House',
        'desc': 'The broad type of construction or property you are building (e.g., Residential House, Commercial Complex, Villa).',
        'color': Colors.orange,
        'icon': Icons.category_rounded,
      },
      {
        'step': '2',
        'title': 'Project Sub Category',
        'example': '2BHK',
        'desc': 'The specific sub-type, layout, or specification under the category (e.g., 2BHK, 3BHK, Duplex, Warehouse).',
        'color': Colors.purple,
        'icon': Icons.subtitles_rounded,
      },
      {
        'step': '3',
        'title': 'Project Stage',
        'example': 'Brick Works',
        'desc': 'The key construction milestones and work stages to track progress (e.g., Excavation, Foundation, Brick Works, Flooring).',
        'color': Colors.red,
        'icon': Icons.flag_rounded,
      },
      {
        'step': '4',
        'title': 'Project Contract',
        'example': 'End-to-End Contract',
        'desc': 'The contractual agreement model with the client or vendor (e.g., End-to-End Contract, Labor Only, Item Rate).',
        'color': Colors.teal,
        'icon': Icons.assignment_rounded,
      },
      {
        'step': '5',
        'title': 'Project Status & Planning',
        'example': 'Planning',
        'desc': 'The active operational lifecycle state of the project (e.g., Planning, In Progress, On Hold, Completed).',
        'color': Colors.blue,
        'icon': Icons.donut_large_rounded,
      },
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 32,
            vertical: 24,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 620,
              maxHeight: MediaQuery.of(context).size.height * 0.88,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── HEADER ───────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        darkAccent,
                        Color.alphaBlend(
                          primaryColor.withValues(alpha: 0.4),
                          darkAccent,
                        ),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.help_outline_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'How Configuration Works',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Master settings & workflow timeline guide',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                        onPressed: () => Navigator.pop(ctx),
                        tooltip: 'Close',
                        splashRadius: 20,
                      ),
                    ],
                  ),
                ),

                // ── SCROLLABLE CONTENT ───────────────────────────────────────
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Quick overview box
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.lightbulb_outline_rounded,
                                  color: primaryColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Configure your master project options once here. When creating or planning a project in the wizard, simply pick from these pre-configured values from the dropdowns.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.45,
                                    color: Colors.blueGrey[800],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Section Title: Expected Hierarchy
                        Row(
                          children: [
                            Icon(Icons.account_tree_rounded, size: 18, color: primaryColor),
                            const SizedBox(width: 8),
                            const Text(
                              'Configuration Flow & Timeline',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Here is how each configuration connects when structuring a real project:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Step Timeline items
                        ...List.generate(steps.length, (index) {
                          final step = steps[index];
                          final isLast = index == steps.length - 1;
                          final color = step['color'] as Color;

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Step indicator column (icon + connecting line)
                              Column(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: color.withValues(alpha: 0.6),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        step['icon'] as IconData,
                                        size: 18,
                                        color: color,
                                      ),
                                    ),
                                  ),
                                  if (!isLast)
                                    Container(
                                      width: 2,
                                      height: 52,
                                      margin: const EdgeInsets.symmetric(vertical: 2),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            color.withValues(alpha: 0.6),
                                            (steps[index + 1]['color'] as Color).withValues(alpha: 0.6),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 14),

                              // Content card
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(bottom: isLast ? 0 : 16.0),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.02),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                step['title'] as String,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: Color(0xFF0F172A),
                                                ),
                                              ),
                                            ),
                                            // Example Tag Pill
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: color.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: color.withValues(alpha: 0.3),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    'e.g. ',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w500,
                                                      color: color.withValues(alpha: 0.8),
                                                    ),
                                                  ),
                                                  Text(
                                                    step['example'] as String,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: color,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          step['desc'] as String,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF475569),
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                        const SizedBox(height: 16),

                        // Visual Example Chain Summary
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: primaryColor.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.check_circle_outline_rounded, size: 16, color: primaryColor),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Example Project Flow:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'House  ➔  2BHK  ➔  Brick Works  ➔  End-to-End Contract  ➔  Planning',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── FOOTER BUTTON ────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border(
                      top: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Got It',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Project Configuration',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded, color: Colors.white),
            tooltip: 'How Configuration Works',
            onPressed: () => _showHelpGuidanceDialog(context),
          ),
          const SizedBox(width: 8),
        ],
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
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isMobile ? double.infinity : 750,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: configSections.map((meta) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: _ProjectConfigSectionCard(meta: meta),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectConfigSectionCard extends StatefulWidget {
  final ConfigTypeMeta meta;

  const _ProjectConfigSectionCard({required this.meta});

  @override
  State<_ProjectConfigSectionCard> createState() =>
      __ProjectConfigSectionCardState();
}

class __ProjectConfigSectionCardState
    extends State<_ProjectConfigSectionCard> {
  final TextEditingController _inputController = TextEditingController();
  bool _isAdding = false;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<String> _generateNextId(ConfigTypeMeta meta) async {
    try {
      final snap =
          await FirestoreService.getCollection(meta.collectionName).get();
      int maxNum = 0;
      for (var doc in snap.docs) {
        final idStr = doc.id;
        final numPart =
            int.tryParse(idStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        if (numPart > maxNum) maxNum = numPart;
      }
      return '${meta.idPrefix}${(maxNum + 1).toString().padLeft(3, '0')}';
    } catch (_) {
      return '${meta.idPrefix}${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}';
    }
  }

  Future<bool> _isDuplicate(ConfigTypeMeta meta, String name) async {
    try {
      final snap =
          await FirestoreService.getCollection(meta.collectionName).get();
      final target = name.trim().toLowerCase();
      for (var doc in snap.docs) {
        final data = doc.data();
        final existingName = (data[meta.nameField] ??
                data['projectState'] ??
                data['name'] ??
                '')
            .toString()
            .trim()
            .toLowerCase();
        if (existingName == target) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _addItem() async {
    final name = _inputController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a valid ${widget.meta.title.toLowerCase()} name'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isAdding = true);

    try {
      final isDup = await _isDuplicate(widget.meta, name);
      if (isDup) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"$name" already exists in ${widget.meta.title}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final id = await _generateNextId(widget.meta);
      final docData = <String, dynamic>{
        widget.meta.idField: id,
        widget.meta.nameField: name,
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (widget.meta.type == ProjectConfigType.status) {
        docData['projectState'] = name;
        docData['projectStatus'] = name;
      }

      await FirestoreService.getCollection(widget.meta.collectionName)
          .doc(id)
          .set(docData);

      _inputController.clear();
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      await DialogUtils.showSuccessDialog(
        context,
        message: '${widget.meta.title} added successfully!',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add item: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _deleteItem(String docId, String itemName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: Colors.red, size: 22),
            ),
            const SizedBox(width: 10),
            Text(
              'Delete ${widget.meta.title}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "$itemName"? This action cannot be undone.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirestoreService.getCollection(widget.meta.collectionName)
          .doc(docId)
          .delete();

      if (mounted) {
        DialogUtils.showSuccessDialog(
          context,
          message: '"$itemName" deleted successfully!',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete item: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = widget.meta;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: meta.themeColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  meta.icon,
                  color: meta.themeColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meta.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0A183D),
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      meta.subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Stream Count Badge
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirestoreService.getCollection(meta.collectionName)
                    .snapshots(),
                builder: (context, snapshot) {
                  final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: meta.themeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: meta.themeColor,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Input Row: [ Enter Value ] -> Add Button
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  textAlignVertical: TextAlignVertical.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF0A183D),
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    hintText: meta.hintText,
                    hintStyle: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12.5,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFCBD5E1),
                        width: 1.0,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: meta.themeColor,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _addItem(),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _isAdding ? null : () => _addItem(),
                  icon: _isAdding
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.add_rounded, size: 18),
                  label: const Text(
                    'Add',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                    shadowColor: theme.primaryColor.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Items List Display
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirestoreService.getCollection(meta.collectionName)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }

              final docs = snapshot.hasData ? snapshot.data!.docs : [];

              if (docs.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.15),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'No ${meta.title.toLowerCase()}s added yet.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                );
              }

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF0A183D).withValues(alpha: 0.08),
                  ),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: Colors.grey.withValues(alpha: 0.15),
                  ),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final itemName = (data[meta.nameField] ??
                            data['projectState'] ??
                            data['name'] ??
                            '')
                        .toString()
                        .trim();

                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 2,
                      ),
                      leading: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: meta.themeColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: meta.themeColor,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        itemName,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0A183D),
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        tooltip: 'Delete $itemName',
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _deleteItem(doc.id, itemName);
                        },
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
