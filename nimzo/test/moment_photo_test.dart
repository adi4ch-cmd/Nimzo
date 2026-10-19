import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/moments/moment_photo.dart';

void main() {
  testWidgets('legacy Moment photos retry the original moment-images bucket',
      (tester) async {
    final db = (await tester.runAsync(() async => SupabaseClient(
          'https://example.supabase.co',
          'key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        )))!;
    addTearDown(() => tester.runAsync(db.dispose));
    await tester.pumpWidget(ProviderScope(
      overrides: [supabaseProvider.overrideWithValue(db)],
      child: const MaterialApp(
          home: Scaffold(body: MomentPhoto(path: 'user/photo.jpg'))),
    ));
    final image = tester.widget<Image>(find.byType(Image));
    expect(
        (image.image as NetworkImage).url, endsWith('/moments/user/photo.jpg'));
    final fallback = image.errorBuilder!(
        tester.element(find.byType(Image)), Exception('404'), null) as Image;
    expect((fallback.image as NetworkImage).url,
        endsWith('/moment-images/user/photo.jpg'));
    final unavailable = fallback.errorBuilder!(
        tester.element(find.byType(Image)), Exception('404'), null);
    // Both missing objects stop at a visible error, with no retry loop.
    expect(unavailable, isNot(isA<Image>()));
  });
}
