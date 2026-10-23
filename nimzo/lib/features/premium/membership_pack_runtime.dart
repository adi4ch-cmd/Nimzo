import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'membership_identity.dart';
import 'membership_status.dart';
import 'membership_pack_inventory.dart';
import 'membership_original_image.dart';
import 'membership_room_background.dart';
import '../store/premium_cosmetics.dart';
import '../store/cosmetic_media_view.dart';

/// NIMZO-native membership look. These are real Flutter decorations rendered
/// on actual profiles/voice rooms, not claims of missing third-party animation
/// files or additional server privileges.
@immutable
class MembershipPackTheme {
  const MembershipPackTheme({
    required this.kind,
    required this.tier,
    required this.light,
    required this.dark,
  });

  final String kind;
  final int tier;
  final Color light, dark;

  bool get isSvip => kind == 'svip';
  String get label => '${kind.toUpperCase()} $tier';

  static MembershipPackTheme? fromStatus(MembershipStatus? status) {
    if (status == null) return null;
    final tier = status.packTier;
    if (tier <= 0) return null;
    final kind = status.packKind!;
    return forTier(kind, tier);
  }

  /// Theme lookup for static previews; grants no membership privileges.
  static MembershipPackTheme forTier(String kind, int tier) {
    if (kind != 'vip' && kind != 'svip') {
      throw ArgumentError.value(kind, 'kind');
    }
    if (tier <= 0) throw RangeError.value(tier, 'tier');
    const vip = <(Color, Color)>[
      (Color(0xfff2b8de), Color(0xff792358)),
      (Color(0xffa7ccfc), Color(0xff24518b)),
      (Color(0xfff8cb78), Color(0xff7e4613)),
      (Color(0xff9ce8d0), Color(0xff17654e)),
      (Color(0xffa8b5ff), Color(0xff35368b)),
      (Color(0xffc2f5a4), Color(0xff3b7134)),
      (Color(0xffe8b2ff), Color(0xff79318d)),
      (Color(0xffffbd99), Color(0xffa2402e)),
      (Color(0xffffd77b), Color(0xff8c441a)),
      (Color(0xffffeda0), Color(0xff986316)),
    ];
    const svip = <(Color, Color)>[
      (Color(0xfff9c0f0), Color(0xff702b93)),
      (Color(0xffb7dfff), Color(0xff244e99)),
      (Color(0xffffd2a0), Color(0xff8a4213)),
      (Color(0xff91f7e7), Color(0xff12687a)),
      (Color(0xff90c5ff), Color(0xff153c84)),
      (Color(0xffaef5c0), Color(0xff186b4d)),
      (Color(0xffdfb4ff), Color(0xff4a227e)),
      (Color(0xffffc08e), Color(0xff8e2819)),
      (Color(0xffffdc84), Color(0xff86250c)),
      (Color(0xffffefa0), Color(0xff992d10)),
    ];
    final palette = kind == 'svip' ? svip : vip;
    final selected = palette[(tier - 1).clamp(0, palette.length - 1)];
    return MembershipPackTheme(
        kind: kind, tier: tier, light: selected.$1, dark: selected.$2);
  }

  LinearGradient gradient({double opacity = 1}) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          light.withValues(alpha: opacity),
          dark.withValues(alpha: opacity),
          light.withValues(alpha: opacity),
        ],
      );
}

/// Fails closed: only server-returned, expiry-checked membership is used.
class VerifiedMembershipPack extends ConsumerWidget {
  const VerifiedMembershipPack({
    super.key,
    required this.userId,
    required this.builder,
    required this.fallback,
    this.slot,
  });

  final String? userId;
  final Widget Function(MembershipPackTheme theme) builder;
  final Widget fallback;
  final String? slot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = userId;
    if (id == null || id.isEmpty) return fallback;
    final state = ref.watch(effectiveMembershipProvider(id));
    final status = state.hasError ? null : state.valueOrNull;
    if (slot != null && status?.hasSlot(slot!) != true) return fallback;
    final theme = MembershipPackTheme.fromStatus(status);
    if (theme == null) return fallback;
    return builder(theme);
  }
}

