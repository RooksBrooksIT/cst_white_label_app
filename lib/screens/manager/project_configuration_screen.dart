import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/dialog_utils.dart';
import 'package:demo_cst/widgets/glass_card.dart';
import 'package:demo_cst/utils/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _seedDefaultStatuses();
  }

  /// Seed default project statuses if Firestore collection is empty
  Future<void> _seedDefaultStatuses() async {
    try {
      final snap =
          await FirestoreService.getCollection('projectStatus').limit(1).get();
      if (snap.docs.isEmpty) {
        final defaultStatuses = [
          'Planning',
          'In Progress',
          'On Hold',
          'Completed',
          'Cancelled',
        ];
        int index = 1;
        for (var status in defaultStatuses) {
          final id = 'PSTU${index.toString().padLeft(3, '0')}';
          await FirestoreService.getCollection('projectStatus').doc(id).set({
            'projectStatusId': id,
            'projectStatus': status,
            'projectState': status,
            'createdAt': FieldValue.serverTimestamp(),
          });
          index++;
        }
      }
    } catch (e) {
      debugPrint('Error seeding default statuses: $e');
    }
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
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF0A183D),
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: meta.hintText,
                    hintStyle: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey.shade500,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFCBD5E1),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFCBD5E1),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: meta.themeColor,
                        width: 1.8,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onSubmitted: (_) => _addItem(),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
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
                  backgroundColor: const Color(0xFF0A183D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
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
