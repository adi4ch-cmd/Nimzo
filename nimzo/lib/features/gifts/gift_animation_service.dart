import 'package:flutter/material.dart';

/// Plays a short, restrained animation when a gift event arrives.
/// Purely visual: the transaction already happened server-side.
class GiftAnimationService {
  static OverlayEntry? _entry;

  static void play(BuildContext context, String label) {
    _entry?.remove();
    final overlay = Overlay.of(context);
    late final OverlayEntry e;
    e = OverlayEntry(builder: (_) => _GiftBurst(label: label, onDone: () { e.remove(); if (_entry == e) _entry = null; }));
    _entry = e;
    overlay.insert(e);
  }
}

class _GiftBurst extends StatefulWidget {
  final String label;
  final VoidCallback onDone;
  const _GiftBurst({required this.label, required this.onDone});
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
                      child: Text(widget.label, style: const TextStyle(color: Color(0xFFF5C451), fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
}
