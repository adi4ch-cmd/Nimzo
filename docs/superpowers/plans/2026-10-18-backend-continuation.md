# Backend continuation

Owner request: install locked 01 Purple Gold logo, then finish backend wiring. Continue from 508c9c1 on the requested feature branch. Preserve Email/Facebook/Google, audio-only rooms, ten seats and io.nimzo.app. No production release or merge.

1. Install approved logo on authentication and persistent Android build inputs; verify generated host icon.
2. Use existing live contracts rather than rebuild working room/chat/profile/store services. Add the absent Family directory, creation and join/leave data flow with authenticated RLS and no financial effects. Owner clarified: join is free; creation costs exactly 1,000,000 coins. Implement atomic creation and debit with idempotent ledger record, no direct insert bypass. No rewards or rank rules.
3. Complete multi-photo Moments while retaining compatibility with existing single-photo posts and existing feed clients. Enforce author permissions and media limits server-side; test against disposable PostgreSQL before additive deployment.
4. Check frontend RPC/table contracts against live metadata, run behavioral authorization and Flutter tests, analyze, review and produce a GitHub Actions test APK.

Known constraint: live purchase_normal_vip explicitly raises 'VIP and SVIP have been retired', matching the approved 2026-10-16 retirement spec. Do not reverse it or invent CP rewards, Store prices, level thresholds or payout rules. Preserve wallet, Games and Vivox internals. Provider/device validation requires real accounts/devices; report limits precisely.
