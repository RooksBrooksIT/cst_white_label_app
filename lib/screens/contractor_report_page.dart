import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ContractorReportPage extends StatefulWidget {
  const ContractorReportPage({super.key});

  @override
  _ContractorReportPageState createState() => _ContractorReportPageState();
}

class _ContractorReportPageState extends State<ContractorReportPage> {
  // Color scheme based on your base color #0b3470 (navy blue)
  final Color primaryColor = Color(0xFF0b3470);
  final Color primaryLightColor = Color(0xFF1a4a8c);
  final Color primaryDarkColor = Color(0xFF052356);
  final Color accentColor = Color(0xFF4a86e8);
  final Color backgroundColor = Color(0xFFf5f7fa);
  final Color cardColor = Colors.white;
  final Color textColor = Color(0xFF2c3e50);
  final Color lightTextColor = Color(0xFF7f8c8d);
  final Color successColor = Color(0xFF27ae60);
  final Color warningColor = Color(0xFFe67e22);
  final Color errorColor = Color(0xFFe74c3c);

  List<Map<String, dynamic>> expenses = [];
  bool isLoadingExpenses = false;
  double totalAmount = 0.0;
  String? selectedContractor;
  List<String> contractorNames = [];
  String? selectedSiteId;
  List<String> siteIdOptions = [];
  bool isLoadingContractors = false;
  bool isLoadingSites = false;
  int? selectedRowIndex;

  // Store the last generated report
  List<Map<String, dynamic>>? lastExpenses;
  double? lastTotalAmount;
  String? lastContractor;
  String? lastSiteId;

  @override
  void initState() {
    super.initState();
    _fetchContractorNames();
  }

