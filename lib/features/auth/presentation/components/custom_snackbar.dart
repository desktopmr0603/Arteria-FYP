import 'package:flutter/material.dart';

class CustomSnackBar {
  /// Displays a floating Snackbar with an icon and a text message.
  /// The snack bar automatically adapts to the app's current ThemeData using `colorScheme.error` as the default background and
  /// `colorScheme.onError` for the icon and text colors.

  static void show(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    IconData icon = Icons.error_outline,
  }) {
    final theme = Theme.of(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: theme.colorScheme.onError),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: theme.colorScheme.onError),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor ?? theme.colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
