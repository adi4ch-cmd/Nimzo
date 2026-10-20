import 'dart:async';

import 'package:flutter/material.dart';

import 'gift_artwork.dart';

/// A plain receipt for a settled artwork gift, never a substitute animation.
class GiftArtworkReceipt extends StatefulWidget {
  const GiftArtworkReceipt({
    super.key,
    required this.giftName,
    required this.sender,
    required this.recipient,
    required this.quantity,
    required this.onFinished,
    this.assetPath,
  });

  final String giftName, sender, recipient;
  final int quantity;
  final String? assetPath;
  final VoidCallback onFinished;

  @override
  State<GiftArtworkReceipt> createState() => _GiftArtworkReceiptState();
}

class _GiftArtworkReceiptState extends State<GiftArtworkReceipt> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) widget.onFinished();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Card(
          margin: const EdgeInsets.fromLTRB(12, 64, 12, 0),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: GiftArtwork(
                    name: widget.giftName,
                    assetPath: widget.assetPath,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Artwork gift · ${widget.giftName} × ${widget.quantity}\n'
                    '${widget.sender} → ${widget.recipient}',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
