import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/theme/app_theme.dart';
import '../rooms/domain/room.dart';
import '../rooms/presentation/room_controller.dart';

/// Read-only server-scored PK battles: gift_events are the ONLY score source.
/// A battle neither charges a bet nor changes the number of Vivox microphones.
class LivePkMatch {
  final String id, roomA, roomB, nameA, nameB;
  final int roomNoA, roomNoB, scoreA, scoreB;
  final DateTime endsAt;
  const LivePkMatch({
    required this.id, required this.roomA, required this.roomB,
    required this.nameA, required this.nameB,
    required this.roomNoA, required this.roomNoB,
    required this.scoreA, required this.scoreB, required this.endsAt,
  });
  factory LivePkMatch.fromJson(Map<String,dynamic> j) => LivePkMatch(
    id: j['match_id'].toString(),
    roomA: j['room_a'].toString(),
    roomB: j['room_b'].toString(),
    nameA: j['name_a']?.toString() ?? 'Room A',
    nameB: j['name_b']?.toString() ?? 'Room B',
    roomNoA: (j['number_a'] as num?)?.toInt() ?? 0,
    roomNoB: (j['number_b'] as num?)?.toInt() ?? 0,
    scoreA: (j['score_a'] as num?)?.toInt() ?? 0,
    scoreB: (j['score_b'] as num?)?.toInt() ?? 0,
    endsAt: DateTime.parse(j['ends_at'].toString()),
  );
  double get progress {
    final sum = scoreA + scoreB;
    return sum == 0 ? .5 : scoreA / sum;
  }
}

final livePkMatchesProvider =
  FutureProvider.autoDispose<List<LivePkMatch>>((ref) async {
    final client = ref.watch(sessionSupabaseProvider).client;
    if (ref.watch(currentUserIdProvider) == null) return [];
    final rows = await client.rpc('pk_live_board');
    if (rows is! List) throw StateError('PK scoreboard unavailable');
    return rows.map((value) =>
      LivePkMatch.fromJson(Map<String,dynamic>.from(value as Map))).toList();
  });

final pkInvitationsProvider =
  FutureProvider.autoDispose<List<Map<String,dynamic>>>((ref) async {
    if (ref.watch(currentUserIdProvider) == null) return [];
    final rows = await ref.watch(sessionSupabaseProvider).client
      .from('room_pk_invites')
      .select('id,challenger_room,challenged_room,requested_by,'
        'created_at,expires_at,status')
      .eq('status','pending')
      .gt('expires_at',DateTime.now().toUtc().toIso8601String())
      .order('created_at',ascending:false).limit(50);
    return rows.map((e)=>Map<String,dynamic>.from(e)).toList();
  });

final myPkRoomProvider = FutureProvider.autoDispose<Room?>((ref) async {
  if (ref.watch(currentUserIdProvider) == null) return null;
  final repo = ref.watch(roomRepositoryProvider);
  final id = await repo.ownedRoomId();
  return id == null ? null : repo.get(id);
});

class PkBattlesScreen extends ConsumerStatefulWidget {
  const PkBattlesScreen({super.key});
  @override
  ConsumerState<PkBattlesScreen> createState() => _PkState();
}

class _PkState extends ConsumerState<PkBattlesScreen> {
  int tab = 0;
  bool busy = false;

