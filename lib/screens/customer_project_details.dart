import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/screens/customer_dashboard.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../utils/responsive.dart';

class Project {
  final String projectName;
  final String projectCategory;
  final String projectSubCategory;
  final String projectType;
  final String projectStage;
  final String projectContract;
  final String ownerName;
  final String contractorName;
  final String siteId;
  final String siteName;
  final String siteLocation;
  final DateTime plannedStartDate;
  final DateTime plannedEndDate;
  final DateTime actualStartDate;
  final DateTime actualEndDate;
  final DateTime contractStartDate;
  final DateTime contractEndDate;
  final double projectBudget;
  final double contractorBudget;
  final double amountSpent;
  final double amountPaid;
  final double amountBalance;
  final bool isContractWork;
  final String currentStatus;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Project({
    required this.projectName,
    required this.projectCategory,
    required this.projectSubCategory,
    required this.projectType,
    required this.projectStage,
    required this.projectContract,
    required this.ownerName,
    required this.contractorName,
    required this.siteId,
    required this.siteName,
    required this.siteLocation,
    required this.plannedStartDate,
    required this.plannedEndDate,
    required this.actualStartDate,
    required this.actualEndDate,
    required this.contractStartDate,
    required this.contractEndDate,
    required this.projectBudget,
    required this.contractorBudget,
    required this.amountSpent,
    required this.amountPaid,
    required this.amountBalance,
    required this.isContractWork,
    required this.currentStatus,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Project.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Helper function to parse dates safely
    DateTime parseDate(dynamic dateValue) {
      if (dateValue == null) return DateTime.now();
      if (dateValue is Timestamp) {
        return dateValue.toDate();
      } else if (dateValue is String) {
        try {
          return DateTime.parse(dateValue);
        } catch (e) {
          return DateTime.now();
        }
      }
      return DateTime.now();
    }

    // Helper function to parse numbers safely
    double parseNumber(dynamic numberValue) {
      if (numberValue == null) return 0.0;
      if (numberValue is int) {
        return numberValue.toDouble();
      } else if (numberValue is double) {
        return numberValue;
      } else if (numberValue is String) {
        try {
          return double.parse(numberValue);
        } catch (e) {
          return 0.0;
        }
      }
      return 0.0;
    }

    return Project(
      projectName: data['projectName'] ?? 'Not Available',
      projectCategory: data['projectCategory'] ?? 'Not Available',
      projectSubCategory: data['projectSubCategory'] ?? 'Not Available',
      projectType: data['projectType'] ?? 'Not Available',
      projectStage: data['projectStage'] ?? 'Not Available',
      projectContract: data['projectContract'] ?? 'Not Available',
      ownerName: data['ownerName'] ?? 'Not Available',
      contractorName: data['contractorName'] ?? 'Not Available',
      siteId: data['siteId'] ?? 'Not Available',
      siteName: data['siteName'] ?? 'Not Available',
      siteLocation: data['siteLocation'] ?? 'Not Available',
      plannedStartDate: parseDate(data['plannedStartDate']),
      plannedEndDate: parseDate(data['plannedEndDate']),
      actualStartDate: parseDate(data['actualStartDate'] ?? 'Not Available'),
      actualEndDate: parseDate(data['actualEndDate'] ?? 'Not Available'),
      contractStartDate: parseDate(
        data['contractStartDate'] ?? 'Not Available',
      ),
      contractEndDate: parseDate(data['contractEndDate'] ?? 'Not Available'),
      projectBudget: parseNumber(data['projectBudget'] ?? 'Not Available'),
      contractorBudget: parseNumber(
        data['contractorBudget'] ?? 'Not Available',
      ),
      amountSpent: parseNumber(data['amountSpent'] ?? 'Not Available'),
      amountPaid: parseNumber(data['amountPaid'] ?? 'Not Available'),
      amountBalance: parseNumber(data['amountBalance'] ?? 'Not Available'),
      isContractWork: data['isContractWork'] ?? false,
      currentStatus: data['currentStatus'] ?? 'Not Available',
      status: data['status'] ?? 'Not Available',
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
    );
  }
}

class ProjectDetailsPage extends StatelessWidget {
  final String siteId;
  final String ownerName;
  final String ownerPhoneNumber;

