import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svga/flutter_svga.dart';

/// Original, unchanged Tana/Vani media with per-file hashes in SOURCE_INVENTORY.
/// Static category images do not claim to be animated gifts or equipment.
/// Does not call any payment, gifting, claim, or equip RPC.
class LicensedStoreMedia {
  const LicensedStoreMedia(this.title, this.category, this.assetPath,
      {this.animated = false});
  final String title;
  final String category;
  final String assetPath;
  final bool animated;
}

const licensedStoreMedia = <LicensedStoreMedia>[
  LicensedStoreMedia('Love Room Theme', 'Themes', 'assets/licensed_tana_vani/tana/ic_room_theme_love.webp', animated: false),
  LicensedStoreMedia('Supreme Room Theme', 'Themes', 'assets/licensed_tana_vani/tana/ic_room_theme_supreme.webp', animated: false),
  LicensedStoreMedia('Room Rank Decoration 1', 'Frames', 'assets/licensed_tana_vani/tana/room_rank_avatar_frame1.webp', animated: false),
  LicensedStoreMedia('Room Rank Decoration 2', 'Frames', 'assets/licensed_tana_vani/tana/room_rank_avatar_frame2.webp', animated: false),
  LicensedStoreMedia('Room Rank Decoration 3', 'Frames', 'assets/licensed_tana_vani/tana/room_rank_avatar_frame3.webp', animated: false),
  LicensedStoreMedia('Avatar Frame Artwork', 'Frames', 'assets/licensed_tana_vani/tana/ic_avatar_frame.webp', animated: false),
  LicensedStoreMedia('Avatar Frame Icon', 'Frames', 'assets/licensed_tana_vani/tana/ic_store_avatar_frame.webp', animated: false),
  LicensedStoreMedia('Vani Frame Collection Artwork', 'Category Art', 'assets/licensed_tana_vani/vani/cat_frames.jpg', animated: false),
  LicensedStoreMedia('Vani Room Themes Artwork', 'Category Art', 'assets/licensed_tana_vani/vani/cat_themes.jpg', animated: false),
  LicensedStoreMedia('Vani Chat Bubbles Artwork', 'Category Art', 'assets/licensed_tana_vani/vani/cat_chat_bubbles.png', animated: false),
  LicensedStoreMedia('Vani Entry Artwork', 'Category Art', 'assets/licensed_tana_vani/vani/cat_entry.png', animated: false),
  LicensedStoreMedia('Vani Action Entry Artwork', 'Category Art', 'assets/licensed_tana_vani/vani/cat_action_entry.png', animated: false),
  LicensedStoreMedia('Store Top Background', 'Store UI', 'assets/licensed_tana_vani/tana/bg_store_top.webp', animated: false),
  LicensedStoreMedia('Store Wallet Background', 'Store UI', 'assets/licensed_tana_vani/tana/bg_store_wallet.webp', animated: false),
  LicensedStoreMedia('Room Capacity Artwork', 'Store UI', 'assets/licensed_tana_vani/tana/bg_store_room_capacity_9.webp', animated: false),
  LicensedStoreMedia('Backpack Transfer Artwork', 'Store UI', 'assets/licensed_tana_vani/tana/bg_store_to_backpack.webp', animated: false),
  LicensedStoreMedia('Mic Theme Dialog Artwork', 'Store UI', 'assets/licensed_tana_vani/tana/bg_mic_theme_dialog.png', animated: false),
  LicensedStoreMedia('Store Cars Category Icon', 'Store UI', 'assets/licensed_tana_vani/tana/props_store_tab_cars_true.webp', animated: false),
  LicensedStoreMedia('Store Frames Category Icon', 'Store UI', 'assets/licensed_tana_vani/tana/props_store_tab_frames_true.webp', animated: false),
  LicensedStoreMedia('Store Themes Category Icon', 'Store UI', 'assets/licensed_tana_vani/tana/props_store_tab_theme_true.webp', animated: false),
  LicensedStoreMedia('Store Entry Category Icon', 'Store UI', 'assets/licensed_tana_vani/tana/props_store_tab_entryefect_true.webp', animated: false),
  LicensedStoreMedia('Store Bubbles Category Icon', 'Store UI', 'assets/licensed_tana_vani/tana/props_store_tab_bubble_true.webp', animated: false),
  LicensedStoreMedia('My Store Icon', 'Store UI', 'assets/licensed_tana_vani/tana/ic_mine_store.webp', animated: false),
  LicensedStoreMedia('My Backpack Icon', 'Store UI', 'assets/licensed_tana_vani/tana/ic_mine_backpack.webp', animated: false),
  LicensedStoreMedia('Entry Decoration', 'Store UI', 'assets/licensed_tana_vani/tana/ic_bottle_entry.png', animated: false),
  LicensedStoreMedia('Birthday Celebration SVGA', 'Animated', 'assets/licensed_tana_vani/tana/birthdayanimation.svga', animated: true),
];

