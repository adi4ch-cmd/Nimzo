# Backend continuation — 18 October 2026

Continued from 508c9c1 on feature/tingle-ui-rebuild-20261017. Owner approved Purple Gold microphone/N logo, backend development, free Family join and exactly 1,000,000 coins for Family creation.

Implemented:
- Approved logo in login/register and persistent Android launcher inputs. Test workflow includes unchanged native Vivox integration, OAuth callback and permissions; APK verifier checks package, signature, native libraries and bundled logo.
- Authenticated Family directory, creation confirmation with explicit cost, free join/leave and own/joined families pinned independently of newest 100 public entries. One owned Family per account.
- Atomic server creation: active account, locked wallet, exact 1M debit, matching ledger record, request-key replay/payload verification; authenticated direct inserts denied. Failed creation rolls back; retries and concurrent same-key calls debit once.
- Up to nine Moment photos, add/remove previews and horizontal feed gallery. Author-only writes, path ownership and media count validation. Existing single-photo rows and legacy feed retained.

Migration deployed successfully: `20261018035405_family_and_moment_media`. Public feed is security invoker; privileged financial implementation is private with auth checks. No game rules, global wallet rules, voice implementation, accounts or balances were reset. Creation charges occur only when a user submits the explicit paid action.

Validation:
- Full live **schema-only** metadata cloned into disposable PostgreSQL 17; no real users copied. Migration, RLS, media ownership, insufficient balance, direct-insert bypass denial, exact debit, replay conflicts and two-session concurrent debit pass. Reproduce using `python3 tools/verify_social_backend.py --snapshot <schema_snapshot.json>`; snapshot query is tools/backend_contract_snapshot.sql. Fixed snapshot replay support for generated columns and table-level grants.
- Before/after live checks: wallet fingerprint unchanged; ledger421, profiles3, Moments3; two existing media posts backfilled. New Family count0. No live user charged for tests. New feed readable; unauthenticated creation denied.
- All statically referenced Flutter RPCs existed except new v2 feed before deployment; new feed and create RPC now deployed. This is contract existence evidence, not a claim that every provider/device flow is exercised.
- Flutter analyze --no-fatal-infos: exit0, 0 errors/warnings, 37 existing infos.
- Full Flutter suite: 343 pass / 3 existing golden failures: master_visual_preview_test room overlay; reference_preview_test approved boards/empty home; remaining_visual_qa_test remaining reference screenshots. Baselines not rewritten or disabled.
- Subsequent focused Family repository tests:3 pass; Moments/editor/Family tests:7 pass. Screenshot capture login/Family/composer:3 tests pass at320/360/390. Screenshot fixture precaches the actual approved logo before capturing; image decoding is asserted.
- Tool workflow contracts:5 pass. Disposable schema behavior and concurrent transactions pass. Independent review found the old-family accessibility issue, which was fixed and regression tested; final security review found no remaining critical/important issue.
- Supabase security advisors unchanged:8 no-policy INFO notices,62 existing authenticated SECURITY DEFINER warnings and existing leaked-password-protection warning. New features introduced no new advisor notices. See [advisor guidance](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable) and [password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).

Remaining product/provider decisions:
- Owner confirmed VIP, SVIP and Store must stay paused. All taps (including Backpack, task and Honor Wall Store links) show Coming soon without navigation. Direct links, query variants and trailing slash URLs redirect to Profile; paused screens have no router builders. Membership backend remains retired.
- CP reward claims and referral rewards lack approved fulfillment rules. Store UI is paused; existing server catalog/ownership records remain intact. No prices or rewards invented.
- Physical microphone/OAuth/purchases/push delivery require provider accounts and device validation. No physical device available in this workspace. Existing device-token registration alone is not evidence of end-to-end push delivery.

No merge, production APK release or updater publication. GitHub Actions test artifact verification is recorded separately after build.

Follow-up paused-feature tests:20 pass, including real Profile taps, authentication precedence and actual router deep-link rejection. Final full-suite rerun and test APK artifact verification pending at this commit.
