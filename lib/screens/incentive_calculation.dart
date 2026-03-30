import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_button.dart';
import 'incentive_calculation_sheet.dart';

class IncentiveCalculation extends StatefulWidget {
  const IncentiveCalculation({super.key});

  @override
  State<IncentiveCalculation> createState() => _IncentiveCalculationState();
}

class _IncentiveCalculationState extends State<IncentiveCalculation> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedSiteId;
  String? _selectedProjectStage;
  String _supervisorName = '';

  List<String> _siteIds = [];
  List<String> _filteredProjectStages = [];
  Map<String, String> _siteSupervisors = {};
  Map<String, Set<String>> _siteProjectStages = {};

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchSiteSupervisorData();
  }

  Future<void> _fetchSiteSupervisorData() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('siteSupervisorEntries')
        .get();
    final siteIds = <String>{};
    final siteSupervisors = <String, String>{};
    final siteProjectStages = <String, Set<String>>{};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final site = data['siteId'] as String? ?? '';
      final supervisor = data['supervisorId'] as String? ?? '';
      final projectStage = data['projectStage'] as String? ?? '';

      if (site.isNotEmpty) siteIds.add(site);
      if (site.isNotEmpty && supervisor.isNotEmpty) {
        siteSupervisors[site] = supervisor;
      }
      if (site.isNotEmpty && projectStage.isNotEmpty) {
        siteProjectStages.putIfAbsent(site, () => <String>{}).add(projectStage);
      }
    }

    setState(() {
      _siteIds = siteIds.toList();
      _siteSupervisors = siteSupervisors;
      _siteProjectStages = siteProjectStages;
      _filteredProjectStages = [];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GlassScaffold(
      title: 'Incentive Calculation',
      appBarBackgroundColor: colorScheme.primary,
      appBarForegroundColor: colorScheme.onPrimary,
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Calculate Incentives',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Select site details to calculate incentives',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 32),
                            Text(
                              'Site Information',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildDropdown(
                              label: 'Site ID',
                              value: _selectedSiteId,
                              items: _siteIds,
                              onChanged: (newValue) {
                                setState(() {
                                  _selectedSiteId = newValue;
                                  _supervisorName = newValue != null
                                      ? (_siteSupervisors[newValue] ?? '')
                                      : '';
                                  _filteredProjectStages = newValue != null
                                      ? _siteProjectStages[newValue]?.toList() ?? []
                                      : [];
                                  _selectedProjectStage = null;
                                });
                              },
                              validator: (value) => value == null ? 'Please select Site ID' : null,
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              decoration: InputDecoration(
                                labelText: 'Supervisor Name',
                                prefixIcon: Icon(Icons.person_outline, color: colorScheme.primary),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: theme.dividerColor),
                                ),
                                filled: true,
                                fillColor: theme.cardColor,
                              ),
                              controller: TextEditingController(text: _supervisorName),
                              readOnly: true,
                            ),
                            const SizedBox(height: 20),
                            _buildDropdown(
                              label: 'Project Stage',
                              value: _selectedProjectStage,
                              items: _filteredProjectStages,
                              onChanged: (newValue) {
                                setState(() {
                                  _selectedProjectStage = newValue;
                                });
                              },
                              validator: (value) => value == null ? 'Please select Project Stage' : null,
                            ),
                            const SizedBox(height: 32),
                            GlassButton(
                              label: 'CALCULATE',
                              onPressed: _calculate,
                            ),
                            const SizedBox(height: 12),
                            GlassButton(
                              label: 'RESET',
                              onPressed: _reset,
                              isSecondary: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colorScheme.primary.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: colorScheme.primary, size: 24),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Select a site to view available project stages and calculate incentives',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(Icons.list_alt, color: colorScheme.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
        filled: true,
        fillColor: theme.cardColor,
      ),
      items: items.map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }

  void _calculate() {
    if (_formKey.currentState!.validate()) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => IncentiveCalculationSheet(
            siteId: _selectedSiteId!,
            supervisor: _supervisorName,
            projectStage: _selectedProjectStage!,
          ),
        ),
      );
    }
  }

  void _reset() {
    setState(() {
      _selectedSiteId = null;
      _selectedProjectStage = null;
      _supervisorName = '';
      _filteredProjectStages = [];
      _formKey.currentState?.reset();
    });
  }
}