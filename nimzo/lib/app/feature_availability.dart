import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// VIP and SVIP remain paused; Store and Backpack are available.
bool isComingSoonLocation(String location) => const {'/vip', '/svip'}
    .contains(Uri.parse(location).path.replaceFirst(RegExp(r'/+$'), ''));

void openAvailableDestination(BuildContext context, String location,
    {bool replace = false}) {
  if (isComingSoonLocation(location)) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Coming soon')));
    return;
  }
  if (replace) {
    context.go(location);
  } else {
    context.push(location);
  }
}
