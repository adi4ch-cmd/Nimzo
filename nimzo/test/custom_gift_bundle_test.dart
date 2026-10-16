// ignore_for_file: prefer_interpolation_to_compose_strings
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/gifts/gift_artwork.dart';
import 'package:nimzo/features/gifts/nimzo_custom_gift_effect.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const gifts = [
    'Kiss','Coffee','Cat','Birthday Cake','Teddy Bear','Gift Box',
    'Panda','Diamond Ring','Golden Palace','Private Jet',
    'Luxury Yacht','Dragon','Golden Dragon','Phoenix'
  ];

  test('all fourteen distinct NIMZO artwork assets are packaged', () async {
    final seen=<String>{};
    for(final gift in gifts) {
      final path=originalNimzoGiftArtwork(gift);
      expect(path,isNotNull,reason:gift);
      expect(seen.add(path!),isTrue,reason:'duplicate: '+gift);
      final data=await rootBundle.load(path);
      expect(data.lengthInBytes,greaterThan(200),reason:gift);
      expect(hasOriginalNimzoGiftEffect(gift),isTrue);
    }
    for (final name in ['Rose','Heart','Crown','Diamond','Rocket','Sports Car']) {
      expect(hasOriginalNimzoGiftEffect(name),isTrue);
    }
    expect(originalNimzoGiftArtwork('Unverified Gift'),isNull);
    expect(hasOriginalNimzoGiftEffect('Unverified Gift'),isFalse);
  });

  test('Phoenix artwork contains a bird head, beak and layered tail plumes',
      () async {
    final svg = await rootBundle.loadString(
      'assets/nimzo_custom_gifts/phoenix.svg',
    );
    expect(svg, contains('Distinct avian head'));
    expect(svg, contains('Three separate flame-tail plumes'));
    expect(RegExp('<path ').allMatches(svg).length, greaterThan(26));
    expect(svg, isNot(contains('M251 171Q167 105 80 95')));
  });

  testWidgets('royal Phoenix shows real bird art with moving flame stage',
      (tester) async {
    var finished = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SizedBox(
        width: 375, height: 700,
        child: NimzoCustomGiftEffect(
          name: 'Phoenix', sender: 'Sender 100005',
          recipient: 'Recipient 100006', quantity: 1,
          onFinished: () => finished++,
        ),
      )),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(GiftArtwork), findsOneWidget);
    expect(find.text('PHOENIX'), findsOneWidget);
    expect(find.text('ROYAL FLAME  ·  NIMZO'), findsOneWidget);
    expect(find.textContaining('Sender 100005 sent Phoenix'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Skip gift animation'));
    expect(finished, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('all fourteen original SVGs actually decode on Flutter',
      (tester) async {
    for (final gift in gifts) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body:SizedBox(width:240,height:240,
          child:GiftArtwork(name:gift))),
      ));
      await tester.pump(const Duration(milliseconds:100));
      expect(tester.takeException(),isNull,reason:gift);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('custom gift effect has actual moving artwork and can skip',
      (tester) async {
    var finished=0;
    await tester.pumpWidget(MaterialApp(
      home:Scaffold(body:SizedBox(
        height:700,width:375,
        child:NimzoCustomGiftEffect(
          name:'Coffee',sender:'Alice',recipient:'Bob',quantity:2,
          onFinished:()=>finished++),
      )),
    ));
    await tester.pump(const Duration(milliseconds:350));
    expect(find.byType(GiftArtwork),findsOneWidget);
    expect(find.text('COFFEE'),findsOneWidget);
    expect(tester.takeException(),isNull);
    await tester.tap(find.byTooltip('Skip gift animation'));
    expect(finished,1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
