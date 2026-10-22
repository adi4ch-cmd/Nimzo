import '../../../core/services/verified_media_file.dart';
import 'room_rocket_config.dart';

/// Native VAP always opens the exact checksum-verified local file. A packed
/// ordinary MP4 without VAP metadata is never passed to the Rocket decoder.
Future<VerifiedMediaFile> prepareRocketMediaFile(
    RocketMediaDescriptor media) async {
  // ApprovedMediaPublication validates bounded ISO BMFF atoms and the complete
  // packed VAP config before VerifiedMediaFile writes any native input.
  return VerifiedMediaFile.create(media.url, media.publication);
}

/// Remote publications explicitly choose one soundtrack. Existing bundled
/// rewards 4–6 keep their native AAC; the other originals use NIMZO effects.
bool rocketNativeMuted(RocketMediaDescriptor? media) =>
    media != null && media.soundMode != RocketSoundMode.embedded;

String? rocketSegmentSound(int artworkStage,
    {required bool reward, RocketMediaDescriptor? media}) {
  RangeError.checkValueInInterval(artworkStage, 0, 5, 'artworkStage');
  if (media != null && media.soundMode != RocketSoundMode.synthesized)
    return null;
  if (media == null && reward && artworkStage >= 3) return null;
  return reward
      ? 'assets/room_rocket/nimzo_rocket_reward.wav'
      : 'assets/room_rocket/nimzo_rocket_launch.wav';
}
