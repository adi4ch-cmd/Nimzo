# NIMZO v3 dynamic implementation and TEST build scope

The owner now permits a TEST APK after dynamic source/backend checks. Vivox is OWNER_DEFERRED. Final full-task acceptance remains held: this report does not assert authenticated device purchases, native voice or physical-device media/audio tests.

## Preserved integration

Work is isolated in `integration/nimzo-v3-dynamic-20261021`, worktree `/workspace/Nimzo-v3`. Existing main/integration worktrees were not reset or cleaned. PR #40's latest source at `098aa0d` was merged. Older feature code/assets, financial history and live user data were retained. No production QA debit, purchase or fake gift event was issued.

The source is 1.0.39+139. Existing automatic APK workflows remain held. The new v3 TEST workflow additionally requires a source-matched dynamic acceptance record and an explicit `[dynamic-qa]` commit or manual dispatch. It runs source tests before compiling, checks exact packaged media, then installs/launches on an Android emulator before publishing a prerelease. It publishes no automatic-update manifest.

## Dynamic contracts implemented

| Destination | Owner-managed publication | Actual authority |
| --- | --- | --- |
| Gifts | `gifts`, `gift_animation_media`: activity, category, priority, prices, thumbnails, verified codecs, sound, duration/aspect/transparency/source, availability windows and minimum VIP | Checked send RPCs retain original atomic settlements, payouts and immutable receipt keys; server checks price/window/eligibility/media |
| Store/Backpack | Existing catalogs/media plus duration and immutable media/thumbnail descriptors | Atomic purchase, durable debit/no-charge receipts, ownership expiry, renewals and equipment RLS |
| VIP/SVIP | Existing real tier prices/recharge thresholds/rewards plus `nimzo_membership_presentations` | Existing effective membership/status and guarded claims; checked-price VIP wrapper |
| Rocket | Published immutable `room_rocket_configs`, pinned once per room/day | Verified gift events drive progress/contributions and exactly-once milestone events; no invented extra prize |
| Games | Existing engine activation plus `nimzo_remote_settings['games.presentation']` | Known compiled engine slugs only; presentation cannot introduce engines, wagers, outcomes or permissions |
| Events | Existing banners, dates and supported route allowlist, with verified image columns | Owner-only publication; exact time-window refresh and safe destination selection |
| Room backgrounds | `nimzo_remote_settings['room.backgrounds']` approved known theme images | Existing room ownership/settings/mic authorization; presentation cannot modify powers |
| Level styles | `nimzo_remote_settings['progression.styles']` validated color/glyph/shape/bands | Existing server XP/earned levels; styling cannot award XP or entitlement |

Realtime revision high-water tracking invalidates targeted catalogs; account transitions reset media access. Resume/reconnect and periodic fallback refresh recover missed publications. Gift and Store pagination supports up to 5,000 records; snapshots are account-scoped, bounded and expire after 24 hours. Offline catalog presentation does not authorize purchases/equipment. Store expiry schedules a refresh and excludes expired equipment; server RLS independently protects older clients.

New paid content uses bounded HTTPS, immutable SHA256 paths, exact size/MIME/magic, PNG/JPEG/WebP decoding and bounded SVGA inflation/protobuf/resource validation before checkout. Native players consume verified private files rather than downloading mutable URLs again. New VAP publications require structural packed-alpha configuration; resource-dependent remote VAP stays unavailable until its resolver is supported. Existing bundled Haza reward resources remain handled by the existing native resolver. Native publication approval requires actual rights/device evidence; no newly extracted animation was activated based on a thumbnail.

Gift and Store pending confirmations preserve account, context/item, original amount and retry key across restart. Read-only receipt recovery precedes media lookup, so deactivated objects cannot hide a completed charge. Unknown transport/media failures preserve the pending confirmation. Known server rollbacks can release it. Account changes after a media await abort a new checkout.

## Actual assets and UI

All six Rocket fly/reward pairs remain from the same Haza package. Transparent posters were regenerated from their actual packed alpha, and the sheet now uses the unified ivory/emerald/gold layout. The client supports server-configured stage counts, labels, thresholds and artwork mapping; playback fetches the exact event's published configuration rather than a newer cycle.

Voku 1.1.7 supplies a complete matching 10 VIP + 10 SVIP hero/badge set: 40 packaged PNGs with source paths, checksums and dimensions in `nimzo/assets/membership/voku/manifest.json`. All 40 were decoded by Flutter's real ImageCodec test. These are artwork/badges, not advertised as animated cars or equipment benefits. Unverified extracted entrance candidates stay inactive.

Gift/Store previews use the real supported renderer or explicitly labelled artwork preview. Games distinguish playable server engines, local practice and board previews. Events show actual server campaigns or honest loading/error/empty states; five screenshot-derived fake campaigns were removed. Existing Store media and original WillChill assets are preserved.

## Backend deployment and verification

Seven reviewed additive migrations were applied to project `kvqvlpozqokwarovwmwv` on 2026-10-22:

- `20261021120000_dynamic_verified_media_publications.sql`
- `20261021120100_dynamic_membership_presentation.sql`
- `20261021144829_gift_checked_send_expected_price.sql`
- `20261021145817_dynamic_room_rocket_cycle_config.sql`
- `20261021150306_dynamic_store_ownership_expiry.sql`
- `20261021151626_dynamic_game_event_presentation.sql`
- `20261022115352_dynamic_gift_availability_and_sound.sql`

Supabase migration history records server-generated application timestamps and descriptive v3 names; these files were not blindly replayed as a full reset. No existing ownership was assigned an expiry and no membership artwork was falsely approved. Read-only post-deployment checks found 4 wallets and all 34 existing Rocket history rows retained, original six thresholds active, all four sampled new RPCs authenticated-only and zero new membership presentation rows.

Disposable PostgreSQL runners validate actual original settlement functions, price/media rollback, lost-response receipt recovery, concurrent same/different keys, duration locking, expiry and renewal, membership reward/price rules, Rocket publication/cycle pinning and rollover, anonymous denial/RLS, banner staging and gift availability/minimum-VIP rules. Each runner creates a fresh isolated database; fixtures never contact production. Source QA repeats these checks in its own PostgreSQL service.

Reproduce from the repository using the `tools/test_*` runners, with a running test PostgreSQL Docker container and a NEW fixture database name. Evidence summaries are recorded in `docs/validation/v3-evidence/` when checks finish.

## Remaining verification boundaries

The TEST APK is for device QA. Vivox is intentionally deferred by the owner; the native source and Codespace SDK helper are preserved. Codespaces access previously returned HTTP403, so this environment cannot verify the SDK claimed to exist there. This is not a claim that the SDK is absent.

Authenticated Android login, paid checkout/claim, remote publication changes across real devices, native VAP/SVGA audio and physical-device voice coexistence still need runtime QA. Unsupported executable game engines cannot be delivered by remote JSON. Native/financial features are not certified by a screenshot or source-test count. Final release/build authorization remains false until the complete original task and these runtime checks pass.

Development-signed QA APKs have no automatic-update manifest. Android rejects replacing an installed app signed with a different certificate. Preserve the installed app and local data; use a separate test device when signatures differ.
