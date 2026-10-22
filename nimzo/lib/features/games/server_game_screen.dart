import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/supabase_provider.dart';
import '../wallet/wallet_screen.dart';
import 'game_catalog.dart';
import 'game_level_screen.dart';
import 'game_repository.dart';

/// Wallet debits, randomness, payouts and eligibility belong to play_game.
/// This board displays returned results and never computes a winning outcome.
class ServerGameScreen extends ConsumerStatefulWidget {
  const ServerGameScreen(
      {super.key,
      required this.slug,
      this.roomId,
      this.onClose,
      this.onMinimize,
      this.onExpand,
      this.expanded = false,
      this.roomControls});
  final String slug;
  final String? roomId;
  final VoidCallback? onClose, onMinimize, onExpand;
  final bool expanded;
  final Widget? roomControls;
  @override
  ConsumerState<ServerGameScreen> createState() => _ServerGameScreenState();
}

class _ServerGameScreenState extends ConsumerState<ServerGameScreen> {
  final _amount = TextEditingController(text: '100');
  GameRetrySession _round = GameRetrySession();
  String? _identity;
  bool _restoring = false;
  bool _storageFailed = false;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _result;

  void _bind(String? userId) {
    final identity = '$userId:${widget.roomId}:${widget.slug}';
    if (_identity == identity) return;
    _identity = identity;
    _busy = false;
    _error = null;
    _result = null;
    _storageFailed = false;
    _restoring = userId != null && widget.roomId != null;
    _round = GameRetrySession(
        scope: _restoring
            ? GameRequestScope(
                userId: userId!, roomId: widget.roomId!, game: widget.slug)
            : null);
    final round = _round;
    if (_restoring)
      unawaited(() async {
        try {
          await round.restore();
          if (!mounted || _identity != identity) return;
          setState(() {
            if (round.pendingBet != null) _amount.text = '${round.pendingBet}';
            _restoring = false;
          });
        } catch (_) {
          if (!mounted || _identity != identity) return;
          setState(() {
            _restoring = false;
            _storageFailed = true;
            _error =
                'Your previous round could not be safely recovered. Reopen the game to retry.';
          });
        }
      }());
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    if (_busy || _restoring || _storageFailed) return;
    final session = ref.read(sessionSupabaseProvider);
    if (session.userId == null) return;
    final identity = _identity;
    final round = _round;
    final room = widget.roomId;
    final slug = widget.slug;
    final amount = int.tryParse(_amount.text);
    if (!_round.pending && (amount == null || amount < 1 || amount > 500000)) {
      setState(() => _error = 'Enter 1–500000 coins.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo =
          GameRepository(session.client, expectedUserId: session.userId);
      final result = await round.play(amount ?? 0, (bet, key) {
        if (ref.read(sessionSupabaseProvider).userId != session.userId) {
          throw StateError('Account changed before round submission');
        }
        return repo.play(roomId: room, game: slug, bet: bet, key: key);
      });
      if (!mounted ||
          identity != _identity ||
          ref.read(sessionSupabaseProvider).userId != session.userId) return;
      ref.invalidate(walletProvider);
      ref.invalidate(gameLevelProvider);
      if (mounted) setState(() => _result = result);
    } catch (_) {
      if (mounted &&
          identity == _identity &&
          ref.read(sessionSupabaseProvider).userId == session.userId)
        setState(() => _error = _round.pending
            ? 'Round not confirmed. Retry the same round to check its result.'
            : 'Round declined. Check your room permission and coin balance.');
    } finally {
      if (mounted && identity == _identity) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = NimzoRoomGames.all.firstWhere((g) => g.slug == widget.slug);
    final room = widget.roomId;
    final joined = room != null && room.trim().isNotEmpty;
    final userId = joined ? ref.watch(sessionSupabaseProvider).userId : null;
    _bind(userId);
    final wallet = joined ? ref.watch(walletProvider) : null;
    final result = _result;
    final outcome = result?['result'];
    final grid = outcome is Map ? outcome['grid'] : null;
    return Scaffold(
      appBar: AppBar(
          title: Text(game.title),
          leading: widget.onClose == null
              ? null
              : IconButton(
                  tooltip: 'Close game',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close)),
          actions: [
            if (widget.onExpand != null)
              IconButton(
                  tooltip: widget.expanded ? 'Collapse game' : 'Expand game',
                  onPressed: widget.onExpand,
                  icon: Icon(widget.expanded
                      ? Icons.fullscreen_exit
                      : Icons.fullscreen)),
            if (widget.onMinimize != null)
              IconButton(
                  tooltip: 'Return to voice room',
                  onPressed: widget.onMinimize,
                  icon: const Icon(Icons.picture_in_picture_alt)),
          ]),
      bottomNavigationBar: widget.roomControls,
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Play with coins',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
            'Each play spends the selected coins. The completed round shows the coins returned to your balance. Practice chips cannot be used here.'),
        const SizedBox(height: 16),
        if (!joined)
          const Text('Join a voice room to play with coins.')
        else ...[
          Text(wallet?.valueOrNull == null
              ? 'Balance unavailable'
              : 'Balance: ${wallet!.valueOrNull!.coins} coins'),
          const SizedBox(height: 12),
          TextField(
              controller: _amount,
              enabled:
                  !_busy && !_restoring && !_storageFailed && !_round.pending,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                  labelText: 'Coins per round', helperText: '1–500000 coins')),
          const SizedBox(height: 12),
          FilledButton(
              key: const ValueKey('server-game-play'),
              onPressed: _busy || _restoring || _storageFailed || userId == null
                  ? null
                  : _play,
              child: Text(_restoring
                  ? 'Recovering previous round…'
                  : _busy
                      ? 'Confirming round…'
                      : _round.pending
                          ? 'Retry same round'
                          : 'Play with coins')),
        ],
        if (_error != null)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_error!)),
        if (result != null) ...[
          const SizedBox(height: 18),
          const Text('Confirmed result',
              style: TextStyle(fontWeight: FontWeight.bold)),
          Text('Payout: ${result['payout']} coins'),
          Text('Round receipt: ${result['bet_id']}'),
          if (grid is List)
            GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5),
                itemCount: grid.length,
                itemBuilder: (_, i) => Card(
                    child: Center(
                        child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: Text('${grid[i]}',
                                textAlign: TextAlign.center))))),
          if (outcome is Map && outcome['symbol'] != null) ...[
            Text('Symbol: ${outcome['symbol']}'),
            Text('Multiplier: ${outcome['multiplier']}×'),
          ],
        ],
      ]),
    );
  }
}
