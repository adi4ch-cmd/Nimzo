# Retired unused workflow/importer cleanup — 21 October 2026

This cleanup follows the verified Store/Gift cleanup in PR #38 and legacy VIP/SVIP reset in PR #37.

Removed only files shown to be obsolete on this branch:
- `tools/import_willchill_package.py` and `tools/install_willchill_premium.py` (fail-closed no-op scripts)
- `.github/workflows/willchill-premium-qa.yml` (references deleted VIP/SVIP tests)
- `.github/workflows/nimzo-premium-no-vivox-apk.yml` (old 441-member-bundle, voice-disabled APK recipe)
- `.github/workflows/nimzo-gift-gallery-preview.yml` (references nonexistent old mock-gift screenshot test)

Kept working verification tools, remaining 261 nonmembership media, standard Android APK workflows, voice/emulator validation, Store/Backpack, gift and Rocket systems, rights evidence, historical migrations, user data, and private archives.

No Supabase mutations or production APK work were performed in this commit. Earlier Supabase private archive holds 41 old Store mock rows and 10 unused disabled gift candidates; disabled gift rows remain in public without being sendable.

No Git history or old branches were rewritten. Newly added narrow GitHub Actions workflow validates this prune without claiming the full app is bug-free.
