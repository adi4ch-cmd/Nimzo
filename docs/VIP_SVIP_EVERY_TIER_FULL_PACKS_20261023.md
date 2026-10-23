# NIMZO VIP / SVIP full sets — all tiers (2026-10-23)

## Scope — not just nine screenshot examples

Build a coherent, functional, themed **set for every VIP and every SVIP tier offered by the server**. Current catalog and bundled previews cover VIP 1–10 and SVIP 1–10 (20 tiers total). Any future tier must use exactly the same data-driven structure, not an image-only generic fallback.

A screenshot of "SVIP Supreme 1–9" was provided as a design **reference**, not a limit on the count or proof those specific assets are in our possession. Never label mixed or partial art as a complete original set.

## Current verified source inventory (branch integration/nimzo-v3-dynamic-20261021)

- `nimzo/assets/membership/remix/manifest.json`: VIP 1–10 each has hero, badge, card; SVIP 1–10 each has hero, badge, card, animated SVIP hero still. VIP cards currently have **different provenance** from hero/badge, so visual consistency is not established.
- `nimzo/assets/willchill_premium/vip/`: VIP 1–5 have additional artwork files for avatar/entry/chat/mic/profile, and VIP 1–7 have tier header and ID ornament. Do not infer that a file is a working in-room effect from a PNG alone.
- `nimzo/assets/willchill_premium/svip/`: SVIP 1–8 have tier page backgrounds, medals/progress widgets; the ID ornament file is shared rather than tier-specific. These are **not** full avatar/chat/entrance/room packs.
- The active membership page previously showed only 3 core media roles per tier, with an optional remotely approved entrance.
- The local `WillChillMembershipShowcase` has icon placeholders and a generic fallback for higher tiers; it is not evidence of complete sets.
- The Voku manifest explicitly marks its contents unapproved. Do not activate it unless its conditions are satisfied.

## Per-tier acceptance checklist

For **every** tier (VIP *n* and SVIP *n*) verify the following distinct assets and behaviors:

1. Animated or static **tier showcase**, matching the rest of the tier.
2. **Membership badge** shown only for active server-verified membership.
3. **Membership/profile card**.
4. **Avatar/profile frame** with actual profile rendering.
5. **Tier-specific ID/nameplate** (not a shared unrelated nameplate).
6. **Animated entry banner / room entrance** that plays once after confirmed join.
7. **Chat bubble** that appears on real chat messages.
8. **Mic-seat effect/frame** applied to the user's actual mic seat.
9. **Profile decoration** in real profile screens.
10. **Room background / room theme** visible in the real voice room.

These are content and runtime acceptance criteria, not a claim that every tier currently has them. Where a game or room widget does not support the specific cosmetic, add the correct runtime integration and tests. Keep purely visual membership entitlements separate from privileged actions and monetary RPCs. No fake benefits or placeholder animations.

## This draft PR delivers

- A data-driven preview gallery for any selected VIP/SVIP tier, opened from the existing membership screen.
- Larger previews on tap, a visible missing-parts inventory, actual existing image and approved media components.
- A source-level inventory that does **not** manufacture art that is absent.
- Coverage and declared-asset checks, pending execution with Flutter CI.

## Not yet delivered / release blockers

- Coherent original complete sets for all 20 tiers. The existing material does not meet the criteria above.
- Audited matching avatar/ID/entry/chat/mic/profile/room artwork for each tier (especially VIP 6–10 and SVIP 1–10).
- End-to-end equip/unequip, ownership, expiry, UI refresh, room join/playback, and mobile screenshots/animation verification.
- Provenances and appropriate reuse rights for each asset, and server-approved publication of any new remote media.
- Flutter static analysis, widget tests and Android device tests on this branch. **Do not build or advertise a finished APK yet.**

## Progress rule

Track completeness **per slot per tier**, not merely whether VIP/SVIP tabs or tier selectors exist. Mark a pack complete only after every promised component passes asset, preview, entitlement and runtime checks. Existing app and Supabase purchases/entitlements must be preserved.
