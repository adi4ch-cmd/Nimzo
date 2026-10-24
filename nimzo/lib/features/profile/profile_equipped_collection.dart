import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../premium/membership_identity.dart';
import '../premium/membership_pack_inventory.dart';
import '../premium/membership_original_image.dart';
import '../store/store_visual_equipment.dart';
import '../store/premium_cosmetics.dart';
import '../store/cosmetic_media_view.dart';
import 'profile_collections.dart';

class EquippedProfileCollectible {
  const EquippedProfileCollectible(this.media, this.label, {this.original});
  final CosmeticMedia media;
  final String label;
  final MembershipPackArtwork? original;
  bool get membership => original != null;
}

/// Shows only publicly verified, currently equipped cosmetics. A membership
/// preview never manufactures Store ownership or legacy collectible records.
final profileEquippedCollectionProvider = Provider.autoDispose
    .family<EquippedProfileCollectible?, (String, ProfileCollection)>(
        (ref, args) {
  final state = ref.watch(effectiveMembershipProvider(args.$1));
  final status = state.hasError ? null : state.valueOrNull;
  final frame = args.$2 == ProfileCollection.frame;
  final slot = frame ? 'Avatar Frame' : 'Rides';
  if (status?.packKind != null && status!.hasSlot(slot)) {
    final art = MembershipPackInventory.forTier(
        status.packKind!, status.packTier)[frame ? 1 : 3];
    if (art.available) {
      return EquippedProfileCollectible(
          CosmeticMedia(
              'profile-pack-${status.packKind}-${status.packTier}-$slot',
              slot,
              art.title,
              art.path!,
              art.animated ? CosmeticMediaKind.svga : CosmeticMediaKind.image),
          '${status.packKind!.toUpperCase()} ${status.packTier} ${frame ? 'frame' : 'entrance'} · Applied',
          original: art);
    }
  }
  final equipment = ref.watch(storeVisualEquipmentProvider(args.$1));
  final media = equipment.hasError ? null : equipment.valueOrNull?[slot];
  return media == null
      ? null
      : EquippedProfileCollectible(media, '${media.name} · Equipped');
});

class ProfileEquippedCollectionTile extends StatelessWidget {
  const ProfileEquippedCollectionTile({super.key, required this.item});
  final EquippedProfileCollectible item;
  Widget _media({bool animate = false}) => item.original?.animated == false
      ? MembershipOriginalImage(artwork: item.original!)
      : CosmeticMediaView(
          media: item.media, animate: animate, fit: BoxFit.contain);

  @override
  Widget build(BuildContext context) => SizedBox(
      width: 130,
      child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => showDialog<void>(
              context: context,
              builder: (context) => Dialog(
                  child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(item.label, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        SizedBox(
                            height: 220,
                            width: 280,
                            child: _media(animate: true)),
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close')),
                      ])))),
          child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: const Color(0xff172039),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xffd9b867))),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(height: 76, width: 100, child: _media()),
                const SizedBox(height: 5),
                Text(item.label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Color(0xfff0d28b), fontSize: 11)),
              ]))));
}
