import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/supabase_provider.dart';
import 'membership_identity.dart';
import 'membership_original_image.dart';

import 'membership_catalog.dart';
import 'membership_media_view.dart';
import 'membership_pack_inventory.dart';
import 'membership_pack_controls.dart';
import '../store/premium_cosmetics.dart';
import '../store/cosmetic_media_view.dart';

/// Asset-level preview of a selected VIP/SVIP set.
/// This is intentionally NOT a proof of ownership or of a working room effect.
class MembershipPackGallery extends ConsumerWidget {
  const MembershipPackGallery(
      {super.key, required this.presentation, this.inline = false});

  final MembershipPresentation presentation;
  final bool inline;

  static const _gold = Color(0xfff0d28b);
  static const _navy = Color(0xff0d1430);

  List<_PackSlot> _parts() {
    final parts =
        MembershipPackInventory.forTier(presentation.kind, presentation.tier);
    return [
      _PackSlot('Avatar frame', artwork: parts[1], category: 'Avatar Frame'),
      _PackSlot('Membership badge',
          media: presentation.badge, category: 'Royal Badge'),
      _PackSlot('Profile card',
          artwork: MembershipPackInventory.profileCard(
              presentation.kind, presentation.tier),
          category: 'Profile Card'),
      _PackSlot('Profile decoration',
          artwork: parts[6], category: 'Profile Decoration'),
      _PackSlot('Membership medal',
          artwork: MembershipPackInventory.medal(
              presentation.kind, presentation.tier),
          category: 'Royal Badge'),
      _PackSlot('ID nameplate', artwork: parts[2], category: 'ID Frame'),
      presentation.entrance != null
          ? _PackSlot('Room entrance animation',
              media: presentation.entrance, category: 'Rides')
          : _PackSlot('Room entrance animation',
              artwork: parts[3], category: 'Rides'),
      _PackSlot('Chat bubble', artwork: parts[4], category: 'Chat Bubble'),
      _PackSlot('Mic animation', artwork: parts[5], category: 'Mic Wave'),
      _PackSlot('Room background', artwork: parts[7]),
    ];
  }

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
          key: ValueKey(
              'membership-original-${presentation.kind}-${presentation.tier}-${artwork.title}'),
          media: CosmeticMedia(
            'membership-${presentation.kind}-${presentation.tier}-${artwork.title}',
            slot.category ?? 'Preview',
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
            errorBuilder: (_, __, ___) => const Text(
                'Asset could not be loaded',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 11)),
          );
      if (artwork.otherSide != null) {
        return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Flexible(child: image(artwork.path!)),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(
                  '${presentation.kind.toUpperCase()} ${presentation.tier}',
                  style: const TextStyle(
                      color: _gold,
                      fontSize: 10,
                      fontWeight: FontWeight.bold))),
          Flexible(child: image(artwork.otherSide!)),
        ]);
      }
      return MembershipOriginalImage(artwork: artwork);
    }
    return const Center(
        child: Text('Not provided',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 12)));
  }

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
              SizedBox(
                  height: 245,
                  width: double.infinity,
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
  Widget build(BuildContext context, WidgetRef ref) {
    final slots = _parts();
    final available = slots.where((s) => s.available).length;
    final label = presentation.kind.toUpperCase();
    final id = ref.watch(sessionSupabaseProvider).userId;
    final state =
        id == null ? null : ref.watch(effectiveMembershipProvider(id));
    final status = state?.hasError == true ? null : state?.valueOrNull;
    final eligible =
        status?.eligible(presentation.kind, presentation.tier) == true;
    final selected = status?.packKind == presentation.kind &&
        status?.packTier == presentation.tier;
    final contents = <Widget>[
      Text('$label ${presentation.tier} · Full package',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontWeight: FontWeight.w800, fontSize: 21, color: _gold)),
      const SizedBox(height: 6),
      Text('$available of ${slots.length} original components available',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 12)),
      const SizedBox(height: 14),
      if (!inline) ...[
        MembershipPackControls(
            kind: presentation.kind, tier: presentation.tier),
        const SizedBox(height: 14),
      ],
      LayoutBuilder(
          builder: (context, layout) => GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: slots.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: layout.maxWidth >= 600 ? 4 : 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  mainAxisExtent: 190 +
                      (MediaQuery.textScalerOf(context).scale(12) - 12) * 5),
              itemBuilder: (context, index) {
                final slot = slots[index];
                final applied = selected &&
                    slot.category != null &&
                    status?.hasSlot(slot.category!) == true &&
                    slot.available;
                final stateLabel = !slot.available
                    ? 'Missing original'
                    : applied
                        ? 'Applied'
                        : slot.title == 'Room background' && eligible
                            ? 'Apply in your room'
                            : eligible
                                ? 'Available'
                                : 'Locked';
                return InkWell(
                    key: ValueKey(
                        'pack-${presentation.kind}-${presentation.tier}-$index'),
                    onTap: slot.available ? () => _expand(context, slot) : null,
                    child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: const Color(0xff1c2543),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: applied
                                    ? const Color(0xff68dab2)
                                    : slot.available
                                        ? _gold.withValues(alpha: .4)
                                        : Colors.white12)),
                        child: Column(children: [
                          Expanded(
                              child: Center(
                                  child: slot.available
                                      ? _media(slot)
                                      : const Icon(Icons.hide_image_outlined,
                                          color: Colors.white24, size: 28))),
                          const SizedBox(height: 6),
                          Text(slot.title,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: _gold,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(stateLabel,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              style: TextStyle(
                                  color: applied
                                      ? const Color(0xff68dab2)
                                      : Colors.white60,
                                  fontSize: 10)),
                          if (slot.available)
                            const Text('Tap to preview',
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 9)),
                        ])));
              })),
      const SizedBox(height: 12),
      const Text(
          'Room backgrounds are applied separately by the room owner. Missing originals are not included.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 11)),
    ];
    return Container(
        color: _navy,
        child: inline
            ? Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: contents))
            : SafeArea(
                top: false,
                child: ListView(
                    padding: const EdgeInsets.all(16), children: contents)));
  }
}

class _PackSlot {
  const _PackSlot(this.title, {this.media, this.artwork, this.category});
  final String title;
  final String? category;
  final MembershipMedia? media;
  final MembershipPackArtwork? artwork;
  bool get available => media != null || (artwork?.available ?? false);
}
