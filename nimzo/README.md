# Nimzo

Flutter + Supabase + Firebase (FCM/Crashlytics only) + Vivox voice.

## Setup
1. `flutter create . --org io.nimzo --project-name nimzo` (adds android/ios folders), then `flutter pub get`.
2. Supabase: run `supabase/migrations/0001..0004` in order. Enable Google + Facebook providers. Add redirect `io.nimzo.app://login-callback` and the matching Android intent-filter.
3. Run: `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...` (anon key only; never the service_role key).
4. Firebase: add `google-services.json`, run `flutterfire configure`.
5. Edge Function: `supabase functions deploy verify-purchase` and set its secrets (see the file header).
6. Make yourself admin: `insert into admins(user_id) values ('<your uid>');` in the SQL editor.
7. Seed `recharge_packages`, `gifts`, `banners`.
8. Tests: `flutter test`; run `supabase/tests/economy.sql` in the SQL editor; run the checks in `supabase/tests/security.sql` as a normal user.

## Not finished / needs your input
- Vivox: `VivoxVoiceService` is a stub. It needs native SDK bindings plus a token Edge Function.
- Store purchase flow (in_app_purchase) is not wired into RechargeScreen; verification function is untested.
- Music player, room-invite/gift DM messages, Friends horizontal list, Achievements/Level data, Moments photo upload, Visitors screen, Blocked-users screen, offline banner.
- Full admin dashboard (rooms, coins, banners, announcements) should be a separate web app.
- Open questions: unit of SVIP Friday rewards (coins assumed), VIP prices, rounding remainder for non-multiples of 20.
- Nothing here has been compiled: expect to fix small errors on first `flutter analyze`.
