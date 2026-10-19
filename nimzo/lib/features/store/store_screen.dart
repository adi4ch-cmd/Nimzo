import 'package:flutter/material.dart';
import 'store_live_catalog.dart';
import '../../core/widge/// Live original NIMZO cosmetics Store and account-persistent Backpack.
class RoyalStoreScreen extends StatelessWidget {
  final bool initialBag;
  const RoyalStoreScreen({super.key, this.initialBag = false});

  @override
  Widget build(BuildContext context) =>
      NimzoLiveStore(initialBag: initialBag);
}

allery(),
      ],
    ),
  );
}

/// UI-only collection preview for product categories whose server catalog
/// is not yet verified. No prices, fake ownership, charges, or checkout.
/// The supplied screenshot establishes layout, not saleable inventory.
class StoreCategoryPreview extends StatefulWidget {
  final String category;
  final IconData icon;
  final Color accent;
  const StoreCategoryPreview({
    super.key,
    required this.category,
    required this.icon,
    required this.accent,
  });

  @override
  State<StoreCategoryPreview> createState() => _StoreCategoryPreviewState();
}

class _StoreCategoryPreviewState extends State<StoreCategoryPreview>
    with SingleTickerProviderStateMixin {
  late final motion = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600), value: 1);
  NimzoArt get kind => switch (widget.category) {
        'Avatar Frame' => NimzoArt.frame,
        'Party Theme' => NimzoArt.theme,
        'Rides' => NimzoArt.entrance,
        'Chat Bubble' => NimzoArt.bubble,
        'Live Frame' => NimzoArt.live,
        _ => NimzoArt.crest,
      };
  void replay() {
    if (MediaQuery.disableAnimationsOf(context)) {
      motion.value = 1;
    } else {
      motion.forward(from: 0);
    }
  }

  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  int selected = 0;
  static const styles = <({String name, IconData icon})>[
    (name: 'Golden Stars', icon: Icons.stars_rounded),
    (name: 'Kiss Me', icon: Icons.favorite_outline_rounded),
    (name: 'Cherry Blossom', icon: Icons.local_florist_rounded),
    (name: 'Neon', icon: Icons.auto_awesome_rounded),
    (name: 'Floral', icon: Icons.spa_rounded),
    (name: 'Hearts', icon: Icons.favorite_rounded),
    (name: 'Royal', icon: Icons.diamond_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = <Color>[
      const Color(0xffffd277),
      const Color(0xfff577bf),
      const Color(0xfff49bb6),
      const Color(0xffb48afa),
      const Color(0xff91e7c4),
      const Color(0xff7dc6f7),
      const Color(0xffeac19b),
    ];
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.category,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800)),
        centerTitle: true,
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xffabb2fa),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 12),
          child: Row(children: [
            Expanded(
                child: Text(styles[selected].name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800))),
            const SizedBox(width: 12),
            const Chip(
              key: ValueKey('store-category-preview-only'),
              label: Text('Preview only'),
              avatar: Icon(Icons.visibility_outlined, size: 17),
            ),
          ]),
        ),
      ),
      body: ListView(
        key: const ValueKey('store-category-preview'),
        children: [
          Container(
            height: 270,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xffb3b7ff), Color(0xfff8f7ff)],
              ),
            ),
            alignment: Alignment.center,
            child: Stack(alignment: Alignment.center, children: [
              AnimatedBuilder(
                  animation: motion,
                  builder: (context, _) => AnimatedSwitcher(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      child: NimzoIdentityArt(
                          key: ValueKey('$kind-$selected'),
                          kind: kind,
                          color: colors[selected],
                          variant: selected,
                          size: 222,
                          progress: motion.value))),
              if (kind == NimzoArt.entrance)
                Positioned(
                    bottom: 6,
                    child: TextButton.icon(
                      onPressed: replay,
                      icon: const Icon(Icons.replay_rounded, size: 18),
                      label: const Text('Replay entrance preview'),
                      style: TextButton.styleFrom(
                          foregroundColor: const Color(0xff70439a)),
                    )),
              if (kind == NimzoArt.entrance)
                Positioned(
                    right: 8,
                    top: 8,
                    child: IconButton(
                        tooltip: 'Replay entrance preview',
                        onPressed: replay,
                        icon: const Icon(Icons.play_circle_outline_rounded))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(widget.category,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Original design previews · items are not available '
              'for purchase until a verified catalog is connected.',
              style: TextStyle(fontSize: 11, color: Color(0xff8b8298)),
            ),
          ),
          const SizedBox(height: 13),
          GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: styles.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 14,
              crossAxisSpacing: 9,
              childAspectRatio: .80,
            ),
            itemBuilder: (context, index) => InkWell(
              key: ValueKey('store-preview-style-$index'),
              borderRadius: BorderRadius.circular(17),
              onTap: () {
                setState(() => selected = index);
                replay();
              },
              child: Column(children: [
                Expanded(
                    child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xfff4f2ff),
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(
                        color: selected == index
                            ? const Color(0xffa343ed)
                            : Colors.transparent,
                        width: 2),
                  ),
                  child: Center(
                    child: NimzoIdentityArt(
                        kind: kind,
                        size: 80,
                        color: colors[index],
                        variant: index),
                  ),
                )),
                const SizedBox(height: 5),
                Text(styles[index].name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
          const SizedBox(height: 25),
        ],
      ),
    );
  }
}

class StoreDesignGallery extends StatelessWidget {
  const StoreDesignGallery({super.key});
  static const designs = [
    (
      NimzoArt.frame,
      'Avatar Frame',
      Color(0xffc195f2),
      Icons.filter_frames_rounded
    ),
    (NimzoArt.theme, 'Party Theme', Color(0xff91e1cf), Icons.palette_rounded),
    (
      NimzoArt.entrance,
      'Rides',
      Color(0xffffca7e),
      Icons.directions_car_rounded
    ),
    (
      NimzoArt.bubble,
      'Chat Bubble',
      Color(0xff91c9fc),
      Icons.chat_bubble_rounded
    ),
    (NimzoArt.live, 'Live Frame', Color(0xfff7a3d2), Icons.crop_square_rounded),
  ];
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('NIMZO Design Collection',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Original art · previews only',
            style: TextStyle(fontSize: 11, color: Color(0xff80738d))),
        const SizedBox(height: 10),
        GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: .94,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              for (final design in designs)
                Semantics(
                    button: true,
                    label: 'Preview ${design.$2}',
                    child: InkWell(
                      key: ValueKey('store-design-${design.$1.name}'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => StoreCategoryPreview(
                                  category: design.$2,
                                  icon: design.$4,
                                  accent: design.$3))),
                      child: Container(
                          decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xff20152f),
                                    Color(0xff40234f)
                                  ]),
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.all(8),
                          child: Column(children: [
                            Expanded(
                                child: Center(
                                    child: NimzoIdentityArt(
                                        kind: design.$1,
                                        color: design.$3,
                                        size: 110))),
                            Text(design.$2,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 11)),
                            const SizedBox(height: 5),
                            Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 3),
                                decoration: BoxDecoration(
                                    color: const Color(0xff9c40ec),
                                    borderRadius: BorderRadius.circular(12)),
                                child: const Text('Preview',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 10))),
                          ])),
                    ))
            ]),
      ]);
}
