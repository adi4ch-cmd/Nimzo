import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'staged_gift_previews.dart';

/// Inactive gift media awaiting approval. Artwork is clearly identified as
/// a concept preview: never show a Send button or charge user coins here.
class PendingGiftGallery extends StatelessWidget {
  const PendingGiftGallery({super.key});

  void _open(BuildContext context, StagedGiftPreview gift) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        key: const ValueKey('nimzo-pending-gift-preview'),
        backgroundColor: const Color(0xff1c1432),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    tooltip: 'Close preview',
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
                SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: SvgPicture.asset(gift.iconAsset, fit: BoxFit.contain),
                ),
                const SizedBox(height: 12),
                Text(gift.name, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 21,
                    fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('ARTWORK PREVIEW ONLY',
                  style: TextStyle(color: Color(0xffffd18d), fontSize: 12,
                    fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text(
                  'Animation is not yet installed and verified. This gift cannot '
                  'be sent or purchased. No coins are charged.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xffd6d0e6), fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextButton(onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Close preview')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('COMING LATER · GIFT PREVIEWS',
        style: TextStyle(color: Color(0xffeac18b),
          fontWeight: FontWeight.w800, fontSize: 12)),
      const SizedBox(height: 5),
      const Text('Tap to inspect the artwork. These are not playable gifts yet.',
        style: TextStyle(color: Color(0xffb7a9d1), fontSize: 11)),
      const SizedBox(height: 12),
      GridView.builder(
        key: const ValueKey('pending-gift-grid'),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: stagedGiftPreviews.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10,
          childAspectRatio: .77,
        ),
        itemBuilder: (context, i) {
          final gift = stagedGiftPreviews[i];
          return InkWell(
            key: ValueKey('pending-gift-${gift.name}'),
            onTap: () => _open(context, gift),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xff291c48),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: const Color(0xff6e5989)),
              ),
              padding: const EdgeInsets.all(8),
              child: Column(children: [
                Expanded(child: SvgPicture.asset(
                  gift.iconAsset, fit: BoxFit.contain)),
                const SizedBox(height: 6),
                Text(gift.name, maxLines: 2, textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 11)),
                const Text('Preview', style: TextStyle(
                  color: Color(0xffffd18d), fontSize: 10)),
              ]),
            ),
          );
        },
      ),
    ]),
  );
}
