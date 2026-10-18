import 'package:flutter/material.dart';

import 'hall_of_fame_vap_overlay.dart';

/// Profile/Moment VAP playback starts only after send_gift/related RPC
/// succeeds. No fake or static fallback, no coin-price overlay.
void showSettledPersonalVapGiftOverlay(
  BuildContext context, {
  required String source,
  required String giftName,
  required String recipientName,
  required int quantity,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  late OverlayEntry entry;
  var removed = false;
  void dismiss() {
    if (removed) return;
    removed = true;
    entry.remove();
    entry.dispose();
  }

  entry = OverlayEntry(
    builder: (_) => HallOfFameVapOverlay(
      source: source,
      giftName: giftName,
      sender: 'You',
      recipient: recipientName,
      quantity: quantity,
      onFinished: dismiss,
    ),
  );
  overlay.insert(entry);
}
