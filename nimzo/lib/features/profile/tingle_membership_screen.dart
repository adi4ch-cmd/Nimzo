import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/supabase_provider.dart';

/// Membership layouts modelled on the supplied three-color Tingle references.
/// Data is read-only; retired purchase/grant RPCs must not be simulated.
class MembershipSnapshot {
  final int level;
  final DateTime? expiry;
  final List<Map<String, dynamic>> tiers;
  const MembershipSnapshot({
    required this.level, required this.expiry, required this.tiers,
  });
}

final membershipSnapshotProvider =
    FutureProvider.autoDispose.family<MembershipSnapshot, bool>((ref, svip) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) throw StateError('Sign in required');
  final client = ref.watch(sessionSupabaseProvider).client;
  final profile = await client.from('profiles')
    .select(svip
      ? 'svip_level,svip_cycle_start,svip_cycle_cents'
      : 'vip_level,vip_expires_at')
    .eq('id', userId).single();
  final rows = svip
      ? await client.from('svip_thresholds')
          .select('level,usd_cents').order('level')
      : await client.from('normal_vip_catalog')
          .select('tier,coin_price,duration_days').order('tier');
  final rawLevel = (profile[svip ? 'svip_level' : 'vip_level'] as num?)
      ?.toInt() ?? 0;
  final expiration = !svip && profile['vip_expires_at'] != null
      ? DateTime.tryParse(profile['vip_expires_at'].toString())
      : null;
  final verifiedLevel = !svip && expiration != null &&
      expiration.isBefore(DateTime.now()) ? 0 : rawLevel;
  return MembershipSnapshot(
    level: verifiedLevel,
    expiry: expiration,
    tiers: [
      for (final row in rows) Map<String, dynamic>.from(row),
    ],
  );
});

class TingleMembershipScreen extends ConsumerStatefulWidget {
  final bool svip;
  const TingleMembershipScreen({super.key, required this.svip});

  @override
  ConsumerState<TingleMembershipScreen> createState() => _MembershipState();
}

class _MembershipState extends ConsumerState<TingleMembershipScreen> {
  int selected = 1;

  static const themes = [
    [Color(0xff160720), Color(0xff59208d), Color(0xffd4abff)],
    [Color(0xff051e13), Color(0xff076638), Color(0xffacffbd)],
    [Color(0xff290719), Color(0xff97114d), Color(0xffffaedc)],
  ];

