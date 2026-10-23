import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../premium/membership_identity.dart';
import '../premium/membership_pack_inventory.dart';
import '../premium/membership_pack_runtime.dart';
import '../premium/membership_original_image.dart';
import '../store/store_visual_equipment.dart';
import '../store/premium_cosmetics.dart';
import '../store/cosmetic_media_view.dart';

/// Shows only currently equipped, server-backed items. VIP/SVIP originals
/// always stay in their exact kind and tier; Store overrides win per slot.
class ProfileEquippedProps extends ConsumerWidget {
  const ProfileEquippedProps({super.key, required this.userId});

  final String userId;

  Widget _membershipArt(MembershipPackArtwork art, {bool expanded = false}) {
    if (art.animated) {
      return CosmeticMediaView(
        media: CosmeticMedia(
          'profile-equipped-${art.sourceKind}-${art.sourceTier}-${art.title}',
          art.title,
          art.title,
          art.path!,
          CosmeticMediaKind.svga,
        ),
        animate: expanded,
        fit: BoxFit.contain,
      );
    }
    return MembershipOriginalImage(artwork: art);
  }

  Widget _tile(
    BuildContext context, {
    required String title,
    required Widget preview,
    required Widget expandedPreview,
  }) =>
      SizedBox(
        width: 93,
        child: InkWell(
          onTap: () => showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(title, style: const TextStyle(fontSize: 16)),
              content: SizedBox(
                width: 250,
                height: 235,
                child: Center(child: expandedPreview),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xfff7f2e9),
              border: Border.all(color: const Color(0xffdac596)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 52, width: 81, child: Center(child: preview)),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xff493b21),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(effectiveMembershipProvider(userId));
    final status = state.hasError ? null : state.valueOrNull;
    final theme = MembershipPackTheme.fromStatus(status);
    final equipped =
        ref.watch(storeVisualEquipmentProvider(userId)).valueOrNull ??
            <String, CosmeticMedia>{};
    final tiles = <Widget>[];

    if (theme != null) {
      final parts = MembershipPackInventory.forTier(theme.kind, theme.tier);
      final originals = <String, MembershipPackArtwork>{
        'Avatar Frame': parts[1],
        'ID Frame': parts[2],
        'Royal Badge': MembershipPackInventory.medal(theme.kind, theme.tier),
        'Profile Card':
            MembershipPackInventory.profileCard(theme.kind, theme.tier),
        'Profile Decoration': parts[6],
        'Chat Bubble': parts[4],
        'Mic Wave': parts[5],
        'Rides': parts[3],
      };
      for (final entry in originals.entries) {
        if (status?.hasSlot(entry.key) != true ||
            !entry.value.available ||
            equipped.containsKey(entry.key)) {
          continue;
        }
        tiles.add(_tile(
          context,
          title: entry.key,
          preview: _membershipArt(entry.value),
          expandedPreview: _membershipArt(entry.value, expanded: true),
        ));
      }
    }

    for (final entry in equipped.entries) {
      tiles.add(_tile(
        context,
        title: entry.key,
        preview: CosmeticMediaView(
          media: entry.value,
          animate: false,
          fit: BoxFit.contain,
        ),
        expandedPreview: CosmeticMediaView(
          media: entry.value,
          animate: true,
          fit: BoxFit.contain,
        ),
      ));
    }

    if (tiles.isEmpty) return const SizedBox.shrink();
    return Padding(
      key: const ValueKey('profile-equipped-props'),
      padding: const EdgeInsets.only(top: 12, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            theme == null ? 'Equipped props' : 'Equipped ${theme.label} props',
            style: const TextStyle(
              color: Color(0xff352a42),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: tiles),
        ],
      ),
    );
  }
}
