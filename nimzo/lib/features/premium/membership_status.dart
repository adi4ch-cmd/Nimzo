/// Effective membership comes from vip_status, never from cached profile fields.
/// Monetary actions require an explicit capability from a reviewed backend.
class MembershipStatus {
  MembershipStatus.fromJson(Map<String, dynamic> json)
      : _selectedKind = json['pack_kind'] as String?,
        _selectedTier = _level(json['pack_tier']),
        _slots =
            (json['pack_slots'] is List ? json['pack_slots'] as List : const [])
                .whereType<String>()
                .toSet(),
        _primaryKind = json['primary_kind'] as String?,
        _primaryTier = _level(json['primary_tier']),
        _serverNow = DateTime.tryParse('${json['server_now'] ?? ''}'),
        _receivedAt = DateTime.now(),
        retired = json['retired'] == true,
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
  final String? _selectedKind, _primaryKind;
  final int _selectedTier, _primaryTier;
  final Set<String> _slots;
  final DateTime? _serverNow;
  final DateTime _receivedAt;

  DateTime get serverNow => _serverNow == null
      ? DateTime.now()
      : _serverNow.add(DateTime.now().difference(_receivedAt));
  bool eligible(String kind, int tier) {
    if (retired || tier < 1 || tier > 10) return false;
    final level = kind == 'vip'
        ? vipLevel
        : kind == 'svip'
            ? svipLevel
            : 0;
    final expiry = kind == 'vip' ? vipExpiresAt : svipExpiresAt;
    return level == tier && (expiry == null || expiry.isAfter(serverNow));
  }

  String? get packKind =>
      _selectedKind != null && eligible(_selectedKind, _selectedTier)
          ? _selectedKind
          : null;
  int get packTier => packKind == null ? 0 : _selectedTier;
  bool hasSlot(String slot) => packKind != null && _slots.contains(slot);
  Set<String> get packSlots =>
      packKind == null ? const {} : Set.unmodifiable(_slots);
  String? get primaryKind {
    if (_primaryKind != null && eligible(_primaryKind, _primaryTier))
      return _primaryKind;
    if (eligible('svip', svipLevel)) return 'svip';
    if (eligible('vip', vipLevel)) return 'vip';
    return null;
  }

  int get primaryTier => primaryKind == 'svip'
      ? svipLevel
      : primaryKind == 'vip'
          ? vipLevel
          : 0;

  static int _level(dynamic value) {
    final level = (value as num?)?.toInt() ?? 0;
    return level >= 1 && level <= 10 ? level : 0;
  }
}
