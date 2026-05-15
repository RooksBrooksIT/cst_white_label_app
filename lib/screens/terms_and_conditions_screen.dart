import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:demo_cst/services/auth_service.dart';
import 'package:demo_cst/services/location_service.dart';
import 'package:demo_cst/screens/Organization_Dashboard.dart';
import 'package:demo_cst/screens/config_account_dashboard.dart';
import 'package:demo_cst/screens/supervisor_dashboard.dart';
import 'package:demo_cst/screens/customer_dashboard.dart';
import 'package:demo_cst/screens/contractor_entry_page.dart';
import 'package:demo_cst/screens/org_subscription_page.dart';

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
          Navigator.pushReplacementNamed(context, '/landing');
      }
    } else {
      Navigator.pushReplacementNamed(context, '/landing');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms and Conditions'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: const SingleChildScrollView(
                        child: Text(
                          '''Terms and Conditions for eBicks App

Effective Date: [Insert Date]

1. Introduction

Welcome to the eBicks App (“App”), operated by Rooks and Brooks Technologies Pvt Ltd (“Company”, “we”, “our”, “us”).
These Terms and Conditions (“Terms”) govern your use of the App and its services.

By accessing or using the App, you agree to comply with these Terms. If you do not agree, please do not use the App.

2. Definitions
“App” refers to eBicks App.
“User” refers to any authorized individual using the App.
“Organization Owner” refers to the primary account holder with full administrative control.
“Manager” refers to users assigned management-level access by the Organization Owner.
“Supervisor” refers to users responsible for monitoring operations and reporting.
“Customer” refers to end-users or clients associated with the organization.
“Services” refers to all features, functionalities, and content provided through the App.
3. Eligibility
Access to the App is restricted to authorized users only.
Accounts are created and assigned by the Organization Owner or authorized personnel.
Public self-registration may be restricted or subject to approval.
4. User Roles and Responsibilities
4.1 Organization Owner
Full control over the organization account
Can create, modify, or delete Manager, Supervisor, and Customer accounts
Responsible for overall data accuracy and compliance
4.2 Manager
Manages operational activities within the App
Oversees Supervisors and Customers as permitted
Ensures proper usage within assigned scope
4.3 Supervisor
Monitors day-to-day activities
Updates records, reports, and operational data
Reports to Manager or Organization Owner
4.4 Customer
Can access limited features provided by the organization
Must not attempt to access restricted areas
5. Account Responsibility
Users must maintain confidentiality of login credentials.
The Organization Owner is responsible for all activities under their organization.
Unauthorized access must be reported immediately.
6. Acceptable Use

Users agree not to:

Use the App for unlawful purposes
Attempt unauthorized access to systems or data
Interfere with the App’s functionality or security
7. Data and Privacy
Data is handled in accordance with our Privacy Policy.
Organizations retain ownership of their operational data.
We implement reasonable security measures to protect information.
8. Intellectual Property
All rights, including software, design, and content, belong to Rooks and Brooks Technologies Pvt Ltd.
Users are granted a limited, non-transferable license for business use only.
9. Service Availability
We strive for continuous service but do not guarantee uninterrupted availability.
Maintenance or technical issues may cause downtime.
10. Limitation of Liability
We are not liable for indirect or consequential damages.
Use of the App is at your own risk.
11. Termination
We may suspend or terminate access for violation of these Terms.
Organization Owners may remove users within their organization.
12. Changes to Terms
These Terms may be updated periodically.
Continued use indicates acceptance of the revised Terms.
13. Governing Law
These Terms shall be governed by the laws of India.
14. Subscription and Billing
The application follows a subscription-based billing model. Each plan (Silver, Gold, Platinum) provides different features.
Payments are securely processed via ICICI Bank Payment Gateway. No sensitive payment details are stored on our servers.
Subscriptions are non-transferable between organizations.
Each organization’s data is strictly isolated and securely maintained.

15. Refund Policy
Refunds (if applicable) are processed within 5–7 working days based on company policy.

16. Contact Information

For any questions or concerns:
Company: Rooks and Brooks Technologies Pvt Ltd
Email: support@rookstechnologies.com''',
                          textAlign: TextAlign.justify,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: _isAccepted
                          ? Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isAccepted
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                      ),
                    ),
                    child: CheckboxListTile(
                      value: _isAccepted,
                      onChanged: (value) {
                        setState(() {
                          _isAccepted = value ?? false;
                        });
                      },
                      title: const Text(
                        'I have read and agree to the Terms and Conditions',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      activeColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isAccepted ? _onAccept : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[300],
                        disabledForegroundColor: Colors.grey[600],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: _isAccepted ? 2 : 0,
                      ),
                      child: const Text(
                        'Accept & Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
    );
  }
}
