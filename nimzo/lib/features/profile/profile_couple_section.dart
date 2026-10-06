import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/utils/helpers.dart';
import '../../core/widgets/nimzo_user_card.dart';
import 'profile.dart';
import 'profile_repository.dart';

final coupleRequestsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async =>
        await ref
            .watch(supabaseProvider)
            .from('couple_requests')
            .select()
            .eq('status', 'pending')
            .order('created_at', ascending: false));

class ProfileCoupleSection extends ConsumerWidget {
  final String userId;
  const ProfileCoupleSection({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
        margin: const EdgeInsets.only(top: 12),
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('CP / Couple',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  ref.watch(profileCoupleProvider(userId)).when(
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => TextButton(
                            onPressed: () =>
                                ref.invalidate(profileCoupleProvider(userId)),
                            child: const Text('Retry loading CP')),
                        data: (couple) {
                          if (couple == null)
                            return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('No couple linked'),
                                ]);
                          final partner = couple['user_a'] == userId
                              ? couple['user_b'] as String
                              : couple['user_a'] as String;
                          final since = DateTime.tryParse(
                              couple['created_at']?.toString() ?? '');
                          return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ref.watch(profileProvider(partner)).when(
                                      loading: () =>
                                          const LinearProgressIndicator(),
                                      error: (_, __) => TextButton(
                                          onPressed: () => ref.invalidate(
                                              profileProvider(partner)),
                                          child: const Text(
                                              'Retry loading partner')),
                                      data: (p) => NimzoUserCard(
                                          user: p,
                                          avatarUrl: storageUrl(
                                              ref.watch(supabaseProvider),
                                              'avatars',
                                              p.avatarPath),
                                          onTap: () => context
                                              .push('/profile/$partner')),
                                    ),
                                const Text('Linked couple'),
                                if (since != null)
                                  Text(
                                      'Together for ${DateTime.now().difference(since).inDays.clamp(0, 100000)} days'),
                              ]);
                        },
                      ),
                  if (ref.watch(currentUserIdProvider) == userId)
                    TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const CoupleInvitationsScreen())), child: const Text('CP invitations')),
                ])),
      );
}

class CoupleInvitationsScreen extends ConsumerStatefulWidget {
  const CoupleInvitationsScreen({super.key});
  @override
  ConsumerState<CoupleInvitationsScreen> createState() =>
      _CoupleInvitationsState();
}

class _CoupleInvitationsState extends ConsumerState<CoupleInvitationsScreen> {
  final search = TextEditingController();
  List<Profile> matches = [];
  bool busy = false;
  String? error;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> change(Future<void> Function() operation) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await operation();
      ref.invalidate(coupleRequestsProvider);
      final me = ref.read(currentUserIdProvider);
      if (me != null) ref.invalidate(profileCoupleProvider(me));
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserIdProvider);
    final db = ref.watch(supabaseProvider);
    return Scaffold(
        appBar: AppBar(title: const Text('CP invitations')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text(
              'A relationship is linked only after your partner accepts.'),
          const SizedBox(height: 12),
          TextField(
              controller: search,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Partner Nimzo ID')),
          TextButton(
              onPressed: busy
                  ? null
                  : () => change(() async {
                        if (int.tryParse(search.text.trim()) == null)
                          throw StateError('Enter a numeric Nimzo ID.');
                        final result = await ref
                            .read(profileRepositoryProvider)
                            .search(search.text.trim());
                        if (mounted)
                          setState(() => matches =
                              result.where((p) => p.id != me).toList());
                        if (result.isEmpty)
                          throw StateError('No profile found for this ID.');
                      }),
              child: const Text('Find partner')),
          for (final p in matches)
            NimzoUserCard(
                user: p,
                avatarUrl: storageUrl(db, 'avatars', p.avatarPath),
                trailing: TextButton(
                    onPressed: busy
                        ? null
                        : () => change(() async {
                              await db.from('couple_requests').insert(
                                  {'requester_id': me, 'addressee_id': p.id});
                              if (mounted) {
                                setState(() => matches = []);
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('CP invitation sent')));
                              }
                            }),
                    child: const Text('Invite'))),
          if (busy) const LinearProgressIndicator(),
          if (error != null)
            Padding(padding: const EdgeInsets.all(8), child: Text(error!)),
          const SizedBox(height: 16),
          Text('Pending invitations',
              style: Theme.of(context).textTheme.titleSmall),
          ref.watch(coupleRequestsProvider).when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => TextButton(
                    onPressed: () => ref.invalidate(coupleRequestsProvider),
                    child: const Text('Retry invitations')),
                data: (requests) => requests.isEmpty
                    ? const Text('No pending invitations')
                    : Column(children: [
                        for (final request in requests)
                          Builder(builder: (context) {
                            final incoming = request['addressee_id'] == me;
                            final partner = (incoming
                                ? request['requester_id']
                                : request['addressee_id']) as String;
                            return ref.watch(profileProvider(partner)).when(
                                  loading: () =>
                                      const LinearProgressIndicator(),
                                  error: (_, __) =>
                                      const Text('Partner unavailable'),
                                  data: (p) => Column(children: [
                                    NimzoUserCard(
                                        user: p,
                                        avatarUrl: storageUrl(
                                            db, 'avatars', p.avatarPath)),
                                    Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          if (incoming)
                                            TextButton(
                                                onPressed: busy
                                                    ? null
                                                    : () => change(() async {
                                                          await db.rpc(
                                                              'respond_couple_request',
                                                              params: {
                                                                'p_request':
                                                                    request[
                                                                        'id'],
                                                                'p_accept': true
                                                              });
                                                        }),
                                                child: const Text('Accept')),
                                          TextButton(
                                              onPressed: busy
                                                  ? null
                                                  : () => change(() async {
                                                        if (incoming) {
                                                          await db.rpc(
                                                              'respond_couple_request',
                                                              params: {
                                                                'p_request':
                                                                    request[
                                                                        'id'],
                                                                'p_accept':
                                                                    false
                                                              });
                                                        } else {
                                                          await db
                                                              .from(
                                                                  'couple_requests')
                                                              .delete()
                                                              .eq(
                                                                  'id',
                                                                  request[
                                                                      'id']);
                                                        }
                                                      }),
                                              child: Text(incoming
                                                  ? 'Decline'
                                                  : 'Cancel request')),
                                        ]),
                                  ]),
                                );
                          }),
                      ]),
              ),
        ]));
  }
}
