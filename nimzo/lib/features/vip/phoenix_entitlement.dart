import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/supabase_provider.dart';

/// A short display lease measured against server time, never the phone clock.
class PhoenixEntitlement {
  final int level;
  final Duration lifetime;
  final Stopwatch _age = Stopwatch()..start();
  PhoenixEntitlement._(this.level, this.lifetime);
  factory PhoenixEntitlement.fromJson(
    Map<String, dynamic> json, {
    Duration requestTime = Duration.zero,
  }) {
    final now = DateTime.tryParse(json['server_now']?.toString() ?? '');
    final expiry = DateTime.tryParse(json['vip_expires_at']?.toString() ?? '');
    final level = json['vip_level'];
    return PhoenixEntitlement._(
      level is int && level >= 0 && level <= 10 ? level : 0,
      now == null || expiry == null
          ? Duration.zero
          : expiry.difference(now) - requestTime,
    );
  }
  bool activeAt(Duration elapsed) => level >= 1 && level <= 10 && elapsed < lifetime;
  // The Lion King entry is a NEW VIP 10 benefit and must never be granted by
  // the retired VIP 6 Phoenix entitlement.
  bool get isRoyalLion =>
      level == 10 && activeLease && _age.elapsed < const Duration(seconds: 30);
  bool get activeLease => _age.elapsed < lifetime;

  // Legacy accessor now denotes the new verified NIMZO VIP crown identity
  // for all ten tiers; no VIP 6-only red Phoenix benefits survive.
  bool get isPhoenix =>
      activeAt(_age.elapsed) && _age.elapsed < const Duration(seconds: 30);
  Duration get leaseRemaining {
    final remaining = lifetime - _age.elapsed;
    final lease = const Duration(seconds: 30) - _age.elapsed;
    return remaining < lease ? remaining : lease;
  }
}

class _MembershipLifecycle extends WidgetsBindingObserver {
  final void Function(AppLifecycleState) changed;
  _MembershipLifecycle(this.changed);
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => changed(state);
}

final phoenixEntitlementProvider = StreamProvider.autoDispose
    .family<PhoenixEntitlement?, String>((ref, userId) {
  final session = ref.watch(sessionSupabaseProvider);
  final me = ref.watch(currentUserIdProvider);
  final output = StreamController<PhoenixEntitlement?>();
  Timer? refreshTimer, expiryTimer;
  bool disposed = false, busy = false, foreground = true;
  int generation = 0;
  Future<void> refresh() async {
    if (disposed || busy || !foreground || me == null) return;
    busy = true;
    final requestGeneration = generation;
    final elapsed = Stopwatch()..start();
    try {
      final result = await session.client.rpc(
        'phoenix_membership',
        params: {'p_user': userId},
      );
      if (disposed || !foreground || requestGeneration != generation) return;
      final entitlement = result is Map
          ? PhoenixEntitlement.fromJson(
              Map<String, dynamic>.from(result),
              requestTime: elapsed.elapsed,
            )
          : null;
      expiryTimer?.cancel();
      output.add(entitlement?.isPhoenix == true ? entitlement : null);
      if (entitlement?.isPhoenix == true) {
        expiryTimer = Timer(entitlement!.leaseRemaining, () {
          if (!disposed) output.add(null);
        });
      }
    } catch (_) {
      if (!disposed && requestGeneration == generation) {
        expiryTimer?.cancel();
        output.add(null);
      }
    } finally {
      busy = false;
      if (!disposed && foreground && generation != requestGeneration)
        unawaited(refresh());
    }
  }

  final lifecycle = _MembershipLifecycle((state) {
    foreground = state == AppLifecycleState.resumed;
    generation++;
    expiryTimer?.cancel();
    if (!disposed) output.add(null);
    if (foreground) unawaited(refresh());
  });
  WidgetsBinding.instance.addObserver(lifecycle);
  refreshTimer = Timer.periodic(
    const Duration(seconds: 20),
    (_) => refresh(),
  );
  if (me == null) output.add(null);
  unawaited(refresh());
  ref.onDispose(() {
    disposed = true;
    refreshTimer?.cancel();
    expiryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(lifecycle);
    unawaited(output.close());
  });
  return output.stream;
});
