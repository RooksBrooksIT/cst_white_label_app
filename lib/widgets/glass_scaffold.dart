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

        final effectiveBgColor = appBarBackgroundColor ?? primaryColor;
        final effectiveFgColor = appBarForegroundColor ?? Colors.white;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: hasAppBar
              ? AppBar(
                  elevation: 0,
                  toolbarHeight: toolbarHeight,
                  backgroundColor: effectiveBgColor,
                  foregroundColor: effectiveFgColor,
                  centerTitle: true,
                  title: title != null
                      ? Text(
                          title!,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: Responsive.fontSize(context, 20),
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: Colors.white,
                          ),
                        )
                      : null,
                  leading: onBack != null
                      ? IconButton(
                          icon: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: effectiveFgColor,
                            size: 18,
                          ),
                          onPressed: onBack,
                        )
                      : null,
                  actions: actions,
                  bottom: bottom,
                  systemOverlayStyle: const SystemUiOverlayStyle(
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness: Brightness.light,
                  ),
                  shape: const RoundedRectangleBorder(),
                )
              : null,
          floatingActionButton: floatingActionButton,
          floatingActionButtonLocation: floatingActionButtonLocation,
          drawer: drawer,
          endDrawer: endDrawer,
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  theme.colorScheme.surface,
                  theme.colorScheme.surface.withOpacity(0.95),
                ],
              ),
            ),
            child: SafeArea(
              bottom: bottomNavigationBar == null,
              child: Padding(
                padding:
                    (padding ??
                            EdgeInsets.symmetric(
                              horizontal: Responsive.spacing(context, 20),
                              vertical: Responsive.spacing(context, 24),
                            ))
                        .copyWith(top: 0),
                child: body,
              ),
            ),
          ),
          bottomNavigationBar: bottomNavigationBar,
        );
      },
    );
  }
}
