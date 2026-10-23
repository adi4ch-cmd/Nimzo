import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/supabase_provider.dart';

class RoomPoll {
  RoomPoll.fromJson(Map<String, dynamic> p)
      : id = p['id'] as String,
        creatorId = p['creator_id'] as String,
        question = p['question'] as String,
        options = (p['options'] as List).cast<String>(),
        counts = (p['counts'] as List).map((n) => (n as num).toInt()).toList(),
        myChoice = (p['my_choice'] as num?)?.toInt(),
        active = p['active'] == true,
        canClose = p['can_close'] == true,
        endsAt = DateTime.parse(p['ends_at'] as String);
  final String id, creatorId, question;
  final List<String> options;
  final List<int> counts;
  final int? myChoice;
  final bool active, canClose;
  final DateTime endsAt;
}

class RoomPollRepository {
  RoomPollRepository(this.db);
  final SupabaseClient db;
  Future<List<RoomPoll>> list(String room) async =>
      (await db.rpc('room_poll_state', params: {'p_room': room}) as List)
          .map((p) => RoomPoll.fromJson(Map<String, dynamic>.from(p)))
          .toList();
  Future<void> create(String room, String question, List<String> options,
      String key, String user) async {
    final id = await db.rpc('create_room_poll', params: {
      'p_room': room,
      'p_question': question,
      'p_options': options,
      'p_key': key,
      'p_expected_user': user
    });
    if (id is! String || id.isEmpty) throw StateError('Poll not confirmed');
  }

  Future<void> vote(String poll, int choice, String user) async {
    final result = await db.rpc('cast_room_vote',
        params: {'p_poll': poll, 'p_choice': choice, 'p_expected_user': user});
    if (result is! Map || result['choice'] != choice)
      throw StateError('Vote not confirmed');
  }

  Future<void> close(String poll, String user) async {
    await db.rpc('close_room_poll',
        params: {'p_poll': poll, 'p_expected_user': user});
  }

  Stream<List<RoomPoll>> watch(String room) {
    late StreamController<List<RoomPoll>> out;
    RealtimeChannel? channel;
    Timer? timer;
    var busy = false, closed = false, again = false;
    Future<void> refresh() async {
      if (closed) return;
      if (busy) {
        again = true;
        return;
      }
      busy = true;
      try {
        final polls = await list(room);
        if (!closed) out.add(polls);
      } catch (e, s) {
        if (!closed) out.addError(e, s);
      } finally {
        busy = false;
        if (again) {
          again = false;
          unawaited(refresh());
        }
      }
    }

    out = StreamController(onListen: () {
      unawaited(refresh());
      timer = Timer.periodic(
          const Duration(seconds: 10), (_) => unawaited(refresh()));
      channel = db
          .channel('room-polls:$room:${DateTime.now().microsecondsSinceEpoch}')
          .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'room_polls',
              filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'room_id',
                  value: room),
              callback: (_) => unawaited(refresh()))
          .subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed) unawaited(refresh());
      });
    }, onCancel: () {
      closed = true;
      timer?.cancel();
      if (channel != null) unawaited(db.removeChannel(channel!));
    });
    return out.stream;
  }
}

final roomPollRepositoryProvider = Provider(
    (ref) => RoomPollRepository(ref.watch(sessionSupabaseProvider).client));
final roomPollsProvider =
    StreamProvider.autoDispose.family<List<RoomPoll>, String>((ref, room) {
  if (ref.watch(currentUserIdProvider) == null)
    return Stream.error(StateError('Sign in required'));
  return ref.watch(roomPollRepositoryProvider).watch(room);
});

class RoomPollSheet extends ConsumerStatefulWidget {
  const RoomPollSheet({super.key, this.roomId});
  final String? roomId;
  @override
  ConsumerState<RoomPollSheet> createState() => _RoomPollState();
}

