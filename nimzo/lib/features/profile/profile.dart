class Profile {
  final String id;
  final int nimzoId;
  final String? bio, avatarPath, coverPath, countryCode, countryName, language, gender;
  final DateTime? dateOfBirth;
  final int wealthLevel, charmLevel, activeLevel, vipLevel, svipLevel;
  const Profile({
    required this.id,
    required this.nimzoId,
    this.bio,
    this.avatarPath,
    this.coverPath,
    this.countryCode,
    this.countryName,
    this.language,
    this.gender,
    this.dateOfBirth,
    this.wealthLevel = 1,
    this.charmLevel = 1,
    this.activeLevel = 1,
    this.vipLevel = 0,
    this.svipLevel = 0,
  });

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j['id'],
        nimzoId: (j['nimzo_id'] as num).toInt(),
        bio: j['bio'],
        avatarPath: j['avatar_path'],
        coverPath: j['cover_path'],
        countryCode: j['country_code'],
        countryName: j['country_name'],
        language: j['language'],
        gender: j['gender'],
        dateOfBirth: j['date_of_birth'] == null ? null : DateTime.tryParse(j['date_of_birth']),
        wealthLevel: (j['wealth_level'] ?? 1) as int,
        charmLevel: (j['charm_level'] ?? 1) as int,
        activeLevel: (j['active_level'] ?? 1) as int,
        vipLevel: (j['vip_level'] ?? 0) as int,
        svipLevel: (j['svip_level'] ?? 0) as int,
      );
}
