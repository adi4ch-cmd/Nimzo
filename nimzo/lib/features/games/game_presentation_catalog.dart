import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/nimzo_content_sync.dart';
import '../../core/services/published_catalog_image.dart';
import 'game_catalog.dart';

final gamePresentationCatalogProvider =
    Provider<GamePresentationCatalog>((ref) {
  final settings = ref.watch(nimzoRemoteSettingsProvider).valueOrNull;
  return GamePresentationCatalog.parse(settings?['games.presentation']);
});

class GamePresentation {
  const GamePresentation._(this.slug, this.title, this.category, this.image);
  final String slug, title, category;
  final PublishedCatalogImage image;
}

/// Only known shipped slugs can receive artwork/labels. Neither navigation nor
/// activation, engine, rules, outcome or financial authority is configurable.
class GamePresentationCatalog {
  const GamePresentationCatalog._(this.games);
  static const empty = GamePresentationCatalog._({});
  final Map<String, GamePresentation> games;
  static const categories = {'Party', 'Slots', 'Cards'};
  static const _fields = {'slug', 'title', 'category', 'image'};

  static GamePresentationCatalog parse(Object? value) {
    if (value is! Map ||
        value.length != 2 ||
        value['version'] is! int ||
        value['version'] != 1 ||
        value['games'] is! List) return empty;
    final rows = value['games'] as List;
    if (rows.length > NimzoRoomGames.all.length) return empty;
    final result = <String, GamePresentation>{};
    for (final row in rows) {
      if (row is! Map ||
          row.length != _fields.length ||
          !row.keys.every(_fields.contains)) return empty;
      final slug = row['slug'],
          title = row['title'],
          category = row['category'];
      if (slug is! String ||
          !NimzoRoomGames.all.any((g) => g.slug == slug) ||
          result.containsKey(slug) ||
          title is! String ||
          title.trim() != title ||
          title.isEmpty ||
          title.runes.length > 40 ||
          RegExp(r'[\x00-\x1f\x7f\u202a-\u202e\u2066-\u2069]')
              .hasMatch(title) ||
          !categories.contains(category)) return empty;
      final image = PublishedCatalogImage.parse(row['image']);
      if (image == null) return empty;
      result[slug] = GamePresentation._(slug, title, category as String, image);
    }
    return GamePresentationCatalog._(Map.unmodifiable(result));
  }

  String titleFor(NimzoGame game) => games[game.slug]?.title ?? game.title;
  String categoryFor(NimzoGame game) =>
      games[game.slug]?.category ?? originalCategory(game.slug);
  static String originalCategory(String slug) {
    if (slug == 'teen_patti') return 'Cards';
    if (slug == 'jackpot' || slug == 'lucky_77') return 'Slots';
    return 'Party';
  }
}
