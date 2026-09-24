import 'package:flutter/material.dart';
import 'package:ebricks/screens/supervisor/tool_request_form.dart';

/// Supervisor → Tools Request Page.
/// Implements the equipment & tool requisition workflow, mirroring the Materials Request Page.
class ToolsRequestPage extends StatelessWidget {
  final String supervisorId;
  final String supervisorName;
  final bool hideAppBar;
  final VoidCallback? onRequestSubmitted;
  final VoidCallback? onCancel;

  const ToolsRequestPage({
    super.key,
    required this.supervisorId,
    required this.supervisorName,
    this.hideAppBar = false,
    this.onRequestSubmitted,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return ToolRequestForm(
      supervisorId: supervisorId,
      supervisorName: supervisorName,
      hideAppBar: hideAppBar,
      onRequestSubmitted: onRequestSubmitted,
      onCancel: onCancel,
    );
  }
}
