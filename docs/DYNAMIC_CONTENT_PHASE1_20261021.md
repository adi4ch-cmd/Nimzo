# NIMZO Dynamic Content — Phase 1 (2026-10-21)

This is an additive, reversible-by-deactivation architecture. It intentionally
does not restore retired VIP/SVIP systems or old Gifts/Store media.

## What actually works after the migration and an APK built from this branch

* Existing `gifts` and `nimzo_cosmetic_catalog` remain the source of truth.
  Changes to their rows bump a **read-only content revision**.
* App listens to `nimzo_content_revisions` via Supabase Realtime.
  A gift revision refreshes `giftCatalogProvider`, Store revision refreshes
  `nimzoStoreProvider`, settings revision refreshes remote settings.
* `nimzo_cosmetic_media` optionally supplies an **approved HTTPS thumbnail**
  for each existing catalog item. Cards and full-screen previews load it remotely,
  with original bundled art still used when no remote thumbnail is configured.
* `nimzo_remote_settings` exposes small, approved config documents through
  `nimzoRemoteSettingsProvider` for later room/banner feature wiring.
* No new admin panel, bot, SDK, app-store update service, purchase RPC, or coins logic.

## Media publishing (privileged backend only)

1. Upload rights-cleared artwork to trusted HTTPS hosting/storage.
2. Review copyright, checksum, MIME/content and preview on test device.
3. In a privileged server-side session insert or update
   `public.nimzo_cosmetic_media(item_id, thumbnail_url, approved)`.
   Approval starts **false**. Do not grant ordinary app users writes.
4. A database statement automatically increments Store revision.
5. Signed-in devices receive Realtime revision, refetch approved media and
   show thumbnail without APK rebuild. Roll back by setting approved=false.

Do not use Flutter's service role key or let client-provided prices decide
wallet debits. Supabase RLS restricts all new tables to authenticated read;
clients cannot INSERT/UPDATE/DELETE. The original purchase RPCs remain authoritative.

## Future work / limits

* Changes to Flutter layouts, Android native code, supported animation codecs and
  new game engines still require an APK/AAB build and release.
* Store remote media currently supports HTTPS **still-image previews**, not
  remote VAP/SVGA playback, dynamic equipment or paid Store purchases.
* Server-triggered room animation already uses `gift_animation_media`.
  Verify each asset decodes on Android before enabling paid gifts.
* No media rows or remote setting flags are seeded/enabled by this migration.
* Realtime requires network and authenticated session. If unreachable, user can
  reopen/retry screens to refetch; offline cache and reconnect polling come next.
* Keep profile/wallet/rooms/backups intact. Do not merge until analyzer, unit tests,
  release smoke tests and RLS negative tests pass.

## Verification

- `cd nimzo && flutter pub get && flutter analyze && flutter test test/dynamic_content_sync_test.dart`
- Check `pg_publication_tables` includes `nimzo_content_revisions`.
- Verify anonymous SELECT and authenticated INSERT/UPDATE are denied.
- Under admin transaction with ROLLBACK, update an existing Store row and
  confirm revision increases within transaction then remains unchanged after
  rollback. Never test with live wallet writes.
- Check full-screen Store preview, sign-out/sign-in, and no startup regression.
