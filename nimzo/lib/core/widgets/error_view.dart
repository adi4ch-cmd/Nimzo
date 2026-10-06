import 'package:flutter/material.dart';

import 'nimzo_button.dart';

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorView({super.key, required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
            child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              SizedBox(
                width: 160,
                child: NimzoButton(label: 'Retry', onPressed: onRetry),
              ),
            ],
          ),
        )),
      );
}
