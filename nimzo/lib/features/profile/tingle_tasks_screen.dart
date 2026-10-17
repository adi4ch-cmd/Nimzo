import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/theme/app_theme.dart';
import '../profile/profile_repository.dart';

/// Reads recorded task progress. Rewards cannot be claimed until a separate
/// server-authoritative awarding RPC has been deployed and tested.
final taskProgressProvider =
    FutureProvider.autoDispose<Map<String, bool>>((ref) async {
  final db = ref.watch(sessionSupabaseProvider).client;
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return {};
  final profile = await ref.watch(profileProvider(uid).future);
  Future<bool?> hasRows(String table, String column) async {
    try {
      final rows = await db.from(table).select(column)
          .eq(column, uid).limit(1);
      return rows.isNotEmpty;
    } catch (_) {
      return null;
    }
  }
  final gifts = await hasRows('gift_events', 'sender_id');
  final recharge = await hasRows('purchases', 'user_id');
  final played = await hasRows('game_bets', 'user_id');
  final store = await hasRows('profile_owned_collectibles', 'user_id');

  Future<int?> countDistinctRooms() async {
    try {
      final rows = await db.from('room_visit_history').select('room_id')
          .eq('user_id', uid).limit(10);
      return rows.map((r) => r['room_id']).toSet().length;
    } catch (_) {
      return null;
    }
  }

  Future<int?> confirmedFriends() async {
    try {
      final a = await db.from('friendships')
          .select('addressee_id').eq('requester_id', uid)
          .eq('status', 'accepted').limit(100);
      final b = await db.from('friendships')
          .select('requester_id').eq('addressee_id', uid)
          .eq('status', 'accepted').limit(100);
      return a.length + b.length;
    } catch (_) {
      return null;
    }
  }

  final friends = await confirmedFriends();
  final rooms = await countDistinctRooms();
  return {
    if (gifts != null) 'gift': gifts,
    if (friends != null) 'friends': friends >= 2,
    'level': profile.wealthLevel >= 5,
    if (store != null) 'store': store,
    if (recharge != null) 'recharge': recharge,
    if (played != null) 'game': played,
    if (rooms != null) 'rooms': rooms >= 3,
  };
});

class TingleTasksScreen extends ConsumerWidget {
  const TingleTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const daily = <_TaskSpec>[
      _TaskSpec('gift', 'Send a gift in the room',
        Icons.card_giftcard_rounded, Color(0xffe83fa1), '/home'),
      _TaskSpec('friends', 'Add 2 friends',
        Icons.group_add_rounded, Color(0xff38a8ec), '/discover'),
      _TaskSpec('mic', 'Speak on mic for 2 minutes',
        Icons.mic_rounded, Color(0xffa548f3), '/home'),
      _TaskSpec('level', 'Reach wealth level 5',
        Icons.verified_rounded, Color(0xff436cea), '/levels'),
      _TaskSpec('store', 'Buy an item from the store',
        Icons.shopping_bag_rounded, Color(0xfff75f98), '/store'),
    ];
    const growth = <_TaskSpec>[
      _TaskSpec('recharge', 'Recharge for the first time',
        Icons.account_balance_wallet_rounded,
        Color(0xff9454ea), '/recharge'),
      _TaskSpec('game', 'Play a game',
        Icons.sports_esports_rounded, Color(0xff3969e6), '/games'),
      _TaskSpec('rooms', 'Join 3 rooms',
        Icons.home_rounded, Color(0xffe58c2d), '/home'),
    ];

    final progress = ref.watch(taskProgressProvider);
    final state = progress.valueOrNull;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Task'),
        centerTitle: true,
        backgroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(taskProgressProvider);
          await ref.read(taskProgressProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
          children: [
            const Text('Daily Tasks', style: TextStyle(
              fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 13),
            for (final task in daily)
              _TaskCard(task: task,
                verified: state == null ? null : state[task.id]),
            const SizedBox(height: 16),
            const Text('Growth Tasks', style: TextStyle(
              fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 13),
            for (final task in growth)
              _TaskCard(task: task,
                verified: state == null ? null : state[task.id]),
            if (progress.hasError)
              TextButton(
                onPressed: () => ref.invalidate(taskProgressProvider),
                child: const Text('Retry progress lookup')),
            const SizedBox(height: 16),
            const Text(
              'Task achievements are read from existing NIMZO records. '
              'Coin and timed-frame rewards are not claimable until their '
              'server-side verification and distribution are enabled.',
              style: TextStyle(color: Color(0xff847a9a), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskSpec {
  final String id, label, route;
  final IconData icon;
  final Color color;
  const _TaskSpec(this.id, this.label, this.icon, this.color, this.route);
}

class _TaskCard extends StatelessWidget {
  final _TaskSpec task;
  final bool? verified;
  const _TaskCard({required this.task, this.verified});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 13),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xfff0eefa)),
      borderRadius: BorderRadius.circular(25),
      boxShadow: const [
        BoxShadow(color: Color(0x0f4a327a),
          blurRadius: 10, offset: Offset(0, 3)),
      ],
    ),
    child: ListTile(
      minTileHeight: 111,
      contentPadding: const EdgeInsets.fromLTRB(15, 5, 16, 5),
      leading: Container(
        width: 74, height: 74,
        decoration: BoxDecoration(
          color: task.color.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: task.color.withValues(alpha: .12)),
        ),
        child: Icon(task.icon, color: task.color, size: 38),
      ),
      title: Text(task.label, maxLines: 2,
        style: const TextStyle(
          fontWeight: FontWeight.w800, fontSize: 17)),
      subtitle: Text(
        verified == true ? 'Completed' :
          verified == false ? 'Not completed yet' : 'Progress not verified',
        style: TextStyle(
          fontSize: 11,
          color: verified == true ? const Color(0xff16a34a)
            : const Color(0xff887bb1))),
      trailing: SizedBox(
        height: 51,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: NimzoStyle.primary,
            shape: const StadiumBorder(),
          ),
          onPressed: () => context.go(task.route),
          child: Text(verified == true ? 'View' : 'Go',
            style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800,
              color: Colors.white)),
        ),
      ),
    ),
  );
}
