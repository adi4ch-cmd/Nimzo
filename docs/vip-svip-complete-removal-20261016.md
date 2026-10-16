# NIMZO — VIP/SVIP full retirement (2026-10-16)

The owner requested that the app no longer provide VIP or SVIP, including free versions, and that users' VIP/SVIP selections and last-claim state be deleted.

## App removal
- Remove VIP and SVIP navigation cards, destinations, purchase/activation pages, badges, animated profile frames, mic decorations, chat bubble effects, and all 17 created membership SVG emblems.
- Old /vip and /svip deep links redirect to Profile rather than restoring a deleted screen.
- Remove non-runtime reference VIP image assets.
- Keep independent Royal Store medals, purchased collectibles, Levels, Gifts, Rooms, Wallet, and Vivox.
- Version: 1.0.27+127.

## Supabase deployment
The additive retirement migration was deployed on 2026-10-16:
- Drop public.activate_free_membership(text,integer).
- Drop public.free_memberships (including all 1 remaining user assignment).
- Reset every legacy VIP/SVIP level, expiry, reward claim date, and related field to zero/NULL. Historical disabled compatibility fields are retained to avoid breaking old schemas.
- Preserve historical financial ledger, payments, gift transactions and old private audit backups. Store medals are not VIP memberships.
- Archive only aggregate deletion counts, not new copies of deleted user membership data, under nimzo_private.membership_removal_audit_v2.
- Ensure the old paid membership APIs remain disabled and gift VIP requirements are zero.

## Live verification
Before: 1 active free VIP/SVIP assignment; 0 active legacy VIP/SVIP; 1 non-null legacy VIP claim date.
After: free_memberships absent, activation function absent, 0 user membership fields populated, 3 user profiles, 3 wallets, 342 ledger rows, 71 gift event rows, 6 independent Store collectible ownerships. Aggregate wallet coins remained 4,386,000 and diamonds 0 at verification.

Never claim permanent deletion of Git history or historical financial/audit records. Real installable APK requires a successful workflow artifact, not just source changes.
