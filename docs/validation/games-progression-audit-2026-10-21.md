# Games and progression audit — 2026-10-21

## Verified backend

Read-only queries against Supabase project `kvqvlpozqokwarovwmwv` found two active `game_catalog` entries: `fruit_party` (Nimzo Fruit Party) and `fruit_wheel` (Nimzo Fruit Wheel). Both `play_game` and `nimzo_game_level` are deployed. No production wager or wallet mutation was performed. Active catalog rows establish technical availability only; jurisdictional, age, provider licensing and commercial eligibility were not verified by this audit. No claim of compliant deployment or regulated-game approval is made.

The client formerly hid both active games: catalog, room selector and room game host all used the seven reference-only games. The server games now appear under their actual names and route to a native server-settled screen. The client submits only room, game, coin amount and idempotency key; it displays the returned result and payout without calculating either. An uncertain network response retains the original amount/key for retry; a definitive database rejection permits correction. Confirmed settlement refreshes wallet and game progress. Pending requests are retained while the screen remains mounted/minimized; process termination or closing the game does not currently persist an unfinished request.

`play_game` validates active account, current room membership, room game permission, bans, wallet balance and its existing 1–500000 coin limit. It generates outcomes and changes the wallet in a database transaction. Fruit Party's existing server payout rules and Fruit Wheel's configured server segments were retained unchanged.

## Exact missing live contracts

- Jackpot, Lucky 77 and Grady Lion use bundled, offline HTML practice games with local demo chips and no wallet/auth bridge. Lucky Wheel 77 uses a Flutter practice board with demo chips. They are labelled **Practice**, separately from **Preview** boards and the two real server games.
- The requested Lucky Wheel is not silently substituted with Fruit Wheel: the existing server game is explicitly named Fruit Wheel. No `lucky_wheel_77` live settlement contract exists.
- Teen Patti has only a Player A/B/C reference board. There is no deployed card-dealing/table/turn/showdown protocol, approved wager and settlement rules, provider integration or multiplayer game session contract in this repository. No cleared provider credentials or jurisdiction/eligibility requirements were supplied. Building a client-random cash game would bypass the established server economy, so the visual board remains unavailable for coin play.
- Jackpot has no deployed shared jackpot pool, contribution, odds, eligibility, funding or payout contract. Its sample pool and forced example jackpot remain explicitly free practice.

## Real progression and honor blockers

The deployed `nimzo_game_level` counts distinct won/lost bets joined to settled server rounds. Its existing thresholds are 0,1,3,6,10,15,21,28,36,45,55,66,78,91,105,120 completed rounds for levels 0–15. Practice taps do not count. The existing level UI uses this RPC and displays its confirmed progress.

Honor medals are deliberately retired by migrations `20261018213000_retire_noncar_gifts_medals_history_access.sql` and `20261018230500_drop_retired_gift_history_and_medal_store.sql`. These remove medal ownership/equipped state, delete medal collectibles, disable listings and revoke/remove old purchase/equip access. `HonorWallContent` is deliberately empty. There is no current earned-honor entitlement/eligibility/award contract to restore. Restoring honor requires approved earning criteria and a new server-owned entitlement design; no invented qualification thresholds or paid-medal economy were introduced.

Existing Wealth/Charm/Active progress remains server-derived from the profile. No level thresholds or financial/progression economy rules changed.