  const ProjectDetailsPage({
    Key? key,
    required this.siteId,
    required this.ownerName,
    required this.ownerPhoneNumber,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Debug logging
    print('=== ProjectDetailsPage Debug ===');
    print('siteId: "$siteId"');
    print('ownerName: "$ownerName"');
    print('ownerPhoneNumber: "$ownerPhoneNumber"');
    print('================================');

    return GlassScaffold(
      title: 'Project Details',
      onBack: () => Navigator.pop(context),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('projects')
            .where('siteId', isEqualTo: siteId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFF64748B), size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading project',
                    style: TextStyle(fontSize: Responsive.fontSize(context, 18), color: const Color(0xFF1E293B)),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.find_in_page_rounded, color: Color(0xFF64748B), size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Project not found',
                    style: TextStyle(fontSize: Responsive.fontSize(context, 18), color: const Color(0xFF1E293B)),
                  ),
                ],
              ),
            );
          }

          final project = Project.fromFirestore(snapshot.data!.docs.first);

          return SingleChildScrollView(
            padding: EdgeInsets.all(Responsive.isMobile(context) ? 20.0 : 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusBanner(context, project.status),
                const SizedBox(height: 24),
                _buildSection(
                  context,
                  title: 'Project Overview',
                  icon: Icons.business_center_rounded,
                  children: [
                    _buildDetailRow(context, 'Project Name', project.projectName),
                    _buildDetailRow(context, 'Category', project.projectCategory),
                    _buildDetailRow(context, 'Sub Category', project.projectSubCategory),
                    _buildDetailRow(context, 'Type', project.projectType),
                    _buildDetailRow(context, 'Stage', project.projectStage),
                    _buildDetailRow(context, 'Contract Type', project.projectContract),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSection(
                  context,
                  title: 'Stakeholders',
                  icon: Icons.people_rounded,
                  children: [
                    _buildDetailRow(context, 'Owner', project.ownerName),
                    _buildDetailRow(context, 'Contractor', project.contractorName),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSection(
                  context,
                  title: 'Site Information',
                  icon: Icons.location_on_rounded,
                  children: [
                    _buildDetailRow(context, 'Site ID', project.siteId),
                    _buildDetailRow(context, 'Site Name', project.siteName),
                    _buildDetailRow(context, 'Location', project.siteLocation, isMultiLine: true),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSection(
                  context,
                  title: 'Timeline',
                  icon: Icons.calendar_today_rounded,
                  children: [
                    _buildDateRow(context, 'Planned Start', project.plannedStartDate),
                    _buildDateRow(context, 'Planned End', project.plannedEndDate),
                    _buildDateRow(context, 'Actual Start', project.actualStartDate),
                    _buildDateRow(context, 'Actual End', project.actualEndDate),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSection(
                  context,
                  title: 'Financials',
                  icon: Icons.payments_rounded,
                  children: [
                    _buildCurrencyRow(context, 'Budget', project.projectBudget),
                    _buildCurrencyRow(context, 'Spent', project.amountSpent),
                    _buildCurrencyRow(context, 'Paid', project.amountPaid),
                    _buildCurrencyRow(
                      context,
                      'Balance',
                      project.amountBalance,
                      color: project.amountBalance >= 0 ? Colors.greenAccent : Colors.redAccent,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBanner(BuildContext context, String status) {
    Color color;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'completed':
        color = Colors.greenAccent;
        icon = Icons.check_circle_rounded;
        break;
      case 'in progress':
      case 'in_progress':
        color = Colors.blueAccent;
        icon = Icons.sync_rounded;
        break;
      case 'pending':
        color = Colors.orangeAccent;
        icon = Icons.schedule_rounded;
        break;
      default:
        color = const Color(0xFF64748B);
        icon = Icons.help_outline_rounded;
    }

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Status: ${status.toUpperCase()}',
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 18),
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF64748B), size: 16),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 12),
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF64748B),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    bool isMultiLine = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: isMultiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 14),
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 15),
                color: const Color(0xFF1E293B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRow(BuildContext context, String label, DateTime date) {
    return _buildDetailRow(context, label, _formatDate(date));
  }

  Widget _buildCurrencyRow(BuildContext context, String label, double amount, {Color? color}) {
    return _buildDetailRow(context, label, '₹${_formatCurrency(amount)}');
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatCurrency(double amount) {
    if (amount >= 10000000) {
      return '${(amount / 10000000).toStringAsFixed(2)}Cr';
    } else if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(2)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(2)}K';
    }
    return amount.toStringAsFixed(2);
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Project Details',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const CustomerDashboardPage(ownerName: '', ownerPhoneNumber: '', siteId: ''),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Project list page to navigate to details
class ProjectListPage extends StatelessWidget {
  const ProjectListPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Projects',
      onBack: () => Navigator.pop(context),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService.getCollection('projects').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Color(0xFF1E293B))));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No projects found', style: TextStyle(color: Color(0xFF64748B))));
          }

          final projects = snapshot.data!.docs;

          return ListView.builder(
            padding: EdgeInsets.all(Responsive.isMobile(context) ? 20.0 : 32.0),
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final project = projects[index];
              final projectData = project.data() as Map<String, dynamic>;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.business_center_rounded,
                        color: Colors.blueAccent,
                      ),
                    ),
                    title: Text(
                      projectData['projectName'] ?? 'Unnamed Project',
                      style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      projectData['projectCategory'] ?? 'No Category',
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1)),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProjectDetailsPage(
                            siteId: projectData['siteId'] ?? '',
                            ownerName: projectData['ownerName'] ?? '',
                            ownerPhoneNumber: projectData['ownerPhoneNumber'] ?? '',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
