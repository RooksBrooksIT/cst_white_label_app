import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';

class ProjectStageConfig extends StatefulWidget {
  const ProjectStageConfig({super.key});

  @override
  _ProjectStageConfigState createState() => _ProjectStageConfigState();
}

class _ProjectStageConfigState extends State<ProjectStageConfig> {
  String? _selectedStage;
  final TextEditingController _newStageController = TextEditingController();

  // --- Colors ---
  static const Color kPrimaryColor = Color(0xFF0B3470);
  static const Color kBackground = Color(0xFFF7F9FC);
  static const Color kErrorColor = Color(0xFFD32F2F);

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
                        color: kPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _newStageController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Stage Name',
                        labelStyle: TextStyle(color: kPrimaryColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: kPrimaryColor, width: 2),
                        ),
                        filled: true,
                        fillColor: kBackground,
                      ),
                      cursorColor: kPrimaryColor,
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
                            foregroundColor: kPrimaryColor,
                          ),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.save, ),
                          label: const Text('Save',
                              style: TextStyle()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isDuplicate ? Colors.grey : kPrimaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 2,
                          ),
                          onPressed: isDuplicate
                              ? null
                              : () async {
                                  final newStage =
                                      _newStageController.text.trim();
                                  if (newStage.isEmpty) return;

                                  final nextId = await _getNextStageId();
                                  await FirebaseFirestore.instance
                                      .collection('projectStages')
                                      .doc(nextId)
                                      .set({
                                    'projectStageId': nextId,
                                    'projectStage': newStage,
                                  });

                                  Navigator.of(context).pop();
                                  setState(() {
                                    _selectedStage = newStage;
                                  });
                                  await _showSuccessAnimation(
                                      message: 'Stage added successfully!');
                                },
                        ),
                      ],
                    ),
                    if (isDuplicate)
                      const Padding(
                        padding: EdgeInsets.only(top: 12.0),
                        child: Text(
                          'This stage already exists.',
                          style: TextStyle(
                            color: Colors.red,
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

  Future<void> _showSuccessAnimation(
      {String message = 'Stage added successfully!'}) async {
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
                    color: kPrimaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(),
                  ),
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
                const Icon(Icons.error_outline,
                    color: Colors.redAccent, size: 60),
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
                  style: const TextStyle(
                    fontSize: 15,
                    
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kErrorColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK', style: TextStyle()),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String> _getNextStageId() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('projectStages')
        .orderBy('projectStageId', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return 'PST001';
    } else {
      final lastId = snapshot.docs.first['projectStageId'] as String;
      final number =
          int.tryParse(lastId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      final nextNumber = number + 1;
      return 'PST${nextNumber.toString().padLeft(3, '0')}';
    }
  }

  Future<bool> _isDuplicateStage(String stage) async {
    final snapshot =
        await FirebaseFirestore.instance.collection('projectStages').get();
    final existingStages = snapshot.docs
        .map((doc) => (doc['projectStage'] as String).toLowerCase())
        .toList();

    return existingStages.contains(stage.toLowerCase());
  }

  Future<void> _deleteSelectedStage() async {
    if (_selectedStage == null) {
      _showErrorModal(
          context, 'No Stage Selected', 'Please select a stage to delete.');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Stage'),
          content: Text(
              'Are you sure you want to delete the stage "${_selectedStage!}"? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kErrorColor,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child:
                  const Text('Delete', style: TextStyle()),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('projectStages')
          .where('projectStage', isEqualTo: _selectedStage)
          .get();

      if (snapshot.docs.isEmpty) {
        _showErrorModal(context, 'Not Found',
            'The selected stage was not found in Firestore.');
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

  Widget _buildCircularActionButton({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color iconColor,
    required Color labelColor,
    required VoidCallback? onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 55,
          height: 55,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(icon, color: iconColor),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text(
          'Project Stage Configuration',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20,),
        ),
        centerTitle: true,
        backgroundColor: kPrimaryColor,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // --- Project Stage Card ---
              Container(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(16),
                  
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Project Stage',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: kPrimaryColor,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('projectStages')
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return const LinearProgressIndicator();
                                  }
                                  final stages = snapshot.data!.docs
                                      .map((doc) =>
                                          doc['projectStage'] as String)
                                      .toSet()
                                      .toList();

                                  bool isStageSelected = _selectedStage != null &&
                                      stages.contains(_selectedStage);

                                  final dropdownValue =
                                      isStageSelected ? _selectedStage : null;

                                  return DropdownButtonFormField<String>(
                                    value: dropdownValue,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: kBackground,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      hintText: 'Select project stage',
                                    ),
                                    icon: const Icon(Icons.arrow_drop_down,
                                        color: kPrimaryColor),
                                    dropdownColor: Colors.white,
                                    items: stages.map((stage) {
                                      return DropdownMenuItem<String>(
                                        value: stage,
                                        child: Text(stage,
                                            style: TextStyle(
                                                color: kPrimaryColor,
                                                fontWeight: FontWeight.w500)),
                                      );
                                    }).toList(),
                                    onChanged: (String? newValue) {
                                      if (newValue != null &&
                                          stages.contains(newValue)) {
                                        setState(() {
                                          _selectedStage = newValue;
                                        });
                                      } else {
                                        _showErrorModal(context,
                                            'Invalid Selection', 'Please try again.');
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
                                  decoration: const BoxDecoration(
                                    color: kPrimaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.add,
                                       size: 24),
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

              const SizedBox(height: 50),

              // --- Action Buttons ---
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildCircularActionButton(
                    icon: Icons.arrow_back,
                    label: 'Back',
                    backgroundColor: Colors.green.shade100,
                    iconColor: Colors.green.shade900,
                    labelColor: Colors.green.shade800,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 40),
                  _buildCircularActionButton(
                    icon: Icons.delete,
                    label: 'Delete',
                    backgroundColor: _selectedStage != null
                        ? Colors.red.shade100
                        : Colors.grey.shade200,
                    iconColor: _selectedStage != null
                        ? Colors.red.shade900
                        : Colors.grey.shade500,
                    labelColor: Colors.red.shade700,
                    onPressed:
                        _selectedStage != null ? _deleteSelectedStage : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
