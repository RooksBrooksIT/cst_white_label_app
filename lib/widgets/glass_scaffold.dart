import 'package:flutter/material.dart';

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
  final Widget? bottomNavigationBar;
  final Widget? drawer;
  final Widget? endDrawer;


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
    this.bottomNavigationBar,
    this.drawer,
    this.endDrawer,
  });


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasAppBar =
        title != null ||
        onBack != null ||
        (actions != null && actions!.isNotEmpty) ||
        bottom != null;

    final effectiveBgColor = appBarBackgroundColor ?? colorScheme.primary;
    final effectiveFgColor = appBarForegroundColor ?? colorScheme.onPrimary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: hasAppBar
          ? AppBar(
              toolbarHeight: 90,
              backgroundColor: effectiveBgColor,
              foregroundColor: effectiveFgColor,
              elevation: 4,
              shadowColor: Colors.black26,
              scrolledUnderElevation: 8,
              centerTitle: false,
              titleSpacing: onBack != null ? 8 : 24,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              title: title != null
                  ? Text(
                      title!,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.0,
                        color: effectiveFgColor,
                      ),
                    )
                  : null,
              leading: onBack != null
                  ? IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: effectiveFgColor,
                        size: 20,
                      ),
                      onPressed: onBack,
                    )
                  : null,
              actions: actions,
              bottom: bottom,
            )
          : null,
      floatingActionButton: floatingActionButton,
      drawer: drawer,
      endDrawer: endDrawer,
      body: SafeArea(

        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: body,
        ),
      ),
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
