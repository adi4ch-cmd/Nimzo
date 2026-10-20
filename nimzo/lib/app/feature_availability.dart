import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// VIP and SVIP are available as verified premium media previews.
/// No financial entitlements are granted by opening these routes.
bool isComingSoonLocation(String location) => const <String>{}
    .contains(Uri.parse(location).path.replaceFirst(RegExp(r'/+

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
), ''));

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
