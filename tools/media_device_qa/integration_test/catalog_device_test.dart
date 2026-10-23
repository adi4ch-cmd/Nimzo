import 'package:integration_test/integration_test.dart';

import '../test/catalog_render_suite.dart';
import '../test/vap_render_suite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  catalogRenderSuite(
    manifestAsset: 'assets/membership/remix/manifest.json',
    minimumCount: 70,
    label: 'YoHo VIP and Falla SVIP',
  );
  vapRenderSuite();
  catalogRenderSuite(
    manifestAsset: 'assets/drive_catalog_premium/manifest.json',
    minimumCount: 1,
    label: 'Diverse premium SVGA gifts',
    mediaKinds: {'svga'},
  );
  catalogRenderSuite();
  catalogRenderSuite(
    manifestAsset: 'assets/drive_catalog_expanded/manifest.json',
    minimumCount: 48,
    label: 'Expanded catalog',
  );
}
