import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/profile/me_screen.dart';
import 'package:nimzo/features/profile/profile.dart';
import 'package:nimzo/features/profile/profile_repository.dart';
void main() {
 testWidgets('Me uses real profile identity with separate VIP and SVIP links at phone width', (tester) async {
  tester.view.physicalSize=const Size(360,800);tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  final db=(await tester.runAsync(() async=>SupabaseClient('https://example.supabase.co','test',authOptions:const AuthClientOptions(autoRefreshToken:false))))!;
  addTearDown(()=>tester.runAsync(db.dispose));
  await tester.pumpWidget(ProviderScope(overrides:[
   supabaseProvider.overrideWithValue(db),currentUserIdProvider.overrideWithValue('u'),
   profileProvider('u').overrideWith((_)async=>const Profile(id:'u',nimzoId:101,displayName:'Amina',wealthLevel:1,charmLevel:1,activeLevel:1)),
   profileStatsProvider('u').overrideWith((_)async=>{'following':3,'followers':7,'visitors':2}),
   meGiftRankingProvider.overrideWith((_)async=>[]),
  ],child:const MaterialApp(home:MeScreen())));
  await tester.pumpAndSettle();
  expect(find.text('Amina'),findsOneWidget);expect(find.textContaining('101'),findsOneWidget);
  expect(find.text('VIP'),findsOneWidget);expect(find.text('SVIP'),findsOneWidget);
  expect(find.text('Wallet'),findsOneWidget);expect(find.text('MR CHARMING'),findsNothing);
  expect(tester.takeException(),isNull);
 });
}
