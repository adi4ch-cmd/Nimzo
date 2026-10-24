# VIP/SVIP live equipment report — 2026-10-23

> Source choices and completeness wording were updated on2026-10-24 after owner feedback. See [the latest Falla/Hafla audit](MEMBERSHIP_SOURCE_CHOICE_20261024.md). The older source lists and host previews below describe the1.0.42 delivery.

PR #44 continues the existing integration branch; existing purchases, membership state, accounts, Store ownership, rooms, gifts and wallets are preserved. **The full20-pack Android acceptance is NOT complete. After the owner explicitly requested “Apk do”,1.0.42 was built and published as a TEST prerelease; this is not the completed20-pack release.**

[Download1.0.42 membership TEST APK](https://github.com/adi4ch-cmd/Nimzo/releases/download/nimzo-v3-dynamic-1.0.42-40028859212/NIMZO_1.0.42_Universal_NO_VIVOX_TEST.apk). [Build and published-binary evidence](validation/membership-pack-test-apk-1.0.42.json). Android15 emulator install/startup passed; authenticated membership/profile/room playback remains unverified.

## What is implemented

- Persistent, atomic `nimzo_membership_apply_full_set` / `nimzo_membership_remove_full_set` selection. The server checks the exact active kind, level and expiration; the client cannot write membership/equipment state directly.
- Explicit eligible selection determines one primary identity; otherwise active SVIP takes precedence. Membership ownership alone does not auto-apply a pack.
- Actual profile and room avatars use the matching original frame and medal. Profile cards, decorative SVIP strips, ID nameplates, original room-message bubbles and speaking mic waves use selected slots. Unsupported originals remain absent.
- Confirmed room occupants drive observer-visible entrance queues. Historical members and rebuilds do not replay entrances. Playback rechecks entitlement after asynchronous catalog lookup, listens for removal, respects expiry, and clears on background/account/room changes. Approved matching remote entrances remain supported before bundled originals.
- Existing Store choices are retained under an applied set. Later individual equip overrides its slot atomically; Remove restores prior Store choices. Realtime changes invalidate membership and Store visual caches.
- An explicit owner-only action selects the genuine VIP6 room wallpaper. It overrides the room surface only while eligible. Selecting a later individual Store Party Theme clears the membership wallpaper choice.
- Every selected tier shows its ten package components **inline below the artwork**, with Applied / Available / Locked / Missing original status and original preview. The membership title and dark/gold cards are readable. Mobile280/360dp layouts tested.

## Media evidence

21 locally available authorized archives were scanned again, including102040 nested entries. Prior extraction inventories were checked first.105 selected original slot records have exact source kind/tier, package/source paths and SHA-256 checksums.39 previously unbundled original files were added, reusing all duplicate bytes already in the repository. Original bytes remain unchanged; transparent source-canvas crop metadata positions the frame correctly over the avatar.

Previous-branch audit additionally covered69 remote refs,51 source inventory/catalog blobs and six embedded archives. No additional source-verified gap fillers were found. See `membership-previous-branches-audit-20261023.md`. Generic Store assets, static entry badges, screenshots and unlabeled media were not relabeled as missing membership originals.

Sources: WillChill VIP1–5 frames/bubbles; YoHo VIP6–10 frames and VIP1–10 medals/nameplates; Voku original empty SVIP1–10 frames; Hafla VIP1–6 entrances and SVIP medals/nameplates; Orii VIP1–6 cards/mic waves, SVIP1–6 entrances/decorative strips and SVIP3–6 mic waves; Falla SVIP7–10 mic waves; BGChat VIP6 bubble; Tana VIP6 room wallpaper. Existing YoHo/Falla hero/badge presentations are retained.

All105 original records were decoded/rendered in Flutter host tests;32 SVGA animations were checked on every frame for visible, changing pixels. This establishes **host rendering**, not Android playback or a real voice-room end-to-end test. Static images are reported as originals, not animations. Perk portraits, static entrance icons, Hilo throne graphics and membership-page backgrounds were rejected as substitutes for other roles.

Provenance: `nimzo/assets/membership/packs/provenance.json`. Reproducible render manifest: `verification_manifest.json` in the same directory. Exact source-audit notes follow in `membership-source-audit-20261023.md`.

## Per-tier acceptance matrix

**Working*** = original bundled and rendered on the Flutter host. It does not mean Android verified. **Apply Working†** = SQL/Flutter control checks; no real Android observer-session acceptance. All20 saved selections were also read through independent database connections as owner and observer.

| Tier | Frame | Entrance | Profile card | Medal | Nameplate | Chat bubble | Mic animation | Room background | Apply Full Set | Android test | Fully functional |
|---|---|---|---|---|---|---|---|---|---|---|---|
| VIP 1 | Working* | Working* | Working* | Working* | Working* | Working* | Working* | Missing | Working† | Not tested | Not verified |
| VIP 2 | Working* | Working* | Working* | Working* | Working* | Working* | Working* | Missing | Working† | Not tested | Not verified |
| VIP 3 | Working* | Working* | Working* | Working* | Working* | Working* | Working* | Missing | Working† | Not tested | Not verified |
| VIP 4 | Working* | Working* | Working* | Working* | Working* | Working* | Working* | Missing | Working† | Not tested | Not verified |
| VIP 5 | Working* | Working* | Working* | Working* | Working* | Working* | Working* | Missing | Working† | Not tested | Not verified |
| VIP 6 | Working* | Working* | Working* | Working* | Working* | Working* | Working* | Working* | Working† | Not tested | Not verified |
| VIP 7 | Working* | Missing | Missing | Working* | Working* | Missing | Missing | Missing | Working† | Not tested | Not verified |
| VIP 8 | Working* | Missing | Missing | Working* | Working* | Missing | Missing | Missing | Working† | Not tested | Not verified |
| VIP 9 | Working* | Missing | Missing | Working* | Working* | Missing | Missing | Missing | Working† | Not tested | Not verified |
| VIP 10 | Working* | Missing | Missing | Working* | Working* | Missing | Missing | Missing | Working† | Not tested | Not verified |
| SVIP 1 | Working* | Working* | Missing | Working* | Working* | Missing | Missing | Missing | Working† | Not tested | Not verified |
| SVIP 2 | Working* | Working* | Missing | Working* | Working* | Missing | Missing | Missing | Working† | Not tested | Not verified |
| SVIP 3 | Working* | Working* | Missing | Working* | Working* | Missing | Working* | Missing | Working† | Not tested | Not verified |
| SVIP 4 | Working* | Working* | Missing | Working* | Working* | Missing | Working* | Missing | Working† | Not tested | Not verified |
| SVIP 5 | Working* | Working* | Missing | Working* | Working* | Missing | Working* | Missing | Working† | Not tested | Not verified |
| SVIP 6 | Working* | Working* | Missing | Working* | Working* | Missing | Working* | Missing | Working† | Not tested | Not verified |
| SVIP 7 | Working* | Missing | Missing | Working* | Working* | Missing | Working* | Missing | Working† | Not tested | Not verified |
| SVIP 8 | Working* | Missing | Missing | Working* | Working* | Missing | Working* | Missing | Working† | Not tested | Not verified |
| SVIP 9 | Working* | Missing | Missing | Working* | Working* | Missing | Working* | Missing | Working† | Not tested | Not verified |
| SVIP 10 | Working* | Missing | Missing | Working* | Working* | Missing | Working* | Missing | Working† | Not tested | Not verified |

Additional profile decoration: genuine animated ornamental strips exist and render for SVIP1–6. These do not count as full profile-card backgrounds. All20 retain their original membership badge presentation. A native room identity/header is separate from original media and is never counted as a recovered original.

## Exact remaining original-media gaps

- Entrance animations: VIP7–10 and SVIP7–10.
- Full profile-card backgrounds: VIP7–10 and SVIP1–10.
- Chat bubbles: VIP7–10 and SVIP1–10.
- Mic animations: VIP7–10 and SVIP1–2.
- Original room backgrounds: all tiers except VIP6.
- Additional original profile decoration: no verified separate decoration for VIP1–10 or SVIP7–10.
- The Lama source archive was previously blocked by the Drive connector file-size limit (286206190 bytes exceeds268435456). It is not included among the21 locally audited archives. Opaque/remote artwork without verified kind/tier/role was not relabeled to hide gaps.

## Backend live activation and preservation

Live migration: `20261023211259_membership_full_pack_equipment`. New appearance/apply/remove and room-background RPCs are installed. Both new tables have RLS and authenticated SELECT only; INSERT/UPDATE/DELETE remain server-only. Both tables are in the Realtime publication. No membership was granted or automatically equipped.

The before/after hashes of12 existing data sets match exactly, including all profiles, wallets, ledger, rooms, gifts, purchases, membership catalogs/presentations and Store catalog/ownership/equipment. See `membership-equipment-live-preservation-20261023.json`. A live authenticated-SQL-role apply/read-as-second-account/remove check passed inside a rolled-back transaction; it left no user selection changed. This is not an authenticated Android/HTTP session test.

Post-deployment security advisors show no missing RLS policy on either new table. They flag the three intentionally authenticated SECURITY DEFINER write RPCs; those endpoints enforce `auth.uid()`, exact entitlement/room ownership and transaction locking. Read RPCs use SECURITY INVOKER. [Advisor reference](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable). The pre-existing leaked-password-protection setting is unchanged; [configuration reference](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).

## Validation and release gate

- Full GitHub workflow40025834526 passed on72f5832:588 Flutter tests,34 Python checks, all SQL suites and105 original-media records. Later refinements have focused regression coverage and are sent to the same full CI workflow.
- Full analyzer:0 errors,0 warnings; informational style notices remain.
- Python build/source checks:34 passed; original checksum validator105/105.
- Existing membership SQL suites: restored memberships, presentation policy, checked purchase/replay, animated presentation schema all passed.
- New SQL: all20 exact-tier apply/read/remove, owner/observer reads, mismatched/inactive/blocked/anonymous denial, no direct client writes, expiry, manual slot overrides, owner wallpaper permission and later Store theme switching passed.
- Concurrent Apply versus individual Store equip serializes under the same transaction lock. All20 selections survive independent connections/account changes.
- Flutter controls: all20 Apply/Remove requests, server-confirmed state changes and actual avatar/chat wrapper activation/removal tested. Entitlement without Apply stays unequipped. Revocation during delayed entrance catalog lookup prevents playback; active removal stops playback. Real original mic motion/lifecycle test passed.
- Owner-requested1.0.42 TEST build workflow40028859212 passed all590 Flutter tests, compiled-media/signature checks and Android15 emulator installation/startup. The published250814417-byte APK was downloaded independently: ZIP integrity, SHA-256 and105 membership original records match. **Authenticated per-tier Android pack/render/playback tests remain Not tested.**
- Release blockers: genuine original-media gaps above; authenticated two-user Android profile/room/chat/restart/speech/expiry acceptance. Vivox remains owner-deferred. There is no final-complete APK; the explicitly owner-requested1.0.42 test prerelease is linked above.

## Actual development previews

These are actual Flutter host captures with test state, not Android/device verification.

- [All20 avatar surfaces](ui/membership-full-packs-20261023/all20-applied-avatar-surfaces-host.png)
- [VIP inline package](ui/membership-full-packs-20261023/v3-vip-package-inline-360.png)
- [SVIP inline package](ui/membership-full-packs-20261023/v3-svip-package-inline-360.png)

## Why the installed app still looks old

The previously published1.0.41 APK predates PR44 and this implementation. A backend refresh cannot add new Flutter widgets, Apply/Remove controls or newly bundled media to that binary. The updated code and backend activation are separately reported; no claim is made that a user device already received this UI.

## Own account avatar regression

The Me-tab avatar now uses the same server-backed membership renderer as public profiles and room seats. VIP and SVIP apply/removal widget regressions pass, and Me-tab layouts fit320/360/390dp. These are host tests, not Android verification. Existing Store frame selection remains preserved.
