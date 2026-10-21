import 'package:flutter/material.dart';
import 'store_live_catalog.dart';

/// Live catalog-backed Store and persistent Backpack only.
/// Retired concept previews are intentionally not shipped.
class RoyalStoreScreen extends StatelessWidget {
  final bool initialBag;
  const RoyalStoreScreen({super.key, this.initialBag = false});

  @override
  Widget build(BuildContext context) =>
      NimzoLiveStore(initialBag: initialBag);
}
