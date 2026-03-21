import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProjectContractScreen extends StatefulWidget {
  const ProjectContractScreen({super.key});

  @override
  _ProjectContractScreenState createState() => _ProjectContractScreenState();
}

class _ProjectContractScreenState extends State<ProjectContractScreen> {
  // Constants for styling
  static const double _cardCornerRadius = 28.0;
  static const double _elementPadding = 24.0;
  static const Color _primaryColor = Color(0xFF0b3470);
  static const Color _secondaryColor = Colors.white;
  static const Color _errorColor = Colors.redAccent;
  static const Color _successColor = Colors.green;

  final TextEditingController _newContractTypeController =
      TextEditingController();

  String? _selectedContractType;
  List<String> _contractTypes = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchContractTypes();
    });
  }

  @override
  void dispose() {
    _newContractTypeController.dispose();
    super.dispose();
  }

  /// Fetch all contract types from Firestore
  Future<void> _fetchContractTypes() async {
    try {
      final querySnapshot =
          await FirebaseFirestore.instance.collection('projectContracts').get();
      if (!mounted) return;
      setState(() {
        _contractTypes = querySnapshot.docs
            .map((doc) => doc['projectContract'] as String)
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
          message: 'Failed to fetch contract types: ${e.toString()}',
          isError: true);
    }
  }

  /// Get Firestore Doc ID from contract type
  Future<String?> _getContractTypeDocId(String contractType) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('projectContracts')
          .where('projectContract', isEqualTo: contractType)
          .limit(1)
          .get();
      if (!mounted) return null;
      return querySnapshot.docs.isEmpty ? null : querySnapshot.docs.first.id;
    } catch (e) {
      if (!mounted) return null;
      _showSnackBar(
          message: 'Error locating contract: ${e.toString()}', isError: true);
      return null;
    }
  }

  /// Delete selected contract type with confirmation
  Future<void> _deleteSelectedContractType() async {
    if (_selectedContractType == null) {
      if (!mounted) return;
      _showSnackBar(
        message: 'Please select a contract type to delete',
        isError: true,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text(
          'Are you sure you want to permanently delete the contract type '
          '"${_selectedContractType!}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'DELETE',
              style: TextStyle(color: _errorColor),
            ),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    try {
      final docId = await _getContractTypeDocId(_selectedContractType!);
      if (!mounted) return; // Check again as getContractTypeDocId is async
      if (docId == null) {
        _showSnackBar(
            message: 'Contract type not found in database', isError: true);
        return;
      }

      await FirebaseFirestore.instance
          .collection('projectContracts')
          .doc(docId)
          .delete();

      if (!mounted) return;
      await _fetchContractTypes();
      if (!mounted) return;

      setState(() => _selectedContractType = null);
      _showSnackBar(
          message: 'Contract type deleted successfully', isError: false);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(message: 'Deletion failed: ${e.toString()}', isError: true);
    }
  }

  /// Snackbar helper
  void _showSnackBar({required String message, required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? _errorColor : _successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Show dialog to add a new contract type
  void _showAddContractTypeModal() {
    _newContractTypeController.clear();
    bool isDuplicate = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(_elementPadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New Contract Type',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _newContractTypeController,
                      decoration: InputDecoration(
                        labelText: 'Contract Type Name',
                        labelStyle: TextStyle(
                          color: _primaryColor,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _primaryColor,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _primaryColor,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _primaryColor,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.grey,
                      ),
                      onChanged: (value) {
                        setStateDialog(() {
                          isDuplicate = _contractTypes
                              .map((type) => type.toLowerCase())
                              .contains(value.trim().toLowerCase());
                        });
                      },
                    ),
                    if (isDuplicate)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'This contract type already exists',
                          style: TextStyle(
                            color: _errorColor,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              'CANCEL',
                              style: TextStyle(color: _primaryColor),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isDuplicate ? Colors.grey : _primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: isDuplicate
                                ? null
                                : () async {
                                    final newType =
                                        _newContractTypeController.text.trim();
                                    if (newType.isEmpty) return;

                                    try {
                                      final querySnapshot =
                                          await FirebaseFirestore.instance
                                              .collection('projectContracts')
                                              .get();

                                      if (!mounted) return;

                                      int maxId = querySnapshot.docs.fold(0,
                                          (prev, doc) {
                                        final docId = doc.id;
                                        if (docId.startsWith('CT')) {
                                          final idNumber = int.tryParse(
                                                  docId.substring(2)) ??
                                              0;
                                          return idNumber > prev
                                              ? idNumber
                                              : prev;
                                        }
                                        return prev;
                                      });

                                      final newDocId =
                                          'CT${(maxId + 1).toString().padLeft(3, '0')}';

                                      await FirebaseFirestore.instance
                                          .collection('projectContracts')
                                          .doc(newDocId)
                                          .set({'projectContract': newType});

                                      if (!mounted) return;

                                      Navigator.of(context).pop();
                                      await _fetchContractTypes();
                                      if (!mounted) return;
                                      setState(() =>
                                          _selectedContractType = newType);

                                      _showSnackBar(
                                          message:
                                              'Contract type added successfully',
                                          isError: false);
                                    } catch (e) {
                                      if (!mounted) return;
                                      _showSnackBar(
                                          message: 'Failed to add: $e',
                                          isError: true);
                                    }
                                  },
                            child: const Text(
                              'SAVE',
                              style: TextStyle(),
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Reusable Circular Action Button - LARGE 70x70 ICON BUTTONS
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
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(icon, color: iconColor, size: 28),
            onPressed: onPressed,
            splashRadius: 32,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: labelColor,
            fontWeight: FontWeight.w600,
            fontSize: 12,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo,
      appBar: AppBar(
        title: const Text(
          'Contract Type Management',
          style: TextStyle(
            
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: _primaryColor,
        elevation: 2,
        centerTitle: true,
        iconTheme: const IconThemeData(),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(_elementPadding),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              children: [
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_cardCornerRadius),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(_elementPadding),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                decoration: InputDecoration(
                                  labelText: 'Select Contract Type',
                                  labelStyle: const TextStyle(
                                    
                                  ),
                                  prefixIcon: const Icon(Icons.contrast),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: const Color.fromARGB(
                                      255, 245, 245, 245),
                                ),
                                value: _selectedContractType,
                                items: _contractTypes.map((type) {
                                  return DropdownMenuItem(
                                    value: type,
                                    child: Text(
                                      type,
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedContractType = value;
                                  });
                                },
                                isExpanded: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            FloatingActionButton(
                              heroTag: 'addContractType',
                              backgroundColor: _primaryColor,
                              elevation: 2,
                              mini: true,
                              onPressed: _showAddContractTypeModal,
                              child: const Icon(Icons.add, ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: _elementPadding),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildCircularActionButton(
                      icon: Icons.arrow_back,
                      label: 'Back',
                      backgroundColor: const Color(0xFF8DD08E),
                      iconColor: const Color(0xFF09400C),
                      labelColor: const Color(0xFF0D5E10),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 40),
                    _buildCircularActionButton(
                      icon: Icons.delete,
                      label: 'Delete',
                      backgroundColor: _selectedContractType != null
                          ? const Color(0xFFC5524A)
                          : const Color(0xFFC7726C),
                      iconColor: _selectedContractType != null
                          ? Colors.red.shade900
                          : const Color(0xFF5F0E0E),
                      labelColor: const Color(0xFF6B1609),
                      onPressed: _selectedContractType != null
                          ? _deleteSelectedContractType
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
