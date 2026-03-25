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
  });

  @override
  Widget build(BuildContext context) {
    final defaultPadding = EdgeInsets.all(Responsive.isMobile(context) ? 20 : 28);
    final currentPadding = padding ?? defaultPadding;
    
    return Card(
      margin: margin,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius ?? (Responsive.isMobile(context) ? 12 : 16)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null)
                Padding(
                  padding: currentPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title!,
                        style: TextStyle(
                          fontSize: Responsive.isMobile(context) ? 18 : 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: Responsive.isMobile(context) ? 14 : 16,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                    ],
                  ),
                ),
              Padding(
                padding: (title != null) 
                  ? currentPadding.copyWith(top: 16)
                  : currentPadding,
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
