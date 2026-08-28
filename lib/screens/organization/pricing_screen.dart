import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/services/auth_service.dart';
import 'package:demo_cst/utils/terms_helper.dart';
import 'package:demo_cst/services/payu_service.dart';
import 'package:demo_cst/screens/organization/payu_checkout_screen.dart';
import 'package:demo_cst/screens/organization/organization_dashboard.dart';
import 'package:demo_cst/screens/common/contact_support_screen.dart';
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
  final String? currentPlan;
  final bool isManagingExisting;

  const PricingScreen({
    super.key,
    this.orgName = '',
    this.email = '',
    this.phone = '',
    this.username = '',
    this.password = '',
    this.dateStr = '',
    this.appName = '',
    this.selectedColor = const Color(0xFF0B1942),
    this.currentPlan,
    this.isManagingExisting = false,
  });

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  bool _isLoading = false;
  String _selectedPlanType = 'Monthly';
  String _selectedPlan = 'Silver';
  int _platinumProjectsCount = 10;
  bool _queueUpgrade = false;

  static const List<String> _plans = [
    'Free Trial',
    'Silver',
    'Gold',
    'Platinum',
    'Enterprise',
  ];

  late PageController _planPageController;
  final ScrollController _mainTabsScrollController = ScrollController();
  final ScrollController _platinumPresetsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.currentPlan != null && widget.currentPlan!.isNotEmpty) {
      final normalized = widget.currentPlan!.trim().toLowerCase();
      if (normalized.contains('gold')) {
        _selectedPlan = 'Gold';
      } else if (normalized.contains('platinum')) {
        _selectedPlan = 'Platinum';
      } else if (normalized.contains('enterprise')) {
        _selectedPlan = 'Enterprise';
      } else if (normalized.contains('free')) {
        _selectedPlan = 'Free Trial';
        _selectedPlanType = 'Free Trial';
      } else {
        _selectedPlan = 'Silver';
      }
    }

    final initialIndex = _plans.indexOf(_selectedPlan);
    _planPageController = PageController(
      initialPage: initialIndex >= 0 ? initialIndex : 1,
    );
  }

  @override
  void dispose() {
    _planPageController.dispose();
    _mainTabsScrollController.dispose();
    _platinumPresetsScrollController.dispose();
    super.dispose();
  }

  int _getMaxProjectsForPlan(String plan, int platinumCount) {
    switch (plan) {
      case 'Enterprise':
        return 999999;
      case 'Platinum':
        return platinumCount;
      case 'Gold':
        return 10;
      case 'Silver':
        return 3;
      case 'Free Trial':
      default:
        return 1;
    }
  }

  int _getMaxUsersForPlan(String plan, int platinumCount) {
    switch (plan) {
      case 'Enterprise':
        return 999999;
      case 'Platinum':
        return (platinumCount * 1.5).round();
      case 'Gold':
        return 15;
      case 'Silver':
        return 5;
      case 'Free Trial':
      default:
        return 2;
    }
  }

  int _getMaxManagersForPlan(String plan, int platinumCount) {
    switch (plan) {
      case 'Enterprise':
        return 999999;
      case 'Platinum':
        return (platinumCount / 2).round().clamp(2, 25);
      case 'Gold':
        return 5;
      case 'Silver':
        return 2;
      case 'Free Trial':
      default:
        return 1;
    }
  }

  int _getMaxSupervisorsForPlan(String plan, int platinumCount) {
    switch (plan) {
      case 'Enterprise':
        return 999999;
      case 'Platinum':
        return platinumCount;
      case 'Gold':
        return 10;
      case 'Silver':
        return 3;
      case 'Free Trial':
      default:
        return 1;
    }
  }

  double _calculatePlanAmount() {
    if (_selectedPlanType == 'Free Trial' || _selectedPlan == 'Free Trial') return 0.0;

    if (_selectedPlan == 'Silver') {
      if (_selectedPlanType == '6 Months') return 594.0;
      if (_selectedPlanType == 'Yearly') return 1188.0;
      return 99.0;
    } else if (_selectedPlan == 'Gold') {
      if (_selectedPlanType == '6 Months') return 1194.0;
      if (_selectedPlanType == 'Yearly') return 2388.0;
      return 199.0;
    } else if (_selectedPlan == 'Platinum') {
      if (_selectedPlanType == '6 Months') {
        return (_platinumProjectsCount * 239.40).roundToDouble();
      }
      if (_selectedPlanType == 'Yearly') {
        return (_platinumProjectsCount * 478.80).roundToDouble();
      }
      return (_platinumProjectsCount * 39.90).roundToDouble();
    }
    return 0.0;
  }

  String _formatPrice(int price) {
    final format = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return '₹${price.toString().replaceAllMapped(format, (Match m) => '${m[1]},')}';
  }

  Future<void> _handleExistingPlanUpdate() async {
    final formattedCurrent = (widget.currentPlan ?? '').trim().toLowerCase();
    final bool isCurrentPlan = formattedCurrent.isNotEmpty &&
        (formattedCurrent == _selectedPlan.toLowerCase() ||
            (formattedCurrent.contains('free') &&
                _selectedPlan.toLowerCase().contains('free')));

    if (isCurrentPlan) {
      AppTheme.showSuccessToast(
          context, 'You are currently on the $_selectedPlan plan.');
      return;
    }

    final double amount = _calculatePlanAmount();
    PayUResult? payuResult;

    if (_selectedPlan != 'Free Trial' && _selectedPlanType != 'Free Trial' && amount > 0) {
      final txnId = PayUService.generateTxnId();
      final payUParams = PayUParams(
        merchantId: PayUService.activeMerchantId,
        merchantKey: PayUService.activeMerchantKey,
        merchantSalt: PayUService.activeMerchantSalt,
        txnid: txnId,
        amount: amount,
        productInfo:
            '${widget.orgName.isEmpty ? "Subscription" : widget.orgName} $_selectedPlan Plan ($_selectedPlanType)',
        firstName: widget.orgName.isEmpty
            ? (widget.username.isEmpty ? 'Organization' : widget.username)
            : widget.orgName,
        email: widget.email.isEmpty ? 'customer@example.com' : widget.email,
        phone: widget.phone.isEmpty ? '9999999999' : widget.phone,
        isSandbox: !PayUService.isProduction,
        pg: 'CC',
        bankcode: 'CC',
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
      final now = DateTime.now();
      final int durationDays;
      if (_selectedPlan == 'Free Trial' || _selectedPlanType == 'Free Trial') {
        durationDays = 14;
      } else if (_selectedPlanType == '6 Months') {
        durationDays = 180;
      } else if (_selectedPlanType == 'Yearly') {
        durationDays = 365;
      } else {
        durationDays = 30;
      }

      final maxProjects = _getMaxProjectsForPlan(_selectedPlan, _platinumProjectsCount);
      final maxUsers = _getMaxUsersForPlan(_selectedPlan, _platinumProjectsCount);
      final maxManagers = _getMaxManagersForPlan(_selectedPlan, _platinumProjectsCount);
      final maxSupervisors = _getMaxSupervisorsForPlan(_selectedPlan, _platinumProjectsCount);

      if (_queueUpgrade) {
        var currentDoc = await FirestoreService.subscriptionDoc.get();
        DateTime queueStartDate = now;
        if (currentDoc.exists) {
          final data = currentDoc.data()!;
          final currentEnd = data['subscriptionEndDate'] as Timestamp?;
          if (currentEnd != null && currentEnd.toDate().isAfter(now)) {
            queueStartDate = currentEnd.toDate();
          }
        }
        final queueEndDate = queueStartDate.add(Duration(days: durationDays));

        final updateData = {
          'isUpgradeQueued': true,
          'queuedPlan': _selectedPlan,
          'queuedPlanType': _selectedPlanType,
          'queuedStartDate': Timestamp.fromDate(queueStartDate),
          'queuedEndDate': Timestamp.fromDate(queueEndDate),
          'queuedMaxProjects': maxProjects,
          'queuedMaxUsers': maxUsers,
          'queuedMaxManagers': maxManagers,
          'queuedMaxSupervisors': maxSupervisors,
          'queuedPaymentTxnId': payuResult?.txnid ?? '',
          'queuedPaymentAmount': amount,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        await FirestoreService.subscriptionDoc
            .set(updateData, SetOptions(merge: true));

        if (mounted) {
          setState(() => _isLoading = false);
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.schedule_send_rounded,
                      color: Color(0xFF10B981), size: 28),
                  SizedBox(width: 10),
                  Text('Upgrade Queued',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: Text(
                'Your upgrade to the $_selectedPlan plan ($_selectedPlanType) has been queued successfully. It will automatically activate on ${DateFormat('dd MMM yyyy').format(queueStartDate)}.',
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B1942),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('OK',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
      } else {
        final startDate = now;
        final endDate = startDate.add(Duration(days: durationDays));

        final updateData = <String, dynamic>{
          'subscriptionPlan': _selectedPlan,
          'subscriptionType': _selectedPlanType,
          'subscriptionStartDate': Timestamp.fromDate(startDate),
          'subscriptionEndDate': Timestamp.fromDate(endDate),
          'isSubscriptionActive': true,
          'isUpgradeQueued': false,
          'queuedPlan': FieldValue.delete(),
          'queuedPlanType': FieldValue.delete(),
          'queuedStartDate': FieldValue.delete(),
          'queuedEndDate': FieldValue.delete(),
          'queuedMaxProjects': FieldValue.delete(),
          'queuedMaxUsers': FieldValue.delete(),
          'queuedMaxManagers': FieldValue.delete(),
          'queuedMaxSupervisors': FieldValue.delete(),
          'maxProjects': maxProjects,
          'maxUsers': maxUsers,
          'maxManagers': maxManagers,
          'maxSupervisors': maxSupervisors,
          'paymentGateway': payuResult != null ? 'PayU' : 'Direct',
          'paymentTxnId': payuResult?.txnid ?? '',
          'paymentAmount': amount,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        await FirestoreService.subscriptionDoc
            .set(updateData, SetOptions(merge: true));

        if (mounted) {
          setState(() => _isLoading = false);
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.stars_rounded,
                      color: Color(0xFF10B981), size: 28),
                  SizedBox(width: 10),
                  Text('Plan Upgraded!',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: Text(
                'Congratulations! Your subscription has been upgraded to the $_selectedPlan plan ($_selectedPlanType) immediately.',
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B1942),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('OK',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating subscription plan: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        AppTheme.showErrorToast(context, 'Failed to update subscription: $e');
      }
    }
  }

  Future<void> _register() async {
    final double amount = _calculatePlanAmount();
    PayUResult? payuResult;
    // Handle PayU Payment Gateway for Paid Plans
    if (_selectedPlan != 'Free Trial' && _selectedPlanType != 'Free Trial' && amount > 0) {
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
        pg: 'CC',
        bankcode: 'CC',
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
            result?.errorMessage ?? 'Payment was cancelled or failed. Please try again.',
          );
        }
        return;
      }

      payuResult = result;
    }

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final orgId = '${widget.orgName.replaceAll(' ', '')}_${DateFormat('dd-MM-yyyy').format(now)}';
      final orgConfigDocPath = 'organisations/$orgId';

      final subscriptionStartDate = now;
      final int durationDays;
      if (_selectedPlan == 'Free Trial' || _selectedPlanType == 'Free Trial') {
        durationDays = 14;
      } else if (_selectedPlanType == '6 Months') {
        durationDays = 180;
      } else if (_selectedPlanType == 'Yearly') {
        durationDays = 365;
      } else {
        durationDays = 30;
      }
      final subscriptionEndDate = subscriptionStartDate.add(Duration(days: durationDays));

      final maxProjects = _getMaxProjectsForPlan(_selectedPlan, _platinumProjectsCount);
      final maxUsers = _getMaxUsersForPlan(_selectedPlan, _platinumProjectsCount);
      final maxManagers = _getMaxManagersForPlan(_selectedPlan, _platinumProjectsCount);
      final maxSupervisors = _getMaxSupervisorsForPlan(_selectedPlan, _platinumProjectsCount);

      final rootDocData = {
        'org_name': widget.orgName,
        'app_name': widget.appName,
        'theme_color': '#${widget.selectedColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
        'created_at': FieldValue.serverTimestamp(),
        'subscriptionPlan': _selectedPlan,
        'subscriptionType': _selectedPlanType,
        'subscriptionStartDate': Timestamp.fromDate(subscriptionStartDate),
        'subscriptionEndDate': Timestamp.fromDate(subscriptionEndDate),
        'isSubscriptionActive': true,
        'maxProjects': maxProjects,
        'maxUsers': maxUsers,
        'maxManagers': maxManagers,
        'maxSupervisors': maxSupervisors,
        'paymentGateway': payuResult != null ? 'PayU' : 'None',
        'paymentTxnId': payuResult?.txnid ?? '',
        'paymentAmount': amount,
      };

      await FirebaseFirestore.instance.doc(orgConfigDocPath).set(rootDocData, SetOptions(merge: true));

      final adminDocData = {
        'subscriptionPlan': _selectedPlan,
        'subscriptionType': _selectedPlanType,
        'subscriptionStartDate': Timestamp.fromDate(subscriptionStartDate),
        'subscriptionEndDate': Timestamp.fromDate(subscriptionEndDate),
        'isSubscriptionActive': true,
        'maxProjects': maxProjects,
        'maxUsers': maxUsers,
        'maxManagers': maxManagers,
        'maxSupervisors': maxSupervisors,
        'paymentGateway': payuResult != null ? 'PayU' : 'None',
        'paymentTxnId': payuResult?.txnid ?? '',
        'paymentAmount': amount,
        'created_at': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .doc(orgConfigDocPath)
          .collection('admin')
          .doc('subscription')
          .set(adminDocData, SetOptions(merge: true));

      final masterConfigData = {
        'org_name': widget.orgName,
        'app_name': widget.appName,
        'theme_color': '#${widget.selectedColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
        'email': widget.email,
        'phone': widget.phone,
        'created_at': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .doc(orgConfigDocPath)
          .collection('admin')
          .doc('masterConfig')
          .set(masterConfigData, SetOptions(merge: true));

      final userData = {
        'org_name': widget.orgName,
        'email': widget.email,
        'phone': widget.phone,
        'username': widget.username,
        'password': widget.password,
        'role': 'Organization',
        'created_at': FieldValue.serverTimestamp(),
      };

      if (widget.phone.isNotEmpty) {
        await FirebaseFirestore.instance
            .doc(orgConfigDocPath)
            .collection('organizationUser')
            .doc(widget.phone)
            .set(userData)
            .catchError((_) {});
      } else {
        await FirebaseFirestore.instance
            .doc(orgConfigDocPath)
            .collection('organizationUser')
            .doc(widget.username.isEmpty ? 'admin' : widget.username)
            .set(userData)
            .catchError((_) {});
      }

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

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const OrganizationDashboard()),
          (route) => false,
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
                maxWidth: isMobile ? double.infinity : 600,
              ),
              child: Column(
                children: [
                  // ── Top Header Section (Fixed at top) ──────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Back Button & Title
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
                            Text(
                              widget.isManagingExisting
                                  ? 'Manage Subscription Plan'
                                  : 'Choose Your Plan',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0A183D),
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(width: 40),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Registration Step Indicator
                        if (!widget.isManagingExisting) ...[
                          _buildStepIndicator(isDesktop),
                          const SizedBox(height: 12),
                        ],

                        // Main Plan Tabs (Level 1 Plan Selector)
                        _buildMainPlanTabs(),
                      ],
                    ),
                  ),

                  // ── Swipeable Plan Cards PageView ─────────────────────────
                  Expanded(
                    child: PageView.builder(
                      controller: _planPageController,
                      itemCount: _plans.length,
                      onPageChanged: (index) {
                        setState(() {
                          _selectedPlan = _plans[index];
                          if (_selectedPlan == 'Free Trial') {
                            _selectedPlanType = 'Free Trial';
                          } else if (_selectedPlanType == 'Free Trial') {
                            _selectedPlanType = 'Monthly';
                          }
                        });
                      },
                      itemBuilder: (context, index) {
                        final plan = _plans[index];
                        return SingleChildScrollView(
                          primary: false,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                          child: _buildPlanCardForPlan(plan, isDesktop),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(bool isDesktop) {
    const steps = ['Details', 'Branding', 'Pricing'];
    const activeStep = 2;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B1942).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
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
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone || isActive
                        ? const Color(0xFF0B1942)
                        : const Color(0xFFE2E8F0),
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(Icons.check, color: Colors.white, size: 14)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isActive ? Colors.white : const Color(0xFF0A183D),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  steps[index],
                  style: const TextStyle(
                    color: Color(0xFF0A183D),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (index < steps.length - 1)
                  Flexible(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 40.0, minWidth: 12.0),
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      color: activeStep > index
                          ? const Color(0xFF0B1942)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  /// Level 1 Main Plan Tabs Switcher
  Widget _buildMainPlanTabs() {
    final Color darkNavy = AppTheme.getDarkAccent(widget.selectedColor);
    final String formattedCurrent = (widget.currentPlan ?? '').trim().toLowerCase();

    return SingleChildScrollView(
      controller: _mainTabsScrollController,
      primary: false,
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _plans.map((planName) {
          final isSelected = _selectedPlan == planName;
          final isCurrentPlan = formattedCurrent.isNotEmpty &&
              (formattedCurrent == planName.toLowerCase() ||
                  (formattedCurrent.contains('free') &&
                      planName.toLowerCase().contains('free')));

          String? badgeText;
          if (planName == 'Gold') badgeText = '★ Expert';
          if (planName == 'Platinum') badgeText = '⚡ Scale';
          if (planName == 'Enterprise') badgeText = '🏢 Team';

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: () {
                final targetIndex = _plans.indexOf(planName);
                if (targetIndex >= 0) {
                  _planPageController.animateToPage(
                    targetIndex,
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeInOut,
                  );
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? darkNavy : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? darkNavy
                        : (isCurrentPlan ? const Color(0xFF10B981) : const Color(0xFFE2E8F0)),
                    width: isSelected ? 1.8 : 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected
                          ? darkNavy.withValues(alpha: 0.22)
                          : const Color(0xFF0F172A).withValues(alpha: 0.04),
                      blurRadius: isSelected ? 8 : 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isCurrentPlan) ...[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF10B981) : const Color(0xFF047857),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      planName,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                        color: isSelected ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (badgeText != null) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.2)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: isSelected ? Colors.white : const Color(0xFF2563EB),
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

  /// Build card for the active plan in the PageView
  Widget _buildPlanCardForPlan(String planName, bool isDesktop) {
    final is6Months = _selectedPlanType == '6 Months';
    final isYearly = _selectedPlanType == 'Yearly';

    switch (planName) {
      case 'Free Trial':
        return _buildPlanCard(
          isDesktop: isDesktop,
          planName: 'Free Trial',
          badgeText: '14-Day Free Access',
          badgeColor: const Color(0xFF0284C7),
          description: 'Experience full workspace capabilities at zero cost',
          price: 'Free',
          originalPrice: '',
          cadenceText: '14-day trial duration',
          billingNote: 'No credit card required to start',
          showBillingTabs: false,
          features: const [
            'Basic Project Management',
            'Layout & Drawings (1 doc/site, view only)',
            'Task Tracking & Updates',
            'Limited Team Members (up to 2)',
            'Basic Reports & Analytics',
            'Standard Cloud Storage',
          ],
        );

      case 'Silver':
        return _buildPlanCard(
          isDesktop: isDesktop,
          planName: 'Silver',
          badgeText: 'Starter',
          badgeColor: const Color(0xFF64748B),
          description: 'For small teams & independent contractors starting out',
          price: is6Months ? '₹594' : isYearly ? '₹1,188' : '₹99',
          originalPrice: is6Months ? '₹894' : isYearly ? '₹1,788' : '₹149',
          cadenceText: is6Months
              ? 'Billed every 6 months'
              : isYearly
                  ? 'Billed annually (Save 33%)'
                  : 'Billed monthly',
          billingNote: isYearly ? '₹99/mo effective rate' : null,
          showBillingTabs: true,
          features: const [
            'Basic Project Management',
            'Layout & Drawings (1 doc/site, view only)',
            'Task Tracking & Updates',
            'Limited Team Members (3-5)',
            'Basic Reports & Data View',
            'Standard Cloud Backup & Sync',
          ],
        );

      case 'Gold':
        return _buildPlanCard(
          isDesktop: isDesktop,
          planName: 'Gold',
          badgeText: 'Expert Choice',
          badgeColor: const Color(0xFF2563EB),
          description: 'Comprehensive management with fixed project quota',
          price: is6Months ? '₹1,194' : isYearly ? '₹2,388' : '₹199',
          originalPrice: is6Months ? '₹1,794' : isYearly ? '₹3,588' : '₹299',
          cadenceText: is6Months
              ? 'Billed every 6 months'
              : isYearly
                  ? 'Billed annually (Save 33%)'
                  : 'Billed monthly',
          billingNote: isYearly ? '₹199/mo effective rate' : null,
          showBillingTabs: true,
          features: const [
            'Up to 10 Projects & Active Sites',
            'Up to 5 Managers & 10 Supervisors',
            'Layout & Drawings (1 doc/site, 1 delete & re-upload)',
            'Advanced collaboration & Site monitoring',
            'Expense tracking & Monthly report views',
            'Role-based Access & Live Timeline',
            'Real-time Material Movement Logs',
          ],
        );

      case 'Platinum':
        return _buildPlanCard(
          isDesktop: isDesktop,
          planName: 'Platinum',
          badgeText: 'Custom Scale',
          badgeColor: const Color(0xFF7C3AED),
          description: 'For growing enterprises with customizable project limits',
          price: is6Months
              ? _formatPrice((_platinumProjectsCount * 239.4).round())
              : isYearly
                  ? _formatPrice((_platinumProjectsCount * 478.8).round())
                  : _formatPrice((_platinumProjectsCount * 39.9).round()),
          originalPrice: is6Months
              ? _formatPrice((_platinumProjectsCount * 359.4).round())
              : isYearly
                  ? _formatPrice((_platinumProjectsCount * 718.8).round())
                  : _formatPrice((_platinumProjectsCount * 59.9).round()),
          cadenceText: is6Months
              ? 'Billed per 6 months'
              : isYearly
                  ? 'Billed annually'
                  : 'Billed monthly',
          billingNote: 'Scalable at ₹39.9 / project / mo',
          showBillingTabs: true,
          features: [
            'Up to $_platinumProjectsCount Projects & Active Sites',
            'Up to ${(_platinumProjectsCount / 2).round().clamp(2, 25)} Managers',
            'Up to $_platinumProjectsCount Supervisors',
            'Layout & Drawings (Up to 2 active docs/site, multi-delete & re-upload)',
            'Advanced collaboration & Workflows',
            'Real-time site monitoring & Live logs',
            'Comprehensive expense tracking & Audits',
            'Priority cloud sync & audit logging',
          ],
        );

      case 'Enterprise':
      default:
        return _buildPlanCard(
          isDesktop: isDesktop,
          planName: 'Enterprise',
          badgeText: 'Team Plan',
          badgeColor: const Color(0xFF0D9488),
          description: 'Tailored architecture, unlimited sites & dedicated SLA',
          price: 'Custom',
          originalPrice: '',
          cadenceText: 'Custom annual contract',
          billingNote: 'Dedicated multi-org deployment',
          showBillingTabs: false,
          features: const [
            'Unlimited Projects & Active Sites',
            'Unlimited Managers & Supervisors',
            'Layout & Drawings (Up to 2 active docs/site, multi-delete & re-upload)',
            'Custom Cloud Infrastructure & Dedicated DB',
            '24/7 Priority SLA & Dedicated Account Manager',
            'Custom API Integrations & Webhooks',
            'Enterprise Security & Data Residency',
          ],
        );
    }
  }

  Widget _buildPlanCard({
    required bool isDesktop,
    required String planName,
    required String? badgeText,
    required Color? badgeColor,
    required String description,
    required String price,
    required String originalPrice,
    required String cadenceText,
    required String? billingNote,
    required bool showBillingTabs,
    required List<String> features,
  }) {
    final Color darkNavy = AppTheme.getDarkAccent(widget.selectedColor);
    final String formattedCurrent = (widget.currentPlan ?? '').trim().toLowerCase();
    final bool isCurrentPlan = formattedCurrent.isNotEmpty &&
        (formattedCurrent == planName.toLowerCase() ||
            (formattedCurrent.contains('free') &&
                planName.toLowerCase().contains('free')));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isCurrentPlan ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
          width: isCurrentPlan ? 2.0 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: darkNavy.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 22.0 : 18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Level 2: In-Card Billing Period Switcher (For Paid Plans) ──
            if (showBillingTabs) ...[
              _buildInCardBillingSwitcher(darkNavy),
              const SizedBox(height: 14),
            ],

            // ── Header Row: Title & Badges ───────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    planName,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: darkNavy,
                      letterSpacing: -0.4,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isCurrentPlan) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded, color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text(
                              'CURRENT PLAN',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (badgeText != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: (badgeColor ?? const Color(0xFF2563EB)).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (badgeColor ?? const Color(0xFF2563EB)).withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: badgeColor ?? const Color(0xFF2563EB),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Price Typography Row (Reference Style) ───────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  price,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: darkNavy,
                    letterSpacing: -0.8,
                  ),
                ),
                if (originalPrice.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    originalPrice,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF94A3B8),
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ],
                if (price != 'Custom' && price != 'Free') ...[
                  const SizedBox(width: 4),
                  const Text(
                    ' /month',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(
              cadenceText,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            if (billingNote != null) ...[
              const SizedBox(height: 1),
              Text(
                billingNote,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
            const SizedBox(height: 14),

            // ── Upgrade Timing Switcher (Immediate vs Queued) ──
            if (widget.isManagingExisting && !isCurrentPlan && planName != 'Enterprise' && planName != 'Free Trial') ...[
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _queueUpgrade = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: !_queueUpgrade ? darkNavy : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Center(
                            child: Text(
                              '⚡ Immediate',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: !_queueUpgrade ? Colors.white : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _queueUpgrade = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: _queueUpgrade ? darkNavy : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Center(
                            child: Text(
                              '⏳ Queue on Expiry',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: _queueUpgrade ? Colors.white : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── Direct CTA Action Button (Below Price, matching Ref Image) ──
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        if (planName == 'Enterprise') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ContactSupportScreen(),
                            ),
                          );
                          return;
                        }
                        if (widget.isManagingExisting) {
                          _handleExistingPlanUpdate();
                        } else {
                          _register();
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCurrentPlan
                      ? const Color(0xFF10B981)
                      : darkNavy,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shadowColor: darkNavy.withValues(alpha: 0.35),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20.0,
                        width: 20.0,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isCurrentPlan
                            ? '✓ CURRENT PLAN ACTIVE'
                            : (planName == 'Enterprise'
                                ? 'CONTACT ENTERPRISE SALES'
                                : (widget.isManagingExisting
                                    ? (_queueUpgrade
                                        ? 'QUEUE UPGRADE TO ${planName.toUpperCase()}'
                                        : 'UPGRADE TO ${planName.toUpperCase()}')
                                    : (planName == 'Free Trial'
                                        ? 'START FREE TRIAL'
                                        : 'UPGRADE TO ${planName.toUpperCase()}'))),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                          letterSpacing: 0.4,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFF1F5F9), height: 1),
            const SizedBox(height: 14),

            // ── Platinum Interactive Project Slider / Stepper ─────────────
            if (planName == 'Platinum') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Customize Site Limit',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '₹39.9 / site / mo',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Stepper Row
              Row(
                children: [
                  InkWell(
                    onTap: () {
                      if (_platinumProjectsCount > 5) {
                        setState(() => _platinumProjectsCount--);
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _platinumProjectsCount > 5 ? darkNavy : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.remove,
                        color: _platinumProjectsCount > 5 ? Colors.white : const Color(0xFF94A3B8),
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Center(
                        child: Text(
                          '$_platinumProjectsCount Sites Quota',
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      if (_platinumProjectsCount < 50) {
                        setState(() => _platinumProjectsCount++);
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _platinumProjectsCount < 50 ? darkNavy : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.add,
                        color: _platinumProjectsCount < 50 ? Colors.white : const Color(0xFF94A3B8),
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Preset Chips
              SingleChildScrollView(
                controller: _platinumPresetsScrollController,
                primary: false,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [5, 10, 15, 20, 25, 30, 40, 50].map((presetCount) {
                    final isChipSelected = _platinumProjectsCount == presetCount;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: InkWell(
                        onTap: () => setState(() => _platinumProjectsCount = presetCount),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isChipSelected ? darkNavy : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isChipSelected ? darkNavy : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Text(
                            '$presetCount Sites',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isChipSelected ? FontWeight.w800 : FontWeight.w700,
                              color: isChipSelected ? Colors.white : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ── Plan Description / Subtitle ──────────────────────────────
            Text(
              description,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 10),

            // ── Feature Checklist (Crisp Reference Typography) ───────────
            ...features.map((feature) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        feature,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

            // ── Queue Upgrade Checkbox for Existing Subscriptions ─────────
            if (widget.isManagingExisting && !isCurrentPlan && planName != 'Enterprise') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: _queueUpgrade
                      ? const Color(0xFF10B981).withValues(alpha: 0.08)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _queueUpgrade
                        ? const Color(0xFF10B981).withValues(alpha: 0.5)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: CheckboxListTile(
                  value: _queueUpgrade,
                  onChanged: (val) => setState(() => _queueUpgrade = val ?? false),
                  activeColor: const Color(0xFF10B981),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    'Queue Upgrade',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  subtitle: Text(
                    _queueUpgrade
                        ? 'New plan activates automatically after current plan ends.'
                        : 'Selected plan upgrade activates immediately.',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: _queueUpgrade ? const Color(0xFF047857) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 14),

            // ── Terms & Refund Policy Link ──────────────────────────────
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
                      fontSize: 11.5,
                      color: Color(0xFF64748B),
                    ),
                    children: [
                      TextSpan(
                        text: planName == 'Free Trial'
                            ? 'By starting the trial, you agree to our '
                            : 'By upgrading, you agree to our ',
                      ),
                      const TextSpan(
                        text: 'Terms & Conditions & Refund Policy',
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w800,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Level 2 In-Card Billing Duration Switcher (Monthly, 6 Months, Annual)
  Widget _buildInCardBillingSwitcher(Color darkNavy) {
    final billingOptions = [
      {'key': 'Monthly', 'label': 'Monthly', 'badge': null},
      {'key': '6 Months', 'label': '6 Months', 'badge': 'SAVE 20%'},
      {'key': 'Yearly', 'label': 'Annual', 'badge': 'SAVE 33%'},
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: billingOptions.map((opt) {
          final String key = opt['key'] as String;
          final String label = opt['label'] as String;
          final String? badge = opt['badge'];
          final isSelected = _selectedPlanType == key;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPlanType = key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                          color: isSelected ? darkNavy : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      height: 16,
                      child: badge != null
                          ? FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFFEF3C7)
                                      : const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  badge,
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                    color: isSelected
                                        ? const Color(0xFF92400E)
                                        : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
