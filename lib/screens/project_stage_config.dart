import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import '../services/firestore_service.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_button.dart';
import '../widgets/glass_card.dart';

class ProjectStageConfig extends StatefulWidget {
  const ProjectStageConfig({super.key});

  @override
  _ProjectStageConfigState createState() => _ProjectStageConfigState();
}

class _ProjectStageConfigState extends State<ProjectStageConfig> {
  String? _selectedStage;
  final TextEditingController _newStageController = TextEditingController();

  Future<void> _showAddStageDialog() async {
    _newStageController.clear();
    bool isDuplicate = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add New Stage',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _newStageController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Stage Name',
                        labelStyle: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                      ),
                      cursorColor: Theme.of(context).colorScheme.primary,
                      onChanged: (value) async {
                        final duplicate = await _isDuplicateStage(value.trim());
                        setState(() {
                          isDuplicate = duplicate;
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                          ),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.save),
                          label: const Text('Save', style: TextStyle()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDuplicate
                                ? Colors.grey
                                : Theme.of(context).colorScheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 2,
                          ),
                          onPressed: isDuplicate
                              ? null
                              : () async {
                                  final newStage = _newStageController.text
                                      .trim();
                                  if (newStage.isEmpty) return;

                                  final nextId = await _getNextStageId();
                                  await FirestoreService.getCollection(
                                    'projectStages',
                                  ).doc(nextId).set({
                                    'projectStageId': nextId,
                                    'projectStage': newStage,
                                  });

                                  Navigator.of(context).pop();
                                  setState(() {
                                    _selectedStage = newStage;
                                  });
                                  await _showSuccessAnimation(
                                    message: 'Stage added successfully!',
                                  );
                                },
                        ),
                      ],
                    ),
                    if (isDuplicate)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Text(
                          'This stage already exists.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showSuccessAnimation({
    String message = 'Stage added successfully!',
  }) async {
    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/animation/success.json',
                  width: 150,
                  height: 150,
                  repeat: false,
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('OK', style: TextStyle()),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showErrorModal(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                  size: 60,
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 20),
                Builder(
                  builder: (context) {
                    final cs = Theme.of(context).colorScheme;
                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.error,
                        foregroundColor: cs.onError,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK'),
                    );
                  },
                ),
              ],
            ),
          ),
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
    final nextNumber = number + 1;
    return 'PST${nextNumber.toString().padLeft(3, '0')}';
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
    if (_selectedStage == null) {
      _showErrorModal(
        context,
        'No Stage Selected',
        'Please select a stage to delete.',
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Stage'),
          content: Text(
            'Are you sure you want to delete the stage "${_selectedStage!}"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      final snapshot = await FirestoreService.getCollection(
        'projectStages',
      ).where('projectStage', isEqualTo: _selectedStage).get();

      if (snapshot.docs.isEmpty) {
        _showErrorModal(
          context,
          'Not Found',
          'The selected stage was not found in Firestore.',
        );
        return;
      }

      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }

      setState(() {
        _selectedStage = null;
      });

      await _showSuccessAnimation(message: 'Stage deleted successfully!');
    } catch (e) {
      _showErrorModal(context, 'Error', 'Failed to delete stage: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryColor = colorScheme.primary;

    return GlassScaffold(
      title: 'Project Stage Configuration',
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // --- Project Stage Card ---
              Container(
                constraints: const BoxConstraints(maxWidth: 500),
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Project Stage',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: StreamBuilder<QuerySnapshot>(
                              stream: FirestoreService.getCollection(
                                'projectStages',
                              ).snapshots(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData || snapshot.data == null) {
                                  return const LinearProgressIndicator();
                                }
                                final stages = snapshot.data!.docs
                                    .map((doc) => doc['projectStage']?.toString() ?? '')
                                    .where((val) => val.isNotEmpty)
                                    .toSet()
                                    .toList();

                                bool isStageSelected =
                                    _selectedStage != null &&
                                    stages.contains(_selectedStage);

                                final dropdownValue = isStageSelected
                                    ? _selectedStage
                                    : null;

                                return DropdownButtonFormField<String>(
                                  value: dropdownValue,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: theme.cardColor,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    hintText: 'Select project stage',
                                  ),
                                  icon: Icon(
                                    Icons.arrow_drop_down,
                                    color: primaryColor,
                                  ),
                                  dropdownColor: theme.cardColor,
                                  items: stages.map((stage) {
                                    return DropdownMenuItem<String>(
                                      value: stage,
                                      child: Text(
                                        stage,
                                        style: TextStyle(
                                          color: theme.colorScheme.onSurface,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    if (newValue != null &&
                                        stages.contains(newValue)) {
                                      setState(() {
                                        _selectedStage = newValue;
                                      });
                                    } else {
                                      _showErrorModal(
                                        context,
                                        'Invalid Selection',
                                        'Please try again.',
                                      );
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Tooltip(
                            message: "Add New Stage",
                            child: InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: () => _showAddStageDialog(),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.add,
                                  size: 24,
                                  color: Colors.white,
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

              const SizedBox(height: 50),

              // --- Action Buttons ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: GlassButton(
                        label: 'BACK',
                        onPressed: () => Navigator.of(context).pop(),
                        isSecondary: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GlassButton(
                        label: 'DELETE',
                        onPressed: _selectedStage != null
                            ? _deleteSelectedStage
                            : null,
                        isSecondary: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