class MembershipPackAvatar extends ConsumerWidget {
  const MembershipPackAvatar(
      {super.key,
      required this.userId,
      required this.child,
      required this.size,
      this.speaking = false});
  final String? userId;
  final Widget child;
  final double size;
  final bool speaking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = userId;
    if (id == null || id.isEmpty) return child;
    final state = ref.watch(effectiveMembershipProvider(id));
    final status = state.hasError ? null : state.valueOrNull;
    final theme = MembershipPackTheme.fromStatus(status);
    if (theme == null) return child;
    final parts = MembershipPackInventory.forTier(theme.kind, theme.tier);
    final frame = status!.hasSlot('Avatar Frame') ? parts[1] : null;
    final mic = speaking &&
            status.hasSlot('Mic Wave') &&
            !MediaQuery.disableAnimationsOf(context)
        ? parts[5]
        : null;
    final medal = status.hasSlot('Royal Badge')
        ? MembershipPackInventory.medal(theme.kind, theme.tier)
        : null;
    return SizedBox(
        key: frame?.available == true
            ? ValueKey('membership-pack-avatar-${theme.kind}-${theme.tier}')
            : null,
        width: size,
        height: size,
        child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Padding(
                  padding:
                      EdgeInsets.all(frame?.available == true ? size * .16 : 0),
                  child: child),
              if (frame?.available == true)
                Positioned.fill(
                    child: IgnorePointer(
                        child: MembershipOriginalImage(artwork: frame!))),
              if (mic?.animated == true)
                Positioned.fill(
                    left: -size * .15,
                    right: -size * .15,
                    top: -size * .15,
                    bottom: -size * .15,
                    child: IgnorePointer(
                        child: CosmeticMediaView(
                            media: CosmeticMedia(
                                'membership-mic-${theme.kind}-${theme.tier}',
                                'Mic Wave',
                                '${theme.label} original mic wave',
                                mic!.path!,
                                CosmeticMediaKind.svga),
                            animate: true))),
              if (medal?.available == true)
                Positioned(
                    bottom: -5,
                    right: -5,
                    child: IgnorePointer(
                        child: SizedBox(
                            width: 24,
                            height: 24,
                            child: MembershipOriginalImage(artwork: medal!)))),
            ]));
  }
}

class MembershipPackProfileDecoration extends StatelessWidget {
  const MembershipPackProfileDecoration({super.key, required this.userId});
  final String userId;
  @override
  Widget build(BuildContext context) => VerifiedMembershipPack(
      userId: userId,
      slot: 'Profile Decoration',
      fallback: const SizedBox.shrink(),
      builder: (theme) {
        final art =
            MembershipPackInventory.profileDecoration(theme.kind, theme.tier);
        if (!art.available) return const SizedBox.shrink();
        return IgnorePointer(
            child: CosmeticMediaView(
                media: CosmeticMedia(
                    'profile-decoration-${theme.kind}-${theme.tier}',
                    'Profile Decoration',
                    'Original profile decoration',
                    art.path!,
                    art.animated
                        ? CosmeticMediaKind.svga
                        : CosmeticMediaKind.image),
                animate: !MediaQuery.disableAnimationsOf(context),
                fit: BoxFit.contain));
      });
}

class MembershipPackNameplate extends StatelessWidget {
  const MembershipPackNameplate({
    super.key,
    required this.userId,
    required this.child,
  });
  final String? userId;
  final Widget child;

  @override
  Widget build(BuildContext context) => VerifiedMembershipPack(
        userId: userId,
        slot: 'ID Frame',
        fallback: child,
        builder: (theme) => Container(
          key:
              ValueKey('membership-pack-nameplate-${theme.kind}-${theme.tier}'),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xff161b32),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: theme.light, width: 1),
            boxShadow: [
              BoxShadow(color: theme.dark.withValues(alpha: .5), blurRadius: 3)
            ],
          ),
          child: DefaultTextStyle.merge(
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800),
            child: MembershipPackInventory.forTier(theme.kind, theme.tier)[2]
                        .path !=
                    null
                ? Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    children: [
                      Image.asset(
                        MembershipPackInventory.forTier(
                                theme.kind, theme.tier)[2]
                            .path!,
                        height: 19,
                        width: 62,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Text(theme.label,
                            style: TextStyle(
                                color: theme.light,
                                fontSize: 10,
                                fontWeight: FontWeight.w900)),
                      ),
                      child,
                    ],
                  )
                : child,
          ),
        ),
      );
}

class MembershipPackChatBubble extends StatelessWidget {
  const MembershipPackChatBubble({
    super.key,
    required this.userId,
    required this.child,
  });
  final String? userId;
  final Widget child;

  @override
  Widget build(BuildContext context) => VerifiedMembershipPack(
        userId: userId,
        slot: 'Chat Bubble',
        fallback: child,
        builder: (theme) => Container(
          key: ValueKey('membership-pack-chat-${theme.kind}-${theme.tier}'),
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            gradient: theme.gradient(),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: theme.light.withValues(alpha: .25), blurRadius: 6)
            ],
          ),
          child: Stack(children: [
            if (MembershipPackInventory.forTier(theme.kind, theme.tier)[4]
                .available)
              Positioned.fill(
                  child: IgnorePointer(
                      child: MembershipOriginalImage(
                          artwork: MembershipPackInventory.forTier(
                              theme.kind, theme.tier)[4],
                          fit: BoxFit.fill))),
            Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(12), child: child)),
          ]),
        ),
      );
}

