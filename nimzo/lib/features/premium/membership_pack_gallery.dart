import 'package:flutter/material.dart';

import 'membership_catalog.dart';
import 'membership_media_view.dart';
import 'membership_pack_inventory.dart';
import 'membership_pack_runtime.dart';
import '../store/premium_cosmetics.dart';
import '../store/cosmetic_media_view.dart';

/// Asset-level preview of a selected VIP/SVIP set.
/// This is intentionally NOT a proof of ownership or of a working room effect.
class MembershipPackGallery extends StatelessWidget {
  const MembershipPackGallery({super.key, required this.presentation});

  final MembershipPresentation presentation;

  static const _gold = Color(0xfff0d28b);
  static const _navy = Color(0xff0d1430);

  List<_PackSlot> _parts() => <_PackSlot>[
        _PackSlot('Tier hero', media: presentation.hero),
        _PackSlot('Membership badge', media: presentation.badge),
        _PackSlot('Membership card', media: presentation.card),
        _PackSlot('Room entrance animation', media: presentation.entrance),
        for (final artwork in MembershipPackInventory.forTier(
            presentation.kind, presentation.tier))
          _PackSlot(artwork.title, artwork: artwork),
      ];

  Widget _media(_PackSlot slot, {bool expanded = false}) {
    final artwork = slot.artwork;
    if (slot.media != null) {
      return MembershipMediaView(
        key: ValueKey('pack-media:${slot.media!.sha256}:$expanded'),
        media: slot.media!,
        fit: BoxFit.contain,
        animate: expanded && slot.title == 'Room entrance animation',
      );
    }
    if (artwork?.available == true) {
      if (artwork!.animated) {
        return CosmeticMediaView(
          key: ValueKey('membership-original-${presentation.kind}-${presentation.tier}-${artwork.title}'),
          media: CosmeticMedia(
            'membership-${presentation.kind}-${presentation.tier}-${artwork.title}',
            artwork.title.contains('entry') ? 'Room Entry' : 'Mic Wave',
            artwork.title,
            artwork.path!,
            CosmeticMediaKind.svga,
            thumbnail: artwork.thumbnail,
          ),
          animate: expanded,
          fit: BoxFit.contain,
        );
      }
      Widget image(String path) => Image.asset(
            path,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                const Text('Asset could not be loaded',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
          );
      if (artwork!.otherSide != null) {
        return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Flexible(child: image(artwork.path!)),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text('${presentation.kind.toUpperCase()} ${presentation.tier}',
                  style: const TextStyle(
                      color: _gold,
                      fontSize: 10,
                      fontWeight: FontWeight.bold))),
          Flexible(child: image(artwork.otherSide!)),
        ]);
      }
      return image(artwork.path!);
    }
    return const Center(
        child: Text('Not provided',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 12)));
  }

  Widget _nativeTile(String label, Widget child) => Container(
    width: 148,
    height: 116,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: const Color(0xff1c2543),
      border: Border.all(color: _gold.withValues(alpha: .34)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(children: [
      Expanded(child: Center(child: child)),
      const SizedBox(height: 6),
      Text(label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _gold, fontSize: 11)),
    ]),
  );

  Widget _nativePreview(MembershipPackTheme theme) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('NIMZO native live cosmetics',
          style: TextStyle(
            color: _gold, fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(height: 5),
      const Text(
          'These are functional NIMZO-drawn styles. They are separate from original media files listed below and appear only with server-verified membership.',
          style: TextStyle(color: Colors.white60, fontSize: 11)),
      const SizedBox(height: 10),
      Wrap(spacing: 9, runSpacing: 9, children: [
        _nativeTile('Profile / mic frame',
          Container(
            width: 61, height: 61,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: theme.gradient(),
              boxShadow: [
                BoxShadow(color: theme.light.withValues(alpha: .4),
                    blurRadius: 7),
              ]),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: const CircleAvatar(
                backgroundColor: Color(0xff22243e),
                child: Icon(Icons.person, color: Colors.white70)),
            ),
          )),
        _nativeTile('ID nameplate',
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xff161b32),
              border: Border.all(color: theme.light),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text('NIMZO  ·  ${theme.label}',
              style: const TextStyle(
                color: Colors.white, fontSize: 11,
                fontWeight: FontWeight.w800)),
          )),
        _nativeTile('Chat decoration',
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              gradient: theme.gradient(),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xff172034),
                borderRadius: BorderRadius.circular(11)),
              child: const Text('Welcome!',
                style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
          )),
        _nativeTile('Room welcome animation',
          SizedBox(
            height: 76,
            child: MembershipPackEntranceBanner(theme: theme),
          )),
      ]),
      const SizedBox(height: 20),
    ],
  );

  Future<void> _expand(BuildContext context, _PackSlot slot) =>
      showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: _navy,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(slot.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: _gold, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SizedBox(height: 245, width: double.infinity,
                  child: _media(slot, expanded: true)),
              const SizedBox(height: 12),
              TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close')),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final slots = _parts();
    final available = slots.where((slot) => slot.available).length;
    final label = presentation.kind.toUpperCase();
    return Container(
      color: _navy,
      child: SafeArea(
        top: false,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Center(
              child: Container(
                  width: 46,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white38,
                    borderRadius: BorderRadius.circular(9),
                  ))),
          const SizedBox(height: 14),
          Text('$label ${presentation.tier} · Set contents',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 23, color: _gold)),
          const SizedBox(height: 6),
          Text('$available of ${slots.length} visual components available',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          const Text(
              'Only original assets matching this exact VIP/SVIP level are shown. Different source APKs are allowed; different levels are not. Missing parts remain empty. Membership access is confirmed by the server.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 18),
          _nativePreview(MembershipPackTheme.forTier(
              presentation.kind, presentation.tier)),
          const Text('Original asset inventory',
              style: TextStyle(
                color: _gold, fontWeight: FontWeight.w800,
                fontSize: 16)),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, layout) {
            final count = layout.maxWidth >= 600 ? 3 : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: slots.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: count,
                crossAxisSpacing: 9,
                mainAxisSpacing: 9,
                childAspectRatio: .91,
              ),
              itemBuilder: (context, index) {
                final slot = slots[index];
                return InkWell(
                  key: ValueKey('pack-${presentation.kind}-${presentation.tier}-${index}'),
                  onTap: slot.available ? () => _expand(context, slot) : null,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xff1c2543),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: slot.available
                              ? _gold.withValues(alpha: .45)
                              : Colors.white12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(9),
                      child: Column(children: [
                        Expanded(child: Center(child: _media(slot))),
                        const SizedBox(height: 8),
                        Text(slot.title,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: _gold,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                        if (slot.artwork?.available == true)
                          Text(slot.artwork!.source,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 9)),
                      ]),
                    ),
                  ),
                );
              },
            );
          }),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}

class _PackSlot {
  const _PackSlot(this.title, {this.media, this.artwork});
  final String title;
  final MembershipMedia? media;
  final MembershipPackArtwork? artwork;
  bool get available => media != null || (artwork?.available ?? false);
}
