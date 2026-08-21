import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/services/notification_service.dart';
import 'package:demo_cst/utils/app_theme.dart';

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

  Color get primaryColor => Theme.of(context).colorScheme.primary;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
  }

  void _fetchData() async {
    List<Map<String, dynamic>> fetchedData = await fetchAllSchedules();
    if (!mounted) return;
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
    try {
      final QuerySnapshot snapshot = await FirestoreService
          .siteSupervisorProjectStageSchedule
          .get();
      return snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      debugPrint('Error fetching schedules: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchAllLabours() async {
    try {
      final QuerySnapshot snapshot = await FirestoreService.getCollection(
        'labours',
      ).get();
      return snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      debugPrint('Error fetching labours: $e');
      return [];
    }
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

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxModalWidth),
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.85,
              minChildSize: 0.4,
              maxChildSize: 0.95,
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

                return StatefulBuilder(
                  builder: (context, setStateModal) {
                    return SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Request Details (${request['wsReqId'] ?? ''})",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  color: Color(0xFF0A183D),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _RowInfo(
                            label: "Site ID",
                            value: request['siteId'] ?? '',
                            icon: Icons.place_rounded,
                          ),
                          _RowInfo(
                            label: "Project Name",
                            value: request['projectName'] ?? '',
                            icon: Icons.assignment_rounded,
                          ),
                          _RowInfo(
                            label: "Supervisor",
                            value: request['supervisorName'] ?? '',
                            icon: Icons.person_rounded,
                          ),
                          _RowInfo(
                            label: "Project Stage",
                            value: request['projectStage'] ?? '',
                            icon: Icons.timeline_rounded,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Labour Requirements",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...List.generate(labours.length, (index) {
                            final designation =
                                labourDesignationControllers[index].text;
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
                                  labourCountControllers[index].text,
                                ) ??
                                0;
                            final totalSalary = count * salary;
                            return _LabourRequirementCard(
                              designation: designation,
                              labourId: labourId,
                              salary: salary,
                              count: count,
                              total: totalSalary,
                              color: primaryColor,
                              onCountChanged: (val) {
                                labourCountControllers[index].text = val;
                                setStateModal(() {});
                              },
                              editable: true,
                            );
                          }),
                          const SizedBox(height: 16),
                          Text(
                            "Days & Estimates",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text(
                                "Estimated Days: ",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF64748B),
                                  fontSize: 13.5,
                                ),
                              ),
                              Text(
                                '${getEstimatedDays()}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0A183D),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Text(
                                "Approved Days: ",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0A183D),
                                  fontSize: 13.5,
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 100,
                                height: 44,
                                child: TextField(
                                  controller: dateController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF0A183D),
                                    fontWeight: FontWeight.bold,
                                  ),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: primaryColor, width: 1.8),
                                    ),
                                  ),
                                  onChanged: (val) {
                                    final enteredDays = int.tryParse(val) ?? 0;
                                    final estDays = getEstimatedDays();
                                    if (enteredDays > estDays) {
                                      setStateModal(() {
                                        approvedDaysError =
                                            "Approved days cannot exceed $estDays";
                                      });
                                    } else if (enteredDays <= 0) {
                                      setStateModal(() {
                                        approvedDaysError =
                                            "Approved days must be > 0";
                                      });
                                    } else {
                                      setStateModal(() {
                                        approvedDaysError = null;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          if (approvedDaysError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                approvedDaysError!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Approved Total Payment:",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0A183D),
                                    fontSize: 13.5,
                                  ),
                                ),
                                Text(
                                  '₹${getApprovedDays() * calculateLabourTotal()}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (request['approvalStatus'] == "Pending")
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: SizedBox(
                                    height: 48,
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.check_circle_rounded, size: 20),
                                      label: const Text(
                                        "Approve Request",
                                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF10B981),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      onPressed: approvedDaysError != null
                                          ? null
                                          : () async {
                                              final nav = Navigator.of(context);
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

                                                _fetchData();

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
                                              nav.pop();
                                            },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: SizedBox(
                                    height: 48,
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.cancel_rounded, size: 18),
                                      label: const Text(
                                        "Reject",
                                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: const Color(0xFFEF4444),
                                        side: const BorderSide(color: Color(0xFFEF4444)),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      onPressed: () async {
                                        final nav = Navigator.of(context);
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
                                        nav.pop();
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
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
    int approvedDays = request['appDays'] ?? request['reqDays'] ?? 0;
    int approvedPayment =
        request['approvedPayment'] ?? request['estimatedPayment'] ?? 0;
    final maxModalWidth = 700.0;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxModalWidth),
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.85,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Approved Request (${request['wsReqId'] ?? ''})",
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: Color(0xFF0A183D),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _RowInfo(
                        label: "Site ID",
                        value: request['siteId'] ?? '',
                        icon: Icons.place_rounded,
                      ),
                      _RowInfo(
                        label: "Project Name",
                        value: request['projectName'] ?? '',
                        icon: Icons.assignment_rounded,
                      ),
                      _RowInfo(
                        label: "Supervisor",
                        value: request['supervisorName'] ?? '',
                        icon: Icons.person_rounded,
                      ),
                      _RowInfo(
                        label: "Project Stage",
                        value: request['projectStage'] ?? '',
                        icon: Icons.timeline_rounded,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Approved Labour Requirements",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
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
                          color: primaryColor,
                          editable: false,
                        );
                      }),
                      const SizedBox(height: 16),
                      Text(
                        "Approved Details",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text(
                            "Days: ",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                              fontSize: 13.5,
                            ),
                          ),
                          Text(
                            approvedDays.toString(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0A183D),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text(
                            "Approved Amount: ",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                              fontSize: 13.5,
                            ),
                          ),
                          Text(
                            '₹$approvedPayment',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.verified_rounded,
                                color: Color(0xFF10B981),
                                size: 22,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "Status: Approved",
                                style: TextStyle(
                                  color: Color(0xFF10B981),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
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
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(
                Icons.event_available_rounded,
                size: 64,
                color: Color(0xFFCBD5E1),
              ),
              SizedBox(height: 16),
              Text(
                'No Requests Found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A183D),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'No schedule requests available under this section.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: filteredRequests.length,
      itemBuilder: (context, index) {
        final request = filteredRequests[index];
        final isPending = request['approvalStatus'] == 'Pending';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => isApprovedTab
                ? _showApprovedRequestDetails(
                    request,
                    isDesktop,
                    isTablet,
                    isMobile,
                  )
                : _showRequestDetails(
                    request,
                    isDesktop,
                    isTablet,
                    isMobile,
                  ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.event_note_rounded,
                              color: primaryColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            request['wsReqId'] ?? 'N/A',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0A183D),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPending
                              ? Colors.amber.withValues(alpha: 0.15)
                              : const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isPending ? 'Pending' : 'Approved',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: isPending ? Colors.amber.shade900 : const Color(0xFF10B981),
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
                            'Site ID',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                          Text(
                            request['siteId'] ?? '-',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0A183D),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Supervisor',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                          Text(
                            request['supervisorName'] ?? '-',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0A183D),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Labours',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                          Text(
                            '${(request['reqLabours'] ?? []).length}',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Schedule Request Approval',
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
            onPressed: _fetchData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 850.0 : (isTablet ? 680.0 : double.infinity),
            ),
            child: Column(
              children: [
                // TabBar Header Container
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: "PENDING"),
                      Tab(text: "APPROVED"),
                    ],
                    labelColor: primaryColor,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    unselectedLabelColor: const Color(0xFF64748B),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    indicatorColor: primaryColor,
                    indicatorWeight: 3,
                  ),
                ),

                // Search Box
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (text) {
                      setState(() {
                        _searchText = text.trim();
                      });
                    },
                    style: const TextStyle(
                      color: Color(0xFF0A183D),
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search Request ID...',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12.5,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: primaryColor,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                    ),
                  ),
                ),

                // TabBarView Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRequestList(
                        pendingRequests,
                        isApprovedTab: false,
                        isDesktop: isDesktop,
                        isTablet: isTablet,
                        isMobile: isMobile,
                      ),
                      _buildRequestList(
                        approvedRequests,
                        isApprovedTab: true,
                        isDesktop: isDesktop,
                        isTablet: isTablet,
                        isMobile: isMobile,
                      ),
                    ],
                  ),
                ),
              ],
            ),
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

  const _RowInfo({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: primaryColor),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Color(0xFF64748B),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0A183D),
              ),
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
  final ValueChanged<String>? onCountChanged;
  final bool editable;

  const _LabourRequirementCard({
    required this.designation,
    required this.labourId,
    required this.salary,
    required this.count,
    required this.total,
    required this.color,
    this.onCountChanged,
    this.editable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.badge_rounded, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  designation,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0A183D),
                    fontSize: 13.5,
                  ),
                ),
                Text(
                  'Daily Salary: ₹$salary',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          if (editable)
            SizedBox(
              width: 70,
              height: 38,
              child: TextFormField(
                initialValue: count.toString(),
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A183D),
                ),
                decoration: InputDecoration(
                  labelText: 'Count',
                  labelStyle: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: onCountChanged,
              ),
            )
          else
            Text(
              'Count: $count',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Color(0xFF0A183D),
              ),
            ),
          const SizedBox(width: 12),
          Text(
            '₹$total',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
