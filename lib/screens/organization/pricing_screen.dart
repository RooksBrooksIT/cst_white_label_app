import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/services/auth_service.dart';
import 'package:demo_cst/utils/terms_helper.dart';
import 'package:demo_cst/services/payu_service.dart';
import 'package:demo_cst/screens/organization/payu_checkout_screen.dart';
import 'package:demo_cst/screens/organization/organization_dashboard.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';

class PricingScreen extends StatefulWidget {
  final String orgName;
  final String email;
  final String phone;
  final String username;
  final String password;
  final String dateStr;
  final String appName;
  final Color selectedColor;

  const PricingScreen({
    super.key,
    required this.orgName,
    required this.email,
    required this.phone,
    required this.username,
    required this.password,
    required this.dateStr,
    required this.appName,
    required this.selectedColor,
  });

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  bool _isLoading = false;
  String _selectedPlanType = 'Monthly';
  String _selectedPlan = 'Silver';
  int _goldProjectsCount = 10;

  double _calculatePlanAmount() {
    if (_selectedPlanType == 'Free Trial') return 0.0;

    if (_selectedPlan == 'Silver') {
      if (_selectedPlanType == '6 Months') return 1194.0;
      if (_selectedPlanType == 'Yearly') return 2388.0;
      return 199.0;
    } else if (_selectedPlan == 'Gold') {
      if (_selectedPlanType == '6 Months') {
        return (_goldProjectsCount * 599.4).roundToDouble();
      }
      if (_selectedPlanType == 'Yearly') {
        return (_goldProjectsCount * 1198.8).roundToDouble();
      }
      return (_goldProjectsCount * 99.9).roundToDouble();
    } else if (_selectedPlan == 'Platinum') {
      if (_selectedPlanType == '6 Months') return 10794.0;
      if (_selectedPlanType == 'Yearly') return 21588.0;
      return 1799.0;
    }
    return 0.0;
  }

  String _formatPrice(int price) {
    final format = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return '₹${price.toString().replaceAllMapped(format, (Match m) => '${m[1]},')}';
  }

