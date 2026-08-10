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
    final primaryColor = AppTheme.primaryColor.value;
    final darkAccent = AppTheme.getDarkAccent(primaryColor);

    if (isSecondary) {
      return SizedBox(
        height: 54,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF0A183D),
            disabledBackgroundColor: Colors.white.withValues(alpha: 0.6),
            disabledForegroundColor: const Color(0xFF0A183D).withValues(alpha: 0.5),
            side: const BorderSide(color: Colors.white, width: 1.5),
            elevation: 4,
            shadowColor: Colors.black.withValues(alpha: 0.15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _buildContent(context, isSecondary: true),
        ),
      );
    }

    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: darkAccent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: darkAccent.withValues(alpha: 0.5),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
          elevation: 6,
          shadowColor: darkAccent.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _buildContent(context, isSecondary: false),
      ),
    );
  }

  Widget _buildContent(BuildContext context, {required bool isSecondary}) {
    if (isLoading) {
      return SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(
            isSecondary ? const Color(0xFF0A183D) : Colors.white,
          ),
        ),
      );
    }

    final bool isDisabled = onPressed == null;
    final Color textColor = isSecondary
        ? (isDisabled
            ? const Color(0xFF0A183D).withValues(alpha: 0.5)
            : const Color(0xFF0A183D))
        : (isDisabled
            ? Colors.white.withValues(alpha: 0.7)
            : Colors.white);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: textColor),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: textColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
