import 'package:flutter/material.dart';

import 'moment_photo.dart';

/// Compact feed thumbnails; the viewer keeps the complete original accessible.
class MomentPhotoGrid extends StatelessWidget {
  const MomentPhotoGrid({super.key, required this.paths});
  final List<String> paths;

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) return const SizedBox.shrink();
    final columns = paths.length == 1
        ? 1
        : paths.length == 2
            ? 2
            : 3;
    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      primary: false,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: paths.length == 1 ? 4 / 3 : 1,
      ),
      itemCount: paths.length,
      itemBuilder: (context, index) => ClipRRect(
        key: ValueKey('moment-photo-tile-$index'),
        borderRadius: BorderRadius.circular(10),
        child: Material(
          color: const Color(0xfff5f2f8),
          child: InkWell(
            onTap: () => showDialog<void>(
              context: context,
              useSafeArea: false,
              builder: (_) => _MomentPhotoViewer(paths: paths, initial: index),
            ),
            child: Semantics(
              label: 'Open photo ${index + 1} of ${paths.length}',
              image: true,
              button: true,
              child: MomentPhoto(path: paths[index]),
            ),
          ),
        ),
      ),
    );
  }
}

class _MomentPhotoViewer extends StatefulWidget {
  const _MomentPhotoViewer({required this.paths, required this.initial});
  final List<String> paths;
  final int initial;

  @override
  State<_MomentPhotoViewer> createState() => _MomentPhotoViewerState();
}

class _MomentPhotoViewerState extends State<_MomentPhotoViewer> {
  late final PageController pages;
  late int selected;

  @override
  void initState() {
    super.initState();
    selected = widget.initial;
    pages = PageController(initialPage: selected);
  }

  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
        backgroundColor: const Color(0xff101018),
        child: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Close photo',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                  Expanded(
                    child: Text('${selected + 1} / ${widget.paths.length}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              Expanded(
                child: PageView.builder(
                  controller: pages,
                  itemCount: widget.paths.length,
                  onPageChanged: (page) => setState(() => selected = page),
                  itemBuilder: (_, index) => InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Center(
                      child: MomentPhoto(
                          path: widget.paths[index], fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
