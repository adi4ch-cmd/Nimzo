import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/store/premium_cosmetics.dart';
import 'package:nimzo/features/store/store_live_catalog.dart';

void main() {
  testWidgets('Paid Store Buy button confirms actual server debit',
      (tester) async {
    var requests = 0;
    final db = SupabaseClient('https://example.supabase.co', 'test',
      httpClient: MockClient((request) async {
        requests++;
        expect(request.url.path, endsWith('/rpc/nimzo_store_purchase'));
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        expect(payload['p_item_id'], 'nimzo-test-premium-frame');
        expect(payload['p_expected_price'], 250000);
        expect(payload['p_key'], matches(RegExp(r'^[a-f0-9]{32}$')));
        return http.Response(jsonEncode({
          'status':'purchased',
          'item_id':'nimzo-test-premium-frame',
          'total':250000,
        }),200,request:request,headers:{'content-type':'application/json'});
      }), authOptions:const AuthClientOptions(autoRefreshToken:false));
    addTearDown(db.dispose);
    await tester.pumpWidget(ProviderScope(overrides:[
      sessionSupabaseProvider.overrideWithValue((client:db,userId:'test-user')),
      nimzoStoreProvider.overrideWith((_) async => NimzoStoreSnapshot(
        items:[const NimzoCosmeticItem(
          id:'nimzo-test-premium-frame',
          category:'Avatar Frame',
          name:'Premium Gold',
          variant:0,
          coinPrice:250000,
          assetUrl:'https://cdn.example.com/frame.svga',
          mediaKind:CosmeticMediaKind.svga,
        )],
        owned:{},equipped:{},
      )),
    ],child:const MaterialApp(home:NimzoLiveStore())));
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.textContaining('250000 coins'), findsWidgets);
    final buyButton = find.byKey(const ValueKey('nimzo-store-action-nimzo-test-premium-frame'));
    expect(buyButton, findsOneWidget);
    await tester.tap(buyButton);
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Confirm Store purchase'),findsOneWidget);
    expect(requests,0);
    await tester.tap(find.widgetWithText(FilledButton,'Buy').last);
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(requests,1);
    await tester.pumpWidget(const SizedBox());
  });
}
