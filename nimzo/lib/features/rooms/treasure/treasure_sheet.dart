import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/master_ui.dart';
import '../../wallet/wallet_screen.dart';
import 'treasure_repository.dart';

class TreasureSheet extends ConsumerStatefulWidget {
  const TreasureSheet({super.key, this.roomId});
  final String? roomId;
  @override
  ConsumerState<TreasureSheet> createState() => _TreasureState();
}

class _TreasureState extends ConsumerState<TreasureSheet> {
  int world = 0, total = 0, quantity = 0, condition = 0;
  bool _busy = false, _restoring = false, _storageFailed = false;
  String? _identity, _message, _claiming;
  TreasureSendSession? _session;
  List<int> get amounts => world == 0
      ? [10000, 50000, 100000, 200000]
      : [500000, 1000000, 5000000, 10000000];
  TreasureRequest get selected => TreasureRequest(
      scope: world == 0 ? 'room' : 'world',
      total: amounts[total],
      quantity: [6, 10, 20, 30][quantity],
      eligibility: ['all', 'fans', 'on_mic'][condition]);
  void _bind(String? user) {
    final id = '$user:${widget.roomId}';
    if (_identity == id) return;
    _identity = id;
    _session = null;
    _message = null;
    _busy = false;
    _claiming = null;
    _storageFailed = false;
    _restoring = user != null && widget.roomId != null;
    if (!_restoring) return;
    final session = TreasureSendSession(userId: user!, roomId: widget.roomId!);
    _session = session;
    unawaited(() async {
      try {
        await session.restore();
        if (!mounted || _identity != id) return;
        setState(() {
          _restoring = false;
          final pending = session.request;
          if (pending != null) {
            world = pending.scope == 'room' ? 0 : 1;
            total = amounts.indexOf(pending.total);
            quantity = [6, 10, 20, 30].indexOf(pending.quantity);
            condition = ['all', 'fans', 'on_mic'].indexOf(pending.eligibility);
          }
        });
      } catch (_) {
        if (mounted && _identity == id)
          setState(() {
            _restoring = false;
            _storageFailed = true;
            _message =
                'Previous confirmation could not be recovered. Reopen Treasure to retry.';
          });
      }
    }());
  }

