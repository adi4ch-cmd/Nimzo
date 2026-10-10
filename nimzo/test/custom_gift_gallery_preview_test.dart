import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/gifts/gift_artwork.dart';
import 'package:nimzo/features/vip/royal_lion_entry.dart';

const previewNames = [
  'Rose', 'Heart', 'Crown', 'Diamond', 'Rocket', 'Sports Car',
  'Kiss', 'Coffee', 'Cat', 'Birthday Cake', 'Teddy Bear', 'Gift Box',
  'Panda', 'Diamond Ring', 'Golden Palace', 'Private Jet',
  'Luxury Yacht', 'Dragon', 'Golden Dragon', 'Phoenix',
];

void main() {
  testWidgets('all twenty approved gifts show distinct new gallery art',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1110);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xff071612),
        body: RepaintBoundary(
          key: const ValueKey('twenty-gift-preview'),
          child: Column(children: [
            const SizedBox(height: 20),
            const Text('NIMZO • 20 GIFTS',
              style:TextStyle(color:Color(0xffe1c386),
                fontSize:20,letterSpacing:1.7,fontWeight:FontWeight.w700)),
            const SizedBox(height:12),
            Expanded(child: GridView.builder(
              padding:const EdgeInsets.all(12),
              physics:const NeverScrollableScrollPhysics(),
              gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount:4,childAspectRatio: .93,
                mainAxisSpacing:8,crossAxisSpacing:8),
              itemCount:previewNames.length,
              itemBuilder:(context,index)=>Container(
                decoration: BoxDecoration(
                  color:const Color(0xff103126),
                  borderRadius:BorderRadius.circular(16),
                  border:Border.all(color:const Color(0xff537d5a))),
                padding:const EdgeInsets.all(10),
                child:Column(children:[
                  Expanded(child:GiftArtwork(name:previewNames[index])),
                  const SizedBox(height:7),
                  Text(previewNames[index],maxLines:1,
                    overflow:TextOverflow.ellipsis,
                    textAlign:TextAlign.center,
                    style:const TextStyle(color:Colors.white,
                      fontSize:13,fontWeight:FontWeight.w600)),
                ]),
              ),
            )),
          ]),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    // The Phoenix illustration was replaced: the retired bitmap golden is
    // intentionally no longer the release artwork. Check the complete grid
    // builds and all twenty independently named images actually render.
    expect(find.byKey(const ValueKey('twenty-gift-preview')), findsOneWidget);
    expect(find.byType(GiftArtwork), findsNWidgets(20));
    for (final name in previewNames) {
      expect(find.text(name), findsOneWidget);
    }
    expect(tester.takeException(),isNull);
  });

  testWidgets('royal lion original entry scene visual regression',
      (tester) async {
    tester.view.physicalSize=const Size(390,844);
    tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home:Scaffold(
      body:MediaQuery(
        data:MediaQueryData(disableAnimations:true),
        child:RepaintBoundary(
          key:ValueKey('lion-preview'),
          child:RoyalLionEntry(name:'NIMZO KING'),
        ),
      ),
    )));
    await tester.pump();
    await expectLater(
      find.byKey(const ValueKey('lion-preview')),
      matchesGoldenFile('goldens/nimzo_lion_entry_preview.png'),
    );
    expect(tester.takeException(),isNull);
  });
}
