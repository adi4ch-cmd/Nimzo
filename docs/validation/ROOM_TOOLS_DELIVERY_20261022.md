# Room tools and game receipt delivery — 2026-10-22

This continues the owner's full NIMZO task in the existing isolated v3 worktree.
It does not certify the complete original task or authenticated Android flows.
Existing branches, installed-app data, asset catalogs and financial history were
preserved. No new APK was built for these changes; the previously published
1.0.39 test APK does not contain them.

## Real funded treasure

The former disabled Send screen is connected to authenticated Supabase RPCs.
Room and World boxes use the existing displayed amounts and quantities. Funding
debits the sender once into an escrow balance. Each eligible person receives one
equal share; the integer remainder is assigned one coin at a time to the first
claims. The sender cannot claim. Fans means followers of the sender; On mic
requires an actual occupied, unlocked room seat, not a client-side assertion.
World boxes cannot be created in private rooms. Claims require current room
membership, an active account and applicable ban/eligibility checks.

Every funding confirmation persists its account, room, amount, quantity,
condition and retry key before submission. The server checks the confirming
account independently of the current SDK token. Lost successful responses remain
recoverable after room/eligibility changes. Corrupt local confirmations block
replacement funding rather than discarding the original key.

Box locking serializes claims and refunds. Expiry is checked using the wall
clock after acquiring the row lock, so waiting behind another transaction cannot
extend eligibility. Unclaimed escrow expires after 24 hours. A protected Cron
job runs every five minutes, refunding up to 100 due boxes per run, with remaining
boxes queued for subsequent runs. The client displays pending/confirmed refund
states and refreshes the wallet when an owned box's refund changes.

Treasure transfers neither award gift XP nor trigger Rocket milestones. There
are no invented Rocket coin prizes. Each debit/claim/refund has a unique ledger
receipt; wallets plus remaining escrow conserve the funded coins.

## Recover settled games before submitting new rounds

`my_game_receipt` reads only the authenticated user's original account/key/game/
room/amount receipt. A settled round can be recovered after leaving a room or
deactivating its catalog entry. Unknown lookup failures retain the pending round.
The new `play_game_checked` also checks the captured account and takes the same
advisory lock as the original game RPC before checking a concurrent settlement.
It delegates a genuinely new wager to the unchanged `play_game` implementation.
No original RNG, odds, caps or payouts were altered.

## Room voting and calculator

Vote now opens actual five-minute room polls: two to four distinct options,
one immutable choice per member, server-derived counts, creator/moderator close,
Realtime updates and a polling fallback. Concurrent creators cannot open two
polls in one room, and concurrent submissions cannot record two choices for one
user. Every mutation checks the confirming account. Creating another poll after
closure uses a new key; uncertain create retries retain the old key. No fake
counts or financial rewards are supplied.

Gift Calculator now computes exact totals using integer arithmetic, validates
numeric input and clears its inputs. It never reads or changes a wallet.

## Deployment and evidence

Three additive, reviewed migrations were applied to `kvqvlpozqokwarovwmwv`:

- `20261022171213_room_treasure_escrow.sql`
- `20261022171412_recover_confirmed_game_receipts.sql`
- `20261022172335_room_polls.sql`

Read-only before/after checks retained 4 wallets, 4,795,975 coins, 22,003,875
diamonds and 34 existing Rocket history events. No production QA funding, gift,
poll or vote was created. All four new tables have RLS enabled. Anonymous
execution of the mutation endpoints is denied; refunds are unavailable to
authenticated app callers. Retry keys are excluded from direct catalog SELECT
grants. The scheduled refund job is active.

Behavioral SQL fixtures run against fresh, disposable PostgreSQL databases.
They exercise actual functions, not production QA debits. Concurrency checks
cover duplicate funding/claims, competing final shares, delayed claims crossing
expiry, simultaneous refund workers, competing poll creation and changed votes.
Game fixtures execute the original settlement function before recovery. Flutter
regressions cover confirmation, restart recovery, corrupt/account-scoped state,
actual RPC payloads, result rendering, poll close/recreation and narrow layouts.
The full suite and log hashes are recorded in
`room-tools-evidence-20261022.json`. CI runs all three added SQL runners.

The Supabase advisor reports the intentional authenticated SECURITY DEFINER
RPC surface; its explicit authorization/privileges were reviewed. That warning
is not represented as an all-clear security audit. Supabase guidance:
https://supabase.com/docs/guides/database/functions#security-definer-vs-invoker

## Remaining original-task scope

Authenticated Android checkout/claim, native animation/audio, multiple-device
Realtime and real voice coexistence remain unverified. Vivox is owner-deferred.
New paid Jackpot/Teen Patti and other preview games still lack implemented and
approved independent settlement/game contracts; they were not enabled through
client randomness. Other unfinished room tools, complete new VIP animation/perk
sets and the inaccessible oversized Lama package remain outside this delivery.
Source/backend tests do not satisfy these device or feature acceptance gates.
Final whole-task release acceptance remains held.
