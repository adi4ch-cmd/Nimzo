# Vivox 1105 and six-stage room Diamond Blast

## Approved room rules

Owner confirmed six cumulative room gifting targets: 5M,10M,20M,30M,50M,100Mcoins. Progress/blast animation only, no wallet rewards. Daily reset23:00GMT+3 (20:00UTC). Green, blue, pink are the first three stages; remaining approved purple/gold gems and the existing crowned crystal hero supply the next stages. No new placeholder artwork or modified game icons.

## Voice defect

The actual device reported `Voice login failed (code1105)`. Vivox5.28's VxcErrors.h defines1105 as `VX_E_SIP_BACKEND_REQUIRED`. Previous JNI used legacy vx_req_account_authtoken_login with a JWT in its auth-ticket field. The official SDKSampleApp's account_anonymous_login instead uses vx_req_account_anonymous_login,access_token and acct_name matching the signed SIP identity. Native bridge now uses that contract; Dart obtains/validates the account name from the existing authenticated voice-token accountUri and passes it through Java/JNI. Supabase accounts and their permanent identities do not change. No credentials/tokens logged. Previous R8 initialization callback retention repair remains.

Regression tests failed before repair, then passed. Release APK checks inspect all three ABI bridges for modern login imports and reject the old auth-ticket request, alongside concrete DEX callback retention. Correct compiled contracts do not prove physical voice connectivity; two-device microphone/audio verification remains unavailable in this environment.

## Server-authoritative Diamond Blast

Migration20261008231759_room_diamond_blast.sql deployed safely to the linked Supabase project. Private derived counters count actual settled gift_events once, atomically; room/cycle advisory locks serialize races. Current-cycle existing gifts seed the baseline without historical blast playback. Transition-table statement trigger excludes all new rows from that baseline, avoiding batch double counting. Crossed stages create unique durable events per room/cycle/stage. Gift replay and failed/rolled-back transactions create no duplicate blasts. No gift economics, wallet credit/debit, rewards or production user-row rewrites added.

room_diamond_status derives membership from auth.uid, exposes actual total, thresholds, stages, stage-local progress and server cycle timestamps. Clients cannot insert blast rows; membership RLS controls reads and Realtime. Metadata verification: RLS enabled, authenticated SELECT but no INSERT, anon RPC EXECUTE denied, one settlement trigger, publication enabled. Security advisor INFO for two private deny-all RLS tables and WARN for intentional guarded authenticated definer RPC reviewed; no unrelated permissions changed.

Flutter room host subscribes to both settled gift inserts (status refresh, including subthreshold/post-final gifts) and verified blast events (animation queue only). Queues/deduplicates stage events, has skip control, keeps microphone/game interactions active via IgnorePointer, clears on room/session departure and daily reset. Status timer uses reset_at minus server_now rather than the phone clock. Five original gem assets are preserved; third stage uses the approved pink asset; final stage uses the crowned crystal asset.

Tests use PG17 disposable metadata clones and UI/server fixtures. No production gifting/balance test or physical-device playback test performed. Fixture screenshot: nimzo/test/goldens/diamond_blast_live.png.

## Verification before integration

Flutter analyzer clean; 236 Flutter tests passed. Seven native voice contracts, native update test, tool contracts and 16 Edge Function tests passed. Disposable PG17 settlement/permission/race suites passed. Signed local 1.0.9+109 APK passed permanent certificate, packaged native libraries, DEX callback and modern login import gates. Physical device verification remains pending.

## Final merged release verification

Latest remote gift broadcast work preserved. Fixed literal escaped newlines that commented out its approved media lookup/client field; room fixtures explicitly mock its Realtime boundary. Final merged run: dart format 170 files/0 changes, analyzer no issues, all 236 Flutter tests passed. Signed 1.0.9+109 built; package io.nimzo.app, ZIP integrity/16KB alignment, three ABI libraries, concrete DEX callback and modern login gates passed. APK SHA256: 2f2b7579773c500cbef20e78c97030e38fd6c57d4a3e09a1e4f76fabdb81e0f6. Signing certificate SHA256: b11d41ae3037f16d639dc606af2ebf0150bf805a204577c7858cc044ff46bb4a. No physical device attached.

## Published delivery

Verified release workflow 37861430874 succeeded. Public test APK: https://github.com/adi4ch-cmd/Nimzo/releases/download/nimzo-release-31816fbef069/app-release.apk . Public APK downloaded again; metadata build109/checksum, certificate, package/version, ZIP integrity/alignment, three ABI native login and callback gates passed. Full automatic compile run37861281145 passed formatting/analyzer/tests but stopped at Require existing signing identity: four signing Secrets absent. Secrets integration access remains HTTP403. Existing permanent local key preserved; no replacement generated. Real-device login/audio, gifting playback and Android installation remain unverified.
