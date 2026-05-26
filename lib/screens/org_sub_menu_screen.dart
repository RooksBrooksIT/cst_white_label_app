import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';

class SubMenuItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  SubMenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class OrgSubMenuScreen extends StatelessWidget {
  final String title;
  final List<SubMenuItem> items;

  const OrgSubMenuScreen({super.key, required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: title,
      onBack: () => Navigator.pop(context),
      padding: EdgeInsets.zero,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 32),
                  _buildSectionGroup(context, items),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
              letterSpacing: -1.0,
              fontSize: 34,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "${items.length} ${items.length == 1 ? 'option' : 'options'} available",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionGroup(BuildContext context, List<SubMenuItem> items) {
    return Column(
      children: items.map((item) => _buildActionTile(context, item)).toList(),
    );
  }

  Widget _buildActionTile(BuildContext context, SubMenuItem item) {
    final theme = Theme.of(context);
    return GlassCard(
      onTap: () {
        _triggerHapticFeedback();
        item.onTap();
      },
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          // Animated Icon Container
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [item.color, item.color.withOpacity(0.7)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: item.color.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(item.icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 18),
          // Title and Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                    fontSize: 16,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.touch_app_rounded,
                        size: 10,
                        color: item.color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Tap to continue',
                        style: TextStyle(
                          color: item.color,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Arrow indicator
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: theme.colorScheme.primary,
            size: 16,
          ),
        ],
      ),
    );
  }

  void _triggerHapticFeedback() {
    HapticFeedback.lightImpact();
  }
}
