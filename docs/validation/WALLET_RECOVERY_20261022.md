# Durable exchange and pending-request recovery — 2026-10-22

The Wallet previously generated a fresh diamond-exchange key on every attempt.
A lost response followed by another confirmation could therefore repeat the
exchange. The updated Wallet persists the account, exact amount and retry key
before submission, restores them after reopening and permits receipt recovery
even when the already-exchanged diamonds leave a zero balance.

The additive `20261022174046_checked_diamond_exchange.sql` migration was applied
to the existing Supabase project. Its checked RPC binds the confirming account,
takes the original exchange advisory lock and recovers the immutable ledger
receipt before mutable account checks. New exchanges delegate to the unchanged
original RPC. The 1:1 rate, balances and historical ledger were not rewritten.
Readback retained 4 wallets, 4,795,975 coins, 22,003,875 diamonds and 34 Rocket
history rows. No production QA exchange was performed. Anonymous execution of
the checked endpoint is denied; authenticated execution is explicitly granted.

Review and regression tests also exposed two cross-screen persistence races:

- A disposed screen's delayed response could clear a newer saved request.
- A stale session could overwrite a newer request before retrying its old key.

The shared pending-confirmation store now serializes short preference operations,
rejects replacement of a different record and assigns each submission a local
attempt lease. Completion clears only the matching record and latest attempt.
An old declined attempt cannot erase a newer uncertain attempt of the same key.
Wallet exchange, Treasure funding and Games use this protection. Local records
keep their existing schema; server authorization remains authoritative.

SharedPreferences updates its cache before its platform write returns. The
helper therefore always awaits a successful write, including when cached data
already matches. A platform-failure regression returns false twice and verifies
that no exchange is submitted until the third write succeeds. Its platform
interface is now an explicit test dependency at the already-locked 2.4.2 version;
no dependency version was downgraded or upgraded.

Fresh disposable SQL fixtures execute the actual original exchange function and
cover receipt recovery after restriction, expected-account rejection, changed
amounts, insufficient funds, anonymous denial, duplicate/legacy concurrency and
coin-plus-diamond conservation. Client regressions exercise lost responses,
reopening at zero diamonds, out-of-order responses, stale writes, same-key retry
ownership, corrupt storage and failed persistence. Evidence and final full-suite
results are recorded in `wallet-recovery-evidence-20261022.json`.

An intermediate full run failed the 320dp login test when another Flutter
invocation regenerated the shared test asset bundle (`AssetManifest.bin` was
temporarily absent). Final verification runs Flutter dependency resolution,
analysis and the full suite sequentially, without overlapping test invocations.

These are source/backend fixes, not authenticated Android purchase/audio proof.
No new APK was built. Full original-task acceptance remains incomplete.
