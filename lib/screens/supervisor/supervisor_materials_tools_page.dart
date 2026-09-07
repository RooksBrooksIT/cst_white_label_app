import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/utils/responsive.dart';
import 'package:demo_cst/screens/supervisor/material_at_site_entry_page.dart';
import 'package:demo_cst/screens/supervisor/tools_at_site_page.dart';
import 'package:demo_cst/screens/supervisor/tools_movement_page.dart';
import 'package:demo_cst/screens/supervisor/supervisor_material_information.dart';

class SupervisorMaterialsToolsPage extends StatelessWidget {
  final String supervisorId;
  final String supervisorName;

  const SupervisorMaterialsToolsPage({
    super.key,
    required this.supervisorId,
    required this.supervisorName,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.primaryColor,
      builder: (context, primaryColor, _) {
        final darkAccent = AppTheme.getDarkAccent(primaryColor);

        final items = [
          _MenuItemData(
            title: 'Materials at Site',
            subtitle: 'Live stock & materials inventory allocated to your sites',
            icon: Icons.inventory_2_rounded,
            accentColor: const Color(0xFF7C3AED),
            badgeText: 'Live Stock',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MaterialAtSiteEntryPage(
                    supervisorId: supervisorId,
                    supervisorName: supervisorName,
                  ),
                ),
              );
            },
          ),
          _MenuItemData(
            title: 'Tools at Site',
            subtitle: 'Equipment, machinery & tool inventory present at site',
            icon: Icons.home_repair_service_rounded,
            accentColor: const Color(0xFF06B6D4),
            badgeText: 'Equipment',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ToolsAtSitePage(
                    supervisorId: supervisorId,
                    supervisorName: supervisorName,
                  ),
                ),
              );
            },
          ),
          _MenuItemData(
            title: 'Tools Movement',
            subtitle: 'Transfer and reassign tools between sites & company warehouse',
            icon: Icons.swap_horiz_rounded,
            accentColor: const Color(0xFF0D9488),
            badgeText: 'Transfer',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ToolsMovementPage(),
                ),
              );
            },
          ),
          _MenuItemData(
            title: 'Materials Info',
            subtitle: 'Material specifications catalog, unit costs & usage guidelines',
            icon: Icons.info_rounded,
            accentColor: const Color(0xFFA855F7),
            badgeText: 'Catalog',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SupervisorMaterialInfoScreen(),
                ),
              );
            },
          ),
        ];

        return Theme(
          data: AppTheme.getTheme(primaryColor),
          child: Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            appBar: AppBar(
              iconTheme: const IconThemeData(color: Colors.white),
              title: const Text(
                'Materials & Tools',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: -0.3,
                ),
              ),
              centerTitle: true,
              elevation: 0,
              backgroundColor: Colors.transparent,
              systemOverlayStyle: const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
                statusBarBrightness: Brightness.light,
              ),
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
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: Responsive.maxContentWidth,
                  ),
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    children: [
                      // Overview Banner Card
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF0D9488).withValues(alpha: 0.18),
                                    const Color(0xFF0D9488).withValues(alpha: 0.06),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFF0D9488).withValues(alpha: 0.25),
                                  width: 1.2,
                                ),
                              ),
                              child: const Icon(
                                Icons.warehouse_rounded,
                                color: Color(0xFF0D9488),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Materials & Tools Hub',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0F172A),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Track site material stocks, tools inventory, movements and product specifications.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF64748B),
                                      height: 1.25,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Section Title
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Available Modules',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.2,
                              ),
                            ),
                            Text(
                              '${items.length} Actions',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0D9488),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Action Cards List
                      ...items.map((item) => _buildActionCard(context, item)),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionCard(BuildContext context, _MenuItemData item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            item.onTap();
          },
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: item.accentColor.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Icon Badge
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        item.accentColor.withValues(alpha: 0.16),
                        item.accentColor.withValues(alpha: 0.06),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: item.accentColor.withValues(alpha: 0.25),
                      width: 1.2,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      item.icon,
                      color: item.accentColor,
                      size: 25,
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Text Information
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: item.accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.badgeText,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: item.accentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.subtitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey.shade600,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Chevron Arrow Button
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 13,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItemData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final String badgeText;
  final VoidCallback onTap;

  const _MenuItemData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.badgeText,
    required this.onTap,
  });
}
