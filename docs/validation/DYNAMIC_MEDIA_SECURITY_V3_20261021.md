# Dynamic media security review — 2026-10-21

Scope: approved byte loading, revision snapshots, dynamic banners/background URLs,
publication SQL; no APK/AAB/IPA build and no live write/migration.

## Reproduced design defects and fixes

- The old loader cached solely by URL and returned its mutable Uint8List. A caller
  could change cached bytes; an updated object at the same URL retained old bytes.
  Verified fetches now key URL + digest + size + MIME + codec + limit, require the
  hash in the immutable URL path, copy cached returns, and never cache legacy
  downloads without publication metadata.
- HTTPS alone previously admitted nonstandard ports/fragments and did not verify
  media identity. Verified fetches compare exact length, SHA256, response MIME,
  codec-specific signature and strict supported VAP config. Redirects, empty,
  oversized and chunked overflow responses fail closed. The entire operation has
  a 30-second deadline; a slow trickle cannot extend the per-chunk deadline forever.
- Old-session in-flight media could populate the next session's process cache.
  clearCache increments a generation and rejects completions from older sessions;
  the root application must invoke it on account transitions.
- Comparing only immediately previous revisions permits 10→2→9 to treat 9 as new.
  ContentRevisionTracker holds high-water marks and resets with the session provider.
  Root application routes only changed channels. Settings have a three-minute
  fallback refresh; existing resume/stream polling continues.
- Malformed banner start/end dates previously became unbounded dates; malformed
  field types could throw. Invalid records now disappear safely. Percent-encoded
  traversal, query and fragment Storage paths are rejected.
- Existing gift approval was opt-in: new paid gifts could leave
  requires_approved_media=false. SQL forces that flag for new paid gift inserts
  only; old gift records are preserved. Financial settlement checks publication
  evidence under row locks; Store ledger validation checks active server price
  and publication within the existing atomic transaction.

## Evidence

Live read-only schema inspection confirmed existing media tables have no digest,
length, MIME, rights or device-verification fields. No live mutation was used.
Supabase changelog and connected documentation were consulted.

The generated/reordered proposal migration is
`supabase/migrations/20261021120000_dynamic_verified_media_publications.sql`.
Its prerequisite migrations are the existing dynamic revision/media/paid guards.
It must be staged and reviewed before application. Existing approved rows remain
readable, but further approval needs verified metadata; paid Store charges fail
closed until publication evidence exists. No balances, ledger history, ownership
or old gift data are rewritten.

`tools/tests/dynamic_media_publication_test.sql` passed on a fresh disposable
`nimzo_dynamic_v3_test` database in local container `nimzo-postgres-test`.
Assertions cover old row preservation, staged unverified approval rejection,
MIME/size/hash-path/device evidence, forced new gift flag, wallet rollback after
media guard failure, Store price/deactivation, and gift media deapproval.

The root agent serializes Flutter runs. Relevant test files:
`approved_media_bytes_test.dart`, `dynamic_content_sync_test.dart`,
`dynamic_media_contract_test.dart`. HTTP tests cover digest/MIME/magic/length,
chunk overflow, redirects, immutable publication cache changes, mutable return
isolation, account cache clear and unsupported VAP configuration. Obtain final
Flutter result from the root verification log; this review does not claim it.

A direct Dart structural probe using the production byte validator passed all
six shipped `vap_rocket_fly_*.mp4` files. Reward videos contain `isVapx=1` plus
external image resource `img0`; new remote publication rejects this unsupported
resource-dependent variant. Bundled legacy playback is preserved.

## Remaining device/integration gates

Hash/signature/container checks establish byte identity and structural preflight,
not successful decode. SVGA protobuf/decompression, image decode memory limits,
VAP H264/alpha/audio compatibility and playback must still be verified using the
shipped decoder on Android. Device verification timestamps are trusted owner
attestations, not something SQL can independently establish.

Separate thumbnail hash/size/MIME columns are optional for legacy rows. New
clients must authenticate thumbnails using their own descriptor rather than the
primary animation hash. Primary publication evidence cannot authorize a different
thumbnail object.

A database cannot establish current CDN object reachability. Gift/Store purchase
boundaries must verify current approved metadata and bytes before asking for a
charge; server transaction guards independently enforce authorization/price and
publication state. Lost-response retries must recover existing server receipts
before requiring fresh online media. No installed-device offline/reconnect,
account switching, purchase/deactivation or native-playback claim is made here.
