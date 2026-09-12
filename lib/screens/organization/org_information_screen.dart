import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:ebricks/services/firestore_service.dart';
import 'package:ebricks/services/auth_service.dart';
import 'package:ebricks/utils/app_theme.dart';

class OrgInformationScreen extends StatefulWidget {
  const OrgInformationScreen({super.key});

  @override
  State<OrgInformationScreen> createState() => _OrgInformationScreenState();
}

class _OrgInformationScreenState extends State<OrgInformationScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _orgPhoneController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  late TabController _tabController;

  bool _isLoading = false;
  bool _isFetching = true;

  // Organization & Admin profile attributes
  String _orgName = '';
  String _adminUsername = '';
  String _adminEmail = '';
  String _adminPhone = '';
  String _adminRole = 'Organization Admin';
  String _selectedRoleFilter = 'All';

  // All organization users list
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_filterUsers);
    _fetchInformation();
  }

  Future<void> _fetchInformation() async {
    if (!mounted) return;
    setState(() => _isFetching = true);

    try {
      if (!FirestoreService.isReady) {
        await FirestoreService.initialize();
      }

      // 1. Fetch Organization Admin Data
      var adminDoc = await FirestoreService.orgDataDoc.get();
      if (!adminDoc.exists) {
        debugPrint('OrgInformationScreen: Data doc not found in admin, falling back to root.');
        adminDoc = await FirestoreService.rootOrgDoc.get();
      }

      final adminData = adminDoc.exists ? adminDoc.data() : null;
      final cachedUserData = AuthService().userData;

      final orgName = (adminData?['org_name'] ??
              adminData?['orgName'] ??
              adminData?['companyName'] ??
              cachedUserData['org_name'] ??
              cachedUserData['orgName'] ??
              FirestoreService.currentOrgId)
          .toString()
          .trim();

      final username = (adminData?['username'] ??
              adminData?['userName'] ??
              adminData?['name'] ??
              adminData?['adminName'] ??
              cachedUserData['username'] ??
              cachedUserData['userName'] ??
              'Admin')
          .toString()
          .trim();

      final email = (adminData?['email'] ??
              adminData?['Email'] ??
              adminData?['emailId'] ??
              cachedUserData['email'] ??
              cachedUserData['Email'] ??
              '')
          .toString()
          .trim();

      final phone = (adminData?['phone'] ??
              adminData?['orgPhone'] ??
              adminData?['phoneNumber'] ??
              adminData?['MobileNumber'] ??
              cachedUserData['phone'] ??
              cachedUserData['MobileNumber'] ??
              '')
          .toString()
          .trim();

      final role = (adminData?['role'] ??
              adminData?['userRole'] ??
              cachedUserData['role'] ??
              'Organization Admin')
          .toString()
          .trim();

      final address = (adminData?['address'] ??
              adminData?['orgAddress'] ??
              cachedUserData['address'] ??
              '')
          .toString()
          .trim();

      // 2. Fetch All Sub-Users (Organization Users, Managers, Supervisors)
      final List<Map<String, dynamic>> compiledUsers = [];
      final Set<String> seenIdentifiers = {};

      // Add the Primary Admin / Head User
      if (username.isNotEmpty) {
        final adminKey = '${username.toLowerCase()}_${email.toLowerCase()}';
        seenIdentifiers.add(adminKey);
        compiledUsers.add({
          'name': username,
          'username': username,
          'phone': phone.isNotEmpty ? phone : 'Not provided',
          'email': email.isNotEmpty ? email : 'Not provided',
          'role': role.isNotEmpty ? role : 'Organization Admin',
          'status': 'Active',
          'isPrimary': true,
        });
      }

      // Fetch from 'organizationUser' subcollection
      try {
        final orgUsersSnap = await FirestoreService.organizationUsers.get();
        for (var doc in orgUsersSnap.docs) {
          final data = doc.data();
          final uName = (data['username'] ?? data['userName'] ?? doc.id).toString().trim();
          final fName = (data['fullName'] ?? data['name'] ?? uName).toString().trim();
          final uEmail = (data['email'] ?? data['Email'] ?? '').toString().trim();
          final uPhone = (data['phone'] ??
                  data['phoneNumber'] ??
                  data['contactNo'] ??
                  data['MobileNumber'] ??
                  '')
              .toString()
              .trim();
          final uRole = (data['role'] ?? data['designation'] ?? 'Organization User')
              .toString()
              .trim();
          final uStatus = (data['status'] ?? data['Status'] ?? 'Active').toString().trim();

          final key = '${uName.toLowerCase()}_${uEmail.toLowerCase()}';
          if (!seenIdentifiers.contains(key)) {
            seenIdentifiers.add(key);
            compiledUsers.add({
              'name': fName.isNotEmpty ? fName : uName,
              'username': uName,
              'phone': uPhone.isNotEmpty ? uPhone : 'Not provided',
              'email': uEmail.isNotEmpty ? uEmail : 'Not provided',
              'role': uRole.isNotEmpty ? uRole : 'Organization User',
              'status': uStatus.isNotEmpty ? uStatus : 'Active',
              'isPrimary': false,
            });
          }
        }
      } catch (e) {
        debugPrint('OrgInformationScreen: Note loading organizationUser: $e');
      }

      // Fetch from 'manager' subcollection
      try {
        final managerSnap = await FirestoreService.getCollection('manager').get();
        for (var doc in managerSnap.docs) {
          final data = doc.data();
          final uName = (data['UserName'] ?? data['userName'] ?? data['username'] ?? doc.id)
              .toString()
              .trim();
          final fName = (data['FullName'] ?? data['fullName'] ?? data['name'] ?? uName)
              .toString()
              .trim();
          final uEmail = (data['Email'] ?? data['email'] ?? '').toString().trim();
          final uPhone = (data['Contact No'] ??
                  data['contactNo'] ??
                  data['phone'] ??
                  data['phoneNumber'] ??
                  '')
              .toString()
              .trim();
          final uRole = (data['Designation'] ?? data['role'] ?? 'Manager').toString().trim();
          final uStatus = (data['Status'] ?? data['status'] ?? 'Active').toString().trim();

          final key = '${uName.toLowerCase()}_${uEmail.toLowerCase()}';
          if (!seenIdentifiers.contains(key)) {
            seenIdentifiers.add(key);
            compiledUsers.add({
              'name': fName.isNotEmpty ? fName : uName,
              'username': uName,
              'phone': uPhone.isNotEmpty ? uPhone : 'Not provided',
              'email': uEmail.isNotEmpty ? uEmail : 'Not provided',
              'role': uRole.isNotEmpty ? uRole : 'Manager',
              'status': uStatus.isNotEmpty ? uStatus : 'Active',
              'isPrimary': false,
            });
          }
        }
      } catch (e) {
        debugPrint('OrgInformationScreen: Note loading manager: $e');
      }

      // Fetch from 'supervisor' subcollection
      try {
        final supervisorSnap = await FirestoreService.getCollection('supervisor').get();
        for (var doc in supervisorSnap.docs) {
          final data = doc.data();
          final uName = (data['Supervisor ID'] ??
                  data['supervisorId'] ??
                  data['username'] ??
                  data['userName'] ??
                  doc.id)
              .toString()
              .trim();
          final fName = (data['Supervisor Name'] ??
                  data['supervisorName'] ??
                  data['fullName'] ??
                  data['name'] ??
                  uName)
              .toString()
              .trim();
          final uEmail = (data['Email'] ?? data['email'] ?? '').toString().trim();
          final uPhone = (data['Contact No'] ??
                  data['contactNo'] ??
                  data['phone'] ??
                  data['MobileNumber'] ??
                  '')
              .toString()
              .trim();
          final uRole = (data['Role'] ?? data['role'] ?? 'Site Supervisor').toString().trim();
          final uStatus = (data['Status'] ?? data['status'] ?? 'Active').toString().trim();

          final key = '${uName.toLowerCase()}_${uEmail.toLowerCase()}';
          if (!seenIdentifiers.contains(key)) {
            seenIdentifiers.add(key);
            compiledUsers.add({
              'name': fName.isNotEmpty ? fName : uName,
              'username': uName,
              'phone': uPhone.isNotEmpty ? uPhone : 'Not provided',
              'email': uEmail.isNotEmpty ? uEmail : 'Not provided',
              'role': uRole.isNotEmpty ? uRole : 'Supervisor',
              'status': uStatus.isNotEmpty ? uStatus : 'Active',
              'isPrimary': false,
            });
          }
        }
      } catch (e) {
        debugPrint('OrgInformationScreen: Note loading supervisor: $e');
      }

      if (mounted) {
        setState(() {
          _orgName = orgName;
          _adminUsername = username;
          _adminEmail = email;
          _adminPhone = phone;
          _adminRole = role;

          _addressController.text = address;
          _orgPhoneController.text = phone;

          _allUsers = compiledUsers;
          _filterUsers();
        });
      }
    } catch (e) {
      debugPrint('Error fetching org information: $e');
      if (mounted) {
        AppTheme.showErrorToast(context, 'Failed to load organisation info');
      }
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  void _filterUsers() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredUsers = _allUsers.where((u) {
        final matchesRole = _selectedRoleFilter == 'All' ||
            u['role'].toString().toLowerCase().contains(_selectedRoleFilter.toLowerCase());

        if (!matchesRole) return false;
        if (query.isEmpty) return true;

        final name = (u['name'] ?? '').toString().toLowerCase();
        final uname = (u['username'] ?? '').toString().toLowerCase();
        final email = (u['email'] ?? '').toString().toLowerCase();
        final phone = (u['phone'] ?? '').toString().toLowerCase();
        final role = (u['role'] ?? '').toString().toLowerCase();

        return name.contains(query) ||
            uname.contains(query) ||
            email.contains(query) ||
            phone.contains(query) ||
            role.contains(query);
      }).toList();
    });
  }

  Future<void> _saveInformation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updatedAddress = _addressController.text.trim();
      final updatedPhone = _orgPhoneController.text.trim();

      await FirestoreService.orgDataDoc.set({
        'address': updatedAddress,
        'phone': updatedPhone,
        'orgPhone': updatedPhone,
      }, SetOptions(merge: true));

      // Also update local cached state
      setState(() {
        _adminPhone = updatedPhone;
        // Update primary admin card entry in user list as well
        final adminIndex = _allUsers.indexWhere((u) => u['isPrimary'] == true);
        if (adminIndex != -1) {
          _allUsers[adminIndex]['phone'] = updatedPhone;
          _filterUsers();
        }
      });

      if (mounted) {
        AppTheme.showSuccessToast(
          context,
          'Organisation information updated successfully!',
        );
      }
    } catch (e) {
      debugPrint('Error saving org information: $e');
      if (mounted) {
        AppTheme.showErrorToast(context, 'Error updating information: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _copyToClipboard(String text, String label) {
    if (text.isEmpty || text == 'Not provided') return;
    Clipboard.setData(ClipboardData(text: text));
    AppTheme.showSuccessToast(context, '$label copied to clipboard');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _addressController.dispose();
    _orgPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.primaryColor,
      builder: (context, primaryColor, _) {
        final darkAccent = AppTheme.getDarkAccent(primaryColor);

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text(
              'Organisation Info',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: -0.3,
              ),
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
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: primaryColor,
                  indicatorWeight: 3,
                  labelColor: primaryColor,
                  unselectedLabelColor: const Color(0xFF64748B),
                  labelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: [
                    const Tab(
                      iconMargin: EdgeInsets.zero,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.business_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Overview & Details'),
                        ],
                      ),
                    ),
                    Tab(
                      iconMargin: EdgeInsets.zero,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.people_alt_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text('All Users (${_allUsers.length})'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: SafeArea(
            child: _isFetching
                ? Center(
                    child: CircularProgressIndicator(
                      color: primaryColor,
                    ),
                  )
                : Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isMobile ? double.infinity : 680,
                      ),
                      child: TabBarView(
                        controller: _tabController,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _buildOverviewTab(theme, primaryColor),
                          _buildAllUsersTab(theme, primaryColor),
                        ],
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: OVERVIEW & ORGANIZATION PROFILE + EDIT FORM
  // ---------------------------------------------------------------------------
  Widget _buildOverviewTab(ThemeData theme, Color primaryColor) {
    return RefreshIndicator(
      color: primaryColor,
      onRefresh: _fetchInformation,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Hero Identity Card (Organization Name, Username, Phone, Email, Role)
              _buildOrgIdentityCard(theme, primaryColor),

              const SizedBox(height: 16),

              // 2. Editable Info Card (Address & Phone Number)
              _buildEditableSectionCard(theme, primaryColor),

              const SizedBox(height: 20),

              // 3. Save CTA Button
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveInformation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: primaryColor.withValues(alpha: 0.35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline_rounded, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'SAVE CHANGES',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrgIdentityCard(ThemeData theme, Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Banner with Org Icon & Name
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
              border: const Border(
                bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primaryColor,
                        AppTheme.getDarkAccent(primaryColor),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.apartment_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _orgName.isNotEmpty ? _orgName : 'Organisation',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0A183D),
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified_rounded,
                                  size: 11,
                                  color: Color(0xFF10B981),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Verified Organisation',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // User details grid / list
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Account & Administrator Details',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 12),

                // Username & Role
                _buildInfoRow(
                  icon: Icons.person_rounded,
                  iconColor: const Color(0xFF2563EB),
                  label: 'User / Username',
                  value: _adminUsername.isNotEmpty ? _adminUsername : 'Admin',
                  badgeText: _adminRole.isNotEmpty ? _adminRole : 'Admin',
                  badgeColor: const Color(0xFF8B5CF6),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: Color(0xFFF1F5F9), height: 1),
                ),

                // Email
                _buildInfoRow(
                  icon: Icons.email_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  label: 'Email Address',
                  value: _adminEmail.isNotEmpty ? _adminEmail : 'Not provided',
                  onCopy: () => _copyToClipboard(_adminEmail, 'Email'),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: Color(0xFFF1F5F9), height: 1),
                ),

                // Phone Number
                _buildInfoRow(
                  icon: Icons.phone_rounded,
                  iconColor: const Color(0xFF10B981),
                  label: 'Phone Number',
                  value: _adminPhone.isNotEmpty ? _adminPhone : 'Not provided',
                  onCopy: () => _copyToClipboard(_adminPhone, 'Phone number'),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: Color(0xFFF1F5F9), height: 1),
                ),

                // Role
                _buildInfoRow(
                  icon: Icons.admin_panel_settings_rounded,
                  iconColor: const Color(0xFF7C3AED),
                  label: 'System Role',
                  value: _adminRole.isNotEmpty ? _adminRole : 'Organization Admin',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    String? badgeText,
    Color? badgeColor,
    VoidCallback? onCopy,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (badgeText != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: (badgeColor ?? iconColor).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: badgeColor ?? iconColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (onCopy != null && value.isNotEmpty && value != 'Not provided')
          IconButton(
            icon: const Icon(
              Icons.copy_rounded,
              size: 16,
              color: Color(0xFF94A3B8),
            ),
            tooltip: 'Copy',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: onCopy,
          ),
      ],
    );
  }

  Widget _buildEditableSectionCard(ThemeData theme, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  Icons.edit_note_rounded,
                  color: primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Update Contact & Address',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0A183D),
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Modify your official organisation address and phone number.',
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

          // Address Input Field
          _buildInputField(
            theme: theme,
            controller: _addressController,
            label: 'Organisation Address',
            hint: 'Enter Full Organisation Address',
            icon: Icons.location_on_rounded,
            maxLines: 3,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter the address';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // Phone Number Input Field
          _buildInputField(
            theme: theme,
            controller: _orgPhoneController,
            label: 'Organisation Contact Phone',
            hint: 'Enter 10-digit Phone Number',
            icon: Icons.phone_rounded,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter the phone number';
              }
              if (val.trim().length != 10) {
                return 'Phone number must be exactly 10 digits';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: ALL USERS LIST (ADMIN, MANAGERS, SUPERVISORS, ORG USERS)
  // ---------------------------------------------------------------------------
  Widget _buildAllUsersTab(ThemeData theme, Color primaryColor) {
    final roleFilters = ['All', 'Admin', 'Manager', 'Supervisor', 'User'];

    return RefreshIndicator(
      color: primaryColor,
      onRefresh: _fetchInformation,
      child: Column(
        children: [
          // Search & Filter Header Container
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
              ),
            ),
            child: Column(
              children: [
                // Search Input Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF64748B),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search by name, username, phone, email...',
                            hintStyle: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      _filterUsers();
                                    },
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Role Filter Chips Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: roleFilters.map((role) {
                      final isSelected = _selectedRoleFilter == role;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(role),
                          selected: isSelected,
                          selectedColor: primaryColor.withValues(alpha: 0.15),
                          backgroundColor: const Color(0xFFF8FAFC),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                            color: isSelected ? primaryColor : const Color(0xFF64748B),
                          ),
                          side: BorderSide(
                            color: isSelected ? primaryColor : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          onSelected: (_) {
                            setState(() {
                              _selectedRoleFilter = role;
                              _filterUsers();
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // User Cards List View
          Expanded(
            child: _filteredUsers.isEmpty
                ? _buildEmptyState(primaryColor)
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      return _buildUserCard(user, primaryColor);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, Color primaryColor) {
    final String name = user['name'] ?? 'User';
    final String username = user['username'] ?? '';
    final String role = user['role'] ?? 'Member';
    final String phone = user['phone'] ?? 'Not provided';
    final String email = user['email'] ?? 'Not provided';
    final String status = user['status'] ?? 'Active';
    final bool isPrimary = user['isPrimary'] == true;

    // Role specific coloring
    Color roleColor = const Color(0xFF2563EB); // Blue default
    IconData roleIcon = Icons.badge_rounded;

    final roleLower = role.toLowerCase();
    if (roleLower.contains('admin') || roleLower.contains('owner') || roleLower.contains('head')) {
      roleColor = const Color(0xFF7C3AED); // Purple
      roleIcon = Icons.shield_rounded;
    } else if (roleLower.contains('manager')) {
      roleColor = const Color(0xFF0284C7); // Sky Blue
      roleIcon = Icons.manage_accounts_rounded;
    } else if (roleLower.contains('supervisor')) {
      roleColor = const Color(0xFFD97706); // Amber
      roleIcon = Icons.engineering_rounded;
    } else if (roleLower.contains('customer')) {
      roleColor = const Color(0xFF059669); // Emerald
      roleIcon = Icons.person_pin_rounded;
    }

    final bool isActive = status.toLowerCase() != 'inactive';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPrimary
              ? primaryColor.withValues(alpha: 0.4)
              : const Color(0xFFE2E8F0),
          width: isPrimary ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Avatar + Name + Username + Role Chip
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar Circle
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: roleColor.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'U',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: roleColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Name & Username
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0A183D),
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isPrimary) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Primary Admin',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@$username',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),

                // Role Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: roleColor.withValues(alpha: 0.2),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(roleIcon, size: 12, color: roleColor),
                      const SizedBox(width: 4),
                      Text(
                        role,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: roleColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(color: Color(0xFFF1F5F9), height: 1),
            ),

            // Contact Information Grid (Phone & Email)
            Row(
              children: [
                // Phone
                Expanded(
                  child: InkWell(
                    onTap: () => _copyToClipboard(phone, 'Phone number'),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.phone_outlined,
                            size: 14,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              phone,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: phone == 'Not provided'
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF334155),
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
                const SizedBox(width: 12),

                // Email
                Expanded(
                  child: InkWell(
                    onTap: () => _copyToClipboard(email, 'Email address'),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.email_outlined,
                            size: 14,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              email,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: email == 'Not provided'
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF334155),
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

            const SizedBox(height: 8),

            // Status indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isActive ? 'Active Account' : 'Inactive Account',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? const Color(0xFF059669)
                            : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Tap to copy details',
                  style: TextStyle(
                    fontSize: 10,
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color primaryColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_search_rounded,
                size: 32,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Users Found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0A183D),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'No users matched your search criteria or role filter.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPER: INPUT FIELD
  // ---------------------------------------------------------------------------
  Widget _buildInputField({
    required ThemeData theme,
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: theme.primaryColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: maxLines > 1 ? 10 : 11,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          ),
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            validator: validator,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }
}
