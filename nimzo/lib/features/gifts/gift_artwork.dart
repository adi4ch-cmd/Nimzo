import 'package:flutter/material.dart';

String? referenceGiftArtwork(String name) {
  final index = switch (name.trim().toLowerCase()) {
    'spark' => 0,
    'rose' || 'eternal rose' => 1,
    'heart' || 'love heart' => 2,
    'wonder box' => 3,
    'rocket' || 'star rocket' => 4,
    'golden king' => 5,
    'royal couple' => 6,
    'diamond' || 'royal diamond' => 7,
    'royal dragon' || 'legend dragon' => 8,
    'crown' || 'emperor crown' => 9,
    'galaxy empire' => 10,
    'dream kingdom' => 11,
    'world crown' => 12,
    _ => null,
  };
  return index == null ? null : 'assets/reference/gift/$index.jpg';
}

class GiftArtwork extends StatelessWidget {
  final String name;
  final String? assetPath;
  const GiftArtwork({super.key, required this.name, this.assetPath});
  @override
  Widget build(BuildContext context) {
    const unavailable = Center(
      child: Text(
        'Artwork unavailable',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11),
      ),
    );
    final path = assetPath ?? referenceGiftArtwork(name);
    if (path == null) return unavailable;
    if (Uri.tryParse(path)?.scheme == 'https')
      return Image.network(path, errorBuilder: (_, __, ___) => unavailable);
    if (path.startsWith('assets/'))
      return Image.asset(path, errorBuilder: (_, __, ___) => unavailable);
    return unavailable;
  }
}
