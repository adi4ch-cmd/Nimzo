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
    required this.level,
    required this.expiry,
    required this.tiers,
  });
}

final membershipSnapshotProvider = FutureProvider.autoDispose
    .family<MembershipSnapshot, bool>((ref, svip) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) throw StateError('Sign in required');
  final client = ref.watch(sessionSupabaseProvider).client;
  final profile = await client
      .from('profiles')
      .select(svip
          ? 'svip_level,svip_cycle_start,svip_cycle_cents'
          : 'vip_level,vip_expires_at')
      .eq('id', userId)
      .single();
  final rows = svip
      ? await client
          .from('svip_thresholds')
          .select('level,usd_cents')
          .order('level')
      : await client
          .from('normal_vip_catalog')
          .select('tier,coin_price,duration_days')
          .order('tier');
  final rawLevel =
      (profile[svip ? 'svip_level' : 'vip_level'] as num?)?.toInt() ?? 0;
  final expiration = !svip && profile['vip_expires_at'] != null
      ? DateTime.tryParse(profile['vip_expires_at'].toString())
      : null;
  final verifiedLevel =
      !svip && expiration != null && expiration.isBefore(DateTime.now())
          ? 0
          : rawLevel;
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
    [Color(0xff210507), Color(0xff8b0c14), Color(0xffffb4a3)],
    [Color(0xff050b24), Color(0xff122d87), Color(0xffa3c9ff)],
    [Color(0xff031c1c), Color(0xff006c60), Color(0xffb0fff1)],
  ];

  static const perks = <({IconData icon, String label})>[
    (icon: Icons.workspace_premium_outlined, label: 'SVIP Title'),
    (icon: Icons.auto_awesome_outlined, label: 'Exclusive Avatar Frame'),
    (icon: Icons.credit_card_rounded, label: 'Distinguished Card'),
    (icon: Icons.chat_bubble_outline_rounded, label: 'Chat Bubble'),
    (icon: Icons.directions_car_outlined, label: 'Awesome Entrance Show'),
    (icon: Icons.card_giftcard_outlined, label: 'Special Gift Tassel'),
    (icon: Icons.filter_frames_rounded, label: 'Live Frame'),
    (icon: Icons.crop_landscape_rounded, label: 'Party Frame'),
  ];

  static const exclusive =
      <({IconData icon, String label, String description})>[
    (
      icon: Icons.lock_person_outlined,
      label: 'Room Privacy Display',
      description: 'Preview the private room identity display.'
    ),
    (
      icon: Icons.redeem_rounded,
      label: 'Privileged Gifts',
      description:
          'Explore the exclusive gift presentation for this membership tier.'
    ),
    (
      icon: Icons.emoji_emotions_outlined,
      label: 'Microphone Emoji',
      description: 'Preview animated expressions around a microphone seat.'
    ),
    (
      icon: Icons.local_offer_outlined,
      label: '20% Discount',
      description:
          'View the membership discount privilege. Eligibility depends on your membership.'
    ),
    (
      icon: Icons.person_outline,
      label: 'Reduce Contact Fee',
      description:
          'View the contact privilege included in eligible memberships.'
    ),
    (
      icon: Icons.visibility_off_outlined,
      label: 'Mysterious Invisibility',
      description: 'Preview the discreet entrance presentation.'
    ),
    (
      icon: Icons.directions_car_rounded,
      label: 'Rare Vehicle',
      description: 'Preview a special entrance effect for a voice room.'
    ),
    (
      icon: Icons.gif_box_outlined,
      label: 'GIF DP',
      description: 'An animated profile picture adds motion to your identity.'
    ),
    (
      icon: Icons.palette_outlined,
      label: 'Party Theme',
      description: 'Preview a themed backdrop for an audio party.'
    ),
    (
      icon: Icons.shield_outlined,
      label: 'Anti-Blocking',
      description: 'View the room access privilege for eligible memberships.'
    ),
    (
      icon: Icons.do_not_disturb_on_outlined,
      label: 'Kicking Defense',
      description:
          'View the room moderation privilege for eligible memberships.'
    ),
    (
      icon: Icons.edit_outlined,
      label: 'Nickname',
      description: 'Preview a highlighted nickname in your membership color.'
    ),
  ];

  void _preview(int initial, List<Color> colors) {
    showDialog<void>(
        context: context,
        builder: (dialog) =>
            _PrivilegePreview(initial: initial, color: colors[2], items: [
              for (final perk in perks)
                (
                  icon: perk.icon,
                  label: perk.label,
                  description:
                      'Preview the ${perk.label.toLowerCase()} design. This preview does not activate membership.'
                ),
              ...exclusive,
            ]));
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(membershipSnapshotProvider(widget.svip));
    final colors = themes[(selected - 1) % themes.length];
    final name = widget.svip ? 'SVIP' : 'VIP';
    return Scaffold(
      backgroundColor: const Color(0xff100e19),
      appBar: AppBar(
        toolbarHeight: 44,
        centerTitle: true,
        backgroundColor: const Color(0xff100e19),
        foregroundColor: Colors.white,
        title: Text(name,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1)),
        actions: [
          IconButton(
            tooltip: 'Refresh membership',
            onPressed: () =>
                ref.invalidate(membershipSnapshotProvider(widget.svip)),
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
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          children: [
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (var tier = 1; tier <= 6; tier++)
                    Padding(
                      padding: const EdgeInsets.only(right: 20),
                      child: InkWell(
                        key: ValueKey('membership-tier-$tier'),
                        onTap: () => setState(() => selected = tier),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('$name $tier',
                                style: TextStyle(
                                    color: selected == tier
                                        ? Colors.white
                                        : Colors.white54,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 5),
                            Container(
                                width: 25,
                                height: 3,
                                color: selected == tier
                                    ? Colors.white
                                    : Colors.transparent),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 310,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [colors[0], colors[1], colors[0]],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                      color: colors[2].withValues(alpha: .6), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                        color: colors[1].withValues(alpha: .4),
                        blurRadius: 25,
                        spreadRadius: 3),
                  ],
                ),
                child: Stack(children: [
                  Positioned(
                      right: -80,
                      top: -65,
                      child: CircleAvatar(
                          radius: 145,
                          backgroundColor: colors[2].withValues(alpha: .10))),
                  Positioned(
                      left: -40,
                      bottom: -145,
                      child: CircleAvatar(
                          radius: 155,
                          backgroundColor: colors[2].withValues(alpha: .08))),
                  Positioned.fill(
                      child: CustomPaint(
                          painter:
                              _MembershipCurtainPainter(accent: colors[2]))),
                  Center(
                      child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.military_tech_rounded,
                          color: const Color(0xffffdf91), size: 49),
                      const SizedBox(height: 13),
                      Container(
                          width: 144,
                          height: 144,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xffffd78c), width: 4),
                              gradient: LinearGradient(
                                  colors: [colors[2], colors[1], colors[0]]),
                              boxShadow: [
                                BoxShadow(
                                    color: colors[2].withValues(alpha: .48),
                                    blurRadius: 22,
                                    spreadRadius: 4)
                              ]),
                          alignment: Alignment.center,
                          child: Container(
                              height: 120,
                              width: 120,
                              decoration: BoxDecoration(
                                  color: colors[0],
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: colors[2], width: 3)),
                              child: Icon(Icons.diamond_rounded,
                                  color: colors[2], size: 70))),
                      const SizedBox(height: 12),
                      Text('$name $selected',
                          style: TextStyle(
                              color: colors[2],
                              fontSize: 24,
                              letterSpacing: 3,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      const Text('IDENTITY COLLECTION',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              letterSpacing: 3)),
                    ],
                  )),
                ]),
              ),
            ),
            const SizedBox(height: 23),
            current.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => TextButton(
                  onPressed: () =>
                      ref.invalidate(membershipSnapshotProvider(widget.svip)),
                  child: const Text('Membership data unavailable · Retry')),
              data: (snapshot) {
                final currentTier = snapshot.tiers
                    .where((r) =>
                        (r[widget.svip ? 'level' : 'tier'] as num?)?.toInt() ==
                        selected)
                    .firstOrNull;
                final threshold = currentTier == null
                    ? 'Unavailable'
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
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 7),
                    Text(threshold,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Color(0xffc9badd), fontSize: 13)),
                    if (snapshot.expiry != null)
                      Text(
                          'Expiry: ${snapshot.expiry!.toLocal().toString().split(' ').first}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white54)),
                  ],
                );
              },
            ),
            const SizedBox(height: 25),
            const Text('Identification',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 15),
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: perks.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: .90,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8),
              itemBuilder: (context, index) {
                final perk = perks[index];
                return InkWell(
                    key: ValueKey('membership-perk-$index'),
                    onTap: () => _preview(index, colors),
                    child: Container(
                      decoration: BoxDecoration(
                        color: colors[0],
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: colors[2].withValues(alpha: .2)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                              height: 43,
                              width: 43,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(13),
                                  gradient: LinearGradient(
                                      colors: [colors[1], colors[0]]),
                                  border: Border.all(
                                      color: colors[2].withValues(alpha: .6))),
                              child:
                                  Icon(perk.icon, size: 30, color: colors[2])),
                          const SizedBox(height: 8),
                          Text(perk.label,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 10)),
                        ],
                      ),
                    ));
              },
            ),
            const SizedBox(height: 24),
            const Center(
                child: Text('Exclusive Privileges',
                    style: TextStyle(
                        color: Color(0xffded168),
                        fontSize: 13,
                        fontWeight: FontWeight.w700))),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: exclusive.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.05,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8),
              itemBuilder: (context, index) => InkWell(
                  key: ValueKey('membership-exclusive-$index'),
                  onTap: () => _preview(perks.length + index, colors),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(exclusive[index].icon,
                            color: const Color(0xffe4dc20), size: 28),
                        const SizedBox(height: 10),
                        Text(exclusive[index].label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Color(0xffd9d376), fontSize: 9)),
                      ])),
            ),
            const SizedBox(height: 16),
            const Text(
                'Previews only. Membership purchases are currently unavailable.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _PrivilegePreview extends StatefulWidget {
  const _PrivilegePreview(
      {required this.initial, required this.color, required this.items});
  final int initial;
  final Color color;
  final List<({IconData icon, String label, String description})> items;

  @override
  State<_PrivilegePreview> createState() => _PrivilegePreviewState();
}

