import 'package:flutter/material.dart';

class ConfirmDialog extends StatelessWidget {
  /// A dialog that asks the user to confirm an action.
  final String title;
  final String content;
  final String confirmText;
  final String cancelText;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.content,
    required this.confirmText,
    required this.cancelText,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () {
            onCancel();
          },
          child: Text(cancelText),
        ),
        TextButton(
          onPressed: () {
            onConfirm();
          },
          child: Text(confirmText),
        ),
      ],
    );
  }
}
