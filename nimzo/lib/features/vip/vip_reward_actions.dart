import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/error_handler.dart';
import '../../core/utils/formatters.dart';
import '../wallet/wallet_screen.dart';
import 'vip_repository.dart';

/// The purchase and claim RPCs are the only authorities for membership rewards.
/// The widget never alters VIP levels, wallet balances or ledgers itself.
class VipRewardActions extends ConsumerStatefulWidget {
  const VipRewardActions({
    super.key,
    required this.svip,
    required this.status,
    required this.accent,
  });

  final bool svip;
  final Map<String, dynamic>? status;
  final Color accent;

  @override
  ConsumerState<VipRewardActions> createState() => _VipRewardActionsState();
}

class _VipRewardActionsState extends ConsumerState<VipRewardActions> {
  bool _busy = false;

  Future<void> _claim() async {
    if (_busy || widget.status == null) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(vipRepositoryProvider);
      if (widget.svip) {
        await repo.claimSvipFriday(); // Backward-compatible Sunday RPC name.
      } else {
        await repo.claimDaily();
      }
      ref.invalidate(vipStatusProvider);
      ref.invalidate(walletProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.svip
            ? 'Weekly SVIP reward verified and credited.'
            : 'Daily VIP reward verified and credited.')),
      );
    } catch (error) {
      if (!mounted) return;
      final message = mapError(error).message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    final key = widget.svip ? 'svip_level' : 'vip_level';
    final level = status?[key];
    final active = level is int && level >= 1 && level <= 10;
    final claimed = status?[
      widget.svip ? 'svip_weekly_claimed' : 'vip_daily_claimed_today'
    ] == true;
    final rewards = ref.watch(widget.svip
        ? svipFridayRewardsProvider
        : vipDailyRewardsProvider);
    final amounts = rewards.valueOrNull ?? const <Map<String, dynamic>>[];
    int? reward;
    if (active) {
      for (final row in amounts) {
        if (row['level'] == level && row['coins'] is int) {
          reward = row['coins'] as int;
          break;
        }
      }
    }
    // Weekly rewards auto-credit Sunday 21:00 Riyadh. Manual claim is only
    // a server-approved fallback after 22:00 if automatic payout was missed.
    final fallbackOpen = !widget.svip ||
        status?['svip_weekly_claimable'] == true;
    final ready = status != null && active && !claimed && fallbackOpen
        && reward != null && reward > 0 && !_busy;
    final title = widget.svip ? 'SVIP weekly reward' : 'VIP daily reward';
    final description = widget.svip
        ? 'Automatic credit every Sunday, 9:00 PM Saudi time. '
          'If payment is missed, a one-time manual fallback opens after 10 PM.'
        : 'One claim per Saudi calendar day while your VIP is active.';
    final expires = status?['vip_expires_at'];
    String? expiryText;
    if (!widget.svip && active && expires is String) {
      final utc = DateTime.tryParse(expires)?.toUtc();
      final date = utc?.add(const Duration(hours: 3));
      if (date != null) {
        expiryText = 'Membership expires (Saudi time): '
            '${date.year}-${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}';
      }
    }

    return Container(
      key: ValueKey(widget.svip ? 'svip-reward-panel' : 'vip-reward-panel'),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: widget.svip ? const Color(0xff21131a)
            : const Color(0xff102b24),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: widget.accent.withValues(alpha: .28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.card_giftcard, color: widget.accent),
            const SizedBox(width: 10),
            Expanded(child: Text(title,
              style: TextStyle(color: widget.accent,
                fontWeight: FontWeight.w800, fontSize: 15))),
          ]),
          const SizedBox(height: 8),
          Text(description,
            style: const TextStyle(color: Color(0xffc0ccc5), fontSize: 12)),
          if (expiryText != null) ...[
            const SizedBox(height: 7),
            Text(expiryText, style:
              const TextStyle(color: Color(0xffd1ddd3), fontSize: 12)),
          ],
          const SizedBox(height: 10),
          Text(
            !active ? 'Activate membership to unlock this reward.'
            : rewards.isLoading ? 'Loading verified reward amount…'
            : rewards.hasError ? 'Reward catalog unavailable.'
            : reward == null ? 'This tier has no configured reward.'
            : '${compactNumber(reward)} coins available per claim',
            style: const TextStyle(color: Colors.white,
              fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: ValueKey(widget.svip ? 'claim-svip-weekly'
                  : 'claim-vip-daily'),
              onPressed: ready ? _claim : null,
              icon: Icon(claimed ? Icons.verified : Icons.redeem),
              label: Text(_busy ? 'Confirming with server…'
                : claimed ? (widget.svip
                    ? 'Weekly reward already credited'
                    : 'Already claimed this cycle')
                : widget.svip
                    ? (fallbackOpen ? 'Claim missed weekly reward'
                        : 'Automatic payout scheduled')
                    : 'Claim verified reward'),
            ),
          ),
        ],
      ),
    );
  }
}
