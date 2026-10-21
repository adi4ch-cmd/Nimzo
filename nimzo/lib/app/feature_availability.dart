import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Legacy membership routes are retired and intentionally not registered.
/// New entitlements/screens must be implemented as a separate fresh feature.
bool isComingSoonLocation(String location) {
  final route = Uri.parse(location).path;
  return const <String>{}.contains(route);
}

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
