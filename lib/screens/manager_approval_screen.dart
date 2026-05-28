import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';

// Responsive padding helper (matches material approval)
EdgeInsets getSymmetricPadding(BuildContext context, {double fraction = 0.06}) {
  double width = MediaQuery.of(context).size.width;
  return EdgeInsets.symmetric(horizontal: width * fraction);
}

class ManagerApprovalScreen extends StatefulWidget {
  const ManagerApprovalScreen({super.key});

  @override
  State<ManagerApprovalScreen> createState() => _ManagerApprovalScreenState();
}

class _ManagerApprovalScreenState extends State<ManagerApprovalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> allRequests = [];
  List<Map<String, dynamic>> pendingRequests = [];
  List<Map<String, dynamic>> approvedRequests = [];
  String _searchText = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
  }

  void _fetchData() async {
    List<Map<String, dynamic>> fetchedData = await fetchAllSchedules();
    setState(() {
      allRequests = fetchedData;
      pendingRequests = allRequests
          .where((req) => req["approvalStatus"] == "Pending")
          .toList();
      approvedRequests = allRequests
          .where((req) => req["approvalStatus"] == "Approved")
          .toList();
    });
  }

  Future<List<Map<String, dynamic>>> fetchAllSchedules() async {
    final QuerySnapshot snapshot = await FirestoreService
        .siteSupervisorProjectStageSchedule
        .get();
    return snapshot.docs
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchAllLabours() async {
    final QuerySnapshot snapshot = await FirestoreService.getCollection(
      'labours',
    ).get();
    return snapshot.docs
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList();
  }

  void _showRequestDetails(Map<String, dynamic> request) async {
    final TextEditingController dateController = TextEditingController(
      text: request['reqDays']?.toString() ?? '',
    );
    final TextEditingController paymentController = TextEditingController(
      text: request['estimatedPayment']?.toString() ?? '',
    );
    final List<Map<String, dynamic>> labours = List<Map<String, dynamic>>.from(
      request['reqLabours'] ?? [],
    );

    final List<TextEditingController> labourCountControllers = labours
        .map(
          (labour) => TextEditingController(
            text: labour['labourCount']?.toString() ?? '',
          ),
        )
        .toList();
    final List<TextEditingController> labourDesignationControllers = labours
        .map(
          (labour) =>
              TextEditingController(text: labour['labourDesignation'] ?? ''),
        )
        .toList();

    final List<Map<String, dynamic>> allLabours = await fetchAllLabours();

    String? approvedDaysError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.4,
          maxChildSize: 0.98,
          builder: (context, scrollController) {
            int calculateLabourTotal() {
              int total = 0;
              for (int i = 0; i < labours.length; i++) {
                final designation = labourDesignationControllers[i].text;
                final matched = allLabours.firstWhere(
                  (l) => l['designation'] == designation,
                  orElse: () => {},
                );
                final salary =
                    int.tryParse(matched['salary']?.toString() ?? '0') ?? 0;
                final count = int.tryParse(labourCountControllers[i].text) ?? 0;
                total += count * salary;
              }
              return total;
            }

            int getApprovedDays() {
              return int.tryParse(dateController.text) ?? 0;
            }

            int getEstimatedDays() {
              return request['reqDays'] ?? 0;
            }

            void recalculate() {
              setState(() {});
            }

            return StatefulBuilder(
              builder: (context, setStateModal) {
                void validateApprovedDays(String value) {
                  final approvedDays = int.tryParse(value) ?? 0;
                  final estimatedDays = getEstimatedDays();
                  setStateModal(() {
                    if (approvedDays > estimatedDays) {
                      approvedDaysError =
                          "Approved Days ($approvedDays) cannot be greater than Estimated Days ($estimatedDays).";
                    } else {
                      approvedDaysError = null;
                    }
                  });
                  setState(() {}); // Sync main state if needed
                }

                return SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: getSymmetricPadding(
                      context,
                      fraction: 0.06,
                    ).copyWith(top: 32, bottom: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 50,
                            height: 5,
                            margin: const EdgeInsets.only(bottom: 18),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Req ID: ${request['wsReqId'] ?? ''}",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: request['approvalStatus'] == 'Approved'
                                    ? Colors.green[100]
                                    : Colors.orange[100],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                request['approvalStatus'] ?? '',
                                style: TextStyle(
                                  color: request['approvalStatus'] == 'Approved'
                                      ? Colors.green[800]
                                      : Colors.orange[800],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const Divider(),
                        const SizedBox(height: 10),
                        Text(
                          "Project Info",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _RowInfo(
                          label: "Project Name",
                          value: request['projectName'] ?? '',
                          icon: Icons.business,
                        ),
                        _RowInfo(
                          label: "Site ID",
                          value: request['siteId'] ?? '',
                          icon: Icons.location_on,
                        ),
                        _RowInfo(
                          label: "Supervisor",
                          value: request['supervisorName'] ?? '',
                          icon: Icons.person,
                        ),
                        _RowInfo(
                          label: "Project Stage",
                          value: request['projectStage'] ?? '',
                          icon: Icons.account_tree,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "Labour Requirements",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...List.generate(request['reqLabours']?.length ?? 0, (
                          index,
                        ) {
                          final labour = request['reqLabours'][index];
                          final designation = labour['labourDesignation'] ?? '';
                          final matched = allLabours.firstWhere(
                            (l) => l['designation'] == designation,
                            orElse: () => {},
                          );
                          final labourId =
                              matched['labourId']?.toString() ?? '';
                          final salary =
                              int.tryParse(
                                matched['salary']?.toString() ?? '0',
                              ) ??
                              0;
                          final count =
                              int.tryParse(
                                labour['labourCount']?.toString() ?? '0',
                              ) ??
                              0;
                          return _LabourRequirementCard(
                            designation: designation,
                            labourId: labourId,
                            salary: salary,
                            count: count,
                            total: count * salary,
                            color: Theme.of(context).colorScheme.primary,
                          );
                        }),
                        const SizedBox(height: 24),
                        Text(
                          "Edit Details",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text(
                              "Estimated Days: ",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(request['reqDays']?.toString() ?? '0'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text(
                              "Estimated Payment: ",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '₹${request['estimatedPayment'] ?? 0}',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: dateController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Approved Days',
                            errorText: approvedDaysError,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.05),
                          ),
                          onChanged: (val) {
                            setState(() {}); // Main UI
                            setStateModal(() {}); // Modal UI
                            validateApprovedDays(val);
                          },
                        ),
                        const SizedBox(height: 16),
                        ...List.generate(labours.length, (index) {
                          final designation =
                              labourDesignationControllers[index].text;
                          final matched = allLabours.firstWhere(
                            (l) => l['designation'] == designation,
                            orElse: () => {},
                          );
                          final salary =
                              int.tryParse(
                                matched['salary']?.toString() ?? '0',
                              ) ??
                              0;
                          final count =
                              int.tryParse(
                                labourCountControllers[index].text,
                              ) ??
                              0;
                          return _LabourRequirementCard(
                            designation: designation,
                            labourId: matched['labourId']?.toString() ?? '',
                            salary: salary,
                            count: count,
                            total: count * salary,
                            color: Theme.of(context).colorScheme.primary,
                            editable: true,
                            countController: labourCountControllers[index],
                            onChanged: () {
                              setState(() {});
                              setStateModal(() {});
                            },
                          );
                        }),
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Actual Payment:",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '₹${getApprovedDays() * calculateLabourTotal()}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (request['approvalStatus'] == "Pending")
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(Icons.check),
                                label: const Text("Approve"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[700],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                ),
                                onPressed: approvedDaysError != null
                                    ? null
                                    : () async {
                                        final wsReqId = request['wsReqId'];
                                        final approvedDays =
                                            int.tryParse(dateController.text) ??
                                            request['reqDays'];

                                        final docSnapshot = await FirestoreService
                                            .siteSupervisorProjectStageSchedule
                                            .where(
                                              'wsReqId',
                                              isEqualTo: wsReqId,
                                            )
                                            .limit(1)
                                            .get();

                                        if (docSnapshot.docs.isNotEmpty) {
                                          final docRef =
                                              docSnapshot.docs.first.reference;
                                          final approvedPayment =
                                              getApprovedDays() *
                                              calculateLabourTotal();
                                          final approvedLabours = List.generate(
                                            labours.length,
                                            (i) => {
                                              'labourCount':
                                                  int.tryParse(
                                                    labourCountControllers[i]
                                                        .text,
                                                  ) ??
                                                  0,
                                              'labourDesignation':
                                                  labourDesignationControllers[i]
                                                      .text,
                                            },
                                          );

                                          await docRef.update({
                                            'appDays': approvedDays,
                                            'appLabours': approvedLabours,
                                            'approvedPayment': approvedPayment,
                                            'approvalStatus': 'Approved',
                                          });

                                          // Update local state
                                          _fetchData();

                                          // Notify supervisor
                                          final supName =
                                              request['supervisorName']
                                                  ?.toString() ??
                                              '';
                                          if (supName.isNotEmpty) {
                                            await NotificationService.notifySupervisor(
                                              supervisorName: supName,
                                              title:
                                                  '✅ Worker Request Approved',
                                              body:
                                                  'Your request $wsReqId has been approved.',
                                              data: {
                                                'type': 'worker_approval',
                                                'wsReqId': wsReqId,
                                                'status': 'Approved',
                                              },
                                            );
                                          }
                                        }
                                        Navigator.pop(context);
                                      },
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.close),
                                label: const Text("Reject"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red[700],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                ),
                                onPressed: () async {
                                  final wsReqId = request['wsReqId'];
                                  final docSnapshot = await FirestoreService
                                      .siteSupervisorProjectStageSchedule
                                      .where('wsReqId', isEqualTo: wsReqId)
                                      .limit(1)
                                      .get();

                                  if (docSnapshot.docs.isNotEmpty) {
                                    await docSnapshot.docs.first.reference
                                        .update({'approvalStatus': 'Rejected'});
                                    _fetchData();

                                    final supName =
                                        request['supervisorName']?.toString() ??
                                        '';
                                    if (supName.isNotEmpty) {
                                      await NotificationService.notifySupervisor(
                                        supervisorName: supName,
                                        title: '❌ Worker Request Rejected',
                                        body:
                                            'Your request $wsReqId has been rejected.',
                                        data: {
                                          'type': 'worker_rejection',
                                          'wsReqId': wsReqId,
                                          'status': 'Rejected',
                                        },
                                      );
                                    }
                                  }
                                  Navigator.pop(context);
                                },
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showApprovedRequestDetails(Map<String, dynamic> request) async {
    List<Map<String, dynamic>> allLabours = await fetchAllLabours();
    List<Map<String, dynamic>> approvedLabours =
        List<Map<String, dynamic>>.from(request['appLabours'] ?? []);
    int approvedDays = request['appDays'] ?? request['reqDays'];
    int approvedPayment =
        request['approvedPayment'] ?? request['estimatedPayment'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.9,
          minChildSize: 0.4,
          maxChildSize: 0.98,
          builder: (context, scrollController) => SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: getSymmetricPadding(
                context,
                fraction: 0.06,
              ).copyWith(top: 32, bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      margin: EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Req ID: ${request['wsReqId'] ?? ''}",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "Approved",
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 18),
                  Divider(),
                  SizedBox(height: 10),
                  // Project Info
                  Text(
                    "Project Info",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  SizedBox(height: 3),
                  _RowInfo(
                    label: "Project Name",
                    value: request['projectName'] ?? '',
                    icon: Icons.business,
                  ),
                  _RowInfo(
                    label: "Site ID",
                    value: request['siteId'] ?? '',
                    icon: Icons.location_on,
                  ),
                  _RowInfo(
                    label: "Supervisor",
                    value: request['supervisorName'] ?? '',
                    icon: Icons.person,
                  ),
                  _RowInfo(
                    label: "Project Stage",
                    value: request['projectStage'] ?? '',
                    icon: Icons.account_tree,
                  ),
                  SizedBox(height: 14),
                  // Approved Labour Requirements
                  Text(
                    "Approved Labour Requirements",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  SizedBox(height: 5),
                  ...List.generate(approvedLabours.length, (index) {
                    final labour = approvedLabours[index];
                    final designation = labour['labourDesignation'] ?? '';
                    final matched = allLabours.firstWhere(
                      (l) => l['designation'] == designation,
                      orElse: () => {},
                    );
                    final labourId = matched['labourId']?.toString() ?? '';
                    final salary =
                        int.tryParse(matched['salary']?.toString() ?? '0') ?? 0;
                    final count =
                        int.tryParse(
                          labour['labourCount']?.toString() ?? '0',
                        ) ??
                        0;
                    final totalSalary = count * salary;
                    return _LabourRequirementCard(
                      designation: designation,
                      labourId: labourId,
                      salary: salary,
                      count: count,
                      total: totalSalary,
                      color: Theme.of(context).colorScheme.primary,
                      editable: false,
                    );
                  }),
                  SizedBox(height: 17),
                  // Approved Details
                  Text(
                    "Approved Details",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        "Days: ",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            approvedDays.toString(),
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.blueGrey[900],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        "Approved Amount: ",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '₹$approvedPayment',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.green[700],
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 22),
                  Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, color: Colors.green),
                          SizedBox(width: 8),
                          Text(
                            "Status: Approved",
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _updateRequestStatus(String wsReqId, String status) {
    setState(() {
      allRequests.firstWhere(
        (req) => req['wsReqId'] == wsReqId,
      )['approvalStatus'] = status;
      pendingRequests = allRequests
          .where((req) => req["approvalStatus"] == "Pending")
          .toList();
      approvedRequests = allRequests
          .where((req) => req["approvalStatus"] == "Approved")
          .toList();
    });
    Navigator.pop(context);
  }

  Widget _buildRequestList(
    List<Map<String, dynamic>> requests, {
    bool isApprovedTab = false,
  }) {
    List<Map<String, dynamic>> filteredRequests = List.from(requests);
    if (_searchText.isNotEmpty) {
      final idx = filteredRequests.indexWhere(
        (req) => (req['wsReqId'] ?? '').toString().toLowerCase().contains(
          _searchText.toLowerCase(),
        ),
      );
      if (idx != -1) {
        final match = filteredRequests.removeAt(idx);
        filteredRequests.insert(0, match);
      }
    }
    if (filteredRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 60, color: Colors.blueGrey[200]),
            SizedBox(height: 12),
            Text(
              "No requests found",
              style: TextStyle(
                color: Colors.blueGrey,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredRequests.length,
      itemBuilder: (context, index) {
        final request = filteredRequests[index];
        final status = request['approvalStatus'] ?? '';
        final isApproved = status == 'Approved';

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: GlassCard(
            title: 'Req ID: ${request['wsReqId'] ?? ""}',
            subtitle: 'Project: ${request['projectName'] ?? ""}',
            onTap: () => isApprovedTab
                ? _showApprovedRequestDetails(request)
                : _showRequestDetails(request),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: Theme.of(context).colorScheme.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      request['siteId'] ?? '',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isApproved
                            ? Colors.green.withOpacity(0.2)
                            : Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isApproved ? Colors.green : Colors.orange,
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: isApproved ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Supervisor',
                          style: TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                        Text(
                          request['supervisorName'] ?? '-',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Labours',
                          style: TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                        Text(
                          '${(request['reqLabours'] ?? []).length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GlassScaffold(
      title: 'Manager Approval',
      onBack: () => Navigator.pop(context),
      body: Column(
        children: [
          Container(
            color: theme.cardColor,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: "PENDING"),
                Tab(text: "APPROVED"),
              ],
              labelColor: colorScheme.primary,
              unselectedLabelColor: colorScheme.onSurfaceVariant,
              indicatorColor: colorScheme.primary,
              indicatorWeight: 3,
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (text) {
                setState(() {
                  _searchText = text.trim();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search Req ID...',
                prefixIcon: Icon(Icons.search, color: colorScheme.primary),
                suffixIcon: _searchText.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: colorScheme.primary),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchText = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                ),
                filled: true,
                fillColor: theme.cardColor,
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRequestList(pendingRequests),
                _buildRequestList(approvedRequests, isApprovedTab: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}

// --- Helper Widgets ---

class _RowInfo extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _RowInfo({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 18),
          const SizedBox(width: 10),
          Text(
            "$label: ",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _LabourRequirementCard extends StatelessWidget {
  final String designation;
  final String labourId;
  final int salary;
  final int count;
  final int total;
  final Color color;
  final bool editable;
  final TextEditingController? countController;
  final TextEditingController? designationController;
  final VoidCallback? onChanged;

  const _LabourRequirementCard({
    required this.designation,
    required this.labourId,
    required this.salary,
    required this.count,
    required this.total,
    required this.color,
    this.editable = false,
    this.countController,
    this.designationController,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.people_outline, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: editable
                  ? Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: designationController,
                                decoration: const InputDecoration(
                                  labelText: 'Designation',
                                  isDense: true,
                                ),
                                style: const TextStyle(fontSize: 14),
                                onChanged: (v) => onChanged?.call(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: countController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Count',
                                  isDense: true,
                                ),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                onChanged: (v) => onChanged?.call(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'ID: $labourId',
                              style: theme.textTheme.bodySmall,
                            ),
                            Text(
                              'Total: ₹$total',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              designation,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'x$count',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('ID: $labourId', style: theme.textTheme.bodySmall),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Salary: ₹$salary',
                              style: theme.textTheme.bodySmall,
                            ),
                            Text(
                              'Total: ₹$total',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: color,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
