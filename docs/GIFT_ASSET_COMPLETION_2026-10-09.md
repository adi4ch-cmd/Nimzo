# Gift asset completion checkpoint

## Supplied originals remain inaccessible

The owner confirmed the binaries were uploaded to an earlier ChatGPT conversation,
not GitHub. This session has no attachment IDs or download URLs for them.
Do not replace them or claim they are bundled. These exact files are missing:

- `1000116618.mp4`
- `1000116619.mp4`
- `NIMZO_Golden_Dragon_All_3_Videos.zip`
- `Entry Effect.svga`
- `Gift Tray.svga`
- `Chat Bubble.svga`
- `Mic Halo.svga`
- `Label.svga`
- `Frame.svga`
- `Profile Card.svga`

The prepared ZIP's intended entries were:

- `nimzo/assets/gifts/golden_dragon_5m.mp4`
- `nimzo/assets/gifts/ai_dragon_video_1.mp4`
- `nimzo/assets/gifts/ai_dragon_video_2.mp4`

These are three aliases of two distinct originals, not three independent videos.
The correspondence between the numeric originals and aliases is unverified.
No absent path has been added to `pubspec.yaml`, and no fictional media URL or
SVGA entitlement has been seeded.

Search covered the checkout, all eight remote branches and reachable file history,
both historical project ZIPs, repository releases and issue/comment attachments,
`/workspace/library-files`, shared downloads and live Supabase Storage. The two
ZIPs contain 147 and 144 entries and no video/SVGA binaries. The historical
`dragon.svg` is static art and is not an original video. Live Storage has eight
uploaded photos and no videos/SVGA files. The approved media table has zero rows.
Existing reference VIP/SVIP emblems and Phoenix code remain intact; they are not
substitutes for the seven missing originals.

## Verified catalog and settlement

Read live on 2026-10-09:

| Gift | Catalog ID | Unit coins | Media status |
|---|---|---:|---|
| Dragon | `e1e65664-37f8-4cfd-9640-3bb035723b98` | 1,000,000 | Original missing; not integrated |
| Golden Dragon | `c3f41e6e-68d5-4e56-9253-33421ec18fc3` | 5,000,000 | Original missing; not integrated |

Both are active with no minimum VIP/SVIP restriction. Their `asset_path` values
are null. No catalog records or prices were changed.

The disposable PostgreSQL clone reproduces the real deployed schema/functions;
the private diamond-cycle tables are also restored so gift triggers run. Synthetic
accounts and balances exist only in the clone. Tests assert full quantity-based
debits, 45% recipient diamonds, 5% eligible owner coins, self-gifts with zero
diamonds, single settlement on retry, changed-payload rejection, nonmember denial,
zero quantity rejection and insufficient-balance rollback. The established
self-gift exclusion from diamond/Charm awards is preserved.

`supabase/tests/dragon_gift_settlement.sql` reproduced missing animation events
for rooms without country metadata. Migration
`20261009061848_verified_room_gift_event_routing.sql` is **deployed and read-verified**.
Room-scoped effects now work without country metadata; 35M/50M country effects
still require a country. Events snapshot the price actually settled and remain
unique per gift event. Client EXECUTE on the trigger remains revoked, with an empty
search path. Profile/Moment gifts have no room overlay destination and do not
generate room effects. No historic event backfill or production fixture gift was
performed. Security-advisor counts are unchanged from before this fix.

## Playback fixes

- Only server-inserted, RLS-scoped animation events request approved media.
- Approved URLs are looked up by exact gift UUID; missing, insecure or unbundled
  sources do not become invented videos.
- Media lookup has an eight-second deadline and cancellable queue timers.
- Backgrounding drops active/queued effects and ignores late lookup responses.
- Deduplication and backlog memory are bounded; initial history is not replayed.
- Both Dragon names, quantities and total settled cost display correctly.
- Room gift videos start muted, offer a sound toggle and request audio mixing.
- Aspect ratio is retained; original videos can play beyond the former fixed
  30-second cutoff. A duration-based watchdog is capped at two minutes, with
  a separate 15-second initialization watchdog, error handling and single dismissal.

Native player callbacks are simulated in Flutter tests; this is not evidence that
the missing original codecs, sound or transparent compositing work on Android.
Only a Linux desktop target is connected, so two-real-Android-device gifting and
Vivox/audio coexistence are **not tested**.

## Next asset integration

When the originals become accessible, verify MP4 container/codec/dimensions/audio,
SHA-256 and the alias mapping; verify SVGA decoding and original art. Register only
present local assets or genuinely uploaded HTTPS media, bind each approved gift
UUID, and verify actual settlement-to-playback on two devices. VIP/SVIP assets must
follow server-verified entitlements; do not infer paid privileges from a local
preview selection. Neither gift's original video nor any supplied SVGA asset is
marked complete by this checkpoint.

## Verification and APK delivery

Local dependency resolution, formatting and strict static analysis pass. All
261 Flutter tests pass, including 13 new media/playback/queue regressions. Node
authorization/payment fixtures pass 16 tests, native voice/updater contracts pass
8, build tools pass 4, and reference integrity passes 1. The new Dragon settlement
suite and the seven existing targeted backend assertion groups pass in the
disposable schema clone. An independent read-only code review found no blocking
defects. The first full local run exposed six incomplete HTTP test fixtures;
after adding their request metadata, the complete rerun passes.

Source version is `1.0.13+113`. The existing GitHub Actions workflow builds and
verifies the installable release-mode test APK after push. Permanent signing
secrets remain unavailable, so this delivery uses development signing. Build
success and the actual artifact URL are reported separately after verification;
this document does not claim the supplied animations are in that APK.
