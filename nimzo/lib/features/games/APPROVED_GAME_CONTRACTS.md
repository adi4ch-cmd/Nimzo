# Approved game execution gaps

The approved catalog contains Lucky 77, Grady Lion, Bigetar, Slot,
Teen Patti, Lucky Wheel 77, and Bounty Football. All seven remain server-disabled.
`nimzo-ui-2.html` defines visual boards and explicitly describes random demo
results, not authoritative server outcomes. No approved financial execution contract was
found in the repository. The legacy `fruit_party` and `fruit_wheel` RPC paths
must not be reused for these identities.

Teen Patti is the fifth catalog entry: its reference has Player A/B/C with
2x/9x/2x multipliers and example card hands. This does not approve traditional
Teen Patti rules. Bounty Football is the seventh entry: its reference has
Home/Draw/Away with 2.5x/6x/2.5x. Approval must confirm that seventh identity,
match/outcome source, and full rules; catalog order is not such approval.

Each approved slug requires approved configuration/rules and versioning,
round/phase/deadline and reconnect state, wager limits/options, authenticated
room-membership authorization, idempotent wager submission, atomic wallet debit,
server-owned outcome and payout, and persisted settlement/history. Clarify gross
versus net multipliers, odds/probabilities, special options, cancellation/refund
policy, and error handling before enabling financial controls.

Current interactions only inspect reference options and preview chip amounts.
Selections do not create wagers, rounds, outcomes, winnings, or wallet writes.
The room overlay supports lower-65-percent, expanded, minimized, restored, and
closed states while retaining the existing room and voice controls. A rendering
engine such as Phaser cannot fill these missing game contracts.

## Lucky 77 HTML5 in-room practice (2026-10-18)

The owner-approved Lucky 77 HTML5 visual demo is packaged offline at
`assets/games/lucky77_room_demo.html` and hosted by `Lucky77RoomWebView`.
The first, formerly mislabeled Fruit Party Jackpot card is now titled
Lucky 77 (slug `lucky_77`). This does not reuse `fruit_party` or any other
previous RPC. The separate Lucky Wheel 77 reference remains unchanged.

The actual Flutter room, its member state and Vivox voice connection stay
mounted while the game is open/minimized. JavaScript can only request
`minimize` or `expand` through the `NimzoGameBridge` channel. There is
no native wallet bridge, real wager submission or Supabase settlement.
All balances, wheel outcomes and repeats are confined to the demo's local
JavaScript memory and reset when the WebView is destroyed.

Approved practice UX: watermelon 2x, 77 8x, grape 2x; one or two betting
boxes, but never both 2x boxes together; chip denominations 5k, 10k, 50k,
300k, 500k, 1m; repeat and auto-repeat. Current spin probabilities are
**illustrative only**, not production odds. Visual parity on physical
Android/iOS devices and secure server-side rules remain separate release gates.
