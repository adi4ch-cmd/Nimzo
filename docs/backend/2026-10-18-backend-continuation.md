# NIMZO backend continuation audit — 2026-10-18

## Work scope

Reviewed live Supabase project **Nimzo**, GitHub
`feature/tingle-ui-rebuild-20261017` (commit `508c9c1`) and the
already-deployed 2026-10-18 Family/Moments schema.

Only additive data/schema migrations were applied. No user accounts,
profiles, wallets, transactions, Moments, photos or rooms were wiped.
No coin adjustment or purchase was initiated. No Android APK was built.

## Fixed and verified

- The secure existing server `create_family` RPC is now wired into
  `FamilyScreen`, retaining the existing royal purple layout. Creation
  explicitly warns and asks confirmation for the existing server charge
  of **1,000,000 coins**, with a stable idempotency key on retries.
- Founder memberships are now inserted by a private SECURITY DEFINER
  trigger during family creation and safely backfilled if absent.
- `nimzo_family_directory` is a PostgreSQL SECURITY INVOKER view,
  aggregating membership counts server-side with existing RLS.
- Family joins previously had an INSERT policy but no INSERT grant;
  `authenticated` now has INSERT permission, still guarded by RLS
  (`user_id=auth.uid()`, valid non-owned Family).
- Owner name/description UPDATE column grants now match the existing
  owner-only RLS policy. Updating `owner_id` remains unavailable.
- Existing Family display/create/join/leave/edit operations use real
  Supabase rows instead of invented placeholder users.
- Moments feed uses the existing `moments_feed_v2` RPC. Legacy
  single-image posts still work; author-owned multi-image posts are
  supported in repositories, gallery picker, editor and feed.
- Previously deployed `family_and_moment_media` migration is now
  represented in version control, not redundantly applied to production.
- Supabase view privilege check: no anonymous SELECT, authenticated
  SELECT and `security_invoker=true` confirmed.
- Production settings read-only audit confirmed
  `coins_per_usd=500000`; no negative wallets among three wallet rows.
  The three registered accounts and balances were preserved.

## Existing backend components confirmed, not rebuilt

- RLS-enabled tables exist for rooms, mic seats, wallets, ledger, gifts,
  Messages, Moments, follows, collectible inventory, PK invites/matches,
  Family and check-ins.
- Edge Functions `voice-token` and `verify-purchase` are ACTIVE.
- Existing self-gift and diamond-exchange logic was not modified.

## Pending / intentionally NOT fabricated

- **Daily check-in** RPC and table exist, but there is no active
  `daily_checkin_reward_coins` amount in `economy_settings`.
  No reward amount was invented and no coins were credited.
- Lucky 77, Grady Lion and proposed Jackpot are still demonstration or
  separately staged work. Production wallet betting, certified outcomes,
  synchronized server rounds and authoritative game payouts are not
  implemented here.
- Verified Play Billing/StoreKit purchase flows, Vivox voice reconnect,
  OAuth redirects and room lifecycle need real Android/iOS device tests.
- A pre-existing registration row lacks `country_code`. Do not assign
  a made-up country to a real account.
- GitHub branches/PRs for UI and games have not been merged automatically
  into main. This backend branch builds on the **UI 508c9c1** checkpoint.
- The old full Flutter suite has three known golden-diff failures;
  this work uses focused backend and Moments tests plus analyzer instead.
- Backend security advisor flags numerous SECURITY DEFINER APIs for
  review. This branch does NOT mass-revoke RPCs required by current
  clients; such changes need per-function authorization review.

## Verification / roll-forward

Run `.github/workflows/nimzo-family-backend-qa.yml` for Flutter
static analysis and focused Family + Moments contract/regression tests;
the workflow never builds or publishes an APK. Supabase migrations
are append-only and tracked under `supabase/migrations/`.

**Not a full production certification.** UI-device, auth, voice,
payment and live load-testing must still follow before a final release.
