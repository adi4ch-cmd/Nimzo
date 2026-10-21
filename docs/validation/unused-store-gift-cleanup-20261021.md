# NIMZO unused Store/Gift cleanup — 21 October 2026

**Scope:** incremental cleanup from `feature/membership-reset-20261021`, not a replacement of `main`, not a release APK.

## Verified live Supabase edits
- Removed **41** generic `nimzo-original-*` Store catalog entries with zero price and no ownership/equipment references. Saved their original rows as `nimzo_private.retired_store_mock_catalog_20261021`.
- Kept **33** catalog items: **32** `nimzo-media-*` items and **1** original item that remains owned. Preserved 8 ownership records.
- Kept **5 active gifts**. The other **24** are disabled. Exactly **10** disabled never-sent candidates were copied to `nimzo_private.retired_unused_gifts_20261021`; their public rows were **not deleted** because gift deletion was blocked, and gift history must remain intact.
- Archived **24** retired `phoenix_room_entries` in `nimzo_private`; no public room entry rows erased.
- Equipped-item count unexpectedly became zero during the cleanup window; six exact previously observed and still-owned media items were restored with uniqueness/ownership guards. Count is now **6**. The cause of the temporary disappearance was not established. A private recovery log was created.
- Preserved 3 profiles, 482 ledger records, 124 gift events, wallets, gift ownership and receipts. No coin economy adjustment.

## GitHub source
- Removed legacy five-item unsendable gift preview grid/gallery plus retired zodiac reference modules and five staged/zodiac SVG icons.
- Deleted backend-independent mock Store category design preview screens; kept the actual `NimzoLiveStore`, Backpack, real media renderers, live gift send and effects, room Rocket and Vivox paths.
- Updated the obsolete tests to verify no fake previews and retain real server-authoritative functionality.
- Checked in live cleanup migrations for mock Store rows and read-only gift archive, plus a guarded equipment recovery description.
- Old migration history, backup, rights evidence, and unverified but potentially useful media remain in Git history and current repository. Do not bulk-delete these.

## Validation
GitHub workflow https://github.com/adi4ch-cmd/Nimzo/actions/runs/39531365782 passed Flutter analyzer, original non-membership media verification and **21 focused tests** on cleanup source. The whole regression diagnostic was **372 passed / 9 failed**; it was informational (continue-on-error), not a complete passing full suite. Failures span Realtime timers and historical UI/game tests. No final APK or device smoke test was run.

## Remaining work
- Do not remove gifts with any transaction references without full historical FK/ledger evidence.
- No stale GitHub release artifacts, backend user data or owned equipment were deliberately removed.
- On this cleanup branch, 12 outdated CI/import workflows and two inert premium import scripts were removed after auditing old branch triggers, missing membership tests and duplicate prototype jobs. Kept the main release APK, valid non-membership asset verification, Vivox, Room Rocket, Store/Gift cleanup QA and Android diagnostic workflows.
- This removes files only from `feature/retire-unused-store-gifts-20261021`. Older branches and their Git history still contain past workflow versions; PR #38 must be integrated into its parent PR chain before it affects a final app release.
- Live Supabase remains unchanged by workflow pruning. The 10 archived never-sent gifts are still inactive in `public.gifts` (not falsely described as deleted).

- Future Codex implementation should use this branch plus PR #37 context, reconcile Supabase migrations, and build tested features before publishing.
