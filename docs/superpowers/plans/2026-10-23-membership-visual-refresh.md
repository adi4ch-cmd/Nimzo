# Membership Visual Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement task-by-task. Steps use checkbox syntax.

**Goal:** Replace Voku visuals for all20 membership tiers with verified source-backed artwork.
**Architecture:** YoHo VIP heroes/badges, Mizah VIP backgrounds, Falla SVIP animated heroes/badges/cards. Immutable bundled manifest plus approved Supabase presentation descriptors; existing membership monetary authority remains unchanged.
**Tech Stack:** Flutter3.47.6, flutter_svga0.0.13, Supabase PostgreSQL/Storage.
**Spec:** docs/superpowers/specs/2026-10-23-membership-visual-refresh-design.md

## Global Constraints
Preserve all old assets and financial/entitlement data.10tiers each, no renamed baked labels.70 original membership assets. Hero SVGA <=4MiB; static card/badge <=4MiB. Real Android evidence before publication. No Vivox integration in this scope.

## Review Focus
Old bundled fallback must never reintroduce rejected Voku art. Remote malformed hero/card must fail closed. Looping hero must not alter finite entrances. Published artwork must not change purchases, grants or rewards.280dp/large-text layouts must remain usable.

### Task1: Source-backed catalog
- [x] Add runtime regression requiring all20 bundled tiers to use non-Voku original hashes and true formats, plus safe remote SVGA hero/static-card parsing.
- [x] Observe failure, then extract70 files from checksum-pinned archives into assets/membership/remix with manifest and change bundled provider.
- [x] Verify actual decoder preflight and original-byte identity for every file.
### Task2: Presentation and motion
- [x] Add finite-entry/looped-hero renderer regression, observe failure; implement explicit lifecycle-aware decorative loop with unchanged finite entrance behavior.
- [x] Refresh premium screen layout only, consume optional card/loop media; preserve monetary callbacks, providers and key handling.
- [x] Run existing responsive/identity/payment tests and capture actual screen previews.
### Task3: Native proof and safe publication
- [x] Extend native harness with70 records; run actual bitmap/SVGA every-frame checks and inspect collected previews.
- [x] Test additive optional-card/hero-format validation and20 presentation insertions in disposable membership fixture; assert old financial/entitlement/catalog rows unchanged.
- [x] Upload exact immutable objects, validate HTTPS/MIME/SHA/size; seal temporary importer.
- [x] Publish only after genuine native proof, read back descriptors and preservation hashes.
### Task4: Delivery
- [x] Full source/backend checks and exact-source TEST acceptance; draft PR43 updated for review. Independent human review remains pending.
- [x] Build/test/publish next test APK, verify actual downloaded bytes and provide source app names/download link.

Latest owner scope: add20 extra diverse gifts,10 at500000 and10 at1000000coins. Maximum2 gifts per semantic type; colors or renamed variants do not create new types. The prior10-car/10-fantasy selection is rejected and must not be published. Mix complete supported SVGA/VAP scenes from authorized sources; preserve previous27giftprices and73Storeitems. Verify all SVGAframes and native VAP completion/frame-events/GPU pixel samples. If fewer than20 genuinely suitable distinct effects exist, report the exact shortfall instead of padding with repeated types. Public static hero envelope carries nested animated descriptor for older client compatibility.

Current honest shortlist:7 candidates (2cars,2armoredfantasy,1dragon,1romance,1crowd),4x500K/3x1M.13 requested gifts remain missing. Rejected20set moved out of app assets into audit scratch; no rejected effect is bundled. Manifest explicitly records requested20/selected7/remaining13.134 total native records (old57+membership70+shortlist7). No new live activation yet.

Delivered checkpoint:20 YoHo/Falla membership presentations and7 diverse gifts published;34 active gifts/73Store. Exact Android proof134media succeeded; all84 public objects checked;12 existing-data hashes unchanged.564 Flutter/34Python/backend checks passed at b92056e. Verified1.0.41+141 TEST APK published and downloaded/checksummed. Requested20 additional gifts remain13 short; this checklist completes the verified refresh/delivery checkpoint, not that whole request or original master task.
