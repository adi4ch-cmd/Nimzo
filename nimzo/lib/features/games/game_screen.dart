import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/supabase_provider.dart';

class GameScreen extends ConsumerStatefulWidget {
  final String? roomId;
  const GameScreen({super.key, this.roomId});
  @override ConsumerState<GameScreen> createState() => _GameScreenState();
}
class _GameScreenState extends ConsumerState<GameScreen> {
  String game = 'fruit_wheel';
  final _bet = TextEditingController(text: '1000');
  bool busy = false;
  Map<String, dynamic>? result;
  @override void dispose() { _bet.dispose(); super.dispose(); }

  Future<void> _play() async {
    final amount = int.tryParse(_bet.text.trim()) ?? 0;
    if (amount <= 0 || amount > 500000) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bet must be between 1 and 500,000 coins.')));
      return;
    }
    setState(() => busy = true);
    try {
      final r = await ref.read(supabaseProvider).rpc('play_game', params: {
        'p_game_slug': game, 'p_bet_amount': amount, 'p_bet_type': 'spin',
        'p_selection': null, 'p_client_key': 'app-\${DateTime.now().microsecondsSinceEpoch}-\${Random().nextInt(1 << 20)}',
      });
      if (mounted) setState(() => result = Map<String, dynamic>.from(r as Map));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('\$e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = result;
    final payout = (r?['payout'] as num?)?.toInt() ?? 0;
    return Scaffold(
      appBar: AppBar(title: Text(widget.roomId == null ? 'Room Games' : 'Games in Room')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'fruit_wheel', label: Text('Fruit Wheel'), icon: Icon(Icons.casino_outlined)),
            ButtonSegment(value: 'fruit_party', label: Text('Fruit Party'), icon: Icon(Icons.grid_view_rounded)),
          ],
          selected: {game},
          onSelectionChanged: busy ? null : (v) => setState(() { game = v.first; result = null; }),
        ),
        const SizedBox(height: 18),
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [
          Icon(game == 'fruit_wheel' ? Icons.casino_outlined : Icons.grid_view_rounded, size: 64),
          const SizedBox(height: 10),
          Text(game == 'fruit_wheel' ? 'Fruit Wheel' : 'Fruit Party 5×5', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Coins only. Results are generated and settled by the Nimzo server.'),
          const SizedBox(height: 16),
          TextField(controller: _bet, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Bet (coins)', prefixIcon: Icon(Icons.monetization_on_outlined))),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: busy ? null : _play, icon: const Icon(Icons.play_arrow_rounded), label: Text(busy ? 'Playing…' : 'Play')),
        ]))),
        if (r != null) ...[
          const SizedBox(height: 16),
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [
            Text(payout > 0 ? 'WIN' : 'RESULT', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('Bet \${r['bet'] ?? 0} • Payout \$payout coins'),
            const SizedBox(height: 10),
            if (game == 'fruit_wheel') Text('\${r['result']?['symbol'] ?? '—'} • \${r['result']?['multiplier'] ?? 0}×', style: Theme.of(context).textTheme.headlineSmall),
            if (game == 'fruit_party') Text('Server result settled', style: Theme.of(context).textTheme.bodyLarge),
          ])),
        ],
      ]),
    );
  }
}
