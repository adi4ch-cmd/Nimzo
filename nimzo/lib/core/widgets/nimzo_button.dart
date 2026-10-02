import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/radius.dart';

class NimzoButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool outlined;
  const NimzoButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2))
        : Text(label);
    const shape = RoundedRectangleBorder(borderRadius: Rad.md);
    const size = Size.fromHeight(50);
    final action = loading ? null : onPressed;
    return outlined
        ? OutlinedButton(
            onPressed: action,
            style: OutlinedButton.styleFrom(
                minimumSize: size,
                shape: shape,
                foregroundColor: NimzoColors.text,
                side: const BorderSide(color: NimzoColors.border)),
            child: child)
        : FilledButton(
            onPressed: action,
            style: FilledButton.styleFrom(
                minimumSize: size,
                shape: shape,
                backgroundColor: NimzoColors.primary),
            child: child);
  }
}
