/// Effective membership comes from vip_status, never from cached profile fields.
/// Monetary actions require an explicit capability from a reviewed backend.
class MembershipStatus {
  MembershipStatus.fromJson(Map<String, dynamic> json)
      : retired = json['retired'] == true,
        canPurchase =
            json['retired'] == false && json['purchases_enabled'] == true,
        vipLevel = json['retired'] == true ? 0 : _level(json['vip_level']),
        svipLevel = json['retired'] == true ? 0 : _level(json['svip_level']),
        cycleCents = json['retired'] == true
            ? 0
            : (json['svip_cycle_cents'] as num?)?.toInt() ?? 0,
        vipExpiresAt = DateTime.tryParse('${json['vip_expires_at'] ?? ''}'),
        svipExpiresAt = DateTime.tryParse('${json['svip_expires_at'] ?? ''}'),
        vipDailyClaimed = json['vip_daily_claimed_today'] == true,
        canClaim = json['retired'] == false && json['claims_enabled'] == true,
        svipWeeklyClaimable = json['svip_weekly_claimable'] == true,
        svipAutoEnabled = json['svip_auto_enabled'] == true,
        vipDailyReward = (json['vip_daily_reward_coins'] as num?)?.toInt(),
        svipWeeklyReward = (json['svip_weekly_reward_coins'] as num?)?.toInt(),
        nextSvipPayout =
            DateTime.tryParse('${json['svip_next_payout_at'] ?? ''}');

  final bool retired,
      canPurchase,
      vipDailyClaimed,
      canClaim,
      svipWeeklyClaimable,
      svipAutoEnabled;
  final int? vipDailyReward, svipWeeklyReward;
  final DateTime? nextSvipPayout;
  final int vipLevel, svipLevel, cycleCents;
  final DateTime? vipExpiresAt, svipExpiresAt;

  static int _level(dynamic value) {
    final level = (value as num?)?.toInt() ?? 0;
    return level >= 1 && level <= 10 ? level : 0;
  }
}
