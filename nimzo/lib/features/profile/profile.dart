class Profile {
  final String id;
  final int nimzoId;
  final String? username,
      displayName,
      bio,
      avatarPath,
      coverPath,
      countryCode,
      countryName,
      language,
      gender;
  final DateTime? dateOfBirth;
  // Authoritative counters are distinct from levels; missing values stay unknown.
  final int? wealthCoins, charmDiamonds, activePoints;
  final int level, wealthLevel, charmLevel, activeLevel;
  const Profile({
    required this.id,
    required this.nimzoId,
    this.username,
    this.displayName,
    this.bio,
    this.avatarPath,
    this.coverPath,
    this.countryCode,
    this.countryName,
    this.language,
    this.gender,
    this.dateOfBirth,
    this.wealthCoins,
    this.charmDiamonds,
    this.activePoints,
    this.level = 1,
    this.wealthLevel = 0,
    this.charmLevel = 0,
    this.activeLevel = 0,
  });

  // Compatibility for older consumers: retired memberships can never be active.
  int get vipLevel => 0;
  int get svipLevel => 0;

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j['id'] as String,
        nimzoId: (j['nimzo_id'] as num).toInt(),
        username: j['username'] as String?,
        displayName: j['display_name'] as String?,
        bio: j['bio'] as String?,
        avatarPath: j['avatar_path'] as String?,
        coverPath: j['cover_path'] as String?,
        countryCode: j['country_code'] as String?,
        countryName: j['country_name'] as String?,
        language: j['language'] as String?,
        gender: j['gender'] as String?,
        wealthCoins: (j['wealth_coins'] as num?)?.toInt(),
        charmDiamonds: (j['charm_diamonds'] as num?)?.toInt(),
        activePoints: (j['active_points'] as num?)?.toInt(),
        dateOfBirth: j['date_of_birth'] == null
            ? null
            : DateTime.tryParse(j['date_of_birth'].toString()),
        level: (j['level'] ?? 1) as int,
        wealthLevel: (j['wealth_level'] ?? 0) as int,
        charmLevel: (j['charm_level'] ?? 0) as int,
        activeLevel: (j['active_level'] ?? 0) as int,
      );
}
