# Profile repair and APK verification

Scope: PR #5, branch feature/profile-reference-redesign. Preserve account IDs,
wallet balances, OAuth contract, native Vivox and locked level palettes. No merge.

1. Reproduce analyzer and widget failures. Read live schema, grants and policies.
2. Repair Top 15 Gifts/View All navigation and render catalog-defined artwork;
   missing artwork must remain explicit. Test ranking, navigation and error states.
3. Add Following/Followers and own Visitors lists using existing RLS. Prevent
   duplicate social mutations, handle loading/errors, refresh counts after changes.
4. Make profile updates detect zero affected rows and handle editor lifecycle,
   initial load failures and upload content types. Test update payload and failure.
5. Read real CP partner/duration. Complete ownership catalogs only once the
   backend contract is established; never invent earned inventory.
6. Package native Vivox and OAuth in the branch CI, pin Flutter, commit dependency
   lockfile, run analyze, Flutter tests, native tests, and release APK build.
7. Review diff and verify the Actions artifact and APK contents before reporting.

Blocked evidence: approved screenshot/mockup originals and exact artwork are not
in the repository/thread. Live gift asset paths and storage bucket are empty;
live schema has no medals/frames/cars catalog or ownership tables. Exact visual
matching and real inventory require these inputs; record gaps honestly.

Validation ledger
- Flutter 3.47.6 / Dart 3.13.5. Full analyzer passes; 36 Flutter tests and 2 native contract tests pass.
- Backend authorization/CP consent/gift replay/visitor test suite passed in rollback transactions before and after additive deployment.
- Migration deployed: 20261006231925_profile_collections_and_couple_requests. Catalog and ownership tables remain empty.
- Existing data unchanged: 2 profiles, 2 wallets, 13,903,000 coins, 0 diamonds, 12 gift events. No fixture accounts retained.
- Security advisors introduced no new findings; two exposed definer warnings removed for visit/stats wrappers. Existing unrelated advisor findings remain (https://supabase.com/docs/guides/database/database-linter).
- Independent review: stale profile cache after gifting and inaccessible invitations for linked owners fixed; regression tests pass.
- Release APK verification runs in GitHub Actions and asserts packaged native Vivox libraries and OAuth/app ID/launcher/permissions.
- Exact reference comparison remains blocked until the two approved screenshots/mockup and original artwork are attached. Existing gift catalog has no assigned artwork. No invented gifts/awards were seeded.
