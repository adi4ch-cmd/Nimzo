# NIMZO — 2026-10-07 LOCKED UI AND BACKEND CONTRACT

**Source of truth:** user-approved `NIMZO_A_TO_Z_LOCKED_UI_MASTER_2026_10_07.html` (includes embedded original screenshots). Never substitute an older mock, an invented layout, placeholder emoji or generic UI for a screenshot. Pixel-level parity must be verified against the embedded references before declaring a screen complete. This document is a checklist, **not** a claim that the Flutter app currently matches.

## Locked screens
- **Profile:** preserve approved original screenshot composition; cover/avatar, name, country flag and permanent Nimzo ID; independently styled Wealth/Charm/Active badges; Following/Followers/Visitors, CP, Medal Wall, Frames, Cars, Top 15 Gifts, Follow/Add Friend/Gift/Chat states; edit profile and storage-backed uploads.
- **Me:** approved purple/pink header, avatar and stats, Task/Store/VIP/Honor Wall, SVIP + Wallet row, CP Zone/Ranking/Settings/Level/About, gift live ranking; bottom tabs Home, Games, Moments, Messages, Profile.
- **Voice Room:** approved white/purple/pink composition; exactly ten microphone seats in two rows of five; owner/member controls, room notice, country selector, gifts, chat and in-room games; Vivox voice remains active.
- **Room Settings:** approved room settings layout; mic, noise reduction, mount/gift effects and text controls; Dice Count 3, Membership Fee 1,000,000, member-only/live mode/guest mic/emoji chat switches, guest text level, room lock/password, dismiss and save. Protect owner-only mutations with backend authorization.
- **Games:** room-only selection and seven named games: Fruit Party Jackpot, Grady Lion, Bigetar, Slot, Teen Patti, Lucky Wheel 77, Bounty Football. Game full-screen views must not expose the room behind them; voice/mic persists. Do not treat preview animations as a working coin game or alter game logic without test coverage.
- **Normal VIP:** tiers 1–10, green-themed membership, coin-based purchase; no dollar recharge conflation.
- **SVIP:** tiers 1–10, black/red/gold styling, verified USD recharge, immediate tier upgrade, 90-day eligibility, automatic Sunday 21:00 Asia/Riyadh reward.

## Economy: exact approved values
| Tier | Normal VIP coin price | SVIP recharge USD | SVIP weekly coins |
|---|---:|---:|---:|
| 1 | 1,000,000 | 50 | 2,000,000 |
| 2 | 3,000,000 | 200 | 5,000,000 |
| 3 | 8,000,000 | 500 | 10,000,000 |
| 4 | 15,000,000 | 1,000 | 20,000,000 |
| 5 | 30,000,000 | 3,000 | 40,000,000 |
| 6 | 60,000,000 | 10,000 | 80,000,000 |
| 7 | 100,000,000 | 30,000 | 150,000,000 |
| 8 | 200,000,000 | 75,000 | 250,000,000 |
| 9 | 350,000,000 | 200,000 | 450,000,000 |
| 10 | 600,000,000 | 500,000 | 800,000,000 |

Exchange rate: **1 USD = 500,000 coins**. Do not credit purchased coins on the client or without a server-verified payment. Wallet transfers, gifts, weekly credits and VIP purchases must be atomic, idempotent and server-authorized. Never delete existing users, IDs, wallets, gifts, levels, ledgers or room data as part of a migration.

## Required verification before merge/release
1. Compare every Flutter screen visually with its corresponding original embedded screenshot at the same viewport and capture a diff; don't declare screenshot parity without this.
2. Verify auth redirects, photo upload bucket policies, profile updates, country codes, RLS, gifts, self-gifts, Moments, room creation uniqueness and ten seats, Vivox audio/mic lifecycle, VIP/SVIP and room settings.
3. Check production database schema/seed/reward scheduler using **read-only** queries first; stage reversible migrations; do not silently change existing financial records or permissions.
4. Run `flutter analyze`, all Flutter tests, native tests, Android release build and actual install/login/room smoke tests. Publish an APK artifact only after these pass.
5. Keep locked UI unchanged except to make it match the approved reference. Never invent success, test results or a final APK.
