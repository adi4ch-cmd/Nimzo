# Rooms, gifts and pages repair

User scope: audit Nimzo on GitHub and Supabase; fix room gifting, Rocket updates and blank/broken pages autonomously.

Release source: `feature/profile-reference-redesign` at `f1140e5`.

- [x] Inspect release source, live schema, grants, catalog, media and recent errors.
- [x] Reproduce Rocket refresh failure: private gift receipts cannot emit client events. Use the settlement-created readable animation event instead; test subthreshold gifts, room filtering, reconnect and cleanup.
- [x] Reproduce missing Moment image: legacy object exists in `moment-images`, current renderer only reads `moments`. Retry legacy bucket without changing user content; test both missing objects terminate in a visible error.
- [x] Repair room gift daily task, which still reads private receipts. Return a caller-scoped UTC-day boolean via authenticated RPC, retaining receipt privacy.
- [x] Verify application analysis, complete tests, rollback settlement tests and authenticated read contracts. Record pre-existing fixture/golden failures explicitly.
- [ ] Review and publish repair branch/PR against the release source.

Constraints: preserve atomic settlement, idempotency, wallet balances, RLS and private media access. Inactive gifts without playable media are a catalog limitation, not permission to fabricate approved media. No real bets, gifts or purchases during verification: database writes roll back.

Verification and remaining visual/release limitations: `docs/superpowers/backend-repair-validation-2026-10-19.md`. The live migration is tracked as `20261019182715_repair_daily_gift_task_status.sql`, matching remote migration history.
