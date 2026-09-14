import 'package:flutter/material.dart';
import 'package:ebricks/utils/site_display_helper.dart';

/// A reusable dropdown widget for selecting a Site ID.
///
/// Displays Site ID and Site Name formatted consistently as `{siteId}_{siteName}`.
class SiteDropdown extends StatelessWidget {
  /// List of site IDs to choose from.
  final List<String> siteIds;

  /// Mapping from site ID to human‑readable site name.
  final Map<String, String> siteNameMap;

  /// Currently selected site ID.
  final String? selectedSiteId;

  /// Callback when the selected value changes.
  final ValueChanged<String?> onChanged;

  /// Optional label for the dropdown field.
  final String label;

  const SiteDropdown({
    super.key,
    required this.siteIds,
    required this.siteNameMap,
    required this.selectedSiteId,
    required this.onChanged,
    this.label = 'Select Site ID',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: (selectedSiteId != null && siteIds.contains(selectedSiteId))
          ? selectedSiteId
          : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        prefixIcon: Icon(Icons.location_on_outlined, size: 20, color: colorScheme.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        filled: true,
        fillColor: theme.cardColor,
      ),
      dropdownColor: theme.cardColor,
      style: TextStyle(color: colorScheme.onSurface),
      items: siteIds.map((id) {
        final name = siteNameMap[id] ?? '';
        final displayName = SiteDisplayHelper.formatSiteDisplay(siteId: id, siteName: name);
        return DropdownMenuItem<String>(
          value: id,
          child: Text(
            displayName,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}