class _PrivilegePreviewState extends State<_PrivilegePreview> {
  late final controller = PageController(initialPage: widget.initial);
  late int page = widget.initial;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: 360,
                maxHeight: MediaQuery.sizeOf(context).height * .62),
            child: Column(children: [
              Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                      tooltip: 'Close privilege preview',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded,
                          color: Color(0xffaaa2b5), size: 20))),
              Expanded(
                  child: PageView.builder(
                      key: const ValueKey('membership-privilege-pages'),
                      controller: controller,
                      itemCount: widget.items.length,
                      onPageChanged: (value) => setState(() => page = value),
                      itemBuilder: (context, index) {
                        final item = widget.items[index];
                        return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Column(children: [
                              Container(
                                  height: 110,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      gradient: LinearGradient(colors: [
                                        const Color(0xff180b2a),
                                        widget.color.withValues(alpha: .6),
                                        const Color(0xff180b2a)
                                      ])),
                                  child: Icon(item.icon,
                                      color: widget.color, size: 64)),
                              const SizedBox(height: 14),
                              Text(item.label,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 10),
                              Expanded(
                                  child: SingleChildScrollView(
                                      child: Text(item.description,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              height: 1.5,
                                              color: Color(0xff93889e))))),
                            ]));
                      })),
              Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                            tooltip: 'Previous privilege',
                            onPressed: page == 0
                                ? null
                                : () => controller.previousPage(
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOut),
                            icon: const Icon(Icons.chevron_left_rounded)),
                        Text('${page + 1} / ${widget.items.length}',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xff9b7cb4))),
                        IconButton(
                            tooltip: 'Next privilege',
                            onPressed: page == widget.items.length - 1
                                ? null
                                : () => controller.nextPage(
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOut),
                            icon: const Icon(Icons.chevron_right_rounded)),
                      ])),
            ])),
      );
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
        ..cubicTo(x - 35, size.height * .25, x + 23, size.height * .75, x - 10,
            size.height);
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = i.isEven ? 15 : 8
            ..color = accent.withValues(alpha: i.isEven ? .09 : .04));
    }
    final edge = Paint()
      ..color = const Color(0x888a723c)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(10, 12, size.width - 20, size.height - 24),
            const Radius.circular(15)),
        edge);
  }

  @override
  bool shouldRepaint(covariant _MembershipCurtainPainter old) =>
      old.accent != accent;
}