class _RoomPollState extends ConsumerState<RoomPollSheet> {
  final question = TextEditingController();
  final options = List.generate(4, (_) => TextEditingController());
  bool busy = false;
  String? message, _boundUser;
  String _key = _newKey();
  static String _newKey() => List.generate(16,
          (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'))
      .join();
  @override
  void dispose() {
    question.dispose();
    for (final input in options) {
      input.dispose();
    }
    super.dispose();
  }

  void bind(String? user) {
    if (user == _boundUser) return;
    _boundUser = user;
    busy = false;
    message = null;
    question.clear();
    for (final input in options) {
      input.clear();
    }
    _key = _newKey();
  }

  Future<void> action(Future<void> Function(RoomPollRepository, String) perform,
      String success) async {
    final user = ref.read(currentUserIdProvider);
    if (user == null || busy) return;
    setState(() => busy = true);
    try {
      await perform(ref.read(roomPollRepositoryProvider), user);
      if (!mounted || ref.read(currentUserIdProvider) != user) return;
      ref.invalidate(roomPollsProvider(widget.roomId!));
      setState(() => message = success);
    } catch (_) {
      if (mounted && ref.read(currentUserIdProvider) == user)
        setState(() => message =
            'Action not confirmed. Refresh to recover the result, then retry if needed.');
    } finally {
      if (mounted && _boundUser == user) setState(() => busy = false);
    }
  }

  Future<void> create() async {
    final values =
        options.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    if (question.text.trim().isEmpty ||
        values.length < 2 ||
        values.map((s) => s.toLowerCase()).toSet().length != values.length) {
      setState(() =>
          message = 'Enter a question and at least two different options.');
      return;
    }
    final q = question.text.trim(), key = _key;
    await action((repo, user) async {
      await repo.create(widget.roomId!, q, values, key, user);
      // Only a confirmed create retires this key. Unknown failures must retry
      // it; the next poll after closure needs its own identity.
      if (mounted && ref.read(currentUserIdProvider) == user) _key = _newKey();
    }, 'Poll created.');
  }

  @override
  Widget build(BuildContext context) {
    if (widget.roomId == null)
      return const Text('Join a room to create or vote in a poll.');
    final user = ref.watch(currentUserIdProvider);
    bind(user);
    if (user == null) return const Text('Sign in to create or vote in a poll.');
    final state = ref.watch(roomPollsProvider(widget.roomId!));
    return SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(
            child: Text('ROOM VOTE',
                style: TextStyle(
                    color: Color(0xff047857),
                    fontSize: 22,
                    fontWeight: FontWeight.w800))),
        IconButton(
            tooltip: 'Refresh polls',
            onPressed: () => ref.invalidate(roomPollsProvider(widget.roomId!)),
            icon: const Icon(Icons.refresh))
      ]),
      const Text('Five-minute polls · one choice per person'),
      if (message != null)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(message!)),
      state.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) =>
              const Text('Polls unavailable. Tap refresh to retry.'),
          data: (polls) =>
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final poll in polls) card(poll),
                if (!polls.any(
                    (p) => p.active && p.endsAt.isAfter(DateTime.now()))) ...[
                  const SizedBox(height: 12),
                  const Text('Start a poll',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  TextField(
                      controller: question,
                      enabled: !busy,
                      maxLength: 120,
                      decoration: const InputDecoration(labelText: 'Question'),
                      onChanged: (_) => _key = _newKey()),
                  for (var i = 0; i < 4; i++)
                    TextField(
                        controller: options[i],
                        enabled: !busy,
                        maxLength: 60,
                        decoration: InputDecoration(
                            labelText:
                                'Option ${i + 1}${i > 1 ? ' (optional)' : ''}'),
                        onChanged: (_) => _key = _newKey()),
                  FilledButton(
                      onPressed: busy ? null : create,
                      child: Text(busy ? 'Confirming…' : 'Start vote')),
                ],
              ])),
    ]));
  }

  Widget card(RoomPoll p) {
    final active = p.active && p.endsAt.isAfter(DateTime.now());
    final total = p.counts.fold<int>(0, (sum, n) => sum + n);
    return Card(
        margin: const EdgeInsets.only(top: 12),
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(p.question,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 17)),
                  Text(
                      active
                          ? 'Open · ${p.endsAt.difference(DateTime.now()).inMinutes + 1} min left'
                          : 'Closed',
                      style: const TextStyle(color: Color(0xff64748b))),
                  for (var i = 0; i < p.options.length; i++)
                    Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              OutlinedButton(
                                  onPressed:
                                      active && p.myChoice == null && !busy
                                          ? () => action(
                                              (repo, user) =>
                                                  repo.vote(p.id, i, user),
                                              'Vote recorded.')
                                          : null,
                                  child: Text(p.options[i])),
                              LinearProgressIndicator(
                                  value: total == 0 ? 0 : p.counts[i] / total,
                                  minHeight: 5),
                              Text(
                                  '${p.counts[i]} ${p.counts[i] == 1 ? 'vote' : 'votes'}${p.myChoice == i ? ' · Your vote' : ''}'),
                            ])),
                  if (active && p.canClose)
                    TextButton(
                        onPressed: busy
                            ? null
                            : () => action(
                                (repo, user) => repo.close(p.id, user),
                                'Poll closed.'),
                        child: const Text('End poll')),
                ])));
  }
}
