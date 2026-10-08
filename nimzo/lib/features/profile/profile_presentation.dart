import 'package:flutter/material.dart';
import '../../core/widgets/reference_widgets.dart';
import '../../core/theme/app_theme.dart';

class CouplePanel extends StatelessWidget {
  final String name;
  final String? partner, avatarUrl, partnerAvatarUrl;
  final int days;
  final VoidCallback? onAdd;
  const CouplePanel(
      {super.key,
      required this.name,
      this.partner,
      this.avatarUrl,
      this.partnerAvatarUrl,
      this.days = 0,
      this.onAdd});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Container(
                height: 110,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: const Color(0xfff5b942), width: 3),
                    gradient: const LinearGradient(
                        colors: [Color(0xfff43f5e), Color(0xffbe185d)])),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle, color: Colors.white),
                          child: NimzoAvatar(
                              name: name,
                              url: avatarUrl,
                              backgroundColor: NimzoStyle.ink,
                              size: 52)),
                      const Icon(Icons.favorite, color: Colors.white, size: 48),
                      partner == null
                          ? InkWell(
                              onTap: onAdd,
                              child: Container(
                                  width: 58,
                                  height: 58,
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2)),
                                  child: const Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text('+',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 20,
                                                height: 1)),
                                        FittedBox(
                                            child: Text('Add CP',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    height: 1)))
                                      ])))
                          : SizedBox(
                              width: 90,
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    NimzoAvatar(
                                        name: partner!,
                                        url: partnerAvatarUrl,
                                        size: 52),
                                    Text(partner!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 12))
                                  ])),
                    ])),
            Positioned(
                top: -12,
                child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    decoration: BoxDecoration(
                        color: const Color(0xfff5b942),
                        borderRadius: BorderRadius.circular(12)),
                    child: Text('$days Day',
                        style: const TextStyle(
                            color: Color(0xff78350f),
                            fontWeight: FontWeight.w700)))),
          ]));
}

class CollectibleArtwork extends StatelessWidget {
  final Map<String, dynamic> item;
  final double size;
  const CollectibleArtwork({super.key, required this.item, this.size = 58});
  @override
  Widget build(BuildContext context) {
    final path = item['image_path']?.toString() ??
        switch (item['name']?.toString().toLowerCase()) {
          'gold frame' => 'assets/reference/frame/0.jpg',
          'vip frame' => 'assets/reference/frame/1.jpg',
          'eagle car' => 'assets/reference/car/0.jpg',
          'jeep car' => 'assets/reference/car/1.jpg',
          _ => null
        };
    if (path != null && path.startsWith('assets/'))
      return Image.asset(path,
          width: size, height: size, errorBuilder: (_, __, ___) => _fallback());
    if (path != null && Uri.tryParse(path)?.scheme == 'https')
      return Image.network(path,
          width: size, height: size, errorBuilder: (_, __, ___) => _fallback());
    return _fallback();
  }

  Widget _fallback() => SizedBox(
      width: size,
      height: size,
      child: Center(
          child: Text(item['name']?.toString() ?? 'Artwork unavailable',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: NimzoStyle.muted))));
}

int profileAge(DateTime dob) {
  final now = DateTime.now();
  return now.year -
      dob.year -
      (now.month < dob.month || now.month == dob.month && now.day < dob.day
          ? 1
          : 0);
}
