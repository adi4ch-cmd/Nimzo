# Issue 15 UI implementation and device-test review

Continued from `610dbcf4e6de8258fce652262baeddc4a0dfddfd` on
`feature/tingle-ui-rebuild-20261017`. This report describes implemented UI and
headless evidence, not owner acceptance or a pixel-perfect certificate.

## Implemented in this continuation

- Original NIMZO vector artwork for premium crests, avatar frames, cards, chat
  bubbles, gifts, entrance vehicles, room frames/themes and all privilege
  illustrations. Seven frame styles include distinct heart, floral, leaf and
  star geometry. Six VIP/SVIP palettes remain selectable.
- All twenty membership preview pages retain swipe, previous, next and close.
  Fixed stretched popup artwork and low-contrast membership title. Normal VIP
  labels/descriptions no longer incorrectly say SVIP. Palette transitions respect
  reduced-motion settings. Membership hero and tile heights also grow with
  accessibility text size; 1.8× layout is verified at 320/390/480dp.
- Store has an original two-column design gallery plus five distinct category
  galleries. Selection changes crossfade; entrance previews have bounded replay
  and reduced-motion support. Every local design is marked preview-only. Existing
  verified medal catalog, purchase, equip and Bag logic are unchanged.
- CP Space now includes an original decorative reward gallery with four
  inspectable dialogs and explicit unavailable rewards. Unlinked profile CP
  panels say **Not linked**, rather than implying a recorded zero-day duration.
- Family has an original palace/curtain backdrop, crest and empty mascot. Its
  directory/creation remain transparently unavailable. No family records or
  entitlement actions were fabricated.
- Original profile shortcuts, SVIP banner crest, inbox/Moments/Friends mascots,
  five navigation marks and microphone chairs replace presentation stand-ins.
- Moments composer retains the existing working header Post/Save action, photo
  chooser, draft, Mention and topic actions. Removed the duplicate oversized
  bottom publish button to follow the reference's compact composition.
- Room title and bottom toolbar use the selected room palette for contrast.
  All existing room handlers, ten seats in 5×2, microphone/session, gifts,
  permissions and confirmed-exit behavior remain intact.

## Evidence and reproduction

- [Annotated comparison matrix](comparison-matrix.md) links targeted video
  timestamps to actual NIMZO captures and states the remaining differences.
- [HTML review gallery](index.html) includes all captured states at 320/360/390dp.
  Open the downloaded repository locally to browse this HTML; GitHub's file view
  displays its source. PNG originals remain outside git; committed WebP copies
  preserve aspect ratio. Reference images appear only inside documentation
  comparison cards, never production assets.
- [Existing full-video inventory](../video-20261018/screen-inventory.md) retains
  the complete timestamp coverage; [23-image filename map](../tingle-ui-first-reference-map-20261017.md)
  remains the index for the absent original PNG files.
- Video re-download was verified at **1,128,636,234 bytes / 385.626822 seconds**.
  Only targeted gap frames were extracted; the old audit/full extraction was not
  repeated. The Drive connector returned 413; the public download succeeded.
- Captures use explicitly labeled test identities and empty/unavailable data.
  They are not live populated-account screenshots or fabricated production data.
  Secondary fixture screenshots preserve the existing test's 390×844 ratio;
  comparison cards pad to a consistent 360×800 canvas without stretching.

```sh
cd nimzo
flutter analyze --no-pub --no-fatal-infos
flutter test --no-pub --reporter expanded
flutter test --no-pub test/tingle_video_ui_test.dart \
  test/issue15_room_walkthrough_test.dart test/issue15_navigation_test.dart \
  --dart-define=NIMZO_CAPTURE_DIR=/path/outside/repository/captures
# Existing fixture harness: explicit targets select captures; normal full-suite
# defaults and every original golden assertion remain unchanged.
flutter test --no-pub test/remaining_visual_qa_test.dart \
  --dart-define=NIMZO_GOLDEN_TARGET=room_settings,public_profile,room_profile,gifts,comments,wallet \
  --dart-define=NIMZO_REVIEW_WIDTH=360 \
  --dart-define=NIMZO_CAPTURE_DIR=/path/outside/repository/captures
cd ..
python3 tools/ui/build_issue15_evidence.py /path/to/captures \
  /path/to/targeted-video-frames docs/ui/issue-15-review
```

## Interaction coverage

