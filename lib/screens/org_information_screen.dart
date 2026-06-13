import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../services/firestore_service.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_text_field.dart';
import '../widgets/glass_button.dart';

class OrgInformationScreen extends StatefulWidget {
  const OrgInformationScreen({super.key});

  @override
  State<OrgInformationScreen> createState() => _OrgInformationScreenState();
}

class _OrgInformationScreenState extends State<OrgInformationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _orgPhoneController = TextEditingController();

  bool _isLoading = false;
  bool _isFetching = true;

  @override
  void initState() {
    super.initState();
    _fetchInformation();
  }

  Future<void> _fetchInformation() async {
    try {
      var doc = await FirestoreService.orgDataDoc.get();

      // Fallback: If admin/data doc doesn't exist, check root doc (legacy)
      if (!doc.exists) {
        debugPrint('OrgInformationScreen: Data doc not found in admin, falling back to root.');
        doc = await FirestoreService.rootOrgDoc.get();
      }

      if (doc.exists && mounted) {
        final data = doc.data();
        setState(() {
          _addressController.text = data?['address'] ?? '';
          _orgPhoneController.text = data?['phone'] ?? data?['orgPhone'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error fetching org information: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load organisation info')),
        );
      }
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  Future<void> _saveInformation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await FirestoreService.orgDataDoc.set({
        'address': _addressController.text.trim(),
        'phone': _orgPhoneController.text.trim(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Organisation information updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving org information: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating information: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _orgPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 600;

    return GlassScaffold(
      title: 'Organisation Info',
      onBack: () => Navigator.pop(context),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
          child: _isFetching
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Update Information',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Update your organisation address and contact number.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          GlassTextField(
                            controller: _addressController,
                            label: 'Organisation Address',
                            icon: Icons.location_on_rounded,
                            maxLines: 3,
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return 'Please enter the address';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          GlassTextField(
                            controller: _orgPhoneController,
                            label: 'Organisation Phone Number',
                            icon: Icons.phone_rounded,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return 'Please enter the phone number';
                              }
                              if (val.length != 10) {
                                return 'Phone number must be 10 digits';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  GlassButton(
                    label: 'SAVE',
                    isLoading: _isLoading,
                    onPressed: _saveInformation,
                  ),
                ],
              ),
            ),
        ),
      ),
    );
  }
}
