# Approved game execution gaps

The approved catalog contains Fruit Party Jackpot, Grady Lion, Bigetar, Slot,
Teen Patti, Lucky Wheel 77, and Bounty Football. All seven remain server-disabled.
`nimzo-ui-2.html` defines visual boards and explicitly describes random demo
results, not authoritative server outcomes. No approved execution contract was
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
