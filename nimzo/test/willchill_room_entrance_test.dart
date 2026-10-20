import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vap_player/flutter_vap_player.dart';
import 'package:nimzo/features/premium/willchill_own_svip_entrance.dart';

void main() {
  testWidgets('missing SVIP entrance media never blocks room UI',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Stack(children: [
        Text('Live room remains accessible'),
        WillChillOwnSvipEntrance(svipLevel: 5),
      ])),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Live room remains accessible'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid/unsupported SVIP levels are safely ignored',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: WillChillOwnSvipEntrance(svipLevel: 10)),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(VapPlayer), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
