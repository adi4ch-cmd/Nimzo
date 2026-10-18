import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/master_ui.dart';
import 'wallet_screen.dart';

/// Balance, recharge, and diamond exchange only. Transaction audit is internal.
class TingleCoinsScreen extends ConsumerStatefulWidget {
  const TingleCoinsScreen({super.key});
  @override
  ConsumerState<TingleCoinsScreen> createState() => _TingleCoinsState();
}

class _TingleCoinsState extends ConsumerState<TingleCoinsScreen> {

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(walletProvider);
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
          await ref.read(walletProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 26),
          children: [
            Container(
              height: 112,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xffff9a17), Color(0xffffca3e),
                    Color(0xffff9e1e)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0x667b4906),
                      borderRadius: BorderRadius.circular(35),
                    ),
                    child: const Text('Remaining coins',
                      style: TextStyle(color: Colors.white,
                        fontSize: 12)),
                  ),
                  const Spacer(),
                  Row(children: [
                    const Icon(Icons.stars_rounded,
                      color: Color(0xffffe26c), size: 31),
                    const SizedBox(width: 7),
                    Expanded(child: value.when(
                      data: (w) => Text(
                        referenceNumber(w.coins),
                        key: const ValueKey('tingle-coin-balance'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          shadows: [Shadow(color: Color(0x446b3100),
                            offset: Offset(1, 2), blurRadius: 2)],
                          fontWeight: FontWeight.w800)),
                      loading: () => const Text('…',
                        style: TextStyle(fontSize: 24, color: Colors.white)),
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
                            fontSize: 15,
                            color: Color(0xfff18a0d),
                            fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              height: 53,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xffa843f1), Color(0xff7634cb)]),
                borderRadius: BorderRadius.circular(15),
              ),
              child: ListTile(
                minTileHeight: 52,
                leading: const Icon(Icons.stars_rounded,
                  size: 27, color: Color(0xffffbd30)),
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
            const SizedBox(height: 18),
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
