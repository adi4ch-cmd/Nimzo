import '../../tools/media_device_qa/test/catalog_render_suite.dart';

// Host rendering is explicitly separate from Android verification.
void main() => catalogRenderSuite(
    manifestAsset: 'assets/membership/packs/verification_manifest.json',
    minimumCount: 105,
    label: 'Exact-tier membership originals');
