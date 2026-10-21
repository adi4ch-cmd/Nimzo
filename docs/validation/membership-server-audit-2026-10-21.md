# Current decision

Owner confirmed on21October: preserve the NEW VIP/SVIP removal. Membership restoration is excluded from this build. A guarded restoration attempt failed before any changes because newer migrations removed the old columns/catalogs. The SQL research is stored under docs/blocked and must not be applied.

# VIP / SVIP server audit — 21 October 2026

Read-only inspection of Supabase project `kvqvlpozqokwarovwmwv` confirmed:

- `vip_status()` returns `retired: true`, zero effective levels, and disabled automatic SVIP payouts.
- `purchase_normal_vip(integer,text)`, `claim_vip_daily()` and `claim_svip_friday()` raise SQLSTATE `0A000` with the retirement message.
- `phoenix_membership(uuid)` returns zero effective levels.
- Ten-tier VIP prices, SVIP recharge thresholds, VIP daily rewards and SVIP weekly reward catalogs remain stored. Their existence does not activate memberships or grant clients access.

The Flutter premium screen now reads effective account status through `vip_status()` instead of raw profile columns. This respects server retirement, account restrictions and membership expiry. The screen refreshes status every minute and on pull to refresh. It preserves the real server level even above the imported artwork range, and identifies artwork as previews (VIP 1–7, SVIP 1–8 versus ten server tiers).

A future purchase contract must explicitly return **both** `retired: false` and `purchases_enabled: true` from `vip_status()` before the purchase button becomes available. The guarded client uses `purchase_normal_vip(p_tier,p_key)`, asks the app user to confirm the coin cost, keeps its retry key after an uncertain response, accepts only `ok`/`replayed` server responses, and invalidates membership, wallet and profile after confirmation. It never directly writes membership or wallet fields. Retry keys currently survive retries while the screen remains open; unresolved purchases should be checked against refreshed account status before leaving and starting a new purchase.

## Outstanding server work

Production activation is **not complete**. No membership migration was applied and no account, balance, entitlement or catalog was modified during this audit. A partial restoration of only the purchase RPC would fail and would misrepresent SVIP benefits.

A coherent restoration must review all effects of `20261016040304_retire_all_vip_svip.sql`: the `reject_retired_membership` profile trigger, retired purchase/claim RPCs, effective status and entry APIs, disabled entry trigger and weekly payout job, removed verified-recharge accrual, catalog grants, and removed moderation protections. Historical snapshot membership must not be blindly restored: expiry, valid purchases and entitlement provenance require validation. Existing wallet balances and ledger/purchase history must remain unchanged.

Benefits such as moderation immunity and weekly rewards must not be advertised as active until their current server implementations and authorization are verified. Artwork and local previews do not demonstrate those guarantees. The current client deliberately leaves paid activation disabled against the audited server.
