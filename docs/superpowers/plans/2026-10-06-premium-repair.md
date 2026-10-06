# Nimzo Premium Repair Implementation Plan

> **For agentic workers:** Execute isolated domain tasks in parallel with root integration and final review.

**Goal:** Repair verified defects and deliver a premium, shareable Android test APK.
**Architecture:** Preserve Flutter Riverpod app, Supabase authoritative database and Android Vivox bridge. Use non-destructive migrations and tested lifecycle/data providers.
**Tech Stack:** Flutter/Dart, PostgreSQL/Supabase Edge Functions, Java/JNI/Vivox, GitHub Actions.
**Spec:** docs/superpowers/specs/2026-10-06-premium-repair.md

## Global Constraints
- 500000 coins/USD; 45% diamonds, 5% room reward per locked spec.
- No account/data deletion or balance resets; preserve IDs and history in backend.
- No Agency/BD/Host Center/Movies or separate history screens.
- Five navigation tabs; premium white/green style; no invented stats/badges.
- User requested autonomous execution; no repeated permission prompts.

## Review Focus
- Logout/reconnect and switching rooms must release voice and membership.
- Unauthorized VIP/reward edits and private-room voice access must fail.
- Failed payment verification must never announce credited coins.
- Small screens/RTL and missing images must render cleanly.
- Retry/idempotency and parallel seat/game calls must preserve balances.

## Tasks
- [ ] Environment: isolated feature checkout, current docs and regression tests; obtain Flutter runtime and baseline tests.
- [ ] Backend: write failing SQL authorization/contract tests; implement migration for protected fields, room/seat/chat/lifetime/game rules and privacy; apply and verify with rollback/read-only tests.
- [ ] Voice: write lifecycle regression tests; connect room entry/seat/mute/exit; permission handling and asynchronous JNI; review token authorization; analyze/test.
- [ ] UI: replace fake/placeholder visual treatment, proper icon family and image surfaces; maintain routes/exclusions; check small-screen layouts and honest states.
- [ ] Data flows: complete profile sections and counters, game presentation/room ID, receipt package contract, wallet refresh and truthful error handling; behavioral tests.
- [ ] Integration: review diffs, resolve interfaces, full analyze/tests, run CI release APK build and inspect package/artifact; publish download and report device-only limitations.
