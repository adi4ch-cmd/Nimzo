# Nimzo spec review: gaps and risks

## Blockers to resolve before launch
1. **Sign in with Apple.** Offering Google + Facebook on iOS generally requires an equivalent privacy-preserving login option (App Store guideline 4.8). The spec bans Apple. Fine for Android-first, but it blocks the iOS release. Verify current wording.
2. **Reseller coin sales vs. store rules.** Selling in-app currency outside Google Play / App Store billing can violate both stores' payment policies. Reseller top-ups are the highest takedown risk in the spec. Get store-policy review.
3. **Fruit Party 5x5.** Coin-stake games with random outcomes are treated as simulated gambling by stores. No cash-out helps, but expect age-rating and policy scrutiny. Outcomes must be server-side RNG; the client only renders.
4. **Vivox in Flutter.** There is no first-party Flutter SDK. Plan native Android/iOS bindings via platform channels plus a token-issuing Edge Function. Confirm current Vivox/UGS licensing and pricing.

## Economy holes
5. **Rounding.** 45%/5% is defined only for round numbers. Schema uses floor on integers. Decide who gets the remainder.
6. **Diamonds -> coins at 1:1** creates a re-gifting loop. It loses 50% per pass, so it is safe, but cap and log it. Exchange RPC not yet written.
7. **VIP/SVIP payouts are unpriced.** VIP price is not given. VIP10 pays 9.6M coins/day, which is about $19/day at 500k coins per $1. Check that this cannot exceed what VIP costs. SVIP Friday rewards (50M-600M) have no stated currency.
8. **SVIP cycle.** Needs cumulative USD per cycle, refund/chargeback reversal, and downgrade rules. Not specified.
9. **Recharge is a legal money flow.** Chargebacks, refunds, tax, and minors buying coins need policy.

## Architecture
10. **Speaking state over Supabase Realtime** is too chatty for the DB. Use Realtime Broadcast/Presence, or local Vivox events. Do not write speaking state to tables.
11. **Room chat and DMs at scale** need retention, rate limits, and moderation hooks.
12. **Admin** should be a separate web app, not inside the mobile app. Server-side role checks are in place (`admins` table).
13. **Storage** needs per-folder policies. Not written yet.
14. **Minors and UGC.** Photo moments and DMs need report/block, age gating, and a takedown SLA for store compliance.

## Build order
Done here: scaffold, theme, core widgets, auth (login), schema + gift RPC + RLS.
Next: register/verify/profile setup, tab shell, wallet read, rooms list, then room + voice.
