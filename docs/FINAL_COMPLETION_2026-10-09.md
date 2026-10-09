# NIMZO completion continuation — 9 October 2026

Started from remote `4f6762c21ee9cf28d076bc7bfd8011c013bd31dd` on `feature/profile-reference-redesign`. Existing approved UI, assets, accounts, UUIDs, permanent numbers, balances and economy are preserved.

## Implemented and verified

- Voice teardown now always clears local SDK/session/speaking state if native leave/shutdown throws; a regression reproduces the old stale indicator and verifies fresh initialization on retry. Native error diagnostics remain sanitized.
- Permanent-room safeguard: one owner across all room statuses, permanent room number copied from the owner's Nimzo ID. No existing rooms are deleted/renumbered. Preconditions reject incompatible records; room writes are locked while installing the constraint/trigger. Trigger lives in the private schema with client execution revoked. The formerly pending migration is now versioned to its actual deployment history.
- Atomic room settings/photo save: new `save_room_settings` uses SECURITY INVOKER and invokes the existing owner-authorized settings/password/photo operations in a single transaction. Injected photo failure rolls back name, permissions and password changes. Successful save preserves password hashing; outsiders and anonymous callers cannot save. Flutter sends exactly one RPC.
- Verified gift animation stream: the live table was absent from `supabase_realtime`; publication membership is now installed idempotently. Event/media writes, including TRUNCATE, are revoked from client roles. Existing country/room/approved-media read policies are preserved; settlement triggers retain server privileges.
- Android delivery: without any permanent signing secret, existing CI builds a release-mode APK using generated Android development signing and uploads a separately named installable test artifact. Any partial permanent signing configuration still fails rather than falling back. The permanent certificate, updater metadata and public release publisher remain gated by complete permanent signing configuration. Signature/package/version, OAuth/permissions, ZIP integrity/alignment, three-ABI native libraries and actual retained Vivox DEX callbacks are verified before upload. Development signing cannot update a permanent-release install and may require uninstall; local drafts/cache may be lost, server accounts/balances persist.
- CI screenshot stability: async board-header image decoding is now awaited. The first CI run failed on the missing Fruit header (2,145 pixels); the Lucky Wheel baseline also contained a missing 48px header. That one baseline was visually checked and corrected to include its existing approved artwork. No production board design or golden tolerance changed. CI uploads future failure images for diagnosis.

## Fresh validation

Flutter 3.47.6 / Dart 3.13.5 installed in this session. Dependency resolution passed without lockfile changes. Formatting: 177 files, zero pending changes. Strict analyzer: no issues. Full Flutter suite: **248 passed**. Focused voice suite: 27 passed. Edge authorization/purchase-contract suite: 16 passed using provider fixtures. Native voice contracts: 7 passed; reference integrity: 1 passed; tool workflow/publication tests: 4 passed. Native update Java test skipped locally because javac is absent; CI includes Java and runs it.

PostgreSQL 17 disposable clones tested the room guard and actual live settings functions with rollback fixtures. The gift publication/grant repair passed metadata tests and repeat application in a disposable simplified event/media schema. These are database/contract tests, not authenticated device or Realtime transport tests. Production verification was read-only after deployment; no production account or balance fixtures were created.

Deployed and read-verified in `kvqvlpozqokwarovwmwv`:
- `20261009052036_permanent_room_owner_guard`
- `20261009052345_atomic_room_settings`
- `20261009052739_verified_gift_realtime_read_only`

All 52 public tables have RLS. Security advisors retain 51 notices for intentionally exposed existing SECURITY DEFINER RPCs, three no-policy informational notices, and disabled leaked-password protection. This pass does not claim a complete independent audit of every historical RPC.

## Remaining blockers

- Seven approved games have artwork/boards but lack complete approved rules, odds, rounds, wagering/reconnect and settlement contracts. They remain disabled; legacy games are not substitutes.
- Wealth/charm/activity level thresholds and Active earning rules are approval-pending. No invented levels are assigned.
- There are zero approved animation-media records and no bundled Dragon/Golden Dragon video or SVGA files. Realtime is repaired, but actual playback cannot be claimed without licensed approved media and device checks.
- Google/Facebook/email are enabled in public GoTrue settings; genuine provider login, recovery, upload, purchase and device voice tests remain unverified. iOS native Vivox implementation is absent. No connected devices or genuine purchase receipts are available.
- Permanent release signing secrets remain absent in the observed CI run. A development-signed test artifact is installable after successful compilation, but is not a permanent-signature updater release.
- Missing provider/product contracts for PK/music/treasure/store rewards and unsupported services remain explicit unavailable states; they are not marked complete.

The initial Actions run `37888159730` stopped on the image-decode golden race; no APK was produced by that run. The next final-source run must finish successfully before an APK link is reported. Final delivery message records its actual source SHA, run status and artifact link.
