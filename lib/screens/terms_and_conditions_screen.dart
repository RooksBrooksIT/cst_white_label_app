import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:demo_cst/services/auth_service.dart';
import 'package:demo_cst/services/location_service.dart';
import 'package:demo_cst/screens/Organization_Dashboard.dart';
import 'package:demo_cst/screens/config_account_dashboard.dart';
import 'package:demo_cst/screens/supervisor_dashboard.dart';
import 'package:demo_cst/screens/customer_dashboard.dart';
import 'package:demo_cst/screens/contractor_entry_page.dart';
import 'package:demo_cst/screens/org_subscription_page.dart';
import 'package:demo_cst/screens/landing_page.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';

class TermsAndConditionsScreen extends StatefulWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  State<TermsAndConditionsScreen> createState() =>
      _TermsAndConditionsScreenState();
}

class _TermsAndConditionsScreenState extends State<TermsAndConditionsScreen> {
  bool _isAccepted = false;
  bool _isLoading = false;

  Future<void> _onAccept() async {
    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_accepted_terms', true);

    if (!mounted) return;

    // Request location permissions after accepting terms
    await LocationService.handleLocationPermission(context);

    if (!mounted) return;

    final auth = AuthService();
    if (auth.isLoggedIn) {
      final data = auth.userData;
      switch (auth.userRole) {
        case UserRole.organization:
          final isSubscriptionValid = await auth.checkSubscriptionStatus();
          if (!mounted) return;
          if (isSubscriptionValid) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const OrganizationDashboard(),
              ),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const OrganizationSubscriptionPage(),
              ),
            );
          }
          break;
        case UserRole.manager:
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const ConfigAccountDashboard(),
            ),
          );
          break;
        case UserRole.supervisor:
          final isContractor = data['isContractor'] ?? false;
          if (isContractor) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ContractorEntryPage(
                  userName: data['username'] ?? '',
                  userDetails: {
                    'supervisorId': data['supervisorId'] ?? '',
                    'contractorName': data['contractorName'] ?? '',
                    'contractorField': data['contractorField'] ?? '',
                  },
                ),
              ),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => SupervisorDashboard(
                  supervisorId: data['supervisorId'] ?? '',
                  supervisorName: data['supervisorName'] ?? '',
                  username: data['username'] ?? '',
                ),
              ),
            );
          }
          break;
        case UserRole.customer:
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => CustomerDashboardPage(
                ownerName: data['ownerName'] ?? '',
                ownerPhoneNumber: '',
                siteId: data['siteId'] ?? '',
              ),
            ),
          );
          break;
        default:
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LandingPage()),
          );
      }
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LandingPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassScaffold(
      title: 'Terms and Conditions',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Text(
                        '''Terms and Conditions for eBicks App

Effective Date: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}

1. Acceptance of Terms
By accessing or using the eBicks App, you agree to comply with and be bound by these Terms and Conditions.

2. Account Security
You are responsible for maintaining the confidentiality of your account credentials and for all activities that occur under your account.

3. Authorized Use
The App is intended for professional use by authorized personnel. You agree not to misuse the App or attempt unauthorized access to any part of the system.

4. Data Privacy
We value your privacy. Data collected is used solely for providing and improving our services. Please refer to our Privacy Policy for more details.

5. Subscription & Payments
Access to features depends on your organization's subscription plan. All payments are processed securely, and no sensitive payment details are stored on our servers.

6. Limitation of Liability
Rooks and Brooks Technologies Pvt Ltd is not liable for any indirect, incidental, or consequential damages resulting from the use of this App.

7. Service Availability
We aim for maximum uptime but do not guarantee uninterrupted access. Maintenance may be performed periodically.

8. Termination
We reserve the right to terminate or suspend access for violations of these Terms or for security reasons.

9. Contact Support
For any queries, please reach out to us at support@rookstechnologies.com.''',
                        textAlign: TextAlign.justify,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 15,
                          height: 1.6,
                          color: theme.colorScheme.onSurface.withOpacity(0.85),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: _isAccepted
                        ? theme.colorScheme.primary.withOpacity(0.08)
                        : theme.cardColor.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isAccepted
                          ? theme.colorScheme.primary
                          : theme.dividerColor.withOpacity(0.1),
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: CheckboxListTile(
                      value: _isAccepted,
                      onChanged: (value) {
                        setState(() {
                          _isAccepted = value ?? false;
                        });
                      },
                      title: Text(
                        'I have read and agree to the Terms and Conditions',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      activeColor: theme.colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isAccepted ? _onAccept : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: theme.dividerColor.withOpacity(
                        0.1,
                      ),
                      disabledForegroundColor: theme.disabledColor,
                      elevation: _isAccepted ? 4 : 0,
                      shadowColor: theme.colorScheme.primary.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Accept & Continue',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
    );
  }
}
