import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/utils/dialog_utils.dart';

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

  // In-App Support Ticket Form State
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  String _selectedCategory = 'Technical Support';
  bool _isSubmitting = false;

  final List<String> _categories = [
    'Technical Support',
    'Site & Attendance Help',
    'Material & Tool Tracking',
    'Billing & Subscriptions',
    'Feature Request',
    'Other Inquiries',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _messageController.dispose();
    super.dispose();
  }

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

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await FirestoreService.getCollection('supportTickets').add({
        'name': _nameController.text.trim(),
        'contact': _contactController.text.trim(),
        'category': _selectedCategory,
        'message': _messageController.text.trim(),
        'status': 'Open',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        await DialogUtils.showSuccessDialog(
          context,
          message: 'Support ticket submitted successfully!\nOur team will contact you shortly.',
        );
        _nameController.clear();
        _contactController.clear();
        _messageController.clear();
      }
    } catch (e) {
      if (mounted) {
        AppTheme.showErrorToast(context, 'Failed to submit ticket: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 680),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── 1. Hero Support Header Card ───────────────────────────
                  _buildHeroHeader(darkAccent),
                  const SizedBox(height: 16),

                  // ── 2. Direct Channels (Email, Phone, WhatsApp) ───────────
                  _buildDirectChannelsCard(darkAccent),
                  const SizedBox(height: 16),

                  // ── 3. Submit a Support Ticket Form ───────────────────────
                  _buildTicketFormCard(darkAccent),
                  const SizedBox(height: 16),

                  // ── 4. Working Hours & Operating Details ──────────────────
                  _buildWorkingHoursCard(darkAccent),
                  const SizedBox(height: 24),

                  Center(
                    child: Text(
                      'Rooks And Brooks Technologies &bull; Powered by Antigravity Cloud',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
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
        children: [
          Container(
            width: 56,
            height: 56,
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
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'ONLINE • FAST RESPONSE',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: primaryColor,
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
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: darkAccent,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Our dedicated support team is available to assist with your construction management operations.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF64748B),
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
                child: Icon(Icons.contact_phone_rounded, color: primaryColor, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'Instant Support Channels',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: darkAccent,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Color(0xFFF1F5F9), height: 1),
          ),

          // 1. Email Support
          _buildChannelItem(
            icon: Icons.alternate_email_rounded,
            title: 'Official Support Email',
            value: _email,
            actionLabel: 'Send Email',
            onTap: _launchEmail,
            onCopy: () => _copyToClipboard(_email, 'Email copied to clipboard'),
          ),
          const SizedBox(height: 10),

          // 2. Phone Support
          _buildChannelItem(
            icon: Icons.phone_iphone_rounded,
            title: 'Customer Helpline',
            value: _phoneDisplay,
            actionLabel: 'Call Now',
            onTap: _launchPhone,
            onCopy: () => _copyToClipboard(_phoneDisplay, 'Phone number copied'),
          ),
          const SizedBox(height: 10),

          // 3. WhatsApp Support
          _buildChannelItem(
            icon: Icons.chat_rounded,
            title: 'WhatsApp Business Chat',
            value: _phoneDisplay,
            actionLabel: 'Chat on WhatsApp',
            onTap: _launchWhatsApp,
            onCopy: () => _copyToClipboard(_phoneDisplay, 'WhatsApp contact copied'),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelItem({
    required IconData icon,
    required String title,
    required String value,
    required String actionLabel,
    required VoidCallback onTap,
    required VoidCallback onCopy,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy',
            icon: Icon(Icons.copy_rounded, size: 16, color: primaryColor),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: onCopy,
          ),
          const SizedBox(width: 6),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              elevation: 2,
              shadowColor: primaryColor.withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              actionLabel,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketFormCard(Color darkAccent) {
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
      child: Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: const InputDecorationTheme(
            filled: false,
            fillColor: Colors.transparent,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        child: Form(
          key: _formKey,
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
                    child: Icon(Icons.confirmation_number_rounded, color: primaryColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Submit a Help Request',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: darkAccent,
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(color: Color(0xFFF1F5F9), height: 1),
              ),

              // Name
              _buildFormLabel('Your Name *', Icons.person_rounded),
              const SizedBox(height: 6),
              _buildInputContainer(
                child: TextFormField(
                  controller: _nameController,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  decoration: const InputDecoration(
                    hintText: 'Enter your full name',
                    hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w500),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Contact
              _buildFormLabel('Email or Phone Number *', Icons.contact_mail_rounded),
              const SizedBox(height: 6),
              _buildInputContainer(
                child: TextFormField(
                  controller: _contactController,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your contact details' : null,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  decoration: const InputDecoration(
                    hintText: 'e.g. name@company.com or +91...',
                    hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w500),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Issue Category
              _buildFormLabel('Issue Category', Icons.category_rounded),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 20),
                    items: _categories.map((c) {
                      return DropdownMenuItem<String>(
                        value: c,
                        child: Text(
                          c,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCategory = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Message
              _buildFormLabel('Describe your query or issue *', Icons.edit_note_rounded),
              const SizedBox(height: 6),
              _buildInputContainer(
                verticalPadding: 10,
                child: TextFormField(
                  controller: _messageController,
                  maxLines: 4,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please provide details about your issue' : null,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A), height: 1.4),
                  decoration: const InputDecoration(
                    hintText: 'Type your message or issue description here...',
                    hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w500),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitTicket,
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'SUBMIT TICKET',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                    shadowColor: primaryColor.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkingHoursCard(Color darkAccent) {
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
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.schedule_rounded, color: primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
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
                  const Text(
                    'Monday – Saturday • 9:00 AM – 6:00 PM IST',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: primaryColor),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
      ],
    );
  }

  Widget _buildInputContainer({required Widget child, double verticalPadding = 11}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: verticalPadding),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
      ),
      child: child,
    );
  }
}
