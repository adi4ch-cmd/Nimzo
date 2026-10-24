import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/supabase_provider.dart';
import '../store/store_live_catalog.dart';
import '../store/store_visual_equipment.dart';
import 'membership_identity.dart';
import 'membership_pack_inventory.dart';
import 'membership_room_background.dart';

/// A server-confirmed selection, independent of purchasing membership.
class MembershipPackControls extends ConsumerStatefulWidget {
  const MembershipPackControls(
      {super.key, required this.kind, required this.tier});
  final String kind;
  final int tier;
  @override
  ConsumerState<MembershipPackControls> createState() =>
      _MembershipPackControlsState();
}

class _MembershipPackControlsState
    extends ConsumerState<MembershipPackControls> {
  bool _busy = false;
  String? _error;

  Future<void> _change(bool apply) async {
    if (_busy) return;
    final session = ref.read(sessionSupabaseProvider);
    if (session.userId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await session.client
          .rpc(
            apply
                ? 'nimzo_membership_apply_full_set'
                : 'nimzo_membership_remove_full_set',
            params: apply ? {'p_kind': widget.kind, 'p_tier': widget.tier} : {},
          )
          .timeout(const Duration(seconds: 15));
      if (result is! Map ||
          (apply
              ? result['pack_kind'] != widget.kind ||
                  result['pack_tier'] != widget.tier
              : result['pack_kind'] != null)) {
        throw StateError('Server did not confirm the selected set');
      }
    } catch (_) {
      if (mounted &&
          ref.read(sessionSupabaseProvider).userId == session.userId) {
        setState(() => _error =
            'Update not confirmed. Refresh to check the saved set, then retry.');
      }
    } finally {
      if (mounted &&
          ref.read(sessionSupabaseProvider).userId == session.userId) {
        ref.invalidate(effectiveMembershipProvider(session.userId!));
        ref.invalidate(storeVisualEquipmentProvider(session.userId!));
        ref.invalidate(nimzoStoreProvider);
        ref.invalidate(membershipRoomBackgroundProvider);
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = ref.watch(sessionSupabaseProvider).userId;
    final state =
        id == null ? null : ref.watch(effectiveMembershipProvider(id));
    final status = state?.hasError == true ? null : state?.valueOrNull;
    final eligible = status?.eligible(widget.kind, widget.tier) == true;
    final applied =
        status?.packKind == widget.kind && status?.packTier == widget.tier;
    final full = applied && status!.packSlots.length == 9;
    final completeMedia =
        MembershipPackInventory.hasCompleteCoreMedia(widget.kind, widget.tier);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(
          full
              ? 'Applied'
              : applied
                  ? 'Individual cosmetics selected'
                  : eligible
                      ? 'Ready to apply'
                      : 'Locked',
          key: ValueKey('pack-status-${widget.kind}-${widget.tier}'),
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Color(0xffac925c), fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      FilledButton.icon(
        key: ValueKey('apply-full-${widget.kind}-${widget.tier}'),
        onPressed: eligible && !_busy && !full ? () => _change(true) : null,
        icon: Icon(full ? Icons.check_circle : Icons.auto_awesome),
        style: FilledButton.styleFrom(
            backgroundColor: const Color(0xffe8c878),
            foregroundColor: const Color(0xff171827),
            disabledBackgroundColor: const Color(0xff29344a),
            disabledForegroundColor: const Color(0xffb8c8de),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
        label: Text(_busy
            ? 'Saving…'
            : full
                ? 'Applied'
                : completeMedia
                    ? 'Apply Full ${widget.kind.toUpperCase()} Set'
                    : 'Apply available ${widget.kind.toUpperCase()} items'),
      ),
      if (applied)
        TextButton(
          key: const ValueKey('remove-full-membership-set'),
          onPressed: _busy ? null : () => _change(false),
          child: Text(completeMedia
              ? 'Remove Full ${widget.kind.toUpperCase()} Set'
              : 'Remove applied items'),
        ),
      if (!completeMedia)
        const Text(
            'Original pack incomplete: only available items will be applied.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xffd1b475))),
      const Text(
          'Applies the available profile and room cosmetics. You can change individual items in Store afterward. Room wallpaper is selected separately by its owner.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Color(0xff7d899c))),
      if (_error != null)
        Text(_error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xffd27d70))),
    ]);
  }
}
