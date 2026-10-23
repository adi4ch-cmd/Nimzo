/// Tracks changes in server-derived levels without inventing progress.
///
/// Initial hydration never announces a level-up. Only a strictly increasing
/// level for the same authenticated user can produce a celebration.
class VerifiedLevelUpTracker {
  String? _userId;
  List<int>? _previous;

  List<VerifiedLevelIncrease> observe(String userId, List<int> levels) {
    if (levels.length != 3) {
      throw ArgumentError.value(levels, 'levels', 'Expected Wealth, Charm, Active');
    }
    final clean = levels.map((level) => level < 0 ? 0 : level).toList();
    if (_userId != userId) {
      _userId = userId;
      _previous = clean;
      return const [];
    }
    final old = _previous;
    _previous = clean;
    if (old == null) return const [];
    return [
      for (var kind = 0; kind < 3; kind++)
        if (clean[kind] > old[kind])
          VerifiedLevelIncrease(kind: kind, from: old[kind], to: clean[kind]),
    ];
  }
}

class VerifiedLevelIncrease {
  const VerifiedLevelIncrease({
    required this.kind,
    required this.from,
    required this.to,
  });

  final int kind;
  final int from;
  final int to;
}