  void notify(String text) {
    if (mounted) ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content:Text(text)));
  }

  Future<void> refresh() async {
    ref.invalidate(livePkMatchesProvider);
    ref.invalidate(pkInvitationsProvider);
    ref.invalidate(myPkRoomProvider);
    await Future.wait([
      ref.read(livePkMatchesProvider.future),
      ref.read(pkInvitationsProvider.future),
      ref.read(myPkRoomProvider.future),
    ]);
  }

  Future<void> challenge(Room from, Room to) async {
    if (busy) return;
    setState(()=>busy=true);
    try {
      await ref.read(sessionSupabaseProvider).client.rpc(
        'pk_invite',
        params: {'p_from_room':from.id,'p_to_room':to.id},
      );
      ref.invalidate(pkInvitationsProvider);
      notify('PK challenge sent. Other room owner must accept within 5 minutes.');
    } catch (error) {
      notify('Could not send challenge: $error');
    } finally {
      if(mounted)setState(()=>busy=false);
    }
  }

  Future<void> respond(Map<String,dynamic> row,bool accept) async {
    if(busy)return;
    setState(()=>busy=true);
    try {
      await ref.read(sessionSupabaseProvider).client.rpc(
        'pk_respond',
        params: {'p_invite':row['id'],'p_accept':accept},
      );
      ref.invalidate(pkInvitationsProvider);
      ref.invalidate(livePkMatchesProvider);
      notify(accept
        ? 'PK started: scores use verified room gifts for 5 minutes.'
        : 'Challenge declined.');
    } catch(error){
      notify('Could not respond to challenge: $error');
    } finally {
      if(mounted)setState(()=>busy=false);
    }
  }

  Future<void> chooseOpponent(Room own) async {
    final publicRooms = await ref.read(popularRoomsProvider(null).future);
    if (!mounted) return;
    final available = publicRooms.where((r)=>r.id != own.id &&
      r.status == 'open' && !r.isPrivate).toList();
    if (available.isEmpty) {
      notify('No other public rooms available for PK.');
      return;
    }
    final chosen = await showModalBottomSheet<Room>(
      context:context,
      isScrollControlled:true,
      shape:const RoundedRectangleBorder(
        borderRadius:BorderRadius.vertical(top:Radius.circular(24))),
      builder:(context)=>SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height*.6,
          child: Column(children:[
            const Padding(
              padding:EdgeInsets.all(20),
              child:Text('Challenge a room',
                style:TextStyle(fontSize:21,fontWeight:FontWeight.w900))),
            Expanded(child:ListView.builder(
              itemCount:available.length,
              itemBuilder:(context,index){
                final r=available[index];
                return ListTile(
                  leading:const CircleAvatar(
                    child:Icon(Icons.mic_rounded)),
                  title:Text(r.name,maxLines:1,
                    overflow:TextOverflow.ellipsis),
                  subtitle:Text('Room ID: ${r.roomNo}'),
                  trailing:const Icon(Icons.chevron_right),
                  onTap:()=>Navigator.pop(context,r),
                );
              },
            )),
          ]),
        ),
      ),
    );
    if(chosen!=null)await challenge(own,chosen);
  }

  @override
  Widget build(BuildContext context){
    final matches=ref.watch(livePkMatchesProvider);
    final invites=ref.watch(pkInvitationsProvider);
    final own=ref.watch(myPkRoomProvider);
    return Scaffold(
      backgroundColor:const Color(0xfff5f3ff),
      appBar:AppBar(
        backgroundColor:Colors.white,
        centerTitle:true,
        title:const Text('PK Battle',
          style:TextStyle(fontWeight:FontWeight.w900)),
        actions:[
          IconButton(
            tooltip:'Refresh PK',
            onPressed:()=>refresh(),
            icon:const Icon(Icons.refresh_rounded,
              color:NimzoStyle.primary)),
        ]),
      body:RefreshIndicator(
        onRefresh:refresh,
        child:ListView(
          physics:const AlwaysScrollableScrollPhysics(),
          padding:const EdgeInsets.fromLTRB(16,18,16,85),
          children:[
            Container(
              height:150,
              decoration:BoxDecoration(
                gradient:const LinearGradient(colors:[
                  Color(0xff352b91),Color(0xff963deb),Color(0xffed62ac),
                ]),
                borderRadius:BorderRadius.circular(25)),
              child:const Row(children:[
                Padding(
                  padding:EdgeInsets.symmetric(horizontal:19),
                  child:Icon(Icons.bolt_rounded,
                    color:Color(0xffffd67c),size:80)),
                Expanded(child:Column(
                  mainAxisAlignment:MainAxisAlignment.center,
                  crossAxisAlignment:CrossAxisAlignment.start,
                  children:[
                    Text('ROOM VS ROOM',
                      style:TextStyle(color:Color(0xffffe4ac),
                        fontSize:12,fontWeight:FontWeight.w800,
                        letterSpacing:2)),
                    SizedBox(height:7),
                    Text('PK Challenge',style:TextStyle(
                      color:Colors.white,fontSize:25,
                      fontWeight:FontWeight.w900)),
                    SizedBox(height:6),
                    Text('5 minutes · real verified gift scores',
                      style:TextStyle(color:Colors.white70,
                        fontSize:12)),
                  ],
                )),
              ]),
            ),
            const SizedBox(height:16),
            own.when(
              loading:()=>const LinearProgressIndicator(),
              error:(_,__)=>const Text('Could not find your room'),
              data:(room)=>room==null
                ? const Text('Create your audio room to challenge others.')
                : room.isPrivate || room.status!='open'
                  ? const Text('Open a public room before starting PK.')
                  : FilledButton.icon(
                      onPressed:busy?null:()=>chooseOpponent(room),
                      icon:const Icon(Icons.add_rounded),
                      label:const Text('Challenge a room'),
                      style:FilledButton.styleFrom(
                        backgroundColor:NimzoStyle.primary,
                        minimumSize:const Size.fromHeight(54)),
                    ),
            ),
            const SizedBox(height:17),
            Container(
              padding:const EdgeInsets.all(5),
              decoration:BoxDecoration(
                color:Colors.white,
                borderRadius:BorderRadius.circular(21)),
              child:Row(children:[
                for(var i=0;i<2;i++)
                  Expanded(child:InkWell(
                    key:ValueKey('pk-tab-$i'),
                    onTap:()=>setState(()=>tab=i),
                    borderRadius:BorderRadius.circular(17),
                    child:Container(
                      alignment:Alignment.center,
                      padding:const EdgeInsets.symmetric(vertical:12),
                      decoration:BoxDecoration(
                        color:tab==i?NimzoStyle.primary:Colors.transparent,
                        borderRadius:BorderRadius.circular(17)),
                      child:Text(i==0?'Live PK':'Invitations',
                        style:TextStyle(
                          color:tab==i?Colors.white:const Color(0xff74678b),
                          fontWeight:FontWeight.w800)),
                    ),
                  )),
              ]),
            ),
            const SizedBox(height:18),
            if(tab==0)
              matches.when(
                loading:()=>const Center(
                  child:CircularProgressIndicator()),
                error:(_,__)=>_EmptyPk('PK matches could not be loaded. Retry.'),
                data:(rows)=>rows.isEmpty
                  ? const _EmptyPk('No public PK matches running right now.')
                  : Column(children:[
                      for(final m in rows)_MatchCard(match:m),
                    ]),
              )
            else
              invites.when(
                loading:()=>const Center(child:CircularProgressIndicator()),
                error:(_,__)=>const _EmptyPk('Could not load PK invitations.'),
                data:(rows)=>rows.isEmpty
                  ? const _EmptyPk('No pending PK invitations.')
                  : Column(children:[
                      for(final row in rows)
                        _InviteCard(
                          invite:row,
                          ownId:own.valueOrNull?.id,
                          onRespond: (accepted)=>respond(row,accepted),
                          busy:busy,
                        ),
                    ]),
              ),
            const SizedBox(height:17),
            const Text(
              'PK is a voluntary five-minute audio room challenge. '
              'Scores use real settled gift events. No random spins, bets, '
              'wallet adjustments or extra microphone seats are involved. '
              'Pull down to refresh scores.',
              textAlign:TextAlign.center,
              style:TextStyle(
                color:Color(0xff887e9b),fontSize:12,height:1.5)),
          ],
        ),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget{
  final LivePkMatch match;
  const _MatchCard({required this.match});
  @override
  Widget build(BuildContext context){
    final minutes=match.endsAt.difference(DateTime.now().toUtc());
    final remaining=minutes.isNegative
      ? 'Finishing' : '${minutes.inMinutes}m left';
    return Container(
      margin:const EdgeInsets.only(bottom:14),
      padding:const EdgeInsets.all(17),
      decoration:BoxDecoration(
        color:Colors.white,
        borderRadius:BorderRadius.circular(24),
        border:Border.all(color:const Color(0xffeadcf8))),
      child:Column(children:[
        Row(children:[
          Expanded(child:_PkRoom(
            name:match.nameA,number:match.roomNoA,
            score:match.scoreA,onTap:()=>context.push('/room/${match.roomA}'),
          )),
          Column(children:[
            const Text('VS',style:TextStyle(
              fontSize:26,color:NimzoStyle.primary,
              fontWeight:FontWeight.w900)),
            Text(remaining,style:const TextStyle(
              color:Color(0xff8f7db1),fontSize:11)),
          ]),
          Expanded(child:_PkRoom(
            name:match.nameB,number:match.roomNoB,
            score:match.scoreB,onTap:()=>context.push('/room/${match.roomB}'),
          )),
        ]),
        const SizedBox(height:15),
        ClipRRect(
          borderRadius:BorderRadius.circular(15),
          child:LinearProgressIndicator(
            minHeight:12,
            value:match.progress,
            backgroundColor:const Color(0xfff18bc2),
            color:const Color(0xff9849ee)),
        ),
        const SizedBox(height:8),
        const Text('Scores from settled room gifts',
          style:TextStyle(color:Color(0xff91879d),fontSize:11)),
      ]),
    );
  }
}

class _PkRoom extends StatelessWidget{
  final String name;
  final int number,score;
  final VoidCallback onTap;
  const _PkRoom({required this.name,required this.number,
    required this.score,required this.onTap});
  @override
  Widget build(BuildContext context)=>InkWell(
    onTap:onTap,
    child:Column(children:[
      const CircleAvatar(
        radius:29,
        backgroundColor:Color(0xffede1fa),
        child:Icon(Icons.mic_rounded,color:NimzoStyle.primary,size:29)),
      const SizedBox(height:7),
      Text(name,maxLines:1,overflow:TextOverflow.ellipsis,
        style:const TextStyle(fontWeight:FontWeight.w800)),
      Text('ID $number',style:const TextStyle(
        fontSize:11,color:Color(0xff887b9d))),
      const SizedBox(height:7),
      Text('$score',style:const TextStyle(
        fontSize:17,fontWeight:FontWeight.w900)),
    ]),
  );
}

class _InviteCard extends StatelessWidget{
  final Map<String,dynamic> invite;
  final String? ownId;
  final bool busy;
  final void Function(bool) onRespond;
  const _InviteCard({
    required this.invite,required this.ownId,required this.busy,
    required this.onRespond,
  });
  @override
  Widget build(BuildContext context){
    final incoming=ownId==invite['challenged_room'];
    return Container(
      margin:const EdgeInsets.only(bottom:12),
      padding:const EdgeInsets.all(17),
      decoration:BoxDecoration(
        color:Colors.white,borderRadius:BorderRadius.circular(22)),
      child:Column(
        crossAxisAlignment:CrossAxisAlignment.stretch,
        children:[
          Text(incoming?'Incoming challenge':'Challenge sent',
            style:const TextStyle(
              fontSize:17,fontWeight:FontWeight.w900)),
          const SizedBox(height:7),
          Text(incoming?'Another room invited you to PK.'
            :'Waiting for the other room owner.',
            style:const TextStyle(
              color:Color(0xff81758d),fontSize:12)),
          const SizedBox(height:10),
          if(incoming) Row(
            mainAxisAlignment:MainAxisAlignment.end,
            children:[
              TextButton(
                onPressed:busy?null:()=>onRespond(false),
                child:const Text('Decline')),
              const SizedBox(width:9),
              FilledButton(
                style:FilledButton.styleFrom(
                  backgroundColor:NimzoStyle.primary),
                onPressed:busy?null:()=>onRespond(true),
                child:const Text('Accept')),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyPk extends StatelessWidget{
  final String label;
  const _EmptyPk(this.label);
  @override
  Widget build(BuildContext context)=>Container(
    padding:const EdgeInsets.all(30),
    decoration:BoxDecoration(
      color:Colors.white,borderRadius:BorderRadius.circular(25)),
    child:Column(children:[
      const Icon(Icons.bolt_outlined,
        color:Color(0xff9f8bc8),size:52),
      const SizedBox(height:13),
      Text(label,textAlign:TextAlign.center,
        style:const TextStyle(
          color:Color(0xff837895),fontWeight:FontWeight.w700)),
    ]),
  );
}
