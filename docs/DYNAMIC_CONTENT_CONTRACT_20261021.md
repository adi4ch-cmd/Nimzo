# NIMZO Dynamic Content Contract — 2026-10-21

**Branch:** `feature/dynamic-content-sync-20261021`  
**Baseline:** `feature/retire-unused-store-gifts-20261021` (keep Codex cleanup intact).  
**Release policy:** No APK/AAB until source QA, device startup, authenticated live round-trip, voice coexistence, real media checks and purchase tests pass.

## Architecture

The Flutter app is installed once with supported decoders and presentation widgets. Supabase contains **data and approved file references**, not remotely executed Dart/Android code.

| Channel | Server data | Live behavior |
|---|---|---|
| Gifts | `gifts`, `gift_animation_media` | Refresh active catalog; server-settled verified room gifts may play approved MP4/VAP/SVGA |
| Store | `nimzo_cosmetic_catalog`, `nimzo_cosmetic_media`, existing ownership/equipment | Refresh catalog and equipped surfaces; remotely approved images/SVGA/VAP supported |
| Banners | `banners` and Storage bucket `banners` | Switch to active, time-bounded server campaigns; old supplied artwork remains when no live row |
| Games | `game_catalog` | Enable/disable **known** game entries; no new executable game engine or simulated payout |
| Settings / Rooms | `nimzo_remote_settings` (`room.backgrounds` key) | Approved HTTPS background for known NIMZO theme names; no remote changes to room permissions or voice |
| Memberships | **Retired legacy VIP/SVIP** | **Not restored.** New independent implementation remains separate Codex scope |

`nimzo_content_revisions` is a read-only RLS-protected Realtime channel.
Statement triggers bump `revision` after committed catalog mutations.
Flutter invalidates the affected Riverpod provider. A three-minute
resubscription can recover missed Realtime events. No APK is built when
content changes. The client can continue using bundled static presentation
assets when server content is unavailable.

## Privileged publishing (ChatGPT or an owner-authorized operator)

There is **no Admin Panel or Telegram bot** required. Only trusted server-side
SQL/storage operations may publish data. Ordinary signed-in accounts have
SELECT-only access to new tables. All management actions should be logged.

1. Obtain the rights-cleared media file and its expected SHA-256, codec,
   aspect ratio, duration, audio, transparency and ownership approval.
2. Upload it to a suitable secure/public Supabase Storage/CDN location using
   **immutable, content-hashed filenames** (never overwrite a URL in place).
   Existing public Storage buckets are not copy-proof; private gift media
   needs the existing authorized signed-URL Edge Function when applicable.
3. Validate actual bytes, size, HTTPS transport, thumbnail, VAP `vapc`
   support, SVGA decode and Android playback. **Do not treat a filename or
   PNG mockup as proof of a playable gift.**
4. Stage the database record as inactive/unapproved. Review source,
   category and allowed media kind. Never use client-supplied amounts to
   alter wallets or award membership.
5. Publish in a transaction: approve playback record, then activate a new
   gift with `requires_approved_media=true`; or approve Store media for an
   existing catalog item. Triggers bump the proper revision automatically.
6. Confirm signed-in devices load/refresh **and actually play/equip** the
   approved item. If broken, set `approved=false` to roll back immediately.
   Newly opted-in animated gifts cannot settle a room gift transaction when
   approved media is missing; Postgres rolls back debits if that guard fires.
7. Record changes and repeat verification on Android and iOS for native
   plugins. Keep existing user/room/wallet/transaction records intact.

### Supported Store media record

`nimzo_cosmetic_media(item_id, thumbnail_url, asset_url, media_kind, approved)`

* `thumbnail_url`: HTTPS preview image (mandatory)
* `asset_url`: HTTPS full media for actual effects/equipment (optional while staged)
* `media_kind`: `image`, `svga`, `vap`
* `approved`: false until verified; no writable client policies
* Only categories supported by shipped Flutter surfaces can be equipped.
* Paid Store checkout is **not** implemented by this content-sync work. Do
  not charge for an item without an audited server-side purchase transaction.

### Supported Gift media record

`gift_animation_media(gift_id, video_url, media_kind, duration_ms, sound_enabled, approved)`

* `media_kind`: `mp4`, `svga`, `vap`
* A verified **server-created** gift animation event, not a client event,
  triggers playback. Replays and queueing are bounded.
* `requires_approved_media` is opt-in on `gifts`; default false leaves
  existing original gifts untouched.
* Media loading **never issues the sending RPC**, creates a gift event, or
  adjusts a wallet. Gift payment remains Postgres-controlled.

### Room background example

Use an authorized server transaction to set
`nimzo_remote_settings.key='room.backgrounds'`, `active=true`, and JSON:

```json
{
  "themes": {
    "nimzo_white": "https://cdn.example.com/rooms/sha256-name.jpg",
    "sage": "https://cdn.example.com/rooms/sha256-name-2.jpg"
  }
}
```

Only shipped theme IDs are accepted by the client. No permission, microphone,
user balance, gift price or game-outcome configuration is interpreted here.

## Verification and release gates

* GitHub **no-APK** workflow `.github/workflows/nimzo-dynamic-content-qa.yml`.
* Run Flutter analyzer and targeted Gift/Store/Room/Event unit tests.
* Supabase migration history, Realtime publication, RLS and grants verified.
* Transactional `ROLLBACK` probes confirm revision triggers and paid-gift
  activation guards without touching real accounts or coin balances.
* Before release: test one real PNG, SVGA, VAP and opaque MP4 (where relevant)
  uploaded to approved storage; verify full previews, equipment across avatar,
  room and chat surfaces, send/receive gift playback, media missing rollback,
  Auth sign-out/in, token refresh, offline/reconnect, low-memory devices and
  Android/iOS sound coexistence.
* **Never publish a final APK just because source CI is green.** APK/native
  tests must be the final step after full feature verification.

## Known limits

* New Flutter layouts, native codecs, mic SDKs, permissions, executable game
  engines and first-time support for this updater require an APK/AAB once.
* Media metadata starts empty; this branch adds the secure ability to publish
  it, **not** invented online assets.
* Existing paid Store purchases and replacement VIP/SVIP packages remain
  separate features. A coin price in a catalog is not proof checkout works.
* A CDN URL alone cannot prevent a determined user from copying bytes. Use
  private storage/signed URLs for truly access-controlled media, and recognize
  that any rendered media can still be screen-recorded.
