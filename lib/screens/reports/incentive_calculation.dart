import 'package:flutter/material.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';
import 'package:demo_cst/widgets/glass_card.dart';
import 'package:demo_cst/widgets/glass_button.dart';
import 'package:demo_cst/screens/reports/incentive_calculation_sheet.dart';
import 'package:demo_cst/utils/app_theme.dart';

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
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;
    final maxContentWidth = 900.0;

    final textColor = isDark ? Colors.white : const Color(0xFF0A183D);
    final subtextColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
    final labelColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
    final iconColor = isDark ? AppTheme.getCardAccent(primaryColor) : primaryColor;
    final fieldBg = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFCBD5E1);

    return GlassScaffold(
      title: 'Incentive Calculation',
      onBack: () => Navigator.pop(context),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
          child: _loading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
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
                                  Text(
                                    'Calculate Incentives',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: textColor,
                                      fontSize: 20,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Select site details to calculate incentives',
                                    style: TextStyle(
                                      color: subtextColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'Site Information',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: textColor,
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
                                      Text(
                                        'Supervisor Name',
                                        style: TextStyle(
                                          color: labelColor,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        style: TextStyle(
                                          color: textColor,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                        ),
                                        decoration: InputDecoration(
                                          prefixIcon: Icon(
                                            Icons.person_outline,
                                            color: iconColor,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(14),
                                            borderSide: BorderSide(color: borderColor),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(14),
                                            borderSide: BorderSide(color: borderColor),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(14),
                                            borderSide: BorderSide(color: primaryColor, width: 1.8),
                                          ),
                                          filled: true,
                                          fillColor: fieldBg,
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
                            color: primaryColor.withValues(alpha: isDark ? 0.15 : 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: primaryColor.withValues(alpha: 0.3),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: iconColor,
                                size: 24,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  'Select a site to view available project stages and calculate incentives',
                                  style: TextStyle(
                                    color: textColor,
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
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;
    final textColor = isDark ? Colors.white : const Color(0xFF0A183D);
    final labelColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
    final iconColor = isDark ? AppTheme.getCardAccent(primaryColor) : primaryColor;
    final fieldBg = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFCBD5E1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: (value != null && items.contains(value)) ? value : null,
          isExpanded: true,
          dropdownColor: isDark ? AppTheme.getDarkAccent(primaryColor) : Colors.white,
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.list_alt, color: iconColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: primaryColor, width: 1.8),
            ),
            filled: true,
            fillColor: fieldBg,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          style: TextStyle(
            fontSize: 14,
            color: textColor,
            fontWeight: FontWeight.w700,
          ),
          items: items.map((String val) {
            return DropdownMenuItem<String>(
              value: val,
              child: Text(
                val,
                style: TextStyle(
                  fontSize: 14,
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          validator: validator,
          hint: Text(
            'Select $label',
            style: TextStyle(
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
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