class LicensedStoreGallery extends StatefulWidget {
  const LicensedStoreGallery({super.key});
  @override
  State<LicensedStoreGallery> createState() => _LicensedStoreGalleryState();
}

class _LicensedStoreGalleryState extends State<LicensedStoreGallery> {
  String filter = 'All';
  static const filters = <String>[
    'All', 'Animated', 'Themes', 'Frames', 'Category Art', 'Store UI'
  ];

  @override
  Widget build(BuildContext context) {
    final shown = licensedStoreMedia
        .where((media) => filter == 'All' || media.category == filter)
        .toList();
    return Scaffold(
      key: const ValueKey('licensed-original-media-gallery'),
      appBar: AppBar(title: const Text('Original Store Media')),
      body: SafeArea(child: Column(children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Text(
            '26 original imported media files. Tap to see the actual full '
            'image or SVGA motion. Artwork and category icons are not '
            'automatically equipable cosmetics or paid gifts.',
            style: TextStyle(fontSize: 12),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final name in filters)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ChoiceChip(
                    label: Text(name),
                    selected: filter == name,
                    onSelected: (_) => setState(() => filter = name),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            key: const ValueKey('licensed-media-grid'),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
            itemCount: shown.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: .78,
              crossAxisSpacing: 10,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, i) {
              final media = shown[i];
              return InkWell(
                key: ValueKey('licensed-media-' + media.assetPath),
                borderRadius: BorderRadius.circular(14),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => _OriginalMediaPreview(media: media),
                  ),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xfff7f9f7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xffe0eae5)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(children: [
                      Expanded(child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: media.animated
                          ? const Center(child: Icon(Icons.play_circle,
                              size: 64, color: Color(0xff078e69)))
                          : Image.asset(
                              media.assetPath,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              errorBuilder: (_, __, ___) =>
                                  const Center(child: Text('Media unavailable')),
                            ),
                      )),
                      const SizedBox(height: 7),
                      Text(media.title,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                      Text(media.animated ? 'Original SVGA motion' : 'Original static media',
                          style: const TextStyle(
                            fontSize: 10, color: Color(0xff5a7667))),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
      ])),
    );
  }
}

class _OriginalMediaPreview extends StatefulWidget {
  const _OriginalMediaPreview({required this.media});
  final LicensedStoreMedia media;
  @override
  State<_OriginalMediaPreview> createState() => _OriginalMediaPreviewState();
}

class _OriginalMediaPreviewState extends State<_OriginalMediaPreview>
    with SingleTickerProviderStateMixin {
  SVGAAnimationController? controller;
  String? error;
  @override
  void initState() {
    super.initState();
    if (widget.media.animated) {
      controller = SVGAAnimationController(vsync: this);
      controller!.muted = false;
      unawaited(_loadOriginalAnimation());
    }
  }

  Future<void> _loadOriginalAnimation() async {
    try {
      final item = await SVGAParser.shared.decodeFromAssets(widget.media.assetPath);
      if (!mounted) {
        item.dispose();
        return;
      }
      controller!.videoItem = item;
      setState(() {});
      await controller!.forward();
    } catch (_) {
      if (mounted) setState(() => error = 'Unable to decode this SVGA on this device.');
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.media;
    return Scaffold(
      key: const ValueKey('licensed-media-full-preview'),
      appBar: AppBar(title: Text(media.title)),
      body: SafeArea(child: Column(children: [
        Expanded(child: Center(child: Padding(
          padding: const EdgeInsets.all(12),
          child: media.animated
            ? controller?.videoItem == null
                ? Text(error ?? 'Loading original SVGA animation...')
                : SVGAImage(controller!)
            : InteractiveViewer(
                minScale: .6,
                maxScale: 3,
                child: Image.asset(media.assetPath, fit: BoxFit.contain),
              ),
        ))),
        if (media.animated)
          TextButton.icon(
            key: const ValueKey('licensed-svga-replay'),
            onPressed: controller?.videoItem == null ? null : () {
              controller!.reset();
              unawaited(controller!.forward());
            },
            icon: const Icon(Icons.replay),
            label: const Text('Replay original animation'),
          ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Text(
            'Actual imported source media — preview only. '
            'No coins are charged and no equipment is granted.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12),
          ),
        ),
      ])),
    );
  }
}