  static const perks = <({IconData icon, String label})>[
    (icon: Icons.workspace_premium_outlined, label: 'SVIP Title'),
    (icon: Icons.auto_awesome_outlined, label: 'Exclusive Avatar Frame'),
    (icon: Icons.credit_card_rounded, label: 'Distinguished Card'),
    (icon: Icons.chat_bubble_outline_rounded, label: 'Chat Bubble'),
    (icon: Icons.shield_outlined, label: 'Avatar Frame'),
    (icon: Icons.card_giftcard_outlined, label: 'Special Gift Tassel'),
  ];

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(membershipSnapshotProvider(widget.svip));
    final colors = themes[(selected - 1) % themes.length];
    final name = widget.svip ? 'SVIP' : 'VIP';
    return Scaffold(
      backgroundColor: const Color(0xff100e19),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color(0xff100e19),
        foregroundColor: Colors.white,
        title: Text(name, style: const TextStyle(
          fontSize: 23, fontWeight: FontWeight.w900,
          letterSpacing: 2)),
        actions: [
          IconButton(
            tooltip: 'Refresh membership',
            onPressed: () => ref.invalidate(
              membershipSnapshotProvider(widget.svip)),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(membershipSnapshotProvider(widget.svip));
          await ref.read(membershipSnapshotProvider(widget.svip).future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 34),
          children: [
            SizedBox(
              height: 59,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (var tier = 1; tier <= 5; tier++)
                    Padding(
                      padding: const EdgeInsets.only(right: 25),
                      child: InkWell(
                        key: ValueKey('membership-tier-$tier'),
                        onTap: () => setState(() => selected = tier),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('$name $tier', style: TextStyle(
                              color: selected == tier
                                ? Colors.white : Colors.white54,
                              fontSize: 19, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 5),
                            Container(
                              width: 25, height: 3,
                              color: selected == tier
                                ? Colors.white : Colors.transparent),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 11),
            SizedBox(
              height: 430,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colors[0], colors[1], colors[0]],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: colors[2]
                    .withValues(alpha: .6), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: colors[1].withValues(alpha: .4),
                      blurRadius: 25, spreadRadius: 3),
                  ],
                ),
                child: Stack(children: [
                  Positioned(
                    right: -80, top: -65,
                    child: CircleAvatar(radius: 145,
                      backgroundColor: colors[2].withValues(alpha: .10))),
                  Positioned(
                    left: -40, bottom: -145,
                    child: CircleAvatar(radius: 155,
                      backgroundColor: colors[2].withValues(alpha: .08))),
                  Positioned.fill(child: CustomPaint(
                    painter: _MembershipCurtainPainter(accent: colors[2]))),
                  Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.military_tech_rounded,
                        color: const Color(0xffffdf91), size: 49),
                      const SizedBox(height: 13),
                      Container(
                        width: 188, height: 188,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xffffd78c), width: 4),
                          gradient: LinearGradient(colors: [
                            colors[2], colors[1], colors[0]]),
                          boxShadow: [BoxShadow(
                            color: colors[2].withValues(alpha: .48),
                            blurRadius: 22, spreadRadius: 4)]),
                        alignment: Alignment.center,
                        child: Container(
                          height: 159, width: 159,
                          decoration: BoxDecoration(
                            color: colors[0], shape: BoxShape.circle,
                            border: Border.all(color: colors[2], width: 3)),
                          child: Icon(Icons.diamond_rounded,
                            color: colors[2], size: 91))),
                      const SizedBox(height: 12),
                      Text('$name $selected', style: TextStyle(
                        color: colors[2], fontSize: 29,
                        letterSpacing: 3, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      const Text('IDENTITY COLLECTION',
                        style: TextStyle(
                          color: Colors.white70, fontSize: 11,
                          letterSpacing: 3)),
                    ],
                  )),
                ]),
              ),
            ),
            const SizedBox(height: 23),
            current.when(
              loading: () => const Center(
                child: CircularProgressIndicator()),
              error: (_, __) => TextButton(
                onPressed: () => ref.invalidate(
                  membershipSnapshotProvider(widget.svip)),
                child: const Text('Membership data unavailable · Retry')),
              data: (snapshot) {
                final currentTier = snapshot.tiers.where(
                  (r) => (r[widget.svip ? 'level' : 'tier'] as num?)
                    ?.toInt() == selected).firstOrNull;
                final threshold = currentTier == null ? 'Unavailable'
                  : widget.svip
                    ? 'Threshold: USD ${((currentTier['usd_cents'] as num).toInt() / 100).toStringAsFixed(0)}'
                    : 'Listed price: ${currentTier['coin_price']} coins';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      snapshot.level > 0
                        ? 'Current $name level: ${snapshot.level}'
                        : '$name not active on this account',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white,
                        fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 7),
                    Text(threshold,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xffc9badd), fontSize: 13)),
                    if (snapshot.expiry != null) Text(
                      'Expiry: ${snapshot.expiry!.toLocal().toString().split(' ').first}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white54)),
                  ],
                );
              },
            ),
            const SizedBox(height: 25),
            const Text('Membership privileges',
              style: TextStyle(
                color: Colors.white,
                fontSize: 21, fontWeight: FontWeight.w800)),
            const SizedBox(height: 15),
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: perks.length,
              gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, childAspectRatio: .90,
                  mainAxisSpacing: 12, crossAxisSpacing: 12),
              itemBuilder: (context, index) {
                final perk = perks[index];
                return Container(
                  decoration: BoxDecoration(
                    color: colors[0],
                    borderRadius: BorderRadius.circular(19),
                    border: Border.all(
                      color: colors[2].withValues(alpha: .2)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 65, width: 65,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(13),
                          gradient: LinearGradient(colors: [
                            colors[1], colors[0]]),
                          border: Border.all(
                            color: colors[2].withValues(alpha: .6))),
                        child: Icon(perk.icon, size: 39, color: colors[2])), 
                      const SizedBox(height: 11),
                      Text(perk.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xff231d31),
                borderRadius: BorderRadius.circular(19)),
              child: const Text(
                'Visual membership preview. The original VIP/SVIP '
                'purchase and reward flows were retired in NIMZO. '
                'These visual effects are not equipped or purchased '
                'from this screen. Memberships require separately '
                'verified server entitlements before activation.',
                style: TextStyle(
                  color: Color(0xffb8adc8), fontSize: 12, height: 1.5)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MembershipCurtainPainter extends CustomPainter {
  final Color accent;
  const _MembershipCurtainPainter({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 10; i++) {
      final x = (i + 1) * size.width / 11;
      final path = Path()
        ..moveTo(x, 0)
        ..cubicTo(x - 35, size.height * .25,
          x + 23, size.height * .75, x - 10, size.height);
      canvas.drawPath(path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = i.isEven ? 15 : 8
          ..color = accent.withValues(alpha: i.isEven ? .09 : .04));
    }
    final edge = Paint()
      ..color = const Color(0x888a723c)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(10, 12, size.width - 20, size.height - 24),
      const Radius.circular(15)), edge);
  }

  @override
  bool shouldRepaint(covariant _MembershipCurtainPainter old) =>
    old.accent != accent;
}
