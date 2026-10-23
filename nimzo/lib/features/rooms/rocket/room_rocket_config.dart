import '../../../core/services/approved_media_bytes.dart';

const originalRocketThresholds = <int>[
  5000000,
  10000000,
  20000000,
  30000000,
  50000000,
  100000000,
];

enum RocketSoundMode { embedded, synthesized, muted }

/// Owner-published immutable identity for a decoder already shipped in the app.
class RocketMediaDescriptor {
  const RocketMediaDescriptor(
      {required this.url, required this.publication, required this.soundMode});
  final String url;
  final ApprovedMediaPublication publication;
  final RocketSoundMode soundMode;

  factory RocketMediaDescriptor.fromJson(Map<String, dynamic> row) {
    final url = row['url'];
    final hash = row['sha256'];
    final size = row['byte_size'];
    final sound = row['sound_mode'];
    final rights = row['rights_reference'];
    if (url is! String ||
        !ApprovedMediaBytes.isSafeUrl(url) ||
        hash is! String ||
        size is! int ||
        row['codec'] != 'vap' ||
        row['mime_type'] != 'video/mp4' ||
        rights is! String ||
        rights.trim().isEmpty ||
        rights.length > 500 ||
        row['verified_at'] is! String ||
        DateTime.tryParse(row['verified_at'] as String) == null ||
        row['device_verified_at'] is! String ||
        DateTime.tryParse(row['device_verified_at'] as String) == null ||
        !['embedded', 'synthesized', 'muted'].contains(sound)) {
      throw const FormatException('Invalid published Rocket VAP media');
    }
    final publication = ApprovedMediaPublication(
        sha256Hex: hash, byteLength: size, mimeType: 'video/mp4', codec: 'vap');
    if (!publication.isValid || !Uri.parse(url).path.contains(hash)) {
      throw const FormatException('Unverified Rocket media identity');
    }
    return RocketMediaDescriptor(
        url: url,
        publication: publication,
        soundMode: RocketSoundMode.values.byName(sound as String));
  }
}

/// Each room/cycle and each settled milestone reference this exact version.
class RoomRocketConfig {
  const RoomRocketConfig(
      {required this.version,
      required this.thresholds,
      required this.artworkStages,
      required this.stageLabels,
      required this.title,
      required this.subtitle,
      required this.flyMedia,
      required this.rewardMedia});

  static const original = RoomRocketConfig(
      version: 1,
      thresholds: originalRocketThresholds,
      artworkStages: [1, 2, 3, 4, 5, 6],
      stageLabels: [
        'Rocket 1',
        'Rocket 2',
        'Rocket 3',
        'Rocket 4',
        'Rocket 5',
        'Rocket 6'
      ],
      title: 'ROOM ROCKET',
      subtitle: 'Gift together to launch six rocket levels',
      flyMedia: [null, null, null, null, null, null],
      rewardMedia: [null, null, null, null, null, null]);

  final int version;
  final List<int> thresholds, artworkStages;
  final List<String> stageLabels;
  final String title, subtitle;
  final List<RocketMediaDescriptor?> flyMedia, rewardMedia;

  factory RoomRocketConfig.fromJson(Map<String, dynamic> row) {
    final version = row['version'] ?? row['config_version'];
    final targets = row['thresholds'];
    final art = row['artwork_stages'];
    final labels = row['stage_labels'];
    final title = row['title'];
    final subtitle = row['subtitle'];
    final fly = row['fly_media'];
    final reward = row['reward_media'];
    if (version is! int ||
        version < 1 ||
        targets is! List ||
        targets.isEmpty ||
        targets.length > 6 ||
        art is! List ||
        art.length != targets.length ||
        labels is! List ||
        labels.length != targets.length ||
        title is! String ||
        title.trim().isEmpty ||
        title.length > 80 ||
        subtitle is! String ||
        subtitle.length > 180 ||
        fly is! List ||
        reward is! List ||
        fly.length != targets.length ||
        reward.length != targets.length) {
      throw const FormatException('Invalid pinned Rocket configuration');
    }
    var previous = 0;
    for (var i = 0; i < targets.length; i++) {
      final target = targets[i];
      final artwork = art[i];
      final label = labels[i];
      if (target is! int ||
          target <= previous ||
          target > 9007199254740991 ||
          artwork is! int ||
          artwork < 1 ||
          artwork > 6 ||
          label is! String ||
          label.trim().isEmpty ||
          label.length > 48) {
        throw const FormatException('Unsupported Rocket stage configuration');
      }
      previous = target;
    }
    List<RocketMediaDescriptor?> media(List values) =>
        List.unmodifiable(values.map((value) {
          if (value == null) return null;
          if (value is! Map)
            throw const FormatException('Invalid Rocket media');
          return RocketMediaDescriptor.fromJson(
              Map<String, dynamic>.from(value));
        }));
    return RoomRocketConfig(
        version: version,
        thresholds: List<int>.unmodifiable(targets.cast<int>()),
        artworkStages: List<int>.unmodifiable(art.cast<int>()),
        stageLabels: List<String>.unmodifiable(labels.cast<String>()),
        title: title,
        subtitle: subtitle,
        flyMedia: media(fly),
        rewardMedia: media(reward));
  }
}
