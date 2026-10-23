# Membership refresh and diverse gift shortlist — staged

Owner direction: YoHo VIP, a different source for SVIP, twenty additional gifts
at500K/1M, and at most two gifts per visual type. Preserve previous code, assets,
catalogs, balances and ownership. Vivox remains owner-deferred.

## Implemented source and backend support

All ten VIP tiers use original YoHo heroes/badges with original Mizah backgrounds.
All ten SVIP tiers use original Falla animated crests, badges and podium cards.
Seventy checksum-pinned membership originals are bundled; original Voku files
remain preserved. SVGA heroes actually loop, pause in background and resume.
Finite entrance playback retains its completion behavior. Cards and badges are
static and accurately labeled. No new prices, thresholds or reward grants.

The presentation schema adds a readable optional card plus bounded nested SVGA
hero animation. The top-level hero remains a real static fallback for older
released clients. Live migration20261023152602 applied successfully. Hashes of
eleven existing financial/profile/ownership/catalog tables were unchanged:
[preservation evidence](membership-refresh-schema-preservation-20261023.json).
No membership presentation or new gift has been activated yet.

## Gift shortfall:7 selected,13 still missing

The previous uncommitted twenty-effect selection contained ten similar cars
and ten similar armored figures. It was rejected and moved out of the app.
The replacement manifest explicitly records requested20, selected7, remaining13:

| Source | Gift | Price | Type |
| --- | --- | ---: | --- |
| Voku | Midnight Muscle Car |500000|car|
| Voku | Violet Fireworks Car |500000|car|
| Voku | Solar Seraph |1000000|armored fantasy|
| Voku | Golden Night Rider |1000000|armored fantasy|
| MiLoop | Golden Cloud Dragon |1000000|dragon|
| MiLoop | Forever Love |500000|romance|
| Ahlan | Cheering Crowd |500000|crowd|

MiLoop originals came from literal static CDN URLs found inside the supplied
checksum-pinned APK. The importer verifies the exact source entry contains each
URL and verifies downloaded original bytes. Six effects are self-contained VAP
videos; one is a complete SVGA. Derived PNGs are thumbnails only.

Audit covered the existing1386SVGA/115MP4 inventory,52ZIP-animation atlases,
bundled legacy media and96 downloadable literal static animation URLs found
in supplied APKs. Other candidates repeated current catalog motifs, contained
VIP labels/dynamic placeholders, were UI effects, or exceeded existing decoder
limits. Limits were preserved. No claim that every possible remote catalog was
exhausted. Missing thirteen suitable diverse effects is a genuine source gap.

## Actual verification so far

- Full Flutter run:563 passed. New SVGA rendering and loaded responsive screen
  checks:6 additional focused checks passed; four screen checks were then
  strengthened to require decoded media/no loading spinner and passed again.
- Python parser/import/build-policy regression:32 passed.
- Analyzer:59 existing info findings; no errors or warnings.
- Disposable membership suite:restored rules, presentation RLS, checked-price
  replay and nested animation/card validation all passed.
- Disposable combined publication:20 presentations and7 gifts inserted;
  profiles/wallets/ownership/equipped/old catalog/reward rules unchanged;
  collision rollback passed;7 sends plus replays charged exactly5000000 once.
  Synthetic SQL fixture evidence never becomes device proof or production SQL.
- Host rendering checked every membership SVGA frame and every cheering-crowd
  frame. Six selected videos fully decoded in host inspection. These checks
  do not establish native Android playback acceptance.

## Native publication gate

The isolated Android harness now verifies134 originals:existing57, membership70,
shortlist7. Static images and SVGAs retain real every-frame raster checks.
VAP checks require native completion, at least90% unique frame events, first/last
indices and changing visible GPU pixel samples. VAP samples are not described
as every-frame pixel proof. All134 PNG previews must be collected.

Production SQL generation requires actual successful GitHub native job metadata,
exact source commit, timestamps, complete raw log records and pinned manifests.
New media remains staged until that verification and immutable Storage readback
pass. This checkpoint authorizes the isolated native audit under the existing
owner-authorized dynamic QA scope; it does not complete the original master task
or twenty-gift request. No new NIMZO APK has been built or published in this refresh.
