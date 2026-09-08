import 'package:flutter/material.dart';
import 'package:ebricks/screens/manager/project_configuration_screen.dart';

class ProjectStatusScreen extends StatelessWidget {
  const ProjectStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProjectConfigurationScreen(initialIndex: 4);
  }
}
