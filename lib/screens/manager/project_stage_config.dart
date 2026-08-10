import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/dialog_utils.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';
import 'package:demo_cst/utils/app_theme.dart';

class ProjectStageConfig extends StatefulWidget {
  const ProjectStageConfig({super.key});

  @override
  State<ProjectStageConfig> createState() => _ProjectStageConfigState();
}

class _ProjectStageConfigState extends State<ProjectStageConfig> {
  String? _selectedStage;
  final TextEditingController _newStageController = TextEditingController();

  Future<void> _showAddStageDialog() async {
    _newStageController.clear();
    bool isDuplicate = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            final Color darkCardBg = AppTheme.getDarkAccent(theme.primaryColor);

            return Container(
              decoration: BoxDecoration(
                color: darkCardBg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                    left: 24,
                    right: 24,
                    top: 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Add New Project Stage',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 20),

                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _newStageController,
                          style: const TextStyle(
                            color: Color(0xFF0A183D),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          onChanged: (value) async {
                            final duplicate = await _isDuplicateStage(
                              value.trim(),
                            );
                            setDialogState(() => isDuplicate = duplicate);
                          },
                          decoration: InputDecoration(
                            hintText: 'Enter Stage Name (e.g. Foundation)',
                            hintStyle: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            prefixIcon: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12.0),
                              child: Icon(
                                Icons.flag_rounded,
                                color: Color(0xFFEF4444),
                                size: 22,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),

                      if (isDuplicate)
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: Text(
                            'This stage already exists.',
                            style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),

                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.4),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  'CANCEL',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: isDuplicate
                                    ? null
                                    : () async {
                                        final newStage = _newStageController
                                            .text
                                            .trim();
                                        if (newStage.isEmpty) return;

                                        final nextId = await _getNextStageId();
                                        await FirestoreService.getCollection(
                                          'projectStages',
                                        ).doc(nextId).set({
                                          'projectStageId': nextId,
                                          'projectStage': newStage,
                                        });

                                        if (mounted) {
                                          Navigator.pop(context);
                                          setState(
                                            () => _selectedStage = newStage,
                                          );
                                          await DialogUtils.showSuccessDialog(
                                            context,
                                            message:
                                                'Stage added successfully!',
                                          );
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEF4444),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  'SAVE',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
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
          },
        );
      },
    );
  }

  Future<String> _getNextStageId() async {
    final snapshot = await FirestoreService.getCollection(
      'projectStages',
    ).orderBy('projectStageId', descending: true).limit(1).get();

    if (snapshot.docs.isEmpty) return 'PST001';
    final lastId = snapshot.docs.first['projectStageId']?.toString() ?? '';
    if (lastId.isEmpty || !lastId.startsWith('PST')) return 'PST001';
    final number = int.tryParse(lastId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return 'PST${(number + 1).toString().padLeft(3, '0')}';
  }

  Future<bool> _isDuplicateStage(String stage) async {
    final snapshot = await FirestoreService.getCollection(
      'projectStages',
    ).get();
    final existingStages = snapshot.docs
        .map((doc) => doc['projectStage']?.toString().toLowerCase() ?? '')
        .toList();
    return existingStages.contains(stage.toLowerCase());
  }

  Future<void> _deleteSelectedStage() async {
    if (_selectedStage == null) return;
    try {
      final snapshot = await FirestoreService.getCollection(
        'projectStages',
      ).where('projectStage', isEqualTo: _selectedStage).get();

      if (snapshot.docs.isNotEmpty) {
        for (final doc in snapshot.docs) {
          await doc.reference.delete();
        }
        if (mounted) {
          setState(() => _selectedStage = null);
          await DialogUtils.showSuccessDialog(
            context,
            message: 'Stage deleted successfully!',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete stage: $e')));
      }
    }
  }

  @override
  void dispose() {
    _newStageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;
    final Color darkCardBg = AppTheme.getDarkAccent(theme.primaryColor);

    return GlassScaffold(
      padding: EdgeInsets.zero,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header Row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B1942),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF0B1942,
                          ).withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Text(
                    'Project Stage Config',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0A183D),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isMobile ? double.infinity : 600,
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Main Card
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: darkCardBg,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: darkCardBg.withValues(alpha: 0.25),
                                blurRadius: 16,
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
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(
                                            0xFFEF4444,
                                          ).withValues(alpha: 0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.flag_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Project Stages',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Configure milestone stages and phases',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFFCBD5E1),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'Select Stage',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),

                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.08,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: StreamBuilder<QuerySnapshot>(
                                        stream: FirestoreService.getCollection(
                                          'projectStages',
                                        ).snapshots(),
                                        builder: (context, snapshot) {
                                          if (!snapshot.hasData ||
                                              snapshot.data == null) {
                                            return const Padding(
                                              padding: EdgeInsets.all(16.0),
                                              child: LinearProgressIndicator(),
                                            );
                                          }
                                          final stages = snapshot.data!.docs
                                              .map(
                                                (d) =>
                                                    d['projectStage']
                                                        ?.toString() ??
                                                    '',
                                              )
                                              .where((s) => s.isNotEmpty)
                                              .toList();

                                          return DropdownButtonFormField<
                                            String
                                          >(
                                            isExpanded: true,
                                            value:
                                                (_selectedStage != null &&
                                                    stages.contains(
                                                      _selectedStage,
                                                    ))
                                                ? _selectedStage
                                                : null,
                                            style: const TextStyle(
                                              color: Color(0xFF0A183D),
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            decoration: InputDecoration(
                                              hintText: 'Choose a stage',
                                              hintStyle: const TextStyle(
                                                color: Color(0xFF94A3B8),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              prefixIcon: const Padding(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 12.0,
                                                ),
                                                child: Icon(
                                                  Icons.search_rounded,
                                                  color: Color(0xFFEF4444),
                                                  size: 20,
                                                ),
                                              ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                borderSide: BorderSide.none,
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 14,
                                                  ),
                                            ),
                                            items: stages
                                                .toSet()
                                                .map(
                                                  (stage) => DropdownMenuItem(
                                                    value: stage,
                                                    child: Text(
                                                      stage,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                            onChanged: (val) => setState(
                                              () => _selectedStage = val,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(
                                            0xFFEF4444,
                                          ).withValues(alpha: 0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.add_rounded,
                                        color: Colors.white,
                                        size: 26,
                                      ),
                                      onPressed: _showAddStageDialog,
                                      tooltip: 'Add Stage',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Delete Stage Button
                        SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _selectedStage == null
                                ? null
                                : () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Delete Stage'),
                                        content: Text(
                                          'Are you sure you want to delete stage "$_selectedStage"?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('CANCEL'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text(
                                              'DELETE',
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await _deleteSelectedStage();
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              elevation: 4,
                              shadowColor: const Color(
                                0xFFEF4444,
                              ).withValues(alpha: 0.35),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'DELETE SELECTED STAGE',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 100),
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
}
