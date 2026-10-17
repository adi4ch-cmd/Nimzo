# NIMZO / Tingle v5.0.19 visual parity tracker

Reference: user-supplied screenshots on 2026-10-17.
Branch: feature/tingle-ui-rebuild-20261017
Base: feature/nimzo-ui-reset-20261017

The UI should match the supplied reference while retaining NIMZO branding,
original Supabase data and server-authoritative permissions. Do not copy
third-party protected artwork into a release without permission.

| Screen/system | State on rebuild branch | Remaining |
|---|---|---|
| Login | Implemented new screenshot-style layout with live email/Google auth | Mobile OTP, quick login, exact icon/pixel QA |
| Registration/profile details | Existing Flutter screen | Match image upload/name/username/country/referral/gender |
| Explore/New/Follow | Rebuilt using real Supabase rooms | PK data, exact gold frame art and chips |
| Daily Check-In | Not implemented | Backend eligibility and payouts |
| My Profile menu | Existing screen | Full screenshot parity |
| Settings | Reference-style UI, existing notification prefs/logout | Calls, blocked users, verification, deletion service |
| Coins/ledger/top-up | Existing wallet/recharge | Full screenshot parity and payment tests |
| SVIP 1/2/3 | Previous UI retired | Original licensed art, membership states and entitlement logic |
| Store and avatar frames | Existing store backend | Categories, buy/equip, exact previews and thumbnails |
| CP Space | Existing CP flow | Reference design and timers |
| Wealth Level | Existing levels | Experience values and level table UI |
| Tasks | Not implemented to reference | Verified reward engine |
| Create Audio Room | New screenshot-style UI with real create RPC | Storage policies/private-room device tests |
| Audio Room | Existing NIMZO room | Tingle has 12 mic seats, NIMZO backend has 10 |
| Seat moderation sheet | Existing controls | Reference design and permission QA |
| Music player | Existing player | Reference controls/queue design and playback QA |
| Friends/Follow | Existing social backend | List badges, friend cards, follows |
| Reactions | Existing app controls | Reference emoji tray and real reactions |
| Country filter | Supabase country filtering wired | Match searchable sheet visuals |
| Moments posting | Existing backend | Reference uploader/topics/mentions |
| Exit dialog | Existing room leave | Match reference confirmation and cleanup QA |
| Gifts/games/rankings/messages | Existing app code | New visual parity and server-authoritative test |

Critical product conflicts:
1. Tingle room shows 12 seats; NIMZO initializes 10. UI-only work cannot
   solve this. A safe seat migration must account for existing rooms and
   backend permissions. Never display dummy seats.
2. Tingle has Normal Live/Multi Live/video calls, whereas NIMZO is audio-only.
   Video SDK, permissions, streaming costs and user consent require new scope.
3. Tingle shows paid SVIP, while earlier NIMZO membership screens were
   intentionally retired. Do not re-enable paid offers without a tested
   entitlement and pricing policy.
4. An APK/screenshots do not supply all live server business rules or
   production animation source files.

Definition of done: licensed/original art, screenshot visual comparison,
functional integration, flutter analyze, tests, device smoke tests and an
installable APK. No unverified claims of A-to-Z parity.
