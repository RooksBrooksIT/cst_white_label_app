import 'package:flutter/material.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/screens/site_status_reportPage.dart';

class SiteStatusReportScreen extends StatefulWidget {
  const SiteStatusReportScreen({super.key});

  @override
  State<SiteStatusReportScreen> createState() => _SiteStatusReportScreenState();
}

class _SiteStatusReportScreenState extends State<SiteStatusReportScreen> {
  // Updated Color Scheme with Navy Blue (#0b3470)
  static const Color primaryColor = Color(0xFF0b3470);
  static const Color primaryLightColor = Color(0xFF1e4a8e);
  static const Color accentColor = Color(0xFF4285F4);
  static const Color successColor = Color(0xFF34A853);
  static const Color warningColor = Color(0xFFFBBC05);
  static const Color dangerColor = Color(0xFFEA4335);
  static const Color backgroundColor = Color(0xFFF8F9FA);
  static const Color cardColor = Colors.white;
  static const Color textColor = Color(0xFF2c3e50);
  static const Color secondaryTextColor = Color(0xFF7f8c8d);

  // State variables
  String? _selectedStatus;
  List<String> _statusOptions = [];
  bool _isLoading = true;
  String? _errorMessage;
  double _spendingPercentage = 0.0;
  double _budgetAmount = 0.0;
  double _spentAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchProjectData();
  }

  Future<void> _fetchProjectData() async {
    try {
      // Fetch status options
      final statusSnapshot = await FirestoreService.getCollection('projectStatus')
          .get();

      // Fetch financial data
      final financialSnapshot = await FirestoreService.getCollection('projectFinances')
          .doc('currentProject')
          .get();

      Set<String> uniqueStatuses = {};
      for (var doc in statusSnapshot.docs) {
        final data = doc.data();
        final stateField = data['projectState'];
        if (stateField is String) {
          uniqueStatuses.add(stateField);
        } else if (stateField is List) {
          for (var status in stateField) {
            if (status is String) uniqueStatuses.add(status);
          }
        }
      }

      // Process financial data
      if (financialSnapshot.exists) {
        final financeData = financialSnapshot.data();
        _budgetAmount = (financeData?['budget'] as num?)?.toDouble() ?? 0.0;
        _spentAmount = (financeData?['spent'] as num?)?.toDouble() ?? 0.0;
        _spendingPercentage = _budgetAmount > 0
            ? _spentAmount / _budgetAmount
            : 0.0;
      }

      if (mounted) {
        setState(() {
          _statusOptions = uniqueStatuses.isNotEmpty
              ? uniqueStatuses.toList()
              : ['No Status Found'];
          _selectedStatus = _statusOptions.first;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _handleReport() {
    if (_selectedStatus != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SiteStatusReportPage(
            status: _selectedStatus!,
            budgetData: {
              'percentage': _spendingPercentage,
              'budget': _budgetAmount,
              'spent': _spentAmount,
              'status': _getSpendingStatus(_spendingPercentage),
            },
          ),
        ),
      );
    }
  }

  void _handleCancel() {
    Navigator.pop(context);
  }

  Color _getSpendingColor(double percentage) {
    if (percentage < 0.25) return successColor;
    if (percentage < 0.5) return warningColor;
    if (percentage < 0.75) return dangerColor;
    return dangerColor;
  }

  String _getSpendingStatus(double percentage) {
    if (percentage < 0.25) return 'On Budget';
    if (percentage < 0.5) return 'Moderate Spending';
    if (percentage < 0.75) return 'High Spending';
    return 'Critical Spending';
  }

  Widget _buildStatusSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PROJECT STATUS',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: secondaryTextColor,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButton<String>(
            value: _selectedStatus,
            isExpanded: true,
            underline: const SizedBox(),
            iconSize: 28,
            dropdownColor: cardColor,
            borderRadius: BorderRadius.circular(10),
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            items: _statusOptions.map((status) {
              return DropdownMenuItem<String>(
                value: status,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    status,
                    style: TextStyle(fontSize: 16, color: textColor),
                  ),
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedStatus = newValue;
              });
            },
            icon: Icon(Icons.arrow_drop_down, color: primaryColor),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: (_selectedStatus == null || _statusOptions.isEmpty)
                ? null
                : _handleReport,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 2,
              shadowColor: primaryColor.withOpacity(0.3),
            ),
            child: const Text(
              'GENERATE REPORT',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: _handleCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              side: BorderSide(
                color: primaryColor.withOpacity(0.5),
                width: 1.5,
              ),
            ),
            child: const Text(
              'CANCEL',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text(
          'Site Status Report',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            
          ),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: dangerColor, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _fetchProjectData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 0,
                    color: primaryColor.withOpacity(0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: primaryColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: primaryColor,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Track project status and financial health. Select status below to generate detailed report.',
                              style: TextStyle(
                                color: secondaryTextColor,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  _buildStatusSelector(),
                  const Spacer(),
                  _buildActionButtons(),
                  const SizedBox(height: 8),
                ],
              ),
            ),
    );
  }
}
