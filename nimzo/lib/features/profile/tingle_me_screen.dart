import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/theme/app_theme.dart';
import '../profile/profile_repository.dart';

/// Tingle-profile reference screen using NIMZO identity and real routes.
/// Existing user data and the former MeScreen remain available for regression QA.
class TingleMeScreen extends ConsumerWidget {
  const TingleMeScreen({super.key});

  void _go(BuildContext context, String location) => context.push(location);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(currentUserIdProvider);
    final p = id == null ? null : ref.watch(profileProvider(id)).valueOrNull;
    final avatarPath = p?.avatarPath;
    final avatar = avatarPath == null ? null : ref.watch(supabaseProvider)
        .storage.from('avatars').getPublicUrl(avatarPath);

    final top = <({String label, String route})>[
      (label: 'Ranking', route: '/ranking'),
      (label: 'My Store', route: '/store'),
      (label: 'Backpack', route: '/store?bag=1'),
      (label: 'Family', route: '/info/Family'),
    ];
    const tiles = <({String label, IconData icon, Color first, Color last})>[
      (label: 'CP Space', icon: Icons.public_rounded,
        first: Color(0xffff4bc4), last: Color(0xffe22aa7)),
      (label: 'Level', icon: Icons.shield_rounded,
        first: Color(0xff26e7ca), last: Color(0xff03bda9)),
      (label: 'Daily Rewards', icon: Icons.card_giftcard_rounded,
        first: Color(0xffc18aff), last: Color(0xff9732f7)),
      (label: 'Task', icon: Icons.event_available_rounded,
        first: Color(0xffffd277), last: Color(0xffffa100)),
    ];
    const menu = <({String title, IconData icon, Color color, String route})>[
      (title: 'Host Request', icon: Icons.person_add_alt_1_rounded,
        color: Color(0xff9e69e5), route: '/info/Host%20Request'),
      (title: 'Demo Agency', icon: Icons.badge_rounded,
        color: Color(0xff2699e4), route: '/info/Demo%20Agency'),
      (title: 'Demo Host', icon: Icons.support_agent_rounded,
        color: Color(0xff82c233), route: '/info/Demo%20Host'),
      (title: 'Demo BD', icon: Icons.verified_rounded,
        color: Color(0xffef5993), route: '/info/Demo%20BD'),
      (title: 'Coin Trading', icon: Icons.wallet_rounded,
        color: Color(0xffa13ae5), route: '/wallet'),
      (title: 'Help', icon: Icons.support_agent_rounded,
        color: Color(0xffffae36), route: '/info/Help%20and%20feedback'),
      (title: 'Referral', icon: Icons.group_add_rounded,
        color: Color(0xfff64e99), route: '/info/Referral'),
      (title: 'About Us', icon: Icons.info_rounded,
        color: Color(0xffffaa22), route: '/info/About'),
    ];

