import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class FirestoreErrorHandler {
  /// Handles Firestore errors by showing a themed dialog.
  /// If the error contains a link (common for missing indices), it provides
  /// buttons to copy the link or open it directly.
  static void handleError(BuildContext context, dynamic error, {String title = 'Database Error'}) {
    final String errorMessage = error.toString();
    final String? indexUrl = _extractUrl(errorMessage);

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 28),
              const SizedBox(width: 12),
              Text(title),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                indexUrl != null
                    ? 'A required Firestore index is missing. This usually happens after a database structural change.'
                    : 'An unexpected error occurred while communicating with the database.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: Text(
                  indexUrl != null
                      ? 'The index must be created in the Firebase Console to enable this query.'
                      : errorMessage,
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
            ),
            if (indexUrl != null) ...[
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: indexUrl));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Index URL copied to clipboard')),
                    );
                  }
                },
                child: const Text('COPY LINK', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final uri = Uri.parse(indexUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not open link automatically. Please use Copy Link.')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('OPEN CONSOLE'),
              ),
            ] else
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('OK'),
              ),
          ],
        );
      },
    );
  }

  /// Extracts a URL from a string (specifically targeting Firestore index links).
  static String? _extractUrl(String text) {
    final RegExp urlRegExp = RegExp(
      r'https?:\/\/[^\s]+',
      caseSensitive: false,
    );
    final match = urlRegExp.firstMatch(text);
    return match?.group(0);
  }
}
