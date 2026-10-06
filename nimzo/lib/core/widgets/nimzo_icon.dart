import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../theme/colors.dart';

/// A single vector family throughout the app. Existing semantic call sites stay
/// compatible while all primary navigation and actions use Lucide's line icons.
class NimzoIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final bool active;
  final Color? color;
  const NimzoIcon(
    this.icon, {
    super.key,
    this.size = 24,
    this.active = false,
    this.color,
  });

  static IconData vector(IconData icon) => _vectors[icon] ?? icon;
  static final Map<IconData, IconData> _vectors = {
    Icons.home_outlined: LucideIcons.home,
    Icons.home_rounded: LucideIcons.home,
    Icons.sports_esports_outlined: LucideIcons.gamepad2,
    Icons.sports_esports_rounded: LucideIcons.gamepad2,
    Icons.auto_awesome_outlined: LucideIcons.sparkles,
    Icons.auto_awesome_rounded: LucideIcons.sparkles,
    Icons.chat_bubble_outline_rounded: LucideIcons.messageCircle,
    Icons.chat_bubble_rounded: LucideIcons.messageCircle,
    Icons.chat_bubble_outline: LucideIcons.messageCircle,
    Icons.person_outline_rounded: LucideIcons.user,
    Icons.person_rounded: LucideIcons.user,
    Icons.person: LucideIcons.user,
    Icons.search_rounded: LucideIcons.search,
    Icons.emoji_events_outlined: LucideIcons.trophy,
    Icons.add_circle_rounded: LucideIcons.plusCircle,
    Icons.add_rounded: LucideIcons.plus,
    Icons.chevron_right_rounded: LucideIcons.chevronRight,
    Icons.public_rounded: LucideIcons.globe2,
    Icons.flag_rounded: LucideIcons.flag,
    Icons.lock_rounded: LucideIcons.lock,
    Icons.mic_rounded: LucideIcons.mic,
    Icons.mic_off: LucideIcons.micOff,
    Icons.account_balance_wallet_rounded: LucideIcons.wallet,
    Icons.workspace_premium_rounded: LucideIcons.crown,
    Icons.settings_rounded: LucideIcons.settings,
    Icons.settings_outlined: LucideIcons.settings,
    Icons.logout_rounded: LucideIcons.logOut,
    Icons.notifications_none_rounded: LucideIcons.bell,
    Icons.send_rounded: LucideIcons.send,
    Icons.send: LucideIcons.send,
    Icons.card_giftcard_rounded: LucideIcons.gift,
    Icons.photo_library_outlined: LucideIcons.image,
    Icons.broken_image_outlined: LucideIcons.imageOff,
    Icons.broken_image_rounded: LucideIcons.imageOff,
    Icons.done_all_rounded: LucideIcons.checkCheck,
    Icons.check_circle_rounded: LucideIcons.checkCircle2,
    Icons.add_photo_alternate_rounded: LucideIcons.imagePlus,
    Icons.more_horiz_rounded: LucideIcons.moreHorizontal,
    Icons.monetization_on_rounded: LucideIcons.coins,
    Icons.camera_alt_outlined: LucideIcons.camera,
    Icons.inbox: LucideIcons.inbox,
    Icons.favorite: LucideIcons.heart,
    Icons.favorite_border: LucideIcons.heart,
    Icons.favorite_rounded: LucideIcons.heart,
    Icons.diamond_rounded: LucideIcons.gem,
    Icons.arrow_back: LucideIcons.arrowLeft,
    Icons.chevron_right: LucideIcons.chevronRight,
    Icons.expand_more: LucideIcons.chevronDown,
    Icons.card_giftcard: LucideIcons.gift,
    Icons.card_giftcard_outlined: LucideIcons.gift,
    Icons.casino_outlined: LucideIcons.dices,
    Icons.done: LucideIcons.check,
    Icons.done_all: LucideIcons.checkCheck,
    Icons.event_seat_outlined: LucideIcons.armchair,
    Icons.flag_outlined: LucideIcons.flag,
    Icons.grid_view_rounded: LucideIcons.layoutGrid,
    Icons.group_add_outlined: LucideIcons.userPlus,
    Icons.group_outlined: LucideIcons.users,
    Icons.people_outline_rounded: LucideIcons.users,
    Icons.meeting_room_outlined: LucideIcons.doorOpen,
    Icons.mic_off_outlined: LucideIcons.micOff,
    Icons.mic_external_on_rounded: LucideIcons.mic,
    Icons.monetization_on_outlined: LucideIcons.coins,
    Icons.more_horiz: LucideIcons.moreHorizontal,
    Icons.north_east: LucideIcons.arrowUpRight,
    Icons.person_add_alt_1_rounded: LucideIcons.userPlus,
    Icons.person_remove_outlined: LucideIcons.userMinus,
    Icons.play_arrow_rounded: LucideIcons.play,
    Icons.rule_outlined: LucideIcons.listChecks,
    Icons.share_outlined: LucideIcons.share2,
    Icons.south_west: LucideIcons.arrowDownLeft,
  };
  @override
  Widget build(BuildContext context) => Icon(
    vector(icon),
    size: size,
    color: color ?? (active ? NimzoColors.primary : NimzoColors.textSecondary),
  );
}

class NimzoNavIcon extends StatelessWidget {
  final IconData icon;
  final bool active;
  const NimzoNavIcon(this.icon, {super.key, required this.active});
  @override
  Widget build(BuildContext context) =>
      NimzoIcon(icon, size: 22, active: active);
}
