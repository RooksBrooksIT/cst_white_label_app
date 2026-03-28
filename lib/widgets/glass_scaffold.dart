import 'package:flutter/material.dart';
import '../utils/responsive.dart';

class GlassScaffold extends StatelessWidget {
  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? bottom;
  final EdgeInsets? padding;
  final Color? appBarBackgroundColor;
  final Color? appBarForegroundColor;

  const GlassScaffold({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.onBack,
    this.floatingActionButton,
    this.bottom,
    this.padding,
    this.appBarBackgroundColor,
    this.appBarForegroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAppBar =
        title != null ||
        onBack != null ||
        (actions != null && actions!.isNotEmpty) ||
        bottom != null;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: hasAppBar
          ? AppBar(
              toolbarHeight: 90,
              backgroundColor: appBarBackgroundColor,
              foregroundColor: appBarForegroundColor,
              elevation: 4,
              shadowColor: Colors.black26,
              scrolledUnderElevation: 8,
              centerTitle: false,
              titleSpacing: onBack != null ? 8 : 24,
              shape: appBarBackgroundColor != null
                  ? const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(32),
                        bottomRight: Radius.circular(32),
                      ),
                    )
                  : null,
              title: title != null 
                  ? Text(
                      title!,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.0,
                        color: appBarForegroundColor,
                      ),
                    ) 
                  : null,
              leading: onBack != null
                  ? IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: appBarForegroundColor,
                      ),
                      onPressed: onBack,
                    )
                  : null,
              actions: actions,
              bottom: bottom,
            )
          : null,
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        child: Padding(
          padding:
              padding ??
              EdgeInsets.symmetric(
                horizontal: Responsive.isMobile(context) ? 16 : 24,
                vertical: 16,
              ),
          child: body,
        ),
      ),
    );
  }
}
