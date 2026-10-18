# Final backend, FCM and APK Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Repair demonstrated backend defects, configure authenticated FCM dispatch where permitted and deliver a verified release-mode APK last.
**Architecture:** Preserve live data and integrations. Reconcile deployed Vault-based sender first; use metadata inspection and disposable databases to validate changes. Keep credential and device limits explicit.
**Tech Stack:** Flutter3.47.6, Supabase/Postgres/Vault/Cron/Edge, Firebase FCM HTTPv1, Vivox, GitHub Actions.
**Spec:** Owner's five-phase execution request in this conversation.

## Global Constraints
- Branch feature/tingle-ui-rebuild-20261017; package io.nimzo.app; Supabase kvqvlpozqokwarovwmwv; Firebase nimzo-1f296.
- Preserve accounts, IDs, balances, current UI, OAuth and Vivox; Email/Facebook/Google only and10 audio seats.
- Family join free/create1M. Rewards disabled and VIP/SVIP/Store paused.
- No credentials in clients/source/logs; authentication stays enabled. Never repeat or route around a rejected security operation.
- Three500000-coin gift demos stay staged; MP4 files do not establish VAP compatibility.
- No reset or production updater publication. Release-mode artifact is built last.

## Review Focus
- Account switching and delayed token callbacks must preserve recipient ownership.
- Scheduler authentication must not export global privileged credentials.
- Spending and retries must settle once without changing real balances during tests.
- Unavailable providers/devices must remain explicit blockers.
- Release APK must retain OAuth callbacks, notifications and native Vivox.

### Task1: Verify existing state
**Files:** tools/backend_contract_snapshot.sql; docs/backend/2026-10-18/final/verification.md; deployed sender source.
- [ ] Fast-forward latest branch; verify every supplied Firebase-state item.
- [ ] Capture schema/RLS/storage/function metadata and account/economy baselines without secrets or user content.
- [ ] Inspect release workflows/signing and establish an artifact-only build path.

### Task2: Complete FCM
**Files:** supabase/functions/push-notifications/index.ts and tests; minimal additive migrations; Firebase client services and Android configuration inputs.
- [ ] Test and fix actual authentication, queue, lifecycle and tap-routing gaps.
- [ ] Verify service-only Vault reader and Google OAuth/HTTPv1 without printing credentials.
- [ ] Configure a supported authenticated scheduler if security review permits. Never disable JWT or export a global service key.
- [ ] Test leases/retries/token cleanup, preferences, blocks and sessions; inspect event triggers before adding any.
- [ ] Verify foreground/background handling and permission/channel/sound/vibration. Document iOS/APNs/device limits.

### Task3: Backend audit and repairs
**Files:** existing backend verification tools/SQL tests; focused new regressions and migrations only for proven defects.
- [ ] Inspect schemas, RLS, RPCs, triggers, storage and Edge Functions.
- [ ] Run disposable auth/profile/room/moderation, gift/ledger/concurrency, Moments/messages and game settlement checks.
- [ ] Confirm current economy rates/catalog before changes. Do not invent odds or activate staged gifts.
- [ ] Repair failures with red/green tests; verify live data fingerprints unchanged.

### Task4: Verification and source push
- [ ] Run dependency resolution, Flutter analyze/full suite, Node/Python/SQL checks. Preserve deferred golden failures.
- [ ] Obtain independent security/economy/build review and push exact source SHA.

### Task5: APK delivery last
**Files:** existing or narrow manual-only release-artifact workflow; final report.
- [ ] Build release mode from final branch SHA with Firebase, OAuth and Vivox.
- [ ] Verify workflow success, actual artifact, package/version/signature/native libraries and launch where hardware exists.
- [ ] Deliver real download URL, SHA, complete verification report and remaining blockers.
