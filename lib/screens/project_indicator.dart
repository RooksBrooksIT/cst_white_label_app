import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/animation.dart';
import 'package:demo_cst/services/firestore_service.dart';

class ProjectIndicatorPage extends StatefulWidget {
  final String? siteId;
  final String projectName;
  final String siteName;
  final String ownerName;

  const ProjectIndicatorPage({
    super.key,
    required this.siteId,
    required this.projectName,
    required this.siteName,
    required this.ownerName,
  });

  @override
  State<ProjectIndicatorPage> createState() => _ProjectIndicatorPageState();
}

class _ProjectIndicatorPageState extends State<ProjectIndicatorPage>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? projectData;
  bool isLoading = true;
  String? errorMsg;
  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;
  Animation<double>? _scaleAnimation;

  // Define our color scheme
  final Color primaryColor = const Color(0xFF0b3470);
  final Color secondaryColor = const Color(0xFF1a4a8f);
  final Color accentColor = const Color(0xFF4a7de2);
  final Color backgroundColor = const Color(0xFFf8f9fa);
  final Color cardColor = Colors.white;
  final Color textColor = const Color(0xFF2c3e50);
  final Color successColor = const Color(0xFF2ecc71);
  final Color warningColor = const Color(0xFFf39c12);
  final Color dangerColor = const Color(0xFFe74c3c);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fetchProjectData();
  }

  Future<void> _fetchProjectData() async {
    try {
      if (widget.siteId == null || widget.siteId!.isEmpty) {
        setState(() {
          errorMsg = 'Project not found';
          isLoading = false;
        });
        return;
      }

      final col = FirestoreService.getCollection('projects');
      QuerySnapshot<Map<String, dynamic>> query =
          await col.where('siteId', isEqualTo: widget.siteId).limit(1).get();
      if (query.docs.isEmpty) {
        query =
            await col.where('siteid', isEqualTo: widget.siteId).limit(1).get();
      }

      if (query.docs.isNotEmpty) {
        setState(() {
          projectData = query.docs.first.data();
          isLoading = false;
          // Initialize animations after data is loaded
          _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
            CurvedAnimation(
              parent: _animationController!,
              curve: Curves.easeInOut,
            ),
          );
          _scaleAnimation = Tween<double>(begin: 0.95, end: 1).animate(
            CurvedAnimation(
              parent: _animationController!,
              curve: Curves.easeOutBack,
            ),
          );
        });
        _animationController?.forward();
      } else {
        setState(() {
          errorMsg = 'Project not found';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMsg = 'Error loading project: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Project Indicator',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: primaryColor,
        centerTitle: true,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryColor,
                secondaryColor,
              ],
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(16),
            ),
          ),
        ),
        iconTheme: const IconThemeData(),
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator.adaptive(
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading project data...',
                    style: TextStyle(
                      color: textColor.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : errorMsg != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: dangerColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          errorMsg!,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _fetchProjectData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                          child: const Text(
                            'Try Again',
                            style: TextStyle(),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : (_fadeAnimation != null && _scaleAnimation != null)
                  ? FadeTransition(
                      opacity: _fadeAnimation!,
                      child: ScaleTransition(
                        scale: _scaleAnimation!,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Project Details Card
                              _buildProjectDetailsCard(),
                              const SizedBox(height: 24),
                              // Financial Indicator Card
                              _buildFinancialIndicatorCard(),
                            ],
                          ),
                        ),
                      ),
                    )
                  : Container(),
    );
  }

  Widget _buildProjectDetailsCard() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      shadowColor: Colors.black.withOpacity(0.1),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.assignment, color: primaryColor, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  'Project Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(height: 1, ),
            const SizedBox(height: 16),
            _buildDetailRow(
                'Site ID',
                projectData?['siteid'] ?? projectData?['siteId'] ?? '-',
                Icons.fingerprint),
            _buildDetailRow(
                'Project Name', projectData?['projectName'] ?? '-', Icons.work),
            _buildDetailRow('Site Location',
                projectData?['siteLocation'] ?? '-', Icons.location_on),
            _buildDetailRow(
                'Owner', projectData?['ownerName'] ?? '-', Icons.person),
            _buildDetailRow(
                'Start Date',
                _formatDate(projectData?['plannedStartDate']),
                Icons.calendar_today),
            _buildDetailRow(
                'End Date',
                _formatDate(projectData?['plannedEndDate']),
                Icons.event_available),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialIndicatorCard() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      shadowColor: Colors.black.withOpacity(0.1),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.attach_money, color: primaryColor, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  'Financial Indicator',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(height: 1, ),
            const SizedBox(height: 16),
            _buildDetailRow('Amount Paid',
                _formatCurrency(projectData?['amountPaid']), Icons.payment),
            _buildDetailRow('Amount Spent',
                _formatCurrency(projectData?['amountSpent']), Icons.money_off),
            _buildDetailRow(
                'Balance Amount',
                _formatCurrency(projectData?['amountBalance']),
                Icons.account_balance_wallet),
            const SizedBox(height: 24),
            _buildFinancialIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: primaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: textColor.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialIndicator() {
    if (projectData == null) return Container();

    final paid = _parseNumber(projectData!['amountPaid']);
    final spent = _parseNumber(projectData!['amountSpent']);
    final balance = _parseNumber(projectData!['amountBalance']);
    final indicatorValue = paid - spent;
    final percent = balance > 0 && paid > 0 ? (balance / paid) * 100 : 0;

    Color color;
    String status;
    String description;
    IconData icon;

    if (percent > 50) {
      color = successColor;
      status = 'Excellent';
      description = 'Your project finances are in great shape!';
      icon = Icons.trending_up;
    } else if (percent > 25) {
      color = warningColor;
      status = 'Good';
      description = 'Project finances are stable but monitor closely.';
      icon = Icons.trending_flat;
    } else if (percent > 10) {
      color = warningColor;
      status = 'Warning';
      description = 'Attention needed on project finances.';
      icon = Icons.trending_down;
    } else {
      color = dangerColor;
      status = 'Critical';
      description = 'Immediate action required on finances!';
      icon = Icons.warning;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Financial Health',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Stack(
            children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                  
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.easeOutQuart,
                    height: 10,
                    width: constraints.maxWidth * (percent / 100),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, color.withOpacity(0.7)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(5),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                status,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Text(
                '${percent.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              color: textColor.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatCard('Paid', _formatCurrency(paid), primaryColor),
              _buildStatCard('Spent', _formatCurrency(spent), accentColor),
              _buildStatCard('Balance', _formatCurrency(balance), color),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '-';
    if (date is String) {
      try {
        final dt = DateTime.parse(date);
        return DateFormat('dd MMM yyyy').format(dt);
      } catch (_) {
        return date;
      }
    } else if (date is Timestamp) {
      return DateFormat('dd MMM yyyy').format(date.toDate());
    } else if (date is DateTime) {
      return DateFormat('dd MMM yyyy').format(date);
    }
    return date.toString();
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return '-';
    if (value is num) {
      return NumberFormat.currency(
        symbol: '₹',
        decimalDigits: 2,
        locale: 'en_IN',
      ).format(value);
    }
    if (value is String) {
      final num? parsed =
          num.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), ''));
      if (parsed != null) {
        return NumberFormat.currency(
          symbol: '₹',
          decimalDigits: 2,
          locale: 'en_IN',
        ).format(parsed);
      }
    }
    return value.toString();
  }

  double _parseNumber(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    }
    return 0;
  }
}