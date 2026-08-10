import 'package:flutter/material.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';
import 'package:demo_cst/widgets/glass_card.dart';
import 'package:demo_cst/widgets/glass_button.dart';
import 'package:demo_cst/screens/reports/incentive_calculation_sheet.dart';

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
    final snapshot = await FirestoreService.siteSupervisorEntries.get();
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

    if (!mounted) return;
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;
    final maxContentWidth = 900.0;

    return GlassScaffold(
      title: 'Incentive Calculation',
      appBarForegroundColor: Colors.white,
      onBack: () => Navigator.pop(context),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
          child: _loading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            )
          : SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 24 : (isTablet ? 20 : 16),
                      vertical: isDesktop ? 24 : 20,
                    ),
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
                                  const Text(
                                    'Calculate Incentives',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      fontSize: 20,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Select site details to calculate incentives',
                                    style: TextStyle(
                                      color: Color(0xFFCBD5E1),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  const Text(
                                    'Site Information',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
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
                                            ? _siteProjectStages[newValue]
                                                      ?.toList() ??
                                                  []
                                            : [];
                                        _selectedProjectStage = null;
                                      });
                                    },
                                    validator: (value) => value == null
                                        ? 'Please select Site ID'
                                        : null,
                                  ),
                                  const SizedBox(height: 16),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Supervisor Name',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        style: const TextStyle(
                                          color: Color(0xFF0A183D),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                        ),
                                        decoration: InputDecoration(
                                          prefixIcon: Icon(
                                            Icons.person_outline,
                                            color: theme.primaryColor,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(14),
                                            borderSide: BorderSide.none,
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(14),
                                            borderSide: BorderSide.none,
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(14),
                                            borderSide: BorderSide(color: theme.primaryColor, width: 1.8),
                                          ),
                                          filled: true,
                                          fillColor: Colors.white,
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                        ),
                                        controller: TextEditingController(
                                          text: _supervisorName,
                                        ),
                                        readOnly: true,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _buildDropdown(
                                    label: 'Project Stage',
                                    value: _selectedProjectStage,
                                    items: _filteredProjectStages,
                                    onChanged: (newValue) {
                                      setState(() {
                                        _selectedProjectStage = newValue;
                                      });
                                    },
                                    validator: (value) => value == null
                                        ? 'Please select Project Stage'
                                        : null,
                                  ),
                                  const SizedBox(height: 28),
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
                            color: const Color(0xFF0B1942).withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.4),
                              width: 1.0,
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Color(0xFF10B981),
                                size: 24,
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  'Select a site to view available project stages and calculate incentives',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: (value != null && items.contains(value)) ? value : null,
          isExpanded: true,
          dropdownColor: Colors.white,
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.list_alt, color: theme.primaryColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: theme.primaryColor, width: 1.8),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF0A183D),
            fontWeight: FontWeight.w700,
          ),
          items: items.map((String val) {
            return DropdownMenuItem<String>(
              value: val,
              child: Text(
                val,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF0A183D),
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          validator: validator,
          hint: Text(
            'Select $label',
            style: const TextStyle(
              color: Color(0xFF5A759E),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ],
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
