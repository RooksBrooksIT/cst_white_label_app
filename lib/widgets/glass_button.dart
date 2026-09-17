import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class GlassButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isSecondary;
  final bool isLoading;
  final IconData? icon;

  const GlassButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isSecondary = false,
    this.isLoading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.primaryColor,
      builder: (context, primaryColor, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final darkAccent = AppTheme.getDarkAccent(primaryColor);

        if (isSecondary) {
          return SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: isLoading ? null : onPressed,
              style: OutlinedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                foregroundColor: isDark ? Colors.white : const Color(0xFF0A183D),
                disabledBackgroundColor: isDark
                    ? const Color(0xFF1E293B).withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.6),
                disabledForegroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.4)
                    : const Color(0xFF0A183D).withValues(alpha: 0.4),
                side: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
                elevation: 2,
                shadowColor: Colors.black.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: _buildContent(context, isSecondary: true, isDark: isDark),
            ),
          );
        }

        return SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: darkAccent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: darkAccent.withValues(alpha: 0.45),
              disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
              elevation: 4,
              shadowColor: darkAccent.withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: _buildContent(context, isSecondary: false, isDark: isDark),
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, {required bool isSecondary, required bool isDark}) {
    if (isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          valueColor: AlwaysStoppedAnimation<Color>(
            isSecondary
                ? (isDark ? Colors.white : const Color(0xFF0A183D))
                : Colors.white,
          ),
        ),
      );
    }

    final bool isDisabled = onPressed == null;
    final Color textColor = isSecondary
        ? (isDisabled
            ? (isDark
                ? Colors.white.withValues(alpha: 0.4)
                : const Color(0xFF0A183D).withValues(alpha: 0.4))
            : (isDark ? Colors.white : const Color(0xFF0A183D)))
        : (isDisabled
            ? Colors.white.withValues(alpha: 0.6)
            : Colors.white);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                color: textColor,
              ),
              maxLines: 1,
            ),
          ),
        ),
      ],
    );
  }
}
