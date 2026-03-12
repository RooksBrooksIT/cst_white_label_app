import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/screens/incentive_calculation_sheet.dart';


class IncentiveCalculation extends StatefulWidget {
  const IncentiveCalculation({super.key});

  @override
  _IncentiveCalculationState createState() => _IncentiveCalculationState();
}

class _IncentiveCalculationState extends State<IncentiveCalculation> {
  final _formKey = GlobalKey<FormState>();
  static const Color primaryColor = Color(0xFF0b3470);
  static const Color accentColor = Color(0xFF4a7cda);
  static const Color backgroundColor = Color(0xFFf8f9fa);
  static const Color textColor = Color(0xFF2c3e50);
  static const Color cardColor = Colors.white;

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
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Incentive Calculation',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 4,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Calculate Incentives',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Select site details to calculate incentives',
                              style: TextStyle(
                                fontSize: 14,
                                color: textColor.withOpacity(0.7),
                              ),
                            ),
                            SizedBox(height: 30),
                            Text(
                              'Site Information',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                            ),
                            SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: 'Site ID',
                                labelStyle: TextStyle(color: primaryColor),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: primaryColor, width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                              dropdownColor: cardColor,
                              value: _selectedSiteId,
                              items: _siteIds.map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(
                                    value,
                                    style: TextStyle(color: textColor),
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedSiteId = newValue;
                                  _supervisorName = newValue != null
                                      ? (_siteSupervisors[newValue] ?? '')
                                      : '';
                                  // Update project stages for selected site
                                  _filteredProjectStages = newValue != null
                                      ? _siteProjectStages[newValue]?.toList() ?? []
                                      : [];
                                  _selectedProjectStage =
                                      null; // Reset project stage selection
                                });
                              },
                              validator: (value) =>
                                  value == null ? 'Please select Site ID' : null,
                              style: TextStyle(color: textColor),
                              icon: Icon(Icons.arrow_drop_down, color: primaryColor),
                            ),
                            SizedBox(height: 20),
                            TextFormField(
                              decoration: InputDecoration(
                                labelText: 'Supervisor Name',
                                labelStyle: TextStyle(color: primaryColor),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: primaryColor, width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                              controller: TextEditingController(text: _supervisorName),
                              readOnly: true,
                              style: TextStyle(color: textColor),
                            ),
                            SizedBox(height: 20),
                            DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: 'Project Stage',
                                labelStyle: TextStyle(color: primaryColor),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: primaryColor, width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                              dropdownColor: cardColor,
                              value: _selectedProjectStage,
                              items: _filteredProjectStages.map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(
                                    value,
                                    style: TextStyle(color: textColor),
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedProjectStage = newValue;
                                });
                              },
                              validator: (value) =>
                                  value == null ? 'Please select Project Stage' : null,
                              style: TextStyle(color: textColor),
                              icon: Icon(Icons.arrow_drop_down, color: primaryColor),
                            ),
                            SizedBox(height: 30),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _calculate,
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.symmetric(vertical: 16),
                                      backgroundColor: primaryColor,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      elevation: 2,
                                    ),
                                    child: Text(
                                      'Calculate',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _reset,
                                    style: OutlinedButton.styleFrom(
                                      padding: EdgeInsets.symmetric(vertical: 16),
                                      side: BorderSide(color: primaryColor),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Text(
                                      'Reset',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: primaryColor,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: OutlinedButton.styleFrom(
                                      padding: EdgeInsets.symmetric(vertical: 16),
                                      side: BorderSide(color: Colors.red.shade700),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Text(
                                      'Cancel',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red.shade700,
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
                  ),
                  SizedBox(height: 20),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: primaryColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: primaryColor, size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Select a site to view available project stages and calculate incentives',
                            style: TextStyle(
                              fontSize: 14,
                              color: textColor.withOpacity(0.8),
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