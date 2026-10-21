/// A read-only fact evaluated by the server; the client never awards honors.
class HonorMilestone {
  final String code, title, category, description;
  final int progress, target;
  final bool earned;
  final DateTime? earnedAt;

  const HonorMilestone({
    required this.code,
    required this.title,
    required this.category,
    required this.description,
    required this.progress,
    required this.target,
    required this.earned,
    this.earnedAt,
  });

  factory HonorMilestone.fromJson(Map<String, dynamic> row) => HonorMilestone(
        code: row['code'] as String,
        title: row['title'] as String,
        category: row['category'] as String,
        description: row['description'] as String,
        progress: (row['progress'] as num).toInt(),
        target: (row['target'] as num).toInt(),
        earned: row['earned'] == true,
        earnedAt: DateTime.tryParse(row['earned_at'] as String? ?? ''),
      );

  double get fraction => target <= 0 ? 0 : (progress / target).clamp(0.0, 1.0);
}