  void _showContractDatesModal(Map<String, dynamic> expense) {
    final contractStart = expense['contractorStartDate'];
    final contractEnd = expense['contractorEndDate'];
    DateTime? startDate;
    DateTime? endDate;
    if (contractStart is Timestamp) {
      startDate = contractStart.toDate();
    } else if (contractStart is String) {
      startDate = DateTime.tryParse(contractStart);
    }
    if (contractEnd is Timestamp) {
      endDate = contractEnd.toDate();
    } else if (contractEnd is String) {
      endDate = DateTime.tryParse(contractEnd);
    }
    final now = DateTime.now();
    int workingDays = 0;
    if (startDate != null) {
      workingDays = now.difference(startDate).inDays;
    }
    String formatDate(DateTime? d) {
      if (d == null) return '-';
      return DateFormat('dd MMM yyyy').format(d);
    }
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Contract Details', 
                    style: TextStyle(
                      fontSize: 20, 
                      fontWeight: FontWeight.bold, 
                      color: textColor
                    )
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: lightTextColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 24),
              Row(
                children: [
                  Icon(Icons.calendar_today, color: primaryColor),
                  SizedBox(width: 12),
                  Text('Contract Start Date: ', 
                    style: TextStyle(fontWeight: FontWeight.w600, color: textColor)
                  ),
                  SizedBox(width: 8),
                  Text(formatDate(startDate), 
                    style: TextStyle(color: textColor)
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.event, color: accentColor),
                  SizedBox(width: 12),
                  Text('Contract End Date: ', 
                    style: TextStyle(fontWeight: FontWeight.w600, color: textColor)
                  ),
                  SizedBox(width: 8),
                  Text(formatDate(endDate), 
                    style: TextStyle(color: textColor)
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.work_history, color: successColor),
                  SizedBox(width: 12),
                  Text('Working Days: ', 
                    style: TextStyle(fontWeight: FontWeight.w600, color: textColor)
                  ),
                  SizedBox(width: 8),
                  Text('$workingDays days', 
                    style: TextStyle(color: textColor)
                  ),
                ],
              ),
              SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  ),
                  child: Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _fetchExpensesForSelection() async {
    if (selectedContractor == null || selectedSiteId == null) return;
    setState(() {
      isLoadingExpenses = true;
      expenses = [];
      totalAmount = 0.0;
      selectedRowIndex = null;
    });
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('contractorEntries')
          .where('contractorName', isEqualTo: selectedContractor)
          .where('siteId', isEqualTo: selectedSiteId)
          .get();
      double sum = 0.0;
      final List<Map<String, dynamic>> fetchedExpenses = [];
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final dynamic amt = data['totalAmount'] ?? data['amount'] ?? 0;
        double parsed = 0.0;
        if (amt is int) {
          parsed = amt.toDouble();
        } else if (amt is double) parsed = amt;
        else if (amt is String) parsed = double.tryParse(amt) ?? 0.0;
        sum += parsed;
        fetchedExpenses.add(data);
      }
      setState(() {
        expenses = fetchedExpenses;
        totalAmount = sum;
        isLoadingExpenses = false;

        // Store the last generated report
        lastExpenses = fetchedExpenses;
        lastTotalAmount = sum;
        lastContractor = selectedContractor;
        lastSiteId = selectedSiteId;

        // Clear the fields
        selectedContractor = null;
        selectedSiteId = null;
        siteIdOptions = [];
        selectedRowIndex = null;
      });
    } catch (e) {
      setState(() => isLoadingExpenses = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching expenses: $e'),
          backgroundColor: errorColor,
        ),
      );
    }
  }

  Future<void> _fetchContractorNames() async {
    setState(() => isLoadingContractors = true);
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('contractors')
          .orderBy('contractorName')
          .get();
      final names = querySnapshot.docs
          .map((doc) => (doc.data()['contractorName'] as String?)?.trim())
          .where((name) => name != null && name.isNotEmpty)
          .map((name) => name!)
          .toSet()
          .toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      setState(() {
        contractorNames = names;
        isLoadingContractors = false;
      });
    } catch (e) {
      setState(() => isLoadingContractors = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching contractors: $e'),
          backgroundColor: errorColor,
        ),
      );
    }
  }

  Future<void> _fetchSiteIdsForContractor(String contractorName) async {
    setState(() {
      isLoadingSites = true;
      siteIdOptions = [];
      selectedSiteId = null;
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('projects')
          .where('isContractWork', isEqualTo: true)
          .where('contractorName', isEqualTo: contractorName)
          .get();
      final ids = <String>[];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final id = data['siteId']?.toString() ?? '';
        if (id.isNotEmpty) ids.add(id);
      }
      setState(() {
        siteIdOptions = ids;
        if (ids.isNotEmpty) selectedSiteId = ids.first;
        isLoadingSites = false;
      });
    } catch (e) {
      setState(() {
        isLoadingSites = false;
        siteIdOptions = [];
        selectedSiteId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching Site IDs: $e'),
          backgroundColor: errorColor,
        ),
      );
    }
  }

  void _showEntryDetails(Map<String, dynamic> expense) {
    num asNum(dynamic v) {
      if (v is int) return v;
      if (v is double) return v;
      if (v is String) return num.tryParse(v) ?? 0;
      return 0;
    }

    final num food = asNum(expense['food']);
    final num fuel = asNum(expense['fuel']);
    final num transport = asNum(expense['transport']);
    final num totalAmt = asNum(expense['totalAmount'] ?? expense['amount']);
    final String siteName = expense['siteName'] ?? 'Unknown Site';
    final String siteId = expense['siteId']?.toString() ?? '-';

    final List<dynamic> labours = (expense['labours'] as List<dynamic>?) ?? [];
    final List<dynamic> materials = (expense['materials'] as List<dynamic>?) ?? [];

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: EdgeInsets.all(20),
          constraints: BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Entry Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: lightTextColor),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                // Entry Details Section (Contract Dates & Working Days)
                Row(
                  children: [
                    Expanded(
                      child: _DetailCard(
                        title: 'Contract Start Date',
                        content: expense['contractorStartDate'] != null
                            ? (expense['contractorStartDate'] is Timestamp
                                ? DateFormat('dd MMM yyyy').format(expense['contractorStartDate'].toDate())
                                : (expense['contractorStartDate'] is String && DateTime.tryParse(expense['contractorStartDate']) != null
                                    ? DateFormat('dd MMM yyyy').format(DateTime.parse(expense['contractorStartDate']))
                                    : '-'))
                            : '-',
                        icon: Icons.calendar_today,
                        color: primaryColor,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _DetailCard(
                        title: 'Contract End Date',
                        content: expense['contractorEndDate'] != null
                            ? (expense['contractorEndDate'] is Timestamp
                                ? DateFormat('dd MMM yyyy').format(expense['contractorEndDate'].toDate())
                                : (expense['contractorEndDate'] is String && DateTime.tryParse(expense['contractorEndDate']) != null
                                    ? DateFormat('dd MMM yyyy').format(DateTime.parse(expense['contractorEndDate']))
                                    : '-'))
                            : '-',
                        icon: Icons.event,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Center(
                  child: _DetailCard(
                    title: 'Working Days',
                    content: (expense['contractorStartDate'] != null &&
                            ((expense['contractorStartDate'] is Timestamp && DateTime.now().difference(expense['contractorStartDate'].toDate()).inDays > 0) ||
                             (expense['contractorStartDate'] is String && DateTime.tryParse(expense['contractorStartDate']) != null && DateTime.now().difference(DateTime.parse(expense['contractorStartDate'])).inDays > 0)))
                        ? (expense['contractorStartDate'] is Timestamp
                            ? '${DateTime.now().difference(expense['contractorStartDate'].toDate()).inDays} days'
                            : '${DateTime.now().difference(DateTime.parse(expense['contractorStartDate'])).inDays} days')
                        : '-',
                    icon: Icons.timelapse,
                    color: successColor,
                  ),
                ),
                SizedBox(height: 16),
                Center(
                  child: Column(
                    children: [
                      _DetailCard(
                        title: 'Site ID',
                        content: siteId,
                        icon: Icons.confirmation_number,
                        color: primaryLightColor,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _DetailCard(
                        title: 'Food',
                        content: '₹$food',
                        icon: Icons.restaurant,
                        color: primaryLightColor,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _DetailCard(
                        title: 'Fuel',
                        content: '₹$fuel',
                        icon: Icons.local_gas_station,
                        color: primaryLightColor,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _DetailCard(
                        title: 'Transport',
                        content: '₹$transport',
                        icon: Icons.directions_car,
                        color: primaryLightColor,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _DetailCard(
                        title: 'Total',
                        content: '₹$totalAmt',
                        icon: Icons.attach_money,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Text(
                  'Labours (${labours.length})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 10),
                if (labours.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'No labours recorded',
                      style: TextStyle(color: lightTextColor),
                    ),
                  )
                else
                  ...labours.map((e) {
                    final type = (e['type'] ?? '').toString();
                    final count = asNum(e['count']);
                    final unitSalary = asNum(e['unitSalary']);
                    final amount = asNum(e['amount']);
                    return Container(
                      margin: EdgeInsets.only(bottom: 8),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.engineering, color: primaryColor),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  type,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: textColor,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Count: $count • Unit: ₹$unitSalary',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: lightTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '₹$amount',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                SizedBox(height: 20),
                Text(
                  'Materials (${materials.length})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 10),
                if (materials.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'No materials recorded',
                      style: TextStyle(color: lightTextColor),
                    ),
                  )
                else
                  ...materials.map((e) {
                    final type = (e['type'] ?? '').toString();
                    final qty = asNum(e['quantity']);
                    final unitPrice = asNum(e['unitPrice']);
                    final amount = asNum(e['amount']);
                    return Container(
                      margin: EdgeInsets.only(bottom: 8),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.inventory_2, color: primaryColor),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  type,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: textColor,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Qty: $qty • Unit: ₹$unitPrice',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: lightTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '₹$amount',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                SizedBox(height: 20),
                Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    ),
                    child: Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Contractor Report',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            
          ),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: IconThemeData(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Contractor selection card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [cardColor, Color(0xFFf0f4f8)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CONTRACTOR NAME',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: lightTextColor,
                        letterSpacing: 1.0,
                      ),
                    ),
                    SizedBox(height: 8),
                    isLoadingContractors
                        ? Center(child: CircularProgressIndicator(color: primaryColor))
                        : DropdownButtonFormField<String>(
                            value: selectedContractor,
                            hint: Text('Select Contractor', style: TextStyle(color: lightTextColor)),
                            isExpanded: true,
                            dropdownColor: cardColor,
                            style: TextStyle(color: textColor),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: backgroundColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: primaryColor.withOpacity(0.3)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: primaryColor),
                              ),
                            ),
                            items: contractorNames.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value, style: TextStyle(color: textColor)),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedContractor = newValue;
                                selectedSiteId = null;
                                siteIdOptions = [];
                                selectedRowIndex = null;
                              });
                              if (newValue != null) {
                                _fetchSiteIdsForContractor(newValue);
                              }
                            },
                          ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            
            // Site ID selection card (only shown when contractor is selected)
            if (selectedContractor != null)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [cardColor, Color(0xFFf0f4f8)],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SITE ID',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: lightTextColor,
                          letterSpacing: 1.0,
                        ),
                      ),
                      SizedBox(height: 8),
                      isLoadingSites
                          ? Center(child: CircularProgressIndicator(color: primaryColor))
                          : DropdownButtonFormField<String>(
                              value: selectedSiteId,
                              hint: Text('Select Site ID', style: TextStyle(color: lightTextColor)),
                              isExpanded: true,
                              dropdownColor: cardColor,
                              style: TextStyle(color: textColor),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: backgroundColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: primaryColor.withOpacity(0.3)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: primaryColor),
                                ),
                              ),
                              items: siteIdOptions.map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value, style: TextStyle(color: textColor)),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  selectedSiteId = newValue;
                                  selectedRowIndex = null;
                                });
                              },
                            ),
                    ],
                  ),
                ),
              ),
            SizedBox(height: 24),
            
            // Generate Report button (only shown when both contractor and site are selected)
            if (selectedContractor != null && selectedSiteId != null)
              ElevatedButton(
                onPressed: _fetchExpensesForSelection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  shadowColor: primaryColor.withOpacity(0.3),
                ),
                child: isLoadingExpenses 
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        
                        strokeWidth: 2,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.summarize, size: 20),
                        SizedBox(width: 8),
                        Text('GENERATE REPORT'),
                      ],
                    ),
              ),
            SizedBox(height: 24),
            
            // Loading indicator
            if (isLoadingExpenses)
              Center(child: CircularProgressIndicator(color: primaryColor)),

            // Show the last generated report if available
            if (!isLoadingExpenses && (lastExpenses != null && lastExpenses!.isNotEmpty))
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Total expenses card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [cardColor, Color(0xFFf0f4f8)],
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Expenses:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            Text(
                              '₹${lastTotalAmount?.toStringAsFixed(2) ?? '0.00'}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    // Expense entries section
                    Row(
                      children: [
                        Text(
                          'Expense Entries',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${lastExpenses!.length} entries',
                            style: TextStyle(
                              fontSize: 12,
                              color: primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    
                    // Data table
                    Expanded(
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Container(
                              constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 32),
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.resolveWith<Color>(
                                  (Set<WidgetState> states) => primaryColor.withOpacity(0.05),
                                ),
                                dataRowColor: WidgetStateProperty.resolveWith<Color>(
                                  (Set<WidgetState> states) {
                                    return states.contains(WidgetState.selected)
                                        ? primaryColor.withOpacity(0.2)
                                        : Colors.transparent;
                                  },
                                ),
                                showCheckboxColumn: false,
                                columns: [
                                  DataColumn(
                                    label: Padding(
                                      padding: EdgeInsets.symmetric(vertical: 8),
                                      child: Text('Date', 
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: primaryColor,
                                        )
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Padding(
                                      padding: EdgeInsets.symmetric(vertical: 8),
                                      child: Text('Site ID', 
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: primaryColor,
                                        )
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Padding(
                                      padding: EdgeInsets.symmetric(vertical: 8),
                                      child: Text('Project Stage', 
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: primaryColor,
                                        )
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Padding(
                                      padding: EdgeInsets.symmetric(vertical: 8),
                                      child: Text('Expense', 
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: primaryColor,
                                        )
                                      ),
                                    ),
                                  ),
                                ],
                                rows: List<DataRow>.generate(lastExpenses!.length, (index) {
                                  final e = lastExpenses![index];
                                  final date = e['date'] ?? '';
                                  final siteId = e['siteId'] ?? '';
                                  final stage = e['projectStage'] ?? '';
                                  final amt = e['totalAmount'] ?? e['amount'] ?? 0;
                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Text(date.toString(), 
                                          style: TextStyle(
                                            color: textColor,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(siteId.toString()),
                                      ),
                                      DataCell(
                                        Text(stage.toString()),
                                      ),
                                      DataCell(
                                        Text('₹$amt', 
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold, 
                                            color: primaryColor,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                    onSelectChanged: (_) {
                                      _showEntryDetails(e);
                                    },
                                  );
                                }),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            // No expenses found message
            if (!isLoadingExpenses && (lastExpenses != null && lastExpenses!.isEmpty) && (lastContractor != null && lastSiteId != null))
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 48,
                        color: lightTextColor,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No expenses found',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'There are no expenses recorded for this contractor and site combination.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: lightTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final String title;
  final String content;
  final IconData icon;
  final Color color;

  const _DetailCard({
    required this.title,
    required this.content,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF666666),
            ),
          ),
          SizedBox(height: 4),
          Text(
            content,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }
}