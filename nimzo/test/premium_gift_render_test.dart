import '../../tools/media_device_qa/test/catalog_render_suite.dart';

void main() {
  catalogRenderSuite(
    manifestAsset: 'assets/drive_catalog_premium/manifest.json',
    minimumCount: 1,
    label: 'Diverse premium SVGA gifts',
    mediaKinds: {'svga'},
  );
}
