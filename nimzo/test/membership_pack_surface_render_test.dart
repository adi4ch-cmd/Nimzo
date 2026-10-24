import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/premium/membership_identity.dart';
import 'package:nimzo/features/premium/membership_status.dart';
import 'package:nimzo/features/premium/membership_pack_runtime.dart';
import 'tingle_video_ui_test.dart' show capture, loadReviewFonts;

void main() {
  testWidgets(
      'all20 selected original frames and nameplates render around actual avatar widgets',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await loadReviewFonts();
    final boundary = GlobalKey();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          effectiveMembershipProvider.overrideWith((_, id) async {
            final kind = id.startsWith('svip') ? 'svip' : 'vip';
            final tier = int.parse(id.substring(kind.length));
            return MembershipStatus.fromJson({
              '${kind}_level': tier,
              'pack_kind': kind,
              'pack_tier': tier,
              'pack_slots': ['Avatar Frame', 'ID Frame', 'Royal Badge']
            });
          }),
        ],
        child: MaterialApp(
            theme: ThemeData(fontFamily: 'Roboto'),
            home: Scaffold(
                backgroundColor: const Color(0xff10182a),
                body: RepaintBoundary(
                    key: boundary,
                    child: Column(children: [
                      const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                              'NIMZO · All20 applied avatar surfaces · Flutter host render',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 20))),
                      Expanded(
                          child: GridView.count(
                              crossAxisCount: 4,
                              childAspectRatio: 1,
                              children: [
                            for (final kind in ['vip', 'svip'])
                              for (var tier = 1; tier <= 10; tier++)
                                Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('${kind.toUpperCase()} $tier',
                                          style: const TextStyle(
                                              color: Color(0xfff0d28b))),
                                      const SizedBox(height: 10),
                                      MembershipPackAvatar(
                                          userId: '$kind$tier',
                                          size: 100,
                                          child: const CircleAvatar(
                                              backgroundColor:
                                                  Color(0xff276c8c),
                                              child: Icon(Icons.person,
                                                  color: Colors.white,
                                                  size: 38))),
                                      const SizedBox(height: 15),
                                      MembershipPackNameplate(
                                          userId: '$kind$tier',
                                          child: const Text('NIMZO member')),
                                    ]),
                          ])),
                    ]))))));
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 20));
    }
    for (final kind in ['vip', 'svip'])
      for (var tier = 1; tier <= 10; tier++) {
        expect(find.byKey(ValueKey('membership-pack-avatar-$kind-$tier')),
            findsOneWidget);
      }
    expect(tester.takeException(), isNull);
    await capture(tester, 'all20-applied-avatar-surfaces-host', boundary);
  });
}
