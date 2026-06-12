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

    return Container(
      width: width,
      margin: margin ?? const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: color ?? theme.cardColor,
        borderRadius: BorderRadius.circular(borderRadius ?? 20),
        border:
            border ?? Border.all(color: theme.dividerColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            spreadRadius: 0,
            offset: const Offset(0, 2),
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
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                                fontSize: isMobile ? 16 : 18,
                                letterSpacing: -0.3,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                subtitle!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
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
                          color: theme.colorScheme.primary,
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
