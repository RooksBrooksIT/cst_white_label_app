/// Central helper for formatting and standardizing Site display across the entire application.
/// Formats Site ID and Site Name into the standard: `{siteId}_{siteName}` (e.g. `ST001_AbineshHouse`, `ST001_shek`).
class SiteDisplayHelper {
  /// Formats siteId and siteName into standard `{siteId}_{siteName}` display format.
  /// Deduplicates redundant names, normalizes `PR` prefixes to `ST`, and prevents repeated concatenations.
  static String formatSiteDisplay({
    dynamic siteId,
    dynamic siteName,
    dynamic rawCombined,
    Map<String, dynamic>? data,
  }) {
    String rawId = (siteId ?? '').toString().trim();
    String rawName = (siteName ?? '').toString().trim();

    if (data != null) {
      if (rawId.isEmpty) {
        rawId = (data['siteId'] ?? data['id'] ?? data['siteCode'] ?? '').toString().trim();
      }
      if (rawName.isEmpty) {
        rawName = (data['siteName'] ?? data['projectName'] ?? data['name'] ?? '').toString().trim();
      }
      if (rawId.isEmpty && rawName.isEmpty) {
        final site = (data['site'] ?? '').toString().trim();
        if (site.isNotEmpty) rawId = site;
      }
    }

    if (rawId.isEmpty && rawCombined != null) {
      rawId = rawCombined.toString().trim();
    }

    // If only rawId is provided and contains both ID and Name (e.g. 'ST001_AbineshHouse' or 'ST001 — AbineshHouse')
    if (rawId.isNotEmpty && rawName.isEmpty) {
      if (rawId.contains(' — ')) {
        final parts = rawId.split(' — ');
        rawId = parts.first.trim();
        rawName = parts.sublist(1).join(' ').trim();
      } else if (rawId.contains('_')) {
        final parts = rawId.split('_');
        // Check if first part is an ID like ST001 or PR001
        final first = parts.first.trim();
        if (first.startsWith('ST') || first.startsWith('PR') || RegExp(r'^[A-Za-z0-9]+$').hasMatch(first)) {
          rawId = first;
          rawName = parts.sublist(1).join(' ').trim();
        }
      }
    }

    // Clean site ID
    String cleanId = rawId;
    if (cleanId.contains(' — ')) {
      cleanId = cleanId.split(' — ').first.trim();
    } else if (cleanId.contains('_')) {
      final parts = cleanId.split('_');
      final first = parts.first.trim();
      if (first.startsWith('ST') || first.startsWith('PR')) {
        cleanId = first;
        if (rawName.isEmpty) {
          rawName = parts.sublist(1).join(' ').trim();
        }
      }
    }

    // Convert PR prefix to ST prefix if applicable
    if (cleanId.toUpperCase().startsWith('PR') && cleanId.length > 2) {
      cleanId = 'ST${cleanId.substring(2)}';
    }

    // Clean site Name
    String cleanName = rawName;
    if (cleanName.contains(' — ')) {
      final parts = cleanName.split(' — ');
      if (parts.length > 1) {
        cleanName = parts.sublist(1).join(' ').trim();
      }
    }

    // If cleanName starts with cleanId (e.g., 'ST001_AbineshHouse' or 'ST001 AbineshHouse')
    if (cleanId.isNotEmpty) {
      final idLower = cleanId.toLowerCase();
      if (cleanName.toLowerCase().startsWith('${idLower}_')) {
        cleanName = cleanName.substring(cleanId.length + 1).trim();
      } else if (cleanName.toLowerCase().startsWith('$idLower ')) {
        cleanName = cleanName.substring(cleanId.length + 1).trim();
      } else if (cleanName.toLowerCase().startsWith(idLower)) {
        cleanName = cleanName.substring(cleanId.length).trim();
      }
    }

    // Remove unwanted duplicate underscores or trailing separators
    cleanName = cleanName.replaceAll(RegExp(r'^_+|_+$'), '').trim();
    cleanId = cleanId.replaceAll(RegExp(r'^_+|_+$'), '').trim();

    // Deduplicate if cleanName is equal to cleanId
    if (cleanName.equalsIgnoreCase(cleanId)) {
      cleanName = '';
    }

    // Final composition
    if (cleanId.isNotEmpty && cleanName.isNotEmpty) {
      // Avoid repetitive suffix like AbineshHouse_AbineshHouse
      if (cleanName.contains('_')) {
        final nameParts = cleanName.split('_');
        if (nameParts.length == 2 && nameParts[0].trim().toLowerCase() == nameParts[1].trim().toLowerCase()) {
          cleanName = nameParts[0].trim();
        }
      }
      return '${cleanId}_$cleanName';
    } else if (cleanId.isNotEmpty) {
      return cleanId;
    } else if (cleanName.isNotEmpty) {
      return cleanName;
    }

    return '';
  }

  /// Extracts the canonical Site ID (e.g. 'ST001') from any input string.
  static String extractSiteId(dynamic input) {
    if (input == null) return '';
    String str = input.toString().trim();
    if (str.contains(' — ')) {
      str = str.split(' — ').first.trim();
    } else if (str.contains('_')) {
      final parts = str.split('_');
      if (parts.first.startsWith('ST') || parts.first.startsWith('PR')) {
        str = parts.first.trim();
      }
    }
    if (str.toUpperCase().startsWith('PR') && str.length > 2) {
      str = 'ST${str.substring(2)}';
    }
    return str;
  }

  /// Extracts the clean Site Name (e.g. 'AbineshHouse') from any input string.
  static String extractSiteName(dynamic input, {String? siteId}) {
    if (input == null) return '';
    String str = input.toString().trim();
    final cleanId = siteId ?? extractSiteId(str);

    if (str.contains(' — ')) {
      final parts = str.split(' — ');
      if (parts.length > 1) {
        return parts.sublist(1).join(' ').trim();
      }
    } else if (str.contains('_')) {
      final parts = str.split('_');
      if (parts.length > 1 && (parts.first.startsWith('ST') || parts.first.startsWith('PR'))) {
        return parts.sublist(1).join('_').trim();
      }
    }

    if (cleanId.isNotEmpty && str.toLowerCase().startsWith(cleanId.toLowerCase())) {
      str = str.substring(cleanId.length).trim();
      str = str.replaceAll(RegExp(r'^_+|^ +'), '').trim();
    }

    return str;
  }
}

extension _StringExtension on String {
  bool equalsIgnoreCase(String other) => toLowerCase() == other.toLowerCase();
}