  bool _same(String identity) =>
      mounted &&
      _identity == identity &&
      ref.read(currentUserIdProvider) == _session?.userId;
  Future<void> _send() async {
    final session = _session, identity = _identity;
    if (session == null ||
        identity == null ||
        _busy ||
        _restoring ||
        _storageFailed) return;
    final request = session.request ?? selected;
    setState(() => _busy = true);
    try {
      if (!session.pending) {
        final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
                    title: const Text('Fund treasure box?'),
                    content: Text(
                        '${referenceNumber(request.total)} coins will leave your balance for ${request.quantity} shares. '
                        'Each eligible person can claim once. Unclaimed coins are refunded after 24 hours by the scheduled refund service.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(
                              'Confirm ${referenceNumber(request.total)} coins'))
                    ]));
        if (confirmed != true || !_same(identity)) return;
      }
      if (!_same(identity)) return;
      final repo = ref.read(treasureRepositoryProvider);
      await session.send(request, (params) {
        if (!_same(identity)) throw StateError('Account changed');
        return repo.create(params);
      });
      if (!_same(identity)) return;
      ref.invalidate(walletProvider);
      ref.invalidate(roomTreasuresProvider(widget.roomId!));
      setState(() => _message = 'Treasure box funded.');
    } catch (_) {
      if (_same(identity))
        setState(() => _message = session.pending
            ? 'Funding not confirmed. Retry the same box to recover its receipt.'
            : 'Box was not funded. Check your balance and room permission.');
    } finally {
      if (mounted && _identity == identity) setState(() => _busy = false);
    }
  }

  Future<void> _claim(TreasureBox box) async {
    final identity = _identity;
    if (identity == null || _claiming != null) return;
    setState(() => _claiming = box.id);
    try {
      final coins = await ref
          .read(treasureRepositoryProvider)
          .claim(box.id, widget.roomId!);
      if (!_same(identity)) return;
      ref.invalidate(walletProvider);
      ref.invalidate(roomTreasuresProvider(widget.roomId!));
      setState(() => _message = '${referenceNumber(coins)} coins received.');
    } catch (_) {
      if (_same(identity)) {
        setState(() => _message =
            'Claim not confirmed. Refresh and retry; a successful claim is never credited twice.');
        ref.invalidate(roomTreasuresProvider(widget.roomId!));
      }
    } finally {
      if (mounted && _identity == identity) setState(() => _claiming = null);
    }
  }

  Widget _label(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 6),
      child: Text(text,
          style: const TextStyle(color: NimzoStyle.muted, fontSize: 12)));
  @override
  Widget build(BuildContext context) {
    final user =
        widget.roomId == null ? null : ref.watch(currentUserIdProvider);
    _bind(user);
    final balance = ref.watch(walletProvider).valueOrNull;
    final enabled =
        _session != null && !_busy && !_restoring && !_storageFailed;
    final locked =
        _busy || _restoring || _storageFailed || (_session?.pending ?? false);
    final boxes =
        user == null ? null : ref.watch(roomTreasuresProvider(widget.roomId!));
    if (user != null) {
      int refunds(AsyncValue<List<TreasureBox>>? value) =>
          value?.valueOrNull
              ?.where((box) => box.senderId == user)
              .fold<int>(0, (sum, box) => sum + box.refunded) ??
          0;
      ref.listen(roomTreasuresProvider(widget.roomId!), (previous, next) {
        if (next.hasValue && refunds(previous) != refunds(next))
          ref.invalidate(walletProvider);
      });
    }
    return SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
          padding: const EdgeInsets.all(18),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xff064e3b), Color(0xff00856a)]),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('TREASURE',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          color: Color(0xffffe5a3))),
                  Text(
                      balance == null
                          ? 'Balance unavailable'
                          : '${balance.coins} coins',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: Colors.white)),
                ])),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                  color: const Color(0x22ffe5a3),
                  borderRadius: BorderRadius.circular(18)),
              child: const Icon(Icons.inventory_2_rounded,
                  color: Color(0xffffd985), size: 36),
            )
          ])),
      IgnorePointer(
          ignoring: locked,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ReferenceTabs(
                labels: const ['Room', 'World'],
                selected: world,
                onSelected: (i) => setState(() {
                      world = i;
                      total = 0;
                      condition = 0;
                    }),
                pills: true),
            _label('Total'),
            ReferenceTabs(
                labels: amounts.map(compactNumber).toList(),
                selected: total,
                onSelected: (i) => setState(() => total = i),
                pills: true),
            _label('Quantity'),
            ReferenceTabs(
                labels: const ['6', '10', '20', '30'],
                selected: quantity,
                onSelected: (i) => setState(() => quantity = i),
                pills: true),
            _label('Condition'),
            ReferenceTabs(
                labels: world == 0
                    ? const ['All', 'Fans', 'On mic']
                    : const ['All', 'Fans'],
                selected: condition,
                onSelected: (i) => setState(() => condition = i),
                pills: true),
          ])),
      const SizedBox(height: 12),
      Text(
          condition == 1
              ? 'Fans means people following the sender.'
              : condition == 2
                  ? 'Only people currently occupying an unlocked mic seat can claim.'
                  : 'Each eligible person can claim one share; the sender cannot claim.',
          style: const TextStyle(color: NimzoStyle.muted, fontSize: 12)),
      const SizedBox(height: 14),
      SizedBox(
          width: double.infinity,
          child: GradientButton(
              onPressed: enabled ? _send : null,
              child: Text(_restoring
                  ? 'Recovering confirmation…'
                  : _busy
                      ? 'Confirming…'
                      : (_session?.pending ?? false)
                          ? 'Retry same box'
                          : 'Send'))),
      const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
              'Equal shares, with any remainder assigned one coin at a time. Unclaimed coins refund after 24 hours; refunds run every 5 minutes.',
              style: TextStyle(color: NimzoStyle.muted, fontSize: 12))),
      if (user == null)
        const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Join a room and sign in to send or claim treasure.')),
      if (_message != null)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_message!,
                key: const ValueKey('treasure-message'),
                style: const TextStyle(fontWeight: FontWeight.w600))),
      if (boxes != null) ...[
        const SizedBox(height: 16),
        Row(children: [
          const Expanded(
              child: Text('Boxes & history',
                  style: TextStyle(fontWeight: FontWeight.w700))),
          IconButton(
              tooltip: 'Refresh treasure',
              onPressed: () {
                ref.invalidate(roomTreasuresProvider(widget.roomId!));
                ref.invalidate(walletProvider);
              },
              icon: const Icon(Icons.refresh))
        ]),
        boxes.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) =>
                const Text('Treasure unavailable. Tap refresh to retry.'),
            data: (items) => items.isEmpty
                ? const Text('No treasure boxes yet.')
                : Column(
                    children: [for (final box in items) _card(box, user!)])),
      ],
    ]));
  }

  Widget _card(TreasureBox box, String user) {
    final expired = !box.expiresAt.isAfter(DateTime.now());
    final left = box.expiresAt.difference(DateTime.now());
    final status = box.refunded > 0
        ? '${referenceNumber(box.refunded)} coins refunded'
        : box.claimedCoins != null
            ? 'You received ${referenceNumber(box.claimedCoins!)} coins'
            : box.remaining == 0
                ? 'Fully claimed'
                : expired
                    ? 'Expired · refund pending'
                    : '${left.inHours}h ${left.inMinutes.remainder(60)}m remaining';
    return Card(
        key: ValueKey('treasure-${box.id}'),
        color: const Color(0xfff1f7f0),
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  '${box.scope == 'world' ? 'World' : 'Room'} · ${box.senderId == user ? 'Your box' : box.name}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                  '${referenceNumber(box.total)} coins · ${box.claimed}/${box.quantity} shares claimed'),
              Text(status,
                  style:
                      const TextStyle(color: NimzoStyle.muted, fontSize: 12)),
              if (box.canClaim && !expired)
                Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                        onPressed: _claiming == null ? () => _claim(box) : null,
                        child: Text(
                            _claiming == box.id ? 'Confirming…' : 'Claim'))),
              if (!box.canClaim &&
                  box.senderId != user &&
                  box.claimedCoins == null &&
                  !expired &&
                  box.remaining > 0)
                Text(
                    box.eligibility == 'fans'
                        ? 'Follow the sender to become eligible.'
                        : box.eligibility == 'on_mic'
                            ? 'Take an available mic seat to become eligible.'
                            : 'You are not currently eligible.',
                    style: const TextStyle(fontSize: 12)),
            ])));
  }
}
