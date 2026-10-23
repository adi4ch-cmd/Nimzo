import '../../tools/media_device_qa/test/catalog_render_suite.dart';

void main() => catalogRenderSuite(
    manifestAsset: 'assets/drive_catalog_expanded/manifest.json',
    minimumCount: 48,
    label: 'Expanded catalog');
