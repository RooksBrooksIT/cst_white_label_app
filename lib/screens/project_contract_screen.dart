import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../widgets/glass_button.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_text_field.dart';
import 'package:flutter/material.dart';

class ProjectContractScreen extends StatefulWidget {
  const ProjectContractScreen({super.key});

  @override
  State<ProjectContractScreen> createState() => _ProjectContractScreenState();
}

class _ProjectContractScreenState extends State<ProjectContractScreen> {
  final _newContractTypeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _selectedContractType;

  Future<void> _deleteSelectedContractType() async {
    if (_selectedContractType == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contract Type'),
        content: Text('Are you sure you want to delete "$_selectedContractType"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('DELETE', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final snapshot = await FirestoreService.getCollection('projectContracts')
          .where('projectContract', isEqualTo: _selectedContractType)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        await snapshot.docs.first.reference.delete();
        setState(() => _selectedContractType = null);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contract type deleted')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _showAddContractTypeModal() async {
    _newContractTypeController.clear();
    bool isDuplicate = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            return Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 20),
                  Text('New Contract Type', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  GlassTextField(
                    controller: _newContractTypeController,
                    label: 'Contract Type Name',
                    icon: Icons.contrast_rounded,
                    onChanged: (value) async {
                      final snapshot = await FirestoreService.getCollection('projectContracts')
                          .where('projectContract', isEqualTo: value.trim())
                          .limit(1)
                          .get();
                      setDialogState(() => isDuplicate = snapshot.docs.isNotEmpty);
                    },
                  ),
                  if (isDuplicate)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text('This contract type already exists', style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
                    ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(child: GlassButton(label: 'CANCEL', onPressed: () => Navigator.pop(context), isSecondary: true)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GlassButton(
                          label: 'SAVE',
                          onPressed: isDuplicate ? null : () async {
                            final name = _newContractTypeController.text.trim();
                            if (name.isEmpty) return;

                            final querySnapshot = await FirestoreService.getCollection('projectContracts').get();
                            int maxId = querySnapshot.docs.fold(0, (prev, doc) {
                              if (doc.id.startsWith('CT')) {
                                final idNum = int.tryParse(doc.id.substring(2)) ?? 0;
                                return idNum > prev ? idNum : prev;
                              }
                              return prev;
                            });

                            final newDocId = 'CT${(maxId + 1).toString().padLeft(3, '0')}';
                            await FirestoreService.getCollection('projectContracts').doc(newDocId).set({'projectContract': name});

                            if (mounted) {
                              Navigator.pop(context);
                              setState(() => _selectedContractType = name);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _newContractTypeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassScaffold(
      title: 'Contract Management',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            GlassCard(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(backgroundColor: theme.primaryColor, child: const Icon(Icons.description_outlined, color: Colors.white)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Contract Types', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              Text('Configure standard project contracts', style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirestoreService.getCollection('projectContracts').snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData || snapshot.data == null) return const LinearProgressIndicator();
                              final items = snapshot.data!.docs
                                  .map((d) => d['projectContract']?.toString() ?? '')
                                  .where((val) => val.isNotEmpty)
                                  .toList();
                              return DropdownButtonFormField<String>(
                                value: (_selectedContractType != null && items.contains(_selectedContractType)) ? _selectedContractType : null,
                                decoration: InputDecoration(
                                  labelText: 'Select Contract Type',
                                  prefixIcon: const Icon(Icons.search_rounded),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  filled: true,
                                  fillColor: theme.cardColor,
                                ),
                                items: items.toSet().map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                                onChanged: (v) => setState(() => _selectedContractType = v),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton.filledTonal(onPressed: _showAddContractTypeModal, icon: const Icon(Icons.add)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(child: GlassButton(label: 'BACK', onPressed: () => Navigator.pop(context), isSecondary: true)),
                const SizedBox(width: 16),
                Expanded(
                  child: GlassButton(
                    label: 'DELETE',
                    onPressed: _selectedContractType == null ? null : _deleteSelectedContractType,
                    isSecondary: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