  Future<Map<String, String>?> _showPaymentMethodBottomSheet(double amount) async {
    return await showModalBottomSheet<Map<String, String>>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Select Payment Method",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0A183D)),
                ),
                Text(
                  "₹${amount.toStringAsFixed(0)}",
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF10B981)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              "Direct app launch powered by PayU",
              style: TextStyle(fontSize: 12.5, color: Color(0xFF5A759E)),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE2E8F0))),
              leading: const CircleAvatar(backgroundColor: Color(0xFFEFF6FF), child: Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF4285F4))),
              title: const Text("Google Pay (GPay)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
              subtitle: const Text("Opens GPay app directly", style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              onTap: () => Navigator.pop(context, {'pg': 'UPI', 'bankcode': 'TEZ'}),
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE2E8F0))),
              leading: const CircleAvatar(backgroundColor: Color(0xFFF3E8FF), child: Icon(Icons.mobile_friendly_rounded, color: Color(0xFF5F259F))),
              title: const Text("PhonePe", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
              subtitle: const Text("Opens PhonePe app directly", style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              onTap: () => Navigator.pop(context, {'pg': 'UPI', 'bankcode': 'PHONEPE'}),
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE2E8F0))),
              leading: const CircleAvatar(backgroundColor: Color(0xFFE0F2FE), child: Icon(Icons.payment_rounded, color: Color(0xFF00BAF2))),
              title: const Text("Paytm UPI", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
              subtitle: const Text("Opens Paytm app directly", style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              onTap: () => Navigator.pop(context, {'pg': 'UPI', 'bankcode': 'PAYTM'}),
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE2E8F0))),
              leading: const CircleAvatar(backgroundColor: Color(0xFFECFDF5), child: Icon(Icons.apps_rounded, color: Color(0xFF10B981))),
              title: const Text("Other UPI Apps", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
              subtitle: const Text("Select from all installed UPI apps", style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              onTap: () => Navigator.pop(context, {'pg': 'UPI', 'bankcode': 'INTENT'}),
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE2E8F0))),
              leading: const CircleAvatar(backgroundColor: Color(0xFFF1F5F9), child: Icon(Icons.credit_card_rounded, color: Color(0xFF0B1942))),
              title: const Text("Credit / Debit Card & NetBanking", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
              subtitle: const Text("Visa, MasterCard, SBI, HDFC, ICICI", style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              onTap: () => Navigator.pop(context, {'pg': 'CC', 'bankcode': 'CC'}),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _register() async {
    final double amount = _calculatePlanAmount();
    PayUResult? payuResult;
    // Handle PayU Payment Gateway for Paid Plans
    if (_selectedPlanType != 'Free Trial' && amount > 0) {
      final selectedMethod = await _showPaymentMethodBottomSheet(amount);
      if (!mounted || selectedMethod == null) return; // User closed sheet or unmounted


      final txnId = PayUService.generateTxnId();
      final payUParams = PayUParams(
        merchantId: PayUService.activeMerchantId,
        merchantKey: PayUService.activeMerchantKey,
        merchantSalt: PayUService.activeMerchantSalt,
        txnid: txnId,
        amount: amount,
        productInfo: '${widget.orgName} $_selectedPlan Plan ($_selectedPlanType)',
        firstName: widget.orgName.isEmpty ? (widget.username.isEmpty ? 'Organization' : widget.username) : widget.orgName,
        email: widget.email.isEmpty ? 'customer@example.com' : widget.email,
        phone: widget.phone.isEmpty ? '9999999999' : widget.phone,
        isSandbox: !PayUService.isProduction,
        pg: selectedMethod['pg']!,
        bankcode: selectedMethod['bankcode']!,
      );

      final result = await Navigator.push<PayUResult>(
        context,
        MaterialPageRoute(
          builder: (context) => PayUCheckoutScreen(params: payUParams),
        ),
      );

      if (result == null || !result.isSuccess) {
        if (mounted) {
          AppTheme.showErrorToast(
            context,
            result?.errorMessage ?? 'Payment was cancelled or failed.',
          );
        }
        return;
      }

      payuResult = result;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Create Firebase Auth account (with fallback UID if network fails)
      String uid = 'local_uid_${DateTime.now().millisecondsSinceEpoch}';
      try {
        final userCredential = await AuthService().registerWithEmail(
          widget.email.isEmpty ? 'admin@${widget.orgName.replaceAll(' ', '')}.com' : widget.email,
          widget.password.isEmpty ? '123456' : widget.password,
        );
        if (userCredential.user != null) {
          uid = userCredential.user!.uid;
        }
      } catch (authError) {
        debugPrint('Firebase Auth network warning (using fallback UID): $authError');
      }

      String orgReferralCode = 'REF${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      try {
        orgReferralCode = await FirestoreService.generateUniqueReferralCode();
      } catch (refError) {
        debugPrint('Referral code generator warning: $refError');
      }

      // Sanitize orgName to create a valid Firestore document ID
      final String sanitizedOrgName = widget.orgName.isEmpty
          ? 'Org'
          : widget.orgName.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
      final String dateSuffix = widget.dateStr.isEmpty
          ? DateTime.now().millisecondsSinceEpoch.toString()
          : widget.dateStr;
      final String orgId = '${sanitizedOrgName}_$dateSuffix';

      final String orgConfigDocPath = 'organisation/$orgId/data/admin';

      // Subscription dates
      final now = DateTime.now();
      final DateTime endDate;
      if (_selectedPlanType == 'Free Trial') {
        endDate = now.add(const Duration(days: 14));
      } else if (_selectedPlanType == '6 Months') {
        endDate = now.add(const Duration(days: 180));
      } else if (_selectedPlanType == 'Yearly') {
        endDate = now.add(const Duration(days: 365));
      } else {
        endDate = now.add(const Duration(days: 30));
      }

      final Map<String, dynamic> brandingData = {
        'appName': widget.appName.isEmpty ? 'eBricks' : widget.appName,
        'primaryColor': AppTheme.colorToHex(widget.selectedColor),
        'createdAt': FieldValue.serverTimestamp(),
      };

      final Map<String, dynamic> adminData = {
        'orgName': widget.orgName.isEmpty ? 'My Organization' : widget.orgName,
        'email': widget.email,
        'phone': widget.phone,
        'username': widget.username.isEmpty ? 'admin' : widget.username,
        'password': widget.password,
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      };

      final Map<String, dynamic> referralData = {
        'referralCode': orgReferralCode,
        'orgReferralCode': orgReferralCode,
        'createdAt': FieldValue.serverTimestamp(),
      };

      final Map<String, dynamic> subData = {
        'subscriptionPlan': _selectedPlan.toLowerCase(),
        'subscriptionStartDate': Timestamp.fromDate(now),
        'subscriptionEndDate': Timestamp.fromDate(endDate),
        'isSubscriptionActive': true,
        'paymentGateway': payuResult != null ? 'PayU' : 'Free Trial',
        'paymentTxnId': payuResult?.txnid ?? '',
        'paymentAmount': amount,
        'payuMoneyId': payuResult?.payuMoneyId ?? '',
        'payerName': widget.orgName,
        'payerEmail': widget.email,
        'payerPhone': widget.phone,
        'maxProjects': _selectedPlan == 'Gold'
            ? _goldProjectsCount
            : _selectedPlan == 'Silver'
            ? 3
            : _selectedPlan == 'Platinum'
            ? 99999
            : 1,
        'maxUsers': _selectedPlan == 'Gold'
            ? (_goldProjectsCount * 1.5).round()
            : _selectedPlan == 'Silver'
            ? 5
            : _selectedPlan == 'Platinum'
            ? 99999
            : 2,
        'createdAt': FieldValue.serverTimestamp(),
      };

      final Map<String, dynamic> userData = {
        'username': widget.username.isEmpty ? 'admin' : widget.username,
        'password': widget.password,
        'role': 'admin',
        'orgId': orgId,
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Write to Firestore with fallback
      try {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final orgRef = FirebaseFirestore.instance.collection('organisation').doc(orgId);
          final dataColl = orgRef.collection('data');

          transaction.set(dataColl.doc('branding'), brandingData);
          transaction.set(dataColl.doc('admin'), adminData);
          transaction.set(dataColl.doc('referral'), referralData);
          transaction.set(dataColl.doc('subscription'), subData);
          transaction.set(
            orgRef.collection('organizationUser').doc(widget.username.isEmpty ? 'admin' : widget.username),
            userData,
          );
        });
      } catch (fsError) {
        debugPrint('Firestore transaction fallback: $fsError');
        final orgRef = FirebaseFirestore.instance.collection('organisation').doc(orgId);
        final dataColl = orgRef.collection('data');
        await dataColl.doc('branding').set(brandingData).catchError((_) {});
        await dataColl.doc('admin').set(adminData).catchError((_) {});
        await dataColl.doc('referral').set(referralData).catchError((_) {});
        await dataColl.doc('subscription').set(subData).catchError((_) {});
        await orgRef
            .collection('organizationUser')
            .doc(widget.username.isEmpty ? 'admin' : widget.username)
            .set(userData)
            .catchError((_) {});
      }

      // Verify payment & confirm subscription status via Cloud Function backend
      if (payuResult != null && payuResult.isSuccess) {
        try {
          await PayUService.verifyAndActivateSubscriptionOnBackend(
            orgId: orgId,
            txnid: payuResult.txnid,
            payuMoneyId: payuResult.payuMoneyId,
            rawData: payuResult.rawData,
            planDetails: {
              'planName': _selectedPlan,
              'planType': _selectedPlanType,
              'amount': amount,
              'payerName': widget.orgName.isEmpty ? widget.username : widget.orgName,
              'payerEmail': widget.email,
              'payerPhone': widget.phone,
              'username': widget.username,
            },

          );
        } catch (backendError) {
          debugPrint('Backend subscription verification note: $backendError');
        }
      }

      // Auto-login using AuthService with fallback

      try {
        await AuthService().login(UserRole.organization, {
          'username': widget.username.isEmpty ? 'admin' : widget.username,
          'dynamicPath': orgId,
          'org_name': widget.orgName.isEmpty ? 'My Organization' : widget.orgName,
          'org_doc_path': orgConfigDocPath,
        });
      } catch (loginError) {
        debugPrint('AuthService login fallback: $loginError');
      }

      try {
        await FirestoreService.initialize();
        await AppTheme.updateTheme(widget.selectedColor);
        await AppTheme.updateAppName(widget.appName);
      } catch (_) {}

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Registration Successful!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0A183D),
                      ),
                    ),
                  ),
                ],
              ),
              content: Text(
                'Welcome ${widget.orgName.isEmpty ? "Admin" : widget.orgName}! Your workspace has been created successfully.',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF5A759E),
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OrganizationDashboard(),
                      ),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B1942),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Go to Dashboard'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      debugPrint('Registration error: $e');
      if (mounted) {
        AppTheme.showErrorToast(context, 'Registration failed: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isDesktop = screenWidth >= 1024;

    return Theme(
      data: AppTheme.getTheme(widget.selectedColor),
      child: GlassScaffold(
        padding: EdgeInsets.zero,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isMobile ? double.infinity : 650,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 16.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Custom Header Row (Back Button & Centered App Title)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B1942),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0B1942).withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        const Text(
                          'Choose Your Plan',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0A183D),
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(width: 40),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 1 2 3 Step Indicator Card
                    _buildStepIndicator(isDesktop),
                    const SizedBox(height: 24),

                    // Headline & Subtitle
                    const Padding(
                      padding: EdgeInsets.only(left: 4.0),
                      child: Text(
                        'Select Workspace Subscription',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0A183D),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Padding(
                      padding: EdgeInsets.only(left: 4.0),
                      child: Text(
                        'Manage projects smarter with the right plan',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0A183D),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Billing Duration Selector Tabs
                    _buildPlanTabs(isDesktop),
                    const SizedBox(height: 24),

                    // Subscription Cards
                    _buildPlanCards(isDesktop),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(bool isDesktop) {
    const steps = ['Details', 'Branding', 'Pricing'];
    const activeStep = 2; // Step 3 active

    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD4E3F4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B1942).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(steps.length, (index) {
          final isActive = activeStep == index;
          final isDone = activeStep > index;

          return Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: isDesktop ? 44 : 36,
                        height: isDesktop ? 44 : 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDone || isActive
                              ? const Color(0xFF0B1942)
                              : const Color(0xFFE2E8F0),
                        ),
                        child: Center(
                          child: isDone
                              ? Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: isDesktop ? 24 : 20,
                                )
                              : Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: isActive
                                        ? Colors.white
                                        : const Color(0xFF0A183D),
                                    fontSize: isDesktop ? 16 : 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(height: isDesktop ? 10 : 8),
                      Text(
                        steps[index],
                        style: const TextStyle(
                          color: Color(0xFF0A183D),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (index < steps.length - 1)
                  Flexible(
                    child: Container(
                      constraints: const BoxConstraints(
                        maxWidth: 60.0,
                        minWidth: 20.0,
                      ),
                      height: 2.5,
                      margin: EdgeInsets.only(
                        bottom: isDesktop ? 28 : 24,
                        left: 8,
                        right: 8,
                      ),
                      decoration: BoxDecoration(
                        color: activeStep > index
                            ? const Color(0xFF0B1942)
                            : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPlanTabs(bool isDesktop) {
    final options = [
      {'key': 'Free Trial', 'label': 'Free Trial', 'badge': null},
      {'key': 'Monthly', 'label': 'Monthly', 'badge': null},
      {'key': '6 Months', 'label': '6 Months', 'badge': 'SAVE 20%'},
      {'key': 'Yearly', 'label': 'Yearly', 'badge': 'SAVE 33%'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: options.map((opt) {
          final String key = opt['key'] as String;
          final String label = opt['label'] as String;
          final String? badge = opt['badge'];
          final isSelected = _selectedPlanType == key;
          const Color darkNavy = Color(0xFF0B1942);

          return Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedPlanType = key;
                  if (key == 'Free Trial') {
                    _selectedPlan = 'Free Trial';
                  } else {
                    _selectedPlan = 'Silver';
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  color: isSelected ? darkNavy : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? darkNavy : const Color(0xFFD4E3F4),
                    width: isSelected ? 2.0 : 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected
                          ? darkNavy.withValues(alpha: 0.25)
                          : darkNavy.withValues(alpha: 0.05),
                      blurRadius: isSelected ? 12 : 6,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                        color: isSelected ? Colors.white : const Color(0xFF0A183D),
                        fontSize: isDesktop ? 15.0 : 13.5,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF10B981)
                              : const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: isSelected ? Colors.white : const Color(0xFF047857),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPlanCards(bool isDesktop) {
    final isFreeTrial = _selectedPlanType == 'Free Trial';
    final is6Months = _selectedPlanType == '6 Months';
    final isYearly = _selectedPlanType == 'Yearly';

    if (isFreeTrial) {
      return _buildPlanCard(
        isDesktop: isDesktop,
        planName: 'Free Trial',
        description: 'Experience full features for 14 days',
        price: 'Free',
        originalPrice: '',
        features: const [
          'Basic Project Management',
          'Task Tracking & Updates',
          'Limited Team Members (up to 2)',
          'Basic Reports & Analytics',
        ],
      );
    }

    return Column(
      children: [
        _buildPlanCard(
          isDesktop: isDesktop,
          planName: 'Silver',
          description: 'For small teams starting out',
          price: is6Months
              ? '₹1,194'
              : isYearly
              ? '₹2,388'
              : '₹199',
          originalPrice: is6Months
              ? '₹1,794'
              : isYearly
              ? '₹3,588'
              : '₹299',
          features: const [
            'Basic Project Management',
            'Task Tracking & Updates',
            'Limited Team Members (3-5)',
            'Basic Reports & Data View',
          ],
        ),
        const SizedBox(height: 18),
        _buildPlanCard(
          isDesktop: isDesktop,
          planName: 'Gold',
          description: 'Comprehensive management with project scaling',
          price: is6Months
              ? _formatPrice((_goldProjectsCount * 599.4).round())
              : isYearly
              ? _formatPrice((_goldProjectsCount * 1198.8).round())
              : _formatPrice((_goldProjectsCount * 99.9).round()),
          originalPrice: is6Months
              ? _formatPrice((_goldProjectsCount * 899.4).round())
              : isYearly
              ? _formatPrice((_goldProjectsCount * 1798.8).round())
              : _formatPrice((_goldProjectsCount * 149.9).round()),
          features: [
            'Up to $_goldProjectsCount Projects & Active Sites',
            'Up to ${(_goldProjectsCount / 2).round().clamp(2, 25)} Managers',
            'Up to $_goldProjectsCount Supervisors',
            'Advanced collaboration & Site monitoring',
            'Expense tracking & Monthly report views',
          ],
        ),
        const SizedBox(height: 18),
        _buildPlanCard(
          isDesktop: isDesktop,
          planName: 'Platinum',
          description: 'For enterprise scale & unlimited access',
          price: is6Months
              ? '₹10,794'
              : isYearly
              ? '₹21,588'
              : '₹1,799',
          originalPrice: is6Months
              ? '₹14,994'
              : isYearly
              ? '₹29,988'
              : '₹2,499',
          features: const [
            'Medium & Large teams (up to 20)',
            'Advanced collaboration & Workflows',
            'Real-time site monitoring & Live logs',
            'Comprehensive expense tracking & Audits',
            'Custom monthly & annual reports',
          ],
        ),
      ],
    );
  }

  Widget _buildPlanCard({
    required bool isDesktop,
    required String planName,
    required String description,
    required String price,
    required String originalPrice,
    required List<String> features,
  }) {
    final isSelected = _selectedPlan == planName;
    final isFreeTrial = _selectedPlanType == 'Free Trial';
    final is6Months = _selectedPlanType == '6 Months';
    final isYearly = _selectedPlanType == 'Yearly';
    final Color darkNavy = AppTheme.getDarkAccent(widget.selectedColor);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPlan = planName;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(isDesktop ? 24.0 : 20.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? darkNavy : const Color(0xFFD4E3F4),
            width: isSelected ? 2.2 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? darkNavy.withValues(alpha: 0.18)
                  : darkNavy.withValues(alpha: 0.05),
              blurRadius: isSelected ? 20 : 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Radio Selector Badge
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? darkNavy : const Color(0xFFCBD5E1),
                            width: 2.0,
                          ),
                          color: isSelected ? darkNavy : Colors.transparent,
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.circle,
                                size: 10,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              planName,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0A183D),
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              description,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF5A759E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0A183D),
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (originalPrice.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        originalPrice,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF94A3B8),
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      isFreeTrial
                          ? '14-day trial'
                          : is6Months
                          ? 'Per 6 months'
                          : isYearly
                          ? 'Per year'
                          : 'Per month',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5A759E),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: isSelected
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        const Divider(color: Color(0xFFE2E8F0), height: 1),
                        const SizedBox(height: 16),

                        if (planName == 'Gold') ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Select Projects Limit',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5,
                                  color: Color(0xFF0A183D),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEBF5FF),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF90CAF9),
                                    width: 1.0,
                                  ),
                                ),
                                child: const Text(
                                  '₹99.9 / project',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11.5,
                                    color: Color(0xFF1E88E5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Horizontal Stepper Row & Count Display
                          Row(
                            children: [
                              // Minus Button
                              GestureDetector(
                                onTap: () {
                                  if (_goldProjectsCount > 5) {
                                    setState(() {
                                      _goldProjectsCount--;
                                    });
                                  }
                                },
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: _goldProjectsCount > 5
                                        ? darkNavy
                                        : const Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.remove,
                                    color: _goldProjectsCount > 5
                                        ? Colors.white
                                        : const Color(0xFF94A3B8),
                                    size: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Active Project Display Badge
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: darkNavy,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: darkNavy.withValues(alpha: 0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$_goldProjectsCount Projects Limit',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Plus Button
                              GestureDetector(
                                onTap: () {
                                  if (_goldProjectsCount < 50) {
                                    setState(() {
                                      _goldProjectsCount++;
                                    });
                                  }
                                },
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: _goldProjectsCount < 50
                                        ? darkNavy
                                        : const Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.add,
                                    color: _goldProjectsCount < 50
                                        ? Colors.white
                                        : const Color(0xFF94A3B8),
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Single Line Horizontal Scrollable Preset Chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: [5, 10, 15, 20, 25, 30, 40, 50].map((presetCount) {
                                final isChipSelected = _goldProjectsCount == presetCount;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _goldProjectsCount = presetCount;
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isChipSelected
                                            ? darkNavy
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isChipSelected
                                              ? darkNavy
                                              : const Color(0xFFD4E3F4),
                                          width: isChipSelected ? 1.8 : 1.2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: isChipSelected
                                                ? darkNavy.withValues(alpha: 0.2)
                                                : darkNavy.withValues(alpha: 0.04),
                                            blurRadius: isChipSelected ? 8 : 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        '$presetCount Sites',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: isChipSelected
                                              ? FontWeight.w800
                                              : FontWeight.w700,
                                          color: isChipSelected
                                              ? Colors.white
                                              : const Color(0xFF0A183D),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        if (features.isNotEmpty) ...[
                          ...features.map((feature) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFEBF5FF),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check_circle_rounded,
                                      size: 18,
                                      color: Color(0xFF1E88E5),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      feature,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0A183D),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],

                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: darkNavy,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18.0),
                              elevation: 4,
                              shadowColor: darkNavy.withValues(alpha: 0.3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 22.0,
                                    width: 22.0,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    isFreeTrial
                                        ? 'Start Free Trial'
                                        : 'Upgrade to $planName',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15.0,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: GestureDetector(
                            onTap: () {
                              TermsHelper.showTermsDialog(
                                context,
                                onAccepted: () {},
                                readOnly: true,
                              );
                            },
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 12.0,
                                  color: Color(0xFF5A759E),
                                ),
                                children: [
                                  TextSpan(
                                    text: isFreeTrial
                                        ? 'By starting the trial, you agree to our '
                                        : 'By upgrading, you agree to our ',
                                  ),
                                  const TextSpan(
                                    text: 'Terms & Conditions & Refund Policy',
                                    style: TextStyle(
                                      color: Color(0xFF0A183D),
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
