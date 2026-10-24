import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../premium/membership_identity.dart';
import '../../premium/membership_pack_inventory.dart';
import '../../premium/membership_pack_runtime.dart';
import '../../premium/membership_original_image.dart';
import '../../store/store_visual_equipment.dart';
import '../../store/cosmetic_media_view.dart';

/// Two bounded rows for a 5-column voice-room seat. Full-size nameplates and
/// animated Store media must never cover an adjacent microphone seat.
class RoomSeatIdentity extends ConsumerWidget {
  const RoomSeatIdentity({
    super.key,
    required this.userId,
    required this.displayName,
    required this.textColor,
  });

  final String userId;
  final String displayName;
  final Color textColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(effectiveMembershipProvider(userId));
    final status = membership.hasError ? null : membership.valueOrNull;
    final theme = MembershipPackTheme.fromStatus(status);
    final nameplate = theme != null && status?.hasSlot('ID Frame') == true
        ? MembershipPackInventory.forTier(theme.kind, theme.tier)[2]
        : null;
    final cosmetics =
        ref.watch(storeVisualEquipmentProvider(userId)).valueOrNull;
    final storeNameplate = cosmetics?['ID Frame'];
    final royalBadge = cosmetics?['Royal Badge'];

    return SizedBox(
      key: ValueKey('room-seat-identity-$userId'),
      height: 33,
      width: double.infinity,
      child: ClipRect(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (theme != null)
              SizedBox(
                height: 14,
                width: double.infinity,
                child: nameplate?.available == true
                    ? MembershipOriginalImage(artwork: nameplate!)
                    : Center(
                        child: Text(
                          theme.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xffffd99a),
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            height: 1,
                          ),
                        ),
                      ),
              ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (storeNameplate != null)
                    IgnorePointer(
                      child: CosmeticMediaView(
                        media: storeNameplate,
                        animate: false,
                        fit: BoxFit.fill,
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            height: 1,
                            shadows: const [
                              Shadow(color: Color(0xaa000000), blurRadius: 2),
                            ],
                          ),
                        ),
                      ),
                      if (royalBadge != null)
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: IgnorePointer(
                            child: CosmeticMediaView(
                              media: royalBadge,
                              animate: false,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
