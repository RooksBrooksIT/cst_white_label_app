import 'package:flutter/material.dart';
import '../utils/responsive.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final String? title;
  final String? subtitle;
  final double? width;
  final EdgeInsets? padding;
  final EdgeInsetsGeometry? margin;
  final double? borderRadius;
  final VoidCallback? onTap;
  final Color? color;
  final BoxBorder? border;
  final MainAxisSize? mainAxisSize;

  const GlassCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.width,
    this.padding,
    this.margin,
    this.borderRadius,
    this.onTap,
    this.color,
    this.border,
    this.mainAxisSize,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);
    final defaultPadding = EdgeInsets.all(isMobile ? 16 : 24);
    final currentPadding = padding ?? defaultPadding;
    final Color cardBg = color ?? theme.cardColor;
    final bool isDarkBg = cardBg.computeLuminance() < 0.5;

    final Color titleColor = isDarkBg ? Colors.white : const Color(0xFF0A183D);
    final Color subtitleColor = isDarkBg
        ? Colors.white.withValues(alpha: 0.75)
        : const Color(0xFF475569);

    return Container(
      width: width,
      margin: margin ?? const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(borderRadius ?? 20),
        border: border ??
            Border.all(
              color: isDarkBg
                  ? Colors.white.withValues(alpha: 0.12)
                  : const Color(0xFFE2E8F0),
              width: 1.0,
            ),
        boxShadow: [
          BoxShadow(
            color: isDarkBg
                ? cardBg.withValues(alpha: 0.25)
                : const Color(0xFF0A183D).withValues(alpha: 0.06),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius ?? 20),
          child: Padding(
            padding: currentPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: mainAxisSize ?? MainAxisSize.min,
              children: [
                if (title != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title!,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: titleColor,
                                fontSize: isMobile ? 16.5 : 18,
                                letterSpacing: -0.3,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                subtitle!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: subtitleColor,
                                  fontSize: 12.5,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (onTap != null)
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: isDarkBg
                              ? Colors.white70
                              : const Color(0xFF64748B),
                          size: 16,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                if ((mainAxisSize ?? MainAxisSize.min) == MainAxisSize.max)
                  Expanded(child: child)
                else
                  child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
