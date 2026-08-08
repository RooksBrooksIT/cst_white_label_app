import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_theme.dart';
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
  final Widget? bottomNavigationBar;
  final Widget? drawer;
  final Widget? endDrawer;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final double? toolbarHeight;

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
    this.floatingActionButtonLocation,
    this.toolbarHeight = 70,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.primaryColor,
      builder: (context, primaryColor, _) {
        final theme = Theme.of(context);
        final hasAppBar =
            title != null ||
            onBack != null ||
            (actions != null && actions!.isNotEmpty) ||
            bottom != null;

        final effectiveBgColor = appBarBackgroundColor ?? Colors.transparent;
        final effectiveFgColor = appBarForegroundColor ?? const Color(0xFF0A183D);

        final dynamicGradientColors = AppTheme.getBackgroundGradientColors(primaryColor);

        return Container(
          decoration: BoxDecoration(
            color: appBarBackgroundColor,
            gradient: appBarBackgroundColor != null
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: dynamicGradientColors,
                    stops: const [0.0, 0.35, 0.7, 1.0],
                  ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: hasAppBar
                ? AppBar(
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    toolbarHeight: toolbarHeight,
                    backgroundColor: effectiveBgColor,
                    surfaceTintColor: Colors.transparent,
                    foregroundColor: effectiveFgColor,
                    centerTitle: true,
                    leadingWidth: 54,
                    title: title != null
                        ? Text(
                            title!,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontSize: Responsive.fontSize(context, 20),
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              color: const Color(0xFF0A183D),
                            ),
                          )
                        : null,
                    leading: onBack != null
                        ? Center(
                            child: Container(
                              width: 38,
                              height: 38,
                              margin: const EdgeInsets.only(left: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0B1942),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0B1942).withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                onPressed: onBack,
                              ),
                            ),
                          )
                        : null,
                    actions: actions,
                    bottom: bottom,
                    systemOverlayStyle: const SystemUiOverlayStyle(
                      statusBarColor: Colors.transparent,
                      statusBarIconBrightness: Brightness.dark,
                    ),
                    shape: const RoundedRectangleBorder(),
                  )
                : null,
            floatingActionButton: floatingActionButton,
            floatingActionButtonLocation: floatingActionButtonLocation,
            drawer: drawer,
            endDrawer: endDrawer,
            body: SafeArea(
              top: true,
              bottom: true,
              left: false,
              right: false,
              child: Padding(
                padding: padding ?? EdgeInsets.zero,
                child: body,
              ),
            ),
            bottomNavigationBar: bottomNavigationBar,
          ),
        );
      },
    );
  }
}
