/// Recorded database recharge, in USD cents, compared only with deployed catalog rows.
/// Expiry, membership activation and payouts remain server decisions.
class SvipProgress {
  final int cycleCents;
  final Map<int, int> thresholds;
  SvipProgress({required this.cycleCents, required Map<int, int> thresholds})
      : thresholds = Map.unmodifiable(thresholds);

  int? thresholdFor(int level) => thresholds[level];
  List<MapEntry<int, int>> get _ordered =>
      thresholds.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
  int? get nextLevel =>
      _ordered.where((row) => row.value > cycleCents).firstOrNull?.key;
  int? get nextThresholdCents =>
      _ordered.where((row) => row.value > cycleCents).firstOrNull?.value;
  double? get fraction => thresholds.isEmpty
      ? null
      : nextThresholdCents == null
          ? 1
          : (cycleCents / nextThresholdCents!).clamp(0.0, 1.0);
}
