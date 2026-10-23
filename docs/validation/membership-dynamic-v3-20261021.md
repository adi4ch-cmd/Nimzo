# Dynamic membership implementation (v3, proposed migration)

The new destination uses existing real VIP prices/duration, SVIP verified-recharge thresholds, effective `vip_status`/`phoenix_membership`, guarded reward claims and persistent purchase retry keys. It does not reinstate the old WillChill privilege grid or advertise frames, bubbles, mic waves or moderation immunity. Store equipment remains in Store. Navigation retains the historical `WillChillPremiumScreen` class name only for compatibility.

## Source decision and actual packaged artwork

The actual accessible package audit (`/workspace/nimzo-audit/media-audit.json`) was checked across every recorded VIP/SVIP package. Voku 1.1.7 is the best **complete matching VIP 1–10 + SVIP 1–10 hero/badge image set** found. Its 40 PNG files are now packaged under `nimzo/assets/membership/voku/`, with full APK/internal path, SHA256, length, dimensions and destination in `manifest.json`. All 40 PNGs passed Pillow verify/decode. Selected tier 1/5/10 heroes/badges were visually inspected in `/workspace/nimzo-audit/membership/voku-staged/contact-sheet.jpg`. No newer same-package version was available in the audited inventory; cross-app version numbers do not establish release chronology.

Alternatives considered: Falla 9.23.0 has 366 membership records and rich SVIP10 media but lacks a matched complete VIP+SVIP series; StarChat 8.41.3 has 814 records but mixes room controls/broadcasts with its tier art; Hafla 1.7.2 has419 records, SVIP10 art and only six VIP entrances; Orii1.0.15 has six SVIP entrances; existing WillChill only had seven VIP/eight SVIP tiers. BGChat/Bazmi and other recorded candidates lack the complete matching set. Voku car imagery is membership presentation only: no vehicle ownership/equipment benefit is invented.

The owner authorizes extraction/use of approved media. Package provenance is recorded without claiming a third-party license or release timestamp that was not supplied. Native animation candidates remain outside published catalogs: no VAP/SVGA entrance is activated based on a thumbnail or source-file presence.

## Dynamic contract and financial safety

`20261021120100_dynamic_membership_presentation.sql` is PROPOSED, not applied. It follows the already-present dynamic revision prerequisite and prospective membership restoration. It adds `nimzo_membership_presentations`, authenticated SELECT of approved active presentation columns, owner/service writes, private provenance/proof columns, constrained supported benefit keys, immutable hashed media descriptors and revision triggers using existing `settings`. It does not edit live accounts, wallets, rewards, catalog prices or old entitlements. Approval requires hero/badge plus an owner-provided device proof record; activation additionally requires approval. No rows are seeded.

The client watches targeted settings revisions, refreshes on resume/every minute/pull, scopes network requests to the session, and replaces remote presentation snapshots. The real equivalent bundled art remains available during offline/missing remote content. Published remote art overrides that baseline. Remote deactivation removes remote artwork/benefits/effects; it cannot remove already earned tier or invent new ownership. Authenticated tier prices and claims remain server-authoritative.

Every remote/bundled image is length/SHA256/MIME/magic checked and ImageCodec decoded before it enables the paid purchase action. URLs must be HTTPS and contain their content hash. Entrance SVGA/VAP supports bounded verified bytes; VAP uses a private temporary file, muted audio, lifecycle disposal and a 12-second watchdog. Native effects remain inactive pending device proof.

The new `nimzo_purchase_vip_checked(tier,key,expected_coins)` wrapper locks the existing idempotency key, returns existing settlement replay before mutable price/account checks, locks the selected catalog row against price updates, compares the confirmed price and delegates atomic settlement to the existing real purchase RPC. The client sends confirmed expected price, persists retry keys before RPC, clears only after confirmed/replayed response, and refreshes wallet/profile/effective membership. The original RPC remains for existing-client compatibility. New wrapper deployment is required before the new client purchase action can succeed.

## Verification and remaining blockers

No Flutter command, app build, live migration, production write or asset activation was run by the membership agent. Central coordinator owns Flutter checks. New focused checks:

- `flutter test --no-pub test/membership_catalog_test.dart test/membership_identity_test.dart test/membership_status_test.dart test/membership_status_provider_test.dart test/membership_purchase_keys_test.dart`
- Existing legacy showcase tests may still exercise the disconnected compatibility widget; they do not prove the new page or native playback.
- Isolated PostgreSQL: apply the new proposed migration after prerequisite fixtures; run `supabase/tests/dynamic_membership_presentation.sql` and `supabase/tests/membership_checked_purchase.sql` with `ON_ERROR_STOP=1`. Both roll back all fixture writes.

Device login, actual paid purchase/recharge, tier expiry at runtime, room entrance/badge rendering, remote publish/deactivate/reconnect demonstration and native effect proof remain required. Complete dynamic production acceptance is therefore **BLOCKED pending proposed migration review/application plus runtime/device verification**. No APK was built.
