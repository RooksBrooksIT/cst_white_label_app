import 'package:flutter/material.dart';
import 'package:demo_cst/services/firestore_service.dart';
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
  List<String> _allProjectStages = [];
  Map<String, String> _siteSupervisors = {};
  Map<String, Set<String>> _siteProjectStages = {};

  bool _loading = true;

  Color get primaryColor => Theme.of(context).colorScheme.primary;

  @override
  void initState() {
    super.initState();
    _fetchSiteSupervisorData();
  }

  Future<void> _fetchSiteSupervisorData() async {
    setState(() => _loading = true);
    try {
      if (!FirestoreService.isReady) {
        await FirestoreService.initialize();
      }

      final siteIds = <String>{};
      final siteSupervisors = <String, String>{};
      final siteProjectStages = <String, Set<String>>{};
      final globalStages = <String>{};

      void processDoc(Map<String, dynamic> data, String fallbackId) {
        final site = (data['siteId'] ??
                data['site'] ??
                data['siteCode'] ??
                fallbackId)
            .toString()
            .trim();
        final supervisor = (data['supervisor'] ??
                data['supervisorName'] ??
                data['Supervisor ID'] ??
                data['supervisorId'] ??
                '')
            .toString()
            .trim();
        final projectStage = (data['projectStage'] ??
                data['projectPhase'] ??
                data['stage'] ??
                '')
            .toString()
            .trim();

        if (site.isNotEmpty && site != 'uninitialized') {
          siteIds.add(site);
          if (supervisor.isNotEmpty && (siteSupervisors[site] == null || siteSupervisors[site]!.isEmpty)) {
            siteSupervisors[site] = supervisor;
          }
          if (projectStage.isNotEmpty) {
            siteProjectStages.putIfAbsent(site, () => <String>{}).add(projectStage);
            globalStages.add(projectStage);
          }
        }
      }

      // 1. Fetch from siteSupervisorMap (primary site mapping)
      try {
        final mapSnap = await FirestoreService.siteSupervisorMap.get();
        for (var doc in mapSnap.docs) {
          processDoc(doc.data(), doc.id);
        }
      } catch (e) {
        debugPrint('IncentiveCalc: Error fetching siteSupervisorMap: $e');
      }

      // 2. Fetch from siteSupervisorProjectStageSchedule
      try {
        final schedSnap = await FirestoreService.siteSupervisorProjectStageSchedule.get();
        for (var doc in schedSnap.docs) {
          processDoc(doc.data(), doc.id);
        }
      } catch (e) {
        debugPrint('IncentiveCalc: Error fetching project stage schedule: $e');
      }

      // 3. Fetch from siteSupervisorProjectStageActual
      try {
        final actSnap = await FirestoreService.siteSupervisorProjectStageActual.get();
        for (var doc in actSnap.docs) {
          processDoc(doc.data(), doc.id);
        }
      } catch (e) {
        debugPrint('IncentiveCalc: Error fetching project stage actual: $e');
      }

      // 4. Fetch from siteSupervisorEntries
      try {
        final entrySnap = await FirestoreService.siteSupervisorEntries.get();
        for (var doc in entrySnap.docs) {
          processDoc(doc.data(), doc.id);
        }
      } catch (e) {
        debugPrint('IncentiveCalc: Error fetching siteSupervisorEntries: $e');
      }

      // 5. Fetch from Site collection (all configured sites)
      try {
        final siteSnap = await FirestoreService.sites.get();
        for (var doc in siteSnap.docs) {
          siteIds.add(doc.id);
        }
      } catch (e) {
        debugPrint('IncentiveCalc: Error fetching Site collection: $e');
      }

      // 6. Fetch from projectStages collection
      try {
        final stagesSnap = await FirestoreService.projectStages.get();
        for (var doc in stagesSnap.docs) {
          final st = (doc.data()['projectStage'] ?? doc.data()['stage'] ?? '').toString().trim();
          if (st.isNotEmpty) {
            globalStages.add(st);
          }
        }
      } catch (e) {
        debugPrint('IncentiveCalc: Error fetching projectStages collection: $e');
      }

      // Ensure every site has at least the global project stages if none specific found
      final allGlobalList = globalStages.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      for (var site in siteIds) {
        if (!siteProjectStages.containsKey(site) || siteProjectStages[site]!.isEmpty) {
          siteProjectStages[site] = Set<String>.from(allGlobalList);
        }
      }

      final sortedSites = siteIds.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      if (!mounted) return;
      setState(() {
        _siteIds = sortedSites;
        _siteSupervisors = siteSupervisors;
        _siteProjectStages = siteProjectStages;
        _allProjectStages = allGlobalList;
        _filteredProjectStages = [];
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error fetching site supervisor data: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Incentive Calculation',
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
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 800.0 : (isTablet ? 650.0 : double.infinity),
            ),
            child: _loading
                ? Center(child: CircularProgressIndicator(color: primaryColor))
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Main Calculation Card
                        Card(
                          elevation: 0,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: primaryColor.withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.calculate_rounded,
                                          color: primaryColor,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: const [
                                          Text(
                                            'Calculate Incentives',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0A183D),
                                              fontSize: 18,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Select site details to calculate incentives',
                                            style: TextStyle(
                                              color: Color(0xFF64748B),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 28, color: Color(0xFFE2E8F0)),

                                  const Text(
                                    'Site Information',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0A183D),
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  _buildDropdown(
                                    label: 'Site ID *',
                                    value: _selectedSiteId,
                                    items: _siteIds,
                                    onChanged: (newValue) {
                                      setState(() {
                                        _selectedSiteId = newValue;
                                        _supervisorName = newValue != null
                                            ? (_siteSupervisors[newValue] ?? '')
                                            : '';
                                        _filteredProjectStages = (newValue != null &&
                                                _siteProjectStages[newValue] != null &&
                                                _siteProjectStages[newValue]!.isNotEmpty)
                                            ? (_siteProjectStages[newValue]!
                                                .toList()
                                              ..sort((a, b) => a
                                                  .toLowerCase()
                                                  .compareTo(b.toLowerCase())))
                                            : List.from(_allProjectStages);
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
                                          color: Color(0xFF0A183D),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        style: const TextStyle(
                                          color: Color(0xFF0A183D),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14.5,
                                        ),
                                        decoration: InputDecoration(
                                          prefixIcon: Icon(
                                            Icons.person_rounded,
                                            color: primaryColor,
                                            size: 20,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(color: primaryColor, width: 1.8),
                                          ),
                                          filled: true,
                                          fillColor: Colors.white,
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 14,
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
                                    label: 'Project Stage *',
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

                                  // Calculate Button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.check_circle_rounded, size: 20),
                                      label: const Text(
                                        'CALCULATE',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        elevation: 2,
                                      ),
                                      onPressed: _calculate,
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Reset Button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.refresh_rounded, size: 20),
                                      label: const Text(
                                        'RESET',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: const Color(0xFF0A183D),
                                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                      ),
                                      onPressed: _reset,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Information Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: primaryColor.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: primaryColor,
                                size: 22,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  'Select a site to view available project stages and calculate performance incentives.',
                                  style: const TextStyle(
                                    color: Color(0xFF0A183D),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
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
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF0A183D),
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: (value != null && items.contains(value)) ? value : null,
          isExpanded: true,
          dropdownColor: Colors.white,
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.list_alt_rounded, color: primaryColor, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor, width: 1.8),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
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
            'Select ${label.replaceAll(' *', '')}',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
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
