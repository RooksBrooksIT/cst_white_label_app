import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    final QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('siteSupervisorProjectStageSchedule')
        .get();
    return snapshot.docs
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchAllLabours() async {
    final QuerySnapshot snapshot =
        await FirebaseFirestore.instance.collection('labours').get();
    return snapshot.docs
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList();
  }

  void _showRequestDetails(Map<String, dynamic> request) async {
    TextEditingController dateController =
        TextEditingController(text: request['reqDays'].toString());
    TextEditingController paymentController =
        TextEditingController(text: request['estimatedPayment'].toString());
    List<Map<String, dynamic>> labours =
        List<Map<String, dynamic>>.from(request['reqLabours'] ?? []);
    List<TextEditingController> labourCountControllers = labours
        .map((labour) => TextEditingController(
            text: labour['labourCount']?.toString() ?? ''))
        .toList();
    List<TextEditingController> labourDesignationControllers = labours
        .map((labour) =>
            TextEditingController(text: labour['labourDesignation'] ?? ''))
        .toList();

    List<Map<String, dynamic>> allLabours = await fetchAllLabours();

    String? approvedDaysError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
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

            void validateApprovedDays(String value) {
              final approvedDays = int.tryParse(value) ?? 0;
              final estimatedDays = getEstimatedDays();
              if (approvedDays > estimatedDays) {
                setState(() {
                  approvedDaysError =
                      "Approved Days ($approvedDays) cannot be greater than Estimated Days ($estimatedDays).";
                });
              } else {
                setState(() {
                  approvedDaysError = null;
                });
              }
            }

            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: getSymmetricPadding(context, fraction: 0.06)
                    .copyWith(top: 32, bottom: 32),
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
                            color: Color(0xFF003768),
                          ),
                        ),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: request['approvalStatus'] == 'Approved'
                                ? Colors.green[100]
                                : Colors.orange,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            request['approvalStatus'] ?? '',
                            style: TextStyle(
                              color: request['approvalStatus'] == 'Approved'
                                  ? Colors.green[800]
                                  : Colors.orange,
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
                    Text("Project Info",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: Color(0xFF003768))),
                    SizedBox(height: 3),
                    _RowInfo(
                        label: "Project Name",
                        value: request['projectName'] ?? '',
                        icon: Icons.business),
                    _RowInfo(
                        label: "Site ID",
                        value: request['siteId'] ?? '',
                        icon: Icons.location_on),
                    _RowInfo(
                        label: "Supervisor",
                        value: request['supervisorName'] ?? '',
                        icon: Icons.person),
                    _RowInfo(
                        label: "Project Stage",
                        value: request['projectStage'] ?? '',
                        icon: Icons.account_tree),
                    SizedBox(height: 14),
                    // Labour Requirements
                    Text("Labour Requirements",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: Color(0xFF003768))),
                    SizedBox(height: 5),
                    ...List.generate(request['reqLabours']?.length ?? 0,
                        (index) {
                      final labour = request['reqLabours'][index];
                      final designation = labour['labourDesignation'] ?? '';
                      final matched = allLabours.firstWhere(
                        (l) => l['designation'] == designation,
                        orElse: () => {},
                      );
                      final labourId = matched['labourId']?.toString() ?? '';
                      final salary =
                          int.tryParse(matched['salary']?.toString() ?? '0') ??
                              0;
                      final count = int.tryParse(
                              labour['labourCount']?.toString() ?? '0') ??
                          0;
                      final totalSalary = count * salary;
                      return _LabourRequirementCard(
                        designation: designation,
                        labourId: labourId,
                        salary: salary,
                        count: count,
                        total: totalSalary,
                        color: Color(0xFF003768),
                      );
                    }),
                    SizedBox(height: 17),
                    // Days
                    Text("Edit Details",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: Color(0xFF003768))),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Text("Days: ",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey)),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              request['reqDays'].toString(),
                              style: TextStyle(
                                  fontSize: 16, color: Colors.blueGrey[900]),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text("Requested Amount: ",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey)),
                        Expanded(
                          child: TextFormField(
                            controller: paymentController,
                            keyboardType: TextInputType.number,
                            readOnly: true,
                            style: TextStyle(
                                color: Colors.green[800],
                                fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    // Editable Days field
                    Row(
                      children: [
                        Text("Days: ",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey)),
                        Expanded(
                          child: TextFormField(
                            controller: dateController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Days',
                              isDense: true,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              errorText: approvedDaysError,
                              fillColor: Colors.orange[50],
                              filled: true,
                            ),
                            onChanged: (val) {
                              recalculate();
                              validateApprovedDays(val);
                            },
                          ),
                        ),
                      ],
                    ),
                    if (approvedDaysError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0, left: 8.0),
                        child: Text(
                          approvedDaysError!,
                          style: TextStyle(color:Color(0xFF003768), fontSize: 12),
                        ),
                      ),
                    SizedBox(height: 10),
                    ...List.generate(labours.length, (index) {
                      final designation =
                          labourDesignationControllers[index].text;
                      final matched = allLabours.firstWhere(
                          (l) => l['designation'] == designation,
                          orElse: () => {});
                      final labourId = matched['labourId']?.toString() ?? '';
                      final salary =
                          int.tryParse(matched['salary']?.toString() ?? '0') ??
                              0;
                      final count =
                          int.tryParse(labourCountControllers[index].text) ?? 0;
                      final totalSalary = count * salary;
                      return _LabourRequirementCard(
                        designation: designation,
                        labourId: labourId,
                        salary: salary,
                        count: count,
                        total: totalSalary,
                        color: Color(0xFF003768),
                        editable: true,
                        countController: labourCountControllers[index],
                        designationController:
                            labourDesignationControllers[index],
                        onChanged: recalculate,
                      );
                    }),
                    SizedBox(height: 18),
                    // Actual amount
                    Container(
                      width: double.infinity,
                      margin: EdgeInsets.symmetric(vertical: 8),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green.shade100, Colors.green.shade50],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.payments, color: Colors.green[700]),
                          SizedBox(width: 10),
                          Text(
                            "Actual Payment: ",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                                fontSize: 16),
                          ),
                          Expanded(
                            child: Text(
                              '₹${getApprovedDays() * calculateLabourTotal()}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.green),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 17),
                    if (request['approvalStatus'] == "Pending")
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            icon: Icon(Icons.check, ),
                            label: Text("Approve",
                                style: TextStyle()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 22, vertical: 14),
                            ),
                            onPressed: (approvedDaysError != null)
                                ? null
                                : () async {
                                    final wsReqId = request['wsReqId'];
                                    final approvedDays =
                                        int.tryParse(dateController.text) ??
                                            request['reqDays'];
                                    final estimatedDays =
                                        request['reqDays'] ?? 0;
                                    if (approvedDays > estimatedDays) {
                                      setState(() {
                                        approvedDaysError =
                                            "Approved Days ($approvedDays) cannot be greater than Estimated Days ($estimatedDays).";
                                      });
                                      return;
                                    }
                                    final docSnapshot = await FirebaseFirestore
                                        .instance
                                        .collection(
                                            'siteSupervisorProjectStageSchedule')
                                        .where('wsReqId', isEqualTo: wsReqId)
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
                                                'labourCount': int.tryParse(
                                                        labourCountControllers[
                                                                i]
                                                            .text) ??
                                                    0,
                                                'labourDesignation':
                                                    labourDesignationControllers[
                                                            i]
                                                        .text,
                                              });
                                      await docRef.update({
                                        'appDays': approvedDays,
                                        'appLabours': approvedLabours,
                                        'approvedPayment': approvedPayment,
                                        'approvalStatus': 'Approved',
                                      });
                                      request['appDays'] = approvedDays;
                                      request['appLabours'] = approvedLabours;
                                      request['approvedPayment'] =
                                          approvedPayment;
                                    }
                                    setState(() {
                                      request['approvalStatus'] = 'Approved';
                                      pendingRequests = allRequests
                                          .where((req) =>
                                              req["approvalStatus"] ==
                                              "Pending")
                                          .toList();
                                      approvedRequests = allRequests
                                          .where((req) =>
                                              req["approvalStatus"] ==
                                              "Approved")
                                          .toList();
                                    });
                                    Navigator.pop(context);
                                  },
                          ),
                          SizedBox(width: 10),
                          ElevatedButton.icon(
                            icon: Icon(Icons.close, ),
                            label: Text("Reject",
                                style: TextStyle()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF003768),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 22, vertical: 14),
                            ),
                            onPressed: () => _updateRequestStatus(
                                request['wsReqId'], "Rejected"),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.9,
          minChildSize: 0.4,
          maxChildSize: 0.98,
          builder: (context, scrollController) => SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: getSymmetricPadding(context, fraction: 0.06)
                  .copyWith(top: 32, bottom: 32),
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
                          color: Color(0xFF003768),
                        ),
                      ),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
                  Text("Project Info",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: Color(0xFF772323))),
                  SizedBox(height: 3),
                  _RowInfo(
                      label: "Project Name",
                      value: request['projectName'] ?? '',
                      icon: Icons.business),
                  _RowInfo(
                      label: "Site ID",
                      value: request['siteId'] ?? '',
                      icon: Icons.location_on),
                  _RowInfo(
                      label: "Supervisor",
                      value: request['supervisorName'] ?? '',
                      icon: Icons.person),
                  _RowInfo(
                      label: "Project Stage",
                      value: request['projectStage'] ?? '',
                      icon: Icons.account_tree),
                  SizedBox(height: 14),
                  // Approved Labour Requirements
                  Text("Approved Labour Requirements",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: Color(0xFF003768))),
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
                    final count = int.tryParse(
                            labour['labourCount']?.toString() ?? '0') ??
                        0;
                    final totalSalary = count * salary;
                    return _LabourRequirementCard(
                      designation: designation,
                      labourId: labourId,
                      salary: salary,
                      count: count,
                      total: totalSalary,
                      color: Color(0xFF003768),
                      editable: false,
                    );
                  }),
                  SizedBox(height: 17),
                  // Approved Details
                  Text("Approved Details",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: Color(0xFF003768))),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Text("Days: ",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey)),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            approvedDays.toString(),
                            style: TextStyle(
                                fontSize: 16, color: Colors.blueGrey[900]),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text("Approved Amount: ",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey)),
                      Expanded(
                        child: Text(
                          '₹$approvedPayment',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.green[700]),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 22),
                  Center(
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 18, vertical: 8),
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
                                fontSize: 16),
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
          (req) => req['wsReqId'] == wsReqId)['approvalStatus'] = status;
      pendingRequests = allRequests
          .where((req) => req["approvalStatus"] == "Pending")
          .toList();
      approvedRequests = allRequests
          .where((req) => req["approvalStatus"] == "Approved")
          .toList();
    });
    Navigator.pop(context);
  }

  Widget _buildRequestList(List<Map<String, dynamic>> requests,
      {bool isApprovedTab = false}) {
    List<Map<String, dynamic>> filteredRequests = List.from(requests);
    if (_searchText.isNotEmpty) {
      final idx = filteredRequests.indexWhere((req) => (req['wsReqId'] ?? '')
          .toString()
          .toLowerCase()
          .contains(_searchText.toLowerCase()));
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
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.only(bottom: 28, top: 8),
      itemCount: filteredRequests.length,
      itemBuilder: (context, index) {
        final request = filteredRequests[index];
        return GestureDetector(
          onTap: () => isApprovedTab
              ? _showApprovedRequestDetails(request)
              : _showRequestDetails(request),
          child: Card(
            margin: getSymmetricPadding(context, fraction: 0.04)
                .copyWith(top: 12, bottom: 10),
            
            elevation: 7,
            shadowColor: Colors.black12,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.assignment,
                          color: Color(0xFF003768), size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          request['wsReqId'] ?? "",
                          style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF003768)),
                        ),
                      ),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            isApprovedTab ? Colors.green[100]! : Colors.orange,
                            Colors.white
                          ]),
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: Text(
                          request['approvalStatus'] ?? '',
                          style: TextStyle(
                            color: isApprovedTab
                                ? Colors.green[800]
                                : Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 14),
                  Text("Project: ${request['projectName'] ?? ''}",
                      style: TextStyle(fontSize: 16)),
                  Text("Site: ${request['siteId'] ?? ''}",
                      style: TextStyle(fontSize: 16)),
                  Text("Supervisor: ${request['supervisorName'] ?? ''}",
                      style: TextStyle(fontSize: 16)),
                  Text("Stage: ${request['projectStage'] ?? ''}",
                      style: TextStyle(fontSize: 16)),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.inventory_2,
                          color: Color(0xFF003768), size: 22),
                      SizedBox(width: 8),
                      Text(
                        "${(request['reqLabours'] ?? []).length} Labours",
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      Spacer(),
                      Icon(
                        isApprovedTab ? Icons.verified : Icons.pending_actions,
                        size: 20,
                        color:
                            isApprovedTab ? Colors.green[700] : Colors.orange,
                      ),
                      SizedBox(width: 4),
                      Text(
                        "Status: ${request['approvalStatus']}",
                        style: TextStyle(
                          color: isApprovedTab ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
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
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text("Work Schedule Requests",
            style: TextStyle( fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 3,
        backgroundColor: Color(0xFF003768),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(100),
          child: Column(
            children: [
              Material(
                
                child: TabBar(
                  controller: _tabController,
                  labelColor: Color(0xFF003768),
                  unselectedLabelColor: Colors.grey[500],
                  indicatorColor: Color(0xFF003768),
                  indicatorWeight: 4,
                  tabs: [
                    Tab(text: "Pending"),
                    Tab(text: "Approved"),
                  ],
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by Request ID',
                    prefixIcon: Icon(Icons.search, color: Color(0xFF772323)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Color(0xFF772323)),
                    ),
                    filled: true,
                    
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchText = value.trim();
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildRequestList(pendingRequests, isApprovedTab: false),
            _buildRequestList(approvedRequests, isApprovedTab: true),
          ],
        ),
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

// --- Helper Widgets styled as per ManagerMaterialApprovalScreen ---

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
    return Row(
      children: [
        Icon(icon, color: Color(0xFF003768), size: 20),
        SizedBox(width: 7),
        Text("$label: ", style: TextStyle(fontWeight: FontWeight.bold)),
        Flexible(child: Text(value, overflow: TextOverflow.ellipsis)),
      ],
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
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.inventory, color: color, size: 18),
            ),
            SizedBox(width: 10),
            Expanded(
              child: editable
                  ? Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: countController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Count',
                              isDense: true,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              fillColor: Colors.orange[50],
                              filled: true,
                            ),
                            onChanged: (val) => onChanged?.call(),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: designationController,
                            decoration: InputDecoration(
                              labelText: 'Designation',
                              isDense: true,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              fillColor: Colors.orange[50],
                              filled: true,
                            ),
                            onChanged: (val) => onChanged?.call(),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ID: $labourId',
                                  style: TextStyle(
                                      fontSize: 12, )),
                              Text('Salary: ₹$salary',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                              Text('Total: ₹$total',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.green)),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          designation,
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2),
                        Text('ID: $labourId',
                            style: TextStyle(
                                fontSize: 12, )),
                        Text('Salary: ₹$salary',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text('Count: $count',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text('Total: ₹$total',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.green)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
