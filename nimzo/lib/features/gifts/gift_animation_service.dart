import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Plays a short, restrained animation when a gift event arrives.
/// Purely visual: the transaction already happened server-side.
class GiftAnimationService {
  static OverlayEntry? _entry;

  static void play(BuildContext context, String label, {String? giftId, int quantity = 1}) {
    _entry?.remove();
    final overlay = Overlay.of(context);
    late final OverlayEntry e;
    e = OverlayEntry(builder: (_) => _GiftBurst(label: label, giftId: giftId, quantity: quantity, onDone: () { e.remove(); if (_entry == e) _entry = null; }));
    _entry = e;
    overlay.insert(e);
  }
}

String? _assetFor(String? id) {
  const map = <String, String>{
    'eb336fe8-8538-4f37-aa4d-9fac97ab4dfb': 'assets/gifts/rose.svg',
    'c4ae46dd-8ff1-49ae-bcfb-cf5f1885e330': 'assets/gifts/heart.svg',
    'cd7f0f74-003d-476b-be50-f7aed78ad5b9': 'assets/gifts/kiss.svg',
    '7b73f7e7-ed4a-4c44-8873-54bd9e0d2659': 'assets/gifts/coffee.svg',
    '2aa6c5cf-1b4c-423b-a3c3-bfbb6f4ea037': 'assets/gifts/crown.svg',
    'bda8bde4-6a1e-4c79-8998-2dfb866bd0c1': 'assets/gifts/diamond.svg',
    '99faac6c-933c-4c08-8026-08c39227751e': 'assets/gifts/rocket.svg',
    '35e4c570-cb02-4466-ae86-d670b3fb05ab': 'assets/gifts/car.svg',
    '8f4ebf03-958d-4fda-a699-84dae2fdb274': 'assets/gifts/yacht.svg',
    '75eb2f0f-cdbe-4f41-a8a3-aee3d655e7c0': 'assets/gifts/jet.svg',
    '1460e83a-5bfb-48b8-85ce-f50171268478': 'assets/gifts/palace.svg',
    'ce25005c-bb88-4e99-9891-e3d89e25e027': 'assets/gifts/dragon.svg',
    'b6fe7c14-ba89-4dec-9517-65660ef1c4a3': 'assets/gifts/phoenix.svg',
  };
  return id == null ? null : map[id];
}

class _GiftBurst extends StatefulWidget {
  final String label;
  final String? giftId;
  final int quantity;
  final VoidCallback onDone;
  const _GiftBurst({required this.label, this.giftId, required this.quantity, required this.onDone});
  @override
  State<_GiftBurst> createState() => _S();
}

class _S extends State<_GiftBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
    ..forward().whenComplete(widget.onDone);
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final t = _c.value;
            final opacity = t < .15 ? t / .15 : t > .8 ? (1 - t) / .2 : 1.0;
            return Align(
              alignment: Alignment(0, .2 - t * .5),
              child: Opacity(
                opacity: opacity.clamp(0, 1),
                child: Transform.scale(
                  scale: .85 + .25 * Curves.easeOut.transform(t.clamp(0, 1)),
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(color: const Color(0xE6111827), borderRadius: BorderRadius.circular(24)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_assetFor(widget.giftId) != null) ...[
                            SvgPicture.asset(_assetFor(widget.giftId)!, width: 42, height: 42),
                            const SizedBox(width: 10),
                          ],
                          Text(widget.label, style: const TextStyle(color: Color(0xFFF5C451), fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
}
