import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/reference_widgets.dart';
import 'wallet_screen.dart';

/// The same live wallet used by gifts and games, formatted to the reference
/// screenshot. Rows come from the user's own RLS-filtered ledger only.
final tingleCoinHistoryProvider = FutureProvider.autoDispose<
    List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(sessionSupabaseProvider).client;
  final id = ref.watch(currentUserIdProvider);
  if (id == null) return [];
  final rows = await db.from('ledger')
      .select('id,kind,coin_delta,created_at')
      .eq('user_id', id)
      .order('created_at', ascending: false)
      .limit(40);
  return rows.map((row) => Map<String, dynamic>.from(row)).toList();
});

class TingleCoinsScreen extends ConsumerStatefulWidget {
  const TingleCoinsScreen({super.key});
  @override
  ConsumerState<TingleCoinsScreen> createState() => _TingleCoinsState();
}

class _TingleCoinsState extends ConsumerState<TingleCoinsScreen> {
  String filter = 'All';

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(walletProvider);
    final history = ref.watch(tingleCoinHistoryProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Coins'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(walletProvider);
          ref.invalidate(tingleCoinHistoryProvider);
          await ref.read(walletProvider.future);
          await ref.read(tingleCoinHistoryProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 23, 24, 25),
          children: [
            Container(
              height: 184,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xffff9a17), Color(0xffffca3e),
                    Color(0xffff9e1e)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(39),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 11),
                    decoration: BoxDecoration(
                      color: const Color(0x667b4906),
                      borderRadius: BorderRadius.circular(35),
                    ),
                    child: const Text('Remaining coins',
                      style: TextStyle(color: Colors.white,
                        fontSize: 15)),
                  ),
                  const Spacer(),
                  Row(children: [
                    const Icon(Icons.stars_rounded,
                      color: Color(0xffffe26c), size: 44),
                    const SizedBox(width: 11),
                    Expanded(child: value.when(
                      data: (w) => Text(
                        referenceNumber(w.coins),
                        key: const ValueKey('tingle-coin-balance'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          shadows: [Shadow(color: Color(0x446b3100),
                            offset: Offset(1, 2), blurRadius: 2)],
                          fontWeight: FontWeight.w800)),
                      loading: () => const Text('…',
                        style: TextStyle(fontSize: 30, color: Colors.white)),
                      error: (_, __) => TextButton(
                        onPressed: () => ref.invalidate(walletProvider),
                        child: const Text('Retry',
                          style: TextStyle(color: Colors.white))),
                    )),
                    Material(
                      elevation: 4,
                      color: Colors.white,
                      shape: const StadiumBorder(),
                      child: TextButton(
                        onPressed: () => context.push('/recharge'),
                        child: const Text('Top Up',
                          style: TextStyle(
                            fontSize: 19,
                            color: Color(0xfff18a0d),
                            fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              height: 87,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xffa843f1), Color(0xff7634cb)]),
                borderRadius: BorderRadius.circular(25),
              ),
              child: ListTile(
                minTileHeight: 85,
                leading: const Icon(Icons.stars_rounded,
                  size: 36, color: Color(0xffffbd30)),
                title: const Text('Offline Recharge',
                  style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w800)),
                trailing: const Icon(Icons.chevron_right_rounded,
                  color: Colors.white),
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text(
                    'Offline recharge provider is not configured. '
                    'Use Top Up for supported purchases.'))),
              ),
            ),
            const SizedBox(height: 25),
            Row(children: [
              const Expanded(child: Text('Coin History',
                style: TextStyle(fontSize: 19, color: Colors.black,
                  fontWeight: FontWeight.w800))),
              DropdownButton<String>(
                value: filter,
                items: const ['All', 'Received', 'Spent'].map(
                  (t) => DropdownMenuItem(value: t, child: Text(t)),
                ).toList(),
                onChanged: (v) => setState(() => filter = v ?? 'All'),
              ),
            ]),
            const SizedBox(height: 15),
            history.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator())),
              error: (_, __) => ListTile(
                title: const Text('Coin history unavailable'),
                trailing: TextButton(
                  onPressed: () => ref.invalidate(tingleCoinHistoryProvider),
                  child: const Text('Retry')),
              ),
              data: (items) {
                final filtered = items.where((row) {
                  final delta = (row['coin_delta'] as num?)?.toInt() ?? 0;
                  return filter == 'All' ||
                    (filter == 'Received' && delta > 0) ||
                    (filter == 'Spent' && delta < 0);
                }).toList();
                if (filtered.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(30),
                    child: Center(child: Text('No coin history yet.')));
                }
                return Column(children: [
                  for (final row in filtered)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xffefedf5)),
                        borderRadius: BorderRadius.circular(23),
                      ),
                      child: ListTile(
                        minTileHeight: 88,
                        leading: Container(
                          width: 53, height: 53,
                          decoration: BoxDecoration(
                            color: const Color(0xfffffaf1),
                            borderRadius: BorderRadius.circular(16)),
                          child: const Icon(Icons.stars_rounded,
                            size: 33, color: Color(0xffffb11d))),
                        title: Text(
                          (row['kind'] ?? 'Transaction').toString()
                            .replaceAll('_', ' '),
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(
                          (row['created_at'] ?? '').toString()
                            .replaceAll('T', ' ').split('.').first,
                          style: const TextStyle(
                            fontSize: 12, color: Color(0xff8982a7))),
                        trailing: Text(
                          ((row['coin_delta'] as num?)?.toInt() ?? 0) >= 0
                            ? '+${row['coin_delta'] ?? 0}'
                            : '${row['coin_delta'] ?? 0}',
                          style: TextStyle(
                            color: ((row['coin_delta'] as num?)?.toInt() ?? 0)
                              >= 0 ? const Color(0xff20bd49) : Colors.red,
                            fontWeight: FontWeight.w800,
                            fontSize: 17)),
                      ),
                    ),
                ]);
              },
            ),
            const SizedBox(height: 15),
            OutlinedButton.icon(
              onPressed: () => context.push('/wallet/exchange'),
              icon: const Icon(Icons.diamond_rounded),
              label: const Text('Diamonds and 1:1 exchange'),
              style: OutlinedButton.styleFrom(
                foregroundColor: NimzoStyle.primary,
                side: const BorderSide(color: Color(0xffd8c2f4)),
                minimumSize: const Size.fromHeight(54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
