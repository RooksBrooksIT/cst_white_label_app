import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_button.dart';
import '../utils/responsive.dart';
import '../utils/terms_helper.dart';

class OrganizationSubscriptionPage extends StatefulWidget {
  const OrganizationSubscriptionPage({super.key});

  @override
  State<OrganizationSubscriptionPage> createState() =>
      _OrganizationSubscriptionPageState();
}

class _OrganizationSubscriptionPageState
    extends State<OrganizationSubscriptionPage> {
  bool _isLoading = true;
  String _planName = 'Loading...';
  String _status = 'Loading...';
  String _expiryDate = 'Loading...';
  bool _isActive = false;

  @override
  void initState() {
    super.initState();
    _fetchSubscriptionData();
  }

  Future<void> _fetchSubscriptionData() async {
    try {
      var doc = await FirestoreService.subscriptionDoc.get();

      // Fallback: If admin/subscription doc doesn't exist, check root doc (legacy)
      if (!doc.exists) {
        debugPrint('OrganizationSubscriptionPage: Subscription doc not found in admin, falling back to root.');
        doc = await FirestoreService.rootOrgDoc.get();
      }

      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _planName = _formatPlanName(data['subscriptionPlan'] ?? 'Unknown');
          
          // Default to true if missing to avoid lockouts during trial/transition
          final isActiveField = data['isSubscriptionActive'] as bool? ?? true;
          final expiry = data['subscriptionEndDate'] as Timestamp?;
          
          bool isExpired = false;
          if (expiry != null) {
            isExpired = DateTime.now().isAfter(expiry.toDate());
            _expiryDate = DateFormat('dd MMM yyyy').format(expiry.toDate());
          } else {
            _expiryDate = 'Lifetime';
          }

          _isActive = isActiveField && !isExpired;
          _status = _isActive ? 'Active' : 'Inactive';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching subscription data: $e');
      if (mounted) {
        setState(() {
          _planName = 'Error';
          _status = 'Error';
          _expiryDate = 'Error';
          _isLoading = false;
        });
      }
    }
  }

  String _formatPlanName(String raw) {
    return raw
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) =>
              word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1),
        )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = Responsive.isMobile(context);

    return PopScope(
      canPop: _isActive,
      child: GlassScaffold(
        title: 'Manage Subscription',
        onBack: _isActive ? () => Navigator.pop(context) : null,
        body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
          child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildCurrentPlanCard(theme, colorScheme),
                    const SizedBox(height: 24),
                    _buildPlanDetailsSection(theme),
                    const SizedBox(height: 32),
                    _buildSupportSection(theme, colorScheme),
                    const SizedBox(height: 24),
                    Center(
                      child: TextButton(
                        onPressed: () {
                          TermsHelper.showTermsDialog(
                            context,
                            onAccepted: () {},
                            readOnly: true,
                          );
                        },
                        child: Text(
                          'View Terms & Conditions & Refund Policy',
                          style: TextStyle(
                            color: colorScheme.primary,
                            decoration: TextDecoration.underline,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
        ),
      ),
      ),
    );
  }

  Widget _buildCurrentPlanCard(ThemeData theme, ColorScheme colorScheme) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (_isActive ? Colors.green : Colors.orange).withOpacity(
                0.1,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isActive ? Icons.stars_rounded : Icons.warning_rounded,
              color: _isActive ? Colors.green : Colors.orange,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _planName,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: (_isActive ? Colors.green : Colors.orange).withOpacity(
                0.1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _status.toUpperCase(),
              style: TextStyle(
                color: _isActive ? Colors.green : Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          _buildInfoRow('Next Billing Date', _expiryDate, theme),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, ThemeData theme) {
    return Row(
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanDetailsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Plan Features',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildFeatureItem('Unlimited Projects & Sites', theme),
        const SizedBox(height: 12),
        _buildFeatureItem('Real-time Financial Tracking', theme),
        const SizedBox(height: 12),
        _buildFeatureItem('Dynamic Report Generation', theme),
        const SizedBox(height: 12),
        _buildFeatureItem('Custom Branding Tools', theme),
      ],
    );
  }

  Widget _buildFeatureItem(String text, ThemeData theme) {
    return Row(
      children: [
        Icon(
          Icons.check_circle_rounded,
          color: theme.colorScheme.primary,
          size: 20,
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildSupportSection(ThemeData theme, ColorScheme colorScheme) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            'Need to change your plan?',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Contact our support team to upgrade your subscription or manage billing details.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          GlassButton(
            label: 'CONTACT SUPPORT',
            onPressed: () {
              // Navigate to support screen if available
              Navigator.pushNamed(context, '/contactSupport');
            },
            isSecondary: true,
          ),
        ],
      ),
    );
  }
}
