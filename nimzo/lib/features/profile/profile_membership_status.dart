import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'profile.dart';
import '../vip/vip_presentation.dart';

/// All profile surfaces share one truth: the server-verified active VIP/SVIP
/// levels in [Profile]. Preview tiers never masquerade as ownership.
class ProfileMembershipStatus extends StatelessWidget {
  const ProfileMembershipStatus({
    super.key,
    required this.profile,
    this.editable = false,
    this.compact = false,
  });

  final Profile profile;
  final bool editable;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (profile.vipLevel == 0 && profile.svipLevel == 0 && !editable) {
      return const SizedBox.shrink();
    }
    Widget item({required bool svip, required int level}) {
      final title = svip ? 'SVIP' : 'VIP';
      final tint = svip ? const Color(0xffb47a44)
          : const Color(0xff148661);
      final active = level >= 1 && level <= 10;
      return InkWell(
        key: ValueKey('profile-${svip ? 'svip' : 'vip'}-membership'),
        onTap: editable ? () => context.push(svip ? '/svip' : '/vip') : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 7 : 10,
            vertical: compact ? 4 : 6,
          ),
          decoration: BoxDecoration(
            color: tint.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tint.withValues(alpha: .29)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (active) MembershipEmblem(
              level: level, svip: svip, size: compact ? 27 : 35),
            if (!active) Icon(Icons.workspace_premium_outlined,
                size: compact ? 19 : 25, color: tint),
            const SizedBox(width: 5),
            Text(active ? '$title $level' : 'Get $title',
              style: TextStyle(color: tint,
                fontWeight: FontWeight.w800,
                fontSize: compact ? 10 : 12)),
            if (editable) ...[
              const SizedBox(width: 3),
              Icon(Icons.chevron_right, size: 15, color: tint),
            ],
          ]),
        ),
      );
    }
    return Wrap(
      key: const ValueKey('verified-membership-row'),
      spacing: 8, runSpacing: 6,
      children: [
        if (profile.vipLevel > 0 || editable)
          item(svip: false, level: profile.vipLevel),
        if (profile.svipLevel > 0 || editable)
          item(svip: true, level: profile.svipLevel),
      ],
    );
  }
}
