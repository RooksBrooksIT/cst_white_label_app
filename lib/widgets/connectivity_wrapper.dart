import 'package:flutter/material.dart';
import 'package:ebricks/widgets/offline_sync_banner.dart';

class ConnectivityWrapper extends StatelessWidget {
  final Widget child;

  const ConnectivityWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: OfflineSyncBanner(),
          ),
        ),
      ],
    );
  }
}
