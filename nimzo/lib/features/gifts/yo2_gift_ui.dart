import 'package:flutter/material.dart';

/// Original Yo2 gift controls are loaded only when the supplied archives have
/// been imported. Missing media is never represented as an original.
class Yo2GiftPanelArt extends StatelessWidget {
  const Yo2GiftPanelArt(
    this.filename, {
    super.key,
    this.width = 24,
    this.height = 24,
    this.fallback,
  });

  final String filename;
  final double width;
  final double height;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/yo2_gifts/images/$filename',
        width: width,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => fallback ?? const SizedBox.shrink(),
      );
}

/// Tabs are derived from NIMZO's live catalog. The two Dragon gifts are not
/// modified by Yo2-specific styling but remain available under All.
List<String> nimzoGiftCategories(Iterable<String> categories) {
  final result = <String>['All'];
  for (final category in categories) {
    final clean = category.trim();
    if (clean.isNotEmpty &&
        clean.toLowerCase() != 'dragon' &&
        !result
            .any((current) => current.toLowerCase() == clean.toLowerCase())) {
      result.add(clean);
    }
  }
  return result;
}

bool giftMatchesCategory(String giftCategory, String selectedCategory) =>
    selectedCategory.toLowerCase() == 'all' ||
    giftCategory.toLowerCase() == selectedCategory.toLowerCase();
