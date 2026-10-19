/// Preview-only NIMZO gifts. These are displayed in the SAME gift grid as
/// approved paid gifts; they cannot be purchased until rights-cleared,
/// transparent sound-enabled animations are deployed and server-approved.
///
/// Price labels are proposed prices, not an offer to charge or deliver.
class StagedGiftPreview {
  const StagedGiftPreview(this.name, this.proposedCoins, this.iconAsset);
  final String name, iconAsset;
  final int proposedCoins;
}
const stagedGiftPreviews = <StagedGiftPreview>[
  StagedGiftPreview('Libra', 100000, 'assets/gifts/libra.svg'),
  StagedGiftPreview('Aries', 100000, 'assets/gifts/aries.svg'),
  StagedGiftPreview('Romantic Blossom', 500000, 'assets/gifts/staged/romantic_blossom.svg'),
  StagedGiftPreview('Ice Queen Magic', 500000, 'assets/gifts/staged/ice_queen_magic.svg'),
  StagedGiftPreview('Tiger Warrior', 500000, 'assets/gifts/staged/tiger_warrior.svg'),
];
