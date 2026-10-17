import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/supabase_provider.dart';
import '../wallet/wallet_screen.dart';

class DailyAttendance {
  final bool claimedToday;
  final int streak;
  final int reward;
  final List<DateTime> recentDays;
  const DailyAttendance({
    required this.claimedToday,
    required this.streak,
    required this.reward,
    required this.recentDays,
  });
}

/// All values come from live Supabase data, never a local simulated reward.
final dailyAttendanceProvider =
    FutureProvider.autoDispose<DailyAttendance>((ref) async {
  final me = ref.watch(currentUserIdProvider);
  if (me == null) throw StateError('Sign in required');
  final db = ref.watch(sessionSupabaseProvider).client;
  final today = DateTime.now().toUtc();
  final day = DateTime.utc(today.year, today.month, today.day);

  final config = await db.from('economy_settings')
      .select('numeric_value').eq('setting_key', 'daily_checkin_reward_coins')
      .eq('active', true).maybeSingle();
  final raw = config?['numeric_value'];
  final amount = raw is num ? raw.toInt()
      : int.tryParse(raw?.toString() ?? '') ?? 0;

  final rows = await db.from('daily_checkins')
      .select('day_utc').eq('user_id', me)
      .order('day_utc', ascending: false).limit(366);
  final checkedDays = <String>{
    for (final row in rows) row['day_utc'].toString(),
  };
  final recent = <DateTime>[];
  for (var i = 6; i >= 0; i--) {
    recent.add(day.subtract(Duration(days: i)));
  }
  var streak = 0;
  var cursor = day;
  if (!checkedDays.contains(_date(cursor))) {
    cursor = cursor.subtract(const Duration(days: 1));
  }
  while (checkedDays.contains(_date(cursor)) && streak < 365) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return DailyAttendance(
    reward: amount > 0 && amount <= 100000 ? amount : 0,
    claimedToday: checkedDays.contains(_date(day)),
    recentDays: recent.where((d) =>
        checkedDays.contains(_date(d))).toList(),
    streak: streak,
  );
});

String _date(DateTime utc) =>
    '${utc.year.toString().padLeft(4, '0')}-'
    '${utc.month.toString().padLeft(2, '0')}-'
    '${utc.day.toString().padLeft(2, '0')}';

class TingleDailyCheckinScreen extends ConsumerStatefulWidget {
  const TingleDailyCheckinScreen({super.key});

  @override
  ConsumerState<TingleDailyCheckinScreen> createState() =>
      _DailyCheckinState();
}

class _DailyCheckinState extends ConsumerState<TingleDailyCheckinScreen> {
  bool claiming = false;

  Future<void> claim() async {
    if (claiming) return;
    setState(() => claiming = true);
    try {
      final client = ref.read(sessionSupabaseProvider).client;
      final result = await client.rpc('claim_daily_checkin');
      if (!mounted) return;
      final data = result is Map ? result : <String, dynamic>{};
      final status = data['status']?.toString() ?? '';
      final coins = data['coins']?.toString() ?? '0';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(status == 'claimed'
          ? 'Daily check-in claimed: +$coins coins'
          : status == 'already_claimed'
            ? 'Already checked in today'
            : 'Check-in could not be verified')),
      );
      ref.invalidate(dailyAttendanceProvider);
      ref.invalidate(walletProvider);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(
          'Daily check-in is unavailable. Please retry after '
          'the server reward is configured.')),
      );
    } finally {
      if (mounted) setState(() => claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dailyAttendanceProvider);
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    return Scaffold(
      backgroundColor: const Color(0xffe5dbf8),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color(0xff8739df),
        foregroundColor: Colors.white,
        title: const Text('DAILY CHECK-IN', style: TextStyle(
          color: Colors.white, fontWeight: FontWeight.w900)),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dailyAttendanceProvider);
          await ref.read(dailyAttendanceProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(13, 14, 13, 30),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Container(
              height: 166,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xffb36cf6),
                    Color(0xff9638e5), Color(0xff6e28cc)])),
              child: Stack(children: [
                Positioned(
                  right: -35, top: -50,
                  child: CircleAvatar(radius: 110,
                    backgroundColor: Colors.white.withValues(alpha: .09))),
                const Positioned(
                  top: 18, right: 18,
                  child: Icon(Icons.card_giftcard_rounded,
                    color: Color(0xffffd75c), size: 75)),
                const Positioned(
                  top: 38, left: 15, right: 90,
                  child: Text('DAILY\nCHECK-IN',
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w900,
                      letterSpacing: .5, fontSize: 24)),
                ),
                const Positioned(
                  top: 115, left: 15, right: 15,
                  child: Text('Visit daily to maintain your streak',
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      color: Color(0xfff7e8ff), fontSize: 13)),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            state.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator())),
              error: (_, __) => Column(children: [
                const Icon(Icons.cloud_off_outlined,
                  size: 48, color: Color(0xff8b79ae)),
                const SizedBox(height: 14),
                const Text('Daily rewards are not enabled on the server',
                  textAlign: TextAlign.center),
                TextButton(
                  onPressed: () => ref.invalidate(dailyAttendanceProvider),
                  child: const Text('Retry')),
              ]),
              data: (attendance) => Column(children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15)),
                  child: Row(children: [
                    const Icon(Icons.local_fire_department_rounded,
                      color: Color(0xffff9c2a), size: 38),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${attendance.streak} day streak',
                          style: const TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w800)),
                        Text(attendance.claimedToday
                          ? 'Today’s reward is already claimed'
                          : attendance.reward > 0
                          ? '+${attendance.reward} coins available today'
                          : 'Coin rewards not configured',
                          style: const TextStyle(
                            fontSize: 12, color: Color(0xff8d829e))),
                      ],
                    )),
                  ]),
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: 7,
                  gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 10, crossAxisSpacing: 9,
                      childAspectRatio: .77),
                  itemBuilder: (context, index) {
                    final day = today.subtract(
                      Duration(days: 6 - index));
                    final checked = attendance.recentDays.any(
                      (d) => _date(d) == _date(day));
                    final isToday = _date(day) == _date(today);
                    return Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: checked
                          ? const Color(0xfffff0c1)
                          : const Color(0xffddbcf7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isToday
                            ? const Color(0xffffd15c) : const Color(0xfff8e1ff),
                          width: isToday ? 2 : 1)),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(checked
                            ? Icons.check_circle_rounded
                            : Icons.card_giftcard_rounded,
                            color: checked
                              ? const Color(0xffe7ab12)
                              : const Color(0xff8e46d0),
                            size: 30),
                          const SizedBox(height: 7),
                          Text(index == 6 ? 'Today'
                              : '${day.day}/${day.month}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 62,
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xffffca30),
                      foregroundColor: const Color(0xff58258c),
                      disabledBackgroundColor: const Color(0xffffdd7c),
                      disabledForegroundColor: const Color(0xff745478),
                      shape: const StadiumBorder()),
                    onPressed: claiming || attendance.claimedToday ||
                      attendance.reward <= 0 ? null : claim,
                    child: Text(
                      claiming ? 'Checking in…'
                        : attendance.claimedToday ? 'Claimed Today'
                        : attendance.reward > 0
                          ? 'Claim +${attendance.reward} Coins'
                          : 'Rewards Not Configured',
                      style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 13),
                const Text(
                  'Daily rewards reset at 00:00 UTC. '
                  'A verified server transaction credits coins once per day. '
                  'No reward is shown until the administrator configures it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xff9287a3),
                    fontSize: 12, height: 1.45)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
