import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A reusable dropdown widget for selecting a Site ID.
///
/// It displays the site ID along with its name (if available) and
/// uses the same visual style as the existing dropdown in `manager_expenses.dart`.
/// The widget is fully responsive and avoids fixed pixel sizes, so it can be
/// placed in any layout without causing overflow errors.
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
    Key? key,
    required this.siteIds,
    required this.siteNameMap,
    required this.selectedSiteId,
    required this.onChanged,
    this.label = 'Select Site ID',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return DropdownButtonFormField<String>(
        isExpanded: true,
      value: selectedSiteId,
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
        final name = siteNameMap[id] ?? 'Unnamed Site';
        return DropdownMenuItem<String>(
          value: id,
          child: Text(
            '$id - $name',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}
