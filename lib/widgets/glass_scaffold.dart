import 'package:flutter/material.dart';
import '../utils/responsive.dart';

class GlassScaffold extends StatelessWidget {
  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? bottom;

  const GlassScaffold({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.onBack,
    this.floatingActionButton,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final hasAppBar = title != null ||
        onBack != null ||
        (actions != null && actions!.isNotEmpty) ||
        bottom != null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: hasAppBar
          ? AppBar(
              title: title != null ? Text(title!) : null,
              leading: onBack != null
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: onBack,
                    )
                  : null,
              actions: actions,
              bottom: bottom,
              centerTitle: true,
              elevation: 0,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
            )
          : null,
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.isMobile(context) ? 16 : 24,
          ),
          child: body,
        ),
      ),
    );
  }
}
