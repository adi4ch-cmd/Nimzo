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