    return Scaffold(
      backgroundColor: const Color(0xfff5f4ff),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xffc6c6ff), Color(0xfff2f0ff),
              Color(0xfff8f7ff)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(15, 12, 15, 22),
            children: [
              Row(
                children: [
                  const Expanded(child: Text('My Profile',
                    style: TextStyle(fontSize: 21,
                      fontWeight: FontWeight.w900, color: Colors.black))),
                  IconButton(
                    tooltip: 'My QR / profile',
                    onPressed: id == null ? null
                      : () => _go(context, '/profile/' + id),
                    icon: const Icon(Icons.qr_code_2_rounded, size: 27,
                      color: Color(0xff24243e)),
                  ),
                  IconButton(
                    tooltip: 'Friends',
                    onPressed: () => _go(context, '/friends'),
                    icon: const Icon(Icons.people_alt_outlined,
                      size: 25, color: Color(0xff29213d)),
                  ),
                  IconButton(
                    tooltip: 'Settings',
                    onPressed: () => _go(context, '/settings'),
                    icon: const Icon(Icons.hexagon_outlined, size: 27,
                      color: Color(0xff29213d)),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: const [
                    BoxShadow(color: Color(0x0d4f3b96),
                      blurRadius: 10, offset: Offset(0, 2)),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(9, 7, 9, 10),
                child: Column(children: [
                  Row(
                    children: [
                      for (final item in top)
                        Expanded(child: TextButton(
                          onPressed: id == null && item.label == 'Family'
                              ? null : () => _go(context, item.route),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 0, vertical: 10),
                          ),
                          child: Text(item.label,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xff6f658a),
                              fontSize: 10, fontWeight: FontWeight.w700,
                            )),
                        )),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final (i, item) in tiles.indexed)
                        Expanded(child: InkWell(
                          onTap: () {
                            if (i == 0) _go(context, '/cp');
                            if (i == 1) _go(context, '/levels');
                            if (i == 2) _go(context, '/daily-checkin');
                            if (i == 3) _go(context, '/task');
                          },
                          child: Column(
                            children: [
                              Container(
                                width: 45, height: 45,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [item.first, item.last],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  border: Border.all(
                                    color: Colors.white, width: 3),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: const [
                                    BoxShadow(color: Color(0x226a47aa),
                                      blurRadius: 8, offset: Offset(0, 5)),
                                  ],
                                ),
                                child: Icon(item.icon,
                                  color: Colors.white, size: 26),
                              ),
                              const SizedBox(height: 5),
                              Text(item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xff70638d),
                                  fontSize: 12, fontWeight: FontWeight.w700,
                                )),
                            ],
                          ),
                        )),
                    ],
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 5),
                child: Column(
                  children: [
                    for (final (i, item) in menu.indexed) ...[
                      ListTile(
                        minTileHeight: 56,
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 37, height: 37,
                          decoration: BoxDecoration(
                            color: item.color.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: item.color.withValues(alpha: .15)),
                          ),
                          alignment: Alignment.center,
                          child: Icon(item.icon, color: item.color, size: 23),
                        ),
                        title: Text(item.title,
                          style: const TextStyle(
                            color: Color(0xff6f608c),
                            fontSize: 14, fontWeight: FontWeight.w700)),
                        trailing: const Icon(Icons.chevron_right_rounded,
                          color: Color(0xff796c96), size: 20),
                        onTap: () => _go(context, item.route),
                      ),
                      if (i < menu.length - 1)
                        const Divider(height: 1,
                          color: Color(0xfff0ecf4)),
                    ],
                  ],
                ),
              ),
              ),
              const SizedBox(height: 16),
              // The screenshot's first viewport is the quick navigation hub.
              // Real account identity and optional VIP previews remain
              // available below its reference menu instead of displacing it.
              if (id != null) ...[
                InkWell(
                  onTap: () => _go(context, '/profile/' + id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 27,
                          backgroundColor: NimzoStyle.primary,
                          backgroundImage:
                            avatar == null ? null : NetworkImage(avatar),
                          child: avatar == null
                            ? const Icon(Icons.person_rounded,
                                color: Colors.white, size: 28)
                            : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p?.displayName ?? 'My NIMZO account',
                              style: const TextStyle(fontSize: 17,
                                fontWeight: FontWeight.w800)),
                            Text('ID: ' + (p?.nimzoId.toString() ?? '…'),
                              style: const TextStyle(
                                color: Color(0xff6e638a), fontSize: 12)),
                            const SizedBox(height: 4),
                            if (p != null) Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xffeee6fc),
                                borderRadius: BorderRadius.circular(9)),
                              child: Text('Lv. ' + p.wealthLevel.toString(),
                                style: const TextStyle(
                                  color: NimzoStyle.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                            ),
                          ],
                        )),
                        IconButton(
                          tooltip: 'Edit profile',
                          onPressed: () => _go(context, '/edit-profile'),
                          icon: const Icon(Icons.edit_outlined,
                            color: Color(0xff8579a7)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: _MembershipShortcut(
                    title: 'VIP',
                    subtitle: 'Member collection',
                    icon: Icons.workspace_premium_rounded,
                    start: const Color(0xff1d133e),
                    end: const Color(0xff8c44bc),
                    onTap: () => _go(context, '/vip'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MembershipShortcut(
                    title: 'SVIP',
                    subtitle: 'Luxury tiers',
                    icon: Icons.diamond_rounded,
                    start: const Color(0xff46143c),
                    end: const Color(0xffcf3b86),
                    onTap: () => _go(context, '/svip'),
                  ),
                ),
              ]),
              const SizedBox(height: 13),

            ],
          ),
        ),
      ),
    );
  }
}

class _MembershipShortcut extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color start, end;
  final VoidCallback onTap;
  const _MembershipShortcut({
    required this.title, required this.subtitle, required this.icon,
    required this.start, required this.end, required this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(22),
    child: Container(
      height: 93,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [start, end]),
        borderRadius: BorderRadius.circular(22)),
      child: Row(children: [
        Icon(icon, color: const Color(0xffffd69a), size: 30),
        const SizedBox(width: 9),
        Expanded(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(
              color: Colors.white, fontSize: 18,
              fontWeight: FontWeight.w900)),
            Text(subtitle,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70,
                fontSize: 11)),
          ],
        )),
      ]),
    ),
  );
}
