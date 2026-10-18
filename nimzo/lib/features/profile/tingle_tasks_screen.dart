import '../../app/feature_availability.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  // Daily tasks reset at the start of the user's local calendar day.
  final now = DateTime.now();
  final dayStartUtc = DateTime(now.year, now.month, now.day)
      .toUtc().toIso8601String();
  Future<bool?> hasRows(String table, String column, {String? since}) async {
    try {
      var query = db.from(table).select(column).eq(column, uid);
      if (since != null) query = query.gte(since, dayStartUtc);
      final rows = await query.limit(1);
      return rows.isNotEmpty;
    } catch (_) {
      return null;
    }
  }
  final gifts = await hasRows('gift_events', 'sender_id',
    since: 'created_at');
  final recharge = await hasRows('purchases', 'user_id');
  final played = await hasRows('game_bets', 'user_id');
  final store = await hasRows('profile_owned_collectibles', 'user_id',
    since: 'granted_at');

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
      _TaskSpec('friends', 'Have 2 friends',
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
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
          children: [
            const Text('Daily Tasks', style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 9),
            for (final task in daily)
              _TaskCard(task: task,
                verified: state == null ? null : state[task.id]),
            const SizedBox(height: 16),
            const Text('Growth Tasks', style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 9),
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
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xfff0eefa)),
      borderRadius: BorderRadius.circular(14),
      boxShadow: const [
        BoxShadow(color: Color(0x0f4a327a),
          blurRadius: 5, offset: Offset(0, 2)),
      ],
    ),
    child: ListTile(
      minTileHeight: 67,
      contentPadding: const EdgeInsets.fromLTRB(11, 2, 10, 2),
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: task.color.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: task.color.withValues(alpha: .12)),
        ),
        child: Icon(task.icon, color: task.color, size: 24),
      ),
      title: Text(task.label, maxLines: 2,
        style: const TextStyle(
          fontWeight: FontWeight.w800, fontSize: 12)),
      subtitle: Text(
        verified == true ? 'Completed' :
          verified == false ? 'Not completed yet' : 'Progress not verified',
        style: TextStyle(
          fontSize: 11,
          color: verified == true ? const Color(0xff16a34a)
            : const Color(0xff887bb1))),
      trailing: SizedBox(
        height: 32, width: 59,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: NimzoStyle.primary,
            padding: EdgeInsets.zero,
            shape: const StadiumBorder(),
          ),
          onPressed: () => openAvailableDestination(context, task.route, replace: true),
          child: Text(verified == true ? 'View' : 'Go',
            style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w800,
              color: Colors.white)),
        ),
      ),
    ),
  );
}
