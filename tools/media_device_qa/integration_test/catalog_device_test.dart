import 'package:integration_test/integration_test.dart';

import '../test/catalog_render_suite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  catalogRenderSuite();
  catalogRenderSuite(
    manifestAsset: 'assets/drive_catalog_expanded/manifest.json',
    minimumCount: 48,
    label: 'Expanded catalog',
  );
}
