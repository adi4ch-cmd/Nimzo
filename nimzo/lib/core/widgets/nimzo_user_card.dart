import 'package:flutter/material.dart';
import '../../features/profile/profile.dart';
import 'nimzo_avatar.dart';
import 'nimzo_badge.dart';

class NimzoUserCard extends StatelessWidget {
  final Profile user;
  final String? avatarUrl;
  final Widget? trailing;
  final VoidCallback? onTap;
  const NimzoUserCard({super.key, required this.user, this.avatarUrl, this.trailing, this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        leading: NimzoAvatar(url: avatarUrl),
        title: Row(children: [
          Flexible(child: Text(user.displayName ?? 'User', overflow: TextOverflow.ellipsis)),
          if (user.svipLevel > 0) ...[const SizedBox(width: 6), NimzoBadge('SVIP${user.svipLevel}', gold: true)]
          else if (user.vipLevel > 0) ...[const SizedBox(width: 6), NimzoBadge('VIP${user.vipLevel}', gold: true)],
        ]),
        subtitle: Text('ID ${user.nimzoId}  ·  Lv ${user.level}'),
        trailing: trailing,
      );
}
