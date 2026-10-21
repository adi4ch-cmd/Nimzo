import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Only explicitly unavailable destinations are redirected.
/// Restored membership routes use server capabilities and effective expiry.
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
