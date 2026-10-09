import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/vip/vip_presentation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('all 10 installed SVIP badges are real packaged WebP resources',
      () async {
    for (var tier = 1; tier <= 10; tier++) {
      final key = 'assets/membership/svip/svip_medal$tier.webp';
      final binary = await rootBundle.load(key);
      expect(binary.lengthInBytes, greaterThan(1000), reason: key);
      final header = binary.buffer.asUint8List(0, 4);
      expect(String.fromCharCodes(header), 'RIFF', reason: key);
    }
  });
  testWidgets('SVIP tier presentation uses packaged NIMZO medals',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home:
          Scaffold(body: Center(child: MembershipEmblem(level: 8, svip: true))),
    ));
    final img = tester.widget<Image>(find.byType(Image));
    expect((img.image as AssetImage).assetName,
        'assets/membership/svip/svip_medal8.webp');
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
