import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ebricks/utils/app_theme.dart';

class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  static const String _email = 'support@rookstechnologies.com';
  static const String _phone = '+918925633099';
  static const String _phoneDisplay = '+91 89256 33099';
  static const String _whatsappNumber = '918925633099';

  Color get primaryColor => Theme.of(context).primaryColor;

  Future<void> _launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: _email,
      queryParameters: {'subject': 'CST App Support Request'},
    );
    try {
      if (!await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          _copyToClipboard(_email, 'Email address copied');
        }
      }
    } catch (_) {
      if (mounted) {
        _copyToClipboard(_email, 'Email address copied');
      }
    }
  }

  Future<void> _launchPhone() async {
    final Uri phoneLaunchUri = Uri(scheme: 'tel', path: _phone);
    try {
      if (!await launchUrl(phoneLaunchUri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          _copyToClipboard(_phoneDisplay, 'Phone number copied');
        }
      }
    } catch (_) {
      if (mounted) {
        _copyToClipboard(_phoneDisplay, 'Phone number copied');
      }
    }
  }

  Future<void> _launchWhatsApp() async {
    final url = Uri.parse(
      'https://wa.me/$_whatsappNumber?text=Hello%20Rooks%20Support%20Team,%20I%20need%20assistance%20with%20the%20CST%20App.',
    );
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          _copyToClipboard(_phoneDisplay, 'WhatsApp contact copied');
        }
      }
    } catch (_) {
      if (mounted) {
        _copyToClipboard(_phoneDisplay, 'WhatsApp contact copied');
      }
    }
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    AppTheme.showSuccessToast(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Contact & Customer Support',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
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
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isMobile ? double.infinity : 680,
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── 1. Hero Support Header Card ───────────────────────────
                  _buildHeroHeader(darkAccent),
                  const SizedBox(height: 16),

                  // ── 2. Direct Channels (Email, Phone, WhatsApp) ───────────
                  _buildDirectChannelsCard(darkAccent),
                  const SizedBox(height: 16),

                  // ── 3. Working Hours & Operating Details ──────────────────
                  _buildWorkingHoursCard(darkAccent),
                  const SizedBox(height: 24),

                  Center(
                    child: Text(
                      'Rooks And Brooks Technologies • Powered by Antigravity Cloud',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
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

  // ---------------------------------------------------------------------------
  // UI SECTIONS
  // ---------------------------------------------------------------------------

  Widget _buildHeroHeader(Color darkAccent) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor,
                  darkAccent,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 10,
                            color: Color(0xFF10B981),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'ONLINE • FAST RESPONSE',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF059669),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'How can we help you?',
                  style: TextStyle(
                    fontSize: 17.5,
                    fontWeight: FontWeight.w900,
                    color: darkAccent,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Our dedicated customer support channels are active to assist you with all construction management operations.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF64748B),
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectChannelsCard(Color darkAccent) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.headset_mic_rounded,
                  color: primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instant Support Channels',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: darkAccent,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Choose a channel below to get in touch with our team directly.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: Color(0xFFF1F5F9), height: 1),
          ),

          // 1. Email Support Channel
          _buildChannelItem(
            icon: Icons.alternate_email_rounded,
            channelAccent: const Color(0xFF1E88E5), // Primary Blue
            title: 'Official Support Email',
            value: _email,
            actionLabel: 'Send Email',
            actionIcon: Icons.outgoing_mail,
            onTap: _launchEmail,
            onCopy: () => _copyToClipboard(_email, 'Email copied to clipboard'),
          ),
          const SizedBox(height: 14),

          // 2. Phone Support Channel
          _buildChannelItem(
            icon: Icons.phone_in_talk_rounded,
            channelAccent: const Color(0xFF059669), // Emerald Green
            title: 'Customer Helpline',
            value: _phoneDisplay,
            actionLabel: 'Call Now',
            actionIcon: Icons.phone_forwarded_rounded,
            onTap: _launchPhone,
            onCopy: () => _copyToClipboard(_phoneDisplay, 'Phone number copied'),
          ),
          const SizedBox(height: 14),

          // 3. WhatsApp Support Channel
          _buildChannelItem(
            icon: Icons.chat_bubble_rounded,
            channelAccent: const Color(0xFF25D366), // WhatsApp Green
            title: 'WhatsApp Business Chat',
            value: _phoneDisplay,
            actionLabel: 'Chat on WhatsApp',
            actionIcon: Icons.send_rounded,
            onTap: _launchWhatsApp,
            onCopy: () =>
                _copyToClipboard(_phoneDisplay, 'WhatsApp contact copied'),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelItem({
    required IconData icon,
    required Color channelAccent,
    required String title,
    required String value,
    required String actionLabel,
    required IconData actionIcon,
    required VoidCallback onTap,
    required VoidCallback onCopy,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Icon + Title & Value + Copy Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: channelAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: channelAccent.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Icon(icon, color: channelAccent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    SelectableText(
                      value,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Copy',
                icon: const Icon(
                  Icons.copy_rounded,
                  size: 16,
                  color: Color(0xFF64748B),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                onPressed: onCopy,
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Action Button across full available width with responsive padding & unclipped text
          Material(
            color: channelAccent,
            borderRadius: BorderRadius.circular(12),
            elevation: 1.5,
            shadowColor: channelAccent.withValues(alpha: 0.35),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(actionIcon, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        actionLabel,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkingHoursCard(Color darkAccent) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.schedule_rounded,
              color: primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Operating Hours',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: darkAccent,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Monday – Saturday • 9:00 AM – 6:00 PM IST',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Emails and WhatsApp messages sent outside working hours will be answered on the next business day.',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF94A3B8),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
