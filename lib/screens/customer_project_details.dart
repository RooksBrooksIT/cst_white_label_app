import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('projects')
              .where('siteId', isEqualTo: siteId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
              final project = Project.fromFirestore(snapshot.data!.docs.first);
              return Text(
                project.projectName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  
                ),
              );
            }
            return const Text(
              'Project Details',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                
              ),
            );
          },
        ),
        backgroundColor: Color(0xFF003768),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20.0),
            bottomRight: Radius.circular(20.0),
          ),
        ),
      ),
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
            print('Error: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, color: Colors.red[300], size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading project',
                    style: TextStyle(fontSize: 18, ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, ),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            print('Project document not found for siteId: $siteId');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.find_in_page,
                    color: Color.fromARGB(255, 7, 108, 196),
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Project not found',
                    style: TextStyle(fontSize: 18, ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'siteId: $siteId',
                    style: TextStyle(fontSize: 12, ),
                  ),
                ],
              ),
            );
          }

          // Get the first document from the query
          final project = Project.fromFirestore(snapshot.data!.docs.first);

          return Container(
            
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Project Status Banner
                  _buildStatusBanner(project.status),

                  const SizedBox(height: 16),

                  // Project Overview Card
                  _buildSectionCard(
                    title: 'Project Overview',
                    icon: Icons.business_center,
                    children: [
                      _buildDetailRow('Project Name', project.projectName),
                      _buildDetailRow('Category', project.projectCategory),
                      _buildDetailRow(
                        'Sub Category',
                        project.projectSubCategory,
                      ),
                      _buildDetailRow('Type', project.projectType),
                      _buildDetailRow('Stage', project.projectStage),
                      _buildDetailRow('Contract Type', project.projectContract),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Stakeholders Card
                  _buildSectionCard(
                    title: 'Stakeholders',
                    icon: Icons.people,
                    children: [
                      _buildDetailRow('Owner', project.ownerName),
                      _buildDetailRow('Contractor', project.contractorName),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Site Information Card
                  _buildSectionCard(
                    title: 'Site Information',
                    icon: Icons.location_on,
                    children: [
                      _buildDetailRow('Site ID', project.siteId),
                      _buildDetailRow('Site Name', project.siteName),
                      _buildDetailRow(
                        'Location',
                        project.siteLocation,
                        isMultiLine: true,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Dates Card
                  _buildSectionCard(
                    title: 'Project Timeline',
                    icon: Icons.calendar_today,
                    children: [
                      _buildDateRow('Planned Start', project.plannedStartDate),
                      _buildDateRow('Planned End', project.plannedEndDate),
                      _buildDateRow('Actual Start', project.actualStartDate),
                      _buildDateRow('Actual End', project.actualEndDate),
                      _buildDateRow(
                        'Contract Start',
                        project.contractStartDate,
                      ),
                      _buildDateRow('Contract End', project.contractEndDate),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Budget & Finance Card
                  _buildSectionCard(
                    title: 'Budget & Finance',
                    icon: Icons.attach_money,
                    children: [
                      _buildCurrencyRow(
                        'Project Budget',
                        project.projectBudget,
                      ),
                      _buildCurrencyRow(
                        'Contractor Budget',
                        project.contractorBudget,
                      ),
                      _buildCurrencyRow('Amount Spent', project.amountSpent),
                      _buildCurrencyRow('Amount Paid', project.amountPaid),
                      _buildCurrencyRow(
                        'Balance',
                        project.amountBalance,
                        color: project.amountBalance >= 0
                            ? Colors.green
                            : Colors.red,
                      ),
                      _buildDetailRow(
                        'Contract Work',
                        project.isContractWork ? 'Yes' : 'No',
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Metadata Card
                  _buildSectionCard(
                    title: 'Project Metadata',
                    icon: Icons.info,
                    children: [
                      _buildDateRow('Created', project.createdAt),
                      _buildDateRow('Last Updated', project.updatedAt),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBanner(String status) {
    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'completed':
        backgroundColor = Colors.green;
        textColor = Colors.white;
        icon = Icons.check_circle;
        break;
      case 'in progress':
      case 'in_progress':
        backgroundColor = Color(0xFF003768);
        textColor = Colors.white;
        icon = Icons.refresh;
        break;
      case 'pending':
        backgroundColor = Colors.orange;
        textColor = Colors.white;
        icon = Icons.schedule;
        break;
      default:
        backgroundColor = Colors.grey;
        textColor = Colors.white;
        icon = Icons.help;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Status: ${status.toUpperCase()}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Color.fromARGB(255, 2, 81, 150), size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(255, 2, 81, 150),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isMultiLine = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: isMultiLine
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRow(String label, DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(date),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    
                  ),
                ),
                Text(
                  _formatTime(date),
                  style: TextStyle(fontSize: 13, ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyRow(String label, double amount, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '₹${_formatCurrency(amount)}',
            style: TextStyle(
              fontSize: 15,
              color: color ?? Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
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
      home: const ProjectListPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Project list page to navigate to details
class ProjectListPage extends StatelessWidget {
  const ProjectListPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects'),
        backgroundColor: Color(0xFF003768),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService.getCollection('projects').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No projects found'));
          }

          final projects = snapshot.data!.docs;

          return ListView.builder(
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final project = projects[index];
              final projectData = project.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(
                    Icons.business_center,
                    color: Color(0xFF003768),
                  ),
                  title: Text(projectData['projectName'] ?? 'Unnamed Project'),
                  subtitle: Text(
                    projectData['projectCategory'] ?? 'No Category',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProjectDetailsPage(
                          siteId: projectData['siteId'] ?? '',
                          ownerName: projectData['ownerName'] ?? '',
                          ownerPhoneNumber:
                              projectData['ownerPhoneNumber'] ?? '',
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
