import 'package:flutter/material.dart';

import '../rocket/room_rocket_playback.dart';
import '../rocket/room_rocket_widgets.dart';
import 'room_diamond_repository.dart';

/// Legacy Flutter names remain only for compatibility with older overlays.
/// The original Diamond artwork and animation code have been retired.
class RoomDiamondSheet extends StatelessWidget {
  const RoomDiamondSheet({super.key, this.roomId});
  final String? roomId;

  @override
  Widget build(BuildContext context) => RoomRocketSheet(roomId: roomId);
}

/// Historical call sites use the same server-authoritative Rocket host.
class RoomDiamondHost extends StatelessWidget {
  const RoomDiamondHost({
    super.key,
    required this.roomId,
    required this.enabled,
    required this.child,
  });

  final String roomId;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) => RoomRocketHost(
        roomId: roomId,
        enabled: enabled,
        child: child,
        playbackBuilder: (event, finished) => DiamondBurst(
          key: ValueKey(event.id),
          event: event,
          onFinished: finished,
        ),
      );
}

/// Compatibility adapter: uses the real VAP renderer, not a Diamond burst.
class DiamondBurst extends StatelessWidget {
  const DiamondBurst({
    super.key,
    required this.event,
    required this.onFinished,
  });

  final DiamondBlastEvent event;
  final VoidCallback onFinished;

  @override
  Widget build(BuildContext context) => RoomRocketPlayback(
        stage: event.stage,
        targetCoins: diamondTargets[event.stage],
        onFinished: onFinished,
      );
}
