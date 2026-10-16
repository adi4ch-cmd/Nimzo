# Profile and room game release — 1.0.7+107

## Implemented

Public Profile has three distinct approved green/blue/red badges directly below User ID. Values come from `profiles.wealth_coins`, `charm_diamonds` and `active_points`; zero is preserved and missing values are explicit. Specific levels are displayed only when provided, never inferred from counters. Existing compact Me/Levels badges are preserved.

All seven approved game boards retain identities, artwork, displayed rules and multipliers. Their headers now explicitly explain service availability. Chip preview selection has accessible labels and reduced-motion-aware animation. Narrow-screen balance overflow is fixed. Approved Games-tab icons are unchanged.

Room games run inside a lower-65-percent window with the existing room mounted. Minimize, restore and close retain room state; minimize/restore retain game selection state. The actual room voice state and authorized microphone callback remain available. Games-tab access remains intact.

## Authoritative contracts still missing

Read-only live schema verification on 2026-10-08 found the three progress counters, but no `wealth_level`, `charm_level` or `active_level` columns or level-threshold RPC. General `level` cannot substitute for three independent levels. Badges therefore show real progress and explicitly unavailable level numbers in production.

The seven approved slugs remain disabled. Existing `game_config`, `play_game`, and `game_my_history` belong to legacy contracts and are not substituted. Each approved game needs an authorized server contract for configuration/rules, current round/phase/deadline, permitted bets, idempotent wager submission, atomic wallet debit, server-owned outcomes/payouts, history and reconnect state. Room scope and membership authorization must be defined. No local winnings, fake rounds or wallet writes were added.

Phaser/WebView integration was not added: the existing Flutter renderer supports these board previews; an additional engine cannot supply missing authoritative gameplay. This release does not claim seven working coin games.

## Signing and APK verification

Existing permanent release key is preserved; its encrypted backup was decrypted and all five files checked byte-for-byte without exposing credentials. Package stays `io.nimzo.app`; build increases to 107. Legacy debug certificate differs and requires initial reinstall; Supabase accounts/IDs/balances are unaffected. Future same-certificate higher-build updates support Android installer handoff.

Previous published build 106 passed aapt parsing, 16-KiB ZIP alignment and arm64 ELF LOAD alignment checks. Minimum Android version is 7.0 (API 24). No attached device or exact device parsing error was available, so the reported phone parsing failure is not claimed resolved. APK ZIP CRC validation was added to both publication paths; modern versioned apksigner output is accepted while enforcing the pinned permanent certificate.

Physical Android installation, two-device Vivox audio and iOS device performance remain unverified. No production data, migrations or economy rules were changed.