class MembershipPackEntranceBanner extends StatelessWidget {
  const MembershipPackEntranceBanner({super.key, required this.theme});
  final MembershipPackTheme theme;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Align(
          alignment: const Alignment(0, -.6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(seconds: 3),
            builder: (_, progress, child) => Opacity(
              opacity: (progress < .18
                      ? progress / .18
                      : progress > .82
                          ? (1 - progress) / .18
                          : 1)
                  .clamp(0.0, 1.0)
                  .toDouble(),
              child: Transform.translate(
                offset: Offset(0, 25 * (1 - progress) - 24 * progress),
                child: child,
              ),
            ),
            child: DecoratedBox(
              key:
                  ValueKey('membership-pack-entry-${theme.kind}-${theme.tier}'),
              decoration: BoxDecoration(
                gradient: theme.gradient(),
                border: Border.all(color: const Color(0xfffff0be), width: 1.5),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                      blurRadius: 18, color: theme.light.withValues(alpha: .65))
                ],
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  // This is a tier-matched STATIC emblem inside NIMZO's
                  // real entrance transition, not a borrowed MP4/VAP effect.
                  if (MembershipPackInventory.forTier(theme.kind, theme.tier)[3]
                      case final entryArt
                      when !entryArt.animated && entryArt.path != null)
                    SizedBox(
                      width: 58,
                      height: 32,
                      child: Image.asset(
                        entryArt.path!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.auto_awesome,
                            color: Color(0xff28121c),
                            size: 19),
                      ),
                    )
                  else
                    const Icon(Icons.auto_awesome,
                        color: Color(0xff28121c), size: 19),
                  const SizedBox(width: 8),
                  Flexible(
                      child: Text('${theme.label} · Welcome to the room',
                          maxLines: 2,
                          style: const TextStyle(
                              color: Color(0xff180c1e),
                              fontWeight: FontWeight.w900))),
                ]),
              ),
            ),
          ),
        ),
      );
}

/// Compact owner-only room identity. It does not change the user's chosen
/// wallpaper, but adds a real matching membership theme to the room header.
class MembershipPackRoomBanner extends StatelessWidget {
  const MembershipPackRoomBanner({super.key, required this.ownerId});
  final String? ownerId;

  @override
  Widget build(BuildContext context) => VerifiedMembershipPack(
        userId: ownerId,
        slot: 'Room Header',
        fallback: const SizedBox.shrink(),
        builder: (theme) => Semantics(
          label: '${theme.label} room membership theme',
          child: Container(
            key: ValueKey('membership-pack-room-${theme.kind}-${theme.tier}'),
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 24),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              gradient: theme.gradient(opacity: .8),
              border: Border(
                  bottom: BorderSide(color: theme.light.withValues(alpha: .9))),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.auto_awesome,
                  size: 13, color: Color(0xff1d1730)),
              const SizedBox(width: 5),
              Flexible(
                  child: Text('${theme.label}  ·  Royal Voice Room',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xff150e23),
                          fontWeight: FontWeight.w900,
                          fontSize: 11))),
            ]),
          ),
        ),
      );
}

/// Room-owner color atmosphere: a lightweight, transparent branded layer
/// that leaves the existing room wallpaper and touch targets intact.
class MembershipPackRoomAtmosphere extends ConsumerWidget {
  const MembershipPackRoomAtmosphere({
    super.key,
    required this.ownerId,
    required this.child,
    this.allowOriginalBackground = false,
    this.roomId,
  });
  final String? ownerId;
  final Widget child;

  /// Only true for rooms with no user-selected/approved custom wallpaper.
  final bool allowOriginalBackground;
  final String? roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final background = roomId == null
        ? null
        : ref.watch(membershipRoomBackgroundProvider(roomId!)).valueOrNull;
    return VerifiedMembershipPack(
      userId: ownerId,
      slot: 'Room Header',
      fallback: child,
      builder: (theme) => DecoratedBox(
        key: ValueKey('membership-pack-atmosphere-${theme.kind}-${theme.tier}'),
        decoration: BoxDecoration(
          // A room's own wallpaper always wins. In a default room the
          // exact-level VIP 6 original background can be displayed.
          image: background?.kind == theme.kind &&
                  background?.tier == theme.tier &&
                  MembershipPackInventory.forTier(theme.kind, theme.tier)[7]
                          .path !=
                      null
              ? DecorationImage(
                  image: AssetImage(
                      MembershipPackInventory.forTier(theme.kind, theme.tier)[7]
                          .path!),
                  fit: BoxFit.cover,
                )
              : null,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.dark.withValues(alpha: .17),
              Colors.transparent,
              theme.light.withValues(alpha: .11),
            ],
          ),
        ),
        child: child,
      ),
    );
  }
}