| Surface | Exercised behavior | Evidence / limitation |
|---|---|---|
| Login | Exactly Email/Facebook/Google; terms open/back; narrow wrapping | Existing login tests and all three walkthrough widths |
| Home | Country search/dismiss; Explore/New/Follow selection | Walkthrough; PK retains existing local route |
| Party | Directory and Follow tab; empty state | Existing room reads; no generated people/banners |
| Moments | Empty feed; composer; topics; Mention; photo chooser/remove; failed-load retry; save/draft preservation | Walkthrough plus existing editor tests; native media UI remains device-only |
| Messages | Search/filter/clear; All/Unread; conversation capture | No Online tab without presence data |
| My/public profiles | Hub routes; fixed edit Save; level links; gifts/collections; CP invitation handling | Existing profile tests and captures; profile cover geometry intentionally retained |
| Friends | Search including numeric ID; tab/empty presentation | Existing Friends tests; no fake presence |
| Ranking | Daily/Weekly/Monthly and category transitions | Unsupported daily/Gift/Active modes remain explicit unavailable states |
| Levels/tasks/check-in | Level bands/tabs; task routes; unknown progress; attendance error | Existing tests; real claim/reward behavior preserved, not simulated |
| VIP/SVIP | All six tiers; twenty popup pages; next/previous/swipe/close | Walkthrough at all widths; original 2D art approximates reference 3D art |
| Store | Five category routes; seven selection styles; entrance replay/reduced motion; Bag/verified catalog | Preview controls never buy, equip or grant anything |
| CP/Family | Four reward previews/dismiss; unavailable Family creation | Original art with no invented membership/rewards |
| Room | Ten seats 5×2; open-seat sheet/cancel; reactions update draft; tools; Music; gift recipient/tray; exit/cancel | Room walkthrough at all widths; permission/session tests retained |
| Room profile/settings | Existing settings, room data, mini-profile captures | Native photos, populated guests and moderation server outcomes not certified |
| Navigation | Five branches; selected routing; preserved scroll position | New navigation test at all widths; Games routes/logic untouched |
| Wallet/recharge/settings | Existing presentation captures | Source/logic frozen; fixture captures are not live payment confirmation |

## Scope verification

No changed files under either `supabase/` tree, `features/games/`,
`features/wallet/`, or `features/voice/`. No repository/data model, auth controller,
OAuth contract, dependencies, package identity, schema, migration, wallet or
Vivox changes. Login remains exactly Email/Facebook/Google. Existing PR #14 is
not merged. The new APK is a debug device-test build, not a production release.

Independent code review found no functional/scope regressions; a follow-up
caught the normal VIP popup description and that copy was corrected. Visual
inspection additionally found the stretched popup and room contrast defects;
regression assertions were added and verified.

## Honest remaining limits

1. No ADB device/emulator or `/dev/kvm` is available. Physical Android keyboard,
   system bars, accessibility text scale, emoji fonts, media picker, native audio,
   OAuth round-trips and device motion remain unverified. Headless evidence does
   not certify these.
2. The original 23 PNG files are absent from this workspace; Drive search for
   their supplied filename returned no result. Their filename map and matching
   video states were used, not marked as inspected originals.
3. Multi-image Moments requires changing the one-image model; Online-only inbox
   requires presence data. Both remain outside this UI-only frozen backend task.
4. Populated Party/Family/VIP/purchase/reward states require real account data.
   Family creation, unsupported catalogs and reward grants remain unavailable.
5. Original vector art, profile cover arrangement and some spacing/motion differ
   from Tingle's proprietary 3D assets. No exact parity or owner acceptance is
   claimed. A frame/style preview is not an equipped room entrance effect.
6. The three existing golden suites remain visible. Narrow secondary captures
   also intentionally mismatch their fixed 390×844 golden image sizes; those
   focused capture failures are documented separately from the normal full run.
   Explicit 390dp capture targets also expose old conversation, settings, recharge
   and notifications baselines with 93–94% pixel differences. Their main UI source
   is unchanged in this pass (the conversation class shares the inbox file).
   These are additional mismatches within `remaining_visual_qa_test.dart`, normally
   not reached because that suite stops at its Catalog mismatch. They were not
   regenerated, hidden or asserted to be exact matches.

## Final command results

Implementation commit: `a2f2580` (the subsequent evidence commit is the APK build
head). Flutter **3.47.6**, Dart **3.13.5**, Linux headless renderer.

| Command | Observed result |
|---|---|
| `flutter analyze --no-pub --no-fatal-infos` | **Exit 0**, no errors/warnings; 37 informational lints |
| `flutter test --no-pub --concurrency=3 --reporter expanded` | **340 passed, 3 failed**; full suite is not green |
| Room walkthrough + reconnect focus | **5 passed**, including the room contrast assertions |
| 1.8× premium layout at 320/390/480dp | **3 passed**, after reproducing and fixing overflows |
| `git diff --check`; evidence script Python compilation | Passed |

Preserved failures: `master_visual_preview_test.dart` (Treasure),
`reference_preview_test.dart` (old Home/game boards), and
`remaining_visual_qa_test.dart` (old Catalog). No goldens were regenerated and no
assertions were disabled. Additional explicitly targeted legacy states are
listed in the limitations above. [Full test log](logs/flutter-test.log),
[analyzer log](logs/flutter-analyze.log), [room focus](logs/room-focused.log), and
[large-text regression checks](logs/premium-large-text.log) are committed.

The comparison set contains **326 captures and 34 annotated pairs**. Its normal
UI geometry is captured at 320/360/390dp; the 480dp accessibility check is a
separate layout test. [Capture manifest](capture-manifest.json) records rendered
PNG dimensions and hashes; the PNGs themselves remain outside git, with the WebP
review copies committed here.

The APK is built only after this UI/test review through the existing active
`nimzo-ui-test-apk.yml` workflow. The final owner response records its exact run,
latest branch SHA, artifact link, binary/checksum verification and compatibility
information. No merge, production release or backend step is authorized by this
report.
