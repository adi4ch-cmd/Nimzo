# Membership live equipment implementation plan

> Execute inline using the executing-plans skill. Owner requested autonomous continuation of PR #44.

**Goal:** Persist an entitlement-checked exact-tier full-pack selection and use it consistently on real profiles and rooms.

**Architecture:** Preserve membership purchases, existing presentations and Store ownership. Add one atomic selection row per member, an explicit owner-only room-background selection, and sanitized appearance RPCs. An explicit full apply overrides applicable Store slots without deleting ownership or earlier equipment; later individual Store choices override their slot. Removing a pack restores the preserved equipment. Expiry checks happen on every server appearance read; client timers also hide expired effects without waiting for navigation.

**Tech stack:** Existing Flutter/Riverpod, Supabase Postgres/RLS/Realtime, SVGA/VAP players.

**Spec:** Owner's 2026-10-23 final-completion request, PR #44 and `docs/VIP_SVIP_EVERY_TIER_FULL_PACKS_20261023.md`.

## Constraints

- All 20 tiers require exact source kind and tier; no borrowed or relabeled art.
- A missing original remains missing. Native decorations are identified separately.
- No user grants, balance changes, data removal, or APK build before final acceptance.
- No physical-device or multi-user Android claims based on widget tests.

## Review focus

- Expired/blocked membership must never render through cached state.
- Both memberships must use one consistent primary identity; explicit eligible selection wins.
- Concurrent full apply and individual equip must serialize and preserve purchases.
- Room wallpaper requires a separate explicit verified owner action.
- Join effects must be driven by confirmed occupant changes, not rebuilds or old occupants.

## Tasks

1. [x] Audit PR #44 versus integration branch and all local inventories. Record genuine per-tier roles/checksums and reject perk illustrations masquerading as live cosmetics.
2. [x] Write failing isolated SQL tests for all 20 apply/read/remove flows, cross-user read, denial, expiry, switching and Store overrides. Implement minimal additive selection schema/RPCs/RLS and run transaction/concurrency checks.
3. [x] Write failing Flutter tests for applied versus merely entitled, server-confirmed buttons, primary identity and expiration. Wire reusable Apply/Remove controls into each tier, refresh other users through Realtime, and preserve session/account isolation.
4. [x] Use selected slots on actual avatars, profile cards, messages and mic seats. Queue original entrances from real occupant changes; release players and suppress historical replay. Provide explicit room-owner background apply/remove.
5. [ ] Run full analyzer/tests/Python/SQL checks, review whole change, publish only verified additive backend changes with preservation checks. Produce 20-row media/render/device/function matrix. Run Android verification only within owner's build rule; with missing originals or acceptance gaps keep final APK blocked and report exact gaps.

## Audit ledger

- PR #44 head `bc4a896`: 52 files ahead of integration; no membership selection migration, no Apply/Remove controls. Auto visuals tied directly to entitlement. Own entrance widget misses observer playback. Existing Store equipment already has expiry-aware RPC and real-room member stream.
- Baseline focused membership widget tests passed (2026-10-23).
- Ruling: Preserve previous Store equipment under a selected pack rather than deleting equipment rows; removing the pack restores those choices. New individual equip disables that membership slot. This preserves user data and supplies deterministic switching.
- Ruling: Native styles remain labeled as native, never counted as genuine original media. Missing originals block final-complete claims and final APK acceptance.

- Live migration20261023211259 installed;12 existing data-set hashes unchanged. All20 persistence, observer and concurrency SQL tests pass. Full host regression587 passed; latest focused room/inline checks pass. Genuine media gaps and Android acceptance still block task5 final release. See final report; no APK built.
