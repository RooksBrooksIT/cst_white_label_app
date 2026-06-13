import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';

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

  void _showRequestDetails(
    Map<String, dynamic> request,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) async {
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
    final maxModalWidth = 700.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxModalWidth),
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
                    final count =
                        int.tryParse(labourCountControllers[i].text) ?? 0;
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
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop
                              ? 32
                              : (isTablet
                                    ? 24
                                    : MediaQuery.of(context).size.width * 0.06),
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
                                    fontSize: isDesktop ? 24 : 22,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isDesktop ? 18 : 14,
                                    vertical: isDesktop ? 10 : 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        request['approvalStatus'] == 'Approved'
                                        ? Colors.green[100]
                                        : Colors.orange[100],
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    request['approvalStatus'] ?? '',
                                    style: TextStyle(
                                      color:
                                          request['approvalStatus'] ==
                                              'Approved'
                                          ? Colors.green[800]
                                          : Colors.orange[800],
                                      fontWeight: FontWeight.bold,
                                      fontSize: isDesktop ? 17 : 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 18),
                            Divider(),
                            SizedBox(height: 10),
                            Text(
                              "Project Info",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: isDesktop ? 19 : 17,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            SizedBox(height: 12),
                            _RowInfo(
                              label: "Project Name",
                              value: request['projectName'] ?? '',
                              icon: Icons.business,
                              isDesktop: isDesktop,
                              isTablet: isTablet,
                              isMobile: isMobile,
                            ),
                            _RowInfo(
                              label: "Site ID",
                              value: request['siteId'] ?? '',
                              icon: Icons.location_on,
                              isDesktop: isDesktop,
                              isTablet: isTablet,
                              isMobile: isMobile,
                            ),
                            _RowInfo(
                              label: "Supervisor",
                              value: request['supervisorName'] ?? '',
                              icon: Icons.person,
                              isDesktop: isDesktop,
                              isTablet: isTablet,
                              isMobile: isMobile,
                            ),
                            _RowInfo(
                              label: "Project Stage",
                              value: request['projectStage'] ?? '',
                              icon: Icons.account_tree,
                              isDesktop: isDesktop,
                              isTablet: isTablet,
                              isMobile: isMobile,
                            ),
                            SizedBox(height: 24),
                            Text(
                              "Labour Requirements",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: isDesktop ? 19 : 17,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            SizedBox(height: 12),
                            ...List.generate(
                              request['reqLabours']?.length ?? 0,
                              (index) {
                                final labour = request['reqLabours'][index];
                                final designation =
                                    labour['labourDesignation'] ?? '';
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
                                  isDesktop: isDesktop,
                                  isTablet: isTablet,
                                  isMobile: isMobile,
                                );
                              },
                            ),
                            SizedBox(height: 24),
                            Text(
                              "Edit Details",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: isDesktop ? 19 : 17,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Text(
                                  "Estimated Days: ",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: isDesktop ? 16 : 14,
                                  ),
                                ),
                                Text(
                                  request['reqDays']?.toString() ?? '0',
                                  style: TextStyle(
                                    fontSize: isDesktop ? 16 : 14,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  "Estimated Payment: ",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: isDesktop ? 16 : 14,
                                  ),
                                ),
                                Text(
                                  '₹${request['estimatedPayment'] ?? 0}',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: isDesktop ? 18 : 16,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            TextFormField(
                              controller: dateController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Approved Days',
                                labelStyle: TextStyle(
                                  fontSize: isDesktop ? 16 : 14,
                                ),
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
                            SizedBox(height: 16),
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
                                isDesktop: isDesktop,
                                isTablet: isTablet,
                                isMobile: isMobile,
                              );
                            }),
                            SizedBox(height: 24),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(isDesktop ? 20 : 16),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.green.shade200,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Actual Payment:",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: isDesktop ? 18 : 16,
                                    ),
                                  ),
                                  Text(
                                    '₹${getApprovedDays() * calculateLabourTotal()}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: isDesktop ? 20 : 18,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 24),
                            if (request['approvalStatus'] == "Pending")
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton.icon(
                                    icon: Icon(
                                      Icons.check,
                                      size: isDesktop ? 24 : 20,
                                    ),
                                    label: Text(
                                      "Approve",
                                      style: TextStyle(
                                        fontSize: isDesktop ? 16 : 14,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green[700],
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isDesktop ? 24 : 20,
                                        vertical: isDesktop ? 16 : 12,
                                      ),
                                    ),
                                    onPressed: approvedDaysError != null
                                        ? null
                                        : () async {
                                            final wsReqId = request['wsReqId'];
                                            final approvedDays =
                                                int.tryParse(
                                                  dateController.text,
                                                ) ??
                                                request['reqDays'];

                                            final docSnapshot =
                                                await FirestoreService
                                                    .siteSupervisorProjectStageSchedule
                                                    .where(
                                                      'wsReqId',
                                                      isEqualTo: wsReqId,
                                                    )
                                                    .limit(1)
                                                    .get();

                                            if (docSnapshot.docs.isNotEmpty) {
                                              final docRef = docSnapshot
                                                  .docs
                                                  .first
                                                  .reference;
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
                                                'approvedPayment':
                                                    approvedPayment,
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
                                                  body: 'Your request $wsReqId has been approved.',
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
                                  SizedBox(width: isDesktop ? 16 : 12),
                                  ElevatedButton.icon(
                                    icon: Icon(
                                      Icons.close,
                                      size: isDesktop ? 24 : 20,
                                    ),
                                    label: Text(
                                      "Reject",
                                      style: TextStyle(
                                        fontSize: isDesktop ? 16 : 14,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red[700],
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isDesktop ? 24 : 20,
                                        vertical: isDesktop ? 16 : 12,
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
                                            .update({
                                              'approvalStatus': 'Rejected',
                                            });
                                        _fetchData();

                                        final supName =
                                            request['supervisorName']
                                                ?.toString() ??
                                            '';
                                        if (supName.isNotEmpty) {
                                          await NotificationService.notifySupervisor(
                                            supervisorName: supName,
                                            title: '❌ Worker Request Rejected',
                                            body: 'Your request $wsReqId has been rejected.',
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
        ),
      ),
    );
  }

  void _showApprovedRequestDetails(
    Map<String, dynamic> request,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) async {
    List<Map<String, dynamic>> allLabours = await fetchAllLabours();
    List<Map<String, dynamic>> approvedLabours =
        List<Map<String, dynamic>>.from(request['appLabours'] ?? []);
    int approvedDays = request['appDays'] ?? request['reqDays'];
    int approvedPayment =
        request['approvedPayment'] ?? request['estimatedPayment'];
    final maxModalWidth = 700.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxModalWidth),
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.9,
              minChildSize: 0.4,
              maxChildSize: 0.98,
              builder: (context, scrollController) => SingleChildScrollView(
                controller: scrollController,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop
                        ? 32
                        : (isTablet
                              ? 24
                              : MediaQuery.of(context).size.width * 0.06),
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
                              fontSize: isDesktop ? 24 : 22,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isDesktop ? 18 : 14,
                              vertical: isDesktop ? 10 : 7,
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
                                fontSize: isDesktop ? 17 : 15,
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
                          fontSize: isDesktop ? 19 : 17,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      SizedBox(height: 3),
                      _RowInfo(
                        label: "Project Name",
                        value: request['projectName'] ?? '',
                        icon: Icons.business,
                        isDesktop: isDesktop,
                        isTablet: isTablet,
                        isMobile: isMobile,
                      ),
                      _RowInfo(
                        label: "Site ID",
                        value: request['siteId'] ?? '',
                        icon: Icons.location_on,
                        isDesktop: isDesktop,
                        isTablet: isTablet,
                        isMobile: isMobile,
                      ),
                      _RowInfo(
                        label: "Supervisor",
                        value: request['supervisorName'] ?? '',
                        icon: Icons.person,
                        isDesktop: isDesktop,
                        isTablet: isTablet,
                        isMobile: isMobile,
                      ),
                      _RowInfo(
                        label: "Project Stage",
                        value: request['projectStage'] ?? '',
                        icon: Icons.account_tree,
                        isDesktop: isDesktop,
                        isTablet: isTablet,
                        isMobile: isMobile,
                      ),
                      SizedBox(height: 14),
                      // Approved Labour Requirements
                      Text(
                        "Approved Labour Requirements",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isDesktop ? 19 : 17,
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
                            int.tryParse(
                              matched['salary']?.toString() ?? '0',
                            ) ??
                            0;
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
                          isDesktop: isDesktop,
                          isTablet: isTablet,
                          isMobile: isMobile,
                        );
                      }),
                      SizedBox(height: 17),
                      // Approved Details
                      Text(
                        "Approved Details",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isDesktop ? 19 : 17,
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
                              fontSize: isDesktop ? 16 : 14,
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                approvedDays.toString(),
                                style: TextStyle(
                                  fontSize: isDesktop ? 18 : 16,
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
                              fontSize: isDesktop ? 16 : 14,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '₹$approvedPayment',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: isDesktop ? 20 : 18,
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
                            horizontal: isDesktop ? 22 : 18,
                            vertical: isDesktop ? 12 : 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified,
                                color: Colors.green,
                                size: isDesktop ? 28 : 24,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "Status: Approved",
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: isDesktop ? 18 : 16,
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
    required bool isDesktop,
    required bool isTablet,
    required bool isMobile,
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
            Icon(
              Icons.inbox,
              size: isDesktop ? 80 : 60,
              color: Colors.blueGrey[200],
            ),
            SizedBox(height: 12),
            Text(
              "No requests found",
              style: TextStyle(
                color: Colors.blueGrey,
                fontSize: isDesktop ? 20 : 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      itemCount: filteredRequests.length,
      itemBuilder: (context, index) {
        final request = filteredRequests[index];
        final status = request['approvalStatus'] ?? '';
        final isApproved = status == 'Approved';

        return Padding(
          padding: EdgeInsets.only(bottom: isDesktop ? 20 : 16),
          child: GlassCard(
            title: 'Req ID: ${request['wsReqId'] ?? ""}',
            subtitle: 'Project: ${request['projectName'] ?? ""}',
            onTap: () => isApprovedTab
                ? _showApprovedRequestDetails(
                    request,
                    isDesktop,
                    isTablet,
                    isMobile,
                  )
                : _showRequestDetails(request, isDesktop, isTablet, isMobile),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: Theme.of(context).colorScheme.primary,
                      size: isDesktop ? 20 : 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      request['siteId'] ?? '',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: isDesktop ? 15 : 13,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 14 : 10,
                        vertical: isDesktop ? 6 : 4,
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
                          fontSize: isDesktop ? 13 : 11,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Supervisor',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: isDesktop ? 13 : 11,
                          ),
                        ),
                        Text(
                          request['supervisorName'] ?? '-',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: isDesktop ? 16 : 14,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Labours',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: isDesktop ? 13 : 11,
                          ),
                        ),
                        Text(
                          '${(request['reqLabours'] ?? []).length}',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: isDesktop ? 16 : 14,
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;
    final maxContentWidth = 900.0;

    return GlassScaffold(
      title: 'Manager Approval',
      onBack: () => Navigator.pop(context),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
          child: Column(
        children: [
          Container(
            color: theme.cardColor,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: "PENDING"),
                    Tab(text: "APPROVED"),
                  ],
                  labelColor: colorScheme.primary,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isDesktop ? 16 : 14,
                  ),
                  unselectedLabelColor: Colors.black54,
                  indicatorColor: colorScheme.primary,
                  indicatorWeight: 3,
                ),
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.all(isDesktop ? 24 : 16.0),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: TextField(
                  controller: _searchController,
                  onChanged: (text) {
                    setState(() {
                      _searchText = text.trim();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search Req ID...',
                    prefixIcon: Icon(
                      Icons.search,
                      color: colorScheme.primary,
                      size: isDesktop ? 24 : 20,
                    ),
                    suffixIcon: _searchText.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: colorScheme.primary,
                              size: isDesktop ? 24 : 20,
                            ),
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
                    ),
                    filled: true,
                    fillColor: theme.cardColor,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxContentWidth),
                    child: _buildRequestList(
                      pendingRequests,
                      isDesktop: isDesktop,
                      isTablet: isTablet,
                      isMobile: isMobile,
                    ),
                  ),
                ),
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxContentWidth),
                    child: _buildRequestList(
                      approvedRequests,
                      isApprovedTab: true,
                      isDesktop: isDesktop,
                      isTablet: isTablet,
                      isMobile: isMobile,
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
    );
  }
}

class _RowInfo extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isDesktop;
  final bool isTablet;
  final bool isMobile;

  const _RowInfo({
    required this.label,
    required this.value,
    required this.icon,
    required this.isDesktop,
    required this.isTablet,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isDesktop ? 10 : 6),
      child: Row(
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: isDesktop ? 24 : 20,
          ),
          SizedBox(width: isDesktop ? 16 : 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: isDesktop ? 14 : 12,
                ),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: isDesktop ? 16 : 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
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
  final VoidCallback? onChanged;
  final bool isDesktop;
  final bool isTablet;
  final bool isMobile;

  const _LabourRequirementCard({
    required this.designation,
    required this.labourId,
    required this.salary,
    required this.count,
    required this.total,
    required this.color,
    this.editable = false,
    this.countController,
    this.onChanged,
    required this.isDesktop,
    required this.isTablet,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isDesktop ? 16 : 12),
      child: Container(
        padding: EdgeInsets.all(isDesktop ? 18 : 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              designation,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: isDesktop ? 18 : 16,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'ID: $labourId',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.black54,
                fontSize: isDesktop ? 14 : 12,
              ),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Salary: ₹$salary',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                    fontSize: isDesktop ? 14 : 12,
                  ),
                ),
                if (editable)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 24 : 16,
                      ),
                      child: TextFormField(
                        controller: countController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Count',
                          contentPadding: EdgeInsets.symmetric(
                            vertical: isDesktop ? 14 : 10,
                            horizontal: isDesktop ? 16 : 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onChanged: (_) => onChanged?.call(),
                      ),
                    ),
                  ),
                Text(
                  'Total: ₹$total',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: isDesktop ? 18 : 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
