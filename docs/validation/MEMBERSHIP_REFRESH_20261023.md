# Membership refresh and diverse gift shortlist — partially delivered

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
Publication migration20261023154035 activated all20 presentations and7 verified gifts. Live totals are34 gifts and73 Store items. All twelve preservation hashes matched before/after publication, including all original gift/media rows. Authenticated-role readback confirms20 cards,10 animated SVIP heroes and34 active gifts; private provenance and presentation writes remain denied. See [publication preservation](membership-refresh-publication-preservation-20261023.json).

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

- Full local Flutter run:563 passed, plus new SVGA rendering/loaded responsive
  focused checks. The complete GitHub source CI run passed564 tests, including
  the added render check and decoded media/no-spinner assertions: https://github.com/adi4ch-cmd/Nimzo/actions/runs/39978492933 .
- Python parser/import/build-policy regression:34 passed locally (32 in the
  first pinned source CI run; two additional cases cover observed native
  terminal-boundary events and reject events beyond that boundary).
- Analyzer:59 existing info findings; no errors or warnings.
- Disposable membership suite:restored rules, presentation RLS, checked-price
  replay and nested animation/card validation all passed.
- Disposable combined publication:20 presentations and7 gifts inserted;
  profiles/wallets/ownership/equipped/old catalog/reward rules unchanged;
  collision rollback passed;7 sends plus replays charged exactly5000000 once.
  Synthetic SQL fixture evidence never becomes device proof or production SQL.
- Host rendering checked every membership SVGA frame and every cheering-crowd
  frame. Six selected videos fully decoded in host inspection. These host checks
  are separate from the successful native checks below.

## Native publication gate

The isolated Android harness verified134 originals:existing57, membership70,
shortlist7. Static images and SVGAs retain real every-frame raster checks.
VAP checks require native completion, at least90% unique frame events, first/last
indices and changing visible GPU pixel samples. VAP samples are not described
as every-frame pixel proof. All134 PNG previews were collected, artifact SHA256 checked and visually
inspected: https://github.com/adi4ch-cmd/Nimzo/actions/runs/39978492899 .
There are49 SVGAs,79 static originals and6 VAP videos. The Android SDK emits
one terminal boundary event at frameCount; the proof retains these raw event
counts without describing them as extra decoded video frames.

Production SQL generation requires actual successful GitHub native job metadata,
exact source commit, timestamps, complete raw log records and pinned manifests.
The actual successful job/source/log and all four pinned manifests passed this
verification. All84 new immutable objects passed public HTTPS/MIME/SHA/size
readback; the importer was immediately sealed as version11 (HTTP410).
The bundled manifest keeps its original staging provenance to preserve exact
native-source identity; current activation is held in the approved backend rows.
This does not complete the original master task or twenty-gift request.
A1.0.41 TEST APK is being prepared under the existing owner authorization;
Vivox and authenticated physical-device checkout remain unverified.
