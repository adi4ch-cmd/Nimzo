# VIP/SVIP Removal Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement inline, task by task.

**Goal:** Permanently retire all VIP/SVIP and current assignments without affecting unrelated accounts or finances.
**Architecture:** A private retirement archive and server-side disablement make stale clients harmless; Flutter removes paid UI and effects. Historical data remains for audit.
**Tech Stack:** Flutter, Riverpod, Supabase Postgres, Vivox Android bridge, GitHub Actions.
**Spec:** docs/superpowers/specs/2026-10-16-vip-svip-removal.md

## Global Constraints
- No replacement free VIP, no purchase, no expiry, no membership rewards.
- Preserve user IDs, wallets, coins/diamonds, gifts, levels, transaction history and administrative permissions.
- Keep SVIP destination blank; old VIP deep links also resolve blank for compatibility.
- No claims of staging or physical device testing without actual evidence.

## Review Focus
- Old clients must fail purchase before any wallet debit.
- Recharge must still credit once but never grant SVIP.
- Migration replay cannot overwrite the original backup.
- Unrelated Royal store medals and gift animations must remain.
- Existing voice reconnect and authorization behavior must continue.

### Task 1: Backend retirement
- [x] Add behavior assertions for zero active assignments, denied purchase/activation/rewards, disabled scheduler and preserved balances/history.
- [x] Run against current live DB in rollback transaction; expect failure for legacy active assignments.
- [x] Generate retirement migration through CLI. Archive affected rows, configuration and function definitions in a private RLS-protected table. Disable mutation APIs, scheduled payouts, regrant hooks and obsolete entry trigger. Clear legacy active assignments. Remove gift membership gates without changing gifts or prices.
- [x] Rehearse migration twice in rollback transaction with invariants and RPC tests; inspect rollback leaves live unchanged.
- [x] Apply authorized migration and verify the same invariants and no assignments.

### Task 2: Flutter retirement
- [x] Add tests that stale membership JSON creates no badge, membership deep links are empty and Me has no purchase link.
- [x] Observe expected failure before replacing membership presentation.
- [x] Delete legacy VIP modules/assets registrations, remove decorators/entry listeners and promotion. Keep ordinary profile identity and all unrelated gifts/store/voice behavior.
- [x] Replace obsolete paid-feature tests with retirement tests, retaining voice reconnect and profile coverage.

### Task 3: Verification and delivery
- [x] Run Flutter analysis, full tests and native/token/purchase regression suites. Record failures and fix relevant regressions.
- [ ] Review changes for account/financial safety and obsolete imports/assets.
- [ ] Commit and push to requested feature branch. Run existing native Vivox Android release workflow and inspect build output.
- [ ] Provide exact commit, deployment status, validation evidence, real successful APK URL and remaining physical device limitations.
