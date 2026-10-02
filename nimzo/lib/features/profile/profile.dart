class Profile {
  final String id;
  final int nimzoId;
  final String? username, displayName, bio, avatarPath, coverPath, countryCode, countryName, language, gender;
  final DateTime? dateOfBirth;
  final int level, wealthLevel, charmLevel, activeLevel, vipLevel, svipLevel;
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
    this.level = 1,
    this.wealthLevel = 1,
    this.charmLevel = 1,
    this.activeLevel = 1,
    this.vipLevel = 0,
    this.svipLevel = 0,
  });

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
        dateOfBirth: j['date_of_birth'] == null ? null : DateTime.tryParse(j['date_of_birth'].toString()),
        level: (j['level'] ?? 1) as int,
        wealthLevel: (j['wealth_level'] ?? 1) as int,
        charmLevel: (j['charm_level'] ?? 1) as int,
        activeLevel: (j['active_level'] ?? 1) as int,
        vipLevel: (j['vip_level'] ?? 0) as int,
        svipLevel: (j['svip_level'] ?? 0) as int,
      );
}
