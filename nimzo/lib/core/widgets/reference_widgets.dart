import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../theme/app_theme.dart';

class NimzoAvatar extends StatelessWidget {
  final String name;
  final String? url;
  final double size;
  const NimzoAvatar({super.key, required this.name, this.url, this.size = 46});
  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: NimzoStyle.primary,
      child: Center(
        child: Text(
          name.trim().isEmpty
              ? 'N'
              : name.trim().characters.first.toUpperCase(),
          maxLines: 1,
          style: TextStyle(
            fontSize: size * .38,
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
    return SizedBox.square(
      dimension: size,
      child: ClipOval(
        child: url == null || url!.isEmpty
            ? fallback
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}

class DataFailure extends StatelessWidget {
  final VoidCallback onRetry;
  final String message;
  const DataFailure({
    super.key,
    required this.onRetry,
    this.message = 'Unable to load this content.',
  });
  @override
  Widget build(BuildContext context) => Padding(
        padding: NimzoStyle.pagePadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.cloudOff, color: NimzoStyle.muted),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
}

class EmptyContent extends StatelessWidget {
  final String message;
  const EmptyContent(this.message, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: NimzoStyle.muted),
        ),
      );
}

class AsyncContent<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T) builder;
  final VoidCallback onRetry;
  const AsyncContent({
    super.key,
    required this.value,
    required this.builder,
    required this.onRetry,
  });
  @override
  Widget build(BuildContext context) => value.when(
        data: builder,
        loading: () => const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => DataFailure(onRetry: onRetry),
      );
}

class ReferenceCard extends StatelessWidget {
  final Widget child;
  const ReferenceCard({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: NimzoStyle.surface,
          borderRadius: BorderRadius.circular(14),
          child: Padding(padding: const EdgeInsets.all(14), child: child),
        ),
      );
}
