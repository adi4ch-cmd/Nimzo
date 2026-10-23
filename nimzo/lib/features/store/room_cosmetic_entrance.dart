import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/supabase_provider.dart';
import '../rooms/presentation/room_controller.dart';
import '../premium/membership_identity.dart';
import '../premium/membership_status.dart';
import '../premium/membership_catalog.dart';
import '../premium/membership_media_view.dart';
import '../premium/membership_pack_inventory.dart';
import 'premium_cosmetics.dart';
import 'store_visual_equipment.dart';
import 'cosmetic_media_view.dart';

/// Only newly confirmed occupants, never the historical roster. Queue identities
/// rather than authorized media: entitlement is rechecked at playback time.
class RoomCosmeticEntrance extends ConsumerStatefulWidget {
  const RoomCosmeticEntrance({super.key, required this.roomId});
  final String roomId;
  @override
  ConsumerState<RoomCosmeticEntrance> createState() =>
      _RoomCosmeticEntranceState();
}

class _RoomCosmeticEntranceState extends ConsumerState<RoomCosmeticEntrance>
    with WidgetsBindingObserver {
  Set<String>? previous;
  final queue = Queue<String>();
  CosmeticMedia? active;
  MembershipMedia? remote;
  Timer? watchdog;
  ProviderSubscription<AsyncValue<MembershipStatus?>>? entitlementSubscription;
  late ProviderSubscription<AsyncValue<List<String>>> membersSubscription;
  int generation = 0, epoch = 0;
  bool loading = false;

  void _enqueue(List<String> ids) {
    for (final id in ids.take(20)) {
      if (queue.length < 10) queue.add(id);
    }
    if (active == null && remote == null && !loading) unawaited(_next());
  }

  Future<void> _next() async {
    if (!mounted || loading) return;
    watchdog?.cancel();
    entitlementSubscription?.close();
    entitlementSubscription = null;
    final requestEpoch = epoch;
    final playback = ++generation;
    setState(() {
      active = null;
      remote = null;
      loading = true;
    });
    while (queue.isNotEmpty) {
      final id = queue.removeFirst();
      if (previous?.contains(id) != true) continue;
      try {
        String? kind;
        var tier = 0;
        entitlementSubscription?.close();
        ref.invalidate(effectiveMembershipProvider(id));
        entitlementSubscription =
            ref.listenManual(effectiveMembershipProvider(id), (_, state) {
          final current = state.valueOrNull;
          if (!loading &&
              kind != null &&
              generation == playback &&
              (state.hasError ||
                  current == null ||
                  !current.hasSlot('Rides') ||
                  current.packKind != kind ||
                  current.packTier != tier)) unawaited(_next());
        });
        MembershipStatus? member;
        try {
          member = await ref.read(effectiveMembershipProvider(id).future);
        } catch (_) {
          /* Existing Store rides remain independent of membership. */
        }
        if (!mounted || epoch != requestEpoch) return;
        if (MediaQuery.disableAnimationsOf(context)) continue;
        CosmeticMedia? media;
        MembershipMedia? approved;
        kind = member?.hasSlot('Rides') == true ? member!.packKind : null;
        tier = kind == null ? 0 : member!.packTier;
        if (kind != null) {
          try {
            final presentations =
                await ref.read(membershipPresentationsProvider.future);
            final matches = presentations.where((p) =>
                p.kind == kind &&
                p.tier == tier &&
                p.benefits.contains('room_entry'));
            if (matches.isNotEmpty) approved = matches.first.entrance;
          } catch (_) {
            /* Bundled exact-tier originals remain usable offline. */
          }
          final art = MembershipPackInventory.forTier(kind, tier)[3];
          if (approved == null && art.animated)
            media = CosmeticMedia(
                'membership-entry-$kind-$tier',
                'Rides',
                'Original membership entrance',
                art.path!,
                CosmeticMediaKind.svga);
        } else {
          media = (await ref
              .refresh(storeVisualEquipmentProvider(id).future))['Rides'];
        }
        if (!mounted || epoch != requestEpoch) return;
        if (kind != null) {
          final confirmed = ref.read(effectiveMembershipProvider(id));
          member = confirmed.valueOrNull;
          if (confirmed.hasError ||
              confirmed.isLoading ||
              member == null ||
              !member.hasSlot('Rides') ||
              member.packKind != kind ||
              member.packTier != tier) continue;
        }
        if (previous?.contains(id) != true ||
            (kind != null && member?.hasSlot('Rides') != true)) continue;
        if (media == null && approved == null) continue;
        setState(() {
          active = media;
          remote = approved;
          loading = false;
        });
        if (kind == null) {
          entitlementSubscription?.close();
          entitlementSubscription = null;
        }
        var timeout = const Duration(seconds: 15);
        final expiry = kind == 'vip'
            ? member?.vipExpiresAt
            : kind == 'svip'
                ? member?.svipExpiresAt
                : null;
        if (expiry != null) {
          final remaining = expiry.difference(member!.serverNow);
          if (remaining < timeout) timeout = remaining;
        }
        watchdog = Timer(timeout.isNegative ? Duration.zero : timeout,
            () => unawaited(_next()));
        return;
      } catch (_) {/* Appearance failures must never block room entry. */}
    }
    if (mounted && epoch == requestEpoch) {
      entitlementSubscription?.close();
      entitlementSubscription = null;
      setState(() => loading = false);
    }
  }

  void _reset({bool forgetRoster = true}) {
    epoch++;
    generation++;
    watchdog?.cancel();
    entitlementSubscription?.close();
    entitlementSubscription = null;
    if (forgetRoster) previous = null;
    active = null;
    remote = null;
    loading = false;
    queue.clear();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscribe();
    ref.listenManual(currentUserIdProvider, (old, next) {
      if (old != next) setState(_reset);
    });
  }

  @override
  void dispose() {
    _reset();
    membersSubscription.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && mounted)
      setState(() => _reset(forgetRoster: false));
  }

  @override
  void didUpdateWidget(covariant RoomCosmeticEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomId != widget.roomId) {
      membersSubscription.close();
      _reset();
      _subscribe();
    }
  }

  void _subscribe() {
    membersSubscription =
        ref.listenManual(roomMemberIdsProvider(widget.roomId), (_, state) {
      final ids = state.valueOrNull;
      if (ids == null) return;
      final old = previous;
      previous = ids.toSet();
      final me = ref.read(currentUserIdProvider);
      final joined = old == null
          ? ids.where((id) => id == me).toList()
          : ids.where((id) => !old.contains(id)).toList();
      if (joined.isNotEmpty) _enqueue(joined);
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    final media = active, approved = remote;
    final playback = generation;
    if (media == null && approved == null) return const SizedBox.shrink();
    void finish() {
      if (generation == playback) unawaited(_next());
    }

    return IgnorePointer(
        child: Center(
            child: AspectRatio(
                aspectRatio: 750 / 600,
                child: approved != null
                    ? MembershipMediaView(
                        key: ValueKey('$generation-${approved.sha256}'),
                        media: approved,
                        animate: true,
                        onFinished: finish)
                    : CosmeticMediaView(
                        key: ValueKey('$generation-${media!.id}'),
                        media: media,
                        onFinished: finish))));
  }
}
